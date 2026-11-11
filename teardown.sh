#!/usr/bin/env bash
# Removes what install.sh added to this account and restores anything it moved aside.
set -euo pipefail

STATE="$HOME/.mac-setup"
if [[ ! -d $STATE ]]; then
  echo "Nothing to remove. $STATE is missing, so install.sh never ran on this account."
  exit 0
fi

preexisting() { grep -qx "$1" "$STATE/preexisting" 2>/dev/null; }

echo "This removes the gateway key from the Keychain, the shell blocks in ~/.zshrc and ~/.zprofile,"
echo "the nvim, ghostty, and paneru configs, the paneru login service, Neovim plugin data, and the git identity install.sh set."
preexisting claude-dir || echo "It also deletes ~/.claude and ~/.claude.json, which install.sh created."
preexisting claude-bin || echo "It also uninstalls Claude Code from ~/.local."
echo "Homebrew packages stay. Your project folders are untouched."
read -r -p "Type yes to continue: " ok
[[ $ok == yes ]] || { echo "Stopped."; exit 1; }

security delete-generic-password -s ANTHROPIC_AUTH_TOKEN >/dev/null 2>&1 || true

while IFS=$'\t' read -r dest kind; do
  [[ -n $dest ]] || continue
  rm -rf "$dest"
  if [[ $kind == backup && -e $dest.mac-setup-bak ]]; then mv "$dest.mac-setup-bak" "$dest"; fi
done <"$STATE/placed"

for f in "$HOME/.zshrc" "$HOME/.zprofile"; do
  [[ -f $f ]] || continue
  awk '/^# >>> mac-setup:/{s=1;next} /^# <<< mac-setup:/{s=0;next} !s' "$f" >"$f.mac-setup-tmp"
  mv "$f.mac-setup-tmp" "$f"
done

preexisting claude-dir || rm -rf "$HOME/.claude" "$HOME/.claude.json"
preexisting claude-bin || rm -rf "$HOME/.local/bin/claude" "$HOME/.local/share/claude" "$HOME/.cache/claude"
rm -rf "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"

if command -v paneru >/dev/null; then
  paneru stop >/dev/null 2>&1 || true
  paneru uninstall >/dev/null 2>&1 || true
fi
rm -rf "$HOME/.local/state/paneru"

if [[ -f $STATE/git-identity ]]; then
  git config --global --unset user.name || true
  git config --global --unset user.email || true
fi

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh auth logout --hostname github.com || true
fi

rm -rf "$STATE" "$HOME/mac-setup"
echo "Done. Sign out of GitHub and any other site in the browser yourself."
