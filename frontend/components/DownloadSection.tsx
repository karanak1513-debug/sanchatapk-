'use client';

import React, { useState } from 'react';
import {
  ArrowDownToLine,
  Smartphone,
  ShieldCheck,
  CheckCircle2,
  Clock,
  Copy,
  Check,
  ExternalLink,
} from 'lucide-react';
import DynamicQrCode from './DynamicQrCode';
import ReleaseVerificationCard from './ReleaseVerificationCard';
import { RELEASE_CONFIG } from '@/config/release';
import Link from 'next/link';

export default function DownloadSection() {
  const [downloadStarted, setDownloadStarted] = useState(false);
  const [copiedField, setCopiedField] = useState<string | null>(null);

  const copyToClipboard = (text: string, field: string) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      setCopiedField(field);
      setTimeout(() => setCopiedField(null), 2500);
    }
  };

  const handleDownloadClick = () => {
    setDownloadStarted(true);
    // Navigates directly to the official /download route which handles the server-side release redirect
    window.location.href = RELEASE_CONFIG.downloadRoute;

    setTimeout(() => {
      setDownloadStarted(false);
    }, 6000);
  };

  const fullDownloadUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}${RELEASE_CONFIG.downloadRoute}`
      : `${RELEASE_CONFIG.officialDomain}${RELEASE_CONFIG.downloadRoute}`;

  return (
    <section id="download" className="py-20 md:py-28 bg-[#F8FAFC] border-t border-cardBorder relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-14">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-white border border-cardBorder text-slateText text-xs font-mono font-medium mb-3 shadow-subtle">
            OFFICIAL SANCHAT RELEASE
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Take Sanchat with you.
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Download the verified release APK directly onto your Android device or scan the dynamic QR code with your phone camera.
          </p>
        </div>

        {/* Action Grid: Direct Download Buttons + Dynamic QR Code */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start mb-14">
          {/* Left Column: Direct Download Actions & Installation Guide */}
          <div className="lg:col-span-7 bg-white rounded-3xl p-6 sm:p-10 border border-cardBorder shadow-cockpit flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between pb-6 mb-6 border-b border-cardBorder">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-2xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-darkEmerald">
                    <Smartphone className="w-6 h-6 text-emeraldAccent" />
                  </div>
                  <div>
                    <h3 className="text-xl font-extrabold text-obsidian">
                      Sanchat for Android
                    </h3>
                    <p className="text-xs text-slateText">
                      Universal Release • {RELEASE_CONFIG.targetSdk}
                    </p>
                  </div>
                </div>
                <span className="text-xs font-mono font-semibold px-2.5 py-1 rounded-full bg-emerald-50 text-darkEmerald border border-emerald-200">
                  v{RELEASE_CONFIG.version}
                </span>
              </div>

              {/* Download Buttons Stack */}
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 mb-4">
                {/* Primary APK Download Button targeting /download */}
                <button
                  type="button"
                  onClick={handleDownloadClick}
                  className="flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-2xl bg-obsidian text-white font-bold text-base hover:bg-deepNavy active:scale-95 transition-all shadow-md focus:outline-none focus:ring-2 focus:ring-emeraldAccent group"
                >
                  <ArrowDownToLine className="w-5 h-5 text-emeraldAccent group-hover:translate-y-0.5 transition-transform" />
                  <span>Download Sanchat APK</span>
                  <span className="text-xs font-mono font-normal text-slate-300 bg-slate-800 px-2 py-0.5 rounded-md">
                    {RELEASE_CONFIG.sizeFormatted.split(' ')[0]} {RELEASE_CONFIG.sizeFormatted.split(' ')[1]}
                  </span>
                </button>

                {/* Google Play Status Indicator */}
                <div className="flex-1 flex items-center justify-center gap-2.5 px-6 py-4 rounded-2xl bg-slate-100 text-slate-500 font-semibold text-sm border border-slate-200 cursor-not-allowed select-none">
                  <Clock className="w-4 h-4 text-slate-400" />
                  <span>Google Play — In Review</span>
                </div>
              </div>

              {/* Secondary Action Row: Copy URL & Copy Hash */}
              <div className="flex items-center gap-3 mb-6">
                <button
                  type="button"
                  onClick={() => copyToClipboard(fullDownloadUrl, 'dl-btn')}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 hover:bg-slate-100 text-xs font-medium text-slate-700 transition-colors"
                >
                  {copiedField === 'dl-btn' ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-darkEmerald" />
                      <span className="text-darkEmerald font-semibold">URL Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5 text-slate-400" />
                      <span>Copy Download URL</span>
                    </>
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => copyToClipboard(RELEASE_CONFIG.sha256, 'hash-btn')}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 hover:bg-slate-100 text-xs font-medium text-slate-700 transition-colors"
                >
                  {copiedField === 'hash-btn' ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-darkEmerald" />
                      <span className="text-darkEmerald font-semibold">SHA-256 Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5 text-slate-400" />
                      <span>Copy SHA-256</span>
                    </>
                  )}
                </button>
              </div>

              {/* Download status toast */}
              {downloadStarted && (
                <div className="p-3.5 mb-6 rounded-xl bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs flex items-center gap-2 animate-in fade-in duration-300">
                  <CheckCircle2 className="w-4 h-4 text-emeraldAccent shrink-0" />
                  <span>
                    Official download initiating via <code className="font-mono font-bold">/download</code> ({RELEASE_CONFIG.filename}, {RELEASE_CONFIG.sizeFormatted.split(' ')[0]} {RELEASE_CONFIG.sizeFormatted.split(' ')[1]}). Check browser notification drawer if prompt does not appear immediately.
                  </span>
                </div>
              )}

              {/* Android Sideloading Instructions */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 text-xs text-slate-600 space-y-2">
                <div className="font-bold text-slate-800 flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4 text-darkEmerald" />
                  <span>Legitimate Android Installation Guide</span>
                </div>
                <p className="leading-relaxed">
                  1. Tap <strong>Download Sanchat APK</strong> to retrieve the official package.
                </p>
                <p className="leading-relaxed">
                  2. Open the downloaded file from your notifications or Files app. If Android prompts for &ldquo;Install unknown apps&rdquo;, allow access for your browser.
                </p>
                <p className="leading-relaxed">
                  3. Verify that the file checksum matches our official SHA-256 hash below before finalizing installation.
                </p>
              </div>
            </div>

            <div className="pt-6 mt-6 border-t border-cardBorder flex flex-wrap items-center justify-between text-xs text-slateText">
              <span>Google Play Submission in Preparation</span>
              <Link href="/verification" className="text-darkEmerald font-semibold hover:underline">
                Full Cryptographic Verification Center →
              </Link>
            </div>
          </div>

          {/* Right Column: Dynamic Scannable QR Code */}
          <div className="lg:col-span-5">
            <DynamicQrCode />
          </div>
        </div>

        {/* Cryptographic Release Verification Technical Panel */}
        <ReleaseVerificationCard />
      </div>
    </section>
  );
}
