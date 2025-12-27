import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CC ISLE - Web Portal",
  description: "Admin and Curator portal for CC ISLE",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
