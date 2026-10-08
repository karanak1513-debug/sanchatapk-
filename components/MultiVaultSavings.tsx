'use client';

import React, { useState } from 'react';
import {
  ShieldAlert,
  Plane,
  Laptop,
  GraduationCap,
  Sparkles,
  Layers,
  ArrowUpRight,
  Plus,
  Lock,
} from 'lucide-react';

export default function MultiVaultSavings() {
  const [activeVaultIndex, setActiveVaultIndex] = useState(0);

  const vaults = [
    {
      id: 'master',
      name: 'Master Reserve Vault',
      icon: Sparkles,
      current: 30000,
      target: 100000,
      percentage: 30,
      deadline: 'Dec 2026',
      pacing: '₹750 / day required',
      status: 'Auto-Pacing Active',
      color: 'from-emerald-500 to-emerald-600',
      badgeColor: 'bg-emerald-50 text-darkEmerald border-emerald-200',
      description: 'The primary wealth anchor. Automatically accumulates daily discipline surplus without touching baseline liquidity.',
    },
    {
      id: 'emergency',
      name: 'Emergency Cushion',
      icon: ShieldAlert,
      current: 65000,
      target: 150000,
      percentage: 43,
      deadline: 'Nov 2026',
      pacing: '₹1,200 / day required',
      status: 'On Track',
      color: 'from-blue-500 to-indigo-600',
      badgeColor: 'bg-blue-50 text-blue-700 border-blue-200',
      description: '6 months of non-negotiable living expenses safely isolated from impulse spending and daily debit cards.',
    },
    {
      id: 'travel',
      name: 'Japan & Alps Voyage',
      icon: Plane,
      current: 18500,
      target: 50000,
      percentage: 37,
      deadline: 'Feb 2027',
      pacing: '₹350 / day required',
      status: 'Paced Ahead',
      color: 'from-amber-500 to-rose-500',
      badgeColor: 'bg-amber-50 text-amber-700 border-amber-200',
      description: 'Dream vacation reserve fueled directly by small daily micro-savings and restaurant trade-offs.',
    },
    {
      id: 'gadget',
      name: 'M4 Studio & Tech Rig',
      icon: Laptop,
      current: 12000,
      target: 40000,
      percentage: 30,
      deadline: 'Jan 2027',
      pacing: '₹400 / day required',
      status: 'Paced',
      color: 'from-purple-500 to-fuchsia-600',
      badgeColor: 'bg-purple-50 text-purple-700 border-purple-200',
      description: 'Targeted hardware and developer gear upgrade vault with atomic increment tracking.',
    },
    {
      id: 'education',
      name: 'Executive Masters / Certs',
      icon: GraduationCap,
      current: 85000,
      target: 200000,
      percentage: 42.5,
      deadline: 'May 2027',
      pacing: '₹600 / day required',
      status: 'On Track',
      color: 'from-teal-500 to-cyan-600',
      badgeColor: 'bg-teal-50 text-teal-700 border-teal-200',
      description: 'Career growth and masterclass reserve isolated under dedicated target pacing rules.',
    },
  ];

  const current = vaults[activeVaultIndex];
  const VaultIcon = current.icon;
  const remaining = current.target - current.current;

  return (
    <section id="vaults" className="py-20 md:py-28 bg-[#F8FAFC] border-y border-cardBorder relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="max-w-3xl mb-12">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-white border border-cardBorder text-slateText text-xs font-mono font-medium mb-3 shadow-subtle">
            TARGET-BASED SAVINGS
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Multi-Vault Discipline.{' '}
            <span className="text-darkEmerald">Zero Temptation.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Create independent digital vaults for life priorities. Each vault monitors its own target date, accumulation pace, and atomic deposits with live Firestore state sync.
          </p>
        </div>

        {/* Interactive Selector Tabs */}
        <div className="flex items-center gap-2 overflow-x-auto pb-4 mb-8 scrollbar-none">
          {vaults.map((vault, idx) => {
            const Icon = vault.icon;
            const isSelected = activeVaultIndex === idx;
            return (
              <button
                key={vault.id}
                onClick={() => setActiveVaultIndex(idx)}
                className={`flex items-center gap-2.5 px-4 py-3 rounded-2xl border text-sm font-bold whitespace-nowrap transition-all ${
                  isSelected
                    ? 'bg-obsidian text-white border-obsidian shadow-md'
                    : 'bg-white text-slate-600 border-cardBorder hover:border-slate-300 hover:text-obsidian'
                }`}
              >
                <Icon className={`w-4 h-4 ${isSelected ? 'text-emeraldAccent' : 'text-slate-400'}`} />
                <span>{vault.name}</span>
                <span
                  className={`text-[10px] font-mono px-1.5 py-0.5 rounded-full ${
                    isSelected ? 'bg-slate-800 text-emerald-400' : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {vault.percentage}%
                </span>
              </button>
            );
          })}
        </div>

        {/* Active Vault Interactive Showcase Card */}
        <div className="bg-white rounded-3xl border border-cardBorder p-6 sm:p-10 shadow-cockpit">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            {/* Visual Ring & Progress */}
            <div className="lg:col-span-5 flex flex-col items-center justify-center p-6 bg-[#F8FAFC] rounded-2xl border border-slate-200/80">
              <div className="relative w-48 h-48 flex items-center justify-center">
                {/* SVG Progress Circle */}
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 120 120">
                  <circle
                    cx="60"
                    cy="60"
                    r="50"
                    stroke="#E2E8F0"
                    strokeWidth="10"
                    fill="transparent"
                  />
                  <circle
                    cx="60"
                    cy="60"
                    r="50"
                    stroke="#10B981"
                    strokeWidth="10"
                    strokeDasharray={2 * Math.PI * 50}
                    strokeDashoffset={2 * Math.PI * 50 * (1 - current.percentage / 100)}
                    strokeLinecap="round"
                    fill="transparent"
                    className="transition-all duration-700 ease-out"
                  />
                </svg>

                {/* Center Content */}
                <div className="absolute flex flex-col items-center justify-center text-center">
                  <VaultIcon className="w-8 h-8 text-darkEmerald mb-1" />
                  <span className="text-3xl font-extrabold text-obsidian font-mono">
                    {current.percentage}%
                  </span>
                  <span className="text-[10px] font-mono uppercase tracking-wider text-slateText">
                    Paced
                  </span>
                </div>
              </div>

              <div className="mt-4 text-center">
                <span className="text-xs text-slate-500 font-mono">
                  Deadline: <span className="font-bold text-obsidian">{current.deadline}</span>
                </span>
              </div>
            </div>

            {/* Vault Metrics & Control */}
            <div className="lg:col-span-7 flex flex-col justify-between">
              <div>
                <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                      Vault ID: {current.id}
                    </span>
                    <span className={`text-[11px] font-semibold px-2.5 py-0.5 rounded-full border ${current.badgeColor}`}>
                      {current.status}
                    </span>
                  </div>
                  <span className="text-xs font-mono text-darkEmerald font-semibold bg-emerald-50 px-2 py-0.5 rounded border border-emerald-100">
                    {current.pacing}
                  </span>
                </div>

                <h3 className="text-2xl sm:text-3xl font-extrabold text-obsidian mb-2">
                  {current.name}
                </h3>
                <p className="text-sm text-slate-600 leading-relaxed mb-6">
                  {current.description}
                </p>

                {/* Financial Indicators Grid */}
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 p-4 rounded-2xl bg-[#F8FAFC] border border-slate-200 mb-6">
                  <div>
                    <span className="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">
                      Current Saved
                    </span>
                    <span className="text-xl font-extrabold font-mono text-obsidian">
                      ₹{current.current.toLocaleString('en-IN')}
                    </span>
                  </div>

                  <div>
                    <span className="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">
                      Target Cap
                    </span>
                    <span className="text-xl font-extrabold font-mono text-slateText">
                      ₹{current.target.toLocaleString('en-IN')}
                    </span>
                  </div>

                  <div className="col-span-2 sm:col-span-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">
                      Remaining Gap
                    </span>
                    <span className="text-xl font-extrabold font-mono text-darkEmerald">
                      ₹{remaining.toLocaleString('en-IN')}
                    </span>
                  </div>
                </div>
              </div>

              {/* Technical Implementation details */}
              <div className="pt-4 border-t border-cardBorder flex flex-wrap items-center justify-between text-xs text-slateText gap-2">
                <span className="flex items-center gap-1.5 font-mono">
                  <Lock className="w-3.5 h-3.5 text-emeraldAccent" />
                  <span>Atomic: FieldValue.increment()</span>
                </span>
                <span className="font-mono text-slate-400">
                  users/{'{uid}'}/targets/{current.id}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="text-center mt-4 text-xs text-slateText">
          * Demonstration values illustrating the multi-vault allocation algorithm.
        </div>
      </div>
    </section>
  );
}
