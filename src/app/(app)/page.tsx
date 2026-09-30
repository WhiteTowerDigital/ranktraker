import type { Metadata } from "next";

import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Projekti · Rank Tracker" };

export default async function ProjectsPage() {
  const supabase = await createClient();
  // RLS vraća samo projekte workspace-a čiji je korisnik član.
  const { data: projects, error } = await supabase
    .from("projects")
    .select("id, name, domain, is_active, keywords(count)")
    .order("name");
  if (error) {
    throw new Error(`Učitavanje projekata nije uspelo: ${error.message}`);
  }

  return (
    <div className="grid gap-6">
      <h1 className="text-2xl font-semibold">Projekti</h1>

      {projects.length === 0 ? (
        <div className="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
          Još nema projekata. Projekti stižu uvozom iz SE Rankinga (faza F1).
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Naziv</th>
                <th className="px-4 py-2 font-medium">Domen</th>
                <th className="px-4 py-2 text-right font-medium">Reči</th>
              </tr>
            </thead>
            <tbody>
              {projects.map((p) => (
                <tr key={p.id} className="border-t">
                  <td className="px-4 py-2">
                    {p.name}
                    {!p.is_active && (
                      <span className="ml-2 text-xs text-muted-foreground">(neaktivan)</span>
                    )}
                  </td>
                  <td className="px-4 py-2 text-muted-foreground">{p.domain}</td>
                  <td className="px-4 py-2 text-right tabular-nums">
                    {p.keywords[0]?.count ?? 0}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
