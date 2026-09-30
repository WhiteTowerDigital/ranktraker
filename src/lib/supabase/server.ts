import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import type { Database } from "@/lib/database.types";
import { supabaseAnonKey, supabaseUrl } from "@/lib/env";

/**
 * Supabase klijent za Server Components, server actions i route handlere.
 * Radi u ime prijavljenog korisnika (anon ključ + sesija iz kolačića), pa
 * svaki upit prolazi kroz RLS.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(supabaseUrl(), supabaseAnonKey(), {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Component ne može da menja kolačiće; sesiju osvežava proxy.
        }
      },
    },
  });
}
