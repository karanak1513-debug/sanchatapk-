import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { ArrowLeft, CheckCircle2, FileText } from 'lucide-react';

export const metadata = {
  title: 'Terms of Service — Sanchat',
  description: 'Terms of Service and Conditions of Use for the Sanchat wealth management application.',
};

export default function TermsPage() {
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
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-slate-100 border border-slate-200 text-slate-700 text-xs font-mono font-medium mb-3">
              LEGAL TERMS
            </div>
            <h1 className="text-3xl sm:text-4xl font-extrabold text-obsidian tracking-tight">
              Terms of Service
            </h1>
            <p className="text-xs text-slate-500 font-mono mt-2">
              Last Updated: October 2026 • Version 1.0.0
            </p>
          </div>

          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian">1. Acceptance of Terms</h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              By downloading, installing, or using the Sanchat application (package <code className="font-mono text-xs bg-slate-100 px-1 py-0.5 rounded">com.aistudio.sanchay.savtrkr</code>), you agree to be bound by these Terms of Service. If you do not agree, do not install or use the application.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian">2. Purpose of Sanchat</h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              Sanchat is an informational personal finance tool designed to assist individuals in monitoring spending runway, tracking goal-based savings vaults, and communicating with approved peers. Sanchat is not a registered financial advisory, bank, payment gateway, or lending service.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian">3. Local SMS Processing</h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              Sanchat analyzes transactional SMS messages locally on your device to display financial insights. You acknowledge that Sanchat relies on standard Android notification/SMS services to categorize your spending, and you are responsible for granting the necessary operating system permissions.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-xl font-bold text-obsidian">4. Limitation of Liability</h2>
            <p className="text-sm text-slate-600 leading-relaxed">
              While Sanchat employs defensive algorithms to minimize parsing errors, transactional SMS formatting varies across financial institutions. Sanchat is provided on an &ldquo;as is&rdquo; basis without warranties of uninterrupted accuracy. Sanchat shall not be liable for any direct or indirect financial decisions made based on displayed metrics.
            </p>
          </section>

          <section className="space-y-3 pt-4 border-t border-cardBorder">
            <h3 className="text-base font-bold text-obsidian">5. Governing Law</h3>
            <p className="text-sm text-slate-600 leading-relaxed">
              These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising out of the use of Sanchat shall be subject to the exclusive jurisdiction of the courts in Delhi, India.
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
