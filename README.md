# dotfiles

Personal dotfiles: live zsh config plus the terminal/multiplexer stack (Ghostty
rendering config, cmux, Herdr) that replaced an oh-my-zsh + `pure` + Warp setup.

## Status

**Migration complete and cut over.** `~/.zshenv` points `ZDOTDIR` at this repo's
`zsh/` directory, so every real shell runs the config checked in here. cmux (built
on Ghostty's renderer) is the daily-driver terminal; Warp has been removed. Startup
time went from ~1.2s to ~0.3s. See
[`docs/plans/terminal-modernization.md`](docs/plans/terminal-modernization.md) for
the full phase-by-phase history and current status, and
[`docs/references/new-tools-guide.md`](docs/references/new-tools-guide.md) for what
each tool does and how it's configured. Config conventions for any zsh file here
follow [`docs/references/zshrc-best-practices.md`](docs/references/zshrc-best-practices.md).

A short list of intentionally-deferred cleanup remains (documented in the plan doc's
Status section) — none of it blocks day-to-day use.

## Setting up a new machine

See [`docs/references/new-machine-setup.md`](docs/references/new-machine-setup.md)
for step-by-step instructions to bootstrap this stack on a machine that doesn't have
any of it yet (fresh Mac, reformat, etc.) — a shorter, more direct path than the
migration plan doc, which is written for migrating an *existing* customized setup.

## Layout

```
zsh/
  .zshenv, .zprofile, .zshrc   # ZDOTDIR-rooted shell config
  conf.d/                      # aliases.zsh, functions.zsh — fragments not covered
                                #   by zinit's oh-my-zsh snippets
starship.toml                  # prompt config, referenced via $STARSHIP_CONFIG
ghostty/config                 # terminal rendering (font/theme/scrollback) — cmux
                                #   reads this directly, symlinked to
                                #   ~/.config/ghostty/config
cmux/cmux.json                 # cmux-specific settings, symlinked to
                                #   ~/.config/cmux/cmux.json
herdr/config.toml              # agent-multiplexer config, symlinked to
                                #   ~/.config/herdr/config.toml
docs/
  references/   style/tool reference docs (not migration-specific)
  plans/        migration plan and its status
```

Secrets live outside the repo in `~/.zshrc.local` (gitignored, sourced last from
`zsh/.zshrc`) — never commit API keys here.

`ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -il` runs an isolated shell against this
config without affecting a live session — see the plan doc for the full
verification workflow.
