import "server-only";

import { redirect } from "next/navigation";
import { cache } from "react";

import { createClient } from "@/lib/supabase/server";
import type { WorkspaceRole } from "@/lib/types";

export type CurrentUser = {
  id: string;
  email: string | null;
  /** null ako korisnik nije član nijednog workspace-a */
  workspace: { id: string; name: string; role: WorkspaceRole } | null;
};

/**
 * Prijavljeni korisnik i njegov workspace (u fazi 1 postoji samo jedan).
 * Keširano po zahtevu, pa ga layout i stranice mogu zvati bez dodatnih upita.
 */
export const getCurrentUser = cache(async (): Promise<CurrentUser> => {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;
  if (!claims?.sub) {
    redirect("/login");
  }

  const { data: membership, error } = await supabase
    .from("workspace_members")
    .select("role, workspace:workspaces(id, name)")
    .eq("user_id", claims.sub)
    .order("created_at")
    .limit(1)
    .maybeSingle();
  if (error) {
    throw new Error(`Učitavanje workspace-a nije uspelo: ${error.message}`);
  }

  return {
    id: claims.sub,
    email: typeof claims.email === "string" ? claims.email : null,
    workspace: membership?.workspace
      ? { ...membership.workspace, role: membership.role as WorkspaceRole }
      : null,
  };
});
