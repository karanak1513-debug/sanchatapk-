'use client';

import React, { useState } from 'react';
import { ChevronDown, HelpCircle } from 'lucide-react';

export default function FaqAccordion() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const faqs = [
    {
      q: "Why doesn't Sanchat need my bank netbanking password?",
      a: "Traditional aggregators often ask for netbanking usernames or screen-scraping access, introducing severe credential vulnerability. Sanchat adopts a completely non-invasive on-device architecture: it parses standard incoming transactional SMS messages (from authorized bank headers like HDFC, SBI, ICICI, etc.) locally on your phone. Sanchat never sees, requests, or stores your banking passwords or debit card PINs.",
    },
    {
      q: 'Are my personal SMS or OTPs uploaded to any server?',
      a: 'No. The Sanchat parsing engine (lib/services/notification_parser.dart) operates entirely on-device. Personal messages, conversations, and one-time passwords (OTPs) are filtered out immediately. Only normalized financial transaction records (amount, transaction type, category, reference fingerprint) are written to your authenticated private Firestore database. Raw SMS content is never transmitted or stored remotely.',
    },
    {
      q: 'How does the Daily Spending Runway work?',
      a: 'The Daily Spending Runway recalculates your safe burn rate in real time. It takes your accessible liquid pool, accounts for remaining days in the budget cycle, and dynamically adjusts your daily quota whenever an expense is registered. If you spend less today, tomorrow’s runway expands. If you exceed your quota, future daily targets gently compress to keep your monthly savings intact.',
    },
    {
      q: 'How do I install the official Android APK?',
      a: 'Download the official sanchat-release.apk directly from this page. Open the downloaded file from your Android notification drawer or file manager. If Android warns you that the app is from an unknown source, review the publisher and verify that the file SHA-256 matches our official checksum (d43668da9f1f73de86a731326f0fe5d72d16581754530ff2c7fbcc693ab45c49). Once verified, tap Install to proceed.',
    },
    {
      q: 'Is Sanchat currently available on Google Play?',
      a: 'The production release package (com.aistudio.sanchay.savtrkr) has been fully engineered to target Android API 36, incorporates Google Play compliant account deletion, and adheres to strict sensitive permission guidelines. The Google Play Store listing is currently undergoing final developer console review. Until the public store link is active, the official signed APK is distributed directly via this verified page.',
    },
  ];

  const toggleFaq = (index: number) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  return (
    <section id="faq" className="py-20 md:py-28 bg-white relative">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center mb-14">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-darkEmerald text-xs font-mono font-medium mb-3">
            FREQUENTLY ASKED QUESTIONS
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-obsidian tracking-tight mb-4">
            Clear Answers.{' '}
            <span className="text-darkEmerald">Zero Ambiguity.</span>
          </h2>
          <p className="text-base sm:text-lg text-slateText leading-relaxed">
            Everything you need to know about Sanchat&apos;s privacy model, on-device parsing, and Android release.
          </p>
        </div>

        {/* Accordion Stack */}
        <div className="space-y-3.5">
          {faqs.map((faq, idx) => {
            const isOpen = openIndex === idx;
            return (
              <div
                key={faq.q}
                className="rounded-2xl border border-cardBorder bg-[#F8FAFC] transition-all overflow-hidden"
              >
                <button
                  type="button"
                  onClick={() => toggleFaq(idx)}
                  className="w-full p-5 sm:p-6 text-left flex items-center justify-between gap-4 focus:outline-none focus:ring-2 focus:ring-emeraldAccent"
                  aria-expanded={isOpen}
                >
                  <span className="text-base sm:text-lg font-bold text-obsidian leading-snug">
                    {faq.q}
                  </span>
                  <div
                    className={`w-8 h-8 rounded-full bg-white border border-cardBorder flex items-center justify-center text-slate-500 shrink-0 transition-transform duration-300 ${
                      isOpen ? 'rotate-180 text-darkEmerald' : ''
                    }`}
                  >
                    <ChevronDown className="w-4 h-4" />
                  </div>
                </button>

                {isOpen && (
                  <div className="px-5 pb-5 sm:px-6 sm:pb-6 text-sm sm:text-base text-slate-600 leading-relaxed border-t border-slate-200/60 pt-4 animate-in fade-in duration-200">
                    {faq.a}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Assistance prompt */}
        <div className="mt-12 text-center p-6 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm text-slateText">
          Have a technical or privacy question not listed here? Review our{' '}
          <a href="/privacy" className="font-bold text-darkEmerald hover:underline">
            Privacy Policy
          </a>{' '}
          or examine the cryptographic release checksums in the verification panel.
        </div>
      </div>
    </section>
  );
}
