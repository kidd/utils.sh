#!/usr/bin/env bash

# Utils, one `. $(dirname "$(readlink -f "$0")")/mblib.sh` away

# COLORS: See https://github.com/eskerda/vtfmt/
declare -A FMT_SET=(
  # Set             # fg colors       # bg colors
  [reset]=0         [fg:default]=39   [bg:default]=49
  [bold]=1          [fg:black]=30     [bg:black]=40
  [dim]=2           [fg:red]=31       [bg:red]=41
  [underline]=4     [fg:green]=32     [bg:green]=42
  [blink]=5         [fg:yellow]=33    [bg:yellow]=43
  [reverse]=7       [fg:blue]=34      [bg:blue]=44
  [hidden]=8        [fg:white]=97     [bg:white]=107
)

vtfmt() {
  local out=(); for comp in "$@"; do out+=("${FMT_SET[$comp]}"); done
  echo $(IFS=';' ; echo "\033[${out[*]}m")
}

WARN_C="$(vtfmt bg:yellow fg:black) WARN $(vtfmt reverse) %s$(vtfmt reset)\n"
INF_C="$(vtfmt bg:green fg:black) INFO $(vtfmt reverse) %s$(vtfmt reset)\n"
ERR_C="$(vtfmt bg:red fg:black)  ERR $(vtfmt reverse) %s$(vtfmt reset)\n"

# Messaging
inf()  { printf "$INF_C" "$*" ; }
err()  { printf "$ERR_C" "$*" ; }
warn() { printf "$WARN_C" "$*" ; }
die()  { err "$*" ; exit 1; }


# Helpers
mkcd   () { mkdir -p "$1"; cd "$1"; }
ask    () { read -p "$1" p; [[ $p =~ [yY](es)* ]]; }
join_by() { local IFS="$1"; shift; echo "$*"; }
mute   () { "$@" >/dev/null 2>/dev/null; }
mktmp  () { local f=$(mktemp "$@"); setup_trap; on_exit "rm -rf $f"; echo $f; }

# deps jq curl 'http httpie'
deps() {
  local UTILS_DEPS_INSTALL_CMD=${UTILS_DEPS_INSTALL_CMD:-apt install -y}
  for dep in "$@"; do
    read cmd package <<<"$dep"
    package=${package:-$cmd}
    mute which "$cmd" ||
      $MBLIB_DEPS_INSTALL_CMD $package ||
      die "couldn't install $package"
  done
}

# TRAP
setup_trap() {
  ON_EXIT=()
  EXIT_RES=

  _on_exit_fn() {
    EXIT_RES=$?
    for cb in "${ON_EXIT[@]}"; do $cb || true; done
    return $EXIT_RES
  }

  trap _on_exit_fn EXIT SIGINT

  on_exit() {
    ON_EXIT+=("$@")
  }
  setup_trap() { true ; }
}

# PG
ropsql() {
  PSQLRC=<(
    [ -f ~/.psqlrc ] && cat ~/.psqlrc ;
    echo 'set session characteristics as transaction read only;'
  ) psql "$@"
}

[ ! -z "$ZSH_VERSION" ] && for c in ropsql; do compdef $c=psql; done

# Profiles
mb::set_env() { export AWS_PROFILE="$1" AWS_REGION="$2" AWS_DEFAULT_REGION="$2" ; inf "$1"; }

mb:dev()     { mb::set_env dev us-west-2; }
mb:staging() { mb::set_env staging us-west-2; }
mb:prod()    { mb::set_env prod us-east-1; }
