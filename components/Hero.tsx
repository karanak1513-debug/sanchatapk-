'use client';

import React from 'react';
import {
  ArrowDownToLine,
  ChevronDown,
  ShieldCheck,
  Smartphone,
  Cpu,
  Lock,
  Sparkles,
} from 'lucide-react';
import MobileCockpit from './MobileCockpit';

export default function Hero() {
  return (
    <section className="relative pt-28 pb-16 md:pt-36 md:pb-24 overflow-hidden bg-emerald-atmosphere bg-subtle-dots">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">
          {/* Left Column: Headlines & Actions */}
          <div className="lg:col-span-7 flex flex-col items-start text-left z-10">
            {/* Feature Pill Badge */}
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs sm:text-sm font-semibold mb-6 shadow-sm">
              <span className="flex h-2 w-2 rounded-full bg-emeraldAccent animate-pulse" />
              <span>Android 16 Ready</span>
              <span className="text-emerald-300">•</span>
              <span>Autonomous UPI Tracking</span>
              <span className="text-emerald-300">•</span>
              <span>Privacy First</span>
            </div>

            {/* Main Headline */}
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-obsidian tracking-tight leading-[1.08] mb-6">
              Master Your Money.{' '}
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-600 via-emeraldAccent to-darkEmerald">
                Build Real Wealth.
              </span>{' '}
              In Total Calm.
            </h1>

            {/* Supporting Subtext */}
            <p className="text-lg sm:text-xl text-slateText max-w-2xl leading-relaxed mb-8">
              Track spending, build discipline, and understand your safe financial runway in real-time
              without turning your daily life into a tedious manual spreadsheet.
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 w-full sm:w-auto mb-10">
              <a
                href="#download"
                className="inline-flex items-center justify-center gap-3 px-7 py-4 rounded-2xl bg-obsidian text-white font-bold text-base hover:bg-deepNavy active:scale-95 transition-all shadow-lg hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-emeraldAccent group"
              >
                <ArrowDownToLine className="w-5 h-5 text-emeraldAccent group-hover:translate-y-0.5 transition-transform" />
                <span>Download Sanchat APK</span>
                <span className="text-xs font-mono font-normal text-slate-300 bg-slate-800 px-2 py-0.5 rounded-md">
                  62.4 MB
                </span>
              </a>

              <a
                href="#vaults"
                className="inline-flex items-center justify-center gap-2 px-6 py-4 rounded-2xl bg-white text-obsidian font-semibold text-base border border-cardBorder hover:bg-lightSlate hover:border-slate-300 active:scale-95 transition-all shadow-sm focus:outline-none focus:ring-2 focus:ring-emeraldAccent"
              >
                <span>Explore Vault System</span>
                <ChevronDown className="w-4 h-4 text-slateText" />
              </a>
            </div>

            {/* Production Readiness & Security Badges */}
            <div className="w-full pt-6 border-t border-cardBorder/80 grid grid-cols-2 sm:grid-cols-3 gap-4">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-emerald-50 border border-emerald-100 flex items-center justify-center text-darkEmerald">
                  <Smartphone className="w-4 h-4 text-emeraldAccent" />
                </div>
                <div>
                  <div className="text-xs font-bold text-obsidian font-mono">v1.0.0+1</div>
                  <div className="text-[11px] text-slateText">API 36 Universal</div>
                </div>
              </div>

              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-emerald-50 border border-emerald-100 flex items-center justify-center text-darkEmerald">
                  <Cpu className="w-4 h-4 text-emeraldAccent" />
                </div>
                <div>
                  <div className="text-xs font-bold text-obsidian">On-Device Parsing</div>
                  <div className="text-[11px] text-slateText">Zero Bank Logins</div>
                </div>
              </div>

              <div className="flex items-center gap-2.5 col-span-2 sm:col-span-1">
                <div className="w-8 h-8 rounded-lg bg-emerald-50 border border-emerald-100 flex items-center justify-center text-darkEmerald">
                  <ShieldCheck className="w-4 h-4 text-emeraldAccent" />
                </div>
                <div>
                  <div className="text-xs font-bold text-obsidian">SHA-256 Signed</div>
                  <div className="text-[11px] text-slateText">Verified Release</div>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Interactive Mobile Cockpit */}
          <div className="lg:col-span-5 flex justify-center lg:justify-end">
            <MobileCockpit />
          </div>
        </div>
      </div>
    </section>
  );
}
