# MacBook setup

Sets up a fresh macOS account with Claude Code on the Vercel AI Gateway, pstack, LazyVim, Ghostty, and tmux. Steps run in order of value. If you stop early, Claude Code already works.

## Run it

Paste this into Terminal.app:

```bash
curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash
```

It downloads a tarball, so it needs no git and no GitHub login. It asks for three things:
- The gateway key, pasted into the macOS Keychain prompt, which may ask twice. It is never written to a file.
- RETURN and the account password for Homebrew.
- Your git name and email.

Short on time? This installs only Claude Code and the gateway settings, and needs no Homebrew and no admin password:

```bash
curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash -s -- --minimal
```

## Order

1. Claude Code (native installer, into `~/.local/bin`).
2. Gateway key into the Keychain. `~/.zshrc` exports `ANTHROPIC_AUTH_TOKEN` from it.
3. `~/.claude/settings.json` with the gateway URL, an empty `ANTHROPIC_API_KEY`, model discovery, opus at xhigh effort, and the statusline.
4. Homebrew, then the `Brewfile`.
5. pstack from the `cursor/plugins` marketplace.
6. Neovim, Ghostty, and tmux configs. Anything already there moves aside to `*.mac-setup-bak`.
7. git identity, then `Lazy! restore` to install Neovim plugins at the pinned versions.

The script prints how long each step took and a checklist to confirm it works.

## Terminal

Homebrew disabled its Alacritty cask on 2026-09-01 because the app fails the Gatekeeper check, so the Mac gets Ghostty set up to match `~/.config/alacritty/alacritty.toml` and the Felix theme it imports. Colors, JetBrainsMono Nerd Font with ligatures off, padding, block cursor, `TERM=xterm-256color`, and OSC 52 clipboard read and write all match. Ghostty 1.4.0 validates the file, and on the Linux laptop it reports the same 18 colors as Alacritty and draws the same 14px-wide cells. Differences from Alacritty:
- The font size is 12, not 9. Ghostty converts points at 72 dpi on macOS and 96 dpi elsewhere, so 12 on a 2x Mac screen is the same pixel size as 9 on the 2x Linux screen.
- The title bar is transparent instead of missing, so the window can still be dragged.
- shift+insert and ctrl+insert aren't carried over, since a MacBook has no Insert key.

## Keys that differ from Omarchy

- ctrl+enter in Ghostty opens a new window. It works only while Ghostty is focused, since a global hotkey needs a macOS permission.
- shift+enter sends a newline in Claude Code, like the Alacritty binding.
- Option acts as Alt, so the tmux `M-` and `C-M-` bindings work.
- The Neovim config drops the LaTeX, R, Jupyter, and Quarto plugins. They need system packages a fresh Mac doesn't have.

## Leaving

```bash
bash ~/mac-setup/teardown.sh
```

It removes the Keychain key, the shell blocks, the configs, Claude Code's state, and the git identity, and restores anything it moved aside. It only runs where `install.sh` ran. Sign out of GitHub in the browser yourself.

## Test

`bash test/stub-run.sh` runs the install twice and then teardown, in a throwaway home directory with stubbed macOS tools. It checks that the two runs end in the same state and that teardown restores the original files. It has not run on a real Mac.
