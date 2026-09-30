/**
 * Dodaje (ili ažurira) člana tima u workspace.
 *
 *   npm run member:add -- ime@whitetower.rs --role admin
 *   npm run member:add -- ime@whitetower.rs --password 'tajna-lozinka'
 *
 * Ako nalog ne postoji: sa --password se pravi nalog sa lozinkom, a bez nje
 * se šalje pozivnica emailom (korisnik se zatim prijavljuje magic linkom).
 * Ako nalog postoji, --password mu postavlja novu lozinku.
 *
 * Koristi SUPABASE_SERVICE_ROLE_KEY (čita .env.local).
 */
import { parseArgs } from "node:util";

import type { User } from "@supabase/supabase-js";

import { WHITE_TOWER_WORKSPACE_ID } from "../src/lib/constants";
import { siteUrl } from "../src/lib/env";
import { createAdminClient } from "../src/lib/supabase/admin";
import type { WorkspaceRole } from "../src/lib/types";

const USAGE =
  "Upotreba: npm run member:add -- <email> [--role admin|member] [--password <lozinka>] [--workspace <uuid>]";

function fail(message: string): never {
  console.error(message);
  process.exit(1);
}

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    role: { type: "string", default: "member" },
    password: { type: "string" },
    workspace: { type: "string", default: WHITE_TOWER_WORKSPACE_ID },
  },
});

const email = positionals[0]?.trim().toLowerCase();
if (!email || !email.includes("@")) fail(USAGE);
if (values.role !== "admin" && values.role !== "member") fail(USAGE);
const role = values.role as WorkspaceRole;
if (values.password !== undefined && values.password.length < 8) {
  fail("Lozinka mora imati bar 8 karaktera.");
}

const supabase = createAdminClient();

async function findUserByEmail(address: string): Promise<User | undefined> {
  const perPage = 1000;
  for (let page = 1; ; page++) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) fail(`Čitanje korisnika nije uspelo: ${error.message}`);
    const found = data.users.find((u) => u.email?.toLowerCase() === address);
    if (found || data.users.length < perPage) return found;
  }
}

async function main() {
  const { data: workspace, error: wsError } = await supabase
    .from("workspaces")
    .select("id, name")
    .eq("id", values.workspace!)
    .maybeSingle();
  if (wsError) fail(`Čitanje workspace-a nije uspelo: ${wsError.message}`);
  if (!workspace) fail(`Workspace ${values.workspace} ne postoji. Da li su migracije primenjene?`);

  let user = await findUserByEmail(email!);

  if (!user && values.password) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: email!,
      password: values.password,
      email_confirm: true,
    });
    if (error) fail(`Pravljenje naloga nije uspelo: ${error.message}`);
    user = data.user;
    console.log(`Napravljen nalog ${email} sa lozinkom.`);
  } else if (!user) {
    const base = siteUrl() ?? "http://localhost:3000";
    const { data, error } = await supabase.auth.admin.inviteUserByEmail(email!, {
      redirectTo: `${base}/auth/confirm`,
    });
    if (error) fail(`Slanje pozivnice nije uspelo: ${error.message}`);
    user = data.user;
    console.log(`Poslata pozivnica na ${email}.`);
  } else if (values.password) {
    const { error } = await supabase.auth.admin.updateUserById(user.id, {
      password: values.password,
    });
    if (error) fail(`Promena lozinke nije uspela: ${error.message}`);
    console.log(`Postavljena nova lozinka za ${email}.`);
  }

  const { error: memberError } = await supabase
    .from("workspace_members")
    .upsert(
      { workspace_id: workspace.id, user_id: user.id, role },
      { onConflict: "workspace_id,user_id" },
    );
  if (memberError) fail(`Dodavanje u workspace nije uspelo: ${memberError.message}`);

  console.log(`${email} je ${role} u workspace-u „${workspace.name}“.`);
}

main().catch((err: unknown) => fail(err instanceof Error ? err.message : String(err)));
