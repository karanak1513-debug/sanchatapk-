import type { Metadata, Viewport } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const viewport: Viewport = {
  themeColor: '#10B981',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  title: 'Sanchat — Master Your Money. Build Real Wealth.',
  description:
    'Sanchat is an intelligent personal finance and wealth management app with autonomous on-device UPI tracking, smart spending runways, multi-vault savings, and 1-on-1 messaging.',
  keywords: [
    'Sanchat',
    'Personal Finance India',
    'UPI Tracker',
    'Spending Runway',
    'Savings Vault',
    'Expense Tracker',
    'Android Fintech',
    'Smart Savings',
  ],
  authors: [{ name: 'Sanchat Team' }],
  metadataBase: new URL('https://stitchsanchaywealthappuisystem.vercel.app'),
  openGraph: {
    title: 'Sanchat — Master Your Money. Build Real Wealth.',
    description:
      'Autonomous on-device UPI tracking, smart daily spending runways, multi-vault savings, and 1-on-1 private messaging. Built for Android 16.',
    url: 'https://stitchsanchaywealthappuisystem.vercel.app',
    siteName: 'Sanchat',
    images: [
      {
        url: '/assets/branding/sanchat_og.png',
        width: 1200,
        height: 630,
        alt: 'Sanchat — Smart Personal Wealth & Vault Cockpit',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Sanchat — Master Your Money. Build Real Wealth.',
    description:
      'Autonomous on-device UPI tracking, smart daily spending runways, multi-vault savings, and 1-on-1 private messaging.',
    images: ['/assets/branding/sanchat_og.png'],
  },
  icons: {
    icon: [
      { url: '/assets/branding/sanchat_icon.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon.png', sizes: '192x192', type: 'image/png' },
    ],
    apple: [{ url: '/assets/branding/sanchat_icon.png', sizes: '180x180' }],
    shortcut: ['/assets/branding/sanchat_icon.png'],
  },
  manifest: '/manifest.json',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${inter.variable} ${jetbrainsMono.variable}`}>
      <body className="min-h-screen bg-white text-obsidian font-sans antialiased selection:bg-emeraldAccent selection:text-white">
        {children}
      </body>
    </html>
  );
}
