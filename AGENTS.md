# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Reactive Resume is a single-package full-stack TypeScript app (not a monorepo) built with [TanStack Start](https://tanstack.com/start/latest/docs/framework/react/overview) (React, Vite, Nitro). It serves both frontend and API on port 3000.

This project uses [Vite+](https://vite.dev/blog/announcing-viteplus), a unified toolchain built on top of Vite, Rolldown, Vitest, tsdown, Oxlint, Oxfmt, and Vite Task. Vite+ wraps runtime management, package management, and frontend tooling in a single global CLI called `vp`. All modules should be imported from the `vite-plus` dependency (e.g., `import { defineConfig } from 'vite-plus'` or `import { expect, test, vi } from 'vite-plus/test'`).

## Key Libraries

| Area                 | Library                                                                  | Docs                               |
| -------------------- | ------------------------------------------------------------------------ | ---------------------------------- |
| Frontend framework   | React                                                                    | https://react.dev                  |
| Full-stack framework | TanStack Start                                                           | https://tanstack.com/start/latest  |
| Router               | TanStack React Router                                                    | https://tanstack.com/router/latest |
| Server state         | TanStack React Query                                                     | https://tanstack.com/query/latest  |
| Client state         | Zustand (+ Zundo for undo/redo, Immer for immutable updates)             | https://zustand.docs.pmnd.rs       |
| Type-safe API        | oRPC                                                                     | https://orpc.unnoq.com             |
| Database ORM         | Drizzle ORM (PostgreSQL)                                                 | https://orm.drizzle.team           |
| Authentication       | Better Auth (+ Drizzle adapter, OAuth provider, API keys, 2FA, Passkeys) | https://www.better-auth.com        |
| Styling              | Tailwind CSS                                                             | https://tailwindcss.com            |
| UI Components        | shadcn/ui (built on Base UI)                                             | https://ui.shadcn.com              |
| Icons                | Phosphor Icons                                                           | https://phosphoricons.com          |
| Forms                | React Hook Form (+ Zod resolvers)                                        | https://react-hook-form.com        |
| Rich text editor     | Tiptap                                                                   | https://tiptap.dev                 |
| Validation           | Zod                                                                      | https://zod.dev                    |
| AI                   | Vercel AI SDK (OpenAI, Anthropic, Google, Ollama providers)              | https://ai-sdk.dev                 |
| MCP                  | Model Context Protocol SDK                                               | https://modelcontextprotocol.io    |
| i18n                 | Lingui                                                                   | https://lingui.dev                 |
| Animations           | Motion (Framer Motion)                                                   | https://motion.dev                 |
| PDF export           | Puppeteer Core (via Browserless)                                         | https://pptr.dev                   |
| Drag and drop        | dnd-kit                                                                  | https://dndkit.com                 |
| Server engine        | Nitro                                                                    | https://nitro.build                |
| PWA                  | Vite PWA Plugin                                                          | https://vite-pwa-org.netlify.app   |
| Unused deps          | Knip                                                                     | https://knip.dev                   |

## Project Structure

```
src/
  components/     UI, resume, layout, animation, theme, locale components
  routes/         File-based routing (TanStack React Router)
  integrations/   Feature modules (auth, drizzle, orpc, ai, email, jobs, mcp, storage)
  schema/         Zod schemas for resume data validation
  utils/          Utility functions (locale, theme, env, resume processing)
  dialogs/        Modal/dialog components
  hooks/          Custom React hooks
  styles/         CSS and Tailwind configuration
  integrations/*/store.ts  Zustand stores (ai, jobs); dialog store at src/dialogs/store.ts
migrations/       Drizzle database migrations
locales/          Lingui i18n message catalogs (47+ locales)
```

### Key Config Files

- `vite.config.ts` — Vite + Nitro + TanStack Start + PWA + Tailwind + Lingui
- `drizzle.config.ts` — PostgreSQL dialect, schema at `./src/integrations/drizzle/schema.ts`
- `tsconfig.json` — ES2022, strict mode, path alias `@/*` → `./src/*`
- `lingui.config.ts` — i18n extraction and locale configuration
- `components.json` — shadcn CLI configuration

### API Architecture

- **oRPC API** (`/api/rpc/*`) — Type-safe RPC with routers for: `ai`, `auth`, `resume`, `storage`, `printer`, `jobs`, `statistics`, `flags`. Three procedure types: `publicProcedure`, `protectedProcedure`, `serverOnlyProcedure`. Auth supports session cookies, `x-api-key` header, and `Authorization: Bearer` (OAuth token). `serverOnlyProcedure` rejects browser requests by requiring the `x-server-side-call: true` header.
- **Better Auth API** (`/api/auth/*`) — OAuth, session management, social provider callbacks.
- **MCP Server** (`/mcp/`) — Model Context Protocol with OAuth Bearer tokens and API key auth. Exposes resumes as resources and tools for resume CRUD.

## Infrastructure Services

**This project shares infrastructure with `/root/workspace/env/my-docker-config`.** Use the shared `infra-postgres` container instead of the project-local `compose.dev.yml` postgres.

### Quick start

```bash
# Load infra helpers (if not already in shell)
source /root/workspace/env/my-docker-config/infra/scripts/infra.sh

# 1. Start shared PostgreSQL
infra-up postgres

# 2. Create the database (one-time; ignore "already exists" error)
sudo docker exec infra-postgres psql -U postgres -c "CREATE DATABASE reactive_resume;"

# 3. Start Browserless (PDF export) — attached to the infra network
sudo docker run -d \
  --name reactive-browserless \
  --network infra_infra_net \
  -p 4000:3000 \
  -e TOKEN=1234567890 \
  -e CONCURRENT=10 \
  ghcr.io/browserless/chromium:latest

# Daily restart (after first-time setup above is done)
infra-up postgres && sudo docker start reactive-browserless
```

- **PostgreSQL** (port 5432) — shared `infra-postgres` container; credentials `postgres`/`root123`.
- **Browserless** (host port 4000) — attached to `infra_infra_net`; token `1234567890`.
- Drizzle migrations run automatically on `vp dev` startup via a Nitro plugin.

### compose.dev.yml (alternative)

Only use if the shared infra is unavailable. It creates a project-local postgres that **conflicts with `infra-postgres` on port 5432** — only one can run at a time.

```bash
sudo docker compose -f compose.dev.yml up -d postgres browserless
```

## Environment Variables

Copy `.env.example` to `.env` if not present. Required changes for the shared-infra setup:

```dotenv
APP_URL="http://localhost:3000"
DATABASE_URL="postgresql://postgres:root123@localhost:5432/reactive_resume"
PRINTER_APP_URL="http://172.20.0.1:3000"   # infra_infra_net gateway IP
PRINTER_ENDPOINT="ws://localhost:4000?token=1234567890"
```

- **`PRINTER_APP_URL`** must be the Docker bridge gateway IP (`172.20.0.1` by default), not `localhost` — the Browserless container uses this to reach the app running on the host. Re-query with: `sudo docker network inspect infra_infra_net --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'`
- `STORAGE_*` and `MAIL_*` can be left empty — the app falls back to local filesystem and console-logged emails.

## Common Commands

**Package manager:** `pnpm` is enforced by a `preinstall` hook (`npx only-allow pnpm`). `vp` is a thin wrapper around pnpm for package ops, but `pnpm exec vp <cmd>` also works. Do **not** use npm or yarn.

| Task                       | Command                                    |
| -------------------------- | ------------------------------------------ |
| Install dependencies       | `pnpm install`                             |
| Dev server (port 3000)     | `pnpm exec vp dev`                         |
| Lint (Oxlint, type-aware)  | `pnpm exec vp lint --type-aware`           |
| Lint + fix                 | `pnpm lint:fix`                            |
| Format check               | `pnpm fmt`                                 |
| Format fix                 | `pnpm fmt:fix`                             |
| Check (lint + fmt + types) | `pnpm exec vp check`                       |
| Typecheck                  | `pnpm typecheck` (uses tsgo)               |
| Run all tests              | `pnpm exec vp test`                        |
| Run a single test file     | `pnpm exec vp test src/utils/date.test.ts` |
| Test with coverage         | `pnpm test:coverage`                       |
| DB migrations generate     | `pnpm db:generate`                         |
| DB migrations run          | `pnpm db:migrate` (auto-runs on dev start) |
| DB studio                  | `pnpm db:studio`                           |
| i18n extraction            | `pnpm lingui:extract`                      |
| Add a dependency           | `pnpm add <package>`                       |
| Remove a dependency        | `pnpm remove <package>`                    |
| One-off binary             | `pnpm exec vp dlx <package>`               |
| Build for production       | `pnpm exec vp build`                       |
| Preview production build   | `pnpm exec vp preview`                     |
| Start production server    | `pnpm start`                               |

## Vite+ Pitfalls

- **Do not run `vp vitest` or `vp oxlint`** — they don't exist. Use `vp test` and `vp lint`.
- **Do not install Vitest, Oxlint, Oxfmt, or tsdown directly** — Vite+ bundles them.
- **Import from `vite-plus`**, not from `vite` or `vitest` directly (e.g., `import { defineConfig } from 'vite-plus'`).
- **Vite+ commands take precedence** over `package.json` scripts. If there's a naming conflict, use `vp run <script>`.
- **Type-aware linting** works out of the box with `vp lint --type-aware` — no need to install `oxlint-tsgolint`.

## Gotchas

- The Docker daemon needs `fuse-overlayfs` storage driver and `iptables-legacy` in the cloud VM (nested container environment).
- `pnpm.onlyBuiltDependencies` in `package.json` controls which packages are allowed to run install scripts — no interactive `pnpm approve-builds` needed.
- Email verification is optional in dev — after signup, click "Continue" to skip. Verification emails are printed to the `vp dev` console.
- Vite and Nitro use beta/nightly builds. Occasional upstream issues may occur.
- If port 3000 is occupied: `kill $(lsof -ti:3000)`.

## Syncing with Upstream

The original repository is already configured as the `upstream` remote (`amruthpillai/reactive-resume`).

```bash
# Fetch latest changes from upstream
git fetch upstream

# Preview what's new before merging
git log main..upstream/main --oneline

# Merge upstream into your current branch
git merge upstream/main
# — or rebase (puts your commits on top, cleaner history) —
git rebase upstream/main

# If conflicts get messy, abort cleanly
git merge --abort    # or: git rebase --abort
```

After merging, always run:

```bash
pnpm install          # dependencies may have changed
pnpm exec vp check    # lint + fmt + types
```

## Review Checklist for Agents

- [ ] Run `pnpm install` after pulling remote changes and before getting started.
- [ ] Run `pnpm lint:fix`, `pnpm fmt:fix`, `pnpm typecheck`, and `pnpm exec vp test` to validate changes.
