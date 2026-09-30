import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import type { Database } from "@/lib/database.types";
import { supabaseAnonKey, supabaseUrl } from "@/lib/env";

/** Putanje dostupne bez prijave. */
const PUBLIC_PATHS = ["/login", "/auth/"];

function isPublic(pathname: string) {
  return PUBLIC_PATHS.some((p) => (p.endsWith("/") ? pathname.startsWith(p) : pathname === p));
}

/**
 * Osvežava Supabase sesiju pri svakom zahtevu i štiti aplikaciju:
 * neprijavljeni korisnik ide na /login, prijavljeni ne vidi /login.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(supabaseUrl(), supabaseAnonKey(), {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
        for (const [key, value] of Object.entries(headers)) {
          response.headers.set(key, value);
        }
      },
    },
  });

  // Ne ubacivati kod između createServerClient i getClaims(): getClaims
  // proverava JWT i po potrebi osvežava sesiju.
  const { data } = await supabase.auth.getClaims();
  const signedIn = Boolean(data?.claims?.sub);
  const { pathname, search } = request.nextUrl;

  const redirectTo = (path: string, next?: string) => {
    const url = request.nextUrl.clone();
    url.pathname = path;
    url.search = next ? `?next=${encodeURIComponent(next)}` : "";
    const redirect = NextResponse.redirect(url);
    // zadrži osvežene kolačiće sesije
    for (const cookie of response.cookies.getAll()) {
      redirect.cookies.set(cookie);
    }
    return redirect;
  };

  if (!signedIn && !isPublic(pathname)) {
    return redirectTo("/login", pathname === "/" ? undefined : pathname + search);
  }

  if (signedIn && pathname === "/login") {
    return redirectTo("/");
  }

  return response;
}
