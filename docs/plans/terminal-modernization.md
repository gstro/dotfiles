# Terminal Modernization — Design Doc

## Context

Goal: modernize an aging, slow zsh setup (~1.2s startup, full oh-my-zsh, `pure` prompt)
by following the patterns in two source posts plus this repo's
[`zshrc-best-practices.md`](../references/zshrc-best-practices.md), while never
breaking the working terminal until an explicit, reversible cutover.

Three rounds of input shaped this doc:

1. An initial design based on `zshrc-best-practices.md` alone, plus a live Q&A that
   locked in: prompt = starship, tools = zoxide/fzf/eza/fd, framework = antidote,
   cutover = `ZDOTDIR` → repo.
2. Reading the two source posts directly (both were behind a Cloudflare JS challenge
   initially; fetched via browser once the Claude-in-Chrome extension connection was
   re-established). **This changed the plan** — see "What changed" below.
3. Follow-up decisions: **Atuin in**, **fnm in** (resolving the two open questions
   from round 2), plus a new scope addition: **replace Warp with cmux + Herdr** as
   the eventual terminal/agent-management stack. See "Terminal + agent multiplexer
   stack" below.

Sources:
- <https://wicksipedia.com/blog/modern-zsh-setup/> ("My Fast Zsh Setup Without Oh My
  Zsh (But With Its Best Plugins)")
- <https://gordonbeeming.com/blog/2026-03-06/i-let-claude-migrate-my-entire-terminal-setup>
- <https://cmux.com/> — terminal app
- <https://herdr.dev/> — agent multiplexer

## Current state (verified on this machine)

- Intel Mac, Homebrew at `/usr/local`, zsh 5.9, `SHELL=/bin/zsh`.
- oh-my-zsh (46 MB) + `pure` prompt (npm `pure-prompt`). Plugins: `git`, `bgnotify`,
  `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- Startup ~1.2s. Culprits: oh-my-zsh + eager conda/nvm/sdkman/rvm.
- `~/.zshrc` mixes conda, nvm, sdkman, rvm, cargo, poetry, coursier, pnpm, scala-cli,
  a stray duplicate `compinit`, and **3 secrets sourced inline**
  (`~/.openai_key`, `~/.lastfm_key`, `~/.tmdb_key`).
- PATH set as strings, duplicated across `.zshrc`/`.zprofile`/`.zlogin`/`.profile`/
  `.bash_profile`.
- Already installed: `bat`, `rg`. Missing: `starship`, `zoxide`, `fzf`, `eza`, `fd`,
  and now `zinit`, `fnm`, `atuin`.
- `~/local/dotfiles` repo exists but is empty (no commits, no remote).
- Currently using **Warp.app** as the terminal emulator (`/Applications/Warp.app`
  present); no Ghostty/cmux config exists yet (`~/.config/ghostty`, `~/.config/cmux`
  both absent).

## What changed after reading the actual sources

The earlier plan used **antidote** as a generic plugin manager and dropped **nvm**
into a hand-rolled lazy shim. That's a reasonable pattern in the abstract, but it
isn't *the* pattern either source actually describes. The real pattern is more
specific and more valuable, so this doc updates the plan to match it:

| Area | Prior plan | What the sources actually do | Updated plan |
|---|---|---|---|
| Plugin manager | antidote, plain plugin list | **Zinit**, with `zinit snippet OMZL::...` / `OMZP::...` to cherry-pick individual oh-my-zsh library files and plugins, no full framework | **Switch to Zinit** — this is the actual headline pattern ("keep the plugins, lose the framework overhead") |
| Node | nvm kept, lazy-loaded shim | **fnm** (Rust, ~40x faster than nvm), same `.nvmrc` files, `--use-on-cd --version-file-strategy=recursive` | **Replace nvm with fnm** — install matching versions before removing nvm |
| History | native `HISTFILE` + fzf Ctrl-R (originally chosen over Atuin) | **Atuin**, full-text/contextual search, loaded last so it can override Ctrl-R; native history kept as SSH/no-Atuin fallback | **Atuin — confirmed.** Supersedes the earlier fzf-Ctrl-R-only decision. |
| `ls` | manual `eza` aliases | `OMZP::eza` snippet + `zstyle ':omz:plugins:eza' ...` (dirs-first/git-status/header/icons) — no aliasing needed | **Adopt the zstyle pattern** instead of manual aliases |
| Extras | — | `OMZL::directories.zsh` (`..`, `...`, `take`), `OMZL::theme-and-appearance.zsh` (ls colors, terminal title), `OMZP::brew` (completions), `OMZP::direnv` (auto-load `.envrc`, opt-in per directory via `direnv allow`) | **Adopt all four** — small footprint, direct source pattern, low risk |
| Async prompt lib | — | `OMZL::async_prompt.zsh` — needed by OMZ-style prompt themes (p10k, pure) for non-blocking git status | **Skip** — starship has its own async rendering built in; this lib would be dead weight with starship specifically |
| Node | nvm | fnm | **fnm — confirmed.** Full replacement, not a lazy shim. |
| Terminal emulator | out of scope | Gordon also switched iTerm2 → **Ghostty** | **In scope now, but not Ghostty directly** — see "Terminal + agent multiplexer stack" below. |

Both open questions from the previous round are now resolved: **Atuin in, fnm fully
replacing nvm.** The plan below reflects that; no more hedging on either.

## Terminal + agent multiplexer stack: Warp → cmux + Herdr

New scope, added after the zsh-focused rounds above: replace **Warp** with
**cmux** (terminal emulator) + **Herdr** (agent multiplexer), specifically because
Warp's AI-agent session management has been cumbersome. Researched both directly
(cmux.com, herdr.dev) since neither was covered by the two zsh-modernization source
posts.

**cmux** — free, open-source, native macOS (Swift/AppKit, no Electron) terminal
built on `libghostty` (the same rendering engine as Ghostty, but cmux is not a
Ghostty fork). Relevant properties for this migration:
- Reads **Ghostty's own config file** (`~/.config/ghostty/config`) for terminal
  rendering — fonts, theme, colors, cursor, keybindings all carry over from any
  existing Ghostty config. cmux-specific behavior (sidebar, tabs, splits,
  notifications) lives separately in `~/.config/cmux/cmux.json`.
- Vertical tabs showing git branch/cwd/ports per tab; notification rings when a
  pane (e.g. an agent) needs attention; split panes; an embedded, scriptable
  in-app browser; session restore across full restarts.
- Explicitly built for the workflow you're moving away from Warp for: works with
  any terminal-based coding agent (Claude Code, Codex, OpenCode, etc.), turns
  spawned subagents into native panes instead of hidden background processes.
- Install: `brew install --cask cmux` (confirmed available).

**Herdr** — a tmux/Zellij-style **terminal multiplexer**, not a terminal emulator
(explicitly: "not a terminal emulator — Ghostty, Kitty, iTerm, Alacritty: your
terminal stays"). Runs *inside* cmux (or any terminal). What it adds on top of
plain tmux:
- Semantic agent state per pane (blocked / working / done / idle) at a glance.
- Persistent PTY sessions that survive detach — including agent sessions (Claude
  Code, Codex, etc.), not just shells.
- Native remote SSH attach: run Herdr on a remote box, attach locally as a thin
  client (`herdr --remote <host>`), or just SSH in and run `herdr` directly like
  tmux.
- CLI + JSON socket API for scripting workspace/pane creation and reading agent
  output/status — this is what lets an agent orchestrate its own subagents through
  Herdr rather than needing a GUI.
- No account, no telemetry, no Electron. Rust binary.
- Install: `brew install herdr` (confirmed available as a formula, not a cask).

**Why both, given they overlap:** cmux gives you the local GUI experience (vertical
tabs, notification rings, embedded browser) for day-to-day use on this Mac. Herdr
gives you the same "which agent needs me" visibility *and* persistence/remote-attach
that works identically over SSH, with no GUI dependency — e.g. if you're driving an
agent on a remote box from a phone or a different machine. Running Herdr inside
cmux is not redundant: cmux's notification system will still fire (it listens for
the same OSC escape sequences), while Herdr adds the tmux-like persistence and
scriptability layer cmux doesn't provide on its own.

**Scope/sequencing relative to the zsh work:** this is an orthogonal track — it
replaces the *app* you type into and the *session manager* you run inside it,
not your shell config. `.zshrc`/`.zprofile`/`starship.toml` behave identically
whether the terminal is Warp, cmux, or a bare `Terminal.app` window. That means it
can be folded into the same phased rollout without entangling the two: install
alongside the other new tools, configure without touching Warp, verify cmux+Herdr
work with the new zsh setup already built in Phase 3, then cut over both the shell
and the terminal app around the same time (or independently — there's no ordering
dependency either direction).

## Safety-net architecture (unchanged)

All new config is authored in the repo **without touching the live shell**. Because
`ZDOTDIR` can be set per-invocation, the whole setup is testable in an isolated
interactive shell before any cutover:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -il
```

- **Build (Phases 1-4):** live `~/.zshrc`/`~/.zshenv` untouched — every existing
  terminal keeps working.
- **Cutover (Phase 5):** replace the one-line `~/.zshenv` bootstrap.
- **Rollback:** restore `~/.zshenv` from backup — instant, since old files were never
  touched.

The sources don't use this pattern (Gordon uses GNU Stow + direct backup; Wicksipedia
doesn't cover migration mechanics at all) — it's specific to your explicit ask to
"keep my terminal working as expected throughout the process." Keeping it.

### Target repo layout (revised)

```
~/local/dotfiles/
  zsh/
    .zshenv          # tiny: env needed by all zsh
    .zprofile        # login: brew shellenv, PATH array, fnm/rbenv-equivalent env,
                     #   lazy shims for conda/sdkman/rvm
    .zshrc           # interactive: options, history, Zinit + snippets, tool init,
                     #   keybindings, sources ~/.zshrc.local
    conf.d/          # fragments not covered by OMZ snippets: gi(), mkcd, extract,
                     #   gclonecd, glg/glg2 (kept custom — not in OMZ's git plugin)
  starship.toml      # referenced via $STARSHIP_CONFIG
  backup/            # timestamped backups (gitignored)
~/.zshenv            # BOOTSTRAP ONLY after cutover: export ZDOTDIR=".../dotfiles/zsh"
~/.zshrc.local       # secrets, outside the repo, gitignored
```

No `.zsh_plugins.txt` manifest — Zinit's `snippet`/`light` calls live directly in
`.zshrc`, matching the source pattern, and Zinit self-bootstraps via a git clone into
`$ZINIT_HOME` on first run.

## Phase-by-phase plan (revised)

### Phase 0 — Backup
Commit the empty repo as baseline, timestamped copy of all shell files + 3 secret
files + `.zsh_history`, snapshot `brew leaves`/casks/omz-custom, **`nvm ls` output**
(need existing Node versions before installing fnm equivalents), baseline startup
time (x3). **Plus:** note Warp's current settings/keybindings worth preserving
(profile, theme, any custom keybindings) before it's replaced — Warp itself isn't
touched or removed until Phase 5, so this is just a reference snapshot.

### Phase 1 — Install new tools
```
brew install starship zoxide fzf eza fd zinit fnm direnv atuin
brew install --cask cmux
brew install herdr
```
(dropping `antidote`, adding `zinit`, `fnm`, `direnv`, `atuin`, `cmux`, `herdr`). For
each Node version currently in `nvm ls`, run `fnm install <version>` so nothing
regresses. Do not run fzf's, atuin's, or herdr's shell installers where avoidable —
prefer sourcing/config manually so nothing touches the live `~/.zshrc`. cmux and
Warp coexist fine as separate apps during the build/verify phases — no need to
quit Warp yet.

### Phase 2 — Config files
- `starship.toml` — minimal config (dir, git branch/status, cmd duration, on-demand
  language modules), matching the "starship replaces 1700-line p10k with ~2 lines"
  spirit.
- Consolidate the 3 secret files into `~/.zshrc.local` (`chmod 600`); originals stay
  until Phase 5.
- `conf.d/aliases.zsh` — **only** the aliases not already covered by `OMZP::git`:
  `gad`, `glg`, `glg2` (your custom log formats), loaded *after* the Zinit snippets so
  they win on any name collision. `conf.d/functions.zsh` — `gi()`, plus `mkcd`,
  `extract`, `gclonecd` from the reference doc.
- `ghostty/config` (in the repo, symlinked/copied to `~/.config/ghostty/config` at
  cutover) — cmux reads this for fonts/theme/keybindings. Start minimal (font,
  theme, cursor) rather than porting Warp settings 1:1, since Warp and
  Ghostty/cmux don't share a config format.
- `cmux/cmux.json` (→ `~/.config/cmux/cmux.json`) — sidebar/tabs/notification
  behavior.
- Herdr config — location and format TBD from `/docs/configuration/` on herdr.dev;
  check during Phase 2 once installed, since the marketing page didn't surface the
  exact path.

### Phase 3 — The rewrite
`zsh/.zshenv`, `zsh/.zprofile`, `zsh/.zshrc`, in reference-doc order, now built around
Zinit:

```zsh
# Zinit bootstrap
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[ -d "$ZINIT_HOME" ] || git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

# Cherry-picked OMZ libs
zinit snippet OMZL::git.zsh
zinit snippet OMZL::directories.zsh
zinit snippet OMZL::theme-and-appearance.zsh
# (async_prompt.zsh skipped — starship handles this natively)

# eza zstyle config — must precede the plugin
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes

# Cherry-picked OMZ plugins
zinit snippet OMZP::git
zinit snippet OMZP::bgnotify   # preserves your existing plugin
zinit snippet OMZP::brew
zinit snippet OMZP::direnv
zinit snippet OMZP::eza

# Zsh plugins
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

# Completion — fpath additions (incl. scala-cli) before compinit
autoload -Uz compinit; compinit

# fzf-tab loaded after compinit per its own docs (small, deliberate deviation
# from the blog's exact snippet order, for correctness)
zinit light Aloxaf/fzf-tab

# custom aliases/functions — after snippets, so custom formats win
for f in "$ZDOTDIR"/conf.d/*.zsh; source "$f"

# Tool init
eval "$(starship init zsh)"
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
eval "$(zoxide init zsh)"
eval "$(fzf --zsh)"   # or brew-shipped fzf shell scripts

bindkey -e

# Atuin last — overrides Ctrl+R (if adopted; see open question)
eval "$(atuin init zsh)"

[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
```

`.zprofile` still carries: `brew shellenv`, deduped PATH array (cargo, poetry, pnpm,
coursier bin dirs), and guarded lazy shims for **conda**, **sdkman**, **rvm** (kept —
the sources don't use these tools, so no upstream pattern to follow; existing
guard/lazy approach stands). `HISTFILE` stays pinned to `$HOME/.zsh_history` (your
existing 397KB history) rather than the blog's `.zhistory` rename — preserving your
data outranks matching the source's exact filename. History options combine your
target sizing with the source's dedup/verify options: `share_history`,
`hist_expire_dups_first`, `hist_ignore_dups`, `hist_verify`, `extendedhistory`.

### Phase 4 — Verify (before any cutover)
Same isolated `ZDOTDIR=... zsh -il` smoke test as before, plus: `fnm current` matches
prior `nvm` default version, `direnv status` behaves in a directory with a test
`.envrc`, Atuin search returns real history, fzf-tab menus work on `git checkout
<Tab>`, `bgnotify` still fires, tool-parity checklist (conda, sdkman, rvm, cargo,
poetry, pnpm, coursier, scala-cli) untouched, secrets present, startup budget
compared to baseline (target ~120-210ms per both sources).

**cmux + Herdr verify (independent of the shell cutover):** launch cmux alongside
Warp (not replacing it yet), confirm it picks up the new zsh config correctly
(prompt, plugins, aliases all behave identically to Warp since it's the same
`ZDOTDIR`-driven shell), confirm notification rings fire for a long-running command,
launch Herdr inside a cmux pane and confirm `blocked/working/done` state tracking
and `herdr --remote` against a test host if you have one available.

### Phase 5 — Cutover + Cleanup
Same one-line `~/.zshenv` bootstrap swap, confidence window, then remove oh-my-zsh
(46 MB), `pure-prompt`, **nvm** (after fnm parity confirmed), the 3 original key
files, and — per Gordon's post finding stray unused config during migration — a
quick pass to check for any other now-orphaned tool installs (worth eyeballing `brew
leaves` from Phase 0 against what's actually referenced in the new config).

**Terminal cutover (independent timing):** once cmux + Herdr have been used
side-by-side with Warp long enough to trust them, make cmux the default terminal and
quit relying on Warp day-to-day. Remove Warp (`brew uninstall --cask warp` /
drag to Trash) only after that confidence window — same reversibility principle as
the shell cutover: nothing about cmux/Herdr requires uninstalling Warp first, so
there's no reason to rush it.

## Status

All three open items from the previous round are now resolved (Atuin in, fnm in,
cmux+Herdr added).

- **Phase 0 (backup): done**, merged to `main`. Timestamped backup at
  `backup/20260713-154441/` (local, gitignored). `.gitignore` fixed (stray `n`
  removed; `backup/`, `.zshrc.local`, `*.local` added).
- **Phase 1 (install tools): done**, on branch `phase-1-install-tools`, awaiting
  merge. Installed via Homebrew: `starship` 1.26.0, `zoxide` 0.10.0, `fzf` 0.74.0,
  `eza` 0.23.5, `fd` 10.4.2, `zinit` 3.15.0, `fnm` 1.39.0, `direnv` 2.37.1, `atuin`
  18.17.0, `cmux` 0.64.17 (cask), `herdr` 0.7.3. All verified to resolve on PATH.
  fnm has all 5 of your prior nvm Node versions installed (12.18.1, 16.14.2,
  18.12.1, 20.17.0, 22.15.0), default set to 22.15.0 to match nvm's prior default.
  Warp untouched, still the active terminal.

  **One deviation worth carrying into Phase 3:** brew's `zinit` formula ships
  `zinit.zsh` directly at `/usr/local/opt/zinit/zinit.zsh` (caveat: "add `source
  /usr/local/opt/zinit/zinit.zsh` to your `~/.zshrc`"). Use that instead of the
  self-bootstrapping git-clone-into-`$ZINIT_HOME` snippet shown in the "Phase 3"
  section below — it's simpler and stays updated via `brew upgrade` rather than a
  separate self-update mechanism. `.zshrc` should do:
  ```zsh
  source /usr/local/opt/zinit/zinit.zsh
  ```
  instead of the `ZINIT_HOME`/git-clone block.

  Also noted: both `atuin` and `herdr` ship an optional background-service caveat
  (`brew services start atuin` / `brew services start herdr`, or run the daemon
  manually). Neither service was started during Phase 1 — that's a Phase 2/3
  config decision, not an install-time one.

- **Phase 2 (config files): done**, on branch `phase-2-config-files`, awaiting
  merge. Created:
  - `starship.toml` (repo root) — minimal: directory, git branch/status, cmd
    duration, a plain `>`/`>` character prompt.
  - `zsh/conf.d/aliases.zsh` — only `gad`/`glg`/`glg2` (not covered by
    `OMZP::git`).
  - `zsh/conf.d/functions.zsh` — `mkcd`, `extract`, `gclonecd` ported verbatim
    from the reference doc, plus `gi()`. **Fixed a bug while porting `gi()`**:
    the original had `curl -sLw n ...` (a mangled `-w "\n"` flag, printing a
    literal `n`); rewritten as a plain `curl -sL "...api/$*"`.
  - `~/.zshrc.local` (outside the repo, `chmod 600`) — consolidates the 3
    secret exports (`OPENAI_API_KEY`, `LASTFM_API_KEY`, `TMDB_API_KEY`).
    Originals at `~/.openai_key`/`~/.lastfm_key`/`~/.tmdb_key` untouched until
    Phase 5.
  - `ghostty/config` (repo root, → `~/.config/ghostty/config` at cutover) —
    font, theme, scrollback, clipboard. Chose `JetBrainsMono Nerd Font` (see
    deviation note below) at size 18 to match Warp's existing `FontSize` of
    18, theme `One Dark` (used verbatim from cmux's own docs example, so the
    theme name is confirmed valid).
  - `cmux/cmux.json` (repo root, → `~/.config/cmux/cmux.json`) — kept close to
    cmux's own generated template (mostly commented-out), per its
    "start minimal" guidance. Schema confirmed at
    `cmux.com/docs/configuration`.
  - `herdr/config.toml` (repo root, → `~/.config/herdr/config.toml`) — theme
    `one-dark` (paired with the Ghostty theme), `[ui.toast] delivery =
    "terminal"` so Herdr's attention notifications route through the same
    OSC-escape-sequence path cmux already listens on. Config path/schema
    confirmed at `herdr.dev/docs/configuration/`.

  **One addition beyond the original Phase 2 list:** installed
  `font-jetbrains-mono-nerd-font` via `brew install --cask`. Neither `eza`'s
  icon mode nor Ghostty/cmux rendering has nerd-font glyphs without one, and
  no Nerd Font was present on this machine (`fc-list`/`~/Library/Fonts` both
  came up empty). Chosen as a widely-used, safe default — swap it in
  `ghostty/config` if you'd prefer a different one.

- **Phase 3 (rewrite): done**, on branch `phase-3-rewrite`, awaiting merge.
  Wrote `zsh/.zshenv` (intentionally near-empty), `zsh/.zprofile` (brew
  shellenv, consolidated PATH array, lazy shims for conda/sdkman/rvm), and
  `zsh/.zshrc` (history, completion, zinit + OMZ snippets, custom `conf.d/`,
  starship, fnm/zoxide/fzf, atuin last, `~/.zshrc.local` last).

  **Deviations/fixes made while implementing** (the doc's Phase 3 code block
  had a few issues that only surface when you actually run it):
  - Used `source /usr/local/opt/zinit/zinit.zsh` (per the Phase 1 finding)
    instead of the git-clone bootstrap.
  - `for f in "$ZDOTDIR"/conf.d/*.zsh; source "$f"` in the original doc is
    invalid zsh syntax (missing `do`/`done`); fixed to a proper loop with a
    `(N)` glob qualifier so it doesn't error if `conf.d/` is ever empty.
  - `eval "$(fzf --zsh)"` (this fzf version supports it) instead of sourcing
    the two separate `key-bindings.zsh`/`completion.zsh` files — simpler,
    one command.
  - `STARSHIP_CONFIG` computed as `"${ZDOTDIR:h}/starship.toml"` since
    `starship.toml` lives at the repo root, one level up from `$ZDOTDIR`.
  - Lazy shims for conda/sdkman/rvm fully written out (the doc only sketched
    the idea) — each is a self-replacing stub function so the real init
    only runs on first actual use.

  **Verified via isolated `ZDOTDIR=... zsh -i` (through a real pty — a
  plain `-c` command string produces a spurious `can't change option: zle`
  warning that isn't a config bug, just a non-tty testing artifact; it
  vanishes under a real pty):**
  - `HISTFILE` correctly `/Users/molo/.zsh_history` (existing history
    preserved).
  - `gad`/`glg`/`glg2` present from `conf.d/`; `gst`/`gco` etc. present from
    `OMZP::git`.
  - `mkcd`/`extract`/`gclonecd`/`gi` all loaded from `conf.d/functions.zsh`.
  - All 3 secrets present via `~/.zshrc.local`.
  - `fnm current` → `v22.15.0`, matching nvm's prior default.
  - `zoxide`'s `z` function loaded; `eza` zstyle plugin working (`ls` →
    `eza -gh --group-directories-first --git --icons=auto`).
  - `bgnotify`'s real hooks (`bgnotify_begin`/`bgnotify_end`) registered in
    `preexec`/`precmd`, alongside `direnv`, autosuggestions,
    syntax-highlighting, starship, and atuin — all present and in sensible
    order.
  - `starship prompt` renders correctly (confirmed directly with
    `STARSHIP_CONFIG` set; `starship explain` also confirms the config
    parses).
  - Informal startup timing (3 runs): **~0.4s**, down from the ~1.2s
    baseline, but not yet at the ~120-210ms both sources report. Worth
    profiling properly (`zmodload zsh/zprof`) in Phase 4 rather than
    guessing here — candidates are `compinit -C` behavior on a stale/first
    dump, the `direnv`/`eza` git-status hooks, and zinit's own overhead, but
    this needs actual measurement, not speculation.

  Live shell (Warp + oh-my-zsh) still completely untouched.

- **Phase 4 (verify): not started.**
- **Phase 5 (cutover + cleanup): not started.**
