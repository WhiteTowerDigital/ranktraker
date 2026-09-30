import { createClient } from "@supabase/supabase-js";

import type { Database } from "@/lib/database.types";
import { supabaseServiceRoleKey, supabaseUrl } from "@/lib/env";

/**
 * Service role klijent: zaobilazi RLS. Samo za worker i admin skripte
 * (npr. scripts/add-member.ts), nikad za kod koji se izvršava u browseru.
 */
export function createAdminClient() {
  if (typeof window !== "undefined") {
    throw new Error("Service role klijent se ne sme koristiti u browseru.");
  }
  return createClient<Database>(supabaseUrl(), supabaseServiceRoleKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
