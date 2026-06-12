---
name: new-stow-package
description: Scaffold a new GNU Stow dotfile package in a confepo-style dotfiles repo and link it. Use for "add a config for X to my dotfiles", "track my <app> config", "new stow package".
---

# new-stow-package

Add an app's config to a GNU-Stow-based dotfiles repo (the confepo layout: each
`stow/<app>/` mirrors `$HOME`, linked with `stow --no-folding`).

1. Confirm the app and where its config lives under `$HOME`
   (e.g. `~/.config/foo/foo.toml`, or `~/.foorc`).
2. Create the package mirroring that path:
   `stow/<app>/<path-relative-to-$HOME>` — e.g.
   `stow/foo/.config/foo/foo.toml`. Move the user's existing config in, or write a
   sensible starter.
3. If the app needs a system package, add its **logical** name to
   `packages/common.txt` (CLI) or `packages/desktop.txt` (GUI), and — only if the
   package name differs by distro — add a mapping in `lib/common.sh → pkg_name`.
4. Link it: `./install.sh --link-only` (or `confepo link`). This pre-creates real
   dirs, backs up any existing real file to `~/.confepo-backup/<ts>/`, then symlinks.
5. Verify: the symlink resolves into the repo (`readlink -f ~/.config/foo/foo.toml`)
   and the app still loads. If the app writes runtime state into its config dir,
   make sure that dir is pre-created in `ensure_dirs` so stow links files, not the
   whole folder.

Then it's covered by `confepo update` (re-link) and `confepo uninstall <app>`
(revert + restore original).
