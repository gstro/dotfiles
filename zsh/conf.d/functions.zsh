gi() {
  curl -sL "https://www.toptal.com/developers/gitignore/api/$*"
}

mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}

extract() {
  [[ -f "$1" ]] || return 1
  case "$1" in
    *.tar.gz) tar -xzf "$1" ;;
    *.zip)    unzip "$1" ;;
    *)        echo "Unsupported archive: $1" >&2; return 1 ;;
  esac
}

gclonecd() {
  git clone "$1" && cd "${1:t:r}"
}
