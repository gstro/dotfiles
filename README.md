# dotfiles

Personal dotfiles, currently focused on modernizing my terminal/zsh setup.

## Status

Pre-implementation. This repo doesn't hold any live shell configs yet — right now
it's just the planning docs for a migration off an oh-my-zsh + `pure` prompt setup
(and off Warp as a terminal) toward a faster, more modular stack. See
[`docs/plans/terminal-modernization.md`](docs/plans/terminal-modernization.md) for
the current plan and status, and
[`docs/references/zshrc-best-practices.md`](docs/references/zshrc-best-practices.md)
for the conventions any zsh config here should follow.

## Layout

```
docs/
  references/   style/convention references (not migration-specific)
  plans/        active migration plans and their status
```

Once the migration starts, shell config will live under `zsh/` using a `ZDOTDIR`
based layout so it can be tested in isolation before being adopted as the live
`~/.zshrc`/`~/.zshenv` — see the plan doc for details.
