#!/usr/bin/env bash
# Sets up a fresh macOS account. Steps run in order of value, so stopping
# early still leaves Claude Code working through the gateway.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HOME/.mac-setup"
KEYCHAIN_SERVICE="ANTHROPIC_AUTH_TOKEN"
DRY_RUN=0
MINIMAL=0
TOOLS=0
STEP_LOG=()
BITWARDEN_ID=nngceckbapebfimnlniiiahkandclblb
BROWSERS=("Google Chrome|Google/Chrome" "Brave Browser|BraveSoftware/Brave-Browser")
# Keys, logins, and tool data that a day of work can leave behind. teardown.sh deletes the ones
# that did not exist before the first install.
SCRUB_PATHS=(
  "$HOME/.ssh" "$HOME/.config/gh" "$HOME/.npmrc" "$HOME/.npm"
  "$HOME/.docker" "$HOME/.colima" "$HOME/.lima"
  "$HOME/Library/Application Support/com.vercel.cli"
  "$HOME/Library/pnpm" "$HOME/.local/share/pnpm"
  "$HOME/.local/share/mise" "$HOME/.local/state/mise" "$HOME/.cache/mise"
  "$HOME/.config/rclone"
)

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --minimal) MINIMAL=1 ;;
    --tools) TOOLS=1 ;;
    *) echo "unknown flag: $arg (use --minimal, --tools, or --dry-run)" >&2; exit 2 ;;
  esac
done
if (( MINIMAL && TOOLS )); then
  echo "--tools needs Homebrew, so it can't run with --minimal." >&2
  exit 2
fi

run() {
  if (( DRY_RUN )); then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}

step() {
  local name=$1 t0=$SECONDS
  shift
  printf '\n==> %s\n' "$name"
  "$@"
  STEP_LOG+=("$(printf '%-22s %4ss' "$name" $((SECONDS - t0)))")
}

write_block() {
  local file=$1 name=$2 content=$3
  local begin="# >>> mac-setup:$name >>>" end="# <<< mac-setup:$name <<<"
  if (( DRY_RUN )); then printf '[dry-run] block %s in %s: %s\n' "$name" "$file" "$content"; return; fi
  touch "$file"
  local tmp
  tmp=$(mktemp)
  awk -v b="$begin" -v e="$end" '$0==b{s=1;next} $0==e{s=0;next} !s' "$file" >"$tmp"
  { cat "$tmp"; printf '%s\n%s\n%s\n' "$begin" "$content" "$end"; } >"$file"
  rm -f "$tmp"
}

# The state file remembers whether each destination existed before the first
# run, so a rerun never backs up our own copy and teardown restores the original.
place() {
  local src=$1 dest=$2
  if ! grep -qxF "$dest"$'\tbackup' "$STATE/placed" 2>/dev/null &&
     ! grep -qxF "$dest"$'\tnew' "$STATE/placed" 2>/dev/null; then
    if [[ -e $dest ]]; then
      run mv "$dest" "$dest.mac-setup-bak"
      (( DRY_RUN )) || printf '%s\tbackup\n' "$dest" >>"$STATE/placed"
    else
      (( DRY_RUN )) || printf '%s\tnew\n' "$dest" >>"$STATE/placed"
    fi
  fi
  run rm -rf "$dest"
  run cp -R "$src" "$dest"
}

preflight() {
  if [[ $(uname -s) != Darwin ]] && (( ! DRY_RUN )); then
    echo "This script is for macOS." >&2
    exit 1
  fi
  run mkdir -p "$STATE"
  if [[ ! -f $STATE/preexisting ]] && (( ! DRY_RUN )); then
    : >"$STATE/preexisting"
    [[ -e $HOME/.claude ]] && echo claude-dir >>"$STATE/preexisting"
    command -v claude >/dev/null && echo claude-bin >>"$STATE/preexisting"
    touch "$STATE/placed" "$STATE/scrub"
    local p
    for p in "${SCRUB_PATHS[@]}"; do
      [[ -e $p ]] || printf '%s\n' "$p" >>"$STATE/scrub"
    done
  fi
  return 0
}

install_claude() {
  if command -v claude >/dev/null || [[ -x $HOME/.local/bin/claude ]]; then
    echo "Claude Code already installed."
  else
    run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
  fi
  write_block "$HOME/.zshrc" path 'export PATH="$HOME/.local/bin:$PATH"'
  export PATH="$HOME/.local/bin:$PATH"
}

gateway_key() {
  if security find-generic-password -s "$KEYCHAIN_SERVICE" -w >/dev/null 2>&1; then
    echo "Gateway key already in the Keychain."
  else
    echo "Paste the Vercel AI Gateway key when asked, twice. It goes to the login Keychain, not a file."
    run security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w
  fi
  write_block "$HOME/.zshrc" gateway \
    'export ANTHROPIC_AUTH_TOKEN="$(security find-generic-password -s ANTHROPIC_AUTH_TOKEN -w 2>/dev/null)"'
}

claude_settings() {
  run mkdir -p "$HOME/.claude"
  place "$HERE/claude/settings.json" "$HOME/.claude/settings.json"
  place "$HERE/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
}

homebrew() {
  local brew_bin=/opt/homebrew/bin/brew
  [[ $(uname -m) == arm64 ]] || brew_bin=/usr/local/bin/brew
  brew_bin=${MAC_SETUP_BREW_BIN:-$brew_bin}
  if [[ -x $brew_bin ]]; then
    echo "Homebrew already installed."
  else
    echo "Homebrew asks for RETURN and this account's macOS password. It may also install the Xcode Command Line Tools."
    run bash -c '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
  write_block "$HOME/.zprofile" brew "eval \"\$($brew_bin shellenv)\""
  if (( ! DRY_RUN )); then eval "$("$brew_bin" shellenv)"; fi
}

brew_bundle() {
  run env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --no-upgrade --file "$HERE/Brewfile"
}

pstack() {
  if claude plugin marketplace list 2>/dev/null | grep -q cursor-plugins; then
    echo "cursor-plugins marketplace already added."
  else
    run claude plugin marketplace add cursor/plugins
  fi
  run claude plugin install -y pstack@cursor-plugins || echo "pstack install exited non-zero. If it says already installed, that's fine."
}

configs() {
  run mkdir -p "$HOME/.config"
  place "$HERE/config/nvim" "$HOME/.config/nvim"
  place "$HERE/config/ghostty" "$HOME/.config/ghostty"
  place "$HERE/config/paneru/paneru.toml" "$HOME/.paneru.toml"
}

# Chrome and Brave install a Web Store extension named by a JSON file in External Extensions,
# and uninstall it when the file goes away.
bitwarden() {
  local entry app data found=0
  for entry in "${BROWSERS[@]}"; do
    app=${entry%%|*}
    data="$HOME/Library/Application Support/${entry#*|}"
    [[ -d "/Applications/$app.app" || -d "$HOME/Applications/$app.app" ]] || continue
    found=1
    run mkdir -p "$data/External Extensions"
    place "$HERE/browser/bitwarden.json" "$data/External Extensions/$BITWARDEN_ID.json"
    echo "Bitwarden is queued for $app. Quit and reopen it, then click Enable."
  done
  (( found )) || echo "Chrome and Brave are not installed, so Bitwarden was skipped. Install one and rerun install.sh."
}

git_identity() {
  if git config --global user.email >/dev/null 2>&1; then
    echo "git identity already set to $(git config --global user.email)."
    return
  fi
  local name email
  read -r -p "git user.name: " name
  read -r -p "git user.email: " email
  run git config --global user.name "$name"
  run git config --global user.email "$email"
  (( DRY_RUN )) || echo set >"$STATE/git-identity"
}

nvim_plugins() {
  run nvim --headless "+Lazy! restore" +qa
}

tools() {
  run env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --no-upgrade --file "$HERE/Brewfile.tools"
  run mkdir -p "$HOME/.docker" "$HOME/.config/mise"
  place "$HERE/config/docker/config.json" "$HOME/.docker/config.json"
  place "$HERE/config/mise/config.toml" "$HOME/.config/mise/config.toml"
  write_block "$HOME/.zshrc" mise 'eval "$(mise activate zsh)"'
  run mise install || echo "mise install exited non-zero. Run mise install again in a new terminal."
  if command -v vercel >/dev/null; then
    echo "Vercel CLI already installed."
  else
    run npm install -g vercel
  fi
}

window_manager() {
  run paneru install || echo "paneru install exited non-zero. If the service already exists, that's fine."
  run paneru start || echo "paneru start exited non-zero. If it is already running, that's fine."
}

summary() {
  printf '\n==> Timings\n'
  printf '  %s\n' "${STEP_LOG[@]}"
  printf '  %-22s %4ss\n' total "$SECONDS"
  cat <<'EOF'

==> Check it works
  1. Open a new terminal (Ghostty if installed, else Terminal.app) so the shell picks up the key.
  2. Run: claude -p "Reply with the single word ok"
     A 401 means the key is wrong, 402 means credits or budget, 429 means rate limit.
  3. Run claude, then /model. Gateway models should be listed.
  4. Press ctrl+enter in Ghostty for a new window, shift+enter in claude for a newline.
  5. Run nvim and :checkhealth lazy.
  6. When macOS asks, allow paneru under Privacy & Security > Accessibility.
     Then option+arrows move between windows and option+1..0 switch workspaces.
  7. Reopen Chrome or Brave and click Enable on Bitwarden.
EOF
  if (( TOOLS )); then
    echo "  8. Run colima start once, then docker run hello-world."
    echo "  9. Run mise ls. bun, go, java, node, and python should be listed."
    echo " 10. For Google Drive, run rclone config create gdrive drive scope=drive and sign in."
  fi
  echo "When you leave, run teardown.sh from this folder."
}

step preflight preflight
step claude-code install_claude
step gateway-key gateway_key
step claude-settings claude_settings
if (( ! MINIMAL )); then
  step homebrew homebrew
  step brew-bundle brew_bundle
  step pstack pstack
  step configs configs
  step bitwarden bitwarden
  step git-identity git_identity
  step nvim-plugins nvim_plugins
  step window-manager window_manager
  if (( TOOLS )); then step tools tools; fi
fi
summary
