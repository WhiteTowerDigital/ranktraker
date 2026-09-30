-- RLS testovi (SPEC §4 RLS, kriterijum F0: korisnik van workspace-a ne vidi ništa).
--
-- Pokretanje: scripts/test-db.sh (ili psql "$DATABASE_URL" -f supabase/tests/rls.test.sql
-- na bazi gde su migracije već primenjene, npr. lokalni Supabase).
-- Sve se izvršava u jednoj transakciji koja se na kraju poništava (ROLLBACK),
-- pa test ne ostavlja tragove ni na lokalnoj Supabase bazi.

\set ON_ERROR_STOP on
\set QUIET on
\o /dev/null
set client_min_messages = notice;

begin;

-- ---------------------------------------------------------------------------
-- Pomoćne funkcije
-- ---------------------------------------------------------------------------
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;

create function tests.ok(cond boolean, msg text) returns void
language plpgsql as $$
begin
  if cond is not true then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'ok - %', msg;
end $$;

-- Prijava kao korisnik (kao što PostgREST radi za zahtev sa JWT-om).
create function tests.login(user_id uuid) returns void
language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
end $$;

create function tests.login_anon() returns void
language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;

create function tests.login_service() returns void
language plpgsql as $$
begin
  perform set_config('role', 'service_role', true);
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
end $$;

-- Broj vidljivih redova koji pripadaju / ne pripadaju datom workspace-u.
create function tests.visible(tbl text, ws uuid, out own bigint, out foreign_rows bigint)
language plpgsql as $$
declare
  col text := case when tbl = 'workspaces' then 'id' else 'workspace_id' end;
begin
  execute format(
    'select count(*) filter (where %1$I = $1), count(*) filter (where %1$I is distinct from $1)
     from public.%2$I', col, tbl)
  into own, foreign_rows using ws;
end $$;

-- Očekuje da SQL baci grešku sa datim SQLSTATE kodom.
create function tests.throws(query text, errcode text, msg text) returns void
language plpgsql as $$
begin
  begin
    execute query;
  exception when others then
    if sqlstate = errcode then
      raise notice 'ok - % (%)', msg, sqlstate;
      return;
    end if;
    raise exception 'FAIL: % — očekivan %, dobijen %: %', msg, errcode, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL: % — očekivana greška %, a upit je prošao', msg, errcode;
end $$;

-- Očekuje da SQL (insert/update/delete) promeni tačno n redova.
create function tests.affects(query text, n int, msg text) returns void
language plpgsql as $$
declare
  cnt int;
begin
  execute query;
  get diagnostics cnt = row_count;
  if cnt <> n then
    raise exception 'FAIL: % — očekivano % redova, promenjeno %', msg, n, cnt;
  end if;
  raise notice 'ok - % (% redova)', msg, cnt;
end $$;

grant execute on all functions in schema tests to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Podaci: workspace A (alice admin, bob member), workspace B (carol admin),
-- dave nije ni u jednom workspace-u.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('a1000000-0000-4000-8000-000000000001', 'alice@rls-test.local'),
  ('b0b00000-0000-4000-8000-000000000001', 'bob@rls-test.local'),
  ('ca000000-0000-4000-8000-000000000001', 'carol@rls-test.local'),
  ('da000000-0000-4000-8000-000000000001', 'dave@rls-test.local');

insert into public.workspaces (id, name) values
  ('aaaaaaaa-0000-4000-8000-000000000000', 'RLS test A'),
  ('bbbbbbbb-0000-4000-8000-000000000000', 'RLS test B');

insert into public.workspace_members (workspace_id, user_id, role) values
  ('aaaaaaaa-0000-4000-8000-000000000000', 'a1000000-0000-4000-8000-000000000001', 'admin'),
  ('aaaaaaaa-0000-4000-8000-000000000000', 'b0b00000-0000-4000-8000-000000000001', 'member'),
  ('bbbbbbbb-0000-4000-8000-000000000000', 'ca000000-0000-4000-8000-000000000001', 'admin');

insert into public.projects (id, workspace_id, name, domain, location_code, language_code) values
  ('aaaaaaaa-0000-4000-8000-00000000000a', 'aaaaaaaa-0000-4000-8000-000000000000', 'A projekat', 'a-test.rs', 2688, 'sr'),
  ('bbbbbbbb-0000-4000-8000-00000000000b', 'bbbbbbbb-0000-4000-8000-000000000000', 'B projekat', 'b-test.rs', 2688, 'sr');

insert into public.keyword_groups (id, workspace_id, project_id, name) values
  ('aaaaaaaa-0000-4000-8000-0000000000a1', 'aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a', 'A grupa'),
  ('bbbbbbbb-0000-4000-8000-0000000000b1', 'bbbbbbbb-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-00000000000b', 'B grupa');

insert into public.keywords (id, workspace_id, project_id, group_id, keyword) values
  ('aaaaaaaa-0000-4000-8000-0000000000a2', 'aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a', 'aaaaaaaa-0000-4000-8000-0000000000a1', 'a reč 1'),
  ('aaaaaaaa-0000-4000-8000-0000000000a3', 'aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a', null, 'a reč 2'),
  ('bbbbbbbb-0000-4000-8000-0000000000b2', 'bbbbbbbb-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-00000000000b', 'bbbbbbbb-0000-4000-8000-0000000000b1', 'b reč 1');

insert into public.positions (workspace_id, keyword_id, checked_on, position, depth_checked, source, cost_usd) values
  ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-0000000000a2', '2026-09-01', 4, 30, 'dataforseo', 0.0006),
  ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-0000000000a3', '2026-09-01', 0, 100, 'seranking_import', 0),
  ('bbbbbbbb-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-0000000000b2', '2026-09-01', 7, 30, 'dataforseo', 0.0006);

insert into public.serp_snapshots (workspace_id, keyword_id, checked_on, results) values
  ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-0000000000a2', '2026-09-01', '[{"rank":1,"domain":"x.rs","url":"https://x.rs/","title":"X"}]'),
  ('bbbbbbbb-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-0000000000b2', '2026-09-01', '[]');

insert into public.check_runs (id, workspace_id, provider, status, tasks_total, cost_usd) values
  ('aaaaaaaa-0000-4000-8000-0000000000a4', 'aaaaaaaa-0000-4000-8000-000000000000', 'dataforseo', 'done', 1, 0.0006),
  ('bbbbbbbb-0000-4000-8000-0000000000b4', 'bbbbbbbb-0000-4000-8000-000000000000', 'dataforseo', 'done', 1, 0.0006);

insert into public.serp_tasks (workspace_id, run_id, keyword_id, provider_task_id, depth, status, cost_usd) values
  ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-0000000000a4', 'aaaaaaaa-0000-4000-8000-0000000000a2', 'rls-test-task-a', 30, 'done', 0.0006),
  ('bbbbbbbb-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-0000000000b4', 'bbbbbbbb-0000-4000-8000-0000000000b2', 'rls-test-task-b', 30, 'done', 0.0006);

-- Tabele i očekivan broj redova po workspace-u.
create table tests.expected (tbl text primary key, a int not null, b int not null);
insert into tests.expected values
  ('workspaces', 1, 1),
  ('workspace_members', 2, 1),
  ('projects', 1, 1),
  ('keyword_groups', 1, 1),
  ('keywords', 2, 1),
  ('positions', 2, 1),
  ('serp_snapshots', 1, 1),
  ('check_runs', 1, 1),
  ('serp_tasks', 1, 1);
grant select on tests.expected to anon, authenticated, service_role;

-- Svaka tabela u public mora imati uključen RLS i biti pokrivena testom.
do $$
declare r record;
begin
  for r in
    select c.relname, c.relrowsecurity
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    perform tests.ok(r.relrowsecurity, format('RLS uključen na public.%s', r.relname));
    perform tests.ok(exists (select 1 from tests.expected e where e.tbl = r.relname),
      format('public.%s je pokrivena RLS testom', r.relname));
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Korisnik van workspace-a (dave) ne vidi ništa
-- ---------------------------------------------------------------------------
select tests.login('da000000-0000-4000-8000-000000000001');
do $$
declare r record; n bigint;
begin
  for r in select tbl from tests.expected loop
    execute format('select count(*) from public.%I', r.tbl) into n;
    perform tests.ok(n = 0, format('dave (bez workspace-a) vidi 0 redova u %s', r.tbl));
  end loop;
end $$;
select tests.throws(
  $q$insert into public.projects (workspace_id, name, domain, location_code, language_code)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'x', 'x.rs', 2688, 'sr')$q$,
  '42501', 'dave ne može da doda projekat u tuđi workspace');
select tests.throws(
  $q$insert into public.workspace_members (workspace_id, user_id, role)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'da000000-0000-4000-8000-000000000001', 'admin')$q$,
  '42501', 'dave ne može sam sebe da doda u workspace');
select tests.throws(
  $q$insert into public.workspaces (name) values ('Dave workspace')$q$,
  '42501', 'dave ne može da napravi workspace');
reset role;

-- Prijavljen zahtev bez sub claim-a takođe ne vidi ništa.
select set_config('role', 'authenticated', true);
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
do $$
declare r record; n bigint;
begin
  for r in select tbl from tests.expected loop
    execute format('select count(*) from public.%I', r.tbl) into n;
    perform tests.ok(n = 0, format('authenticated bez sub-a vidi 0 redova u %s', r.tbl));
  end loop;
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 2. anon nema nikakav pristup
-- ---------------------------------------------------------------------------
select tests.login_anon();
do $$
declare r record;
begin
  for r in select tbl from tests.expected loop
    perform tests.throws(format('select 1 from public.%I', r.tbl), '42501',
      format('anon nema pristup tabeli %s', r.tbl));
  end loop;
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 3. Članovi vide samo svoj workspace
-- ---------------------------------------------------------------------------
select tests.login('ca000000-0000-4000-8000-000000000001');
do $$
declare r record; v record;
begin
  for r in select * from tests.expected loop
    v := tests.visible(r.tbl, 'bbbbbbbb-0000-4000-8000-000000000000');
    perform tests.ok(v.own = r.b and v.foreign_rows = 0,
      format('carol (B) vidi %s/%s svojih i 0 tuđih redova u %s (vidi %s tuđih)',
        v.own, r.b, r.tbl, v.foreign_rows));
  end loop;
end $$;
reset role;

select tests.login('b0b00000-0000-4000-8000-000000000001');
do $$
declare r record; v record;
begin
  for r in select * from tests.expected loop
    v := tests.visible(r.tbl, 'aaaaaaaa-0000-4000-8000-000000000000');
    perform tests.ok(v.own = r.a and v.foreign_rows = 0,
      format('bob (A) vidi %s/%s svojih i 0 tuđih redova u %s (vidi %s tuđih)',
        v.own, r.a, r.tbl, v.foreign_rows));
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Član (bob) menja podatke svog workspace-a, ali ne i tuđe
-- ---------------------------------------------------------------------------
select tests.affects(
  $q$insert into public.keywords (workspace_id, project_id, keyword)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a', 'nova reč')$q$,
  1, 'bob dodaje reč u svoj projekat');
select tests.affects(
  $q$update public.keywords set is_active = false
     where id = 'aaaaaaaa-0000-4000-8000-0000000000a3'$q$,
  1, 'bob menja reč u svom projektu');
select tests.affects(
  $q$insert into public.positions (workspace_id, keyword_id, checked_on, position, depth_checked, source)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-0000000000a2', '2026-09-04', 3, 30, 'manual')$q$,
  1, 'bob ručno upisuje poziciju');

select tests.throws(
  $q$insert into public.projects (workspace_id, name, domain, location_code, language_code)
     values ('bbbbbbbb-0000-4000-8000-000000000000', 'x', 'x.rs', 2688, 'sr')$q$,
  '42501', 'bob ne može da doda projekat u workspace B');
select tests.throws(
  $q$insert into public.keywords (workspace_id, project_id, keyword)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-00000000000b', 'podmetnuta reč')$q$,
  '23503', 'bob ne može da veže reč za projekat iz workspace-a B');
select tests.throws(
  $q$insert into public.keywords (workspace_id, project_id, group_id, keyword)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'aaaaaaaa-0000-4000-8000-00000000000a',
             'bbbbbbbb-0000-4000-8000-0000000000b1', 'reč u tuđoj grupi')$q$,
  '23503', 'bob ne može da stavi reč u grupu iz workspace-a B');
select tests.throws(
  $q$update public.keywords set workspace_id = 'bbbbbbbb-0000-4000-8000-000000000000'
     where id = 'aaaaaaaa-0000-4000-8000-0000000000a2'$q$,
  '42501', 'bob ne može da prebaci reč u workspace B');
select tests.affects(
  $q$update public.keywords set keyword = 'hakovano' where id = 'bbbbbbbb-0000-4000-8000-0000000000b2'$q$,
  0, 'bob ne može da menja reč iz workspace-a B');
select tests.affects(
  $q$delete from public.positions where workspace_id = 'bbbbbbbb-0000-4000-8000-000000000000'$q$,
  0, 'bob ne može da briše pozicije iz workspace-a B');
select tests.affects(
  $q$update public.workspaces set name = 'x' where id = 'bbbbbbbb-0000-4000-8000-000000000000'$q$,
  0, 'bob ne može da menja workspace B');

-- Samo admin: brisanje projekata i upravljanje članovima.
select tests.affects(
  $q$delete from public.projects where id = 'aaaaaaaa-0000-4000-8000-00000000000a'$q$,
  0, 'bob (member) ne može da obriše projekat');
select tests.throws(
  $q$insert into public.workspace_members (workspace_id, user_id, role)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'da000000-0000-4000-8000-000000000001', 'member')$q$,
  '42501', 'bob (member) ne može da doda člana');
select tests.affects(
  $q$update public.workspace_members set role = 'admin'
     where user_id = 'b0b00000-0000-4000-8000-000000000001'$q$,
  0, 'bob (member) ne može sebi da dodeli admin ulogu');
select tests.affects(
  $q$update public.workspaces set name = 'x' where id = 'aaaaaaaa-0000-4000-8000-000000000000'$q$,
  0, 'bob (member) ne može da preimenuje workspace');

-- Evidencija provera i troška: samo čitanje.
select tests.throws(
  $q$insert into public.check_runs (workspace_id, provider) values ('aaaaaaaa-0000-4000-8000-000000000000', 'dataforseo')$q$,
  '42501', 'bob ne može da upisuje check_runs');
select tests.throws(
  $q$update public.serp_tasks set cost_usd = 0$q$,
  '42501', 'bob ne može da menja trošak u serp_tasks');
select tests.throws(
  $q$truncate public.positions$q$,
  '42501', 'bob ne može TRUNCATE (zaobišao bi RLS)');
reset role;

-- ---------------------------------------------------------------------------
-- 5. Admin (alice) upravlja članovima i briše projekte svog workspace-a
-- ---------------------------------------------------------------------------
select tests.login('a1000000-0000-4000-8000-000000000001');
select tests.affects(
  $q$insert into public.workspace_members (workspace_id, user_id, role)
     values ('aaaaaaaa-0000-4000-8000-000000000000', 'da000000-0000-4000-8000-000000000001', 'member')$q$,
  1, 'alice (admin) dodaje dave-a u workspace A');
reset role;

select tests.login('da000000-0000-4000-8000-000000000001');
do $$
declare v record;
begin
  v := tests.visible('keywords', 'aaaaaaaa-0000-4000-8000-000000000000');
  perform tests.ok(v.own > 0 and v.foreign_rows = 0, 'dave posle dodavanja vidi reči workspace-a A i ništa van njega');
end $$;
reset role;

select tests.login('a1000000-0000-4000-8000-000000000001');
select tests.affects(
  $q$delete from public.workspace_members where user_id = 'da000000-0000-4000-8000-000000000001'$q$,
  1, 'alice (admin) uklanja dave-a');
select tests.affects(
  $q$delete from public.workspace_members where user_id = 'ca000000-0000-4000-8000-000000000001'$q$,
  0, 'alice ne može da ukloni člana workspace-a B');
select tests.throws(
  $q$update public.workspace_members set role = 'member'
     where user_id = 'a1000000-0000-4000-8000-000000000001'$q$,
  '23514', 'poslednji admin ne može sebi da oduzme admin ulogu');
select tests.affects(
  $q$update public.workspaces set name = 'RLS test A (novo ime)' where id = 'aaaaaaaa-0000-4000-8000-000000000000'$q$,
  1, 'alice (admin) preimenuje workspace');
select tests.affects(
  $q$delete from public.projects where id = 'bbbbbbbb-0000-4000-8000-00000000000b'$q$,
  0, 'alice ne može da obriše projekat iz workspace-a B');
select tests.affects(
  $q$delete from public.projects where id = 'aaaaaaaa-0000-4000-8000-00000000000a'$q$,
  1, 'alice (admin) briše projekat');
do $$
declare v record;
begin
  v := tests.visible('keywords', 'aaaaaaaa-0000-4000-8000-000000000000');
  perform tests.ok(v.own = 0, 'brisanje projekta briše i njegove reči (cascade)');
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 6. Worker (service role) vidi sve workspace-e
-- ---------------------------------------------------------------------------
select tests.login_service();
do $$
declare v record;
begin
  v := tests.visible('projects', 'bbbbbbbb-0000-4000-8000-000000000000');
  perform tests.ok(v.own = 1 and v.foreign_rows >= 0, 'service role vidi projekte workspace-a B');
  perform tests.ok(
    (select count(*) from public.workspaces
     where id in ('aaaaaaaa-0000-4000-8000-000000000000', 'bbbbbbbb-0000-4000-8000-000000000000')) = 2,
    'service role vidi oba workspace-a');
end $$;
reset role;

rollback;

\echo 'RLS testovi: svi prošli.'
