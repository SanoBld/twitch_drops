# Twitch Drops (custom miner)

## Setup
1. Install Flutter SDK, enable desktop: `flutter config --enable-windows-desktop` (or linux)
2. `flutter create .` in this folder to generate platform files (windows/, linux/)
3. `flutter pub get`
4. `flutter run -d windows` (or linux)

## How auth works
No login form. Paste your `auth-token` cookie from twitch.tv (devtools > Application > Cookies) on first launch. Stored locally via shared_preferences.

## Structure
- lib/services: Twitch GQL client, auth, websocket, mining loop, settings
- lib/models: DropCampaign, TimeBasedDrop, Channel
- lib/screens: Login, Home
- lib/widgets: CampaignCard

## CI / GitHub Actions
`.github/workflows/build.yml` builds Windows + Linux on every push to main, and packages them into a GitHub Release when you publish one (tag like `v1.0.0`).

## Update system
`UpdateService` checks `api.github.com/repos/<you>/twitch_drops/releases/latest` on startup and shows a dialog if a newer version exists, linking to the download. Update `_repo` in `lib/services/update_service.dart` with your actual GitHub username/repo before building.

## Android signing (only if you enable Android build)
Without a fixed signing key, every CI build gets a random debug signature, and Android refuses to update in place — you'd have to uninstall/reinstall each time. To fix this, generate ONE keystore, keep it secret, reuse it forever:

1. Generate the keystore (run once, locally):
   ```
   keytool -genkey -v -keystore release.keystore -alias twitchdrops -keyalg RSA -keysize 2048 -validity 10000
   ```
   This is NOT a Play Store key, just a private signature so updates install over the existing app instead of conflicting.

2. Encode it to base64 (PowerShell):
   ```
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Set-Clipboard
   ```

3. In your GitHub repo: Settings > Secrets and variables > Actions, add:
   - `ANDROID_KEYSTORE_BASE64` (paste the base64 string)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS` (e.g. `twitchdrops`)
   - `ANDROID_KEY_PASSWORD`

4. In `build.yml`, set `if: false` to `if: true` on the `build-android` job to enable it.

5. Keep `release.keystore` somewhere safe outside the repo — losing it means future updates can never overwrite old installs again.

## Known gaps (next steps)
- GQL operation hashes (sha256Hash) need to be captured from real Twitch network traffic, mine are placeholders
- Channel priority/auto-switch logic not implemented yet (mining_service.dart only pings active channel)
- System tray / autostart packages added in pubspec but not wired in main.dart yet
- No 2FA/captcha handling needed since auth is cookie-based
- Android build disabled by default in CI (see Android signing section)
