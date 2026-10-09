# Sanchat — Future Release Checklist

Use this checklist before releasing every new production update of Sanchat.

---

## 1. Pre-Flight Code Quality & Tests
- [ ] Run static analysis:
  ```bash
  flutter analyze
  ```
  *Ensure 0 errors and 0 warnings.*
- [ ] Run full mobile test suite:
  ```bash
  flutter test
  ```
  *Ensure all notification, chat, and finance tests pass.*
- [ ] Verify Next.js web application:
  ```bash
  npm run lint
  npm run build
  ```
  *Ensure all static routes compile cleanly.*

---

## 2. Android Versioning & Builds
- [ ] Bump version in `pubspec.yaml` (e.g., `1.0.1+2`).
- [ ] Clean previous artifacts:
  ```bash
  flutter clean
  flutter pub get
  ```
- [ ] Build signed Release APK:
  ```bash
  flutter build apk --release
  ```
- [ ] Build signed Release AAB for Google Play Store:
  ```bash
  flutter build appbundle --release
  ```
- [ ] Calculate the SHA-256 hash of the generated APK:
  ```powershell
  Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
  ```
- [ ] Note exact byte size:
  ```powershell
  (Get-Item build\app\outputs\flutter-apk\app-release.apk).Length
  ```

---

## 3. Website & Artifact Synchronization
- [ ] Copy the fresh APK to website download destinations:
  ```powershell
  Copy-Item build\app\outputs\flutter-apk\app-release.apk public\downloads\sanchat-release.apk -Force
  Copy-Item build\app\outputs\flutter-apk\app-release.apk sanchay-release.apk -Force
  ```
- [ ] Update `config/release.ts`:
  - Update `versionName` and `versionCode`
  - Update `sizeBytes` and `sizeFormatted`
  - Update `sha256` checksum
- [ ] Verify Next.js build with the new binary:
  ```bash
  npm run build
  ```
- [ ] Deploy website to Vercel:
  ```bash
  npx -y vercel deploy --prod --yes
  ```

---

## 4. Verification & Testing
- [ ] Verify website live download header and status:
  ```bash
  curl.exe -IL https://stitchsanchaywealthappuisystem.vercel.app/download
  ```
  *Confirm HTTP 200 OK and matching Content-Length.*
- [ ] Test notification delivery:
  - User A sends to User B while User B is in the chat screen -> No banner/sound (active chat suppressed).
  - User A sends to User B while User B is on the finance dashboard -> Notification displays.
  - User A sends to User B while User B has app in background / locked -> Push notification arrives via FCM.
  - User A does not receive a self-notification.

---

## 5. Deployment & Release Publishing
- [ ] Deploy Cloud Functions (requires Blaze plan):
  ```bash
  firebase deploy --only functions
  ```
- [ ] Commit all verified release files to Git:
  ```bash
  git add .
  git commit -m "chore(release): v1.0.X release"
  git push origin <branch>
  ```
- [ ] Upload `app-release.aab` to Google Play Console Internal Testing track.
