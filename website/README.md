# cdin website

Marketing and docs site for [cdin](https://github.com/m-mdy-m/cdin), a small fast text editor written in C + Lua.

Built with React + TypeScript + Vite. Runs as a separate toolchain inside the cdin repo.

## Tech stack

- Vite 8 + React 19 + TypeScript
- Tailwind CSS v4 (theme defined in `src/index.css`, no `tailwind.config.js`)
- shadcn/ui (`radix-nova` style) + radix-ui + lucide-react icons
- react-router, react-markdown + remark-gfm

## Getting started

Uses **pnpm** (no npm/yarn).

```sh
pnpm install
pnpm dev        # dev server with HMR
pnpm build      # typecheck gate: tsc -b && vite build
pnpm lint       # eslint .
pnpm preview
```

## Project structure

- `src/main.tsx` — entry point and all route definitions (routes live here, not `App.tsx`)
- `src/pages/` — About, Download, Docs, and the two layouts
- `src/components/` — UI sections (Landing, DocsComp, Download, Navigations, BottomBartion) + shadcn `ui/` primitives
- `src/consts/` — static nav/footer/FAQ data
- `src/lib/` — `docs.ts` (doc loader) and `utils.ts`

## Docs

Docs render from `../../docs/**/*.md` in the editor repo via a Vite raw glob import in `src/lib/docs.ts`. Slug, category, and title are derived from the file path and first heading, so adding a doc to the editor's `docs/` makes it appear on the site automatically.

## Deployment

Deployed to GitHub Pages at <https://m-mdy-m.github.io/cdin/>. `vite.config.ts` sets `base` to `/cdin/` under GitHub Actions and `/` otherwise.
