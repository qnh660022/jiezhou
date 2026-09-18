-- ============================================================
-- 芥舟 V2.7.2 云端增量脚本（幂等，可重复执行）
--
-- 施工依据：docs/V2.7/芥舟V2.7.2版提示词工程.md
--   §四 S1.4(3) 云端增量脚本
--
-- 内容：
--   0) 既有列扩列：trips.pace / trip_items.guide_ref / trip_items.backup_of
--      （云端无 shared_* 镜像云表——受邀端共用同一云表，见偏差登记）
--   1) 新表：wishlist_items_sync（+ 索引）
--   2) RLS：逐条克隆 trips_sync / trip_items_sync 现行策略，仅替换表名与列集
--   3) 对账查询（列名核对 + 空值核对 + 行数核对 + 新表存在性核对）
--
-- ⚠️ guide_ref / backup_of 为弱关联（nullable），不建外键、不加 NOT NULL。
-- ⚠️ 本脚本不修改任何既有 RLS 策略语义（仅新增，不放宽）。
-- ============================================================

-- ============================================================
-- 0. 既有表扩列
-- ============================================================

-- 装配节奏档（relaxed / standard / tight），随 trips 整行 LWW
alter table public.trips_sync
  add column if not exists pace text not null default 'standard';
update public.trips_sync set pace = 'standard' where pace is null;
alter table public.trips_sync alter column pace set not null;

-- 攻略弱关联 "<cityKey>#<栏>#<序号>"（spots|food）与 Plan B 备选指向
alter table public.trip_items_sync add column if not exists guide_ref text;
alter table public.trip_items_sync add column if not exists backup_of text;

-- ============================================================
-- 1. 新表：想去池（行程内候选区，条目无日期）
-- ============================================================

create table if not exists public.wishlist_items_sync (
  id            text primary key,
  owner_user_id uuid not null default auth.uid(),
  trip_id       text not null,
  city_key      text not null default '',
  name          text not null default '',
  address       text not null default '',
  type          text not null default 'attraction', -- attraction|food|transport|stay|note
  duration_min  bigint null,
  tag           text null,
  guide_ref     text null,
  note          text not null default '',
  sort_order    bigint not null default 0,
  created_ms    bigint not null,
  updated_ms    bigint not null,
  deleted       boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_wishlist_items_sync_trip on public.wishlist_items_sync(trip_id);

-- 兼容已执行过旧版/部分版脚本的数据库（补齐可能缺失的列）
alter table public.wishlist_items_sync add column if not exists city_key text not null default '';
alter table public.wishlist_items_sync add column if not exists address text not null default '';
alter table public.wishlist_items_sync add column if not exists type text not null default 'attraction';
alter table public.wishlist_items_sync add column if not exists note text not null default '';
alter table public.wishlist_items_sync add column if not exists sort_order bigint not null default 0;
alter table public.wishlist_items_sync add column if not exists deleted boolean not null default false;

-- ============================================================
-- 2. RLS：克隆 trips_sync（读放宽给空间成员）与 trip_items_sync
--    （写放宽给空间 owner/editor）的现行策略，仅替换表名与列集。
-- ============================================================

alter table public.wishlist_items_sync enable row level security;

drop policy if exists "wishlist_items_sync_select" on public.wishlist_items_sync;
drop policy if exists "wishlist_items_sync_insert" on public.wishlist_items_sync;
drop policy if exists "wishlist_items_sync_update" on public.wishlist_items_sync;
drop policy if exists "wishlist_items_sync_delete" on public.wishlist_items_sync;
create policy "wishlist_items_sync_select" on public.wishlist_items_sync for select
  using (auth.uid() = owner_user_id
         or (deleted = false and public._can_read_trip(trip_id, auth.uid())));
create policy "wishlist_items_sync_insert" on public.wishlist_items_sync for insert
  with check (
    auth.uid() = owner_user_id
    or (public._can_edit_trip_items(trip_id, auth.uid())
        and owner_user_id = (select t.owner_user_id from public.trips_sync t
                              where t.id = wishlist_items_sync.trip_id)));
create policy "wishlist_items_sync_update" on public.wishlist_items_sync for update
  using (auth.uid() = owner_user_id
         or public._can_edit_trip_items(trip_id, auth.uid()))
  with check (
    auth.uid() = owner_user_id
    or (public._can_edit_trip_items(trip_id, auth.uid())
        and owner_user_id = (select t.owner_user_id from public.trips_sync t
                              where t.id = wishlist_items_sync.trip_id)));
create policy "wishlist_items_sync_delete" on public.wishlist_items_sync for delete
  using (auth.uid() = owner_user_id
         or public._can_edit_trip_items(trip_id, auth.uid()));

-- ============================================================
-- 3. 对账查询（人工核对；未通过不得放行）
-- ============================================================

-- 3.1 列名核对：3 个既有表扩列 + 新表存在
select table_name, column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public'
   and (
     (table_name = 'trips_sync'      and column_name = 'pace')
     or (table_name = 'trip_items_sync' and column_name in ('guide_ref', 'backup_of'))
     or (table_name = 'wishlist_items_sync')
   )
 order by table_name, ordinal_position;

-- 3.2 空值核对：NOT NULL 列不得为空
select 'trips_sync.pace' as col, count(*) as null_rows
  from public.trips_sync where pace is null
union all
select 'wishlist_items_sync.trip_id', count(*)
  from public.wishlist_items_sync where trip_id is null
union all
select 'wishlist_items_sync.name', count(*)
  from public.wishlist_items_sync where name is null
union all
select 'wishlist_items_sync.type', count(*)
  from public.wishlist_items_sync where type is null;

-- 3.3 行数核对：扩列不改变既有行数
select 'trips_sync' as t, count(*) from public.trips_sync
union all select 'trip_items_sync', count(*) from public.trip_items_sync
union all select 'wishlist_items_sync', count(*) from public.wishlist_items_sync;

-- 3.4 RLS 策略核对：新表 4 条策略
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'wishlist_items_sync'
 order by policyname;

-- ============================================================
-- 4. 回退说明（人工裁决用，不自动执行）
--   * 扩列可保留（无副作用）；如需回退：
--     alter table public.trips_sync drop column if exists pace;
--     alter table public.trip_items_sync drop column if exists guide_ref;
--     alter table public.trip_items_sync drop column if exists backup_of;
--   * 新表回退需先确认无存量行：
--     drop table if exists public.wishlist_items_sync;
-- ============================================================
