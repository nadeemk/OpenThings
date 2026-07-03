# Building Morrow for iPhone (on your Xcode machine)

The iOS app identity is already configured: display name **Morrow**,
bundle ID **com.nadeemk.morrow**, app icon, iOS 13 deployment target.
Every commit is verified to compile for iOS in CI, so these steps are
just: get it signed onto your phone.

## Prerequisites (one-time on the Xcode machine)

- **Xcode** (from the App Store), opened once to accept the license.
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`).
- **Flutter**: `git clone https://github.com/flutter/flutter -b stable ~/flutter`
  and add `~/flutter/bin` to your PATH, or install via your usual method.

## Build & run

```sh
git clone https://github.com/nadeemk/OpenThings.git
cd OpenThings
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build with sync keys baked in so the phone shares your web account:
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://ybsvrknyyxgtwprsfyep.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlic3Zya255eXhndHdwcnNmeWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwMjAyNDAsImV4cCI6MjA5ODU5NjI0MH0.vEXsvSfwg7U0wIgqaDBx-do-3t7X86n9TgQxgsURPe4
```

Then open the workspace and run to your device:

```sh
open ios/Runner.xcworkspace
```

In Xcode:
1. Select the **Runner** target → **Signing & Capabilities** → check
   **Automatically manage signing** → choose your **Team** (your Apple ID).
   - Free Apple ID: installs but expires after 7 days.
   - Apple Developer Program ($99/yr): 1-year installs + TestFlight.
2. Plug in your iPhone, pick it as the run destination, press **Run** (▶).
3. First launch: on the phone, **Settings → General → VPN & Device
   Management** → trust your developer certificate.

Sign in with the same email/password you use on the web → same synced list.

## Reinstall over-the-air (recommended, needs the $99 program)

```sh
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://ybsvrknyyxgtwprsfyep.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<same key as above>
```
Upload `build/ios/ipa/*.ipa` via Xcode **Organizer** (or Transporter) to
**TestFlight**, then install/update from the TestFlight app on your phone
with no cable.

## Notes
- Reminders (local notifications) and the read-only calendar mirror work
  on the native iOS build (they don't on the web PWA).
- The iOS share-sheet extension and home-screen widget aren't included
  yet — they require extra Xcode extension targets.
- The app requires sign-in on first launch (same as web), so your phone
  always shows your account's list.
