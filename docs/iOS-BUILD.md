# Building Morrow for iPhone (on your Xcode machine)

The iOS app identity is already configured: display name **Morrow**,
bundle ID **com.nadeemk.morrow**, app icon generated. These steps build
it onto your iPhone from the machine that has Xcode.

## One-time setup

1. **Clone and prepare**
   ```sh
   git clone https://github.com/nadeemk/OpenThings.git
   cd OpenThings
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Open the iOS workspace in Xcode**
   ```sh
   open ios/Runner.xcworkspace
   ```
   (Open the `.xcworkspace`, not `.xcodeproj`.)

3. **Signing** — in Xcode: select the **Runner** target → **Signing &
   Capabilities** → check **Automatically manage signing** → pick your
   **Team** (your Apple ID). A free Apple ID works but the app expires
   after 7 days; the $99/yr Apple Developer Program keeps it for a year
   and unlocks TestFlight.

## Build with sync enabled

Morrow needs the Supabase keys baked in at build time so your phone and
your browsers share one account. Build from the command line with your
keys (see `README.md` → "Enabling sync" for creating the Supabase
project):

```sh
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Then in Xcode: plug in your iPhone, select it as the run destination,
and press **Run** (▶). Trust the developer profile on the phone under
**Settings → General → VPN & Device Management** the first time.

## Reinstalling without the cable (recommended: TestFlight)

With the $99 program you can push a build to **TestFlight** once and then
reinstall/update over the air from anywhere:

```sh
flutter build ipa --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# then upload build/ios/archive via Xcode Organizer or `xcrun altool`
```

## Notes
- Reminders (local notifications) and the calendar mirror work on the
  native iOS build (they don't on the web PWA).
- The iOS share-sheet extension and home-screen widget are not included
  yet — they need extension targets added in Xcode.
