import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Rotmaker — brainrot video generator",
  description: "Turn a script into a talking-avatar brainrot video, captions and all.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
