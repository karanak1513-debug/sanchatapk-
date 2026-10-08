import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { ArrowLeft, ShieldCheck, Lock, Smartphone, UserX } from 'lucide-react';

export const metadata = {
  title: 'Privacy Policy — Sanchat',
  description:
    'Sanchat Financial Privacy Policy & Google Play Data Safety Disclosures regarding local on-device SMS parsing and Firestore encryption.',
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-[#F8FAFC] text-obsidian flex flex-col">
      {/* Top Header */}
      <header className="bg-white border-b border-cardBorder py-4 sticky top-0 z-30">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 flex items-center justify-between">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-xs sm:text-sm font-semibold text-slate-600 hover:text-obsidian"
          >
            <ArrowLeft className="w-4 h-4 text-emeraldAccent" />
            <span>Back to Sanchat</span>
          </Link>
          <div className="flex items-center gap-2">
            <div className="relative w-6 h-6 rounded-lg overflow-hidden border border-slate-200">
              <Image
                src="/assets/branding/sanchat_icon.png"
                alt="Sanchat Logo"
                fill
                className="object-contain"
              />
            </div>
            <span className="font-extrabold text-sm tracking-tight">SANCHAT</span>
          </div>
        </div>
      </header>

      {/* Main Content Body */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 py-12 flex-1">
        <div className="bg-white rounded-3xl p-6 sm:p-12 border border-cardBorder shadow-sm space-y-8">
          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs font-mono font-medium mb-3">
              GOOGLE PLAY DATA SAFETY & DISCLOSURES
            </div>
            <h1 className="text-3xl sm:text-4xl font-extrabold text-obsidian tracking-tight">
              Sanchat Privacy Policy
            </h1>
            <p className="text-xs text-slate-500 font-mono mt-2">
              Effective Date: October 2026 • Application: Sanchat (com.aistudio.sanchay.savtrkr)
            </p>
          </div>

          <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-start gap-3 text-xs sm:text-sm text-darkEmerald">
            <ShieldCheck className="w-5 h-5 text-emeraldAccent shrink-0 mt-0.5" />
            <div className="leading-relaxed">
              <strong>Core Privacy Guarantee:</strong> Sanchat operates on an on-device first architecture. We do not require, request, or store your netbanking passwords, bank login credentials, or debit card PINs.
            </div>
          </div>

          {/* Section 1: SMS Policy */}
          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian flex items-center gap-2">
              <Smartphone className="w-5 h-5 text-emeraldAccent" />
              <span>1. Transaction SMS Processing & Disclosure</span>
            </h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              Sanchat utilizes the Android <code className="font-mono text-xs bg-slate-100 px-1.5 py-0.5 rounded">RECEIVE_SMS</code> and <code className="font-mono text-xs bg-slate-100 px-1.5 py-0.5 rounded">READ_SMS</code> permissions strictly for autonomous financial expense tracking.
            </p>
            <ul className="list-disc pl-5 text-sm text-slate-600 space-y-1.5 leading-relaxed">
              <li>
                <strong>On-Device Filtering:</strong> All SMS messages are evaluated locally by the defensive regex engine (<code className="font-mono text-xs bg-slate-100 px-1 py-0.5 rounded">NotificationParser</code>).
              </li>
              <li>
                <strong>Zero Personal Surveillance:</strong> Non-financial personal SMS, marketing promotions, OTPs, and verification codes are discarded immediately in memory.
              </li>
              <li>
                <strong>No Raw Upload:</strong> Raw SMS body strings are <em>never</em> uploaded to or stored on Sanchat servers or Firebase. Only normalized ledger entries (amount, timestamp, category, reference hash) are saved to your private Firestore collection.
              </li>
            </ul>
          </section>

          {/* Section 2: Data Storage */}
          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian flex items-center gap-2">
              <Lock className="w-5 h-5 text-emeraldAccent" />
              <span>2. Cloud Storage & Security Architecture</span>
            </h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              When user authentication is enabled, your normalized financial targets, vaults, and private chat messages are synchronized with Google Firebase Firestore under strict security rules.
            </p>
            <ul className="list-disc pl-5 text-sm text-slate-600 space-y-1.5 leading-relaxed">
              <li>
                All network communication utilizes authenticated TLS 1.3 transport encryption.
              </li>
              <li>
                Firestore Security Rules enforce cryptographic ownership (<code className="font-mono text-xs bg-slate-100 px-1 py-0.5 rounded">request.auth.uid == userId</code>), preventing any third party from accessing your financial ledgers.
              </li>
              <li>
                Chat messages are strictly readable and writable only by the two authenticated participants of the deterministic chat thread.
              </li>
            </ul>
          </section>

          {/* Section 3: Account Deletion */}
          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian flex items-center gap-2">
              <UserX className="w-5 h-5 text-rose-500" />
              <span>3. Account & Data Deletion Rights</span>
            </h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              In full compliance with Google Play Developer Policies, users retain perpetual sovereignty over their data. You may permanently delete your entire account, all associated vaults, transaction logs, and profile records at any time:
            </p>
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 text-xs text-slate-700 font-mono">
              In-App: Settings → Account Security → Tap &ldquo;Delete Account & Data Permanently&rdquo;
            </div>
            <p className="text-sm text-slate-600 leading-relaxed">
              Upon confirmation, all Firestore records belonging to your UID (targets, ledger items, public profile, friend requests) are permanently wiped and your Firebase authentication account is purged.
            </p>
          </section>

          {/* Section 4: Contact */}
          <section className="space-y-2 pt-4 border-t border-cardBorder">
            <h3 className="text-base font-bold text-obsidian">Contact & Privacy Inquiries</h3>
            <p className="text-sm text-slate-600 leading-relaxed">
              For any privacy inquiries or technical verification of our local parsing engine, please contact the Sanchat Engineering Team at <code className="font-mono text-xs text-darkEmerald">privacy@sanchat.wealth</code>.
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
