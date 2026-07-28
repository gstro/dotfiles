# New Tools Guide

Every tool introduced by the terminal modernization (see
`docs/plans/terminal-modernization.md` for the migration itself). For each: what it
replaced, how it's configured *right now* in this repo, the recommended settings, and
why. Ordered roughly by how often you'll touch its config.

---

## Starship (prompt)

**Replaces:** `pure` (npm prompt).
**Config:** `starship.toml`, referenced via `export STARSHIP_CONFIG=".../starship.toml"`
in `zsh/.zshrc` — deliberately *not* symlinked to `~/.config/starship.toml`, so the repo
file is the only copy that matters.

Current config is intentionally minimal — directory, git branch, git status, command
duration (only shown past 2s), and a two-color prompt character:

```toml
format = """$directory$git_branch$git_status$cmd_duration$character"""

[directory]
truncation_length = 3
truncate_to_repo = true
```

**Recommended settings / why:**
- `truncate_to_repo = true` — once you're inside a git repo, the path collapses to
  repo-relative, which is the single biggest prompt-length win for deeply nested repos.
- `cmd_duration.min_time = 2000` — hides duration noise for anything fast; only surfaces
  commands worth knowing took a while.
- Consider adding a `[nodejs]`/`[package]` module *only* if you find yourself running
  `node -v` out of habit — each extra module is a per-prompt subprocess-ish check, so
  the sources' own advice (and the reason this file stayed this small) is to add modules
  on-demand rather than enabling the defaults, which show language versions in every
  directory whether relevant or not.
- Full module list / options: `starship.toml` reference at starship.rs — worth a look
  once you've lived with the prompt a few days and know what you actually want to see.

---

## Zinit (plugin manager)

**Replaces:** oh-my-zsh (full framework, 46MB, eager-loaded).
**Config:** top of `zsh/.zshrc` — `source /usr/local/opt/zinit/zinit.zsh`, then a mix of
`zinit snippet OMZL::*`/`OMZP::*` (cherry-picked individual oh-my-zsh files, without
loading the framework) and `zinit light user/repo` (plain non-OMZ plugins).

Currently loaded:
- `OMZL::git.zsh`, `OMZL::directories.zsh`, `OMZL::theme-and-appearance.zsh` — oh-my-zsh
  *library* files (helper functions), not plugins.
- `OMZP::bgnotify`, `OMZP::brew`, `OMZP::direnv`, `OMZP::eza` — individual plugins.
- `zsh-users/zsh-autosuggestions`, `zsh-users/zsh-syntax-highlighting`,
  `Aloxaf/fzf-tab` — non-OMZ plugins.

**Recommended settings / why:**
- Snippet/cherry-pick only what you use, rather than `zinit snippet OMZ::` the whole
  framework — this is *the* mechanism that got startup down from oh-my-zsh's baseline.
  `OMZP::git` was deliberately dropped (see plan doc's Phase 4 writeup) once we
  confirmed our own git aliases in `conf.d/aliases.zsh` already covered everything it
  provided — it was the single biggest remaining cost in the `zprof` output.
- If you add a new oh-my-zsh plugin later, prefer the snippet form over adding another
  full framework dependency, and profile before/after with:
  ```zsh
  # temporarily, top and bottom of .zshrc:
  zmodload zsh/zprof   # top
  zprof                # bottom
  ```
- `zinit light` plugins load turbo-eagerly by default; true async turbo-mode
  (`wait'0' lucid`) was attempted for the `OMZP::*` snippets but reverted — it couldn't
  be reliably verified in a non-interactive test harness. It's a legitimate follow-up if
  you want to shave more startup time, but verify it yourself in a real interactive
  shell (confirm `gst` etc. work *immediately* in a fresh tab, not just after idling)
  before trusting it.

---

## fzf-tab

**New** (didn't exist before).
**Config:** `zinit light Aloxaf/fzf-tab`, loaded in `zsh/.zshrc` *after* `compinit`.

**Recommended settings / why:**
- The load-order (after `compinit`) is a deliberate deviation from the exact snippet
  order in the original source blog post — fzf-tab's own docs require it, and loading
  it earlier silently breaks the fuzzy tab-completion menu without any error.
- Default behavior (fuzzy-narrow completion menus with fzf's UI) is good as-is; the
  main tunable if you want it later is `zstyle ':fzf-tab:*' fzf-flags` to pass extra
  fzf options (e.g. a different `--height`), but there's no need to touch this unless
  something about the menu bothers you in practice.

---

## zsh-autosuggestions / zsh-syntax-highlighting

**Replaces:** the same-named oh-my-zsh custom plugins (functionally identical, now
loaded via zinit instead of `~/.oh-my-zsh/custom/plugins`).
**Config:** `zinit light zsh-users/zsh-autosuggestions` /
`zinit light zsh-users/zsh-syntax-highlighting` in `zsh/.zshrc`, no options set.

**Recommended settings / why:**
- Defaults are fine. The one setting worth knowing about if suggestions ever feel
  slow on a very long history: `ZSH_AUTOSUGGEST_STRATEGY=(history completion)` (default)
  vs. just `(history)` — history-only is faster on huge `HISTFILE`s but less complete.
  Not changed here since startup/typing both felt fine in Phase 4 testing.
- Order matters: syntax-highlighting should load *after* anything else that wraps
  `zle` widgets (it's last of the two here, which is correct) — if you ever add another
  zle-wrapping plugin, put it before syntax-highlighting.

---

## fnm (Node version manager)

**Replaces:** nvm (eagerly-sourced, ~genuinely slow part of the old startup).
**Config:** one line in `zsh/.zshrc`:
```zsh
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
```

**Recommended settings / why:**
- `--use-on-cd` — auto-switches Node version on `cd` into a directory with a
  `.nvmrc`/`.node-version`, matching nvm muscle memory (via a hooked `chpwd`, not a
  slow eager shim like nvm's).
- `--version-file-strategy=recursive` — walks up parent directories to find a version
  file, not just the exact cwd. Matters for monorepos where the version file lives at
  the repo root, not in the subdirectory you're actually working in.
- **Still pending your confirmation**: this only fully replaces nvm once you've
  actually exercised your old pinned versions (five were in use pre-migration:
  v12.18.1/v16.14.2/v18.12.1/v20.17.0/v22.15.0 — see `backup/*/nvm-versions.txt`).
  `fnm install <version>` per project the first time you `cd` in and it's missing.
  Don't `brew uninstall nvm` until you've confirmed real parity across the projects
  you actually use.

---

## zoxide (smarter `cd`)

**New** (didn't exist before).
**Config:** `eval "$(zoxide init zsh)"` in `zsh/.zshrc`, defaults only.

**Recommended settings / why:**
- Defaults mean `z <partial-name>` jumps to your highest-ranked matching directory by
  frecency (frequency + recency) — no config needed to get value from it, it just
  needs a few days of normal `cd` usage to build up ranking data.
- If you want it to fully replace `cd` (not just add `z`), zoxide supports
  `alias cd='z'`, but that's a habit change, not a default — worth trying only once
  `z` alone feels natural.

---

## fzf (fuzzy finder)

**New as a shell-level tool** (installed via brew, not manually built).
**Config:** `eval "$(fzf --zsh)"` in `zsh/.zshrc` — uses the brew-shipped
keybindings/completion scripts directly, deliberately *not* via `fzf`'s own
`install` script (which edits `~/.zshrc` directly and would have fought the whole
`ZDOTDIR` safety-net approach).

**Recommended settings / why:**
- Default keybindings: `Ctrl-T` (paste file path), `Ctrl-R` (history search — later
  overridden by atuin, see below), `Alt-C` (cd into fuzzy-picked directory).
- `Ctrl-R` is intentionally superseded by atuin (`.zshrc` loads atuin *last*
  specifically to win that rebind) — if you ever want fzf's own history search back
  instead, that's a one-line reorder, not a config option.
- No `FZF_DEFAULT_OPTS` set currently (e.g. a preview pane, height, layout). Worth
  adding once you know which fzf-invoking workflow (history vs. file search vs.
  fzf-tab) you use most and want to tune for.

---

## eza (`ls` replacement)

**Replaces:** manual `ls`/`ll`/`la` aliases.
**Config:** *not* manual aliases — configured the oh-my-zsh way, via zstyle before the
plugin loads (`zsh/.zshrc`):
```zsh
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes
zinit snippet OMZP::eza
```

**Recommended settings / why:**
- `dirs-first` — directories sort before files, matches most people's mental model
  better than alphabetical-only.
- `git-status` — inline git status per file/dir in listings; genuinely useful inside
  a repo, negligible cost outside one.
- `header` / `icons` — cosmetic; drop either if the Nerd Font icons don't render
  correctly in a given terminal (should be fine in Warp/cmux given the JetBrainsMono
  Nerd Font in `ghostty/config`).
- The zstyle block **must precede** `zinit snippet OMZP::eza` — the plugin reads these
  at load time, not lazily.

---

## Atuin (shell history)

**New** (didn't exist before; earlier plan draft had explicitly said "no atuin," later
reversed once the source blogs showed it as core).
**Config:** `eval "$(atuin init zsh)"`, loaded **last** in `zsh/.zshrc`, after fzf.

**Recommended settings / why:**
- Load order is the single important setting: atuin must init after fzf so it wins the
  `Ctrl-R` rebind. If you ever reorder `.zshrc`, keep this pinned last.
- Local-only by default — no account/sync configured. Atuin supports end-to-end
  encrypted history sync across machines (`atuin register`/`atuin login` +
  `atuin sync`), which is worth considering if you use more than one machine, but it's
  an explicit opt-in step, not something silently enabled.
- Config file (not yet created — atuin works fine on defaults) would live at
  `~/.config/atuin/config.toml`. Two settings worth knowing about if search ever feels
  off: `search_mode = "fuzzy"` (default is `"prefix"`) and `filter_mode = "host"` if you
  want per-machine history separated once you're on multiple machines.

---

## cmux (terminal emulator) — not yet cut over

**Replaces:** Warp (planned, not yet executed — you're still on Warp as of this
writing; confirmed via the earlier mouse-capture question that Warp is swallowing
Herdr's mouse events, expected to resolve once you switch).
**Config:** `cmux/cmux.json` (cmux-specific settings — notifications, automation) +
`ghostty/config` (rendering: font, theme, scrollback — cmux reads Ghostty's config
directly since it's built on `libghostty`). Neither is symlinked into `~/.config/` yet.

Current `ghostty/config`:
```
font-family = JetBrainsMono Nerd Font
font-size = 18
theme = One Dark
scrollback-limit = 50000000
copy-on-select = false
```

**Recommended settings / why:**
- `copy-on-select = false` — deliberate: with a mouse-native pane multiplexer (Herdr)
  in front of it, auto-copy-on-select is more likely to fight Herdr's own click/drag
  handling than help.
- `cmux/cmux.json` is currently left close to cmux's own defaults on purpose — commented
  out `notifications`/`automation` blocks are there as a starting point, not yet
  enabled. Worth revisiting after a few real days on cmux, once you know whether
  Herdr's own toast (see below) is enough or you want cmux-level notification/automation
  behavior too.
- **Known wrinkle before symlinking**: cmux auto-generates its own default
  `~/.config/cmux/cmux.json` on first launch. Back that up or diff it against the
  repo's version before symlinking the repo's file in — don't just overwrite blind.

---

## Herdr (agent-aware multiplexer) — not yet cut over

**New** (replaces nothing directly — new capability; doesn't require cmux, works in
Warp today, just with the mouse limitation noted above).
**Config:** `herdr/config.toml`, not yet symlinked to `~/.config/herdr/config.toml`
(currently running on Herdr's built-in defaults — no config.toml exists live yet).

Current repo config:
```toml
[theme]
name = "one-dark"

[ui.toast]
delivery = "terminal"
```

**Recommended settings / why:**
- `theme = "one-dark"` — matches the Ghostty/cmux theme for visual consistency across
  the whole stack.
- `[ui.toast] delivery = "terminal"` — routes Herdr's "agent needs your attention"
  signal through the outer terminal's own notification escape-sequence path, so it
  shows up as one native desktop notification instead of Herdr and cmux each having
  their own separate notification system.
- `ui.mouse_capture` (not currently set, defaults to `true`) — leave this alone; this
  is the setting that governs whether Herdr or the terminal handles raw clicks. Only
  set it to `false` if you specifically want the terminal to handle plain clicks (e.g.
  Cmd-click opening URLs the terminal's own way) at the cost of losing Herdr's own
  click-to-focus pane/tab/workspace behavior.
- Default keybinding prefix is `Ctrl-b` (tmux-style) — not overridden here; only worth
  changing if it collides with something else you use constantly.

---

## Not yet reconfigured

- **conda / sdkman / rvm** — kept as lazy-loading shims in `zsh/.zprofile` (self-replace
  on first real invocation), not "new tools" so much as existing tools whose *loading
  strategy* changed. No new config surface, just deferred cost.
- **`.zshrc.local`** (secrets) — plain `export KEY=value` lines, intentionally as
  boring as possible; this file has no "configuration" beyond staying out of the repo
  and `chmod 600`.
