'use client';

import React from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { ShieldCheck, Smartphone, Lock, Terminal } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="bg-obsidian text-slate-400 text-xs border-t border-slate-800 pt-16 pb-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-10 pb-12 border-b border-slate-800">
          {/* Brand & Purpose (2 cols) */}
          <div className="lg:col-span-2 flex flex-col items-start">
            <Link href="/" className="flex items-center gap-3 mb-4 group">
              <div className="relative w-9 h-9 rounded-xl overflow-hidden ring-1 ring-slate-700 group-hover:ring-emeraldAccent transition-all">
                <Image
                  src="/assets/branding/sanchat_icon.png"
                  alt="Sanchat Logo"
                  fill
                  className="object-contain"
                />
              </div>
              <div className="flex flex-col">
                <span className="font-extrabold text-lg tracking-tight text-white">
                  SANCHAT
                </span>
                <span className="text-[10px] font-mono text-emerald-400">
                  WEALTH COCKPIT
                </span>
              </div>
            </Link>

            <p className="text-slate-400 text-sm leading-relaxed max-w-sm mb-4">
              Your money. Your control. Intelligent on-device personal finance, autonomous UPI tracking, multi-vault savings, and private 1-on-1 messaging.
            </p>

            <div className="flex items-center gap-2 text-[11px] font-mono text-slate-300 bg-slate-900 px-3 py-1.5 rounded-lg border border-slate-800">
              <ShieldCheck className="w-4 h-4 text-emeraldAccent shrink-0" />
              <span>Android 16 Ready • Target SDK 36</span>
            </div>
          </div>

          {/* Column 2: Product */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Product
            </h4>
            <ul className="space-y-2.5">
              <li>
                <a href="#features" className="hover:text-white transition-colors">
                  Autonomous Tracking
                </a>
              </li>
              <li>
                <a href="#how-it-works" className="hover:text-white transition-colors">
                  System Architecture
                </a>
              </li>
              <li>
                <a href="#vaults" className="hover:text-white transition-colors">
                  Multi-Vault Savings
                </a>
              </li>
              <li>
                <a href="#runway" className="hover:text-white transition-colors">
                  Daily Spending Runway
                </a>
              </li>
              <li>
                <a href="#download" className="hover:text-white transition-colors">
                  Download Android APK
                </a>
              </li>
            </ul>
          </div>

          {/* Column 3: Trust & Legal */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Trust & Legal
            </h4>
            <ul className="space-y-2.5">
              <li>
                <Link href="/privacy" className="hover:text-white transition-colors">
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link href="/terms" className="hover:text-white transition-colors">
                  Terms of Service
                </Link>
              </li>
              <li>
                <a href="#privacy" className="hover:text-white transition-colors">
                  Data Safety Principles
                </a>
              </li>
              <li>
                <a href="#faq" className="hover:text-white transition-colors">
                  FAQ & Permissions
                </a>
              </li>
              <li>
                <a href="#verification" className="hover:text-white transition-colors">
                  Cryptographic Verification
                </a>
              </li>
            </ul>
          </div>

          {/* Column 4: Engineering & Technical */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Package Info
            </h4>
            <div className="space-y-2 font-mono text-[11px]">
              <div>
                <span className="text-slate-500 block text-[9px] uppercase font-sans">
                  Package ID
                </span>
                <span className="text-slate-200 break-all">com.aistudio.sanchay.savtrkr</span>
              </div>
              <div>
                <span className="text-slate-500 block text-[9px] uppercase font-sans">
                  Latest Build
                </span>
                <span className="text-emerald-400">v1.0.0+1 (API 36)</span>
              </div>
              <div>
                <span className="text-slate-500 block text-[9px] uppercase font-sans">
                  Release SHA-256
                </span>
                <span className="text-slate-400 break-all select-all text-[10px]">
                  d43668da9f1f...5c49
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-[11px] text-slate-500">
          <div>
            © 2026 Sanchat. All rights reserved. Designed for responsible fintech privacy.
          </div>
          <div className="flex items-center gap-4">
            <Link href="/privacy" className="hover:text-slate-300 transition-colors">
              Privacy
            </Link>
            <span>•</span>
            <Link href="/terms" className="hover:text-slate-300 transition-colors">
              Terms
            </Link>
            <span>•</span>
            <a href="#verification" className="hover:text-slate-300 transition-colors font-mono">
              SHA256SUMS
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
