# PerformanceBench Injector

APK injection toolchain for embedding the PerformanceBench profiling SDK into Android apps.

**Part of the [Benchify](https://github.com/sundarlohar007/Benchify) project — free, open-source mobile performance profiler.**

## Purpose

Modify any Android APK (including AAB via bundletool conversion) to embed the PerformanceBench SDK. The injector decompiles the APK, patches Smali bytecode at Application.onCreate(), modifies AndroidManifest.xml for required permissions and services, rebuilds, re-signs, and verifies the result.

## Requirements

- **Python 3.10+**
- **Java JDK 11+** — required by apktool and apksigner
- **apktool** — APK decompile/rebuild tool ([install guide](https://apktool.org/docs/install))
- **bundletool** — AAB to APK conversion ([download](https://github.com/google/bundletool/releases) as bundletool.jar)
- **Android SDK Build Tools 34.0+** — provides apksigner for re-signing and verification

## Install

```bash
pip install -r requirements.txt
```

## CLI Usage

### Inject SDK into an APK

```bash
python injector_cli.py inject \
  --apk app.apk \
  --method smali \
  --keystore debug.keystore \
  --keystore-password android \
  --key-alias androiddebugkey \
  --key-password android \
  --sdk-so-dir ./libs \
  --output app_injected.apk
```

### Verify an already-injected APK

```bash
python injector_cli.py verify \
  --apk app_injected.apk \
  --keystore debug.keystore \
  --device-serial emulator-5554 \
  --package com.example.app
```

### Re-sign an APK

```bash
python injector_cli.py resign \
  --apk unsigned.apk \
  --keystore release.keystore \
  --keystore-password mypassword \
  --key-alias mykey \
  --key-password mykeypass \
  --output signed.apk
```

### Inject AAB (Android App Bundle)

```bash
python injector_cli.py inject \
  --apk app.aab \
  --aab \
  --method smali \
  --keystore debug.keystore \
  --key-alias androiddebugkey \
  --output app_injected.apk
```

## Architecture

```
performancebench-injector/
├── injector_cli.py              # Click CLI entry point (inject, verify, resign)
├── injector/
│   ├── apk_decompiler.py        # apktool wrapper for APK decompile + rebuild
│   ├── smali_patcher.py         # Smali bytecode patch at Application.onCreate()
│   ├── manifest_patcher.py      # AndroidManifest.xml modification (permissions, services)
│   ├── aab_converter.py         # bundletool wrapper for AAB -> universal APK
│   ├── proguard_helper.py       # ProGuard/R8 mapping.txt parser
│   ├── resigner.py              # apksigner wrapper for APK re-signing
│   └── verifier.py              # Multi-step verification (apksigner, smali, ADB)
├── tests/                       # pytest test suite
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

## Injection Pipeline

1. **Validate** — Check APK magic bytes (ZIP header), verify minSdk >= 21
2. **Decompile** — apktool d -f -s <apk> -o <workdir>
3. **Patch Smali** — Insert SDK init code into Application.onCreate()
4. **Patch Manifest** — Add permissions, BenchifyService, BenchifyBroadcastReceiver
5. **Rebuild** — apktool b <workdir> -o <unsigned.apk>
6. **Re-sign** — apksigner sign with user-provided keystore
7. **Verify** — apksigner verify, Smali patch validation, ADB connectivity test

## License

MIT — see LICENSE file in the monorepo root.
