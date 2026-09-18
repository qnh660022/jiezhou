-- ============================================================
-- 芥舟 V2.7.1 云端增量脚本（幂等，可重复执行）
--
-- 施工依据：docs/V2.7/芥舟V2.7.1版提示词工程.md
--   §五 S1.2(3) 云端增量脚本
--   §十一 S5.3     只读结算链接（share_links CHECK + get_share_snapshot 分支）
--
-- 内容：
--   0) 既有列扩列：groups.kind / members.archived / expenses.fund_id /
--      expenses.pay_method / settlements.strategy
--   1) 新表：funds_sync / inbox_items_sync（+ 索引）
--   2) RLS：按 _group_role 分档（owner 全权；member 可写；viewer 仅 select）
--   3) share_links.entity_type CHECK 扩 'settle'
--   4) get_share_snapshot 增 settle 分支（trip/group 分支原样保留）
--   5) 对账查询（列名核对 + 空值核对 + 行数核对 + 新表存在性核对）
--
-- ⚠️ 排序别名带引号的坑（H-历史）：settle 分支不做子查询排序别名扩列，
--    trip 分支内的 "dateEpochDay" / "sortOrder" 带引号引用必须原样保留。
-- ============================================================

-- ============================================================
-- 0. 既有表扩列
-- ============================================================

alter table public.groups_sync
  add column if not exists kind text not null default 'travel';
update public.groups_sync set kind = 'travel' where kind is null;
alter table public.groups_sync alter column kind set not null;

alter table public.members_sync
  add column if not exists archived boolean not null default false;
update public.members_sync set archived = false where archived is null;
alter table public.members_sync alter column archived set not null;

alter table public.expenses_sync
  add column if not exists fund_id text null;
alter table public.expenses_sync
  add column if not exists pay_method text null;

alter table public.settlements_sync
  add column if not exists strategy text not null default 'minTransfers';
update public.settlements_sync set strategy = 'minTransfers' where strategy is null;
alter table public.settlements_sync alter column strategy set not null;

-- ============================================================
-- 1. 新表：公款池 / 记账收件箱
-- ============================================================

-- 1.1 公款池（一池一管理人；入金 prepay / 出金 normal）
create table if not exists public.funds_sync (
  id                text primary key,
  owner_user_id     uuid not null default auth.uid(),
  group_id          text not null,
  name              text not null default '',
  manager_member_id text not null default '',
  target_cents      bigint null,
  status            text not null default 'open',   -- open | closed
  created_ms        bigint not null,
  updated_ms        bigint not null,
  deleted           boolean not null default false,
  server_updated    timestamptz not null default now()
);
create index if not exists idx_funds_sync_group on public.funds_sync(group_id);
create index if not exists idx_funds_sync_status on public.funds_sync(group_id, status);

-- 1.2 记账收件箱（pending 条目不参与任何金额口径，仅本表暂存）
create table if not exists public.inbox_items_sync (
  id                  text primary key,
  owner_user_id       uuid not null default auth.uid(),
  group_id            text not null,
  amount_cents        bigint not null default 0,
  note                text null,
  captured_ms         bigint not null,
  source              text not null default 'manual',  -- manual | quick_action
  status              text not null default 'pending', -- pending | converted
  converted_expense_id text null,
  created_ms          bigint not null,
  updated_ms          bigint not null,
  deleted             boolean not null default false,
  server_updated      timestamptz not null default now()
);
create index if not exists idx_inbox_items_sync_group on public.inbox_items_sync(group_id);
create index if not exists idx_inbox_items_sync_status on public.inbox_items_sync(group_id, status);

-- 兼容已执行过旧版/部分版脚本的数据库（补齐可能缺失的列）
alter table public.funds_sync      add column if not exists status text not null default 'open';
alter table public.inbox_items_sync add column if not exists source text not null default 'manual';
alter table public.inbox_items_sync add column if not exists status text not null default 'pending';
alter table public.inbox_items_sync add column if not exists converted_expense_id text null;

-- ============================================================
-- 2. RLS：与 db_v2662.sql §3.4~3.7 同款分档写法
--    owner 全权；编辑者（'owner'/'member'）可写；viewer 仅 select。
--    不得放宽既有策略、不新增 permissive 全量策略。
-- ============================================================

alter table public.funds_sync enable row level security;

drop policy if exists "funds_sync_select" on public.funds_sync;
drop policy if exists "funds_sync_insert" on public.funds_sync;
drop policy if exists "funds_sync_update" on public.funds_sync;
drop policy if exists "funds_sync_delete" on public.funds_sync;
create policy "funds_sync_select" on public.funds_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "funds_sync_insert" on public.funds_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "funds_sync_update" on public.funds_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "funds_sync_delete" on public.funds_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

alter table public.inbox_items_sync enable row level security;

drop policy if exists "inbox_items_sync_select" on public.inbox_items_sync;
drop policy if exists "inbox_items_sync_insert" on public.inbox_items_sync;
drop policy if exists "inbox_items_sync_update" on public.inbox_items_sync;
drop policy if exists "inbox_items_sync_delete" on public.inbox_items_sync;
create policy "inbox_items_sync_select" on public.inbox_items_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "inbox_items_sync_insert" on public.inbox_items_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "inbox_items_sync_update" on public.inbox_items_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "inbox_items_sync_delete" on public.inbox_items_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

-- ============================================================
-- 3. share_links：entity_type CHECK 扩 'settle'
-- ============================================================

alter table public.share_links drop constraint if exists share_links_entity_type_check;
alter table public.share_links add constraint share_links_entity_type_check
  check (entity_type in ('trip', 'group', 'settle'));

-- ============================================================
-- 4. get_share_snapshot：增 settle 分支
--    ⚠️ trip / group 分支逐字保留（回归红线）。
--    ⚠️ settle 快照只含转账列表：不含账单明细、备注、成员余额。
--    completedAt 口径：云端 settlements_sync 无 completed_at 列，
--    status='completed' 时以 updated_ms 近似（完成时会更新该行）。
-- ============================================================

create or replace function public.get_share_snapshot(token text, pass text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  link public.share_links%rowtype;
  t public.trips_sync%rowtype;
  g public.groups_sync%rowtype;
  st public.settlements_sync%rowtype;
  items json;
  members json;
  expenses json;
  settlements json;
  group_name text;
begin
  select * into link
    from public.share_links sl
   where sl.token = get_share_snapshot.token;
  if not found then
    return json_build_object('ok', false, 'error', 'not_found');
  end if;

  if link.pass_hash is not null then
    if pass is null or length(trim(pass)) = 0 then
      return json_build_object('ok', false, 'error', 'need_pass');
    end if;
    if crypt(pass, link.pass_hash) <> link.pass_hash then
      return json_build_object('ok', false, 'error', 'bad_pass');
    end if;
  end if;

  if link.entity_type = 'trip' then
    select * into t
      from public.trips_sync ts
     where ts.id = link.entity_id and ts.deleted = false;
    if not found then
      return json_build_object('ok', false, 'error', 'not_found');
    end if;
    if t.group_id is not null then
      select gs.name into group_name
        from public.groups_sync gs where gs.id = t.group_id;
    end if;
    select coalesce(
             json_agg(row_to_json(x) order by x."dateEpochDay", x."sortOrder"),
             '[]'::json)
      into items
      from (
        select ti.date_epoch_day as "dateEpochDay", ti.type, ti.name, ti.address,
               ti.lat, ti.lng, ti.start_time_min as "startTimeMin",
               ti.duration_min as "durationMin", ti.cost_cents as "costCents",
               ti.cost_currency as "costCurrency", ti.note,
               ti.sort_order as "sortOrder"
          from public.trip_items_sync ti
         where ti.trip_id = t.id and ti.deleted = false
      ) x;
    return json_build_object('ok', true, 'kind', 'trip', 'data', json_build_object(
      'trip', json_build_object(
        'name', t.name, 'destination', t.destination, 'emoji', t.emoji,
        'cover', t.cover, 'startEpochDay', t.start_epoch_day,
        'endEpochDay', t.end_epoch_day, 'note', t.note,
        'groupName', group_name),
      'items', items));
  elsif link.entity_type = 'group' then
    select * into g
      from public.groups_sync gs
     where gs.id = link.entity_id and gs.deleted = false;
    if not found then
      return json_build_object('ok', false, 'error', 'not_found');
    end if;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into members
      from (
        select m.name, m.color_index as "colorIndex"
          from public.members_sync m
         where m.group_id = g.id and m.deleted = false
      ) x;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into expenses
      from (
        select e.date_epoch_day as "dateEpochDay", e.title,
               e.category_key as "categoryKey", e.type,
               e.amount_cents as "amountCents", e.currency, e.note
          from public.expenses_sync e
         where e.group_id = g.id and e.deleted = false
      ) x;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into settlements
      from (
        select s.transfers_json as "transfersJson", s.round_no as "roundNo",
               s.created_ms as "createdMs"
          from public.settlements_sync s
         where s.group_id = g.id and s.deleted = false
         order by s.created_ms desc limit 10
      ) x;
    return json_build_object('ok', true, 'kind', 'group', 'data', json_build_object(
      'group', json_build_object(
        'name', g.name, 'icon', g.icon, 'budgetEnabled', g.budget_enabled,
        'budgetCents', g.budget_cents),
      'members', members, 'expenses', expenses, 'settlements', settlements));
  elsif link.entity_type = 'settle' then
    select * into st
      from public.settlements_sync ss
     where ss.id = link.entity_id and ss.deleted = false;
    if not found then
      return json_build_object('ok', false, 'error', 'not_found');
    end if;
    select gs.name into group_name
      from public.groups_sync gs where gs.id = st.group_id;
    return json_build_object('ok', true, 'kind', 'settle', 'data', json_build_object(
      'groupName', group_name,
      'roundNo', st.round_no,
      'completedAt', case when st.status = 'completed' then st.updated_ms else null end,
      'transfers', coalesce(nullif(st.transfers_json, '')::json, '[]'::json)));
  end if;
  return json_build_object('ok', false, 'error', 'not_found');
end;
$$;

grant execute on function public.get_share_snapshot(text, text) to anon, authenticated;

-- 4.1 create_share_link：entity_type 扩 'settle'（归属校验走 settlements_sync）
--     ⚠️ trip / group 分支逐字保留。
create or replace function public.create_share_link(entity_type text, entity_id text, pass text)
returns json language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  uid uuid := auth.uid();
  token text;
  hash text;
  owned boolean;
begin
  if uid is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if entity_type not in ('trip','group','settle') then
    return json_build_object('ok', false, 'error', 'bad_entity_type');
  end if;
  if entity_type = 'trip' then
    select exists(select 1 from public.trips_sync t where t.id = entity_id and t.owner_user_id = uid)
      into owned;
  elsif entity_type = 'settle' then
    select exists(select 1 from public.settlements_sync s where s.id = entity_id and s.owner_user_id = uid)
      into owned;
  else
    select exists(select 1 from public.groups_sync g where g.id = entity_id and g.owner_user_id = uid)
      into owned;
  end if;
  if not owned then
    return json_build_object('ok', false, 'error', 'not_owner');
  end if;
  token := gen_random_uuid()::text;
  if pass is not null and length(trim(pass)) > 0 then
    hash := crypt(trim(pass), gen_salt('bf', 10));
  else
    hash := null;
  end if;
  insert into public.share_links (token, entity_type, entity_id, owner_user_id, pass_hash)
  values (token, entity_type, entity_id, uid, hash);
  return json_build_object('ok', true, 'token', token);
end;
$$;

grant execute on function public.create_share_link(text, text, text) to authenticated;

-- ============================================================
-- 5. 对账查询（人工核对；未通过不得放行）
-- ============================================================

-- 5.1 列名核对：5 个既有表扩列 + 2 张新表存在
select table_name, column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public'
   and (
     (table_name = 'groups_sync'      and column_name = 'kind')
     or (table_name = 'members_sync'  and column_name = 'archived')
     or (table_name = 'expenses_sync' and column_name in ('fund_id', 'pay_method'))
     or (table_name = 'settlements_sync' and column_name = 'strategy')
     or (table_name = 'funds_sync')
     or (table_name = 'inbox_items_sync')
   )
 order by table_name, ordinal_position;

-- 5.2 空值核对：NOT NULL 列不得为空
select 'groups_sync.kind' as col, count(*) as null_rows
  from public.groups_sync where kind is null
union all
select 'members_sync.archived', count(*)
  from public.members_sync where archived is null
union all
select 'settlements_sync.strategy', count(*)
  from public.settlements_sync where strategy is null
union all
select 'funds_sync.manager_member_id', count(*)
  from public.funds_sync where manager_member_id is null
union all
select 'inbox_items_sync.status', count(*)
  from public.inbox_items_sync where status is null;

-- 5.3 行数核对：扩列不改变既有行数
select 'groups_sync' as t, count(*) from public.groups_sync
union all select 'members_sync', count(*) from public.members_sync
union all select 'expenses_sync', count(*) from public.expenses_sync
union all select 'settlements_sync', count(*) from public.settlements_sync
union all select 'funds_sync', count(*) from public.funds_sync
union all select 'inbox_items_sync', count(*) from public.inbox_items_sync;

-- 5.4 约束核对：share_links CHECK 已含 'settle'
select con.conname, pg_get_constraintdef(con.oid) as definition
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
 where rel.relname = 'share_links' and con.contype = 'c';

-- 5.5 RLS 策略核对：新表每表 4 条策略
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public' and tablename in ('funds_sync', 'inbox_items_sync')
 order by tablename, policyname;

-- ============================================================
-- 6. 回退说明（人工裁决用，不自动执行）
--   * 扩列可保留（无副作用）；如需回退：
--     alter table public.groups_sync drop column if exists kind;
--   * get_share_snapshot 回退：重新 create or replace 上一版函数体
--     （docs/fix_companion_space_and_share_20260913.sql §get_share_snapshot）
--   * share_links CHECK 回退需先清理 entity_type='settle' 的存量行。
-- ============================================================
