# Login-shell setup: PATH, brew, and lazy shims for heavy version managers.
# Aliases/functions/prompt/completions belong in .zshrc, not here.

[[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"

typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/.cargo/bin"
  "$HOME/.poetry/bin"
  "$HOME/Library/pnpm"
  "$HOME/.local/share/coursier"
  "$HOME/Library/Application Support/Coursier/bin"
  "$HOME/.rvm/bin"
  $path
)

export PNPM_HOME="$HOME/Library/pnpm"

# --- Lazy shims for conda/sdkman/rvm ---
# Each defines a stub function that, on first real invocation, replaces
# itself with the tool's actual init and re-dispatches. Keeps these off the
# hot path for every new shell, guarded so a shell without them still opens
# cleanly (e.g. on a fresh machine or over SSH).

if [[ -x /opt/miniconda3/bin/conda ]]; then
  conda() {
    unfunction conda
    __conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
      eval "$__conda_setup"
    elif [[ -f /opt/miniconda3/etc/profile.d/conda.sh ]]; then
      . /opt/miniconda3/etc/profile.d/conda.sh
    else
      path+=(/opt/miniconda3/bin)
    fi
    unset __conda_setup
    conda "$@"
  }
fi

if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  sdk() {
    unfunction sdk
    export SDKMAN_DIR="$HOME/.sdkman"
    # Lazy-loading means this only ever runs on first use, so it's
    # naturally always "last" — the old "must be at the end of the
    # file" constraint from sourcing it eagerly no longer applies.
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk "$@"
  }
fi

if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  rvm() {
    unfunction rvm
    source "$HOME/.rvm/scripts/rvm"
    rvm "$@"
  }
fi
