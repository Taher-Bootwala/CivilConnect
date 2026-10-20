import "./globals.css";
import React from "react";

export const metadata = {
  title: "CivilHand Admin & Operations Console",
  description: "Production on-demand marketplace control center",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-50 text-slate-900 antialiased">
        {children}
      </body>
    </html>
  );
}
