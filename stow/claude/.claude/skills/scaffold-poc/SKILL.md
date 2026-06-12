---
name: scaffold-poc
description: Spin up a fresh front-end proof-of-concept project (Vite + React + Tailwind, or a single HTML file). Use for "mock up a UI", "quick prototype", or "POC frontend".
---

# scaffold-poc

Stand up a runnable frontend POC quickly.

1. Pick the form factor: **zero-setup** — one self-contained `index.html` (CDN React
   or vanilla JS + Tailwind via CDN) for a throwaway demo; or a **Vite app**
   (`npm create vite@latest <name> -- --template react-ts`) when it will grow.
   (CDN + JSX needs Babel standalone — `<script type="text/babel">` — or write
   `React.createElement`.)
2. For Vite: scaffold, add **Tailwind v4** via the `@tailwindcss/vite` plugin +
   `@import "tailwindcss";` (not the v3 `init -p`/`content` flow), and drop in a
   clean starter layout (header + content area + a couple of components with
   placeholder data) and a short README with `npm install && npm run dev`.
3. Make it look deliberate: consistent spacing, one accent color, responsive,
   labelled inputs. Wire just enough interactivity to show the idea.
4. State clearly what's mocked vs. real, then run `npm run dev` (or open the HTML) to
   confirm it works. For richer UI work, hand off to the `frontend-prototyper` agent.
