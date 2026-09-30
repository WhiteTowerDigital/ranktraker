# Rank Tracker

Interni alat White Tower Digital-a za praćenje pozicija ključnih reči.
Specifikacija: `SPEC-rank-tracker.md` (MVP, faze F0–F5).

**Status: F0** – repo, Next.js, Supabase šema, RLS, login, seed workspace.

## Stack

| Sloj | |
|---|---|
| Dashboard | Next.js 16 (App Router) + Tailwind 4 + shadcn/ui |
| Baza i auth | Supabase (Postgres, Auth, RLS) |
| Worker | Node skripte u `/worker` (od F2) |

```
src/
  app/(app)/          zaštićeni deo (layout sa zaglavljem, lista projekata)
  app/login/          prijava: email + lozinka ili magic link
  app/auth/confirm/   odredište linkova iz emaila (magic link, pozivnica)
  lib/supabase/       klijenti: server (RLS), admin (service role), proxy (sesija)
  lib/database.types.ts
  proxy.ts            Next 16 "proxy" (nekadašnji middleware): osvežava sesiju, štiti rute
supabase/
  migrations/         šema, RLS, workspace „White Tower“
  seed.sql            lokalni test nalozi
  templates/          email šabloni (token_hash linkovi)
  tests/rls.test.sql  RLS testovi
scripts/
  add-member.ts       dodavanje člana tima
  test-db.sh          pokretanje RLS testova
```

## Lokalni razvoj

Potrebno: Node 22+, Docker (za lokalni Supabase).

```bash
npm install
npm run db:start            # lokalni Supabase; ispisuje URL i ključeve
cp .env.example .env.local  # upisati SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
npm run db:reset            # migracije + seed.sql
npm run dev                 # http://localhost:3000
```

Lokalni nalozi iz `supabase/seed.sql` (lozinka `lozinka123`):

| Nalog | Uloga |
|---|---|
| `admin@whitetower.local` | admin u workspace-u White Tower |
| `outsider@whitetower.local` | nije član – posle prijave vidi „Nemate pristup“, a RLS mu ne vraća nijedan red |

Emailovi (magic link, pozivnice) lokalno stižu u Mailpit: http://127.0.0.1:54324.

## Članovi tima

Samostalna registracija je isključena. Člana dodaje admin skriptom (UI za članove dolazi u F4):

```bash
npm run member:add -- ime@whitetower.rs --role admin                # pozivnica emailom
npm run member:add -- ime@whitetower.rs --password 'duga-lozinka'   # nalog sa lozinkom
```

Ako nalog već postoji, skripta samo menja ulogu (i lozinku, ako je data).

## Baza i RLS

- Svaka tabela ima `workspace_id`; podređene tabele referenciraju roditelja preko
  `(id, workspace_id)`, pa red ne može da pokazuje na podatke drugog workspace-a.
- Korisnik vidi i menja samo redove workspace-a čiji je član. Brisanje projekata
  i upravljanje članovima samo za `admin`; workspace ne može ostati bez admina.
- `check_runs` i `serp_tasks` (trošak) članovi samo čitaju, piše ih worker (service role).
- `anon` nema pristup nijednoj tabeli.

RLS testovi (sve u transakciji koja se poništava):

```bash
npm run test:db                                   # lokalni Supabase
DATABASE_URL=postgresql://... npm run test:db     # prazna Postgres baza (npr. CI)
```

Na običnom Postgresu skripta prvo primeni minimalni Supabase sloj
(`supabase/tests/support/supabase_stub.sql`) i migracije. CI (`.github/workflows/ci.yml`)
pokreće lint, typecheck, build i RLS testove.

Posle izmene šeme: nova migracija u `supabase/migrations/`, zatim `npm run db:types`
i proširenje `tests.expected` u `rls.test.sql` (test pada ako neka tabela nije pokrivena).

## Hostovani Supabase projekat

1. `npx supabase link --project-ref <ref>` pa `npx supabase db push` (migracije,
   uključujući workspace „White Tower“). **Ne** pokretati `seed.sql` u produkciji.
2. Authentication → Sign In / Providers: isključiti „Allow new users to sign up“.
   Email provider **ostaviti uključen** (inače ne radi ni prijava).
3. Authentication → URL Configuration: Site URL = javni URL aplikacije,
   Redirect URLs = `https://<domen>/**`.
4. Authentication → Emails: šablone „Invite user“ i „Magic Link“ zameniti sadržajem
   `supabase/templates/invite.html` i `magic_link.html`. Link u podrazumevanim šablonima
   za pozivnicu ne radi sa server-side prijavom.
5. Prvi admin: `npm run member:add -- ime@whitetower.rs --role admin --password '...'`
   sa produkcionim ključevima u `.env.local`.

## Env varijable

Vidi `.env.example`. `SUPABASE_URL` i `SUPABASE_ANON_KEY` koristi samo server
(nema `NEXT_PUBLIC_` prefiksa), a `SUPABASE_SERVICE_ROLE_KEY` samo worker i skripte.
