# Read by every zsh invocation (scripts, non-interactive, login, interactive).
# Intentionally minimal — see docs/references/zshrc-best-practices.md.
#
# No PATH/env setup here: PATH lives in .zprofile as a single deduped array,
# and cargo's own env script (`. "$HOME/.cargo/env"`) is redundant with it,
# so it's deliberately not sourced here.
