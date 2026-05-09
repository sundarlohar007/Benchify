# Slice 19 — Build, packaging, CI

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All CI workflows, packaging scripts, and build configuration.

| Path                                              | LOC | Read |
|---------------------------------------------------|----:|:----:|
| `.github/workflows/desktop-ci.yml`                | 148 | full |
| `.github/workflows/injector-sdk-ci.yml`           | 105 | full |
| `.github/workflows/release.yml`                   | 335 | full |
| `.github/workflows/server-ci.yml`                 |  97 | full |
| `.github/workflows/web-dashboard-ci.yml`          |  51 | full |
| `.github/workflows/self-heal.yml`                 |  85 | full |
| `.github/workflows/ios-test.yml`                  | 114 | full |
| `.github/workflows/packet-capture-test.yml`       |  76 | full |
| `performancebench/windows/installer/performancebench.nsi` | 74 | full |
| `performancebench/linux/build_appimage.sh`        |  91 | full |
| `performancebench/macos/package_dmg.sh`           |  41 | full |
| `performancebench/macos/package_pkg.sh`           |  83 | full |
| `.gitignore`                                      |  26 | full |

## Key themes

### 1. SECURITY: Shell injection in release workflow (release.yml)
`${{ inputs.tag }}` was directly interpolated in a shell `run:` block. Anyone with workflow_dispatch permission could inject arbitrary shell commands. Fixed by passing via `env:` block.

### 2. Non-blocking CI (multiple workflows)
`|| true`, `2>&1 || true`, and `continue-on-error: true` are used pervasively across `desktop-ci.yml`, `injector-sdk-ci.yml`, and `server-ci.yml`. This makes flutter analyze, cargo clippy, pytest, and even server tests non-blocking. CI passes regardless of actual results.

### 3. Workflow name collision (server-ci.yml + desktop-ci.yml)
Both were named `name: CI`, breaking `self-heal.yml`'s workflow reference. Fixed by renaming `server-ci.yml` to `Server CI`.

### 4. Installer version drift (performancebench.nsi)
NSIS script hardcodes `PRODUCT_VERSION "1.0.0"`. Every Windows installer shows "1.0.0" in Add/Remove Programs regardless of the actual release tag.

### 5. CI waste (desktop-ci.yml)
Linux build step re-installed the exact same `apt-get` packages already installed 60 lines earlier. Fixed.

## Findings

| ID    | Sev  | Title                                                      | Status              |
|-------|------|------------------------------------------------------------|---------------------|
| B-174 | HIGH | Release workflow: shell injection via `inputs.tag`         | FIXED in this slice |
| B-175 | MED  | `server-ci.yml` and `desktop-ci.yml` both named "CI"       | FIXED in this slice |
| B-176 | LOW  | Linux build step duplicates apt-get install                | FIXED in this slice |
| B-177 | MED  | `flutter analyze` failures silently swallowed by `|| true` | DEFERRED-TO-S20     |
| B-178 | MED  | Clippy and pytest failures silently swallowed              | DEFERRED-TO-S20     |
| B-179 | MED  | Server test step has `continue-on-error: true`             | DEFERRED-TO-S20     |
| B-180 | MED  | NSIS installer version hardcoded to "1.0.0"                | DEFERRED-TO-S20     |
| B-181 | NIT  | AppImage script downloads linuxdeploy to /tmp (no cache)   | DEFERRED-TO-S20     |

## Verification

```
All workflow YAML files pass yamllint (valid structure).
No runtime tests — CI workflows are validated by GitHub Actions.
```
