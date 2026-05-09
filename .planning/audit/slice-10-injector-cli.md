# Slice 10 — Injector: CLI + workflows

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

Top-level orchestrator for the injection pipeline plus dependency manifests + helper modules.

| Path                                             | LOC | Read |
|--------------------------------------------------|----:|:----:|
| `injector_cli.py`                                | 485 | full |
| `requirements.txt`                               |   3 | full |
| `injector/aab_converter.py`                      | 117 | full |
| `injector/proguard_helper.py`                    | 139 | full |
| `injector/{ipa_injector,ipa_verifier,apple_signing}.py` | — | partial — these are large; their CLI surface (read here) is what S-10 cares about, internals belong with the iOS-side audit threads (B-073/B-077..B-072 already noted) |

## User-flow trace

> *Desktop spawns `python injector_cli.py inject --apk … --method smali …`. CLI orchestrates `validate → decompile → smali → manifest → rebuild → resign`. Stdout is line-delimited JSON consumed by `InjectionService` on the desktop side.*

1. CLI boots, runs `_read_stdin_json()` to pick up passwords sent under T-04-02. **Pre-fix (B-092)**: this function aliased the std-library `json` as `_json` *inside its own scope only*. The rest of the file used a bare `json` reference — but no top-level `import json` existed. The smali path crashed at the very first `click.echo(json.dumps(...))` with `NameError: name 'json' is not defined`.
2. Smali method runs through six steps; each emits a structured JSON line. **Pre-fix (B-094)**: any subprocess failure (apktool, apksigner, …) raised an exception that escaped through Click as a stderr traceback — the desktop's NDJSON reader saw the stream end without a `step=error` event, so the UI hung on "running…".
3. tmpdir is created via `tempfile.mkdtemp` and never cleaned up (B-098). Each successful or failed run leaves a multi-MB extraction.
4. On the AAB path, `aab_converter` calls `bundletool` with `--ks-pass=pass:{password}` literal argv (B-095) — sister of B-088's apksigner leak, fixed in S-09.

## Findings

| ID    | Sev   | Title                                                                                              | Status              |
|-------|-------|----------------------------------------------------------------------------------------------------|---------------------|
| B-092 | HIGH  | `injector_cli.inject()` references bare `json` but only `import json as _json` exists locally — smali path crashes immediately | FIXED in this slice |
| B-093 | MED   | `@click.version_option(version="1.0.0")` hardcoded — same drift as B-024 / B-044 / B-079           | FIXED in this slice |
| B-094 | MED   | `inject()` smali path has no try/except; subprocess failures escape as stderr instead of structured JSON `step=error` | FIXED in this slice |
| B-095 | MED   | `aab_converter` passes keystore password via `pass:{value}` argv (sister of B-088, but bundletool) | DEFERRED-TO-S20     |
| B-096 | LOW   | `--output` defaults relative to CWD; injected APK lands wherever the user happened to launch from  | DEFERRED-TO-S20     |
| B-097 | LOW   | `proguard_helper` opens `mapping.txt` and smali files without explicit encoding                    | FIXED in this slice |
| B-098 | LOW   | `tmpdir` never cleaned up after `inject` (success or failure); disk leak per run                   | FIXED in this slice |
| B-099 | NIT   | `pytest` sits in production `requirements.txt` instead of a dev manifest                           | FIXED in this slice |
| B-100 | NIT   | `verify` subcommand declares `--keystore` but never reads it                                       | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-095** uses bundletool, which doesn't support `env:VAR` — only `pass:`, `file:`, and `stdin`. Cleanest port: write password to a `tempfile.NamedTemporaryFile(mode="w", delete=False)` with `chmod 0600` (POSIX) / `os.replace` semantics (Windows), pass `--ks-pass=file:/path`, then `os.unlink`. Defer with the rest of the password-handling polish.
- **B-100** carries the same shape as B-064 (unused import in mobile app.dart): cosmetic, but a teaching moment on stale CLI surfaces. Bundle into S-20 cleanup.

## Local fixes summary

1. **B-092 (HIGH)** — added top-level `import json` (and `tempfile`, `shutil` while in the area) and dropped the in-function `import json as _json` alias. The smali code path can now actually emit its first event.
2. **B-093 (MED)** — version literal flipped to `"0.1.1"` to match the published release line; TODO references S-19 for `package_info`-style auto-versioning. Sister fix to B-024 + B-044 + B-079.
3. **B-094 + B-098 (MED + LOW combined)** — wrapped the entire smali pipeline in `try / except / finally`:
   - `current_step` tracks the most-recent "running" event; on exception we emit `{"step": current_step, "status": "fail", "detail": "..."}` plus a terminal `{"step": "error", "status": "fail", ...}` so the desktop's NDJSON reader sees a clean close.
   - The exception is re-raised so Click maps to a non-zero exit code.
   - `finally` clause `shutil.rmtree(tmpdir, ignore_errors=True)` — but only when we created the tmpdir ourselves. A caller passing `--work-dir` keeps their inspect-friendly directory.
4. **B-097 (LOW)** — `proguard_helper.py`'s three file-open sites now pass `encoding="utf-8", errors="replace"`. Default platform encoding (CP-1252 on Windows) was an obscure failure mode for non-ASCII source paths in `mapping.txt`.
5. **B-099 (NIT)** — split `requirements.txt` into runtime-only + a new `requirements-dev.txt` that does `-r requirements.txt` + `pytest>=7.0`. Updated `injector-sdk-ci.yml`'s `python-tests` job to `pip install -r requirements-dev.txt`.

## Verification

```
$ python -m pytest tests/
106 passed, 5 warnings in 0.97s
```

All existing tests still green. No changes to test files in this slice.
