-- ============================================================
-- 芥舟 V2.6.6.2 云端增量脚本（Supabase SQL Editor 直接粘贴运行，可重复执行）
--
-- 内容：
--   0. group_collab 角色列（账本域权限投影）
--   1. 4 张新表：spaces_sync / space_members_sync / space_events_sync / space_invites
--   2. 权限判定辅助函数（security definer，规避 RLS 自引用递归）
--   3. RLS：新表四策略齐全；账本五表按 group_collab/space 角色分档（viewer 只读）；
--      trips_sync / trip_items_sync 读放宽、写受控
--   4. RPC：11 个（create_space ... delete_space / list_my_spaces）
--   5. 授权 + 云端清理函数扩展 + 核查语句
--
-- 依赖：必须先执行过 docs/db_v26.sql（trips_sync / groups_sync / group_collab 等已存在）
--
-- 【与规格书 V2.6.6.2 §3.1 的两处必要补列，已在验收报告「规格偏差」章节登记】
--   ① space_events_sync 补 `updated_ms bigint not null` 与
--      `deleted boolean not null default false`：通用同步引擎的增量拉取
--      （复合游标 updated_ms,id）与合流软删判定强依赖这两列；事件表语义仍是
--      append-only（永不置 deleted / 永不更新），两列只为打通同一条管道。
--   ② space_members_sync 补 `created_ms bigint not null`：§0.3.1 硬性边界要求
--      所有 *_sync 云表的 created_ms 一律 not null 且无默认值，且上行信封
--      SyncEnvelope.toCloudJson() 恒带该列，缺列会被 PostgREST 以 PGRST204 拒绝。
--      joined_ms 保留（业务语义：加入时刻）。
--   所有新表的软删仍同时写 `deleted= true`（引擎墓碑）与 `deleted_ms`（规格书业务字段）。
-- ============================================================

-- pgcrypto（邀请码/空间 id 随机源；db_v26.sql 已建，此处幂等重申）
create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- 0. group_collab 角色列（§3.2）
--    存量行不动 → default 'member'，语义等同 editor。
--    role 同时是「老客户端兼容投影」的聚合位（见 _group_role 注释）。
-- ============================================================
alter table public.group_collab
  add column if not exists "role" text not null default 'member';

-- ============================================================
-- 1. 新表
-- ============================================================

-- 1.1 空间主表（一程一空间：0~1 行程 + 0~1 账本）
create table if not exists public.spaces_sync (
  id          text primary key,
  name        text not null,
  trip_id     text null,                       -- 关联行程（指向 trips_sync.id；跨账号引用只存值，不建外键）
  group_id    text null,                       -- 关联账本（指向 groups_sync.id；同上）
  created_by  uuid not null,                   -- 空间 owner 的 auth uid
  note        text null,
  status      text not null,                   -- 'active' | 'archived'
  created_ms  bigint not null,
  updated_ms  bigint not null,
  deleted_ms  bigint null,                     -- 业务软删时刻（只读残档判定）
  deleted     boolean not null default false,  -- 同步引擎墓碑（与 deleted_ms 同步置位）
  server_updated timestamptz not null default now()
);
create index if not exists idx_spaces_sync_created_by on public.spaces_sync(created_by);
create index if not exists idx_spaces_sync_trip on public.spaces_sync(trip_id);
-- 幂等键：一个账本同时只有一个「未删除」空间（迁移脚本防重复生成，§3.6.1）
create unique index if not exists uq_spaces_sync_group_active
  on public.spaces_sync(group_id) where deleted = false and group_id is not null;

-- 1.2 空间成员（三级权限落库：owner / editor / viewer）
create table if not exists public.space_members_sync (
  id           text primary key,
  space_id     text not null references public.spaces_sync(id),
  user_id      uuid not null,
  role         text not null,             -- 'owner' | 'editor' | 'viewer'
  display_name text not null,
  joined_ms    bigint not null,
  created_ms   bigint not null,           -- §0.3.1：所有 *_sync 表的 created_ms 一律 not null 无默认值
  updated_ms   bigint not null,
  deleted_ms   bigint null,
  deleted      boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_space_members_sync_space on public.space_members_sync(space_id);
create index if not exists idx_space_members_sync_user on public.space_members_sync(user_id);

-- 1.3 协作动态流（append-only：只插入，从不更新/删除）
create table if not exists public.space_events_sync (
  id          text primary key,
  space_id    text not null references public.spaces_sync(id),
  actor_user  uuid not null,
  action      text not null,   -- 枚举见 §3.4
  entity_kind text not null,   -- 'space'|'member'|'trip_item'|'expense'
  entity_id   text null,
  summary     text not null,   -- 展示素材：金额分/条目名/旧新值摘要
  created_ms  bigint not null,
  updated_ms  bigint not null,                  -- 补列①：增量游标用（恒 == created_ms）
  deleted     boolean not null default false,   -- 补列①：引擎合流用（恒 false）
  server_updated timestamptz not null default now()
);
create index if not exists idx_space_events_sync_space
  on public.space_events_sync(space_id, created_ms desc);

-- 1.4 空间邀请码（6 位，机制与账本邀请一致；不落客户端本地表）
create table if not exists public.space_invites (
  code        text primary key,           -- 6 位数字/大写字母
  space_id    text not null references public.spaces_sync(id),
  role        text not null default 'editor',  -- 受邀加入时的默认角色
  created_by  uuid not null,
  created_ms  bigint not null,
  expires_ms  bigint null,                -- 可空 = 永久
  revoked_ms  bigint null
);
create index if not exists idx_space_invites_space on public.space_invites(space_id);

-- ============================================================
-- 2. 权限判定辅助函数
--    全部 security definer：策略内部引用其它 RLS 表时不触发对方策略（否则自引用
--    递归 → 42P17 infinite recursion detected in policy）。
-- ============================================================

-- 当前用户在某空间的角色；非成员返回 null。
create or replace function public._space_role(p_space_id text, p_uid uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select sm.role
    from public.space_members_sync sm
   where sm.space_id = p_space_id
     and sm.user_id = p_uid
     and sm.deleted = false
   limit 1;
$$;

-- 当前用户在某行程上的协作角色（经空间间接判定）；无权限返回 null。
-- 行程 owner 属于「隐含 owner」：由调用方的 owner_user_id 分支单独放行，此处不重复。
create or replace function public._trip_space_role(p_trip_id text, p_uid uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select sm.role
    from public.spaces_sync s
    join public.space_members_sync sm on sm.space_id = s.id
   where s.trip_id = p_trip_id
     and s.deleted = false
     and s.status = 'active'
     and sm.user_id = p_uid
     and sm.deleted = false
   limit 1;
$$;

-- 是否可读该行程（owner 之外：任一空间成员）
create or replace function public._can_read_trip(p_trip_id text, p_uid uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public._trip_space_role(p_trip_id, p_uid) is not null;
$$;

-- 是否可编辑该行程的行程项（owner 之外：空间 owner/editor）
create or replace function public._can_edit_trip_items(p_trip_id text, p_uid uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public._trip_space_role(p_trip_id, p_uid) in ('owner', 'editor');
$$;

-- 账本域角色：空间成员表是权威源；无空间行时回退老 group_collab（老客户端/迁移前数据）。
-- 返回 'owner' | 'member' | 'viewer' | null。语义对齐 §3.2 映射表：
--   空间 owner → 'owner'，空间 editor → 'member'，空间 viewer → 'viewer'。
create or replace function public._group_role(p_group_id text, p_uid uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(
    -- ① 权威源：空间成员（经 spaces_sync.group_id 投影）
    (select case sm.role
              when 'owner'  then 'owner'
              when 'editor' then 'member'
              else 'viewer'
            end
       from public.spaces_sync s
       join public.space_members_sync sm on sm.space_id = s.id
      where s.group_id = p_group_id
        and s.deleted = false
        and sm.user_id = p_uid
        and sm.deleted = false
      limit 1),
    -- ② 回退源：老 group_collab（数组 + 聚合 role 列）
    (select case
              when gc.owner_user_id = p_uid then 'owner'
              when p_uid = any(gc.member_user_id) then coalesce(gc.role, 'member')
              else null
            end
       from public.group_collab gc
      where gc.group_id = p_group_id
      limit 1));
$$;

-- 是否是该空间 owner
create or replace function public._is_space_owner(p_space_id text, p_uid uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public._space_role(p_space_id, p_uid) = 'owner';
$$;

-- 空间动态流是否可读（成员即可）
create or replace function public._can_read_space(p_space_id text, p_uid uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public._space_role(p_space_id, p_uid) is not null;
$$;

-- ============================================================
-- 3. RLS
-- ============================================================

-- ---------- 3.1 trips_sync：读放宽（owner 或任一关联空间成员），写不放宽 ----------
drop policy if exists "trips_sync_owner_all" on public.trips_sync;
drop policy if exists "trips_sync_select" on public.trips_sync;
drop policy if exists "trips_sync_insert" on public.trips_sync;
drop policy if exists "trips_sync_update" on public.trips_sync;
drop policy if exists "trips_sync_delete" on public.trips_sync;
create policy "trips_sync_select" on public.trips_sync for select
  using (auth.uid() = owner_user_id
         or (deleted = false and public._can_read_trip(id, auth.uid())));
create policy "trips_sync_insert" on public.trips_sync for insert
  with check (auth.uid() = owner_user_id);
create policy "trips_sync_update" on public.trips_sync for update
  using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
create policy "trips_sync_delete" on public.trips_sync for delete
  using (auth.uid() = owner_user_id);

-- ---------- 3.2 trip_items_sync：读放宽 + 空间编辑者可写（强制 owner_user_id 保行程 owner） ----------
drop policy if exists "trip_items_sync_owner_all" on public.trip_items_sync;
drop policy if exists "trip_items_sync_select" on public.trip_items_sync;
drop policy if exists "trip_items_sync_insert" on public.trip_items_sync;
drop policy if exists "trip_items_sync_update" on public.trip_items_sync;
drop policy if exists "trip_items_sync_delete" on public.trip_items_sync;
create policy "trip_items_sync_select" on public.trip_items_sync for select
  using (auth.uid() = owner_user_id
         or (deleted = false and public._can_read_trip(trip_id, auth.uid())));
create policy "trip_items_sync_insert" on public.trip_items_sync for insert
  with check (
    auth.uid() = owner_user_id
    or (public._can_edit_trip_items(trip_id, auth.uid())
        and owner_user_id = (select t.owner_user_id from public.trips_sync t
                              where t.id = trip_items_sync.trip_id)));
create policy "trip_items_sync_update" on public.trip_items_sync for update
  using (auth.uid() = owner_user_id
         or public._can_edit_trip_items(trip_id, auth.uid()))
  with check (
    auth.uid() = owner_user_id
    or (public._can_edit_trip_items(trip_id, auth.uid())
        and owner_user_id = (select t.owner_user_id from public.trips_sync t
                              where t.id = trip_items_sync.trip_id)));
create policy "trip_items_sync_delete" on public.trip_items_sync for delete
  using (auth.uid() = owner_user_id
         or public._can_edit_trip_items(trip_id, auth.uid()));

-- ---------- 3.3 categories_sync：不变（逐条列出四策略，避免「其余同理」） ----------
drop policy if exists "categories_sync_owner_all" on public.categories_sync;
drop policy if exists "categories_sync_select" on public.categories_sync;
drop policy if exists "categories_sync_insert" on public.categories_sync;
drop policy if exists "categories_sync_update" on public.categories_sync;
drop policy if exists "categories_sync_delete" on public.categories_sync;
create policy "categories_sync_select" on public.categories_sync for select
  using (auth.uid() = owner_user_id);
create policy "categories_sync_insert" on public.categories_sync for insert
  with check (auth.uid() = owner_user_id);
create policy "categories_sync_update" on public.categories_sync for update
  using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);
create policy "categories_sync_delete" on public.categories_sync for delete
  using (auth.uid() = owner_user_id);

-- ---------- 3.4 groups_sync：owner 全权；协作成员按角色（viewer 只读） ----------
drop policy if exists "groups_sync_owner_all" on public.groups_sync;
drop policy if exists "groups_sync_collab_rw" on public.groups_sync;
drop policy if exists "groups_sync_select" on public.groups_sync;
drop policy if exists "groups_sync_insert" on public.groups_sync;
drop policy if exists "groups_sync_update" on public.groups_sync;
drop policy if exists "groups_sync_delete" on public.groups_sync;
create policy "groups_sync_select" on public.groups_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(id, auth.uid()) is not null);
create policy "groups_sync_insert" on public.groups_sync for insert
  with check (auth.uid() = owner_user_id);
create policy "groups_sync_update" on public.groups_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(id, auth.uid()) in ('owner', 'member'));
create policy "groups_sync_delete" on public.groups_sync for delete
  using (auth.uid() = owner_user_id);

-- ---------- 3.5 members_sync：viewer 仅 select ----------
drop policy if exists "members_sync_owner_all" on public.members_sync;
drop policy if exists "members_sync_collab_rw" on public.members_sync;
drop policy if exists "members_sync_select" on public.members_sync;
drop policy if exists "members_sync_insert" on public.members_sync;
drop policy if exists "members_sync_update" on public.members_sync;
drop policy if exists "members_sync_delete" on public.members_sync;
create policy "members_sync_select" on public.members_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "members_sync_insert" on public.members_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "members_sync_update" on public.members_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "members_sync_delete" on public.members_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

-- ---------- 3.6 expenses_sync：viewer 仅 select ----------
drop policy if exists "expenses_sync_owner_all" on public.expenses_sync;
drop policy if exists "expenses_sync_collab_rw" on public.expenses_sync;
drop policy if exists "expenses_sync_select" on public.expenses_sync;
drop policy if exists "expenses_sync_insert" on public.expenses_sync;
drop policy if exists "expenses_sync_update" on public.expenses_sync;
drop policy if exists "expenses_sync_delete" on public.expenses_sync;
create policy "expenses_sync_select" on public.expenses_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "expenses_sync_insert" on public.expenses_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "expenses_sync_update" on public.expenses_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "expenses_sync_delete" on public.expenses_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

-- ---------- 3.7 settlements_sync：viewer 仅 select ----------
drop policy if exists "settlements_sync_owner_all" on public.settlements_sync;
drop policy if exists "settlements_sync_collab_rw" on public.settlements_sync;
drop policy if exists "settlements_sync_select" on public.settlements_sync;
drop policy if exists "settlements_sync_insert" on public.settlements_sync;
drop policy if exists "settlements_sync_update" on public.settlements_sync;
drop policy if exists "settlements_sync_delete" on public.settlements_sync;
create policy "settlements_sync_select" on public.settlements_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "settlements_sync_insert" on public.settlements_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "settlements_sync_update" on public.settlements_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "settlements_sync_delete" on public.settlements_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

-- ---------- 3.8 group_collab：owner 全权（投影由 RPC 以 definer 身份维护） ----------
drop policy if exists "group_collab_owner_all" on public.group_collab;
drop policy if exists "group_collab_select" on public.group_collab;
drop policy if exists "group_collab_insert" on public.group_collab;
drop policy if exists "group_collab_update" on public.group_collab;
drop policy if exists "group_collab_delete" on public.group_collab;
create policy "group_collab_select" on public.group_collab for select
  using (auth.uid() = owner_user_id);
create policy "group_collab_insert" on public.group_collab for insert
  with check (auth.uid() = owner_user_id);
create policy "group_collab_update" on public.group_collab for update
  using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);
create policy "group_collab_delete" on public.group_collab for delete
  using (auth.uid() = owner_user_id);

-- ---------- 3.9 spaces_sync ----------
alter table public.spaces_sync enable row level security;
drop policy if exists "spaces_sync_select" on public.spaces_sync;
drop policy if exists "spaces_sync_insert" on public.spaces_sync;
drop policy if exists "spaces_sync_update" on public.spaces_sync;
drop policy if exists "spaces_sync_delete" on public.spaces_sync;
create policy "spaces_sync_select" on public.spaces_sync for select
  using (auth.uid() = created_by
         or (deleted = false and public._can_read_space(id, auth.uid())));
create policy "spaces_sync_insert" on public.spaces_sync for insert
  with check (auth.uid() = created_by);
create policy "spaces_sync_update" on public.spaces_sync for update
  using (auth.uid() = created_by) with check (auth.uid() = created_by);
create policy "spaces_sync_delete" on public.spaces_sync for delete
  using (auth.uid() = created_by);

-- ---------- 3.10 space_members_sync ----------
alter table public.space_members_sync enable row level security;
drop policy if exists "space_members_sync_select" on public.space_members_sync;
drop policy if exists "space_members_sync_insert" on public.space_members_sync;
drop policy if exists "space_members_sync_update" on public.space_members_sync;
drop policy if exists "space_members_sync_delete" on public.space_members_sync;
create policy "space_members_sync_select" on public.space_members_sync for select
  using (auth.uid() = user_id
         or (deleted = false and public._can_read_space(space_id, auth.uid())));
create policy "space_members_sync_insert" on public.space_members_sync for insert
  with check (public._is_space_owner(space_id, auth.uid()));
create policy "space_members_sync_update" on public.space_members_sync for update
  using (public._is_space_owner(space_id, auth.uid()))
  with check (public._is_space_owner(space_id, auth.uid()));
create policy "space_members_sync_delete" on public.space_members_sync for delete
  using (public._is_space_owner(space_id, auth.uid()));

-- ---------- 3.11 space_events_sync（append-only） ----------
alter table public.space_events_sync enable row level security;
drop policy if exists "space_events_sync_select" on public.space_events_sync;
drop policy if exists "space_events_sync_insert" on public.space_events_sync;
drop policy if exists "space_events_sync_update" on public.space_events_sync;
drop policy if exists "space_events_sync_delete" on public.space_events_sync;
create policy "space_events_sync_select" on public.space_events_sync for select
  using (public._can_read_space(space_id, auth.uid()));
create policy "space_events_sync_insert" on public.space_events_sync for insert
  with check (auth.uid() = actor_user
              and public._can_read_space(space_id, auth.uid()));
create policy "space_events_sync_update" on public.space_events_sync for update
  using (public._is_space_owner(space_id, auth.uid()))
  with check (public._is_space_owner(space_id, auth.uid()));
create policy "space_events_sync_delete" on public.space_events_sync for delete
  using (public._is_space_owner(space_id, auth.uid()));

-- ---------- 3.12 space_invites（仅空间 owner 可管理） ----------
alter table public.space_invites enable row level security;
drop policy if exists "space_invites_select" on public.space_invites;
drop policy if exists "space_invites_insert" on public.space_invites;
drop policy if exists "space_invites_update" on public.space_invites;
drop policy if exists "space_invites_delete" on public.space_invites;
create policy "space_invites_select" on public.space_invites for select
  using (auth.uid() = created_by or public._is_space_owner(space_id, auth.uid()));
create policy "space_invites_insert" on public.space_invites for insert
  with check (auth.uid() = created_by and public._is_space_owner(space_id, auth.uid()));
create policy "space_invites_update" on public.space_invites for update
  using (public._is_space_owner(space_id, auth.uid()))
  with check (public._is_space_owner(space_id, auth.uid()));
create policy "space_invites_delete" on public.space_invites for delete
  using (public._is_space_owner(space_id, auth.uid()));

-- ============================================================
-- 4. RPC（全部 security definer + search_path 含 public/extensions/pg_temp）
--    统一返回 {ok: bool, ...}；未登录一律 {ok:false,error:'unauthenticated'}
-- ============================================================

-- 内部：写一条协作动态（append-only，失败不抛给主流程调用方；此处直接插入）
create or replace function public._space_event(
  p_space_id text, p_actor uuid, p_action text,
  p_entity_kind text, p_entity_id text, p_summary text)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  insert into public.space_events_sync
    (id, space_id, actor_user, action, entity_kind, entity_id, summary,
     created_ms, updated_ms, deleted)
  values
    ('evt_' || replace(gen_random_uuid()::text, '-', ''), p_space_id, p_actor,
     p_action, p_entity_kind, p_entity_id, coalesce(p_summary, ''),
     now_ms, now_ms, false);
end;
$$;

-- 内部：把空间成员变更投影到 group_collab（老客户端兼容 + 账本域权限）
--   规则（§3.2）：空间 owner → 'owner'，存在任一 editor → 'member'，全为 viewer → 'viewer'
create or replace function public._project_group_collab(p_space_id text)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_group_id text;
  v_owner    uuid;
  v_members  uuid[];
  v_role     text;
  v_has_edit boolean;
begin
  select s.group_id, s.created_by into v_group_id, v_owner
    from public.spaces_sync s where s.id = p_space_id;
  if v_group_id is null then
    return;                                  -- 空间未关联账本：无投影
  end if;
  select coalesce(array_agg(sm.user_id), '{}'::uuid[]),
         coalesce(bool_or(sm.role in ('owner','editor')), false)
    into v_members, v_has_edit
    from public.space_members_sync sm
   where sm.space_id = p_space_id and sm.deleted = false;
  -- owner 必须在数组里（老客户端的「成员」概念含 owner）
  if v_owner is not null and not (v_owner = any(v_members)) then
    v_members := v_members || array[v_owner];
  end if;
  v_role := case when v_has_edit then 'member' else 'viewer' end;
  insert into public.group_collab (group_id, owner_user_id, member_user_id, invite_code, "role")
  values (v_group_id, v_owner, v_members, public._jiezhou_gen_invite_code(), v_role)
  on conflict (group_id) do update
    set member_user_id = excluded.member_user_id,
        "role" = excluded."role";
end;
$$;

-- 内部：加入空间（双写 space_members_sync + group_collab 投影）
create or replace function public._join_space_as(
  p_space_id text, p_uid uuid, p_role text, p_display_name text)
returns text language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_member_id text;
  v_now       bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name      text;
begin
  select sm.id into v_member_id
    from public.space_members_sync sm
   where sm.space_id = p_space_id and sm.user_id = p_uid
   limit 1;
  if v_member_id is not null then
    update public.space_members_sync
       set deleted = false, deleted_ms = null, updated_ms = v_now,
           role = case when role = 'owner' then 'owner' else p_role end,
           display_name = coalesce(nullif(p_display_name, ''), display_name)
     where id = v_member_id;
  else
    v_name := coalesce(nullif(p_display_name, ''), '旅伴');
    insert into public.space_members_sync
      (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
    values
      ('sm_' || replace(gen_random_uuid()::text, '-', ''), p_space_id, p_uid, p_role,
       v_name, v_now, v_now, v_now, false);
  end if;
  perform public._project_group_collab(p_space_id);
  return 'ok';
end;
$$;

-- 4.1 建空间（+ owner 成员行 + space_created 动态）
create or replace function public.create_space(
  p_name text, p_trip_id text, p_group_id text, p_note text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid      uuid := auth.uid();
  v_space_id text;
  v_name     text;
  v_now      bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_display  text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  v_name := nullif(trim(coalesce(p_name, '')), '');
  if v_name is null then
    return jsonb_build_object('ok', false, 'error', 'name_required');
  end if;
  -- 关联实体必须是自己的（避免把别人账本/行程挂进自己空间）
  if p_group_id is not null and not exists (
      select 1 from public.groups_sync g where g.id = p_group_id and g.owner_user_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_trip_id is not null and not exists (
      select 1 from public.trips_sync t where t.id = p_trip_id and t.owner_user_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_group_id is not null and exists (
      select 1 from public.spaces_sync s where s.group_id = p_group_id and s.deleted = false) then
    return jsonb_build_object('ok', false, 'error', 'group_already_in_space');
  end if;

  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');
  insert into public.spaces_sync
    (id, name, trip_id, group_id, created_by, note, status, created_ms, updated_ms, deleted)
  values
    (v_space_id, v_name, p_trip_id, p_group_id, v_uid, p_note, 'active', v_now, v_now, false);

  v_display := coalesce(
    (select u.raw_user_meta_data->>'name' from auth.users u where u.id = v_uid),
    (select split_part(u.email, '@', 1) from auth.users u where u.id = v_uid),
    '我');
  insert into public.space_members_sync
    (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
  values
    ('sm_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, v_uid, 'owner',
     v_display, v_now, v_now, v_now, false);

  perform public._project_group_collab(v_space_id);
  perform public._space_event(v_space_id, v_uid, 'space_created', 'space', v_space_id, v_name);
  return jsonb_build_object('ok', true, 'space_id', v_space_id);
end;
$$;

-- 4.2 改空间（仅 owner；变更写 space_events）
create or replace function public.update_space(
  p_space_id text, p_name text, p_status text, p_trip_id text, p_group_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid  uuid := auth.uid();
  v_old  public.spaces_sync%rowtype;
  v_note text := '';
  v_now  bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text;
  v_status text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_old from public.spaces_sync s where s.id = p_space_id and s.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_old.created_by <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  v_name := coalesce(nullif(trim(coalesce(p_name, '')), ''), v_old.name);
  v_status := coalesce(nullif(trim(coalesce(p_status, '')), ''), v_old.status);
  if v_status not in ('active', 'archived') then
    return jsonb_build_object('ok', false, 'error', 'bad_status');
  end if;
  update public.spaces_sync
     set name = v_name,
         status = v_status,
         trip_id = coalesce(p_trip_id, trip_id),
         group_id = coalesce(p_group_id, group_id),
         updated_ms = v_now
   where id = p_space_id;
  if v_name <> v_old.name then
    v_note := v_old.name || ' → ' || v_name;
    perform public._space_event(p_space_id, v_uid, 'space_renamed', 'space', p_space_id, v_note);
  end if;
  perform public._project_group_collab(p_space_id);
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.3 生成空间邀请码（仅 owner；6 位，复用 pgcrypto 随机）
create or replace function public.create_space_invite(
  p_space_id text, p_role text, p_ttl_hours int)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid   uuid := auth.uid();
  v_role  text := coalesce(nullif(trim(coalesce(p_role, '')), ''), 'editor');
  v_code  text;
  v_tries int := 0;
  v_now   bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_exp   bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public._is_space_owner(p_space_id, v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_role not in ('editor', 'viewer') then
    return jsonb_build_object('ok', false, 'error', 'bad_role');
  end if;
  loop
    v_tries := v_tries + 1;
    v_code := public._jiezhou_gen_invite_code();
    exit when not exists (select 1 from public.space_invites i where i.code = v_code) or v_tries >= 5;
  end loop;
  if exists (select 1 from public.space_invites i where i.code = v_code) then
    raise exception 'invite_code_conflict';
  end if;
  v_exp := case when p_ttl_hours is null or p_ttl_hours <= 0 then null
                else v_now + (p_ttl_hours::bigint * 3600 * 1000) end;
  insert into public.space_invites (code, space_id, role, created_by, created_ms, expires_ms)
  values (v_code, p_space_id, v_role, v_uid, v_now, v_exp);
  return jsonb_build_object('ok', true, 'code', v_code,
                            'role', v_role, 'expires_ms', v_exp);
end;
$$;

-- 4.4 加入空间（单一加入入口；先空间码，未命中回退旧账本邀请码语义）
create or replace function public.join_space(p_code text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid       uuid := auth.uid();
  v_code      text := upper(trim(coalesce(p_code, '')));
  v_inv       public.space_invites%rowtype;
  v_collab    public.group_collab%rowtype;
  v_space_id  text;
  v_now       bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name      text;
  v_display   text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if v_code = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  -- ① 空间邀请码
  select * into v_inv from public.space_invites i where i.code = v_code;
  if found then
    if v_inv.revoked_ms is not null then
      return jsonb_build_object('ok', false, 'error', 'revoked_code');
    end if;
    if v_inv.expires_ms is not null and v_inv.expires_ms < v_now then
      return jsonb_build_object('ok', false, 'error', 'expired_code');
    end if;
    v_display := coalesce(
      (select u.raw_user_meta_data->>'name' from auth.users u where u.id = v_uid),
      (select split_part(u.email, '@', 1) from auth.users u where u.id = v_uid),
      '旅伴');
    perform public._join_space_as(v_inv.space_id, v_uid, v_inv.role, v_display);
    perform public._space_event(v_inv.space_id, v_uid, 'member_joined', 'member', v_uid::text, v_display);
    return jsonb_build_object('ok', true, 'space_id', v_inv.space_id, 'legacy', false);
  end if;

  -- ② 回退：旧账本邀请码（等价 add_collab_member 的按码找群逻辑）
  select * into v_collab from public.group_collab gc where gc.invite_code = v_code;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;
  -- 找该账本已有空间；没有则即时迁移生成（与 migrate_spaces_v2662.sql 同规则）
  select s.id into v_space_id
    from public.spaces_sync s
   where s.group_id = v_collab.group_id and s.deleted = false
   limit 1;
  if v_space_id is null then
    select coalesce(nullif(g.name, ''), '共享账本') into v_name
      from public.groups_sync g where g.id = v_collab.group_id;
    v_name := coalesce(v_name, '共享账本');
    v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');
    insert into public.spaces_sync
      (id, name, trip_id, group_id, created_by, note, status, created_ms, updated_ms, deleted)
    values
      (v_space_id, v_name, null, v_collab.group_id, v_collab.owner_user_id, '由旧共享账本自动升级',
       'active', v_now, v_now, false);
    insert into public.space_members_sync
      (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
    values
      ('sm_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, v_collab.owner_user_id,
       'owner', '旅伴', v_now, v_now, v_now, false)
    on conflict (id) do nothing;
    perform public._space_event(v_space_id, v_collab.owner_user_id, 'space_created',
                                'space', v_space_id, v_name);
  end if;
  -- 老语义：把调用者加进 group_collab.member_user_id（老客户端立即可见）
  if v_collab.owner_user_id <> v_uid and not (v_uid = any(v_collab.member_user_id)) then
    update public.group_collab
       set member_user_id = member_user_id || array[v_uid]
     where group_id = v_collab.group_id;
  end if;
  v_display := coalesce(
    (select u.raw_user_meta_data->>'name' from auth.users u where u.id = v_uid),
    (select split_part(u.email, '@', 1) from auth.users u where u.id = v_uid),
    '旅伴');
  if v_collab.owner_user_id <> v_uid then
    perform public._join_space_as(v_space_id, v_uid, 'editor', v_display);
  end if;
  perform public._space_event(v_space_id, v_uid, 'member_joined', 'member', v_uid::text, v_display);
  return jsonb_build_object('ok', true, 'space_id', v_space_id, 'legacy', true);
end;
$$;

-- 4.5 改成员角色（仅 owner；同步刷新 group_collab.role 投影）
create or replace function public.set_space_member_role(
  p_space_id text, p_target uuid, p_role text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid   uuid := auth.uid();
  v_role  text := trim(coalesce(p_role, ''));
  v_now   bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_old   text;
  v_owner uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public._is_space_owner(p_space_id, v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_role not in ('owner', 'editor', 'viewer') then
    return jsonb_build_object('ok', false, 'error', 'bad_role');
  end if;
  select created_by into v_owner from public.spaces_sync s where s.id = p_space_id;
  if v_owner = p_target and v_role <> 'owner' then
    return jsonb_build_object('ok', false, 'error', 'cannot_demote_owner');
  end if;
  select sm.role into v_old
    from public.space_members_sync sm
   where sm.space_id = p_space_id and sm.user_id = p_target and sm.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;
  update public.space_members_sync
     set role = v_role, updated_ms = v_now
   where space_id = p_space_id and user_id = p_target and deleted = false;
  perform public._project_group_collab(p_space_id);
  perform public._space_event(p_space_id, v_uid, 'member_role_changed', 'member',
                              p_target::text, v_old || ' → ' || v_role);
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.6 移除成员（仅 owner；不能移除自己；软删成员行 + 投影）
create or replace function public.remove_space_member(
  p_space_id text, p_target uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid   uuid := auth.uid();
  v_now   bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name  text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public._is_space_owner(p_space_id, v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_target = v_uid then
    return jsonb_build_object('ok', false, 'error', 'cannot_remove_self');
  end if;
  select sm.display_name into v_name
    from public.space_members_sync sm
   where sm.space_id = p_space_id and sm.user_id = p_target and sm.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;
  update public.space_members_sync
     set deleted = true, deleted_ms = v_now, updated_ms = v_now
   where space_id = p_space_id and user_id = p_target and deleted = false;
  perform public._project_group_collab(p_space_id);
  perform public._space_event(p_space_id, v_uid, 'member_left', 'member',
                              p_target::text, coalesce(v_name, '旅伴') || ' 被移出空间');
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.7 协作直写行程项（空间 owner/editor）
--     校验：调用者是该 space 的 owner/editor；行程项归属 space.trip_id；
--     强制 owner_user_id = 行程 owner（客户端 + RLS 双重校验，§3.3）
create or replace function public.upsert_trip_item_collab(
  p_item jsonb, p_space_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid      uuid := auth.uid();
  v_role     text;
  v_trip_id  text;
  v_space    public.spaces_sync%rowtype;
  v_trip     public.trips_sync%rowtype;
  v_item_id  text;
  v_now      bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_action   text;
  v_summary  text;
  v_exists   boolean;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_space from public.spaces_sync s
   where s.id = p_space_id and s.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  v_role := public._space_role(p_space_id, v_uid);
  if v_role is null or v_role = 'viewer' then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_space.trip_id is null then
    return jsonb_build_object('ok', false, 'error', 'space_has_no_trip');
  end if;
  v_trip_id := p_item->>'trip_id';
  if v_trip_id is null or v_trip_id <> v_space.trip_id then
    return jsonb_build_object('ok', false, 'error', 'trip_mismatch');
  end if;
  select * into v_trip from public.trips_sync t where t.id = v_trip_id and t.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'trip_not_found');
  end if;
  v_item_id := p_item->>'id';
  if v_item_id is null or v_item_id = '' then
    return jsonb_build_object('ok', false, 'error', 'id_required');
  end if;
  select exists(select 1 from public.trip_items_sync ti where ti.id = v_item_id) into v_exists;

  insert into public.trip_items_sync (
    id, owner_user_id, trip_id, date_epoch_day, type, name, address, lat, lng,
    photo_uri, start_time_min, duration_min, cost_cents, cost_currency, note,
    from_name, from_address, from_lat, from_lng, to_name, to_address, to_lat, to_lng,
    flight_no, sort_order, created_ms, updated_ms, deleted)
  values (
    v_item_id,
    v_trip.owner_user_id,                        -- 强制保持行程 owner
    v_trip_id,
    coalesce((p_item->>'date_epoch_day')::int, 0),
    coalesce(nullif(p_item->>'type', ''), 'attraction'),
    coalesce(p_item->>'name', ''),
    coalesce(p_item->>'address', ''),
    nullif(p_item->>'lat', '')::double precision,
    nullif(p_item->>'lng', '')::double precision,
    nullif(p_item->>'photo_uri', ''),
    nullif(p_item->>'start_time_min', '')::int,
    nullif(p_item->>'duration_min', '')::int,
    nullif(p_item->>'cost_cents', '')::bigint,
    coalesce(nullif(p_item->>'cost_currency', ''), 'CNY'),
    coalesce(p_item->>'note', ''),
    coalesce(p_item->>'from_name', ''),
    coalesce(p_item->>'from_address', ''),
    nullif(p_item->>'from_lat', '')::double precision,
    nullif(p_item->>'from_lng', '')::double precision,
    coalesce(p_item->>'to_name', ''),
    coalesce(p_item->>'to_address', ''),
    nullif(p_item->>'to_lat', '')::double precision,
    nullif(p_item->>'to_lng', '')::double precision,
    nullif(p_item->>'flight_no', ''),
    coalesce((p_item->>'sort_order')::int, 0),
    coalesce(nullif(p_item->>'created_ms', '')::bigint, v_now),
    v_now,
    false)
  on conflict (id) do update set
    trip_id = excluded.trip_id,
    owner_user_id = excluded.owner_user_id,
    date_epoch_day = excluded.date_epoch_day,
    type = excluded.type,
    name = excluded.name,
    address = excluded.address,
    lat = excluded.lat,
    lng = excluded.lng,
    photo_uri = excluded.photo_uri,
    start_time_min = excluded.start_time_min,
    duration_min = excluded.duration_min,
    cost_cents = excluded.cost_cents,
    cost_currency = excluded.cost_currency,
    note = excluded.note,
    from_name = excluded.from_name,
    from_address = excluded.from_address,
    from_lat = excluded.from_lat,
    from_lng = excluded.from_lng,
    to_name = excluded.to_name,
    to_address = excluded.to_address,
    to_lat = excluded.to_lat,
    to_lng = excluded.to_lng,
    flight_no = excluded.flight_no,
    sort_order = excluded.sort_order,
    updated_ms = excluded.updated_ms,
    deleted = false;

  v_action := case when v_exists then 'trip_item_updated' else 'trip_item_added' end;
  v_summary := coalesce(nullif(p_item->>'name', ''), '行程项');
  perform public._space_event(p_space_id, v_uid, v_action, 'trip_item', v_item_id, v_summary);

  return jsonb_build_object('ok', true, 'row', (
    select to_jsonb(ti) from public.trip_items_sync ti where ti.id = v_item_id));
end;
$$;

-- 4.8 协作删除行程项（软删 + 事件）
create or replace function public.delete_trip_item_collab(
  p_item_id text, p_space_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid     uuid := auth.uid();
  v_role    text;
  v_space   public.spaces_sync%rowtype;
  v_item    public.trip_items_sync%rowtype;
  v_now     bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_space from public.spaces_sync s
   where s.id = p_space_id and s.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  v_role := public._space_role(p_space_id, v_uid);
  if v_role is null or v_role = 'viewer' then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select * into v_item from public.trip_items_sync ti where ti.id = p_item_id and ti.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'item_not_found');
  end if;
  if v_item.trip_id <> coalesce(v_space.trip_id, '') then
    return jsonb_build_object('ok', false, 'error', 'trip_mismatch');
  end if;
  update public.trip_items_sync
     set deleted = true, updated_ms = v_now
   where id = p_item_id;
  perform public._space_event(p_space_id, v_uid, 'trip_item_deleted', 'trip_item',
                              p_item_id, coalesce(nullif(v_item.name, ''), '行程项'));
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.9 自助退出空间（owner 不能退出自己的空间，只能删空间）
create or replace function public.leave_space(p_space_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid  uuid := auth.uid();
  v_now  bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_owner uuid;
  v_name text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select created_by into v_owner from public.spaces_sync s where s.id = p_space_id and s.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_owner = v_uid then
    return jsonb_build_object('ok', false, 'error', 'owner_cannot_leave');
  end if;
  select sm.display_name into v_name
    from public.space_members_sync sm
   where sm.space_id = p_space_id and sm.user_id = v_uid and sm.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;
  update public.space_members_sync
     set deleted = true, deleted_ms = v_now, updated_ms = v_now
   where space_id = p_space_id and user_id = v_uid and deleted = false;
  -- 老账本域：同步从 member_user_id 数组移除（老客户端立即生效）
  update public.group_collab gc
     set member_user_id = array_remove(gc.member_user_id, v_uid)
   where gc.group_id = (select s.group_id from public.spaces_sync s where s.id = p_space_id);
  perform public._project_group_collab(p_space_id);
  perform public._space_event(p_space_id, v_uid, 'member_left', 'member',
                              v_uid::text, coalesce(v_name, '旅伴') || ' 退出了空间');
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.10 删空间（仅 owner；空间+成员+邀请软删，动态保留 = 只读残档）
create or replace function public.delete_space(p_space_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid  uuid := auth.uid();
  v_now  bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text;
  v_gid  text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select s.name, s.group_id into v_name, v_gid
    from public.spaces_sync s where s.id = p_space_id and s.deleted = false;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if not public._is_space_owner(p_space_id, v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  update public.spaces_sync
     set deleted = true, deleted_ms = v_now, updated_ms = v_now, status = 'archived'
   where id = p_space_id;
  update public.space_members_sync
     set deleted = true, deleted_ms = v_now, updated_ms = v_now
   where space_id = p_space_id and deleted = false;
  update public.space_invites
     set revoked_ms = v_now
   where space_id = p_space_id and revoked_ms is null;
  -- 老账本域：空间没了，协作名单同步清空（老客户端不再看到该共享账本）
  if v_gid is not null then
    update public.group_collab gc
       set member_user_id = '{}'::uuid[]
     where gc.group_id = v_gid;
  end if;
  -- 动态流保留（只读残档，§3.5）
  return jsonb_build_object('ok', true);
end;
$$;

-- 4.11 我的空间列表（客户端同步引擎的协作上下文来源；与 list_my_collabs 同构）
create or replace function public.list_my_spaces()
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid    uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'spaceId',   s.id,
           'name',      s.name,
           'tripId',    s.trip_id,
           'groupId',   s.group_id,
           'status',    s.status,
           'createdBy', s.created_by::text,
           'role',      sm.role,
           'inviteCode', case
                           when s.created_by = v_uid
                           then (select i.code from public.space_invites i
                                  where i.space_id = s.id and i.revoked_ms is null
                                    and (i.expires_ms is null or i.expires_ms > (extract(epoch from clock_timestamp()) * 1000)::bigint)
                                  order by i.created_ms desc limit 1)
                           else null
                         end)), '[]'::jsonb)
    into v_result
    from public.spaces_sync s
    join public.space_members_sync sm on sm.space_id = s.id
   where s.deleted = false
     and sm.deleted = false
     and sm.user_id = v_uid;
  return jsonb_build_object('ok', true, 'spaces', v_result);
end;
$$;

-- ============================================================
-- 5. 授权
-- ============================================================
grant execute on function public.create_space(text, text, text, text) to authenticated;
grant execute on function public.update_space(text, text, text, text, text) to authenticated;
grant execute on function public.create_space_invite(text, text, int) to authenticated;
grant execute on function public.join_space(text) to authenticated;
grant execute on function public.set_space_member_role(text, uuid, text) to authenticated;
grant execute on function public.remove_space_member(text, uuid) to authenticated;
grant execute on function public.upsert_trip_item_collab(jsonb, text) to authenticated;
grant execute on function public.delete_trip_item_collab(text, text) to authenticated;
grant execute on function public.leave_space(text) to authenticated;
grant execute on function public.delete_space(text) to authenticated;
grant execute on function public.list_my_spaces() to authenticated;

-- ============================================================
-- 6. 云端清理函数扩展（新表纳入账号清除 / 软删物理清理）
-- ============================================================
create or replace function public.purge_my_data()
returns json language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  -- 空间域：我建的整空间清除；我只是成员的，移除自己那一行
  delete from public.space_events_sync
   where space_id in (select id from public.spaces_sync where created_by = auth.uid())
      or actor_user = auth.uid();
  delete from public.space_invites
   where created_by = auth.uid()
      or space_id in (select id from public.spaces_sync where created_by = auth.uid());
  delete from public.space_members_sync
   where user_id = auth.uid()
      or space_id in (select id from public.spaces_sync where created_by = auth.uid());
  delete from public.spaces_sync where created_by = auth.uid();
  -- 账本/行程域
  delete from public.trips_sync where owner_user_id = auth.uid();
  delete from public.trip_items_sync where owner_user_id = auth.uid();
  delete from public.groups_sync where owner_user_id = auth.uid();
  delete from public.members_sync where owner_user_id = auth.uid();
  delete from public.expenses_sync where owner_user_id = auth.uid();
  delete from public.settlements_sync where owner_user_id = auth.uid();
  delete from public.categories_sync where owner_user_id = auth.uid();
  delete from public.share_links where owner_user_id = auth.uid();
  delete from public.group_collab where owner_user_id = auth.uid();
  delete from public.app_settings where owner_user_id = auth.uid();
  return json_build_object('ok', true);
end;
$$;

create or replace function public.purge_deleted_rows(retain_months int)
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  cutoff bigint;
  removed bigint := 0;
  n bigint;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if retain_months is null or retain_months < 0 then
    retain_months := 0;
  end if;
  cutoff := (extract(epoch from now()) * 1000)::bigint - (retain_months::bigint * 30 * 24 * 3600 * 1000);

  delete from public.trip_items_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.trips_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.members_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.expenses_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.settlements_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.categories_sync where owner_user_id = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;
  delete from public.space_members_sync where deleted = true and deleted_ms is not null
    and (retain_months = 0 or deleted_ms < cutoff)
    and public._is_space_owner(space_id, auth.uid());
  get diagnostics n = row_count; removed := removed + n;
  delete from public.spaces_sync where created_by = auth.uid() and deleted = true
    and (retain_months = 0 or updated_ms < cutoff);
  get diagnostics n = row_count; removed := removed + n;

  return json_build_object('ok', true, 'deletedRows', removed);
end;
$$;

-- ============================================================
-- 7. 核查语句（执行后人工核对；不要在 SQL Editor 里全选执行）
-- ============================================================
-- 7.1 新表已建且开启 RLS：
-- select relname, relrowsecurity from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public'
--    and relname in ('spaces_sync','space_members_sync','space_events_sync','space_invites');
--
-- 7.2 新表策略逐表 4 条（spaces/space_members/space_events/space_invites 各 4）：
-- select tablename, policyname, cmd from pg_policies
--  where schemaname = 'public'
--    and tablename in ('spaces_sync','space_members_sync','space_events_sync','space_invites')
--  order by tablename, cmd;
--
-- 7.3 group_collab.role 列已存在且默认 member：
-- select column_name, data_type, column_default, is_nullable
--   from information_schema.columns
--  where table_schema = 'public' and table_name = 'group_collab' and column_name = 'role';
--
-- 7.4 11 个新 RPC 全部就绪：
-- select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and proname in ('create_space','update_space','create_space_invite','join_space',
--                    'set_space_member_role','remove_space_member','upsert_trip_item_collab',
--                    'delete_trip_item_collab','leave_space','delete_space','list_my_spaces')
--  order by proname;
