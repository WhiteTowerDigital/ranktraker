// Env varijable (SPEC §3). SUPABASE_URL i SUPABASE_ANON_KEY koristi samo
// server (Server Components, server actions, proxy), pa nema NEXT_PUBLIC_
// prefiksa i ništa se ne ugrađuje u browser bundle.

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Nedostaje env varijabla ${name} (vidi .env.example).`);
  }
  return value;
}

export function supabaseUrl(): string {
  return required("SUPABASE_URL");
}

export function supabaseAnonKey(): string {
  return required("SUPABASE_ANON_KEY");
}

/** Samo worker i admin skripte. Nikad ne sme završiti u browseru. */
export function supabaseServiceRoleKey(): string {
  return required("SUPABASE_SERVICE_ROLE_KEY");
}

/** Javni URL aplikacije za linkove u emailovima; opciono (default: iz zahteva). */
export function siteUrl(): string | undefined {
  return process.env.SITE_URL?.replace(/\/+$/, "") || undefined;
}
