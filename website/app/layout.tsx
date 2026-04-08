import type { Metadata, Viewport } from "next";
import { Inter, Amiri } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const amiri = Amiri({
  variable: "--font-amiri",
  subsets: ["arabic", "latin"],
  weight: ["400", "700"],
  display: "swap",
});

export const viewport: Viewport = {
  themeColor: "#050A14",
  width: "device-width",
  initialScale: 1,
};

export const metadata: Metadata = {
  title: "Tadabbur — One Ayah. Every Day. For Life.",
  description:
    "Begin a daily practice of Quranic contemplation. Receive one verse each morning, understand it deeply through tafsir and scholarly context, and write reflections that transform your relationship with the Quran.",
  keywords: [
    "Quran",
    "Tadabbur",
    "Daily Ayah",
    "Islamic",
    "Reflection",
    "Contemplation",
    "Quran Journal",
    "Muslim App",
  ],
  authors: [{ name: "Tadabbur" }],
  openGraph: {
    title: "Tadabbur — One Ayah. Every Day. For Life.",
    description:
      "A daily Quranic contemplation app. One verse, deep understanding, personal reflection.",
    type: "website",
    locale: "en_US",
    siteName: "Tadabbur",
  },
  twitter: {
    card: "summary_large_image",
    title: "Tadabbur — One Ayah. Every Day. For Life.",
    description:
      "A daily Quranic contemplation app. One verse, deep understanding, personal reflection.",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${amiri.variable}`}>
      <body className="min-h-screen font-sans antialiased">
        <div className="starfield" aria-hidden="true" />
        <div className="noise-overlay" aria-hidden="true" />
        <div className="relative z-10">{children}</div>
      </body>
    </html>
  );
}
