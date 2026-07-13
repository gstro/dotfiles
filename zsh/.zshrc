# Interactive shell config. See docs/plans/terminal-modernization.md for the
# full migration plan and docs/references/zshrc-best-practices.md for the
# conventions this file follows.

[[ -o interactive ]] || return

# --- Basic shell behavior ---
setopt autocd
setopt interactivecomments
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify
setopt extendedhistory

# --- History ---
# Pinned to the existing history file/size rather than ZDOTDIR's default
# location, so the pre-migration history is preserved.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

# --- Completion styles + fpath (before compinit) ---
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-dirs-first true

fpath=("$HOME/Library/Application Support/ScalaCli/completions/zsh" $fpath)

# --- Zinit + cherry-picked oh-my-zsh snippets ---
# Uses the brew-installed zinit.zsh directly (see Phase 1 status in the plan
# doc) rather than self-bootstrapping via a git clone.
source /usr/local/opt/zinit/zinit.zsh

zinit snippet OMZL::git.zsh
zinit snippet OMZL::directories.zsh
zinit snippet OMZL::theme-and-appearance.zsh
# OMZL::async_prompt.zsh intentionally skipped — starship has its own async
# rendering, so this lib would be dead weight here.

# eza zstyle config — must precede the plugin.
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes

zinit snippet OMZP::git
zinit snippet OMZP::bgnotify
zinit snippet OMZP::brew
zinit snippet OMZP::direnv
zinit snippet OMZP::eza

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

autoload -Uz compinit
compinit -C

# fzf-tab loaded after compinit per its own docs — a small, deliberate
# deviation from the exact snippet order in the source blog post.
zinit light Aloxaf/fzf-tab

# --- Custom aliases/functions (after snippets, so these win on collision) ---
for f in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$f"
done

# --- Prompt ---
export STARSHIP_CONFIG="${ZDOTDIR:h}/starship.toml"
eval "$(starship init zsh)"

# --- Tool integrations ---
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
eval "$(zoxide init zsh)"
eval "$(fzf --zsh)"

bindkey -e

# Atuin last — overrides Ctrl+R after everything else, including fzf, has
# had a chance to bind it first.
eval "$(atuin init zsh)"

# --- Local secrets (outside the repo, gitignored) ---
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
