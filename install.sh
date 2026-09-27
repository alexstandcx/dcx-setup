#!/usr/bin/env bash
#
# dcx-setup: the first step of setting up a machine the way Alex works.
#
#   curl -fsSL https://raw.githubusercontent.com/alexstandcx/dcx-setup/main/install.sh | bash
#
# It installs git, curl and the GitHub CLI, has you sign in to GitHub,
# fetches the private new-project-template repo, and hands over to its
# machine/setup.sh, which shows a plan and asks before changing anything.
# This script holds nothing private. Read it before running it:
#   curl -fsSL https://raw.githubusercontent.com/alexstandcx/dcx-setup/main/install.sh | less

# Everything is inside one function called on the last line, so a download
# cut off part way runs nothing at all.
dcx_setup_main() {
  set -euo pipefail

  local repo="${DCX_REPO:-alexstandcx/new-project-template}"
  local dir="${DCX_DIR:-$HOME/.local/share/dcx/new-project-template}"
  # Piped from curl, this script's own input is the pipe, so every answer
  # is read from the terminal.
  local tty="${DCX_TTY:-/dev/tty}"

  say() { printf '%s\n' "$*"; }
  run() { printf '+ %s\n' "$*"; "$@"; }

  local osr="${DCX_OS_RELEASE:-/etc/os-release}"
  if [ ! -r "$osr" ] || ! grep -qiE '^(ID|ID_LIKE)=.*(ubuntu|debian)' "$osr"; then
    say "stop: this setup is for Ubuntu or Debian, including under WSL."
    return 2
  fi

  local need=() t
  for t in git curl gh; do command -v "$t" >/dev/null 2>&1 || need+=("$t"); done
  if [ "${#need[@]}" -gt 0 ]; then
    say "Installing ${need[*]}. sudo will ask for your Linux password."
    run sudo apt-get update -q </"$tty"
    run sudo apt-get install -y "${need[@]}" </"$tty"
  else
    say "ok: git, curl and gh are installed"
  fi

  if gh repo view "$repo" >/dev/null 2>&1; then
    say "ok: signed in to GitHub with access to $repo"
  else
    say "Sign in to GitHub as the account that can read $repo. Choose GitHub.com, HTTPS, and yes to authenticating Git."
    run gh auth login </"$tty"
    gh repo view "$repo" >/dev/null 2>&1 || { say "stop: this GitHub account cannot read $repo."; return 2; }
  fi
  gh auth setup-git >/dev/null 2>&1 || true

  if [ -d "$dir/.git" ]; then
    run git -C "$dir" pull --ff-only --quiet
  else
    mkdir -p "$(dirname "$dir")"
    run gh repo clone "$repo" "$dir" -- --quiet
  fi

  say "Handing over to machine/setup.sh. It shows a plan and asks before changing anything."
  exec bash "$dir/machine/setup.sh" </"$tty"
}

dcx_setup_main "$@"
