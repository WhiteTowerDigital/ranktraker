import { Button } from "@/components/ui/button";
import { getCurrentUser } from "@/lib/auth";

import { signOut } from "./actions";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();

  return (
    <div className="flex flex-1 flex-col">
      <header className="border-b">
        <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between gap-4 px-4">
          <div className="flex items-baseline gap-3">
            <span className="font-semibold">Rank Tracker</span>
            {user.workspace && (
              <span className="text-sm text-muted-foreground">{user.workspace.name}</span>
            )}
          </div>
          <div className="flex items-center gap-3">
            <span className="hidden text-sm text-muted-foreground sm:inline">
              {user.email}
              {user.workspace?.role === "admin" && " · admin"}
            </span>
            <form action={signOut}>
              <Button type="submit" variant="outline" size="sm">
                Odjava
              </Button>
            </form>
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">
        {user.workspace ? (
          children
        ) : (
          <div className="rounded-lg border p-6">
            <h1 className="font-semibold">Nemate pristup nijednom workspace-u</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              Nalog {user.email} postoji, ali nije dodat u tim. Zamolite admina da vas doda.
            </p>
          </div>
        )}
      </main>
    </div>
  );
}
