# Sanchay Wealth & Savings Vault System

A comprehensive financial management and wealth-building ecosystem consisting of an autonomous Flutter mobile app, Next.js web application, and Firebase Cloud Functions backend.

---

## 📁 Repository Structure

```
stitch_sanchay_wealth_app_ui_system/
├── frontend/                     # Next.js 14 Web Application & Cockpit
│   ├── app/                      # Next.js App Router (Showcase, Downloads, Legal)
│   ├── components/               # React UI components (Framer Motion, Tailwind)
│   ├── public/                   # Static web assets & release APK distribution
│   ├── package.json              # Web dependencies
│   ├── tailwind.config.ts        # Styling tokens & theme
│   └── tsconfig.json             # TypeScript configuration
│
├── backend/                      # Firebase & Cloud Backend Services
│   ├── functions/                # Firebase Cloud Functions (FCM push notification service)
│   ├── firestore.rules           # Hardened Firestore security rules
│   ├── storage.rules             # Cloud Storage security rules
│   ├── firestore.indexes.json    # Composite indexes for chat and transactions
│   ├── firebase.json             # Firebase deployment configuration
│   ├── serve_sanchay.js          # Standalone showcase & feedback HTTP API
│   └── serve_apk.js              # Standalone release APK distribution server
│
├── mobile/                       # Flutter Cross-Platform Application
│   ├── lib/                      # Flutter Dart source code
│   │   ├── models/               # Transactions, Vaults, Chat, Gamification
│   │   ├── providers/            # State management (ChangeNotifier)
│   │   ├── screens/              # App screens & flows
│   │   ├── services/             # Autonomous UPI parser, SMS sync, FCM
│   │   └── widgets/              # Reusable UI widgets & modals
│   ├── android/                  # Android native module (SDK 36, Kotlin)
│   ├── ios/                      # iOS native module (Swift)
│   ├── assets/                   # App icons, illustrations, and branding
│   ├── test/                     # Unit, integration, and parser test suites
│   ├── pubspec.yaml              # Flutter dependencies and assets config
│   └── build_apk.bat             # Production release APK compilation script
│
├── package.json                  # Root monorepo orchestration scripts
├── build_apk.bat                 # Root helper to compile release APK
├── run_sanchay.bat               # Root helper to run backend/showcase
└── PROJECT_RULES.md              # Engineering standards & verification protocol
```

---

## 🚀 Quick Start Guide

### 1. Web Frontend (Next.js)
```bash
# From root directory:
npm run dev

# Or directly inside frontend:
cd frontend
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) to view the landing page and cockpit.

### 2. Backend & Cloud Functions
```bash
# Deploy Cloud Functions to Firebase:
firebase deploy --only functions --config backend/firebase.json

# Deploy Security Rules:
firebase deploy --only firestore:rules,storage --config backend/firebase.json

# Run standalone backend server locally:
npm run serve:backend
```

### 3. Mobile App (Flutter)
```bash
cd mobile

# Install dependencies:
flutter pub get

# Run unit tests:
flutter test

# Build production release APK:
flutter build apk --release
# Or run the batch script:
build_apk.bat
```
Output APK is automatically generated at `mobile/build/app/outputs/flutter-apk/app-release.apk` and copied to `frontend/public/` for web distribution.
