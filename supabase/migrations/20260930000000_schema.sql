-- Rank Tracker: osnovna šema (SPEC §4).
--
-- Konvencije:
--   * svaka tabela ima id uuid, created_at i workspace_id (osim workspaces),
--   * podređene tabele referenciraju roditelja preko (id, workspace_id), pa baza
--     sama garantuje da red ne može da pokazuje na podatke drugog workspace-a,
--   * RLS politike su u sledećoj migraciji.

-- ---------------------------------------------------------------------------
-- workspaces
-- ---------------------------------------------------------------------------
create table public.workspaces (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name       text not null check (length(trim(name)) > 0)
);

-- ---------------------------------------------------------------------------
-- workspace_members
-- ---------------------------------------------------------------------------
create table public.workspace_members (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  role         text not null default 'member' check (role in ('admin', 'member')),
  unique (workspace_id, user_id)
);

create index workspace_members_user_id_idx on public.workspace_members (user_id);

-- ---------------------------------------------------------------------------
-- projects
-- ---------------------------------------------------------------------------
create table public.projects (
  id                  uuid primary key default gen_random_uuid(),
  created_at          timestamptz not null default now(),
  workspace_id        uuid not null references public.workspaces (id) on delete cascade,
  name                text not null check (length(trim(name)) > 0),
  -- bez protokola, www i putanje, npr. "biokanna.rs"
  domain              text not null check (
                        domain = lower(domain) and domain !~ '[/:?#[:space:]]'
                        and domain !~ '^www\.' and length(domain) > 0),
  match_mode          text not null default 'domain'
                        check (match_mode in ('domain', 'exact_domain', 'url_prefix')),
  location_code       int  not null,
  language_code       text not null,
  device              text not null default 'desktop' check (device in ('desktop', 'mobile')),
  check_interval_days int  not null default 3 check (check_interval_days between 1 and 365),
  is_active           boolean not null default true,
  seranking_site_id   bigint,
  unique (id, workspace_id),
  unique (workspace_id, seranking_site_id)
);

create index projects_workspace_id_idx on public.projects (workspace_id);

-- ---------------------------------------------------------------------------
-- keyword_groups
-- ---------------------------------------------------------------------------
create table public.keyword_groups (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  workspace_id       uuid not null references public.workspaces (id) on delete cascade,
  project_id         uuid not null,
  name               text not null check (length(trim(name)) > 0),
  seranking_group_id bigint,
  foreign key (project_id, workspace_id)
    references public.projects (id, workspace_id) on delete cascade,
  unique (id, project_id),
  unique (project_id, name),
  unique (project_id, seranking_group_id)
);

create index keyword_groups_workspace_id_idx on public.keyword_groups (workspace_id);

-- ---------------------------------------------------------------------------
-- keywords
-- ---------------------------------------------------------------------------
create table public.keywords (
  id                   uuid primary key default gen_random_uuid(),
  created_at           timestamptz not null default now(),
  workspace_id         uuid not null references public.workspaces (id) on delete cascade,
  project_id           uuid not null,
  group_id             uuid,
  keyword              text not null check (length(trim(keyword)) > 0),
  target_url           text,
  depth_override       int check (depth_override between 1 and 700),
  is_active            boolean not null default true,
  next_check_on        date not null default current_date,
  seranking_keyword_id bigint,
  foreign key (project_id, workspace_id)
    references public.projects (id, workspace_id) on delete cascade,
  -- grupa mora pripadati istom projektu; brisanje grupe samo odvaja reč
  foreign key (group_id, project_id)
    references public.keyword_groups (id, project_id) on delete set null (group_id),
  unique (id, workspace_id),
  unique (project_id, keyword),
  unique (project_id, seranking_keyword_id)
);

create index keywords_workspace_id_idx on public.keywords (workspace_id);
create index keywords_group_id_idx on public.keywords (group_id);
-- planer: aktivne reči kojima je provera na redu
create index keywords_due_idx on public.keywords (next_check_on) where is_active;

-- ---------------------------------------------------------------------------
-- positions
-- ---------------------------------------------------------------------------
create table public.positions (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  workspace_id   uuid not null references public.workspaces (id) on delete cascade,
  keyword_id     uuid not null,
  checked_on     date not null,
  -- 0 = nije pronađen do depth_checked; null = provera nije uspela
  position       int check (position >= 0),
  ranking_url    text,
  matches_target boolean,
  depth_checked  int not null check (depth_checked > 0),
  source         text not null check (source in ('dataforseo', 'seranking_import', 'manual')),
  cost_usd       numeric(10, 5) not null default 0 check (cost_usd >= 0),
  foreign key (keyword_id, workspace_id)
    references public.keywords (id, workspace_id) on delete cascade
);

-- unique(keyword_id, checked_on) + index(keyword_id, checked_on desc) u jednom indeksu
create unique index positions_keyword_id_checked_on_key
  on public.positions (keyword_id, checked_on desc);
create index positions_workspace_id_idx on public.positions (workspace_id);

-- ---------------------------------------------------------------------------
-- serp_snapshots
-- ---------------------------------------------------------------------------
create table public.serp_snapshots (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  keyword_id   uuid not null,
  checked_on   date not null,
  -- [{rank, domain, url, title}], prvih 10 organskih
  results      jsonb not null default '[]'::jsonb check (jsonb_typeof(results) = 'array'),
  foreign key (keyword_id, workspace_id)
    references public.keywords (id, workspace_id) on delete cascade,
  unique (keyword_id, checked_on)
);

create index serp_snapshots_workspace_id_idx on public.serp_snapshots (workspace_id);

-- ---------------------------------------------------------------------------
-- check_runs
-- ---------------------------------------------------------------------------
create table public.check_runs (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  status       text not null default 'running' check (status in ('running', 'done', 'failed')),
  provider     text not null,
  tasks_total  int not null default 0 check (tasks_total >= 0),
  tasks_failed int not null default 0 check (tasks_failed >= 0),
  cost_usd     numeric(10, 4) not null default 0 check (cost_usd >= 0),
  unique (id, workspace_id)
);

create index check_runs_workspace_id_started_at_idx
  on public.check_runs (workspace_id, started_at desc);

-- ---------------------------------------------------------------------------
-- serp_tasks
-- ---------------------------------------------------------------------------
create table public.serp_tasks (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  workspace_id     uuid not null references public.workspaces (id) on delete cascade,
  run_id           uuid not null,
  keyword_id       uuid not null,
  provider_task_id text,
  depth            int not null check (depth > 0),
  status           text not null default 'posted' check (status in ('posted', 'done', 'failed')),
  attempts         int not null default 0 check (attempts between 0 and 3),
  cost_usd         numeric(10, 5) not null default 0 check (cost_usd >= 0),
  error            text,
  foreign key (run_id, workspace_id)
    references public.check_runs (id, workspace_id) on delete cascade,
  foreign key (keyword_id, workspace_id)
    references public.keywords (id, workspace_id) on delete cascade
);

create index serp_tasks_run_id_idx on public.serp_tasks (run_id);
create index serp_tasks_keyword_id_idx on public.serp_tasks (keyword_id);
create index serp_tasks_workspace_id_idx on public.serp_tasks (workspace_id);
create unique index serp_tasks_provider_task_id_key
  on public.serp_tasks (provider_task_id) where provider_task_id is not null;
create index serp_tasks_open_idx on public.serp_tasks (status) where status = 'posted';
