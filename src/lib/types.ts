// Dozvoljene vrednosti tekstualnih kolona (check constraint-i u šemi).
// database.types.ts ih prikazuje kao string, jer tako radi `supabase gen types`.

export type WorkspaceRole = "admin" | "member";
export type MatchMode = "domain" | "exact_domain" | "url_prefix";
export type Device = "desktop" | "mobile";
export type PositionSource = "dataforseo" | "seranking_import" | "manual";
export type CheckRunStatus = "running" | "done" | "failed";
export type SerpTaskStatus = "posted" | "done" | "failed";
