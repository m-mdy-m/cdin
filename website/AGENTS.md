# AGENTS.md (website)

Docs/marketing site for the cdin editor. Lives inside the cdin repo but is a separate toolchain — see the root `AGENTS.md` for editor guidance.

## Outside website direcotory
- NEVER and EVER change or touch anything outside the website directory.

## Commands (pnpm only)

```sh
pnpm dev            # vite dev server with HMR
pnpm build          # typecheck gate first: tsc -b && vite build
pnpm lint           # eslint .
pnpm exec tsc -b    # typecheck alone (same as the build gate)
```

- Use **pnpm** (`pnpm-lock.yaml`; no package-lock/yarn.lock).
- There is no test suite and no formatter config — verification is `pnpm lint` + `tsc -b`.

## Stack quirks

- Tailwind CSS v4 via `@tailwindcss/vite`: theme is defined in CSS (`src/index.css`), there is no `tailwind.config.js`.
- shadcn/ui with the `radix-nova` style (`components.json`); generated primitives go in `src/components/ui`, icons from `lucide-react`.
- Path alias `@/*` → `src/*` (configured in both `vite.config.ts` and `tsconfig.json`).
- Routes are declared in `src/main.tsx`, not `App.tsx` — `App.tsx` is just the home page component.
- Existing component folders use non-standard names (`BottomBartion/`, `Navigations/`). Follow local naming when adding to them; don't rename casually.
- For UI/design work, a repo-local `frontend-design` skill is available under `.agents/skills/`.
