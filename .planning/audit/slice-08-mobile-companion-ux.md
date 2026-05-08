# Slice 08 — Mobile companion: install + first-run UX path

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

Cross-cutting slice: end-to-end user journey from "user opens GitHub Releases page" through "viewing sessions on phone." Touches **assets / pubspec / README** that didn't fit in S-05..S-07.

| Path                                                                  | Read |
|-----------------------------------------------------------------------|:----:|
| `performancebench-mobile/pubspec.yaml`                                | full |
| `performancebench-mobile/README.md`                                   | full |
| `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`| dimensions checked + xxxhdpi rendered |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (16 PNGs)            | 1024×1024 rendered |
| `release.yml` mobile bundle paths                                     | (covered in S-19, sanity-checked here) |

## User-flow trace

> *Goal: zero-friction path from "user reads release notes" to "user sees their first session row."*

1. **Discovery**: user lands on GitHub Releases page. Pre-fix: README inside `performancebench-mobile/` said "A new Flutter project" and linked to Flutter learning material — no install instructions, no link back to the parent project. (B-080)
2. **Download**: filename is `performancebench-mobile-<ver>.apk`, version `0.1.1-rc.6` from the latest release tag. **Pre-fix (B-079)**: `pubspec.yaml` shipped `version: 0.1.0+1` — drift from the published release name. The version baked into the binary metadata didn't match the filename users downloaded.
3. **Install (Android)**: `.apk` is debug-signed (S-06 B-069 deferred). Android prompts for "Install unknown apps" — expected, but not documented anywhere user-readable.
4. **Launch**: home-screen icon is the **default Flutter logo** on both Android (B-075, all 5 mipmap densities) and iOS (B-076, all 16 sizes from `Icon-App-1024x1024@1x.png` down). Visual indistinguishable from any other freshly-scaffolded Flutter project. Reduces user trust ("did I download the right APK?").
5. **Boot**: app shows the Connect screen.
6. **Connect**: text fields for `Server URL` and `API Token`. **Pre-fix (B-081)**: no help text on what the URL should look like beyond `hintText: "https://192.168.1.100:3000"`. **No mDNS / Bonjour discovery (B-082)**: user manually types the desktop's LAN IP. **No token-generation flow** in the desktop app referenced anywhere (B-083): user has to know which file holds the token.
7. **Connected**: lands on `/sessions`. End-to-end happy path completes.

## Findings

| ID    | Sev   | Title                                                                                          | Status              |
|-------|-------|------------------------------------------------------------------------------------------------|---------------------|
| B-075 | MED   | Android launcher icons are the default Flutter logo (all 5 mipmap densities)                    | DEFERRED-TO-S20     |
| B-076 | MED   | iOS app icons are the default Flutter logo (all 16 sizes in `AppIcon.appiconset`)              | DEFERRED-TO-S20     |
| B-077 | MED   | `pubspec.yaml` description was `"A new Flutter project."`                                      | FIXED in this slice |
| B-078 | MED   | `pubspec.yaml` `name: performancebench_mobile` — non-branded module name                       | DEFERRED-TO-S20     |
| B-079 | LOW   | `pubspec.yaml` version `0.1.0+1` drifted from desktop release line (`0.1.1`)                   | FIXED in this slice |
| B-080 | LOW   | `README.md` was the Flutter scaffolder default ("A new Flutter project")                        | FIXED in this slice |
| B-081 | MED   | First-run UX: `Server URL` field has only a placeholder; no instructions on what to put         | DEFERRED-TO-S20     |
| B-082 | LOW   | No mDNS / Bonjour discovery — user types desktop LAN IP manually                                | DEFERRED-TO-S20     |
| B-083 | LOW   | No token-generation flow referenced; user must locate token file manually                       | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-075 / B-076 (icons)**: needs an actual brand asset (likely a small SVG/PNG icon set). Couples with **macOS app_icon_*.png** already used by the desktop AppImage (S-19 build). Best landed in S-20 once we know which design language the project commits to.
- **B-078**: changing `name:` cascades into `applicationId`, `CFBundleIdentifier`, `package_info_plus` lookups, and the Android namespace. Cross-cuts S-06 + S-07 + S-19 release.yml signing config — defer.
- **B-081 / B-082 / B-083 (UX)**: the entire connect flow (B-051 / B-052 fixed the *crash*; UX still needs warmth). Bundle in S-20 with onboarding screen design.
- **B-077 (description)**: also affects the iOS App Store listing once a paid Apple Developer account is added; harmless as-is for free sideload.

## Local fixes summary

1. **B-077 (pubspec description)** — replaced the scaffolder default with a one-paragraph description that says what the app *is* (companion viewer for the desktop) and what it *isn't* (it doesn't profile). Picked up by `flutter pub` consumers + future App Store listing.
2. **B-079 (version drift)** — bumped `0.1.0+1` → `0.1.1+2`. Matches the latest desktop release line. Build-number incremented so Android's `versionCode` doesn't go backwards.
3. **B-080 (README)** — wrote a real `performancebench-mobile/README.md`:
   - install instructions for both platforms with file-naming convention,
   - link back to the parent project's Releases page,
   - first-run walkthrough,
   - build-from-source commands,
   - call-outs to the deferred items (B-054, B-069, B-083) so contributors landing here see the open work.

## Verification

- `Read` of pubspec.yaml + README.md after edits — formatted correctly.
- Cannot rebuild APK/IPA in audit container; release pipeline will pick up the new version on the next tag push.
