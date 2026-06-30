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

## Known gaps (next steps)
- GQL operation hashes (sha256Hash) need to be captured from real Twitch network traffic, mine are placeholders
- Channel priority/auto-switch logic not implemented yet (mining_service.dart only pings active channel)
- System tray / autostart packages added in pubspec but not wired in main.dart yet
- No 2FA/captcha handling needed since auth is cookie-based
