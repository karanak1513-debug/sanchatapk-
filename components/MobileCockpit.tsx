'use client';

import React, { useState, useRef } from 'react';
import Image from 'next/image';
import {
  Bell,
  Settings,
  Shield,
  Flame,
  ArrowUpRight,
  TrendingUp,
  Sparkles,
  Layers,
  Repeat,
  PieChart,
  User,
  CheckCircle2,
} from 'lucide-react';

export default function MobileCockpit() {
  const [activeTab, setActiveTab] = useState<'cockpit' | 'vaults' | 'ledger'>('cockpit');
  const [dailyQuota, setDailyQuota] = useState(1500);
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const cardRef = useRef<HTMLDivElement>(null);

  // Safe calculated runway days
  const safeDays = Math.round(33000 / dailyQuota);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!cardRef.current) return;
    const rect = cardRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    // Dampened tilt values
    setTilt({
      x: -(y / rect.height) * 10,
      y: (x / rect.width) * 10,
    });
  };

  const handleMouseLeave = () => {
    setTilt({ x: 0, y: 0 });
  };

  return (
    <div className="relative w-full max-w-[400px] mx-auto select-none">
      {/* Ambient background glows */}
      <div className="absolute -top-10 -right-10 w-64 h-64 bg-emerald-200/50 rounded-full blur-3xl pointer-events-none -z-10" />
      <div className="absolute -bottom-10 -left-10 w-64 h-64 bg-slate-200/60 rounded-full blur-3xl pointer-events-none -z-10" />

      {/* Floating Badge 1: Discipline Streak */}
      <div className="hidden sm:flex absolute -top-5 -left-8 z-30 items-center gap-2 px-3 py-2 bg-white/95 backdrop-blur-md rounded-2xl shadow-cockpit border border-cardBorder animate-float-slow">
        <div className="w-8 h-8 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600">
          <Flame className="w-4 h-4 fill-amber-500" />
        </div>
        <div>
          <div className="text-xs font-bold text-obsidian flex items-center gap-1">
            5-Day Streak
            <Sparkles className="w-3 h-3 text-emeraldAccent" />
          </div>
          <div className="text-[10px] text-slateText">Discipline Intact</div>
        </div>
      </div>

      {/* Floating Badge 2: Privacy Guarantee */}
      <div className="hidden sm:flex absolute top-1/2 -right-8 z-30 items-center gap-2 px-3 py-2 bg-white/95 backdrop-blur-md rounded-2xl shadow-cockpit border border-cardBorder">
        <div className="w-8 h-8 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-darkEmerald">
          <Shield className="w-4 h-4 text-emeraldAccent" />
        </div>
        <div>
          <div className="text-xs font-bold text-obsidian">No Bank Passwords</div>
          <div className="text-[10px] text-slateText">100% On-Device SMS Parser</div>
        </div>
      </div>

      {/* Outer Phone Shell */}
      <div
        ref={cardRef}
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
        style={{
          transform: `perspective(1000px) rotateX(${tilt.x}deg) rotateY(${tilt.y}deg)`,
          transition: 'transform 0.15s ease-out',
        }}
        className="relative rounded-[44px] p-3.5 bg-gradient-to-b from-slate-800 via-obsidian to-slate-900 shadow-2xl ring-1 ring-slate-700/60"
      >
        {/* Phone Bezel Speaker Notch */}
        <div className="absolute top-6 left-1/2 -translate-x-1/2 w-28 h-4 bg-obsidian rounded-full z-40 flex items-center justify-center">
          <div className="w-10 h-1 bg-slate-700 rounded-full" />
        </div>

        {/* Screen Container */}
        <div className="relative rounded-[36px] bg-[#F8FAFC] overflow-hidden text-obsidian border border-slate-200/50 flex flex-col min-h-[640px]">
          {/* Top Status Bar */}
          <div className="pt-3 px-6 pb-2 flex items-center justify-between text-slate-500 text-[11px] font-mono select-none">
            <span className="font-semibold text-slate-700">09:41</span>
            <div className="flex items-center gap-1.5">
              <span className="text-[9px] font-bold px-1 py-0.5 rounded bg-slate-200 text-slate-700">5G</span>
              <div className="w-5 h-2.5 rounded-sm border border-slate-500 p-0.5 flex items-center">
                <div className="h-full w-3/4 bg-emeraldAccent rounded-2xs" />
              </div>
            </div>
          </div>

          {/* Sanchat App Header */}
          <div className="px-5 py-2.5 flex items-center justify-between border-b border-slate-200/60 bg-white/70 backdrop-blur-sm">
            <div className="flex items-center gap-2">
              <div className="relative w-7 h-7 rounded-lg overflow-hidden border border-slate-200">
                <Image
                  src="/assets/branding/sanchat_icon.png"
                  alt="App Icon"
                  fill
                  className="object-cover"
                />
              </div>
              <div className="flex flex-col">
                <span className="text-[9px] font-bold tracking-wider uppercase text-darkEmerald">
                  Sanchat Wealth
                </span>
                <span className="text-xs font-bold text-obsidian leading-none">
                  Dashboard Cockpit
                </span>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="w-7 h-7 rounded-full bg-slate-100 flex items-center justify-center text-slate-600">
                <Bell className="w-3.5 h-3.5" />
              </div>
              <div className="w-7 h-7 rounded-full bg-slate-100 flex items-center justify-center text-slate-600">
                <Settings className="w-3.5 h-3.5" />
              </div>
            </div>
          </div>

          {/* App Body Content */}
          <div className="p-4 flex-1 flex flex-col gap-3 overflow-y-auto">
            {/* Greeting & Live Sync indicator */}
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-extrabold text-obsidian tracking-tight">Good morning, Karan</h3>
                <div className="flex items-center gap-1.5 mt-0.5">
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emeraldAccent opacity-75" />
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-emeraldAccent" />
                  </span>
                  <span className="text-[10px] font-semibold text-darkEmerald">Live Sync Active</span>
                </div>
              </div>
              <span className="text-[10px] font-mono text-slateText px-2 py-0.5 bg-slate-100 rounded-md border border-slate-200">
                Oct 2026
              </span>
            </div>

            {/* Primary Reserve Target Card */}
            <div className="relative rounded-2xl bg-white p-4 shadow-sm border border-cardBorder overflow-hidden">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-obsidian">Master Reserve Target</span>
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-50 text-darkEmerald border border-emerald-200">
                  Auto-Pacing On
                </span>
              </div>

              <div className="flex items-baseline justify-between mb-2">
                <div>
                  <span className="text-[10px] font-medium text-slateText uppercase tracking-wider block">
                    Current Accumulation
                  </span>
                  <span className="text-xl font-extrabold text-obsidian font-mono">
                    ₹30,000
                  </span>
                </div>
                <div className="text-right">
                  <span className="text-[10px] font-medium text-slateText uppercase tracking-wider block">
                    Target Cap
                  </span>
                  <span className="text-xs font-bold text-slateText font-mono">
                    ₹1,00,000
                  </span>
                </div>
              </div>

              {/* Progress bar */}
              <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden mb-2">
                <div
                  className="bg-gradient-to-r from-emerald-500 to-emerald-600 h-full rounded-full transition-all duration-500"
                  style={{ width: '30%' }}
                />
              </div>
              <div className="flex justify-between items-center text-[10px] text-slateText">
                <span className="font-semibold text-darkEmerald">30% Paced</span>
                <span>₹70,000 Remaining</span>
              </div>
            </div>

            {/* Daily Spending Runway Interactive Card */}
            <div className="rounded-2xl bg-gradient-to-br from-obsidian to-slate-900 text-white p-4 shadow-md">
              <div className="flex items-center justify-between mb-1.5">
                <div className="flex items-center gap-1.5">
                  <TrendingUp className="w-3.5 h-3.5 text-emeraldAccent" />
                  <span className="text-xs font-bold text-slate-200">Daily Spending Runway</span>
                </div>
                <span className="text-[10px] font-mono px-2 py-0.5 bg-emerald-950 text-emerald-400 rounded border border-emerald-800">
                  Safe Zone
                </span>
              </div>

              <div className="flex items-baseline justify-between my-2">
                <div>
                  <div className="text-2xl font-extrabold font-mono text-white tracking-tight">
                    ₹{dailyQuota.toLocaleString('en-IN')}
                    <span className="text-xs font-normal text-slate-400 ml-1">/ day</span>
                  </div>
                  <div className="text-[11px] text-emerald-400 font-medium flex items-center gap-1 mt-0.5">
                    <CheckCircle2 className="w-3 h-3" />
                    <span>{safeDays} Days Safe Runway</span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-[9px] text-slate-400 uppercase tracking-wider block">
                    Net Liquidity
                  </span>
                  <span className="text-sm font-bold font-mono text-slate-200">₹48,500</span>
                </div>
              </div>

              {/* Slider for interactive demonstration */}
              <div className="mt-3 pt-2.5 border-t border-slate-800">
                <div className="flex justify-between items-center text-[10px] text-slate-400 mb-1">
                  <span>Simulate Daily Quota:</span>
                  <span className="font-mono text-emeraldAccent font-semibold">
                    ₹{dailyQuota}/day
                  </span>
                </div>
                <input
                  type="range"
                  min="500"
                  max="3000"
                  step="100"
                  value={dailyQuota}
                  onChange={(e) => setDailyQuota(Number(e.target.value))}
                  className="w-full accent-emeraldAccent cursor-pointer h-1.5 bg-slate-700 rounded-lg"
                  aria-label="Adjust daily spending runway simulation"
                />
              </div>
            </div>

            {/* Recent Transaction Live Feed (Demo) */}
            <div className="rounded-2xl bg-white p-3 shadow-sm border border-cardBorder">
              <div className="flex items-center justify-between mb-2">
                <span className="text-[11px] font-bold text-obsidian">Recent Local Activity</span>
                <span className="text-[9px] text-slateText">Auto-Categorized</span>
              </div>
              <div className="flex items-center justify-between text-xs py-1">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-lg bg-emerald-50 text-darkEmerald flex items-center justify-center font-bold text-[10px]">
                    UPI
                  </div>
                  <div>
                    <div className="font-semibold text-obsidian text-[11px]">HDFC • Swiggy Instamart</div>
                    <div className="text-[9px] text-slateText">Ref #948271 • Today, 08:30</div>
                  </div>
                </div>
                <span className="font-mono font-bold text-rose-600 text-[11px]">-₹380.00</span>
              </div>
            </div>
          </div>

          {/* Bottom App Navigation */}
          <div className="px-3 py-2 bg-white border-t border-slate-200 flex items-center justify-around text-slate-500">
            <button
              onClick={() => setActiveTab('cockpit')}
              className={`flex flex-col items-center gap-0.5 text-[9px] font-semibold ${
                activeTab === 'cockpit' ? 'text-darkEmerald' : 'text-slate-400'
              }`}
            >
              <Repeat className="w-4 h-4" />
              <span>Cockpit</span>
            </button>
            <button
              onClick={() => setActiveTab('vaults')}
              className={`flex flex-col items-center gap-0.5 text-[9px] font-semibold ${
                activeTab === 'vaults' ? 'text-darkEmerald' : 'text-slate-400'
              }`}
            >
              <Layers className="w-4 h-4" />
              <span>Vaults</span>
            </button>
            <button
              onClick={() => setActiveTab('ledger')}
              className={`flex flex-col items-center gap-0.5 text-[9px] font-semibold ${
                activeTab === 'ledger' ? 'text-darkEmerald' : 'text-slate-400'
              }`}
            >
              <PieChart className="w-4 h-4" />
              <span>Ledger</span>
            </button>
            <div className="flex flex-col items-center gap-0.5 text-[9px] font-semibold text-slate-400">
              <User className="w-4 h-4" />
              <span>Profile</span>
            </div>
          </div>
        </div>
      </div>

      {/* Demo disclaimer caption below phone */}
      <div className="text-center mt-3 text-[11px] text-slateText font-medium">
        Interactive Sanchat Cockpit • Values shown for product demonstration
      </div>
    </div>
  );
}
