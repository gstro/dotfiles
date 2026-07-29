# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Greg's personal dotfiles repo (zsh/terminal-focused). It holds the **live** zsh
config (`zsh/.zshenv`, `.zprofile`, `.zshrc`, `conf.d/*.zsh`) plus the terminal
stack that replaced Warp + oh-my-zsh + `pure`: `starship.toml`, `ghostty/config`,
`cmux/cmux.json`, `herdr/config.toml`. `~/.zshenv` on this machine is a one-line
bootstrap (`export ZDOTDIR="$HOME/local/dotfiles/zsh"`), so every real shell runs
the config checked in here — this is not a staging/planning repo, changes here take
effect the next time a shell starts. There is no build/lint/test tooling; validation
means running an isolated shell against the config (see below).

The migration that built all this is **done and cut over** (oh-my-zsh, `pure`,
`nvm`, and Warp have all been removed from the machine). The plan doc below is kept
as the historical record and tracks a short list of intentionally-deferred cleanup
— check its Status section before assuming something listed as "held back" has been
resolved.

## Read these first

- `docs/references/zshrc-best-practices.md` — the style guide for any zsh config
  authored in this repo: file responsibilities (`.zshenv` vs `.zprofile` vs `.zshrc`),
  startup-order rules, PATH-as-array conventions, guarding optional tools with
  `command -v`, and the target of keeping interactive shell startup under
  ~100-200ms. Treat this as the authoritative style reference for any zsh file added
  here — don't reinvent these conventions ad hoc.
- `docs/plans/terminal-modernization.md` — the phased migration record
  (oh-my-zsh/pure/nvm/Warp → zinit/starship/fnm/atuin/cmux+herdr) and its Status
  section, the source of truth for what's actually live on the machine vs. what's
  still an open follow-up.
- `docs/references/new-tools-guide.md` — per-tool reference for everything the
  migration introduced: what it replaced, current config, and recommended settings.
  Check this before changing any tool's config (starship, zinit, fnm, zoxide, fzf,
  eza, atuin, cmux, Herdr) — it explains *why* the current settings were chosen.
- `docs/references/new-machine-setup.md` — step-by-step bootstrap instructions for
  putting this stack on a machine that doesn't have any of it yet (as opposed to
  `terminal-modernization.md`, which documents *migrating* an existing customized
  setup). If a change here affects setup on a fresh machine — a new hardcoded path,
  a new required `brew install`, a new symlink — update this doc too.

## Architecture

A `ZDOTDIR`-based safety-net pattern: all zsh config lives under `zsh/` in this repo
(`.zshenv`, `.zprofile`, `.zshrc`, `conf.d/*.zsh`), and `~/.zshenv` is the only file
outside the repo that matters — it just sets `ZDOTDIR`. This means:

- Any new zsh config work goes under `zsh/` here, not `$HOME` directly.
- Secrets are kept **outside** the repo entirely, in `~/.zshrc.local` (gitignored,
  sourced last from `.zshrc`) — never commit API keys or tokens into `zsh/`.
- `ghostty/config` and `cmux/cmux.json` are symlinked live to
  `~/.config/ghostty/config` and `~/.config/cmux/cmux.json`; `herdr/config.toml` to
  `~/.config/herdr/config.toml`. Same rule applies: edit the repo copy, not the
  `~/.config` one — the symlink is what makes the repo copy authoritative.

## Verifying shell config changes

There's no test suite — validate zsh config changes by running an isolated shell
against this repo's config without affecting the current session:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -il
```

Startup performance is checked with:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" /usr/bin/time zsh -i -c exit
```

Note `-ic`/non-login testing silently skips `.zprofile` (Phase 3 of the migration
made exactly this mistake and caught it in Phase 4) — for anything that touches
`.zprofile` (PATH array, conda/sdkman/rvm lazy shims), test a real login+interactive
shell instead:

```zsh
env -i HOME="$HOME" TERM="$TERM" ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -ilc '<command>'
```

## .gitignore

toptal-generated macOS + VS Code template, since fixed (the stray trailing `n` from
Phase 0 is gone) and extended with `backup/`, `.zshrc.local`, `*.local`, and
`zsh/.zcompdump*` (compinit's runtime cache) — no outstanding gaps.
