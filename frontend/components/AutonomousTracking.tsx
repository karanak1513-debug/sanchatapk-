'use client';

import React, { useState } from 'react';
import {
  Bell,
  ArrowRight,
  ShieldAlert,
  ShieldCheck,
  Smartphone,
  RefreshCw,
  Utensils,
  Fuel,
  Zap,
} from 'lucide-react';

export default function AutonomousTracking() {
  const [selectedScenario, setSelectedScenario] = useState<0 | 1 | 2>(0);

  const scenarios = [
    {
      title: 'Legitimate Bank Debit (Pass)',
      sender: 'HDFC-BANK',
      rawText: 'Alert! Rs. 450.00 debited from A/c XX8921 on 08-Oct-2026. Paid to Blue Tokai Coffee via UPI Ref 90812345. Avl Bal: Rs. 42,100.',
      status: 'TRANSACTION RECORDED',
      amount: '₹450.00',
      type: 'DEBIT',
      category: 'Food & Dining',
      icon: Utensils,
      passFilter: true,
      reason: 'Verified financial header + Debit phrase + Account A/c XX + UPI Ref evidence.',
    },
    {
      title: 'Promotional Telco Spam (Rejected)',
      sender: 'JioPC',
      rawText: 'Special Diwali Deal! Plans start at just ₹333/month with unlimited 5G. Recharge today to get ₹50 cashback coupon voucher!',
      status: 'REJECTED (SPAM FILTER)',
      amount: 'NONE (Parsed: null)',
      type: 'PROMOTIONAL IGNORED',
      category: 'None',
      icon: ShieldAlert,
      passFilter: false,
      reason: 'Defensive Rule: Non-bank sender + Marketing tokens ("plans start at", "cashback", "coupon", "voucher") detected. Zero false-positive ledger entry.',
    },
    {
      title: 'Utility Bill Auto-Debit (Pass)',
      sender: 'SBI-INB',
      rawText: 'Your A/c XX5678 debited by Rs. 1,280.50 on 08-OCT-26 for Adani Electricity Txn ID 887216719. Info: Electricity Utility.',
      status: 'TRANSACTION RECORDED',
      amount: '₹1,280.50',
      type: 'DEBIT',
      category: 'Utilities & Power',
      icon: Zap,
      passFilter: true,
      reason: 'Verified bank header + "debited by" + Account XX + Txn ID evidence.',
    },
  ];

  const current = scenarios[selectedScenario];
  const CategoryIcon = current.icon;

  return (
    <section className="py-20 md:py-28 bg-white relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-3xl mb-12">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs font-mono font-medium mb-3">
            ON-DEVICE MACHINE RECOGNITION
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Your spending{' '}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-600 to-darkEmerald">
              updates itself.
            </span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Sanchat runs a defensive transaction parser right inside your Android phone. It instantly captures legitimate UPI and bank transactions while ruthlessly tossing out promotional spam.
          </p>
        </div>

        {/* Interactive Scenario Buttons */}
        <div className="flex flex-wrap gap-2.5 mb-8">
          {scenarios.map((sc, idx) => (
            <button
              key={sc.title}
              onClick={() => setSelectedScenario(idx as 0 | 1 | 2)}
              className={`px-4 py-2.5 rounded-xl text-xs sm:text-sm font-semibold border transition-all flex items-center gap-2 ${
                selectedScenario === idx
                  ? sc.passFilter
                    ? 'bg-emerald-50 border-emeraldAccent text-darkEmerald shadow-sm'
                    : 'bg-rose-50 border-rose-400 text-rose-700 shadow-sm'
                  : 'bg-white border-cardBorder text-slate-600 hover:bg-slate-50'
              }`}
            >
              {sc.passFilter ? (
                <ShieldCheck className="w-4 h-4 text-emeraldAccent" />
              ) : (
                <ShieldAlert className="w-4 h-4 text-rose-500" />
              )}
              <span>{sc.title}</span>
            </button>
          ))}
        </div>

        {/* Pipeline Interactive Card */}
        <div className="bg-[#F8FAFC] rounded-3xl border border-cardBorder p-6 sm:p-8 shadow-cockpit">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            {/* Raw SMS card representation */}
            <div className="lg:col-span-5 flex flex-col gap-4">
              <div className="text-xs font-bold uppercase tracking-wider text-slate-500 flex items-center justify-between">
                <span>Incoming Device Message</span>
                <span className="font-mono text-[10px] bg-white px-2 py-0.5 rounded border border-cardBorder">
                  SMS / Notification Payload
                </span>
              </div>

              <div className="bg-white rounded-2xl p-5 border border-cardBorder shadow-sm relative overflow-hidden">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-700">
                      <Smartphone className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-obsidian">{current.sender}</div>
                      <div className="text-[10px] text-slate-400">Device Notification</div>
                    </div>
                  </div>
                  <span className="text-[10px] font-mono text-slate-400">Just now</span>
                </div>
                <p className="text-xs sm:text-sm text-slate-700 font-mono leading-relaxed bg-slate-50 p-3 rounded-xl border border-slate-200">
                  {current.rawText}
                </p>
              </div>

              <div className="text-[11px] text-slateText italic">
                * Simulated scenario demonstrating Sanchat defensive parsing algorithm.
              </div>
            </div>

            {/* Pipeline Arrow Transition */}
            <div className="lg:col-span-2 flex flex-col items-center justify-center gap-2 text-slate-400 py-2">
              <div className="w-10 h-10 rounded-full bg-white border border-cardBorder shadow-sm flex items-center justify-center text-darkEmerald">
                <ArrowRight className="w-5 h-5 rotate-90 lg:rotate-0" />
              </div>
              <span className="text-[10px] font-mono uppercase tracking-wider text-slateText">
                8-Rule Parser
              </span>
            </div>

            {/* Parsing Outcome Card */}
            <div className="lg:col-span-5">
              <div className="text-xs font-bold uppercase tracking-wider text-slate-500 mb-4">
                Sandbox Filter Evaluation
              </div>

              <div
                className={`rounded-2xl p-6 border shadow-sm ${
                  current.passFilter
                    ? 'bg-white border-emerald-200'
                    : 'bg-rose-50/60 border-rose-200'
                }`}
              >
                <div className="flex items-center justify-between pb-3 mb-3 border-b border-cardBorder">
                  <span
                    className={`text-xs font-extrabold px-2.5 py-1 rounded-full ${
                      current.passFilter
                        ? 'bg-emerald-100 text-darkEmerald'
                        : 'bg-rose-100 text-rose-700'
                    }`}
                  >
                    {current.status}
                  </span>
                  <span className="font-mono text-xs font-bold text-slate-600">
                    {current.type}
                  </span>
                </div>

                <div className="space-y-3">
                  <div className="flex justify-between items-baseline">
                    <span className="text-xs text-slateText">Extracted Amount:</span>
                    <span
                      className={`font-mono text-lg font-extrabold ${
                        current.passFilter ? 'text-obsidian' : 'text-slate-400'
                      }`}
                    >
                      {current.amount}
                    </span>
                  </div>

                  {current.passFilter && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-slateText">Auto-Category:</span>
                      <span className="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-0.5 rounded-lg bg-slate-100 text-obsidian">
                        <CategoryIcon className="w-3.5 h-3.5 text-emeraldAccent" />
                        <span>{current.category}</span>
                      </span>
                    </div>
                  )}

                  <div className="pt-3 border-t border-slate-100">
                    <div className="text-[11px] font-bold text-slate-700 mb-1">
                      Engine Verdict:
                    </div>
                    <p className="text-xs text-slate-600 leading-relaxed bg-white/70 p-2.5 rounded-lg border border-slate-200">
                      {current.reason}
                    </p>
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
