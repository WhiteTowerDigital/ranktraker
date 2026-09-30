-- Rank Tracker: Row Level Security (SPEC §4 RLS).
--
-- Korisnik vidi i menja samo redove čiji je workspace_id u workspace_members
-- za auth.uid(). Brisanje projekata i upravljanje članovima samo za admin.
-- check_runs i serp_tasks piše samo worker (service role, zaobilazi RLS);
-- članovi ih samo čitaju, da bi evidencija troška ostala verodostojna.

-- ---------------------------------------------------------------------------
-- Pomoćne funkcije (šema private nije izložena preko Supabase API-ja)
-- ---------------------------------------------------------------------------
create schema if not exists private;
grant usage on schema private to authenticated;

-- security definer: čita workspace_members bez RLS-a, pa politika na samoj
-- workspace_members tabeli ne ulazi u rekurziju.
create function private.user_workspace_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.workspace_id
  from public.workspace_members m
  where m.user_id = (select auth.uid())
$$;

create function private.user_admin_workspace_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.workspace_id
  from public.workspace_members m
  where m.user_id = (select auth.uid())
    and m.role = 'admin'
$$;

revoke all on function private.user_workspace_ids() from public;
revoke all on function private.user_admin_workspace_ids() from public;
grant execute on function private.user_workspace_ids() to authenticated;
grant execute on function private.user_admin_workspace_ids() to authenticated;

-- ---------------------------------------------------------------------------
-- Privilegije: anon nema pristup ničemu, TRUNCATE zaobilazi RLS pa ga
-- oduzimamo svima osim service role-a.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
revoke insert, update, delete on public.check_runs, public.serp_tasks from authenticated;

-- ---------------------------------------------------------------------------
-- Uključi RLS na svim tabelama
-- ---------------------------------------------------------------------------
alter table public.workspaces        enable row level security;
alter table public.workspace_members enable row level security;
alter table public.projects          enable row level security;
alter table public.keyword_groups    enable row level security;
alter table public.keywords          enable row level security;
alter table public.positions         enable row level security;
alter table public.serp_snapshots    enable row level security;
alter table public.check_runs        enable row level security;
alter table public.serp_tasks        enable row level security;

-- ---------------------------------------------------------------------------
-- workspaces: članovi čitaju, admin menja naziv. Nove workspace-e pravi
-- samo service role (registracija dolazi tek u SaaS fazi).
-- ---------------------------------------------------------------------------
create policy workspaces_select on public.workspaces
  for select to authenticated
  using (id in (select private.user_workspace_ids()));

create policy workspaces_update on public.workspaces
  for update to authenticated
  using (id in (select private.user_admin_workspace_ids()))
  with check (id in (select private.user_admin_workspace_ids()));

-- ---------------------------------------------------------------------------
-- workspace_members: članovi vide tim, samo admin upravlja članstvom.
-- ---------------------------------------------------------------------------
create policy workspace_members_select on public.workspace_members
  for select to authenticated
  using (workspace_id in (select private.user_workspace_ids()));

create policy workspace_members_insert on public.workspace_members
  for insert to authenticated
  with check (workspace_id in (select private.user_admin_workspace_ids()));

create policy workspace_members_update on public.workspace_members
  for update to authenticated
  using (workspace_id in (select private.user_admin_workspace_ids()))
  with check (workspace_id in (select private.user_admin_workspace_ids()));

create policy workspace_members_delete on public.workspace_members
  for delete to authenticated
  using (workspace_id in (select private.user_admin_workspace_ids()));

-- Workspace ne sme ostati bez admina (npr. admin sebi slučajno ukloni ulogu).
create function private.ensure_workspace_has_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin'
     and exists (select 1 from public.workspaces w where w.id = old.workspace_id)
     and not exists (
       select 1 from public.workspace_members m
       where m.workspace_id = old.workspace_id and m.role = 'admin'
     )
  then
    raise exception 'Workspace mora imati bar jednog admina'
      using errcode = 'check_violation';
  end if;
  return null;
end;
$$;

create trigger workspace_members_keep_admin
  after update or delete on public.workspace_members
  for each row execute function private.ensure_workspace_has_admin();

-- ---------------------------------------------------------------------------
-- projects: članovi čitaju, dodaju i menjaju; briše samo admin.
-- ---------------------------------------------------------------------------
create policy projects_select on public.projects
  for select to authenticated
  using (workspace_id in (select private.user_workspace_ids()));

create policy projects_insert on public.projects
  for insert to authenticated
  with check (workspace_id in (select private.user_workspace_ids()));

create policy projects_update on public.projects
  for update to authenticated
  using (workspace_id in (select private.user_workspace_ids()))
  with check (workspace_id in (select private.user_workspace_ids()));

create policy projects_delete on public.projects
  for delete to authenticated
  using (workspace_id in (select private.user_admin_workspace_ids()));

-- ---------------------------------------------------------------------------
-- keyword_groups, keywords, positions, serp_snapshots: pun pristup članovima.
-- ---------------------------------------------------------------------------
create policy keyword_groups_member on public.keyword_groups
  for all to authenticated
  using (workspace_id in (select private.user_workspace_ids()))
  with check (workspace_id in (select private.user_workspace_ids()));

create policy keywords_member on public.keywords
  for all to authenticated
  using (workspace_id in (select private.user_workspace_ids()))
  with check (workspace_id in (select private.user_workspace_ids()));

create policy positions_member on public.positions
  for all to authenticated
  using (workspace_id in (select private.user_workspace_ids()))
  with check (workspace_id in (select private.user_workspace_ids()));

create policy serp_snapshots_member on public.serp_snapshots
  for all to authenticated
  using (workspace_id in (select private.user_workspace_ids()))
  with check (workspace_id in (select private.user_workspace_ids()));

-- ---------------------------------------------------------------------------
-- check_runs, serp_tasks: članovi samo čitaju (piše worker).
-- ---------------------------------------------------------------------------
create policy check_runs_select on public.check_runs
  for select to authenticated
  using (workspace_id in (select private.user_workspace_ids()));

create policy serp_tasks_select on public.serp_tasks
  for select to authenticated
  using (workspace_id in (select private.user_workspace_ids()));
