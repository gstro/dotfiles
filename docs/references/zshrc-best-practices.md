# Zshrc Best Practices

Best practice: keep `~/.zshrc` **interactive, deterministic, fast, and boring**. It should set up the shell experience, not become a general machine bootstrap script.

## What belongs in `~/.zshrc`

Zsh reads `~/.zshrc` for **interactive shells**. That makes it the right place for aliases, shell options, functions, key bindings, prompt setup, completions, plugin loading, and interactive tools.

Put login-only work in `~/.zprofile` or `~/.zlogin`, and keep `~/.zshenv` extremely small because it is read by nearly every Zsh invocation. The official startup order is roughly:

1. `.zshenv`
2. Login files such as `.zprofile`
3. `.zshrc` for interactive shells
4. `.zlogin` for login shells

Source: <https://zsh.sourceforge.io/Doc/Release/Files.html>

## Recommended file responsibilities

| File | Use for | Avoid |
|---|---|---|
| `~/.zshenv` | Minimal environment needed by every Zsh process, maybe `ZDOTDIR` | Output, slow commands, interactive setup |
| `~/.zprofile` | Login-shell environment, PATH bootstrapping, Homebrew shellenv, pyenv/fnm/asdf env if needed before GUI apps | Aliases, keybindings, prompt |
| `~/.zshrc` | Interactive config: aliases, functions, completion, prompt, plugins, history, keybindings | Heavy installers, network calls, long-running checks |
| `~/.zlogin` | Rare login-only commands after `.zshrc` | Usually unnecessary |
| `~/.zlogout` | Cleanup on logout | Most people do not need it |

## Recommended `~/.zshrc` structure

```zsh
# ~/.zshrc

# 0. Exit early if not interactive.
[[ -o interactive ]] || return

# 1. Basic shell behavior.
setopt autocd
setopt interactivecomments
setopt histignorealldups
setopt sharehistory
setopt extendedhistory

# 2. History.
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# 3. PATH additions, only if they are interactive-specific.
typeset -U path PATH
path=(
  $HOME/.local/bin
  $HOME/bin
  $path
)

# 4. Completion configuration before compinit.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-dirs-first true

autoload -Uz compinit
compinit

# 5. Aliases.
alias ll='ls -lah'
alias grep='grep --color=auto'

# 6. Functions.
mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}

# 7. Tool initialization.
# eval "$(starship init zsh)"
# eval "$(zoxide init zsh)"
# eval "$(fnm env --use-on-cd --shell zsh)"

# 8. Key bindings last-ish.
bindkey -e

# 9. Tools that override key bindings should go very late.
# eval "$(atuin init zsh)"
```

## Practical best practices

### 1. Keep startup fast

Everything in `.zshrc` runs every time you open a terminal tab. Avoid network calls, package-manager updates, `brew upgrade`, `npm`, `curl`, `git fetch`, `aws sts`, or anything that can block.

If a tool supports lazy loading or shell integration caching, use it.

Measure startup time with:

```zsh
time zsh -i -c exit
```

For deeper profiling:

```zsh
zmodload zsh/zprof
# ... rest of .zshrc ...
zprof
```

A good target is under roughly 100-200 ms for an interactive shell. Lower is better, but reliability matters more than chasing micro-optimizations.

### 2. Initialize completions once, after configuring `fpath`

The Zsh completion system is initialized with:

```zsh
autoload -Uz compinit
compinit
```

`compinit` uses `fpath` to find completion functions, so add custom completion directories **before** calling `compinit`.

Good:

```zsh
fpath=("$HOME/.zsh/completions" $fpath)

zstyle ':completion:*' menu select
autoload -Uz compinit
compinit
```

Bad:

```zsh
autoload -Uz compinit
compinit

fpath=("$HOME/.zsh/completions" $fpath) # too late for this shell
```

Source: <https://zsh.sourceforge.io/Doc/Release/Completion-System.html>

### 3. Do not disable completion security casually

`compinit` checks whether completion files or directories are owned by unsafe users or are group/world-writable. If it finds insecure paths, it warns before loading them. That is intentional because completions are shell code.

Prefer fixing permissions:

```zsh
compaudit
chmod -R go-w /path/to/problem
```

Avoid papering over this with `compinit -u` unless you understand the risk. Also be careful with `compinit -C`; it can skip security checks when a dump file already exists.

Source: <https://zsh.sourceforge.io/Doc/Release/Completion-System.html>

### 4. Use `.zcompdump`, but know when to delete it

By default, `compinit` creates a `.zcompdump` file so future shells do not have to perform full completion initialization every time.

If completions behave weirdly after installing or removing tools, delete the dump and let it rebuild:

```zsh
rm -f ~/.zcompdump*
exec zsh
```

Source: <https://zsh.sourceforge.io/Doc/Release/Completion-System.html>

### 5. Prefer arrays for `PATH`

Zsh has a native `path` array tied to `PATH`. Use it instead of string concatenation.

Good:

```zsh
typeset -U path PATH
path=(
  /opt/homebrew/bin
  $HOME/.local/bin
  $path
)
```

Less good:

```zsh
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
```

The array form is easier to dedupe, reorder, and reason about.

### 6. Guard optional tools

Your shell should still open if a tool is uninstalled. This matters on new machines, SSH hosts, CI containers, and recovery shells.

```zsh
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell zsh)"
```

For heavier tools, prefer lazy loading.

### 7. Keep aliases simple; use functions for logic

Aliases are great for tiny substitutions:

```zsh
alias g='git'
alias gst='git status'
alias k='kubectl'
```

Use functions when arguments, quoting, branching, or error handling matter:

```zsh
gclonecd() {
  git clone "$1" && cd "${1:t:r}"
}
```

### 8. Quote aggressively in functions

A lot of shell bugs come from unquoted variables.

Good:

```zsh
extract() {
  [[ -f "$1" ]] || return 1
  case "$1" in
    *.tar.gz) tar -xzf "$1" ;;
    *.zip)    unzip "$1" ;;
    *)        echo "Unsupported archive: $1" >&2; return 1 ;;
  esac
}
```

Bad:

```zsh
tar -xzf $1
```

### 9. Keep secrets out of `.zshrc`

Do not put API keys, tokens, or cloud credentials directly in the file.

Prefer one of these:

- Password manager
- OS keychain
- `.envrc` via `direnv`
- AWS profiles
- `gcloud auth`
- `op`
- `aws-vault`
- Similar credential-management tooling

At most, source a private local file that is not committed:

```zsh
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

Then add this file to your dotfiles repository ignore list.

### 10. Make machine-specific config explicit

A clean pattern:

```zsh
# Shared config above...

case "$(uname -s)" in
  Darwin)
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    ;;
  Linux)
    # Linux-specific setup
    ;;
esac

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

This keeps your portable config portable and your host-specific hacks isolated.

### 11. Be careful with plugin frameworks

Plugin managers are useful, but every plugin is startup code. Prefer a small number of high-value plugins.

A reasonable modern set:

```text
prompt:              starship or p10k
completion UX:       fzf-tab or native zstyle config
history search:      atuin or fzf history
directory jumping:   zoxide
syntax feedback:     zsh-syntax-highlighting
suggestions:         zsh-autosuggestions
```

Do not load an entire framework just to get three aliases.

### 12. Order matters

A good ordering rule:

```text
early guard
shell options
environment/path
completion paths and styles
compinit
aliases/functions
prompt
tool integrations
key bindings
history/search tools that override key bindings
local overrides
```

For example, `fzf-tab` generally needs to be loaded after completion is available. Tools like Atuin that override `Ctrl+R` should come after anything else that might bind `Ctrl+R`.

## Preferred philosophy

For a modern engineering workstation, aim for:

```text
minimal .zshenv
boring .zprofile
fast .zshrc
one prompt tool
one plugin manager or none
guarded optional tools
no secrets
no package installs
no network calls
local override file
startup profiling when it feels slow
```

The biggest mistake is treating `.zshrc` like a setup script. It is not. It is hot-path runtime code for every interactive shell.

## Sources

- Zsh startup files: <https://zsh.sourceforge.io/Doc/Release/Files.html>
- Zsh completion system: <https://zsh.sourceforge.io/Doc/Release/Completion-System.html>
