-- ============================================================
-- 芥舟 V2.8.1 云端增量脚本（幂等，可重复执行）
--
-- 施工依据：docs/V2.8/芥舟V2.8.1版提示词工程.md
--   §十一 S8.1 数据契约（SubBudgets 全量同步登记）
--
-- 内容：
--   1) 新表：sub_budgets_sync（分类子预算，团级；+ 索引）
--   2) RLS：克隆 funds_sync 现行策略范式（_group_role），仅替换表名
--   3) 对账查询（列名核对 + 空值核对 + 行数核对 + 新表存在性核对）
--
-- 口径：子预算独立于总预算（groups.budget_cents），不计入总预算口径；
--       category_key 为内置 key 或自定义分类 id（弱关联，不建外键）。
-- ⚠️ 本脚本不修改任何既有 RLS 策略语义（仅新增，不放宽）。
-- ============================================================

-- ============================================================
-- 1. 新表：分类子预算（团队账本级）
-- ============================================================

create table if not exists public.sub_budgets_sync (
  id            text primary key,
  owner_user_id uuid not null default auth.uid(),
  group_id      text not null,
  category_key  text not null default '',
  amount        bigint not null, -- int 分
  created_ms    bigint not null,
  updated_ms    bigint not null,
  deleted       boolean not null default false,
  server_updated timestamptz not null default now()
);
create index if not exists idx_sub_budgets_sync_group on public.sub_budgets_sync(group_id);
create index if not exists idx_sub_budgets_sync_category on public.sub_budgets_sync(group_id, category_key);

-- 兼容已执行过旧版/部分版脚本的数据库（补齐可能缺失的列）
alter table public.sub_budgets_sync add column if not exists category_key text not null default '';
alter table public.sub_budgets_sync add column if not exists deleted boolean not null default false;
alter table public.sub_budgets_sync add column if not exists server_updated timestamptz not null default now();
update public.sub_budgets_sync set deleted = false where deleted is null;
update public.sub_budgets_sync set category_key = '' where category_key is null;

-- ============================================================
-- 2. RLS（克隆 funds_sync 范式；仅新增策略，不改既有语义）
-- ============================================================

alter table public.sub_budgets_sync enable row level security;

drop policy if exists "sub_budgets_sync_select" on public.sub_budgets_sync;
drop policy if exists "sub_budgets_sync_insert" on public.sub_budgets_sync;
drop policy if exists "sub_budgets_sync_update" on public.sub_budgets_sync;
drop policy if exists "sub_budgets_sync_delete" on public.sub_budgets_sync;
create policy "sub_budgets_sync_select" on public.sub_budgets_sync for select
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) is not null);
create policy "sub_budgets_sync_insert" on public.sub_budgets_sync for insert
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "sub_budgets_sync_update" on public.sub_budgets_sync for update
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'))
  with check (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));
create policy "sub_budgets_sync_delete" on public.sub_budgets_sync for delete
  using (auth.uid() = owner_user_id
         or public._group_role(group_id, auth.uid()) in ('owner', 'member'));

-- ============================================================
-- 3. 对账查询（人工执行核对，预期全部非零/一致）
-- ============================================================

-- 3.1 列集核对（预期 9 列：id/owner_user_id/group_id/category_key/amount/created_ms/updated_ms/deleted/server_updated）
-- select column_name, data_type from information_schema.columns
--  where table_schema = 'public' and table_name = 'sub_budgets_sync' order by ordinal_position;

-- 3.2 空值核对（预期 0 行）
-- select count(*) from public.sub_budgets_sync where amount is null or category_key is null;

-- 3.3 行数核对（与 app 端 sub_budgets 本地行数一致）
-- select count(*) from public.sub_budgets_sync;

-- 3.4 新表存在性核对（预期 t）
-- select to_regclass('public.sub_budgets_sync') is not null as exists_;
