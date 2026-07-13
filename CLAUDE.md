# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Greg's personal dotfiles repo (currently zsh/terminal-focused only). As of now the
repo contains **no shell configs yet** — it's in the planning stage of a migration
away from an oh-my-zsh + `pure` prompt setup living in `$HOME`. There is no
build/lint/test tooling because there is no code here yet, only shell configuration
(present and future) and two docs that govern how that configuration should be
written and rolled out.

## Read these first

- `docs/references/zshrc-best-practices.md` — the style guide for any zsh config
  authored in this repo: file responsibilities (`.zshenv` vs `.zprofile` vs `.zshrc`),
  startup-order rules, PATH-as-array conventions, guarding optional tools with
  `command -v`, and the target of keeping interactive shell startup under
  ~100-200ms. Treat this as the authoritative style reference for any zsh file added
  here — don't reinvent these conventions ad hoc.
- `docs/plans/terminal-modernization.md` — the live, phased plan for the actual
  migration (oh-my-zsh/pure/nvm/Warp → zinit/starship/fnm/atuin/cmux+herdr). This is
  the source of truth for what's been decided, what's still open, and which phase
  has (not) been executed. **Check its "Status" section before doing any shell-config
  work** — it tracks what's real vs. still just planned.

## Planned architecture (not yet built)

The migration plan uses a `ZDOTDIR`-based safety-net pattern: new config is authored
under `zsh/` in this repo (`.zshenv`, `.zprofile`, `.zshrc`, `conf.d/*.zsh`,
`starship.toml`) without ever touching the live `~/.zshrc`/`~/.zshenv` until an
explicit, one-line cutover (`export ZDOTDIR=.../zsh` in `~/.zshenv`). This means:

- Any new zsh config work should go under a `zsh/` subdirectory here, not assume it
  lands directly in `$HOME`.
- Secrets are kept **outside** the repo entirely, in `~/.zshrc.local` (gitignored,
  sourced last from `.zshrc`) — never commit API keys or tokens into `zsh/`.
- The repo is also expected to eventually hold `ghostty/config` and `cmux/cmux.json`
  (for the cmux terminal app) once that track of the plan is executed — these mirror
  `~/.config/ghostty/config` and `~/.config/cmux/cmux.json`.

## Verifying shell config changes

Since there's no test suite, the way to validate zsh config changes once `zsh/`
exists is to run an isolated shell against it without affecting the current session:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -il
```

Startup performance is checked with:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" /usr/bin/time zsh -i -c exit
```

Both are used repeatedly throughout `docs/plans/terminal-modernization.md`'s Phase 4
verification steps — reuse the same pattern rather than testing against the live
`~/.zshrc`.

## .gitignore

Currently the toptal-generated macOS + VS Code template. It has a known stray
trailing `n` on the last line (Phase 0 of the migration plan calls out fixing it)
and still needs `backup/`, `.zshrc.local`, and `*.local` added before any backups or
local secrets files are created in/near this repo.
