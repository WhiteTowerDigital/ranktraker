# Rank Tracker: tehnička specifikacija (MVP)

Interni alat za praćenje pozicija ključnih reči za White Tower Digital.
Faza 1 služi samo za interni tim. Arhitektura je od početka pripremljena za kasniju prodaju kao SaaS (multi-tenant).

---

## 1. Ciljevi i obim

**MVP mora da:**
- preuzme projekte, grupe, ključne reči i istoriju pozicija iz SE Rankinga,
- proverava pozicije preko SERP API provajdera (početno DataForSEO) na svaka 3 dana,
- prikaže pozicije, promene i istoriju u web dashboardu,
- izveze podatke u CSV/XLSX za izveštaje,
- beleži trošak svake provere po projektu.

**Van obima MVP-a** (dolazi tek uz SaaS fazu): naplata, white-label izveštaji, pristup za klijente, praćenje konkurencije, SERP feature-i, lokalni (Maps) rezultati, mobile pozicije, alerti.

---

## 2. Arhitektonski principi

1. **Multi-tenant od prvog dana.** Svaka tabela ima `workspace_id`, a pristup kontroliše Postgres RLS. Za sada postoji jedan workspace („White Tower“).
2. **SERP provajder je zamenljiv adapter.** Ostatak koda ne sme da zna za DataForSEO. Zamena provajdera znači novi adapter, bez izmena u ostatku sistema.
3. **Svaka pozicija ima izvor** (`dataforseo`, `seranking_import`, `manual`). Podaci različitog porekla nikad se ne mešaju bez oznake.
4. **Trošak se beleži po zadatku.** To je osnova za kasnije određivanje cene alata.
5. **Jednostavnost pre svega.** Jedan repo, jedan jezik (TypeScript), minimalno servisa.

---

## 3. Tehnički stack

| Sloj | Izbor |
|---|---|
| Jezik | TypeScript (ceo repo) |
| Dashboard | Next.js (App Router) + Tailwind + shadcn/ui, grafikoni: Recharts |
| Baza i auth | Supabase (Postgres, Auth, RLS) |
| Worker | Node skripte (`/worker`), pokreću se preko crona |
| Hosting | VPS (npr. Hetzner) sa Dockerom: Next.js + cron worker |
| Export | CSV + XLSX (SheetJS) |

**Env varijable:**
```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY     # samo worker, nikad u browseru
DATAFORSEO_LOGIN
DATAFORSEO_PASSWORD
SERANKING_API_KEY             # samo za import
```

---

## 4. Šema baze

Sve tabele imaju `id uuid pk default gen_random_uuid()`, `created_at timestamptz default now()` i `workspace_id uuid not null` (osim `workspaces`).

### workspaces
| kolona | tip | napomena |
|---|---|---|
| name | text | |

### workspace_members
| kolona | tip | napomena |
|---|---|---|
| workspace_id | uuid fk | |
| user_id | uuid fk auth.users | |
| role | text | `admin` \| `member` |

unique(workspace_id, user_id)

### projects
| kolona | tip | napomena |
|---|---|---|
| name | text | npr. „Biokanna“ |
| domain | text | npr. `biokanna.rs` (bez protokola i www) |
| match_mode | text | `domain` (uklj. poddomene) \| `exact_domain` \| `url_prefix` |
| location_code | int | DataForSEO kod lokacije, Srbija = 2688 |
| language_code | text | npr. `sr` |
| device | text | `desktop` (mobile kasnije) |
| check_interval_days | int | default 3 |
| is_active | bool | default true |
| seranking_site_id | bigint null | za import i poređenje |

### keyword_groups
| kolona | tip | napomena |
|---|---|---|
| project_id | uuid fk | |
| name | text | npr. „CBD“ |
| seranking_group_id | bigint null | |

### keywords
| kolona | tip | napomena |
|---|---|---|
| project_id | uuid fk | |
| group_id | uuid fk null | |
| keyword | text | |
| target_url | text null | očekivana landing stranica |
| depth_override | int null | ako je setovano, ignoriše automatsku dubinu |
| is_active | bool | default true |
| next_check_on | date | kad je sledeća provera na redu |
| seranking_keyword_id | bigint null | |

unique(project_id, keyword)

### positions
| kolona | tip | napomena |
|---|---|---|
| keyword_id | uuid fk | |
| checked_on | date | |
| position | int null | organska pozicija (rank_group); `0` = nije pronađen do `depth_checked`; `null` = provera nije uspela |
| ranking_url | text null | URL koji rangira |
| matches_target | bool null | da li je ranking_url = target_url |
| depth_checked | int | 10, 30, 100... |
| source | text | `dataforseo` \| `seranking_import` \| `manual` |
| cost_usd | numeric(10,5) | 0 za import i manual |

unique(keyword_id, checked_on)
index(keyword_id, checked_on desc)

### serp_snapshots
Čuva top 10 za svaku proveru (za kasnije praćenje konkurencije, jeftino jer je jsonb).

| kolona | tip | napomena |
|---|---|---|
| keyword_id | uuid fk | |
| checked_on | date | |
| results | jsonb | `[{rank, domain, url, title}]`, prvih 10 organskih |

unique(keyword_id, checked_on)

### check_runs
| kolona | tip | napomena |
|---|---|---|
| started_at / finished_at | timestamptz | |
| status | text | `running` \| `done` \| `failed` |
| provider | text | `dataforseo` |
| tasks_total / tasks_failed | int | |
| cost_usd | numeric(10,4) | zbir troška |

### serp_tasks
| kolona | tip | napomena |
|---|---|---|
| run_id | uuid fk | |
| keyword_id | uuid fk | |
| provider_task_id | text | ID koji vrati provajder |
| depth | int | |
| status | text | `posted` \| `done` \| `failed` |
| attempts | int | default 0, max 3 |
| cost_usd | numeric(10,5) | |
| error | text null | |

### RLS
Na svim tabelama: korisnik vidi i menja samo redove čiji je `workspace_id` u `workspace_members` za `auth.uid()`. Brisanje projekata i upravljanje članovima samo za `admin`. Worker koristi service role ključ.

---

## 5. SERP provajder (adapter)

```ts
interface SerpTaskInput {
  keywordId: string;
  keyword: string;
  locationCode: number;
  languageCode: string;
  device: 'desktop' | 'mobile';
  depth: number;
}

interface SerpOrganicItem {
  rankGroup: number;      // pozicija među organskim rezultatima
  rankAbsolute: number;   // pozicija uključujući ostale SERP elemente
  url: string;
  domain: string;
  title?: string;
}

interface SerpResult {
  keywordId: string;
  providerTaskId: string;
  items: SerpOrganicItem[];
  costUsd: number;
}

interface SerpProvider {
  name: string;
  submit(tasks: SerpTaskInput[]): Promise<{ keywordId: string; providerTaskId: string }[]>;
  collectReady(): Promise<SerpResult[]>;   // vraća završene zadatke
}
```

**DataForSEO adapter** koristi standardni red (najjeftiniji):
- `POST /v3/serp/google/organic/task_post`, do 100 zadataka po zahtevu, sa `tag = keywordId`,
- `GET /v3/serp/google/organic/tasks_ready`, pa `GET /v3/serp/google/organic/task_get/advanced/{id}`,
- zadržava samo `type = "organic"` stavke,
- trošak čita iz polja `cost` svakog zadatka.

---

## 6. Logika provere

### Raspored (cron)
- **Planer** (svaki dan u 03:00): uzima aktivne ključne reči gde je `next_check_on <= danas`, pravi `check_run` i šalje zadatke.
  - Pri inicijalnom uvozu, `next_check_on` se raspoređuje ravnomerno na 3 dana. Tako se dnevno proverava oko trećina reči, a trošak i opterećenje su ravnomerni.
- **Sakupljač** (na svakih 15 min): preuzima gotove zadatke, računa pozicije i upisuje `positions` i `serp_snapshots`. Neuspele zadatke ponovo šalje (max 3 pokušaja). Po uspehu postavlja `next_check_on = danas + check_interval_days`.

### Automatska dubina
- `depth_override`, ako je postavljen, ima prednost.
- Poslednja poznata pozicija 1–20: dubina 30.
- Poslednja poznata pozicija > 20, 0 ili nepoznata: dubina 100.
- Ako reč nije pronađena na dubini 30, a prethodno je bila u top 20: odmah ponovo pošalji sa dubinom 100 (retko se dešava, ali sprečava lažne nule).

### Određivanje pozicije
1. Prođi kroz organske stavke po `rankGroup`.
2. Prvi rezultat čiji domen odgovara projektu (prema `match_mode`) daje `position` i `ranking_url`.
3. Ako ništa ne odgovara: `position = 0`.
4. Ako je `target_url` postavljen: `matches_target = normalize(ranking_url) == normalize(target_url)`.
5. Normalizacija URL-a: bez protokola, bez `www.`, bez završne `/`, bez query stringa.

---

## 7. Uvoz iz SE Rankinga (jednokratno + po potrebi)

Preko SE Ranking Project API-ja (tačne endpointe proveriti u njihovoj dokumentaciji):
1. Projekti (sites), iz kojih se mapiraju `name`, `domain`, `seranking_site_id`.
2. Pretraživač projekta, sa mapiranjem na `location_code`/`language_code`. Google Srbija (sr-Latn) = `2688` / `sr`.
3. Grupe ključnih reči i ključne reči, uz ciljne URL-ove (landing pages).
4. Istorija pozicija, sa `source = seranking_import`.

**Važno za istoriju:** SE Ranking je od oko 23. 9. 2026. vraćao lažne nule zbog promene kod Google-a. Uvoz mora imati parametar `--trust-until=YYYY-MM-DD`. Nule posle tog datuma se ne uvoze. Ne-nula vrednosti posle tog datuma se uvoze sa `source = manual`, jer su tada ručno upisane.

Uvoz mora biti idempotentan (ponovno pokretanje ne pravi duplikate).

---

## 8. Dashboard: ekrani

1. **Login** (Supabase Auth, email + lozinka ili magic link).
2. **Projekti:** naziv, domen, broj reči, prosečna pozicija, broj u top 3 / top 10, promena u odnosu na prethodnu proveru, datum poslednje provere.
3. **Projekat:**
   - tabela reči: ključna reč, grupa, trenutna pozicija, promena (zeleno/crveno), najbolja pozicija, ranking URL (sa oznakom ako ne odgovara target URL-u), datum provere, mini grafikon,
   - filteri: grupa, pretraga, top 3 / top 10 / top 30 / van top 100,
   - grafikon prosečne pozicije po grupi kroz vreme,
   - dugme „Proveri sad“ (ručna provera izabranih reči, uz prikaz procenjenog troška).
4. **Ključna reč:** grafikon istorije pozicije, istorija ranking URL-ova, poslednji top 10 snapshot.
5. **Podešavanja projekta:** izmena podataka, bulk dodavanje reči (paste liste, reč po redu, opciono `reč;grupa;target_url`), interval provere.
6. **Troškovi:** trošak po projektu i po mesecu, procena za tekući mesec.
7. **Članovi tima** (samo admin): pozivanje i uklanjanje, dodela uloga.
8. **Export:** CSV/XLSX po projektu za izabrani period (reč, grupa, pozicije po datumima u kolonama).

Pozicije prikazivati kao: broj; `>100` za 0; `—` za neuspelu proveru. Pored ručno unetih vrednosti prikazati malu oznaku izvora.

---

## 9. Faze izrade

| Faza | Sadržaj | Kriterijum završetka |
|---|---|---|
| **F0** | Repo, Next.js, Supabase, šema, RLS, login, seed workspace | Tim može da se uloguje; RLS test: korisnik van workspace-a ne vidi ništa |
| **F1** | Uvoz iz SE Rankinga | Svi projekti, grupe, reči i istorija do `trust-until` su u bazi; ponovni uvoz ne pravi duplikate |
| **F2** | DataForSEO adapter, planer, sakupljač | Biokanna CBD grupa proverena end-to-end; pozicije ručno uporediti sa incognito proverom za 3 reči; trošak upisan |
| **F3** | Dashboard: projekti, projekat, ključna reč | Sve pozicije i grafikoni vidljivi; filteri rade |
| **F4** | Export, troškovi, članovi tima, bulk dodavanje, „Proveri sad“ | Tim može da vodi projekte bez SE Rankinga |
| **F5** | Deploy na VPS, cron, monitoring (email kad `check_run` padne ili >10% zadataka ne uspe) | Radi samostalno 2 nedelje paralelno sa SE Rankingom |

Posle F5: mesec dana paralelnog rada sa SE Rankingom, pa odluka o SE Ranking pretplati.

---

## 10. Kasnije (SaaS faza), ne raditi sada

Registracija novih workspace-a, naplata (Stripe), limiti po planu (broj reči, interval), white-label PDF izveštaji, pristup za klijente (read-only link), praćenje konkurencije (iz `serp_snapshots`), mobile pozicije, lokalne pozicije, alerti za pad pozicija.
Pre prodaje: proveriti DataForSEO uslove korišćenja za upotrebu njihovih podataka u komercijalnom proizvodu.

---

## 11. Otvorena pitanja

- Da li `match_mode = domain` (uključuje poddomene) kao podrazumevano odgovara svim projektima?
- Da li „Proveri sad“ treba ograničiti (npr. dnevni budžet po workspace-u)?
- Da li je nekim projektima potreban interval različit od 3 dana?
