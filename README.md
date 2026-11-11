This repo sets up a fresh Mac with Claude Code on the Vercel AI Gateway, pstack, LazyVim, Ghostty, and the Paneru scrolling window manager. Paste `curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash` into Terminal.app. Add `-s -- --minimal` after `bash` to install only Claude Code, which needs no admin password. When you're done, `bash ~/mac-setup/teardown.sh` removes the key, the configs, Claude Code, and the Paneru service, and puts back any files it replaced.

Paneru uses Option where Hyprland uses Super, and Cmd where it uses Alt.

| Keys | Action |
| --- | --- |
| Option + arrows | Focus left or right, switch workspace up or down |
| Option + Ctrl + up or down | Focus the window above or below |
| Option + Shift + arrows | Swap left or right, move the window up or down a workspace |
| Option + 1 to 0 | Go to a workspace |
| Option + Shift + 1 to 0 | Move the window to a workspace |
| Option + T, Option + F | Float, full width |
| Option + minus or equal | Narrower, wider |

Allow Paneru under Privacy & Security > Accessibility when macOS asks. Keep an external monitor above or below the laptop, not beside it. `paneru stop` turns Paneru off.
