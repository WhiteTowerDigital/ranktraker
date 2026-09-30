import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Rank Tracker · White Tower",
  description: "Interni alat za praćenje pozicija ključnih reči",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="sr-Latn" className="h-full antialiased">
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
