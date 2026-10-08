'use client';

import React, { useState, useEffect } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { Menu, X, ArrowDownToLine, ShieldCheck } from 'lucide-react';

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const navLinks = [
    { name: 'Features', href: '#features' },
    { name: 'How It Works', href: '#how-it-works' },
    { name: 'Vaults', href: '#vaults' },
    { name: 'Runway', href: '#runway' },
    { name: 'Privacy', href: '#privacy' },
    { name: 'FAQ', href: '#faq' },
  ];

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'bg-white/85 backdrop-blur-md border-b border-cardBorder shadow-subtle py-3'
          : 'bg-transparent py-5'
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between">
          {/* Logo & Brand */}
          <Link href="/" className="flex items-center gap-3 group focus:outline-none focus:ring-2 focus:ring-emeraldAccent rounded-lg p-1">
            <div className="relative w-9 h-9 sm:w-10 sm:h-10 rounded-xl overflow-hidden shadow-sm ring-1 ring-cardBorder group-hover:ring-emeraldAccent transition-all">
              <Image
                src="/assets/branding/sanchat_icon.png"
                alt="Sanchat Canonical Logo"
                fill
                sizes="(max-width: 640px) 36px, 40px"
                className="object-contain"
                priority
              />
            </div>
            <div className="flex flex-col">
              <div className="flex items-center gap-1.5">
                <span className="font-extrabold text-lg sm:text-xl tracking-tight text-obsidian">
                  SANCHAT
                </span>
                <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-emerald-50 text-darkEmerald border border-emerald-200">
                  WEALTH
                </span>
              </div>
              <span className="text-[10px] font-medium text-slateText tracking-wider -mt-1 hidden sm:block">
                FINTECH COCKPIT
              </span>
            </div>
          </Link>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <a
                key={link.name}
                href={link.href}
                className="text-sm font-medium text-slateText hover:text-obsidian transition-colors focus:outline-none focus:ring-2 focus:ring-emeraldAccent rounded-md px-1 py-0.5"
              >
                {link.name}
              </a>
            ))}
          </nav>

          {/* Right Action / CTA */}
          <div className="hidden md:flex items-center gap-4">
            <a
              href="#verification"
              className="inline-flex items-center gap-1.5 text-xs font-mono text-slateText hover:text-darkEmerald transition-colors"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-emeraldAccent" />
              <span>v1.0.0+1 (API 36)</span>
            </a>
            <a
              href="#download"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold bg-obsidian text-white hover:bg-deepNavy active:scale-95 transition-all shadow-sm focus:outline-none focus:ring-2 focus:ring-emeraldAccent"
            >
              <ArrowDownToLine className="w-4 h-4 text-emeraldAccent" />
              <span>Get Sanchat</span>
            </a>
          </div>

          {/* Mobile Menu Toggle Button */}
          <div className="md:hidden flex items-center gap-2">
            <a
              href="#download"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-obsidian text-white"
            >
              <ArrowDownToLine className="w-3.5 h-3.5 text-emeraldAccent" />
              <span>Get APK</span>
            </a>
            <button
              type="button"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-lg text-slateText hover:text-obsidian hover:bg-lightSlate focus:outline-none focus:ring-2 focus:ring-emeraldAccent"
              aria-label="Toggle navigation menu"
              aria-expanded={mobileMenuOpen}
            >
              {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>

        {/* Mobile Dropdown Menu */}
        {mobileMenuOpen && (
          <div className="md:hidden pt-4 pb-6 border-t border-cardBorder mt-3 animate-in fade-in slide-in-from-top-4 duration-200">
            <div className="flex flex-col gap-3">
              {navLinks.map((link) => (
                <a
                  key={link.name}
                  href={link.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className="px-3 py-2 rounded-lg text-base font-medium text-slateText hover:text-obsidian hover:bg-lightSlate transition-colors"
                >
                  {link.name}
                </a>
              ))}
              <div className="pt-2 border-t border-cardBorder flex flex-col gap-2">
                <a
                  href="#download"
                  onClick={() => setMobileMenuOpen(false)}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-obsidian text-white font-semibold text-sm"
                >
                  <ArrowDownToLine className="w-4 h-4 text-emeraldAccent" />
                  <span>Download Sanchat APK (62.4 MB)</span>
                </a>
                <div className="text-center text-xs text-slateText font-mono pt-1">
                  SHA-256 Verified • Target SDK 36
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
