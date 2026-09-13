-- ============================================================
-- 芥舟 V2.6.6.2 存量迁移脚本：老共享账本 → 旅伴空间
--
-- 前置：必须先执行 docs/db_v2662.sql（spaces_sync / space_members_sync /
--       space_events_sync / space_invites 与辅助函数已就绪）。
--
-- 特性：
--   * 幂等可重复执行：同一账本只会生成一个未删除空间（唯一部分索引
--     uq_spaces_sync_group_active 兜底，脚本自身也先查后插）。
--   * 不删除 group_collab 数据：老版本客户端继续用旧 RPC 与旧四 Tab 数据路径。
--   * 只做「投影生成空间行 + 成员行」，不改动任何账本/账单/成员业务数据。
--
-- 映射规则（§3.2 / §3.6）：
--   group_collab.owner_user_id            → space.created_by + space_members.role='owner'
--   group_collab.member_user_id[] 任一元素 → space_members.role='editor'
--   display_name 取 members_sync 中该团成员名（按 created_ms 顺序位次对应），
--                取不到回退 '旅伴'。
--
-- 执行方式：Supabase SQL Editor 整段粘贴运行；末尾会自动输出对账查询结果，
--           请肉眼核对「空间数 == 协作账本数」「成员数 == 协作成员数 + 协作账本数」。
-- ============================================================

do $mig$
declare
  rec        record;
  v_space_id text;
  v_now      bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_names    text[];
  v_uid      uuid;
  v_display  text;
  v_idx      int;
  v_created  int := 0;
begin
  for rec in
    select gc.group_id,
           gc.owner_user_id,
           gc.member_user_id,
           coalesce(nullif(g.name, ''), '共享账本') as group_name,
           g.created_ms as group_created_ms
      from public.group_collab gc
      left join public.groups_sync g on g.id = gc.group_id
     order by gc.group_id
  loop
    -- ① 幂等：该账本已有未删除空间则跳过
    select s.id into v_space_id
      from public.spaces_sync s
     where s.group_id = rec.group_id and s.deleted = false
     limit 1;
    if v_space_id is not null then
      continue;
    end if;
    v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');

    insert into public.spaces_sync
      (id, name, trip_id, group_id, created_by, note, status, created_ms, updated_ms, deleted)
    values
      (v_space_id, rec.group_name, null, rec.group_id, rec.owner_user_id,
       '由旧共享账本自动升级', 'active',
       coalesce(rec.group_created_ms, v_now), v_now, false)
    on conflict (id) do nothing;
    v_created := v_created + 1;

    -- ② 取该团成员名（按创建时间排序，用于按位次给 auth 用户命名）
    select coalesce(array_agg(m.name order by m.created_ms, m.id), '{}'::text[])
      into v_names
      from public.members_sync m
     where m.group_id = rec.group_id and m.deleted = false;

    -- ③ owner 成员行
    v_display := coalesce(nullif(v_names[1], ''), '旅伴');
    insert into public.space_members_sync
      (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
    values
      ('sm_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, rec.owner_user_id,
       'owner', v_display, coalesce(rec.group_created_ms, v_now),
       coalesce(rec.group_created_ms, v_now), v_now, false)
    on conflict (id) do nothing;

    -- ④ 受邀成员行（位次 2..n 对应 members_sync 第 2..n 个名字）
    v_idx := 1;
    if rec.member_user_id is not null then
      foreach v_uid in array rec.member_user_id loop
        if v_uid is null or v_uid = rec.owner_user_id then
          continue;
        end if;
        v_idx := v_idx + 1;
        v_display := coalesce(nullif(v_names[v_idx], ''), '旅伴');
        insert into public.space_members_sync
          (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
        values
          ('sm_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, v_uid,
           'editor', v_display, v_now, v_now, v_now, false)
        on conflict (id) do nothing;
      end loop;
    end if;

    -- ⑤ 升级动态（残档可追溯）
    insert into public.space_events_sync
      (id, space_id, actor_user, action, entity_kind, entity_id, summary,
       created_ms, updated_ms, deleted)
    values
      ('evt_' || replace(gen_random_uuid()::text, '-', ''), v_space_id, rec.owner_user_id,
       'space_created', 'space', v_space_id, rec.group_name || '（由共享账本升级）',
       v_now, v_now, false);
  end loop;

  raise notice 'migrate_spaces_v2662: 本次新建空间 % 个', v_created;
end;
$mig$;

-- 兜底：为「有协作成员行但空间成员缺失」的空间补齐（脚本中途失败后重跑可自愈）
do $fix$
declare
  rec       record;
  v_now     bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_uid     uuid;
  v_names   text[];
  v_display text;
  v_idx     int;
  v_rows    int := 0;
begin
  for rec in
    select s.id as space_id, s.created_by, s.group_id, gc.member_user_id
      from public.spaces_sync s
      left join public.group_collab gc on gc.group_id = s.group_id
     where s.deleted = false
  loop
    if rec.group_id is null then
      continue;
    end if;
    -- owner 行缺失 → 补
    if not exists (select 1 from public.space_members_sync sm
                    where sm.space_id = rec.space_id and sm.user_id = rec.created_by) then
      select coalesce(array_agg(m.name order by m.created_ms, m.id), '{}'::text[])
        into v_names
        from public.members_sync m
       where m.group_id = rec.group_id and m.deleted = false;
      insert into public.space_members_sync
        (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
      values
        ('sm_' || replace(gen_random_uuid()::text, '-', ''), rec.space_id, rec.created_by,
         'owner', coalesce(nullif(v_names[1], ''), '旅伴'), v_now, v_now, v_now, false);
      v_rows := v_rows + 1;
    end if;
    -- 受邀成员行缺失 → 补
    if rec.member_user_id is not null then
      v_idx := 1;
      foreach v_uid in array rec.member_user_id loop
        v_idx := v_idx + 1;
        if v_uid is null or v_uid = rec.created_by then
          continue;
        end if;
        if not exists (select 1 from public.space_members_sync sm
                        where sm.space_id = rec.space_id and sm.user_id = v_uid) then
          select coalesce(array_agg(m.name order by m.created_ms, m.id), '{}'::text[])
            into v_names
            from public.members_sync m
           where m.group_id = rec.group_id and m.deleted = false;
          v_display := coalesce(nullif(v_names[v_idx], ''), '旅伴');
          insert into public.space_members_sync
            (id, space_id, user_id, role, display_name, joined_ms, created_ms, updated_ms, deleted)
          values
            ('sm_' || replace(gen_random_uuid()::text, '-', ''), rec.space_id, v_uid,
             'editor', v_display, v_now, v_now, v_now, false);
          v_rows := v_rows + 1;
        end if;
      end loop;
    end if;
  end loop;
  raise notice 'migrate_spaces_v2662: 兜底补齐成员行 % 条', v_rows;
end;
$fix$;

-- 同步老账本的聚合角色列（存在 editor/owner 成员 → 'member'；全 viewer → 'viewer'）
update public.group_collab gc
   set "role" = coalesce(sub.r, 'member')
  from (
    select s.group_id,
           case when bool_or(sm.role in ('owner','editor')) then 'member' else 'viewer' end as r
      from public.spaces_sync s
      join public.space_members_sync sm on sm.space_id = s.id and sm.deleted = false
     where s.deleted = false and s.group_id is not null
     group by s.group_id
  ) sub
 where gc.group_id = sub.group_id;

-- ============================================================
-- 对账校验（执行后请看结果集，两项必须相等）
-- ============================================================
-- 校验 1：空间数 vs 协作账本数
select
  (select count(*) from public.spaces_sync where deleted = false)                as "空间数",
  (select count(distinct gc.group_id) from public.group_collab gc)               as "协作账本数",
  (select count(*) from public.spaces_sync
    where deleted = false and group_id is not null)                              as "关联账本的空间数";

-- 校验 2：空间成员数 vs （协作账本 owner + 协作受邀成员）
select
  (select count(*) from public.space_members_sync where deleted = false)         as "空间成员行数",
  (select count(*) from public.group_collab)                                     as "协作账本数",
  (select coalesce(sum(coalesce(array_length(gc.member_user_id, 1), 0)), 0)
     from public.group_collab gc)                                                as "受邀成员总数",
  (select count(*) from public.group_collab)
    + (select coalesce(sum(coalesce(array_length(gc.member_user_id, 1), 0)), 0)
         from public.group_collab gc)
    - (select coalesce(sum(case when gc.owner_user_id = any(gc.member_user_id)
                                then 1 else 0 end), 0)
         from public.group_collab gc)                                            as "期望成员行数";

-- 校验 3：每个空间至少一个 owner 成员（结果应为空）
select s.id as "缺 owner 的空间", s.name
  from public.spaces_sync s
 where s.deleted = false
   and not exists (select 1 from public.space_members_sync sm
                    where sm.space_id = s.id and sm.deleted = false and sm.role = 'owner');

-- 校验 4：有 group_collab 却没生成空间的账本（结果应为空）
select gc.group_id as "未升级账本"
  from public.group_collab gc
 where not exists (select 1 from public.spaces_sync s
                    where s.group_id = gc.group_id and s.deleted = false);
