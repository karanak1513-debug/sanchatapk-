'use client';

import React, { useState } from 'react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { RELEASE_CONFIG } from '@/config/release';
import {
  ShieldCheck,
  Copy,
  Check,
  Terminal,
  FileCheck,
  ArrowDownToLine,
  ExternalLink,
  ArrowLeft,
} from 'lucide-react';
import Link from 'next/link';

export default function VerificationPage() {
  const [copiedField, setCopiedField] = useState<string | null>(null);

  const copyToClipboard = (text: string, field: string) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      setCopiedField(field);
      setTimeout(() => setCopiedField(null), 2500);
    }
  };

  const fullDownloadUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}${RELEASE_CONFIG.downloadRoute}`
      : `${RELEASE_CONFIG.officialDomain}${RELEASE_CONFIG.downloadRoute}`;

  return (
    <div className="min-h-screen bg-slate-950 text-white flex flex-col selection:bg-emeraldAccent selection:text-white">
      <Navbar />

      <main className="flex-1 py-16 sm:py-24 max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        {/* Navigation Breadcrumb */}
        <div className="mb-8">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-xs font-mono text-slate-400 hover:text-emerald-400 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Sanchat Home</span>
          </Link>
        </div>

        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-12">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-950 border border-emerald-700 text-emerald-400 text-xs font-mono font-medium mb-3">
            <ShieldCheck className="w-4 h-4" />
            <span>OFFICIAL SANCHAT RELEASE VERIFICATION</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-white tracking-tight mb-4">
            Cryptographic Integrity Center
          </h1>
          <p className="text-slate-400 text-sm sm:text-base leading-relaxed">
            Verify the authenticity of your Sanchat Android APK binary before installing. Every build is cryptographically signed and independently verifiable.
          </p>
        </div>

        {/* Verification Card */}
        <div className="bg-slate-900 rounded-3xl p-6 sm:p-10 border border-slate-800 shadow-2xl relative overflow-hidden mb-10">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 mb-6">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-emerald-950 border border-emerald-700 flex items-center justify-center text-emerald-400">
                <FileCheck className="w-6 h-6" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-slate-100 flex items-center gap-2">
                  <span>Official Sanchat Release</span>
                  <span className="text-[10px] font-mono font-semibold px-2 py-0.5 rounded-full bg-emerald-900/60 text-emerald-400 border border-emerald-700">
                    v{RELEASE_CONFIG.version}
                  </span>
                </h2>
                <p className="text-xs text-slate-400 font-mono">
                  Universal Android APK • Target SDK 36 (Android 16)
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => copyToClipboard(RELEASE_CONFIG.sha256, 'all-hash')}
                className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-mono text-slate-200 border border-slate-700 transition-all active:scale-95"
              >
                {copiedField === 'all-hash' ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-emerald-400" />
                    <span className="text-emerald-400">SHA-256 Copied</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5 text-slate-400" />
                    <span>Copy SHA-256</span>
                  </>
                )}
              </button>

              <Link
                href={RELEASE_CONFIG.downloadRoute}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-emeraldAccent hover:bg-emerald-400 text-obsidian font-bold text-xs transition-all active:scale-95 shadow-md"
              >
                <ArrowDownToLine className="w-3.5 h-3.5" />
                <span>Download APK</span>
              </Link>
            </div>
          </div>

          {/* Grid of Verified Fields */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 font-mono text-xs">
            {/* Package */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
              <div>
                <span className="text-[10px] text-slate-500 uppercase block mb-1 font-sans">
                  Application Package ID
                </span>
                <span className="text-slate-200 font-bold">{RELEASE_CONFIG.packageId}</span>
              </div>
              <button
                type="button"
                onClick={() => copyToClipboard(RELEASE_CONFIG.packageId, 'pkg')}
                className="p-1.5 rounded hover:bg-slate-800 text-slate-400 hover:text-white"
                aria-label="Copy Package ID"
              >
                {copiedField === 'pkg' ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : (
                  <Copy className="w-3.5 h-3.5" />
                )}
              </button>
            </div>

            {/* Version */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
              <div>
                <span className="text-[10px] text-slate-500 uppercase block mb-1 font-sans">
                  Version & Build Number
                </span>
                <span className="text-emerald-400 font-bold">
                  {RELEASE_CONFIG.versionName} (Build {RELEASE_CONFIG.versionCode})
                </span>
              </div>
              <span className="text-[10px] text-slate-400 px-2 py-0.5 rounded bg-slate-900 border border-slate-800">
                {RELEASE_CONFIG.targetSdk}
              </span>
            </div>

            {/* File & Size */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
              <div>
                <span className="text-[10px] text-slate-500 uppercase block mb-1 font-sans">
                  Official Binary File
                </span>
                <span className="text-slate-200 font-bold">{RELEASE_CONFIG.filename}</span>
              </div>
              <span className="text-slate-300 font-semibold">{RELEASE_CONFIG.sizeFormatted}</span>
            </div>

            {/* Signing */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
              <div>
                <span className="text-[10px] text-slate-500 uppercase block mb-1 font-sans">
                  Signing Verification
                </span>
                <span className="text-emerald-400 font-semibold">
                  {RELEASE_CONFIG.signatureScheme}
                </span>
              </div>
              <FileCheck className="w-4 h-4 text-emerald-400" />
            </div>

            {/* Official Download URL */}
            <div className="md:col-span-2 p-4 rounded-xl bg-slate-950/70 border border-slate-800/80">
              <div className="flex items-center justify-between mb-1.5 font-sans">
                <span className="text-[10px] text-slate-400 uppercase font-semibold">
                  Official Canonical Download Endpoint
                </span>
                <span className="text-[10px] text-emerald-400 font-mono">
                  Stable Route
                </span>
              </div>
              <div className="flex items-center gap-2 p-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300">
                <span className="flex-1 truncate select-all">{fullDownloadUrl}</span>
                <button
                  type="button"
                  onClick={() => copyToClipboard(fullDownloadUrl, 'dl-url')}
                  className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-white flex items-center gap-1 shrink-0"
                >
                  {copiedField === 'dl-url' ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-emerald-400" />
                      <span className="text-emerald-400">Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5 text-slate-400" />
                      <span>Copy URL</span>
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* Full SHA-256 Checksum */}
            <div className="md:col-span-2 p-4 rounded-xl bg-slate-950 border border-slate-800">
              <div className="flex items-center justify-between mb-1.5 font-sans">
                <span className="text-[10px] text-slate-400 uppercase font-semibold">
                  SHA-256 Cryptographic Checksum (sha256sum)
                </span>
                <span className="text-[10px] text-emerald-400 font-mono">
                  Computed from verified APK
                </span>
              </div>
              <div className="text-xs text-emerald-300 break-all select-all p-3 rounded-lg bg-slate-900 border border-slate-800 font-mono">
                {RELEASE_CONFIG.sha256}
              </div>
            </div>
          </div>

          {/* Terminal Command Verification */}
          <div className="mt-8 pt-6 border-t border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4 text-xs text-slate-400">
            <div className="flex items-center gap-2 font-mono">
              <Terminal className="w-4 h-4 text-slate-500" />
              <span>Verify via terminal:</span>
              <code className="text-slate-300 bg-slate-950 px-2.5 py-1 rounded border border-slate-800 select-all">
                sha256sum sanchat-release.apk
              </code>
            </div>
            <a
              href={RELEASE_CONFIG.githubReleaseUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-emerald-400 hover:underline font-sans"
            >
              <span>View GitHub Release</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
