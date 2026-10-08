'use client';

import React, { useState } from 'react';
import {
  Bell,
  Cpu,
  Tag,
  BookOpen,
  TrendingUp,
  ShieldCheck,
  ArrowRight,
  CheckCircle2,
} from 'lucide-react';

export default function MoneyFlow() {
  const [activeStep, setActiveStep] = useState(0);

  const steps = [
    {
      id: 'step-1',
      title: 'Incoming Notification',
      badge: 'Step 01',
      icon: Bell,
      desc: 'Legitimate financial bank SMS headers (HDFC, SBI, ICICI, etc.) are received directly on your Android device.',
      demoSnippet: 'HDFC: "₹500.00 debited from A/c XX1234 on 08-OCT via UPI Ref 928374..."',
      indicatorColor: 'text-blue-500 bg-blue-50 border-blue-200',
    },
    {
      id: 'step-2',
      title: 'Transaction Recognition',
      badge: 'Step 02',
      icon: Cpu,
      desc: 'Defensive 8-rule parsing engine filters promotional noise and extracts debit/credit amounts with account evidence.',
      demoSnippet: 'DEFENSE PASS: Debit ₹500.00 • Marketing check: Clean • Ref: #928374',
      indicatorColor: 'text-amber-500 bg-amber-50 border-amber-200',
    },
    {
      id: 'step-3',
      title: 'Auto-Categorization',
      badge: 'Step 03',
      icon: Tag,
      desc: 'Merchant headers & UPI handles are tagged into clean buckets (Food, Fuel, Utilities, Rent) without cloud surveillance.',
      demoSnippet: 'CATEGORY: Dining & Essentials • Merchant: Swiggy Instamart',
      indicatorColor: 'text-purple-500 bg-purple-50 border-purple-200',
    },
    {
      id: 'step-4',
      title: 'Deterministic Ledger',
      badge: 'Step 04',
      icon: BookOpen,
      desc: 'A cryptographic SHA-256 fingerprint deduplicates every event, ensuring you never double-count an expense.',
      demoSnippet: 'FINGERPRINT: sha256(hdfc:928374:500:20261008) • Deduplicated',
      indicatorColor: 'text-emerald-500 bg-emerald-50 border-emerald-200',
    },
    {
      id: 'step-5',
      title: 'Runway Recalculation',
      badge: 'Step 05',
      icon: TrendingUp,
      desc: 'Your daily safe spending allowance automatically recalculates to keep your month on track without manual math.',
      demoSnippet: 'RUNWAY: ₹1,500/day -> Adjusted to ₹1,480/day (22 Days Safe)',
      indicatorColor: 'text-darkEmerald bg-emerald-50 border-emerald-200',
    },
    {
      id: 'step-6',
      title: 'Vault Allocation',
      badge: 'Step 06',
      icon: ShieldCheck,
      desc: 'Disciplined surpluses route into dedicated multi-vaults with atomic increment tracking and paced targets.',
      demoSnippet: 'VAULT ALLOCATION: Master Reserve Target: ₹30,000 / ₹1,00,000',
      indicatorColor: 'text-emeraldAccent bg-emerald-950 border-emerald-700',
    },
  ];

  return (
    <section id="how-it-works" className="py-20 md:py-28 bg-[#F8FAFC] border-y border-cardBorder relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="max-w-3xl mb-16">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-white border border-cardBorder text-slateText text-xs font-mono font-medium mb-3 shadow-subtle">
            SYSTEM ARCHITECTURE
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Your Money,{' '}
            <span className="text-darkEmerald">Finally in Motion.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            From the exact millisecond your bank triggers a notification to your updated spending runway and long-term savings goals. All computed on-device with zero bank passwords.
          </p>
        </div>

        {/* System Diagram Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* Interactive Step Navigator */}
          <div className="lg:col-span-5 flex flex-col gap-3">
            {steps.map((step, idx) => {
              const StepIcon = step.icon;
              const isSelected = activeStep === idx;
              return (
                <button
                  key={step.id}
                  onClick={() => setActiveStep(idx)}
                  className={`w-full text-left p-4 rounded-2xl border transition-all flex items-start gap-3.5 ${
                    isSelected
                      ? 'bg-white border-darkEmerald shadow-md ring-1 ring-emeraldAccent/40'
                      : 'bg-white/60 border-cardBorder hover:bg-white hover:border-slate-300'
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 border ${step.indicatorColor}`}
                  >
                    <StepIcon className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-0.5">
                      <span className="text-xs font-mono font-bold text-slateText uppercase">
                        {step.badge}
                      </span>
                      {isSelected && (
                        <span className="flex items-center gap-1 text-[11px] font-semibold text-darkEmerald">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>Active Flow</span>
                        </span>
                      )}
                    </div>
                    <div className="text-sm font-bold text-obsidian">{step.title}</div>
                    <div className="text-xs text-slateText line-clamp-2 mt-0.5">
                      {step.desc}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Right: Detailed Live Flow Simulator Preview */}
          <div className="lg:col-span-7 bg-white rounded-3xl border border-cardBorder p-6 sm:p-8 shadow-cockpit flex flex-col justify-between min-h-[460px]">
            <div>
              {/* Header */}
              <div className="flex items-center justify-between pb-5 border-b border-cardBorder">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-slate-900 text-white flex items-center justify-center font-mono font-bold text-sm">
                    {steps[activeStep].badge}
                  </div>
                  <div>
                    <h3 className="text-lg font-extrabold text-obsidian">
                      {steps[activeStep].title}
                    </h3>
                    <p className="text-xs text-slateText">Sanchat Local Execution Pipeline</p>
                  </div>
                </div>
                <span className="text-xs font-mono px-2.5 py-1 rounded bg-slate-100 text-slate-700 border border-slate-200">
                  On-Device Sandbox
                </span>
              </div>

              {/* Description */}
              <p className="text-slate-700 text-sm sm:text-base leading-relaxed mt-6 mb-6">
                {steps[activeStep].desc}
              </p>

              {/* Terminal / Code Style Snip */}
              <div className="rounded-2xl bg-slate-900 p-4 sm:p-5 font-mono text-xs sm:text-sm text-slate-200 border border-slate-800 shadow-inner">
                <div className="flex items-center justify-between pb-2 mb-3 border-b border-slate-800 text-[11px] text-slate-400">
                  <div className="flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-rose-500/80" />
                    <span className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-500/80" />
                    <span className="ml-2 font-mono text-slate-400">engine_debug.log</span>
                  </div>
                  <span>latency: 4.2ms</span>
                </div>
                <div className="text-emerald-400 font-semibold mb-1">
                  $ sanchat-core --simulate-pipe
                </div>
                <div className="text-slate-300 break-all bg-slate-950/70 p-3 rounded-lg border border-slate-800/80">
                  {steps[activeStep].demoSnippet}
                </div>
              </div>
            </div>

            {/* Bottom step scrubber */}
            <div className="pt-6 mt-6 border-t border-cardBorder flex items-center justify-between">
              <span className="text-xs text-slateText">
                Step {activeStep + 1} of {steps.length}
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setActiveStep((prev) => Math.max(0, prev - 1))}
                  disabled={activeStep === 0}
                  className="px-3 py-1.5 rounded-lg border border-cardBorder text-xs font-semibold text-slate-700 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  Previous
                </button>
                <button
                  type="button"
                  onClick={() => setActiveStep((prev) => Math.min(steps.length - 1, prev + 1))}
                  disabled={activeStep === steps.length - 1}
                  className="px-3.5 py-1.5 rounded-lg bg-obsidian text-white text-xs font-semibold hover:bg-deepNavy disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1"
                >
                  <span>Next Step</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
