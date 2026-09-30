"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { siteUrl } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { safeNextPath } from "@/lib/utils";

export type LoginState = {
  error?: string;
  message?: string;
  email?: string;
};

async function appOrigin(): Promise<string> {
  const configured = siteUrl();
  if (configured) return configured;
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  return `${proto}://${host}`;
}

export async function login(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  const intent = formData.get("intent") === "magic" ? "magic" : "password";
  const next = safeNextPath(formData.get("next"));

  if (!email) {
    return { error: "Unesite email adresu." };
  }

  const supabase = await createClient();

  if (intent === "magic") {
    const confirmUrl = new URL("/auth/confirm", await appOrigin());
    confirmUrl.searchParams.set("next", next);
    const { error } = await supabase.auth.signInWithOtp({
      email,
      // Nalozi se ne otvaraju sami: članove dodaje admin.
      options: { shouldCreateUser: false, emailRedirectTo: confirmUrl.toString() },
    });
    if (error?.status === 429) {
      return { error: "Previše zahteva. Pokušajte ponovo za minut.", email };
    }
    if (error && error.code !== "otp_disabled" && error.code !== "user_not_found") {
      console.error("Slanje magic linka nije uspelo:", error.code, error.message);
    }
    // Isti odgovor i kad nalog ne postoji, da se ne otkriva ko ima pristup.
    return { message: "Ako nalog postoji, link za prijavu je poslat na email.", email };
  }

  if (!password) {
    return { error: "Unesite lozinku ili izaberite prijavu linkom.", email };
  }

  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    if (error.code !== "invalid_credentials") {
      console.error("Prijava lozinkom nije uspela:", error.code, error.message);
    }
    return { error: "Pogrešan email ili lozinka.", email };
  }

  redirect(next);
}
