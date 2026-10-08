'use client';

import React, { useState } from 'react';
import {
  ShieldCheck,
  Copy,
  Check,
  Terminal,
  FileCode,
  FileCheck,
} from 'lucide-react';

export default function ReleaseVerificationCard() {
  const [copiedField, setCopiedField] = useState<string | null>(null);

  const releaseMetadata = {
    version: '1.0.0+1',
    packageId: 'com.aistudio.sanchay.savtrkr',
    targetSdk: 'Android 16 (API 36)',
    minSdk: 'Android 8.0 (API 26)',
    filename: 'sanchat-release.apk',
    sizeFormatted: '62.4 MB (65,404,536 bytes)',
    sha256: 'd43668da9f1f73de86a731326f0fe5d72d16581754530ff2c7fbcc693ab45c49',
    signatureScheme: 'APK Signature Scheme v2 (Signed)',
    signerSubject: 'CN=Sanchay, OU=Fintech, O=Sanchay, L=Delhi, ST=Delhi, C=IN',
  };

  const copyToClipboard = (text: string, field: string) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      setCopiedField(field);
      setTimeout(() => setCopiedField(null), 2500);
    }
  };

  return (
    <div
      id="verification"
      className="bg-slate-900 rounded-3xl p-6 sm:p-10 text-white border border-slate-800 shadow-2xl relative overflow-hidden"
    >
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-950 border border-emerald-700 flex items-center justify-center text-emerald-400">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-slate-100 flex items-center gap-2">
              <span>Cryptographic Release Verification</span>
              <span className="text-[10px] font-mono font-semibold px-2 py-0.5 rounded-full bg-emerald-900/60 text-emerald-400 border border-emerald-700">
                PROD
              </span>
            </h3>
            <p className="text-xs text-slate-400">
              Independently verifiable Android release checksums
            </p>
          </div>
        </div>

        <button
          type="button"
          onClick={() => copyToClipboard(releaseMetadata.sha256, 'all-hash')}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs font-mono text-slate-200 border border-slate-700 transition-all self-start sm:self-auto"
        >
          {copiedField === 'all-hash' ? (
            <>
              <Check className="w-3.5 h-3.5 text-emerald-400" />
              <span className="text-emerald-400">SHA-256 Copied</span>
            </>
          ) : (
            <>
              <Copy className="w-3.5 h-3.5 text-slate-400" />
              <span>Copy SHA-256 Hash</span>
            </>
          )}
        </button>
      </div>

      {/* Grid of Technical Fields */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 font-mono text-xs">
        {/* Package ID */}
        <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
          <div>
            <span className="text-[10px] text-slate-500 uppercase block mb-0.5 font-sans">
              Package ID
            </span>
            <span className="text-slate-200 font-bold">{releaseMetadata.packageId}</span>
          </div>
          <button
            type="button"
            onClick={() => copyToClipboard(releaseMetadata.packageId, 'pkg')}
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

        {/* Version & Build */}
        <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
          <div>
            <span className="text-[10px] text-slate-500 uppercase block mb-0.5 font-sans">
              Version & Target SDK
            </span>
            <span className="text-emerald-400 font-bold">
              v{releaseMetadata.version} • {releaseMetadata.targetSdk}
            </span>
          </div>
          <span className="text-[10px] text-slate-400 px-2 py-0.5 rounded bg-slate-900 border border-slate-800">
            Min SDK 26
          </span>
        </div>

        {/* File Details */}
        <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
          <div>
            <span className="text-[10px] text-slate-500 uppercase block mb-0.5 font-sans">
              Official Binary File
            </span>
            <span className="text-slate-200">{releaseMetadata.filename}</span>
          </div>
          <span className="text-slate-300 font-semibold">{releaseMetadata.sizeFormatted}</span>
        </div>

        {/* Signature Status */}
        <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between">
          <div>
            <span className="text-[10px] text-slate-500 uppercase block mb-0.5 font-sans">
              Release Signing Scheme
            </span>
            <span className="text-emerald-400 font-semibold">
              {releaseMetadata.signatureScheme}
            </span>
          </div>
          <FileCheck className="w-4 h-4 text-emerald-400" />
        </div>

        {/* Full SHA-256 Hash Display (Spans 2 cols) */}
        <div className="md:col-span-2 p-3.5 rounded-xl bg-slate-950 border border-slate-800">
          <div className="flex items-center justify-between mb-1.5 font-sans">
            <span className="text-[10px] text-slate-400 uppercase font-semibold">
              Authentic SHA-256 Checksum (SHA256SUMS)
            </span>
            <span className="text-[10px] text-emerald-400 font-mono">
              Computed from verified APK
            </span>
          </div>
          <div className="text-xs text-emerald-300 break-all select-all p-2 rounded bg-slate-900 border border-slate-800 font-mono">
            {releaseMetadata.sha256}
          </div>
        </div>
      </div>

      {/* Terminal Verification Helper Command */}
      <div className="mt-6 pt-4 border-t border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs text-slate-400">
        <div className="flex items-center gap-2 font-mono">
          <Terminal className="w-4 h-4 text-slate-500" />
          <span>Verify via terminal:</span>
          <code className="text-slate-300 bg-slate-950 px-2 py-0.5 rounded border border-slate-800 select-all">
            sha256sum sanchat-release.apk
          </code>
        </div>
        <span className="text-[11px] font-sans text-slate-500">
          Never trust unverified binaries. Checksum match guarantees untampered delivery.
        </span>
      </div>
    </div>
  );
}
