import type { Metadata } from "next";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { safeNextPath } from "@/lib/utils";

import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Prijava · Rank Tracker" };

const ERRORS: Record<string, string> = {
  link: "Link za prijavu je nevažeći ili je istekao. Zatražite novi.",
};

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const params = await searchParams;
  const next = safeNextPath(params.next);
  const errorKey = typeof params.error === "string" ? params.error : undefined;

  return (
    <main className="flex flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="text-xl">Rank Tracker</CardTitle>
          <CardDescription>Prijava za White Tower tim</CardDescription>
        </CardHeader>
        <CardContent>
          <LoginForm next={next} initialError={errorKey ? ERRORS[errorKey] : undefined} />
        </CardContent>
      </Card>
    </main>
  );
}
