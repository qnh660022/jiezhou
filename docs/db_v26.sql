-- ============================================================
-- 芥舟 V2.6 云端建库脚本（Supabase SQL Editor 直接粘贴运行，可重复执行）
-- 内容：7 张同步镜像表 + 协作/分享/设置表 + RLS 策略 + 7 个 RPC 函数 + 核查语句
-- 说明：所有业务合流基准是客户端时钟 updated_ms（bigint 毫秒），无 timestamptz 参与合流；
--       跨账号引用（group_id/trip_id 等）只是"值"，不建关系约束、不做 JOIN 解析。
-- ============================================================

-- pgcrypto（分享口令 bcrypt 校验用；须先建，get_share_snapshot 依赖 crypt/gen_salt）
-- Supabase 惯例：扩展装在 extensions schema（2026-09-13 修正）——
-- 此前未指定 schema，若装进了别处，分享函数的 search_path 只有 public，
-- 带 crypt/gen_salt 的口令分支会运行时报错（免口令链接不受影响）。
create extension if not exists pgcrypto with schema extensions;

-- 1 行程镜像
create table if not exists public.trips_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  name text not null default '',
  destination text not null default '',
  emoji text not null default '✈️',
  cover text not null default 'ocean',
  start_epoch_day int not null default 0,
  end_epoch_day int not null default 0,
  note text not null default '',
  group_id text null,
  archived boolean not null default false,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);

-- 2 行程安排镜像
create table if not exists public.trip_items_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  trip_id text not null,
  date_epoch_day int not null default 0,
  type text not null default 'attraction',
  name text not null default '',
  address text not null default '',
  lat double precision null,
  lng double precision null,
  photo_uri text null,            -- 仅存相对路径文字，图片文件不上云
  start_time_min int null,
  duration_min int null,
  cost_cents bigint null,
  cost_currency text not null default 'CNY',
  note text not null default '',
  from_name text not null default '',
  from_address text not null default '',
  from_lat double precision null,
  from_lng double precision null,
  to_name text not null default '',
  to_address text not null default '',
  to_lat double precision null,
  to_lng double precision null,
  flight_no text null,
  sort_order int not null default 0,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_trip_items_sync_trip on public.trip_items_sync(trip_id);

-- 3 团镜像
create table if not exists public.groups_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  name text not null default '',
  icon text not null default '📁',
  budget_enabled boolean not null default false,
  budget_cents bigint null,
  archived boolean not null default false,
  archived_at_ms bigint null,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);

-- 4 成员镜像
create table if not exists public.members_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  group_id text not null,
  name text not null default '',
  color_index int not null default 0,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_members_sync_group on public.members_sync(group_id);

-- 5 账单镜像
create table if not exists public.expenses_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  group_id text not null,
  date_epoch_day int not null default 0,
  title text not null default '',
  category_key text not null default 'other',
  type text not null default 'normal',        -- normal|prepay|refund，金额口径与本地一致(退款负数)
  amount_cents bigint not null default 0,
  currency text not null default 'CNY',
  rate double precision not null default 1.0,
  amount_foreign_cents bigint null,
  payers_json text not null default '[]',
  shares_json text not null default '[]',
  share_mode text not null default 'equal',
  portions_json text null,
  note text not null default '',
  settled_round_id text null,
  trip_id text null,
  trip_item_id text null,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_expenses_sync_group on public.expenses_sync(group_id);

-- 6 结算镜像
create table if not exists public.settlements_sync (
  id text primary key,
  owner_user_id uuid not null default auth.uid(),
  group_id text not null,
  status text not null default 'active',
  transfers_json text not null default '[]',
  expense_ids_json text not null default '[]',
  round_no int not null default 1,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_settlements_sync_group on public.settlements_sync(group_id);

-- 7 分类镜像（小表整体镜像）
create table if not exists public.categories_sync (
  key text primary key,
  owner_user_id uuid not null default auth.uid(),
  name text not null default '',
  icon text not null default '📦',
  builtin boolean not null default false,
  created_ms bigint not null,
  updated_ms bigint not null,
  deleted boolean not null default false
);

-- 8 账本协作：邀请码 + 成员（owner + 受邀成员）
create table if not exists public.group_collab (
  group_id text primary key,
  owner_user_id uuid not null,
  member_user_id uuid[] not null default '{}',
  invite_code text not null unique,   -- 6 位大写，字符集 ABCDEFGHJKLMNPQRSTUVWXYZ23456789
  created_at timestamptz not null default now()
);

-- 9 只读分享令牌（可选口令）
create table if not exists public.share_links (
  token text primary key,             -- 随机 UUID v4
  entity_type text not null check (entity_type in ('trip','group')),
  entity_id text not null,
  owner_user_id uuid not null,
  pass_hash text null,                -- bcrypt cost=10；NULL=免口令
  created_at timestamptz not null default now()
);
create index if not exists idx_share_links_entity on public.share_links(entity_type, entity_id);

-- 10 应用级设置（云端非敏感配置：AI baseUrl/model 等）
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  owner_user_id uuid not null default auth.uid()
);

-- ============================================================
-- RLS：开启行级安全 + 策略
-- 权限模型：owner 全权；账本四表对协作成员（group_collab 名单内）读写；
-- anon 对业务表一律无直表授权（只读页走 security definer 函数）。
-- ============================================================

alter table public.trips_sync enable row level security;
create policy "trips_sync_owner_all" on public.trips_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

alter table public.trip_items_sync enable row level security;
create policy "trip_items_sync_owner_all" on public.trip_items_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

alter table public.categories_sync enable row level security;
create policy "categories_sync_owner_all" on public.categories_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

alter table public.groups_sync enable row level security;
create policy "groups_sync_owner_all" on public.groups_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
create policy "groups_sync_collab_rw" on public.groups_sync
  for all using (
    exists (select 1 from public.group_collab gc
            where gc.group_id = groups_sync.id
              and auth.uid() = any(gc.member_user_id))
  )
  with check (
    exists (select 1 from public.group_collab gc
            where gc.group_id = groups_sync.id
              and auth.uid() = any(gc.member_user_id))
  );

alter table public.members_sync enable row level security;
create policy "members_sync_owner_all" on public.members_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
create policy "members_sync_collab_rw" on public.members_sync
  for all using (
    exists (select 1 from public.group_collab gc
            where gc.group_id = members_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  )
  with check (
    exists (select 1 from public.group_collab gc
            where gc.group_id = members_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  );

alter table public.expenses_sync enable row level security;
create policy "expenses_sync_owner_all" on public.expenses_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
create policy "expenses_sync_collab_rw" on public.expenses_sync
  for all using (
    exists (select 1 from public.group_collab gc
            where gc.group_id = expenses_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  )
  with check (
    exists (select 1 from public.group_collab gc
            where gc.group_id = expenses_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  );

alter table public.settlements_sync enable row level security;
create policy "settlements_sync_owner_all" on public.settlements_sync
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);
create policy "settlements_sync_collab_rw" on public.settlements_sync
  for all using (
    exists (select 1 from public.group_collab gc
            where gc.group_id = settlements_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  )
  with check (
    exists (select 1 from public.group_collab gc
            where gc.group_id = settlements_sync.group_id
              and auth.uid() = any(gc.member_user_id))
  );

alter table public.group_collab enable row level security;
create policy "group_collab_owner_all" on public.group_collab
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

alter table public.share_links enable row level security;
create policy "share_links_owner_all" on public.share_links
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

alter table public.app_settings enable row level security;
create policy "app_settings_owner_all" on public.app_settings
  for all using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

-- ============================================================
-- RPC（全部 security definer、set search_path = public, pg_temp、参数化、JSON 出参）
-- ============================================================

-- 邀请码字符集（去 0/O/1/I）
create or replace function public._jiezhou_invite_charset()
returns text language sql immutable as $$
  select 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
$$;

-- 生成 6 位邀请码
create or replace function public._jiezhou_gen_invite_code()
returns text language plpgsql volatile as $$
declare
  chars text := public._jiezhou_invite_charset();
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, floor(random() * length(chars))::int + 1, 1);
  end loop;
  return result;
end;
$$;

-- 加入协作：按邀请码把当前用户加进 member_user_id（已含则幂等 ok）
create or replace function public.add_collab_member(code text)
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  rec public.group_collab%rowtype;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into rec from public.group_collab gc where gc.invite_code = upper(trim(code));
  if not found then
    return json_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if rec.owner_user_id = auth.uid() then
    return json_build_object('ok', true, 'groupId', rec.group_id);
  end if;
  if not (auth.uid() = any(rec.member_user_id)) then
    update public.group_collab
       set member_user_id = member_user_id || array[auth.uid()]
     where group_id = rec.group_id;
  end if;
  return json_build_object('ok', true, 'groupId', rec.group_id);
end;
$$;

-- 移除协作成员（仅 owner；owner 自身不可被移除）
create or replace function public.remove_collab_member(group_id text, target uuid)
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  rec public.group_collab%rowtype;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into rec from public.group_collab gc where gc.group_id = remove_collab_member.group_id;
  if not found or rec.owner_user_id <> auth.uid() then
    return json_build_object('ok', false, 'error', 'not_owner');
  end if;
  if target = rec.owner_user_id then
    return json_build_object('ok', false, 'error', 'not_owner');
  end if;
  update public.group_collab
     set member_user_id = array_remove(member_user_id, target)
   where group_id = remove_collab_member.group_id;
  return json_build_object('ok', true);
end;
$$;

-- 退出协作（调用者在名单中则移除自己；owner 调用返回 not_member）
create or replace function public.leave_collab(group_id text)
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  rec public.group_collab%rowtype;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into rec from public.group_collab gc where gc.group_id = leave_collab.group_id;
  if not found or rec.owner_user_id = auth.uid() or not (auth.uid() = any(rec.member_user_id)) then
    return json_build_object('ok', false, 'error', 'not_member');
  end if;
  update public.group_collab
     set member_user_id = array_remove(member_user_id, auth.uid())
   where group_id = leave_collab.group_id;
  return json_build_object('ok', true);
end;
$$;

-- 重新生成邀请码（仅 owner；冲突重试最多 5 次）
create or replace function public.regenerate_invite_code(group_id text)
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  rec public.group_collab%rowtype;
  new_code text;
  tries int := 0;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into rec from public.group_collab gc where gc.group_id = regenerate_invite_code.group_id;
  if not found or rec.owner_user_id <> auth.uid() then
    return json_build_object('ok', false, 'error', 'not_owner');
  end if;
  loop
    tries := tries + 1;
    new_code := public._jiezhou_gen_invite_code();
    exit when not exists (select 1 from public.group_collab gc2 where gc2.invite_code = new_code)
           or tries >= 5;
  end loop;
  if exists (select 1 from public.group_collab gc3 where gc3.invite_code = new_code) then
    -- 5 次仍冲突：抛异常让调用方显式重试（概率可忽略：32^6 ≈ 10^9）
    raise exception 'invite_code_conflict';
  end if;
  update public.group_collab
     set invite_code = new_code
   where group_id = regenerate_invite_code.group_id;
  return json_build_object('ok', true, 'code', new_code);
end;
$$;

-- 清除当前账号全部云端数据（不删 auth.user，账号可再登录）
create or replace function public.purge_my_data()
returns json language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
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

-- 物理清理当前账号软删行（retain_months=0 全清 deleted 行）
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

  return json_build_object('ok', true, 'deletedRows', removed);
end;
$$;

-- 只读分享快照（匿名可调；函数属主豁免 RLS，权限全部内聚在函数内——表上无任何 anon policy）
-- 口令：share_links.pass_hash 非空 → 必须传对 4 位口令（bcrypt 校验）
create or replace function public.get_share_snapshot(token text, pass text)
returns json language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare
  link public.share_links%rowtype;
  t public.trips_sync%rowtype;
  g public.groups_sync%rowtype;
  items json;
  members json;
  expenses json;
  settlements json;
  group_name text;
begin
  select * into link from public.share_links sl where sl.token = get_share_snapshot.token;
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
    select * into t from public.trips_sync ts where ts.id = link.entity_id and ts.deleted = false;
    if not found then
      return json_build_object('ok', false, 'error', 'not_found');
    end if;
    if t.group_id is not null then
      select gs.name into group_name from public.groups_sync gs where gs.id = t.group_id;
    end if;
    select coalesce(json_agg(row_to_json(x) order by x.date_epoch_day, x.sort_order), '[]'::json)
      into items
      from (
        select ti.date_epoch_day as "dateEpochDay", ti.type, ti.name, ti.address,
               ti.lat, ti.lng, ti.start_time_min as "startTimeMin", ti.duration_min as "durationMin",
               ti.cost_cents as "costCents", ti.cost_currency as "costCurrency", ti.note, ti.sort_order as "sortOrder"
        from public.trip_items_sync ti
        where ti.trip_id = t.id and ti.deleted = false
      ) x;
    return json_build_object('ok', true, 'kind', 'trip', 'data', json_build_object(
      'trip', json_build_object(
        'name', t.name, 'destination', t.destination, 'emoji', t.emoji, 'cover', t.cover,
        'startEpochDay', t.start_epoch_day, 'endEpochDay', t.end_epoch_day, 'note', t.note,
        'groupName', group_name),
      'items', items));
  elsif link.entity_type = 'group' then
    select * into g from public.groups_sync gs where gs.id = link.entity_id and gs.deleted = false;
    if not found then
      return json_build_object('ok', false, 'error', 'not_found');
    end if;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into members
      from (select m.name, m.color_index as "colorIndex" from public.members_sync m
             where m.group_id = g.id and m.deleted = false) x;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into expenses
      from (select e.date_epoch_day as "dateEpochDay", e.title, e.category_key as "categoryKey",
                   e.type, e.amount_cents as "amountCents", e.currency, e.note
             from public.expenses_sync e
             where e.group_id = g.id and e.deleted = false) x;
    select coalesce(json_agg(row_to_json(x)), '[]'::json) into settlements
      from (select s.transfers_json as "transfersJson", s.round_no as "roundNo", s.created_ms as "createdMs"
             from public.settlements_sync s
             where s.group_id = g.id and s.deleted = false
             order by s.created_ms desc limit 10) x;
    return json_build_object('ok', true, 'kind', 'group', 'data', json_build_object(
      'group', json_build_object('name', g.name, 'icon', g.icon,
                                 'budgetEnabled', g.budget_enabled, 'budgetCents', g.budget_cents),
      'members', members, 'expenses', expenses, 'settlements', settlements));
  end if;
  return json_build_object('ok', false, 'error', 'not_found');
end;
$$;

-- 我的协作名单（§3.13.2：受邀端每次 pull 前刷新"我参与的共享团集合"）。
-- group_collab 对 member 无直表 select（owner 除外），故名单查询走本 RPC。
create or replace function public.list_my_collabs()
returns json language plpgsql security definer set search_path = public, pg_temp as $$
declare
  result json;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select coalesce(json_agg(json_build_object(
           'groupId', gc.group_id,
           'ownerUserId', gc.owner_user_id::text,
           'inviteCode', case when gc.owner_user_id = auth.uid() then gc.invite_code else null end)),
         '[]'::json)
    into result
    from public.group_collab gc
   where gc.owner_user_id = auth.uid() or auth.uid() = any(gc.member_user_id);
  return json_build_object('ok', true, 'collabs', result);
end;
$$;

-- 创建只读分享链接（owner；口令 bcrypt 服务端计算，绝不明文存储）
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
  if entity_type not in ('trip','group') then
    return json_build_object('ok', false, 'error', 'bad_entity_type');
  end if;
  -- 只能分享自己拥有的实体（owner 校验）
  if entity_type = 'trip' then
    select exists(select 1 from public.trips_sync t where t.id = entity_id and t.owner_user_id = uid)
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

-- 执行权限：只读快照对匿名开放；其余仅登录用户
grant execute on function public.get_share_snapshot(text, text) to anon, authenticated;
grant execute on function public.add_collab_member(text) to authenticated;
grant execute on function public.remove_collab_member(text, uuid) to authenticated;
grant execute on function public.leave_collab(text) to authenticated;
grant execute on function public.regenerate_invite_code(text) to authenticated;
grant execute on function public.purge_my_data() to authenticated;
grant execute on function public.purge_deleted_rows(int) to authenticated;
grant execute on function public.list_my_collabs() to authenticated;
grant execute on function public.create_share_link(text, text, text) to authenticated;

-- ============================================================
-- 核查语句：执行后应看到上面 10 张表 relrowsecurity 全部为 true
-- ============================================================
-- select relname, relrowsecurity
--   from pg_class c join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public' and relkind = 'r'
--  order by relname;
