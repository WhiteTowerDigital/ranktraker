import type { EmailOtpType } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import type { NextRequest } from "next/server";

import { createClient } from "@/lib/supabase/server";
import { safeNextPath } from "@/lib/utils";

/**
 * Odredište linkova iz emaila (magic link, pozivnica).
 * Podržava oba formata: ?token_hash=&type= (preporučeni email šabloni, vidi
 * supabase/templates) i ?code= (PKCE, podrazumevani Supabase šabloni).
 */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;
  const tokenHash = params.get("token_hash");
  const type = params.get("type") as EmailOtpType | null;
  const code = params.get("code");
  const next = safeNextPath(params.get("next"));

  const supabase = await createClient();

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    if (!error) redirect(next);
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) redirect(next);
  }

  redirect("/login?error=link");
}
