-- Combined one-paste setup: run this whole file once in the Supabase SQL Editor.
-- OpenThings remote schema, mirroring the local drift model.
-- Every row is owned by a user; RLS restricts access to the owner.

create table public.areas (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  order_index double precision not null default 0,
  created_at timestamptz not null,
  modified_at timestamptz not null
);

create table public.tasks (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  type smallint not null,                -- 0 todo, 1 project, 2 heading
  title text not null default '',
  notes text not null default '',
  status smallint not null,              -- 0 open, 1 completed, 2 cancelled
  start_bucket smallint not null,        -- 0 inbox, 1 anytime, 2 someday
  start_date date,
  is_evening boolean not null default false,
  deadline date,
  reminder_minutes integer,
  area_id uuid,
  project_id uuid,
  heading_id uuid,
  order_index double precision not null default 0,
  today_index double precision not null default 0,
  repeat_mode smallint not null default 0,
  repeat_every_n integer not null default 1,
  repeat_unit smallint not null default 0,
  is_repeat_template boolean not null default false,
  repeater_template_id uuid,
  next_instance_date date,
  completion_date timestamptz,
  trashed_at timestamptz,
  created_at timestamptz not null,
  modified_at timestamptz not null
);

create table public.checklist_items (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null,
  title text not null default '',
  done boolean not null default false,
  order_index double precision not null default 0,
  created_at timestamptz not null,
  modified_at timestamptz not null
);

create table public.tags (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  parent_tag_id uuid,
  order_index double precision not null default 0,
  created_at timestamptz not null,
  modified_at timestamptz not null
);

create table public.task_tags (
  task_id uuid not null,
  tag_id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  modified_at timestamptz not null,
  primary key (task_id, tag_id)
);

-- Tombstones so hard deletes (empty trash, checklist/tag removal)
-- propagate across devices.
create table public.deletions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entity text not null,                  -- 'task' | 'area' | ...
  entity_id uuid not null,
  deleted_at timestamptz not null default now()
);

-- Sync watermark queries filter on modified_at per user.
create index tasks_user_modified on public.tasks (user_id, modified_at);
create index areas_user_modified on public.areas (user_id, modified_at);
create index checklist_user_modified
  on public.checklist_items (user_id, modified_at);
create index tags_user_modified on public.tags (user_id, modified_at);
create index deletions_user_time on public.deletions (user_id, deleted_at);

-- Row-level security: owner-only access.
alter table public.areas enable row level security;
alter table public.tasks enable row level security;
alter table public.checklist_items enable row level security;
alter table public.tags enable row level security;
alter table public.task_tags enable row level security;
alter table public.deletions enable row level security;

create policy "own areas" on public.areas
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own tasks" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own checklist" on public.checklist_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own tags" on public.tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own task_tags" on public.task_tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own deletions" on public.deletions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- Self-service account deletion (required by App Store for apps with
-- account creation). The security-definer function deletes the calling
-- user's auth row; all app data cascades via the user_id foreign keys.

create or replace function public.delete_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

-- Only authenticated users may call it (and only affect themselves).
revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
-- Enable Supabase Realtime for the synced tables so an already-open
-- device is notified the instant another device changes data. Without
-- this, cross-device updates only arrive on the next fallback poll.

alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.areas;
alter publication supabase_realtime add table public.checklist_items;
alter publication supabase_realtime add table public.tags;
