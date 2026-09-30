"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { login, type LoginState } from "./actions";

export function LoginForm({ next, initialError }: { next: string; initialError?: string }) {
  const [state, formAction, pending] = useActionState<LoginState, FormData>(login, {
    error: initialError,
  });

  return (
    <form action={formAction} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <div className="grid gap-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          defaultValue={state.email}
          placeholder="ime@whitetower.rs"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="password">Lozinka</Label>
        <Input id="password" name="password" type="password" autoComplete="current-password" />
      </div>

      {state.error && (
        <p role="alert" className="text-sm text-destructive">
          {state.error}
        </p>
      )}
      {state.message && (
        <p role="status" className="text-sm text-muted-foreground">
          {state.message}
        </p>
      )}

      <Button type="submit" name="intent" value="password" disabled={pending}>
        Prijavi se
      </Button>
      <Button type="submit" name="intent" value="magic" variant="outline" disabled={pending}>
        Pošalji link za prijavu na email
      </Button>
    </form>
  );
}
