#!/usr/bin/env bats
#
# install.sh with sudo, apt-get and gh stubbed, in a fake HOME. Nothing is
# installed, nothing reaches the network, and no real login happens.

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
  export LOG="$BATS_TEST_TMPDIR/calls.log"; : >"$LOG"
  export DCX_TTY="$BATS_TEST_TMPDIR/tty"; : >"$DCX_TTY"
  export DCX_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"; printf 'ID=ubuntu\n' >"$DCX_OS_RELEASE"
  export GH_ACCESS=yes
  S="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$S"
  for t in sudo apt-get; do printf '#!/usr/bin/env bash\necho "%s $*" >>"$LOG"\n[ "%s" = sudo ] && exec "$@"\nexit 0\n' "$t" "$t" >"$S/$t"; done
  cat >"$S/gh" <<'G'
#!/usr/bin/env bash
echo "gh $*" >>"$LOG"
case "$1 $2" in
  "repo view") [ "$GH_ACCESS" = yes ] ;;
  "auth login") export GH_ACCESS=yes; touch "$HOME/.logged-in" ;;
  "repo clone") mkdir -p "$4/machine"; printf '#!/usr/bin/env bash\necho "setup.sh ran" >>"$LOG"\n' >"$4/machine/setup.sh" ;;
  *) exit 0 ;;
esac
G
  chmod +x "$S"/*
  export PATH="$S:$PATH"
}

@test "on a machine with the tools, it signs in, fetches and hands over" {
  run bash "$BATS_TEST_DIRNAME/../install.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  ! grep -q 'apt-get install' "$LOG"
  grep -q 'gh repo clone alexstandcx/new-project-template' "$LOG"
  grep -q 'setup.sh ran' "$LOG"
}

@test "missing tools are installed with apt" {
  local S2="$BATS_TEST_TMPDIR/nogh"; mkdir -p "$S2"
  for t in bash env git curl grep mkdir dirname cat printf; do ln -sf "$(command -v $t)" "$S2/$t"; done
  cp "$BATS_TEST_TMPDIR/stubs/sudo" "$BATS_TEST_TMPDIR/stubs/apt-get" "$S2/"
  PATH="$S2" run "$S2/bash" "$BATS_TEST_DIRNAME/../install.sh"
  grep -q 'apt-get install -y gh' "$LOG"
}

@test "not signed in: it asks for a GitHub login" {
  export GH_ACCESS=no
  run bash "$BATS_TEST_DIRNAME/../install.sh"
  grep -q 'gh auth login' "$LOG"
}

@test "already fetched: it pulls fast forward only instead of cloning" {
  local d="$HOME/.local/share/dcx/new-project-template"
  git init --quiet "$d"; mkdir -p "$d/machine"; printf '#!/usr/bin/env bash\necho "setup.sh ran" >>"$LOG"\n' >"$d/machine/setup.sh"
  git -C "$d" -c user.name=t -c user.email=t@t add -A; git -C "$d" -c user.name=t -c user.email=t@t commit --quiet -m x
  git init --quiet --bare "$BATS_TEST_TMPDIR/remote.git"; git -C "$d" remote add origin "$BATS_TEST_TMPDIR/remote.git"; git -C "$d" push --quiet -u origin HEAD 2>/dev/null
  run bash "$BATS_TEST_DIRNAME/../install.sh"
  echo "$output"
  [[ "$output" == *"pull --ff-only"* ]]
  ! grep -q 'repo clone' "$LOG"
  grep -q 'setup.sh ran' "$LOG"
}

@test "not Ubuntu or Debian: it stops" {
  printf 'ID=fedora\n' >"$DCX_OS_RELEASE"
  run bash "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
}

@test "a download cut off part way runs nothing" {
  head -c 1500 "$BATS_TEST_DIRNAME/../install.sh" >"$BATS_TEST_TMPDIR/cut.sh"
  run bash "$BATS_TEST_TMPDIR/cut.sh"
  [ ! -s "$LOG" ]
}

@test "it holds nothing private" {
  ! grep -iE 'token|password|secret|api[_-]?key' "$BATS_TEST_DIRNAME/../install.sh" | grep -v -i 'password\.\|your linux password'
}
