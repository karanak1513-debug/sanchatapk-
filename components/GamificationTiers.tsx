'use client';

import React, { useState } from 'react';
import {
  Trophy,
  Shield,
  Star,
  Award,
  Crown,
  Sparkles,
  ChevronRight,
  Flame,
} from 'lucide-react';

export default function GamificationTiers() {
  const [selectedTier, setSelectedTier] = useState<number>(2); // Default to Gold Grower

  const tiers = [
    {
      levelRange: 'Levels 01 – 15',
      name: 'Copper Seed',
      badge: 'Tier 1',
      xpRequirement: '0 – 2,500 XP',
      milestone: 'Consistent Daily Runway Tracking for 7 days',
      disciplines: ['Autonomous UPI sync activated', 'First emergency buffer initiated', 'Zero impulse day streak: 3'],
      accentBg: 'bg-amber-950/40 border-amber-800/60 text-amber-400',
      tagColor: 'border-amber-700/50 text-amber-300',
      color: '#B45309',
    },
    {
      levelRange: 'Levels 16 – 35',
      name: 'Silver Builder',
      badge: 'Tier 2',
      xpRequirement: '2,501 – 7,500 XP',
      milestone: 'First Multi-Vault 25% Goal Cap reached',
      disciplines: ['30-day budget discipline intact', 'Master Vault pacing configured', 'Emergency fund initialized'],
      accentBg: 'bg-slate-800/60 border-slate-600/60 text-slate-200',
      tagColor: 'border-slate-500/50 text-slate-300',
      color: '#94A3B8',
    },
    {
      levelRange: 'Levels 36 – 55',
      name: 'Gold Grower',
      badge: 'Tier 3 (Current Demo)',
      xpRequirement: '7,501 – 15,000 XP',
      milestone: '60-Day Unbroken Safe Runway Streak',
      disciplines: ['Under daily quota 18 of 22 days', 'Emergency Cushion 43% populated', 'Zero bank password compromise'],
      accentBg: 'bg-yellow-950/40 border-yellow-700/60 text-yellow-300',
      tagColor: 'border-yellow-600/50 text-yellow-200',
      color: '#EAB308',
    },
    {
      levelRange: 'Levels 56 – 75',
      name: 'Platinum Planner',
      badge: 'Tier 4',
      xpRequirement: '15,001 – 25,000 XP',
      milestone: '3 Dedicated Multi-Vaults fully funded',
      disciplines: ['Automated surplus routing active', 'Discipline streak > 90 days', 'Runway buffer exceeds 60 days'],
      accentBg: 'bg-cyan-950/40 border-cyan-700/60 text-cyan-300',
      tagColor: 'border-cyan-600/50 text-cyan-200',
      color: '#06B6D4',
    },
    {
      levelRange: 'Levels 76 – 95',
      name: 'Diamond Strategist',
      badge: 'Tier 5',
      xpRequirement: '25,001 – 40,000 XP',
      milestone: '180-Day Financial Autonomy & Complete Peace',
      disciplines: ['All 5 Life Vaults paced on schedule', 'Net wealth trajectory positive', 'Total financial calm'],
      accentBg: 'bg-blue-950/40 border-blue-700/60 text-blue-300',
      tagColor: 'border-blue-600/50 text-blue-200',
      color: '#3B82F6',
    },
    {
      levelRange: 'Levels 96 – 100',
      name: 'Cosmic Wealth God',
      badge: 'Tier 6 (Supreme Master)',
      xpRequirement: '40,001+ XP',
      milestone: 'Permanent Wealth Independence & Lifelong Mastery',
      disciplines: ['Complete financial sovereignty', 'Zero friction lifestyle balance', 'Legendary discipline streak'],
      accentBg: 'bg-emerald-950/50 border-emerald-700/80 text-emerald-300',
      tagColor: 'border-emerald-500/60 text-emerald-200',
      color: '#10B981',
    },
  ];

  const current = tiers[selectedTier];

  return (
    <section className="py-20 md:py-28 bg-[#F8FAFC] border-y border-cardBorder relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mb-12">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-white border border-cardBorder text-slateText text-xs font-mono font-medium mb-3 shadow-subtle">
            FINANCIAL DISCIPLINE GAMIFICATION
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            The 100-Tier{' '}
            <span className="text-darkEmerald">Discipline Journey.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Gamification designed for serious adults. Every day you stay within your safe runway and contribute to your savings vaults earns genuine experience points.
          </p>
        </div>

        {/* Vertical Progression Architecture */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* Tier Selection Buttons */}
          <div className="lg:col-span-5 flex flex-col gap-2.5">
            {tiers.map((tier, idx) => {
              const isSelected = selectedTier === idx;
              return (
                <button
                  key={tier.name}
                  onClick={() => setSelectedTier(idx)}
                  className={`w-full text-left p-4 rounded-2xl border transition-all flex items-center justify-between ${
                    isSelected
                      ? 'bg-obsidian text-white border-obsidian shadow-md'
                      : 'bg-white text-slate-700 border-cardBorder hover:border-slate-300 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-8 h-8 rounded-lg flex items-center justify-center font-mono text-xs font-bold border ${tier.accentBg}`}
                    >
                      {idx + 1}
                    </div>
                    <div>
                      <div className="text-sm font-bold">{tier.name}</div>
                      <div
                        className={`text-xs font-mono ${
                          isSelected ? 'text-slate-400' : 'text-slate-500'
                        }`}
                      >
                        {tier.levelRange}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-[11px] font-mono px-2 py-0.5 rounded border ${
                        isSelected
                          ? 'border-slate-700 bg-slate-900 text-slate-300'
                          : 'border-slate-200 bg-slate-100 text-slate-600'
                      }`}
                    >
                      {tier.xpRequirement}
                    </span>
                    <ChevronRight
                      className={`w-4 h-4 ${
                        isSelected ? 'text-emeraldAccent' : 'text-slate-400'
                      }`}
                    />
                  </div>
                </button>
              );
            })}
          </div>

          {/* Right Tier Detail Cockpit Panel */}
          <div className="lg:col-span-7 bg-white rounded-3xl border border-cardBorder p-6 sm:p-10 shadow-cockpit flex flex-col justify-between min-h-[460px]">
            <div>
              <div className="flex items-center justify-between pb-4 border-b border-cardBorder">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-mono font-bold text-slate-400 uppercase">
                    Rank Hierarchy: {current.levelRange}
                  </span>
                  <span className="text-xs font-mono font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                    {current.badge}
                  </span>
                </div>
                <div className="flex items-center gap-1.5 text-xs font-bold text-darkEmerald">
                  <Flame className="w-4 h-4 text-emeraldAccent" />
                  <span>XP: {current.xpRequirement}</span>
                </div>
              </div>

              <div className="my-6">
                <h3 className="text-2xl sm:text-3xl font-extrabold text-obsidian tracking-tight mb-2">
                  {current.name}
                </h3>
                <p className="text-sm text-slate-600 leading-relaxed">
                  Advancing to this rank requires verifiable mastery over your daily spending impulses and demonstrated commitment to long-term wealth targets.
                </p>
              </div>

              {/* Next Milestone Box */}
              <div className="p-4 rounded-2xl bg-[#F8FAFC] border border-slate-200 mb-6">
                <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1">
                  Primary Milestone Objective
                </div>
                <div className="text-sm font-bold text-obsidian flex items-center gap-2">
                  <Trophy className="w-4 h-4 text-emeraldAccent" />
                  <span>{current.milestone}</span>
                </div>
              </div>

              {/* Disciplines Required */}
              <div className="space-y-2">
                <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">
                  Verified Disciplines
                </div>
                {current.disciplines.map((d, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-2 text-xs sm:text-sm text-slate-700 bg-white p-2.5 rounded-xl border border-cardBorder"
                  >
                    <div className="w-1.5 h-1.5 rounded-full bg-emeraldAccent" />
                    <span>{d}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="pt-6 mt-6 border-t border-cardBorder flex items-center justify-between text-xs text-slateText font-mono">
              <span>Sanchat Gamification v1.0</span>
              <span className="text-darkEmerald font-semibold">100 Tiers of Calm Mastery</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
