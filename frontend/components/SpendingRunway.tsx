'use client';

import React, { useState } from 'react';
import {
  TrendingUp,
  AlertCircle,
  CheckCircle2,
  Sliders,
  Calendar,
  Sparkles,
  Shield,
} from 'lucide-react';

export default function SpendingRunway() {
  const [dailyBudget, setDailyBudget] = useState(1500);
  const liquidCash = 45000;

  // Calculated runway days
  const runwayDays = Math.max(1, Math.floor(liquidCash / dailyBudget));

  // Determine health tier
  const isHealthy = runwayDays >= 25;
  const isModerate = runwayDays >= 15 && runwayDays < 25;

  return (
    <section id="runway" className="py-20 md:py-28 bg-white relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mb-14">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs font-mono font-medium mb-3">
            BURN-RATE INTELLIGENCE
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            How much can I{' '}
            <span className="text-darkEmerald">safely spend today?</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Instead of staring at a raw bank balance, Sanchat computes your safe daily spending quota in real-time. Spend under your quota, and your runway dynamically extends.
          </p>
        </div>

        {/* Interactive Runway Cockpit Console */}
        <div className="bg-gradient-to-br from-obsidian via-slate-900 to-slate-950 rounded-3xl p-6 sm:p-12 text-white shadow-2xl border border-slate-800">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
            {/* Left metrics display */}
            <div className="lg:col-span-7 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-3 mb-4">
                  <span className="px-3 py-1 rounded-full text-xs font-mono font-bold bg-emerald-950 text-emerald-400 border border-emerald-700">
                    DYNAMIC RUNWAY ALGORITHM
                  </span>
                  <span className="text-xs text-slate-400">
                    Net Liquid Pool: ₹{liquidCash.toLocaleString('en-IN')} (Demo)
                  </span>
                </div>

                <div className="text-xs uppercase font-mono tracking-wider text-slate-400 mb-1">
                  Today&apos;s Safe Spending Allowance
                </div>

                {/* Big Dynamic Metric */}
                <div className="flex items-baseline gap-3 mb-6">
                  <span className="text-5xl sm:text-6xl font-extrabold font-mono text-emerald-400 tracking-tight">
                    ₹{dailyBudget.toLocaleString('en-IN')}
                  </span>
                  <span className="text-xl sm:text-2xl text-slate-400 font-medium">/ day</span>
                </div>

                {/* Status Indicator */}
                <div className="flex items-center gap-3 p-4 rounded-2xl bg-slate-900/80 border border-slate-800 mb-8">
                  {isHealthy ? (
                    <div className="w-9 h-9 rounded-xl bg-emerald-950 border border-emerald-600 flex items-center justify-center text-emerald-400 shrink-0">
                      <CheckCircle2 className="w-5 h-5" />
                    </div>
                  ) : isModerate ? (
                    <div className="w-9 h-9 rounded-xl bg-amber-950 border border-amber-600 flex items-center justify-center text-amber-400 shrink-0">
                      <Sparkles className="w-5 h-5" />
                    </div>
                  ) : (
                    <div className="w-9 h-9 rounded-xl bg-rose-950 border border-rose-600 flex items-center justify-center text-rose-400 shrink-0">
                      <AlertCircle className="w-5 h-5" />
                    </div>
                  )}

                  <div>
                    <div className="text-sm font-bold text-slate-100 flex items-center gap-2">
                      <span>{runwayDays} Days of Safe Runway</span>
                      <span className="text-xs font-normal text-slate-400">
                        ({isHealthy ? 'Surplus Pace' : isModerate ? 'Moderate Pace' : 'High Burn'})
                      </span>
                    </div>
                    <div className="text-xs text-slate-400 mt-0.5">
                      At ₹{dailyBudget}/day, your liquidity comfortably outlasts the monthly cycle.
                    </div>
                  </div>
                </div>
              </div>

              {/* Interactive Simulator Slider */}
              <div className="pt-6 border-t border-slate-800/80">
                <div className="flex items-center justify-between text-xs text-slate-300 font-mono mb-2">
                  <span className="flex items-center gap-1.5">
                    <Sliders className="w-3.5 h-3.5 text-emerald-400" />
                    <span>Simulate Daily Quota Adjustment:</span>
                  </span>
                  <span className="font-bold text-emerald-400 text-sm">
                    ₹{dailyBudget} / day
                  </span>
                </div>

                <input
                  type="range"
                  min="600"
                  max="3500"
                  step="100"
                  value={dailyBudget}
                  onChange={(e) => setDailyBudget(Number(e.target.value))}
                  className="w-full accent-emerald-400 cursor-pointer h-2 bg-slate-800 rounded-lg"
                  aria-label="Adjust daily spending quota simulation"
                />

                <div className="flex justify-between text-[11px] text-slate-500 font-mono mt-1.5">
                  <span>₹600 (Lean 75 Days)</span>
                  <span>₹2,000 (Target)</span>
                  <span>₹3,500 (Aggressive 12 Days)</span>
                </div>
              </div>
            </div>

            {/* Right: Visual Ring & Timeline */}
            <div className="lg:col-span-5 flex flex-col items-center justify-center bg-slate-900/60 p-8 rounded-3xl border border-slate-800/80">
              <div className="relative w-56 h-56 flex items-center justify-center">
                {/* SVG Radial Track */}
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 140 140">
                  <circle
                    cx="70"
                    cy="70"
                    r="58"
                    stroke="#1E293B"
                    strokeWidth="12"
                    fill="transparent"
                  />
                  <circle
                    cx="70"
                    cy="70"
                    r="58"
                    stroke="#10B981"
                    strokeWidth="12"
                    strokeDasharray={2 * Math.PI * 58}
                    strokeDashoffset={
                      2 * Math.PI * 58 * (1 - Math.min(runwayDays, 45) / 45)
                    }
                    strokeLinecap="round"
                    fill="transparent"
                    className="transition-all duration-500 ease-out"
                  />
                </svg>

                {/* Center Content */}
                <div className="absolute flex flex-col items-center justify-center text-center">
                  <Calendar className="w-6 h-6 text-emerald-400 mb-1" />
                  <span className="text-4xl font-extrabold font-mono text-white tracking-tight">
                    {runwayDays}
                  </span>
                  <span className="text-[11px] font-mono uppercase tracking-wider text-slate-400">
                    Days Safe
                  </span>
                </div>
              </div>

              <div className="mt-6 text-center text-xs text-slate-400 max-w-xs">
                Zero spreadsheets. Zero manual bookkeeping. Sanchat runs this dynamic calculation locally for every UPI debit.
              </div>
            </div>
          </div>
        </div>

        <div className="text-center mt-4 text-xs text-slateText">
          * Demonstration simulation. Sanchat processes personal financial data strictly on your Android device.
        </div>
      </div>
    </section>
  );
}
