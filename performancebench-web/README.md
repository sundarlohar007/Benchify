# PerformanceBench Web Dashboard

React + TypeScript web analytics dashboard for PerformanceBench session data.

**Part of the [Benchify](https://github.com/sundarlohar007/Benchify) project — free, open-source performance profiler.**

## Prerequisites

- **Node.js 22+**
- **pnpm 10+** (`npm install -g pnpm`)

## Setup

```bash
pnpm install
```

## Development

```bash
pnpm dev
```

Open `http://localhost:5173` in your browser. The dashboard connects to the PerformanceBench API server.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_BASE_URL` | `http://localhost:3000` | Backend API server URL |
| `VITE_WS_URL` | `ws://localhost:3000/ws` | WebSocket endpoint for live metrics |

## Build

```bash
pnpm build        # Production build → dist/
pnpm preview      # Preview production build locally
```

## Type Checking

```bash
pnpm exec tsc --noEmit
```

## Architecture

```
src/
├── components/
│   ├── admin/           # SSO config, user management, audit log
│   ├── auth/            # Login form, protected route wrapper
│   ├── charts/          # LiveChart (real-time), TrendChart (historical)
│   ├── layout/          # Sidebar, Header, AppLayout
│   └── sessions/        # SessionDetailTabs (metrics, issues, charts)
├── hooks/               # Data fetching hooks (TanStack Query)
│   ├── useAuth.ts       # Authentication + token management
│   ├── useSessions.ts   # Session CRUD + detail queries
│   ├── useAlerts.ts     # Alert rules + events
│   ├── useAudit.ts      # Audit log pagination
│   ├── useAdmin.ts      # User/SSO management
│   ├── useTeams.ts      # Org/project/member management
│   ├── useTrends.ts     # Cross-session trend data
│   └── useWebSocket.ts  # WebSocket with auto-reconnect
├── lib/
│   ├── api.ts           # HTTP client (apiFetch wrapper)
│   ├── utils.ts         # Formatting helpers (KB, duration, CSV)
│   └── constants.ts     # App name, defaults
├── routes/              # TanStack Router file-based routes
│   ├── live.tsx         # Real-time metric streaming
│   ├── alerts.tsx       # Alert rules + event history
│   ├── sessions/
│   │   └── $sessionId.tsx  # Session detail (export, Jira integration)
│   └── admin/
│       └── audit.tsx    # Audit log (admin/auditor only)
└── main.tsx             # App entry point
```

## Tech Stack

- **React 19** + **TypeScript**
- **TanStack Router** — file-based routing
- **TanStack Query** — server state management
- **Chart.js** + **react-chartjs-2** — data visualization
- **Zod** — runtime schema validation
- **react-hook-form** — form management
- **Vite** — build tooling

## License

MIT — see LICENSE file in the monorepo root.
