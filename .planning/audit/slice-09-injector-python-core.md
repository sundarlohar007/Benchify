# Slice 09 — Injector: Python core

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench-injector/{frida,injector}/` — the actual APK / IPA injection pipeline.

| Path                                                | LOC | Read |
|-----------------------------------------------------|----:|:----:|
| `injector/smali_patcher.py`                         | 198 | full |
| `injector/manifest_patcher.py`                      | 198 | full |
| `injector/resigner.py`                              |  67 | full |
| `injector/apk_decompiler.py`                        | 136 | full |
| `injector/frida_injector.py`                        | 100 | full |
| `injector/verifier.py`                              | 200 | full |
| `frida/gadget_injector.py`                          | 232 | full |
| `injector/{apple_signing,ipa_injector,ipa_verifier,aab_converter,proguard_helper}.py` | — | head + skim (S-10 covers the CLI orchestrator that calls them) |
| `tests/test_apk_decompiler.py`, `tests/test_resigner.py` | — | full (modified) |

S-10 (Injector CLI) handles `injector_cli.py` + workflow orchestration; S-11/S-12 cover the Rust SDK side.

## User-flow trace

> *User picks APK → desktop spawns `injector_cli.py inject` → smali / manifest / resign → installable APK lands on disk → user pushes to device → app launches with SDK active.*

1. CLI calls `decompile_apk(apk, decoded)`. **Pre-fix (B-085)**: defaults to `apktool d -f -s`. `-s` is "skip smali decoding" — but smali decoding is the whole point. Decoded directory ends up with no `.smali` files.
2. CLI calls `find_application_smali(decoded)`. Walks for `.smali` files extending `Landroid/app/Application;`. **Pre-fix**: returns `None` because step 1 didn't produce smali.
3. CLI sees `None`, skips smali patch step. Manifest still patched, then `resign(...)` runs on the unmodified-classes APK.
4. Output APK installs and runs with **no SDK injected**. The CLI happily prints `step=done status=ok`. End user sees no metrics; appears "broken in some other way."
5. Frida path (`gadget_injector.inject_frida_gadget`) goes straight from input APK → output APK, copying entries through Python's `zipfile`. **Critical (B-084)**: this invalidates both V1 and V2 signatures, so the result won't install on stock Android. Doc-string says "Frida gadget injection leaves original signature intact" — wrong; the bytes are kept but the digest no longer matches the modified ZIP.

## Findings

| ID    | Sev      | Title                                                                                              | Status              |
|-------|----------|----------------------------------------------------------------------------------------------------|---------------------|
| B-084 | BLOCKER  | Frida path doesn't re-sign — modified APK fails signature verification on stock Android            | DEFERRED-TO-S20     |
| B-085 | HIGH     | `apk_decompiler` default `-s` flag skips smali; injector ships unmodified APKs as "ok"             | FIXED in this slice |
| B-086 | HIGH     | `smali_patcher` doesn't bump `.locals` count when injecting `v0` — possible verifier rejection     | DEFERRED-TO-S20     |
| B-087 | HIGH     | `smali_patcher` fallback hardcodes `Landroid/app/Application;` as super, ignoring real `.super`    | DEFERRED-TO-S20     |
| B-088 | MED      | `resigner` passes keystore + key passwords via `pass:` literal CLI args (visible in `ps`/Procmon)  | FIXED in this slice |
| B-089 | MED      | `manifest_patcher` exports `BenchifyBroadcastReceiver` to all apps (no signature permission)       | DEFERRED-TO-S20     |
| B-090 | LOW      | `find_application_smali` reads only first 4096 bytes — `.super` line beyond that is missed         | DEFERRED-TO-S20     |
| B-091 | LOW      | `verify_smali_patch` runs full apktool decompile just to grep for `SdkLoader.init` — slow          | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-084 (BLOCKER, frida path)**: doc string + injector_cli verification step claim "leaves original signature intact". Real options:
  1. Document that the frida path is for **rooted devices only** (where signature checks are bypassable), and gate the desktop UI accordingly.
  2. Re-sign with a debug key after gadget injection, defeating the "no keystore" promise.
  3. Drop the frida path entirely.
  Decision belongs in S-20 with the rest of the injection-flow gate work (similar shape to B-016 screenshot UI gate). Until then, end users hitting the Frida button get an install-fail on most devices.
- **B-086 / B-087 (smali correctness)**: needs a small smali bytecode model (read `.locals`, find super-class string from `.super` line). Bundle into S-20 as a single "smali correctness" follow-up.
- **B-089 (broadcast receiver security)**: `<receiver android:exported="true">` lets *any* app on the device send `com.benchify.COMMAND`. Should add `android:permission="dev.benchify.permission.COMMAND"` + `<permission ... protectionLevel="signature">` so only apps signed with the same key (i.e. the desktop's keystore-resigned debug builds) can drive automation. Defer with security batch.
- **B-091 (verify perf)**: replace full apktool decompile with `zipfile.ZipFile` extraction of `classes*.dex` + `dexdump`-based search (or just stat the size + checksum to short-circuit re-injection). Defer.

## Local fixes summary

1. **B-085 (HIGH)** — `apk_decompiler.py`:
   - Removed the wrong `else: cmd.append("-s")` branch.
   - Default mode now decodes both smali + resources.
   - `no_res=True` keeps the option to skip resources for speed; smali always decoded.
   - Test `test_calls_apktool_with_correct_args` flipped to assert `-s NOT in args`.
   - New test `test_no_res_skips_resource_decoding_only` covers the optional skip path.
2. **B-088 (MED)** — `resigner.py`:
   - Switched to `apksigner --ks-pass env:PB_KS_PASS --key-pass env:PB_KEY_PASS` form.
   - Subprocess `env=` carries the password values; `os.environ` left untouched (no race with concurrent callers).
   - Test rewritten to assert `pass:password` *not* in args, `env:PB_KS_PASS` is, and that the env dict carries the actual password value.
   - Aligns with the T-04-02 contract that `injection_service.dart` and the docstring already promised but the code didn't deliver.

## Verification

```
$ python -m pytest tests/
106 passed, 5 warnings in 0.87s
```

All existing tests + 1 new test pass. Two existing tests (resigner, apk_decompiler) updated to match new contracts.
