# Benchify Mobile

Companion mobile app for [Benchify](https://github.com/sundarlohar007/Benchify) — the free, open-source mobile + desktop performance profiler.

This is the **read-only viewer**. The desktop app does the recording and analytics; this app lets you browse sessions, check trends, and look at per-app stats from your phone, away from your workstation.

> **Heads-up**: profiling itself happens on the desktop. The mobile app is a remote viewer that talks to a self-hosted Benchify server.

## Install

| Platform | File                                              | How                                                                                                  |
|----------|---------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Android  | `performancebench-mobile-<ver>.apk`               | Enable *Install unknown apps* for your file manager / browser, then tap the APK.                     |
| iOS      | `performancebench-mobile-<ver>-unsigned.ipa`      | Sideload via [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io). Free Apple IDs need re-sign every 7 days. |

Latest builds live on the [GitHub Releases](https://github.com/sundarlohar007/Benchify/releases) page.

> **Android signing note**: the GitHub-published APK is signed with an ephemeral CI debug key (B-069 / S-19 follow-up). Android refuses signature mismatches on update — uninstall the prior version before installing a new release.

## First run

1. Install the APK / IPA above and open it.
2. The app boots into **Connect to Server**.
3. Enter the URL of your Benchify desktop's HTTP API — typically `https://<your-desktop-LAN-IP>:<port>` while both devices are on the same network.
4. Paste the API token your desktop generated. *(Token-generation flow is tracked under B-083 — currently you copy/paste manually.)*
5. Tap **Connect**. On success the app jumps to the Sessions tab.

Once connected, the URL + token persist across launches via `SharedPreferences` *(token stored in plain prefs today — B-054 will move it to platform-secure storage)*.

## Build from source

```bash
flutter pub get
flutter run                       # debug build, attached device
flutter build apk --release       # Android APK in build/app/outputs/flutter-apk/
flutter build ios --release --no-codesign   # iOS .app — needs macOS host
```

The release pipeline lives in [`.github/workflows/release.yml`](../.github/workflows/release.yml) at the repo root; it produces both the APK and an unsigned IPA on each `v*` tag.

## License

MIT — see [`LICENSE`](../LICENSE) at the repo root.
