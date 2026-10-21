import React from 'react';
import Navbar from '@/components/Navbar';
import Hero from '@/components/Hero';
import MoneyFlow from '@/components/MoneyFlow';
import AutonomousTracking from '@/components/AutonomousTracking';
import MultiVaultSavings from '@/components/MultiVaultSavings';
import SpendingRunway from '@/components/SpendingRunway';
import GamificationTiers from '@/components/GamificationTiers';
import FeatureGrid from '@/components/FeatureGrid';
import PrivacySecurity from '@/components/PrivacySecurity';
import DownloadSection from '@/components/DownloadSection';
import FaqAccordion from '@/components/FaqAccordion';
import Footer from '@/components/Footer';

export default function HomePage() {
  return (
    <main className="min-h-screen bg-white text-obsidian flex flex-col selection:bg-emeraldAccent selection:text-white">
      <Navbar />
      <Hero />
      <MoneyFlow />
      <AutonomousTracking />
      <MultiVaultSavings />
      <SpendingRunway />
      <GamificationTiers />
      <FeatureGrid />
      <PrivacySecurity />
      <DownloadSection />
      <FaqAccordion />
      <Footer />
    </main>
  );
}
