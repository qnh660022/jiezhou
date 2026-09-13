-- ============================================================
-- 旅伴空间创建 + 行程分享链接热修复（2026-09-13）
-- Supabase Dashboard → SQL Editor 直接执行，可重复执行。
--
-- 修复内容：
-- 1) 给曾执行过旧版/部分版旅伴空间脚本的数据库补齐同步字段，避免
--    create_space 在协作投影或动态写入阶段因缺列整笔回滚；
-- 2) 修复 get_share_snapshot 的排序字段别名。子查询输出的是
--    "dateEpochDay" / "sortOrder"，外层排序必须引用这两个带引号的别名。
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- 旅伴空间旧版增量脚本兼容补列
alter table public.group_collab
  add column if not exists "role" text not null default 'member';

alter table public.spaces_sync
  add column if not exists deleted_ms bigint;

alter table public.space_members_sync
  add column if not exists created_ms bigint;
update public.space_members_sync
   set created_ms = coalesce(created_ms, joined_ms, 0)
 where created_ms is null;
alter table public.space_members_sync
  alter column created_ms set not null;

alter table public.space_events_sync
  add column if not exists updated_ms bigint;
update public.space_events_sync
   set updated_ms = coalesce(updated_ms, created_ms, 0)
 where updated_ms is null;
alter table public.space_events_sync
  alter column updated_ms set not null;
alter table public.space_events_sync
  add column if not exists deleted boolean default false;
update public.space_events_sync
   set deleted = false
 where deleted is null;
alter table public.space_events_sync
  alter column deleted set default false;
alter table public.space_events_sync
  alter column deleted set not null;

-- 确保建空间函数使用包含 extensions 的 search_path（gen_random_uuid）。
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
  if p_group_id is not null and not exists (
      select 1 from public.groups_sync g
       where g.id = p_group_id and g.owner_user_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_trip_id is not null and not exists (
      select 1 from public.trips_sync t
       where t.id = p_trip_id and t.owner_user_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_group_id is not null and exists (
      select 1 from public.spaces_sync s
       where s.group_id = p_group_id and s.deleted = false) then
    return jsonb_build_object('ok', false, 'error', 'group_already_in_space');
  end if;

  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');
  insert into public.spaces_sync
    (id, name, trip_id, group_id, created_by, note, status,
     created_ms, updated_ms, deleted)
  values
    (v_space_id, v_name, p_trip_id, p_group_id, v_uid, p_note, 'active',
     v_now, v_now, false);

  v_display := coalesce(
    (select u.raw_user_meta_data->>'name' from auth.users u where u.id = v_uid),
    (select split_part(u.email, '@', 1) from auth.users u where u.id = v_uid),
    '我');
  insert into public.space_members_sync
    (id, space_id, user_id, role, display_name, joined_ms,
     created_ms, updated_ms, deleted)
  values
    ('sm_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, v_uid,
     'owner', v_display, v_now, v_now, v_now, false);

  perform public._project_group_collab(v_space_id);
  perform public._space_event(v_space_id, v_uid, 'space_created', 'space',
                              v_space_id, v_name);
  return jsonb_build_object('ok', true, 'space_id', v_space_id);
end;
$$;

grant execute on function public.create_space(text, text, text, text) to authenticated;

-- 只读分享快照（与 docs/db_v26.sql / fix_share_pass_20260913.sql 保持一致）
create or replace function public.get_share_snapshot(token text, pass text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
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
  end if;
  return json_build_object('ok', false, 'error', 'not_found');
end;
$$;

grant execute on function public.get_share_snapshot(text, text) to anon, authenticated;
