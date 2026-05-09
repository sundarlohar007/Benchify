# Slice 06 — Flutter mobile: Android side

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench-mobile/android/` — Gradle build configs, Manifests (main / debug / profile), the single Kotlin Activity, splash drawables, themes.

| Path                                                                  | LOC | Read |
|-----------------------------------------------------------------------|----:|:----:|
| `app/build.gradle.kts`                                                |  44 | full |
| `app/src/main/AndroidManifest.xml`                                    |  46 | full |
| `app/src/debug/AndroidManifest.xml`                                   |   8 | full |
| `app/src/profile/AndroidManifest.xml`                                 |   8 | full |
| `app/src/main/kotlin/.../MainActivity.kt`                             |   5 | full |
| `app/src/main/res/values/styles.xml`                                  |  19 | full |
| `app/src/main/res/values-night/styles.xml`                            |  19 | full |
| `app/src/main/res/drawable/launch_background.xml`                     |  12 | full |
| `app/src/main/res/drawable-v21/launch_background.xml`                 |  12 | full |
| `build.gradle.kts`                                                    |  25 | full |
| `settings.gradle.kts`                                                 |  27 | full |
| `gradle.properties`                                                   |   2 | full |
| `gradle/wrapper/gradle-wrapper.properties`                            |   5 | full |

## User-flow trace

> *Install APK → tap launcher icon → Android creates LaunchTheme window → Flutter engine boots → companion UI renders.*

1. APK is installed; launcher reads main `AndroidManifest.xml`.
2. **Pre-fix (B-066)**: launcher displays `performancebench_mobile` as the app label — user-facing text. Bad branding.
3. Tap → Android creates an Activity with `LaunchTheme` parent `@android:style/Theme.Light.NoTitleBar` (B-070); window background resolves to `launch_background.xml` which hardcoded `@android:color/white` → user gets a brief white flash before Flutter's dark UI renders.
4. Flutter engine starts; first GET to the server runs.
5. **Pre-fix (B-065)**: in a release/profile build, the request fails with `SocketException: failed host lookup` because `INTERNET` is only declared in the debug/profile manifests, not the main one. Release APK couldn't reach any server.

## Findings

| ID    | Sev   | Title                                                                                          | Status              |
|-------|-------|------------------------------------------------------------------------------------------------|---------------------|
| B-065 | HIGH  | `INTERNET` permission missing from main `AndroidManifest.xml` — release APK can't reach server | FIXED in this slice |
| B-066 | MED   | App label is `performancebench_mobile` (raw module name) instead of a branded string           | FIXED in this slice |
| B-067 | MED   | No `usesCleartextTraffic` config; couples with B-058 (HTTPS enforcement)                       | DEFERRED-TO-S20     |
| B-068 | LOW   | No `android:dataExtractionRules` / backup rules — token in `SharedPreferences` may end up in Auto Backup | DEFERRED-TO-S20 |
| B-069 | LOW   | Release `signingConfig` falls back to debug keys; users can't ship updates that match prior installs | DEFERRED-TO-S19 |
| B-070 | NIT   | Launch theme is `Theme.Light.NoTitleBar` + white drawable — flashes white before Flutter's dark UI | FIXED in this slice |

## Cross-slice notes

- **B-067 + B-058 (mobile transport security)**: bundle these in S-20 with `flutter_secure_storage` migration (B-054).
- **B-068**: the same token covered by B-054 also lives in Android's auto-backup unless we declare a `dataExtractionRules` XML opting it out. Land alongside B-054.
- **B-069**: the existing `release.yml` workflow uses an ephemeral CI key for the published APK (release notes already warn users about needing to uninstall before updating). Long-term fix is to inject a stable upload key via GitHub Secrets — pinned to S-19 (build/CI).

## Local fixes summary

1. **B-065 (HIGH)** — added `<uses-permission android:name="android.permission.INTERNET"/>` to the main manifest above the `<application>` tag, with a leading comment explaining why the debug + profile manifests aren't sufficient for release.
2. **B-066 (MED)** — `android:label` flipped from `"performancebench_mobile"` → `"Benchify Mobile"`. Matches the in-app `MaterialApp.title` already set on the Flutter side.
3. **B-070 (NIT)** — `LaunchTheme` and `NormalTheme` re-parented to `@android:style/Theme.Black.NoTitleBar`; `drawable/launch_background.xml` swapped `@android:color/white` → `?android:colorBackground` so the day-mode pre-API-21 path matches the v21+ drawable. The night drawable was already correct; audit aligns the day branch.

## Verification

`Read` of all 13 files — no parse-affecting changes. Cannot run `flutter build apk` from the audit container (no Android SDK installed); verification deferred to CI on next push to `audit/v0.1.x`.
