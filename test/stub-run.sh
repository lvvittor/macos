#!/usr/bin/env bash
# Runs install.sh twice and teardown.sh once in a throwaway HOME with stubbed
# macOS tools, then checks the account ends where it started.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
BIN="$T/bin"
mkdir -p "$HOME/.config/nvim" "$BIN"
echo ORIGINAL >"$HOME/.config/nvim/init.lua"
echo "USER LINE" >"$HOME/.zshrc"
mkdir -p "$HOME/Applications/Google Chrome.app" "$HOME/.lima"
echo KEEP >"$HOME/.lima/keep"
CHROME="$HOME/Library/Application Support/Google/Chrome"
BW=nngceckbapebfimnlniiiahkandclblb

stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$BIN/$1"; chmod +x "$BIN/$1"; }
stub uname 'case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; *) /usr/bin/uname "$@" ;; esac'
stub security 'k="$HOME/.fake-keychain"
case "$1" in
  find-generic-password) [[ -f $k ]] && cat "$k" ;;
  add-generic-password) echo fake-key >"$k" ;;
  delete-generic-password) rm -f "$k" ;;
esac'
stub claude 'if [[ "$*" == "plugin marketplace list" ]]; then [[ -f $HOME/.fake-mkt ]] && echo cursor-plugins; exit 0; fi
[[ "$*" == "plugin marketplace add cursor/plugins" ]] && touch "$HOME/.fake-mkt"
exit 0'
stub brew 'echo "$*" >>"$HOME/.fake-brew-calls"'
stub nvim 'exit 0'
stub mise 'echo "$*" >>"$HOME/.fake-mise-calls"'
stub npm 'echo "$*" >>"$HOME/.fake-npm-calls"'
stub colima 'echo "$*" >>"$HOME/.fake-colima-calls"'
stub paneru 'echo "$*" >>"$HOME/.fake-paneru-calls"'
stub gh 'exit 1'
export MAC_SETUP_BREW_BIN="$BIN/brew"
export PATH="$BIN:/usr/bin:/bin"

fail() { echo "FAIL: $*" >&2; exit 1; }

if bash "$ROOT/install.sh" --minimal --tools </dev/null >/dev/null 2>&1; then fail "--minimal --tools rejected"; fi
printf 'Test User\ntest@example.com\n' | bash "$ROOT/install.sh" >"$T/run1.log"
bash "$ROOT/install.sh" </dev/null >"$T/run2.log"

[[ $(cat "$HOME/.config/nvim.mac-setup-bak/init.lua") == ORIGINAL ]] || fail "original nvim config backed up"
grep -q 'lazy' "$HOME/.config/nvim/init.lua" || fail "our nvim config placed"
[[ $(grep -c '^# >>> mac-setup:gateway >>>' "$HOME/.zshrc") == 1 ]] || fail "gateway block written once after two runs"
[[ $(grep -c '^# >>> mac-setup:brew >>>' "$HOME/.zprofile") == 1 ]] || fail "brew block written once after two runs"
[[ $(grep -c "nvim" "$HOME/.mac-setup/placed") == 1 ]] || fail "nvim recorded once in state"
grep -q 'ai-gateway.vercel.sh/claude-code' "$HOME/.claude/settings.json" || fail "gateway base URL in settings"
grep -q 'already in the Keychain' "$T/run2.log" || fail "second run reuses the key"
[[ $(git config --global user.email) == test@example.com ]] || fail "git identity set"
[[ -f $HOME/.config/ghostty/config ]] || fail "ghostty config placed"
grep -q "window_focus_west" "$HOME/.paneru.toml" || fail "paneru config placed"
grep -qx start "$HOME/.fake-paneru-calls" || fail "paneru service started"
grep -q clients2.google.com "$CHROME/External Extensions/$BW.json" || fail "bitwarden queued for chrome"
[[ ! -e "$HOME/Library/Application Support/BraveSoftware" ]] || fail "nothing written for brave, which is not installed"
! grep -q Brewfile.tools "$HOME/.fake-brew-calls" || fail "tools skipped without --tools"
! grep -q "mac-setup:mise" "$HOME/.zshrc" || fail "no mise hook without --tools"
bash "$ROOT/install.sh" --tools </dev/null >"$T/run3.log"
bash "$ROOT/install.sh" --tools </dev/null >"$T/run4.log"
grep -q "Brewfile.tools" "$HOME/.fake-brew-calls" || fail "tools Brewfile installed with --tools"
grep -q cliPluginsExtraDirs "$HOME/.docker/config.json" || fail "docker plugin config placed"
grep -q "^node" "$HOME/.config/mise/config.toml" || fail "mise config placed"
[[ $(grep -c "^# >>> mac-setup:mise >>>" "$HOME/.zshrc") == 1 ]] || fail "mise hook written once after two --tools runs"
grep -qx install "$HOME/.fake-mise-calls" || fail "mise install ran"
grep -qx "install -g vercel typescript" "$HOME/.fake-npm-calls" || fail "vercel cli and typescript installed"
grep -qxF "$HOME/.ssh" "$HOME/.mac-setup/scrub" || fail "missing ssh dir listed for teardown"
! grep -qxF "$HOME/.lima" "$HOME/.mac-setup/scrub" || fail "preexisting lima dir not listed"
mkdir -p "$HOME/.ssh" "$HOME/.colima"
echo secret >"$HOME/.ssh/id_ed25519"
echo token >"$HOME/.npmrc"
mkdir -p "$HOME/.config/rclone"
echo token >"$HOME/.config/rclone/rclone.conf"
mkdir -p "$HOME/.cargo"
echo token >"$HOME/.cargo/credentials.toml"
mkdir -p "$CHROME/Default/Extensions/$BW/1.0" "$CHROME/Default/Local Extension Settings/$BW" "$CHROME/Default/Local Extension Settings/other"

echo yes | bash "$ROOT/teardown.sh" >"$T/teardown.log"

[[ $(cat "$HOME/.config/nvim/init.lua") == ORIGINAL ]] || fail "original nvim config restored"
[[ ! -e $HOME/.config/nvim.mac-setup-bak ]] || fail "backup consumed"
[[ ! -e $HOME/.config/ghostty && ! -e $HOME/.paneru.toml ]] || fail "new configs removed"
grep -qx uninstall "$HOME/.fake-paneru-calls" || fail "paneru service uninstalled"
[[ ! -e "$CHROME/External Extensions/$BW.json" ]] || fail "bitwarden file removed"
[[ ! -e "$CHROME/Default/Extensions/$BW" && ! -e "$CHROME/Default/Local Extension Settings/$BW" ]] || fail "bitwarden data removed"
[[ -d "$CHROME/Default/Local Extension Settings/other" ]] || fail "other extensions untouched"
[[ ! -e $HOME/.ssh && ! -e $HOME/.npmrc && ! -e $HOME/.colima && ! -e $HOME/.docker ]] || fail "keys, tokens, and tool data removed"
[[ ! -e $HOME/.config/mise/config.toml ]] || fail "mise config removed"
[[ ! -e $HOME/.config/rclone ]] || fail "rclone token removed"
[[ ! -e $HOME/.cargo ]] || fail "cargo token removed"
[[ $(cat "$HOME/.lima/keep") == KEEP ]] || fail "preexisting lima dir kept"
grep -q "delete --force" "$HOME/.fake-colima-calls" || fail "colima VM deleted"
[[ $(cat "$HOME/.zshrc") == "USER LINE" ]] || fail "zshrc back to the user's own line"
[[ ! -s $HOME/.zprofile ]] || fail "zprofile block removed"
[[ ! -e $HOME/.fake-keychain ]] || fail "gateway key deleted from keychain"
[[ ! -e $HOME/.claude ]] || fail "home .claude removed"
[[ ! -e $HOME/.mac-setup ]] || fail "state removed"
! git config --global user.email >/dev/null || fail "git identity removed"

echo "PASS: two installs converge, teardown restores the account"
