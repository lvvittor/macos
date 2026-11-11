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
mkdir -p "$HOME/Applications/Google Chrome.app"
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
stub brew 'exit 0'
stub nvim 'exit 0'
stub paneru 'echo "$*" >>"$HOME/.fake-paneru-calls"'
stub gh 'exit 1'
export MAC_SETUP_BREW_BIN="$BIN/brew"
export PATH="$BIN:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }

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
mkdir -p "$CHROME/Default/Extensions/$BW/1.0" "$CHROME/Default/Local Extension Settings/$BW" "$CHROME/Default/Local Extension Settings/other"

echo yes | bash "$ROOT/teardown.sh" >"$T/teardown.log"

[[ $(cat "$HOME/.config/nvim/init.lua") == ORIGINAL ]] || fail "original nvim config restored"
[[ ! -e $HOME/.config/nvim.mac-setup-bak ]] || fail "backup consumed"
[[ ! -e $HOME/.config/ghostty && ! -e $HOME/.paneru.toml ]] || fail "new configs removed"
grep -qx uninstall "$HOME/.fake-paneru-calls" || fail "paneru service uninstalled"
[[ ! -e "$CHROME/External Extensions/$BW.json" ]] || fail "bitwarden file removed"
[[ ! -e "$CHROME/Default/Extensions/$BW" && ! -e "$CHROME/Default/Local Extension Settings/$BW" ]] || fail "bitwarden data removed"
[[ -d "$CHROME/Default/Local Extension Settings/other" ]] || fail "other extensions untouched"
[[ $(cat "$HOME/.zshrc") == "USER LINE" ]] || fail "zshrc back to the user's own line"
[[ ! -s $HOME/.zprofile ]] || fail "zprofile block removed"
[[ ! -e $HOME/.fake-keychain ]] || fail "gateway key deleted from keychain"
[[ ! -e $HOME/.claude ]] || fail "home .claude removed"
[[ ! -e $HOME/.mac-setup ]] || fail "state removed"
! git config --global user.email >/dev/null || fail "git identity removed"

echo "PASS: two installs converge, teardown restores the account"
