# New Machine Setup Guide

Step-by-step instructions for bootstrapping **this dotfiles repo's terminal stack
on a machine that doesn't have any of it yet** — a fresh Mac, a reformat, or a
machine that never had the old oh-my-zsh/`pure`/Warp setup in the first place.

This is not the same document as
[`docs/plans/terminal-modernization.md`](../plans/terminal-modernization.md) — that
one is the historical record of *migrating an existing, customized* oh-my-zsh
machine over to this stack, with backup/rollback steps for state that no longer
exists on a new machine. If you're moving this exact setup onto a brand-new Mac,
this guide is the one to follow; skip the backup/rollback ceremony, there's nothing
to preserve.

Total time: ~20-30 minutes, most of it Homebrew installing casks.

## What you end up with

zsh config driven by [Zinit](https://github.com/zdharma-continuum/zinit)
(cherry-picked oh-my-zsh plugins, no full framework), a
[Starship](https://starship.rs) prompt, [fnm](https://github.com/Schniz/fnm) for
Node, [Atuin](https://atuin.sh) for history search, [zoxide](https://github.com/ajeetdsouza/zoxide)/[fzf](https://github.com/junegunn/fzf)/[eza](https://github.com/eza-community/eza),
and [cmux](https://cmux.com) (terminal) + [Herdr](https://herdr.dev) (agent
multiplexer) as the terminal app. See
[`docs/references/new-tools-guide.md`](new-tools-guide.md) for what each tool does
and why it's configured the way it is.

## Prerequisites

- macOS. Both Apple Silicon and Intel are supported (see the [architecture
  note](#architecture-note-apple-silicon-vs-intel) below — this repo handles both).
- Xcode Command Line Tools (Homebrew needs these):
  ```zsh
  xcode-select --install
  ```
- zsh as the login shell — the macOS default since Catalina. Confirm with:
  ```zsh
  dscl . -read ~ UserShell
  ```
  If it says anything other than `/bin/zsh`, fix it with `chsh -s /bin/zsh`.

## Step 1 — Install Homebrew

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer prints a "next steps" block with a `brew shellenv` line to add to
your shell config — **skip that**, this repo's `zsh/.zprofile` already handles it
for both Homebrew install locations (Apple Silicon `/opt/homebrew`, Intel
`/usr/local`). You don't need to touch `~/.zprofile` by hand.

## Step 2 — Clone this repo

```zsh
mkdir -p ~/local
git clone https://github.com/gstro/dotfiles.git ~/local/dotfiles
```

Everything below assumes `~/local/dotfiles` — if you clone somewhere else, adjust
the `ZDOTDIR` path in Step 5 accordingly.

## Step 3 — Install the toolchain via Homebrew

```zsh
brew install starship zoxide fzf eza fd zinit fnm direnv atuin herdr
brew install --cask cmux font-jetbrains-mono-nerd-font
```

`herdr` is a formula, not a cask. `cmux` and the Nerd Font are casks (GUI
app + font, respectively). This is the exact tool list the terminal-modernization
migration settled on — see `new-tools-guide.md` if you want a different font or to
skip anything (e.g. Herdr, if you don't want the agent-multiplexer piece).

## Architecture note: Apple Silicon vs. Intel

`zsh/.zprofile` (Homebrew's `shellenv`) and `zsh/.zshrc` (Zinit's init script)
both check `/opt/homebrew` (Apple Silicon) before falling back to `/usr/local`
(Intel), so **no manual path editing is required either way** — this was fixed
directly in the repo rather than documented as a manual step, since a guide that
requires patching source files first isn't a very good guide. If you ever see
`command not found: brew` or missing git aliases (`gst`, etc.) after following this
guide, that's the first thing to check — confirm `brew --prefix` matches one of
the two paths these files look for.

## Step 4 — Point `ZDOTDIR` at the repo

Check what's currently at `~/.zshenv` first — on a genuinely fresh machine this is
usually empty or absent, but don't assume:

```zsh
cat ~/.zshenv 2>/dev/null || echo "(no existing ~/.zshenv)"
```

If it has real content you want to keep, back it up (`cp ~/.zshenv
~/.zshenv.pre-dotfiles.bak`) before overwriting. Then:

```zsh
echo 'export ZDOTDIR="$HOME/local/dotfiles/zsh"' > ~/.zshenv
```

This one line is the entire cutover mechanism — every zsh invocation from here on
reads `.zshenv`/`.zprofile`/`.zshrc` from the repo instead of `$HOME` directly. It's
worth testing in isolation before trusting it in every new terminal tab:

```zsh
ZDOTDIR="$HOME/local/dotfiles/zsh" zsh -il
```

If that opens cleanly with a Starship prompt, the bootstrap line is safe to rely on
for real.

## Step 5 — Secrets file

This repo's `zsh/.zshrc` sources `~/.zshrc.local` last, if it exists — this is
where API keys and anything else that shouldn't be committed goes. It's already
`.gitignore`d (`*.local`), so create it directly:

```zsh
cat > ~/.zshrc.local <<'EOF'
export OPENAI_API_KEY="..."
export LASTFM_API_KEY="..."
export TMDB_API_KEY="..."
EOF
chmod 600 ~/.zshrc.local
```

Only include the keys you actually use — this file is read unconditionally if
present, but there's no requirement to populate all three. Skip this step entirely
if you don't use any of them; `.zshrc` guards the `source` with `[[ -r ... ]]`, so a
missing file is a no-op, not an error.

## Step 6 — Node via fnm

```zsh
fnm install --lts
fnm default lts-latest
```

`fnm`'s shell integration (`--use-on-cd`) is already wired up in `zsh/.zshrc`, so
`cd`-ing into any directory with a `.nvmrc`/`.node-version` auto-switches — install
whichever specific versions your projects pin as you hit them
(`fnm install <version>`), there's no need to pre-install a full version matrix on
a fresh machine.

## Step 7 — Terminal stack: Ghostty config, cmux, Herdr

```zsh
mkdir -p ~/.config/ghostty ~/.config/cmux ~/.config/herdr
ln -sf ~/local/dotfiles/ghostty/config ~/.config/ghostty/config
ln -sf ~/local/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
```

**cmux is different — do this before first launch.** cmux auto-generates its own
default `~/.config/cmux/cmux.json` the first time it runs. If you haven't opened
cmux yet on this machine, just symlink directly:

```zsh
ln -sf ~/local/dotfiles/cmux/cmux.json ~/.config/cmux/cmux.json
```

If you've already launched cmux at least once (so a real generated file already
exists there), back it up before overwriting — diff it first in case it holds
settings you don't want to lose, since cmux may have prompted you through
first-run setup that isn't captured in the repo's version:

```zsh
diff ~/.config/cmux/cmux.json ~/local/dotfiles/cmux/cmux.json
cp ~/.config/cmux/cmux.json ~/.config/cmux/cmux.json.pre-repo-symlink.bak
ln -sf ~/local/dotfiles/cmux/cmux.json ~/.config/cmux/cmux.json
```

Then launch cmux (`open -a cmux`) and confirm the font/theme render correctly. If
it was already running before you symlinked, reload its config (`Cmd+Shift+,`) or
restart it.

## Step 8 — Verify

Same checks the migration itself used, adapted for a machine with no prior shell
state to compare against. Run a genuinely clean login+interactive shell (not
`zsh -ic`, which skips `.zprofile` — a mistake worth avoiding, it hid a real bug
during the original migration):

```zsh
env -i HOME="$HOME" TERM="$TERM" /bin/zsh -ilc '
  echo "ZDOTDIR=$ZDOTDIR"; echo "brew=$(command -v brew)"; fnm current;
  which gst glg mkcd extract;
  for c in starship zoxide fzf eza atuin; do printf "%s: " "$c"; command -v $c || echo "NOT FOUND"; done'
```

Every line should resolve to something under `/opt/homebrew` or `/usr/local`
(Homebrew), `~/.local/share/fnm` (fnm-managed Node), or print a real alias/function
body — not `NOT FOUND` or a blank line.

Then check startup time (target: roughly 120-300ms once history/completion caches
are warm — the first run or two may be slower while `compinit` builds its dump):

```zsh
for i in 1 2 3; do /usr/bin/time zsh -ilc exit; done
```

If something's missing, check the corresponding `brew install` from Step 3 landed,
and re-check the [architecture note](#architecture-note-apple-silicon-vs-intel)
above if it's specifically Homebrew or Zinit-sourced things (git aliases, `eza`
plugin) that are missing.

## Step 9 — Make cmux your terminal

Open cmux (`open -a cmux` or Spotlight) and use it for real work for a bit before
treating it as the default. If cmux exposes a "set as default terminal" option,
that's a one-time toggle in its own Settings (`Cmd+,`) — there's no scriptable
system-wide "default terminal" concept on macOS equivalent to default browser, so
this is a manual, GUI-only step.

## Optional: bringing history across from another machine

If you're setting up a second machine and want your shell history to carry over
rather than starting fresh, Atuin supports end-to-end encrypted sync
(`atuin register` / `atuin login` + `atuin sync` on both machines) — opt-in, not
required. Without it, each machine just builds its own local Atuin history from
that point forward, which is the simpler default and fine for most cases.

## What this guide deliberately skips

- **conda / sdkman / rvm** — `zsh/.zprofile` has guarded lazy-loading shims for
  all three (see `docs/references/zshrc-best-practices.md`), but they're no-ops if
  those tools aren't installed. Install them the normal way (their own official
  installers) if you need them; nothing here requires it.
- **`.profile` / `.bash_profile` / `.bashrc`** — this repo is zsh-only. If you also
  need a working `bash`/`sh` environment on the new machine (e.g. for a script that
  explicitly invokes `bash`), that's outside this repo's scope; set those up
  separately.
- **Warp** — not part of this stack anymore (see `docs/plans/terminal-modernization.md`
  for why). No need to install it on a new machine.
