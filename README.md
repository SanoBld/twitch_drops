# Twitch Drops (custom miner)

## Setup
1. Install Flutter SDK, enable desktop: `flutter config --enable-windows-desktop` (or linux)
2. `flutter create .` in this folder to generate platform files (windows/, linux/)
3. `flutter pub get`
4. On Linux only: `sudo apt install libayatana-appindicator3-dev` (needed for tray icon support)
5. `flutter run -d windows` (or linux)

## How auth works
TV-style device code login (like TDM/consoles): the app requests a code from Twitch, shows it on screen with a URL, and polls Twitch until you approve it on their site. No password, no cookie paste. Token stored locally via shared_preferences.

## Background mode
Closing the window hides it to the system tray instead of quitting (`window_manager` + `tray_manager`), mining keeps running. Click the tray icon or its "Show window" menu entry to bring it back, "Quit" to actually exit. A toggle in the app bar enables/disables launching automatically with the system (`launch_at_startup`), same role as TDM's registry entry.

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
- GQL hashes captured so far: `ViewerDropsDashboard`, `DirectoryPage_Game`. `PlaybackAccessToken_Template` uses a raw query (not persisted hash), already wired in `mining_service.dart`.
- **Critical missing piece: the Spade "minute-watched" event.** `PlaybackAccessToken` only authorizes watching a channel, it likely does NOT make drop progress advance by itself. Twitch tracks actual watch-time through a separate binary event sent to `https://spade.twitch.tv/track` (protobuf-encoded, base64'd in a `data` query param), roughly every 60 seconds while watching. This needs to be captured: open a live stream, filter devtools Network on `spade.twitch.tv`, find the periodic POST request, inspect its payload. This is the actual mechanism that makes drops progress, more important than the GQL hash work done so far.
- Tray icon is a placeholder purple circle, swap assets/tray_icon.ico and .png for a real design later
- Android build disabled by default in CI (see Android signing section)
- Game priority + auto channel switching is implemented (`priority_screen.dart`, `mining_service.dart`): it ranks campaigns by your saved priority list, picks the most-viewed live channel for the top one with unclaimed drops, and re-checks every 2 minutes
