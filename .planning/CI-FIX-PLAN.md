# CI Fix Plan — Issues #46 + #47

**Date:** 2026-05-08
**Failures:** Rust 1.95.0 lints, TS type drift, NSIS syntax, AppImage desktop file, missing pytest
**Changes:** 25 across 14 files in 6 independent groups

---

## Wave 1 — Rust Library (12 changes, 5 files)

### PLAN-01: Fix Clippy 1.95.0 lints in `performancebench-injector/sdk/src/`

**Depends on:** nothing
**Files modified:** `jni_bridge.rs`, `transport.rs`, `net_per_process.rs`, `gpu.rs`, `pdh.rs`

#### Task 1.1: `jni_bridge.rs` — JNI type imports + warnings
- **read_first:** `performancebench-injector/sdk/src/jni_bridge.rs`, `performancebench-injector/sdk/Cargo.toml`
- **action:**
  1. Line 10: change `use jni::objects::{JClass, JObject};` → `use jni::objects::{JClass, JObject, JString};`
  2. Line 32: change `mut env: JNIEnv,` → `env: JNIEnv,`
  3. Line 104: change `mut env: JNIEnv,` → `env: JNIEnv,`
  4. Lines 109-110: change both `.unwrap_or_default().into()` → `.map(|s| s.into()).unwrap_or_default()`
- **acceptance_criteria:**
  - `jni_bridge.rs` contains `use jni::objects::{JClass, JObject, JString};`
  - `jni_bridge.rs` line 32 is `env: JNIEnv,` (no mut)
  - `jni_bridge.rs` line 104 is `env: JNIEnv,` (no mut)
  - `jni_bridge.rs` lines 109-110 use `.map(|s| s.into()).unwrap_or_default()`
  - `cargo clippy -- -D warnings` passes on Linux host
  - `cargo ndk build --release -t arm64-v8a` compiles without `JString` errors

#### Task 1.2: `transport.rs` — option_map_unit_fn + unused import
- **read_first:** `performancebench-injector/sdk/src/transport.rs`
- **action:**
  1. Line 16: remove `gpu` from the `use crate::metrics::{...}` import list
  2. Lines 49: change `METRIC_STATE.lock().ok().map(|mut s| s.session_id = id.to_string());` → `if let Ok(mut s) = METRIC_STATE.lock() { s.session_id = id.to_string(); }`
  3. Line 241: change `METRIC_STATE.lock().ok().map(|mut s| s.frame_deltas.push(delta_ns));` → `if let Ok(mut s) = METRIC_STATE.lock() { s.frame_deltas.push(delta_ns); }`
- **acceptance_criteria:**
  - `transport.rs` import line does not contain `gpu`
  - `transport.rs:49` contains `if let Ok(mut s) = METRIC_STATE.lock()`
  - `transport.rs:241` contains `if let Ok(mut s) = METRIC_STATE.lock()`
  - `cargo clippy -- -D warnings` shows zero errors from transport.rs

#### Task 1.3: `net_per_process.rs` — unused import + static_mut_refs + unused variable
- **read_first:** `performancebench-injector/sdk/src/metrics/net_per_process.rs`
- **action:**
  1. Line 18: remove `use std::collections::HashMap;`
  2. Add `#[allow(static_mut_refs)]` before `pub fn collect(...)` function (line ~186)
  3. Line 208: change `let (deltas, result) = match prev {` → `let (_deltas, result) = match prev {`
- **acceptance_criteria:**
  - `net_per_process.rs` does not contain `use std::collections::HashMap`
  - `net_per_process.rs` contains `#[allow(static_mut_refs)]` before `pub fn collect`
  - `net_per_process.rs:208` uses `_deltas`
  - `cargo clippy -- -D warnings` shows zero errors from net_per_process.rs

#### Task 1.4: `gpu.rs` — trim_split_whitespace
- **read_first:** `performancebench-injector/sdk/src/metrics/gpu.rs`
- **action:**
  1. Line 10: change `content.trim().split_whitespace()` → `content.split_whitespace()`
  2. Line 25: change `content.trim().split_whitespace()` → `content.split_whitespace()`
- **acceptance_criteria:**
  - `gpu.rs` line 10 is `content.split_whitespace()` (no .trim())
  - `gpu.rs` line 25 is `content.split_whitespace()` (no .trim())
  - `cargo clippy -- -D warnings` shows zero errors from gpu.rs

#### Task 1.5: `pdh.rs` — cfg-gate `now_ms()`
- **read_first:** `performancebench-injector/sdk/src/pc_metrics/pdh.rs`
- **action:**
  1. Line 494 (before `fn now_ms()`): add `#[cfg(windows)]`
- **acceptance_criteria:**
  - `pdh.rs` contains `#[cfg(windows)]` on the line immediately before `fn now_ms()`
  - `cargo clippy -- -D warnings` shows zero errors from pdh.rs

#### Verification — all Rust
- `cd performancebench-injector/sdk && cargo clippy -- -D warnings` exits 0
- `cd performancebench-injector/sdk && cargo test --no-run` compiles all test targets
- Android cross-compile: `cargo ndk -t arm64-v8a build --release` exits 0

---

## Wave 2 — TypeScript (8 changes, 8 files)

### PLAN-02: Fix TypeScript type errors in `performancebench-web/src/`

**Depends on:** nothing (independent from Rust)
**Files modified:** `tsconfig.json`, `useWebSocket.ts`, `TrendChart.tsx`, `SessionTable.tsx`, `admin/audit.tsx`, `admin/users.tsx`, `lenses.tsx`, `$sessionId.tsx`

#### Task 2.1: `tsconfig.json` — enable strictNullChecks
- **read_first:** `performancebench-web/tsconfig.json`
- **action:**
  1. Add `"strictNullChecks": true` inside `compilerOptions`. The file currently has `"strict": false` — strictNullChecks overrides it.
- **acceptance_criteria:**
  - `tsconfig.json` contains `"strictNullChecks": true`

#### Task 2.2: `useWebSocket.ts` — useRef initial value
- **read_first:** `performancebench-web/src/hooks/useWebSocket.ts`
- **action:**
  1. Line 11: change `const reconnectTimeoutRef = useRef<number>();` → `const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);`
- **acceptance_criteria:**
  - `useWebSocket.ts:11` contains `useRef<ReturnType<typeof setTimeout>>`

#### Task 2.3: `TrendChart.tsx` — chart.js scale title type assertion
- **read_first:** `performancebench-web/src/components/charts/TrendChart.tsx`
- **action:**
  1. Line 125-133: wrap the `y` scale spread with type assertion. Change:
  ```tsx
  y: {
    ...base.scales.y,
    title: { ... },
  },
  ```
  to:
  ```tsx
  y: {
    ...(base.scales.y as Record<string, unknown>),
    title: { ... },
  } as any,
  ```
- **acceptance_criteria:**
  - `TrendChart.tsx` contains `base.scales.y as Record<string, unknown>`

#### Task 2.4: `SessionTable.tsx` — route params type assertion
- **read_first:** `performancebench-web/src/components/sessions/SessionTable.tsx`
- **action:**
  1. Lines 278-282: add `as any` cast on params:
  ```tsx
  navigate({
    to: '/sessions/$sessionId',
    params: { sessionId: row.original.id } as any,
  })
  ```
- **acceptance_criteria:**
  - `SessionTable.tsx` contains `params: { sessionId: row.original.id } as any`

#### Task 2.5: `admin/audit.tsx` — beforeLoad context type
- **read_first:** `performancebench-web/src/routes/admin/audit.tsx`
- **action:**
  1. Line 22: change `const user = context.queryClient.getQueryData...` to:
  ```tsx
  const ctx = context as { queryClient: QueryClient };
  const user = ctx.queryClient.getQueryData<User>(['auth', 'me']);
  ```
  2. Add import: `import type { QueryClient } from '@tanstack/react-query';` at top if not already present
- **acceptance_criteria:**
  - `admin/audit.tsx` contains `context as { queryClient: QueryClient }`

#### Task 2.6: `admin/users.tsx` — beforeLoad context type
- **read_first:** `performancebench-web/src/routes/admin/users.tsx`
- **action:**
  1. Line 11: same pattern as Task 2.5:
  ```tsx
  const ctx = context as { queryClient: QueryClient };
  const user = ctx.queryClient.getQueryData<User>(['auth', 'me']);
  ```
  2. Add import: `import type { QueryClient } from '@tanstack/react-query';` if not already present
- **acceptance_criteria:**
  - `admin/users.tsx` contains `context as { queryClient: QueryClient }`

#### Task 2.7: `lenses.tsx` — search params type assertion
- **read_first:** `performancebench-web/src/routes/lenses.tsx`
- **action:**
  1. Line 127: change `navigate({ to: '/sessions', search: Object.fromEntries(params) });` to:
  ```tsx
  navigate({ to: '/sessions', search: Object.fromEntries(params) as any });
  ```
- **acceptance_criteria:**
  - `lenses.tsx` contains `Object.fromEntries(params) as any`

#### Task 2.8: `$sessionId.tsx` — MetricSample double-cast
- **read_first:** `performancebench-web/src/routes/sessions/$sessionId.tsx`
- **action:**
  1. Line 407: change `(s as Record<string, unknown>)[k]` to `(s as unknown as Record<string, unknown>)[k]`
- **acceptance_criteria:**
  - `$sessionId.tsx` contains `s as unknown as Record<string, unknown>`

#### Verification — all TypeScript
- `cd performancebench-web && pnpm exec tsc --noEmit` exits 0
- If strictNullChecks surfaces additional errors beyond the 8 fixed: each new error represents a null-safety bug. Mark them and either fix or add to backlog.

---

## Wave 3 — NSIS, Linux, Python, macOS (5 changes, 5 files)

### PLAN-03: Fix NSIS installer syntax

**Depends on:** nothing
**Files modified:** `performancebench/windows/installer/performancebench.nsi`

#### Task 3.1: Correct SetCompressor syntax
- **read_first:** `performancebench/windows/installer/performancebench.nsi`
- **action:**
  1. Replace lines 15-16:
  ```nsi
  SetCompressor lzma
  SetCompress solid
  ```
  with:
  ```nsi
  SetCompressor /SOLID lzma
  ```
- **acceptance_criteria:**
  - `performancebench.nsi` line 15 is `SetCompressor /SOLID lzma`
  - `performancebench.nsi` does not contain `SetCompress solid`

### PLAN-04: Fix Linux AppImage build + workflow fallback

**Depends on:** nothing
**Files modified:** `performancebench/linux/build_appimage.sh`, `.github/workflows/release.yml`

#### Task 4.1: `build_appimage.sh` — create .desktop file + accept VERSION env
- **read_first:** `performancebench/linux/build_appimage.sh`
- **action:**
  1. Line 9: already reads `VERSION="${VERSION:-1.0.0}"` — no change needed (workflow will pass env)
  2. Before line 31 (linuxdeploy invocation), add creation of minimal .desktop file:
  ```bash
  # Create minimal .desktop file for linuxdeploy
  mkdir -p AppDir/usr/share/applications
  cat > AppDir/usr/share/applications/performancebench.desktop << 'DESKTOPEOF'
  [Desktop Entry]
  Name=PerformanceBench
  Exec=performancebench
  Type=Application
  Categories=Development;
  DESKTOPEOF
  ```
  3. Change line 34 from `--desktop-file AppDir/data/flutter_assets/linux.desktop` to `--desktop-file AppDir/usr/share/applications/performancebench.desktop`
- **acceptance_criteria:**
  - `build_appimage.sh` creates `.desktop` file before linuxdeploy invocation
  - `build_appimage.sh` references `AppDir/usr/share/applications/performancebench.desktop`

#### Task 4.2: `release.yml` — handle .tar.gz fallback in staging step
- **read_first:** `.github/workflows/release.yml`
- **action:**
  1. In `build-linux` job, "Stage AppImage" step (around line 77-86): after the `find ... -name "*.AppImage"` logic, add fallback:
  ```bash
  if [ -z "$APPIMAGE" ]; then
    TARBALL=$(find performancebench -maxdepth 4 -name "*.tar.gz" | head -1)
    if [ -n "$TARBALL" ]; then
      cp "$TARBALL" "dist/performancebench-${VER}-linux-x86_64.tar.gz"
    else
      echo "::error::No AppImage or tar.gz produced"
      exit 1
    fi
  else
    cp "$APPIMAGE" "dist/performancebench-${VER}-linux-x86_64.AppImage"
  fi
  ```
- **acceptance_criteria:**
  - `release.yml` "Stage AppImage" step handles both `.AppImage` and `.tar.gz`
  - No exit 1 when only `.tar.gz` is produced

### PLAN-05: Fix Python missing pytest

**Depends on:** nothing
**Files modified:** `performancebench-injector/requirements.txt`

#### Task 5.1: Add pytest to requirements
- **read_first:** `performancebench-injector/requirements.txt`
- **action:**
  1. Add `pytest>=7.0` as line 3
- **acceptance_criteria:**
  - `requirements.txt` contains `pytest>=7.0`
  - `pip install -r requirements.txt && python -m pytest --version` works

### PLAN-06: Fix macOS DMG VERSION env var

**Depends on:** nothing
**Files modified:** `.github/workflows/release.yml`

#### Task 6.1: Pass VERSION to package_dmg.sh
- **read_first:** `.github/workflows/release.yml`, `performancebench/macos/package_dmg.sh`
- **action:**
  1. In `build-macos` job, "Build macOS desktop DMG" step (around line 124): add `VERSION` env:
  ```yaml
  - name: Build macOS desktop DMG
    working-directory: performancebench
    env:
      VERSION: ${{ needs.resolve-version.outputs.version }}
    run: |
      flutter pub get
      flutter build macos --release
      bash macos/package_dmg.sh
  ```
- **acceptance_criteria:**
  - `release.yml` build-macos job passes `VERSION` env var to `package_dmg.sh`
  - DMG is named `PerformanceBench-0.1.0.dmg` (not 1.0.0)

---

## Execution Order

```
Wave 1 (Rust)  ─┐
Wave 2 (TS)    ─┤  All six groups are independent — can run in parallel
Wave 3 (NSIS)  ─┤
Wave 4 (Linux) ─┤
Wave 5 (Python)─┤
Wave 6 (macOS) ─┘
```

All 6 groups touch different files. No merge conflicts. Commit each group separately.

## Post-Fix Verification

1. Push to branch, trigger CI
2. All workflow jobs must pass: TypeScript Check, Build (web), Clippy, Test SDK (host), Python injector tests, Build Android .so (all 3 targets), build-linux, build-macos, build-windows, build-plugins, release
