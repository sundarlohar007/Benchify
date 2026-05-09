# Slice 07 — Flutter mobile: iOS side

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench-mobile/ios/` — Info.plist, AppDelegate / SceneDelegate Swift, Flutter `.xcconfig` files, AppFrameworkInfo, RunnerTests stub.

| Path                                      | LOC | Read |
|-------------------------------------------|----:|:----:|
| `Runner/Info.plist`                       |  70 | full |
| `Runner/AppDelegate.swift`                |  16 | full |
| `Runner/SceneDelegate.swift`              |   6 | full |
| `Flutter/AppFrameworkInfo.plist`          |  24 | full |
| `Flutter/Debug.xcconfig`                  |   1 | full |
| `Flutter/Release.xcconfig`                |   1 | full |
| `RunnerTests/RunnerTests.swift`           |  12 | full |

No `Podfile` in repo (flutter regenerates it on first run; `.gitignore` likely excludes it). `project.pbxproj` skimmed only — auto-generated.

## User-flow trace

> *Sideload IPA → tap launcher → iOS shows app under whatever name plist exposes → Flutter renders.*

1. iOS reads `Info.plist` for bundle metadata.
2. **Pre-fix (B-071)**: home-screen icon labelled `"Performancebench Mobile"` (mid-sentence capitalisation). `CFBundleName` (used by some system UIs as fallback) was `performancebench_mobile`. Branding mismatch with `Benchify Mobile` set elsewhere.
3. `AppDelegate.application(...)` boots Flutter engine; `SceneDelegate` is empty `FlutterSceneDelegate` subclass.
4. First HTTPS request runs through default ATS — works fine.
5. **Pre-fix (B-073)**: a user pointing the app at `http://192.168.…` would silently fail because iOS 14+ blocks cleartext by default and the plist has no exception. Same shape as Android B-067.

## Findings

| ID    | Sev   | Title                                                                                              | Status              |
|-------|-------|----------------------------------------------------------------------------------------------------|---------------------|
| B-071 | MED   | `CFBundleDisplayName` "Performancebench Mobile" — wrong branding                                   | FIXED in this slice |
| B-072 | MED   | `CFBundleName` "performancebench_mobile" — raw module name leaking into system UIs                 | FIXED in this slice |
| B-073 | MED   | No `NSAppTransportSecurity` config; cleartext `http://` to a self-hosted server silently blocked   | DEFERRED-TO-S20     |
| B-074 | NIT   | `RunnerTests.swift` is the empty Xcode template — no actual tests                                  | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-073 + B-067 + B-058**: Android cleartext + iOS ATS + URL validation are all the same security decision. Bundle in S-20 with `flutter_secure_storage` migration (B-054) and HTTPS-only enforcement.
- iOS-side build/CI key pinning sits in `release.yml`'s `build-macos` job; that's S-19 territory. No iOS-only signing finding here — the IPA is intentionally unsigned per release-notes design.

## Local fixes summary

1. **B-071 + B-072 (combined)**: `Runner/Info.plist`
   - `CFBundleDisplayName`: `"Performancebench Mobile"` → `"Benchify Mobile"`.
   - `CFBundleName`: `"performancebench_mobile"` → `"Benchify Mobile"` (matches `MaterialApp.title` and Android `android:label`).

## Verification

`Read` of all 7 files — no parse-affecting changes (only string-value edits inside an existing `<key>/<string>` pair). Cannot run `xcodebuild` from the audit container; verification deferred to CI on next `release.yml` run.
