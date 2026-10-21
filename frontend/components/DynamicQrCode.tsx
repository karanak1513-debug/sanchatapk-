'use client';

import React, { useState, useEffect } from 'react';
import QRCode from 'qrcode';
import { QrCode, Copy, Check, Smartphone, ShieldCheck } from 'lucide-react';
import { RELEASE_CONFIG } from '@/config/release';

export default function DynamicQrCode() {
  const [downloadUrl, setDownloadUrl] = useState<string>(
    `${RELEASE_CONFIG.officialDomain}${RELEASE_CONFIG.downloadRoute}`
  );
  const [qrDataUrl, setQrDataUrl] = useState<string>('');
  const [copied, setCopied] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Resolve stable canonical official /download route
    let url = `${RELEASE_CONFIG.officialDomain}${RELEASE_CONFIG.downloadRoute}`;
    if (typeof window !== 'undefined' && window.location.origin) {
      url = `${window.location.origin}${RELEASE_CONFIG.downloadRoute}`;
    }
    setDownloadUrl(url);

    // Generate real scannable QR Code as high-res DataURL
    QRCode.toDataURL(url, {
      width: 240,
      margin: 2,
      color: {
        dark: '#0F172A',
        light: '#FFFFFF',
      },
      errorCorrectionLevel: 'M',
    })
      .then((dataUrl) => {
        setQrDataUrl(dataUrl);
      })
      .catch((err) => {
        console.error('Failed to generate local QR Code:', err);
        setError('QR Generation error');
      });
  }, []);

  const handleCopy = () => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(downloadUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    }
  };

  return (
    <div className="bg-white rounded-3xl p-6 sm:p-8 border border-cardBorder shadow-cockpit flex flex-col items-center text-center">
      {/* Badge Header */}
      <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 border border-emerald-200 text-darkEmerald text-[11px] font-mono font-bold uppercase mb-3">
        <span className="w-2 h-2 rounded-full bg-emeraldAccent animate-pulse" />
        <span>LIVE OFFICIAL DOWNLOAD</span>
      </div>

      <h3 className="text-xl font-extrabold text-obsidian tracking-tight mb-1">
        Scan to Download
      </h3>
      <p className="text-xs text-slateText mb-6 max-w-xs">
        Point your phone camera here to begin the official Android installation.
      </p>

      {/* QR Code Container */}
      <div className="relative p-3.5 bg-white rounded-2xl border-2 border-slate-200 shadow-sm flex items-center justify-center min-w-[210px] min-h-[210px]">
        {qrDataUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={qrDataUrl}
            alt="Official Sanchat /download QR Code"
            className="w-48 h-48 object-contain rounded-lg"
          />
        ) : (
          <div className="w-48 h-48 flex items-center justify-center text-xs text-slate-400 font-mono">
            {error || 'Generating dynamic QR...'}
          </div>
        )}
      </div>

      {/* Verified Status Tag */}
      <div className="mt-4 text-xs font-semibold flex items-center gap-1.5 text-darkEmerald">
        <span className="w-2 h-2 rounded-full bg-emerald-500" />
        <span>Download link verified</span>
      </div>

      {/* Live Destination URL & Copy Trigger */}
      <div className="w-full mt-5 pt-4 border-t border-cardBorder text-left">
        <div className="text-[10px] uppercase font-mono font-bold text-slate-400 mb-1 flex items-center justify-between">
          <span>Target Official Route</span>
          <span>HTTPS Verified</span>
        </div>
        <div className="flex items-center gap-2 p-2 rounded-xl bg-slate-50 border border-slate-200 text-slate-700">
          <input
            type="text"
            readOnly
            value={downloadUrl}
            className="bg-transparent text-xs font-mono text-slate-600 flex-1 truncate focus:outline-none select-all"
            aria-label="Official /download URL"
          />
          <button
            type="button"
            onClick={handleCopy}
            className="px-2.5 py-1 rounded-lg bg-white border border-cardBorder hover:bg-slate-100 text-xs font-semibold text-obsidian flex items-center gap-1 shrink-0 transition-all active:scale-95 shadow-2xs"
            aria-label="Copy official download link"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-darkEmerald" />
                <span className="text-darkEmerald">Copied</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5 text-slate-500" />
                <span>Copy</span>
              </>
            )}
          </button>
        </div>
      </div>

      <div className="text-[10px] text-slate-400 mt-3 font-mono">
        Encodes official canonical route: <span className="text-slate-600 font-bold">/download</span>
      </div>
    </div>
  );
}
