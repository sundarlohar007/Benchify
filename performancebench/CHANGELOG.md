# Changelog

## v1.0.0 — 2024-05-04

Initial release — External Profiling MVP.

### Features
- Real-time FPS, CPU, Memory, Battery, Network, Thermal, GPU metrics at 1Hz
- Android profiling via ADB (all platforms)
- iOS profiling via pyidevice (macOS only)
- VS Code-inspired dark theme (4 variants: Dark/Light/High Contrast/System)
- Session history with filtering, sorting, and search
- Session detail with 5-tab layout (Scorecard/Charts/FPS Analysis/Markers/Screenshots)
- Session comparison with overlaid charts and delta table
- JSON and CSV export (manual trigger only)
- Post-session analytics engine (FPS stats, power math, memory trends, network totals)
- Per-marker statistics
- 300-sample ring buffer (60s rolling window)
- SQLite batch writer (5s flush interval)
- Screenshot capture pipeline (5 sizes, JPEG, Lanczos resize)
- Settings panel (6 categories)
- Error handler with Debug/Release dual mode
- 3-step onboarding wizard
- Bundled demo session
- Windows NSIS installer, macOS DMG, Linux AppImage

### Security
- Zero network calls (except GitHub Releases version check — opt-in)
- All data local only — verified by CI packet capture test
- CSV formula injection mitigation
- MIT license
