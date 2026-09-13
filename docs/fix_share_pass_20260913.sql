-- ============================================================
-- 修复「带口令的分享链接无法使用」（2026-09-13）
-- 在 Supabase Dashboard → SQL Editor 粘贴执行一次即可，可重复执行。
--
-- 现象：免口令链接一切正常；带 4 位口令时「生成链接」报错 /
-- 打开链接口令验证失败。
-- 根因：pgcrypto（crypt / gen_salt）在 Supabase 上默认装在
--   extensions schema，而分享两个函数声明了
--   `set search_path = public, pg_temp`，口令分支运行时找不到
--   crypt/gen_salt → 500。免口令分支不经过这两个函数，所以正常。
--
-- 执行后自检：
--   1) 第一段查询应返回 crypt/gen_salt 所在 schema（期望 extensions）；
--   2) App 里带口令重新生成一条链接并打开验证。
-- ============================================================

-- 0) 诊断：crypt / gen_salt 现在装在哪个 schema
select n.nspname as schema_name, p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where p.proname in ('crypt', 'gen_salt')
 order by p.proname;

-- 1) 确保扩展存在且位于 extensions schema
--    （若已装在 public 也不影响：search_path 两个 schema 都包含）
create extension if not exists pgcrypto with schema extensions;

-- 2) 重建分享函数：search_path 加入 extensions
--    （create or replace 保持签名不变，幂等）

-- 只读分享快照（匿名可调；口令 bcrypt 校验）
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

-- 创建只读分享链接（owner；口令 bcrypt 服务端计算）
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

-- 3) 执行权限（重建函数后保持不变，重复 grant 幂等）
grant execute on function public.get_share_snapshot(text, text) to anon, authenticated;
grant execute on function public.create_share_link(text, text, text) to authenticated;
