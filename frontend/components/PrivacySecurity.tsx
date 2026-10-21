'use client';

import React from 'react';
import {
  Smartphone,
  ShieldCheck,
  Lock,
  Server,
  KeyRound,
  FileText,
  UserCheck,
  CheckCircle2,
} from 'lucide-react';

export default function PrivacySecurity() {
  const securityPillars = [
    {
      icon: Smartphone,
      title: 'Local On-Device Parsing',
      desc: 'SMS and transaction notifications are parsed directly inside your local Android environment. Your personal messages and OTPs are never sent to external servers.',
      badge: 'Local Execution',
    },
    {
      icon: Lock,
      title: 'TLS 1.3 Transport Encryption',
      desc: 'All communications between your mobile device and backend Firebase infrastructure use authenticated HTTPS/TLS with strict certificate validation.',
      badge: 'Transport Security',
    },
    {
      icon: KeyRound,
      title: 'Firestore Security Rules',
      desc: 'Database rules strictly mandate `request.auth != null` and restrict access so users can only read and write their own targets, ledgers, and authorized chats.',
      badge: 'Strict Authorization',
    },
    {
      icon: UserCheck,
      title: 'Sovereign Account Deletion',
      desc: 'Full compliance with Google Play data safety policies. You can permanently erase your entire financial profile, vaults, and chat history directly inside Settings.',
      badge: 'Play Store Compliant',
    },
  ];

  return (
    <section id="privacy" className="py-20 md:py-28 bg-white relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mb-14">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs font-mono font-medium mb-3">
            ZERO NETBANKING COMPROMISE
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Your financial life{' '}
            <span className="text-darkEmerald">should stay yours.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Sanchat was deliberately designed to eliminate bank password vulnerability. We never ask for your bank credentials, netbanking logins, or debit card pins.
          </p>
        </div>

        {/* Data Architecture Flow Diagram */}
        <div className="bg-[#F8FAFC] rounded-3xl p-6 sm:p-10 border border-cardBorder mb-12 shadow-cockpit">
          <div className="text-xs font-mono uppercase tracking-wider text-slate-500 mb-6 font-bold">
            TRUST & SECURITY DATA FLOW
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 relative">
            {/* Step 1: Device */}
            <div className="bg-white p-5 rounded-2xl border border-cardBorder shadow-sm flex flex-col justify-between">
              <div>
                <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700 mb-3">
                  <Smartphone className="w-5 h-5" />
                </div>
                <div className="font-bold text-sm text-obsidian mb-1">1. User Device</div>
                <div className="text-xs text-slateText leading-relaxed">
                  SMS arrives on phone. Defensive parser extracts amount & reference number locally.
                </div>
              </div>
              <div className="mt-4 pt-3 border-t border-slate-100 text-[10px] font-mono text-darkEmerald font-semibold">
                ✓ On-Device Sandbox
              </div>
            </div>

            {/* Step 2: Sanchat App */}
            <div className="bg-white p-5 rounded-2xl border border-cardBorder shadow-sm flex flex-col justify-between">
              <div>
                <div className="w-10 h-10 rounded-xl bg-emerald-50 text-darkEmerald border border-emerald-200 flex items-center justify-center mb-3">
                  <ShieldCheck className="w-5 h-5 text-emeraldAccent" />
                </div>
                <div className="font-bold text-sm text-obsidian mb-1">2. Sanchat Engine</div>
                <div className="text-xs text-slateText leading-relaxed">
                  Deduplicates via SHA-256 fingerprint, categorizes expense, and updates daily runway.
                </div>
              </div>
              <div className="mt-4 pt-3 border-t border-slate-100 text-[10px] font-mono text-darkEmerald font-semibold">
                ✓ Zero OTP Upload
              </div>
            </div>

            {/* Step 3: Encrypted Transport */}
            <div className="bg-white p-5 rounded-2xl border border-cardBorder shadow-sm flex flex-col justify-between">
              <div>
                <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700 mb-3">
                  <Lock className="w-5 h-5 text-slate-700" />
                </div>
                <div className="font-bold text-sm text-obsidian mb-1">3. TLS 1.3 Transport</div>
                <div className="text-xs text-slateText leading-relaxed">
                  Only the user&apos;s authenticated financial balances & vaults are synced over encrypted HTTPS.
                </div>
              </div>
              <div className="mt-4 pt-3 border-t border-slate-100 text-[10px] font-mono text-darkEmerald font-semibold">
                ✓ Encrypted Pipeline
              </div>
            </div>

            {/* Step 4: Firebase Services */}
            <div className="bg-white p-5 rounded-2xl border border-cardBorder shadow-sm flex flex-col justify-between">
              <div>
                <div className="w-10 h-10 rounded-xl bg-slate-900 text-white flex items-center justify-center mb-3">
                  <Server className="w-5 h-5" />
                </div>
                <div className="font-bold text-sm text-obsidian mb-1">4. Firebase Backend</div>
                <div className="text-xs text-slateText leading-relaxed">
                  Firestore rules enforce owner-only read/write isolation. Unauthorized callers are denied.
                </div>
              </div>
              <div className="mt-4 pt-3 border-t border-slate-100 text-[10px] font-mono text-darkEmerald font-semibold">
                ✓ Owner Isolated
              </div>
            </div>
          </div>
        </div>

        {/* 4 Pillars Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-10">
          {securityPillars.map((pillar) => {
            const Icon = pillar.icon;
            return (
              <div
                key={pillar.title}
                className="p-6 rounded-2xl border border-cardBorder bg-white hover:border-slate-300 transition-all shadow-sm"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-darkEmerald">
                    <Icon className="w-5 h-5 text-emeraldAccent" />
                  </div>
                  <span className="text-xs font-mono px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-700 border border-slate-200">
                    {pillar.badge}
                  </span>
                </div>
                <h3 className="text-base font-bold text-obsidian mb-2">{pillar.title}</h3>
                <p className="text-sm text-slateText leading-relaxed">{pillar.desc}</p>
              </div>
            );
          })}
        </div>

        {/* Responsible Compliance Notice */}
        <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <CheckCircle2 className="w-5 h-5 text-darkEmerald shrink-0" />
            <div className="text-xs sm:text-sm text-slate-700">
              <span className="font-bold text-obsidian">Compliance Commitment:</span> Built for responsible Android security and Google Play policies. Complete Data Safety disclosures documented in our Privacy Policy.
            </div>
          </div>
          <a
            href="/privacy"
            className="text-xs font-bold text-darkEmerald hover:text-emerald-700 underline whitespace-nowrap"
          >
            Read Privacy Policy →
          </a>
        </div>
      </div>
    </section>
  );
}
