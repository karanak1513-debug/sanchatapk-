'use client';

import React, { useState, useEffect } from 'react';
import Image from 'next/image';
import {
  MessageSquare,
  CheckCheck,
  ShieldCheck,
  Send,
  Zap,
  Layers,
  TrendingUp,
  Cpu,
  Sparkles,
} from 'lucide-react';

export default function FeatureGrid() {
  const [typingDots, setTypingDots] = useState('');

  useEffect(() => {
    const interval = setInterval(() => {
      setTypingDots((prev) => (prev.length < 3 ? prev + '.' : ''));
    }, 450);
    return () => clearInterval(interval);
  }, []);

  return (
    <section id="features" className="py-20 md:py-28 bg-[#F8FAFC] border-y border-cardBorder relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mb-14">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-white border border-cardBorder text-slateText text-xs font-mono font-medium mb-3 shadow-subtle">
            CORE CAPABILITIES
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Engineered for Calm.{' '}
            <span className="text-darkEmerald">Built for Discipline.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Four specialized systems working harmoniously to eliminate anxiety from personal finances and everyday collaboration.
          </p>
        </div>

        {/* Asymmetric 4-Feature Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Feature 1: Autonomous Tracking (Spans 7 cols) */}
          <div className="lg:col-span-7 bg-white rounded-3xl p-6 sm:p-8 border border-cardBorder shadow-sm flex flex-col justify-between">
            <div>
              <div className="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-darkEmerald mb-4">
                <Zap className="w-5 h-5 text-emeraldAccent" />
              </div>
              <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                01 • ZERO MANUAL ENTRY
              </span>
              <h3 className="text-xl sm:text-2xl font-extrabold text-obsidian mt-1 mb-2">
                Autonomous On-Device Transaction Engine
              </h3>
              <p className="text-sm text-slateText leading-relaxed mb-6">
                Never open a spreadsheet again. When bank notifications arrive, Sanchat parses amount, merchant, and reference code locally in under 5 milliseconds.
              </p>
            </div>

            {/* Visual Stream Simulation */}
            <div className="space-y-2 bg-slate-50 p-4 rounded-2xl border border-slate-200">
              <div className="flex items-center justify-between text-xs bg-white p-2.5 rounded-xl border border-slate-200 shadow-2xs">
                <div className="flex items-center gap-2.5">
                  <span className="w-2 h-2 rounded-full bg-emeraldAccent" />
                  <span className="font-bold text-obsidian">HDFC • Swiggy Delivery</span>
                  <span className="text-[10px] text-slate-400 font-mono">UPI Ref #84920</span>
                </div>
                <span className="font-mono font-bold text-rose-600">-₹420.00</span>
              </div>
              <div className="flex items-center justify-between text-xs bg-white p-2.5 rounded-xl border border-slate-200 shadow-2xs">
                <div className="flex items-center gap-2.5">
                  <span className="w-2 h-2 rounded-full bg-emeraldAccent" />
                  <span className="font-bold text-obsidian">SBI • Shell Fuel Station</span>
                  <span className="text-[10px] text-slate-400 font-mono">UPI Ref #19284</span>
                </div>
                <span className="font-mono font-bold text-rose-600">-₹1,200.00</span>
              </div>
              <div className="text-[10px] font-mono text-darkEmerald text-right">
                ✓ SHA-256 Fingerprint Deduplicated
              </div>
            </div>
          </div>

          {/* Feature 2: Multi-Vault Savings (Spans 5 cols) */}
          <div className="lg:col-span-5 bg-white rounded-3xl p-6 sm:p-8 border border-cardBorder shadow-sm flex flex-col justify-between">
            <div>
              <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-200 flex items-center justify-center text-blue-700 mb-4">
                <Layers className="w-5 h-5 text-blue-600" />
              </div>
              <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                02 • ISOLATED TARGETS
              </span>
              <h3 className="text-xl sm:text-2xl font-extrabold text-obsidian mt-1 mb-2">
                Atomic Multi-Vault Savings
              </h3>
              <p className="text-sm text-slateText leading-relaxed mb-6">
                Segregate emergency reserves from travel and equipment goals. Atomic increments prevent race conditions during concurrent sync.
              </p>
            </div>

            {/* Visual Vault Bar */}
            <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-3">
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span>Emergency Fund</span>
                  <span className="font-mono text-darkEmerald">₹65,000 / ₹1,50,000</span>
                </div>
                <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                  <div className="bg-blue-600 h-full rounded-full" style={{ width: '43%' }} />
                </div>
              </div>
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span>Master Reserve Target</span>
                  <span className="font-mono text-darkEmerald">₹30,000 / ₹1,00,000</span>
                </div>
                <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                  <div className="bg-emerald-500 h-full rounded-full" style={{ width: '30%' }} />
                </div>
              </div>
            </div>
          </div>

          {/* Feature 3: Wealth Progression (Spans 5 cols) */}
          <div className="lg:col-span-5 bg-white rounded-3xl p-6 sm:p-8 border border-cardBorder shadow-sm flex flex-col justify-between">
            <div>
              <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-700 mb-4">
                <TrendingUp className="w-5 h-5 text-amber-600" />
              </div>
              <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                03 • DISCIPLINE TRACKING
              </span>
              <h3 className="text-xl sm:text-2xl font-extrabold text-obsidian mt-1 mb-2">
                100-Level Wealth Gamification
              </h3>
              <p className="text-sm text-slateText leading-relaxed mb-6">
                Turn quiet restraint into tangible momentum. Earn XP for every consecutive day your spending remains under your calculated daily runway quota.
              </p>
            </div>

            <div className="p-4 bg-slate-900 text-white rounded-2xl flex items-center justify-between">
              <div>
                <div className="text-[10px] font-mono text-emerald-400 uppercase">Active Status</div>
                <div className="text-base font-extrabold">Tier 3: Gold Grower</div>
                <div className="text-xs text-slate-400 font-mono">Level 42 • 11,250 XP</div>
              </div>
              <div className="w-12 h-12 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400 font-bold font-mono">
                L42
              </div>
            </div>
          </div>

          {/* Feature 4: 1-on-1 Social Chat (Spans 7 cols) */}
          <div className="lg:col-span-7 bg-white rounded-3xl p-6 sm:p-8 border border-cardBorder shadow-sm flex flex-col justify-between">
            <div>
              <div className="w-10 h-10 rounded-xl bg-purple-50 border border-purple-200 flex items-center justify-center text-purple-700 mb-4">
                <MessageSquare className="w-5 h-5 text-purple-600" />
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                  04 • PRIVATE SOCIAL CONNECT
                </span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-purple-100 text-purple-700 font-semibold">
                  Deterministic UID Sync
                </span>
              </div>
              <h3 className="text-xl sm:text-2xl font-extrabold text-obsidian mt-1 mb-2">
                1-on-1 Real-Time Financial Conversations
              </h3>
              <p className="text-sm text-slateText leading-relaxed mb-4">
                Connect directly with people through private 1-on-1 conversations. Real-time Firebase Firestore streams ensure zero lag, while FCM delivers alerts in the background.
              </p>
            </div>

            {/* High-Fidelity Chat Window Mockup */}
            <div className="bg-[#F8FAFC] p-4 rounded-2xl border border-cardBorder">
              {/* Chat Header */}
              <div className="flex items-center justify-between pb-3 mb-3 border-b border-cardBorder">
                <div className="flex items-center gap-2.5">
                  <div className="relative w-8 h-8 rounded-full bg-slate-200 overflow-hidden ring-1 ring-cardBorder">
                    <Image
                      src="/assets/branding/sanchat_icon.png"
                      alt="Peer Avatar"
                      fill
                      className="object-cover"
                    />
                  </div>
                  <div>
                    <div className="text-xs font-bold text-obsidian flex items-center gap-1">
                      <span>Ananya Sharma</span>
                      <ShieldCheck className="w-3.5 h-3.5 text-emeraldAccent fill-emerald-100" />
                    </div>
                    <div className="text-[10px] text-slateText font-mono">@ananya_invests</div>
                  </div>
                </div>
                <span className="text-[10px] font-mono text-darkEmerald bg-emerald-50 px-2 py-0.5 rounded border border-emerald-100 font-semibold">
                  Live Stream
                </span>
              </div>

              {/* Chat Messages */}
              <div className="space-y-2 mb-3">
                <div className="flex justify-start">
                  <div className="max-w-[78%] bg-white p-2.5 rounded-2xl rounded-tl-xs border border-cardBorder shadow-2xs text-xs text-obsidian">
                    <div>Hey! Did you see how Sanchat recalculated the daily runway after the rent debit?</div>
                    <div className="text-[9px] text-slate-400 text-right mt-1">10:14 AM</div>
                  </div>
                </div>

                <div className="flex justify-end">
                  <div className="max-w-[78%] bg-obsidian text-white p-2.5 rounded-2xl rounded-tr-xs shadow-2xs text-xs">
                    <div>Yes! Automatically compensated by shifting my daily quota to ₹1,480. Zero stress.</div>
                    <div className="text-[9px] text-slate-400 text-right mt-1 flex items-center justify-end gap-1">
                      <span>10:15 AM</span>
                      <CheckCheck className="w-3 h-3 text-emeraldAccent" />
                    </div>
                  </div>
                </div>

                {/* Real-time typing animation */}
                <div className="flex justify-start">
                  <div className="bg-white px-3 py-1.5 rounded-full border border-cardBorder text-[11px] text-slate-500 font-mono flex items-center gap-1">
                    <span>Ananya is typing{typingDots}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
