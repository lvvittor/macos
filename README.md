This repo sets up a fresh Mac with Claude Code on the Vercel AI Gateway, pstack, LazyVim, Ghostty, Brave with Bitwarden, and the Paneru scrolling window manager. Paste each command into Terminal.app.

Install everything:

```bash
curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash
```

Install everything plus dev tools (pnpm, just, mise with bun, node, python, and rust, TypeScript, deno, the Vercel CLI, rclone, and Docker through Colima):

```bash
curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash -s -- --tools
```

Install only Claude Code, with no admin password:

```bash
curl -fsSL https://raw.githubusercontent.com/lvvittor/macos/main/bootstrap.sh | bash -s -- --minimal
```

Start Docker once before using it:

```bash
colima start
```

Connect Google Drive:

```bash
rclone config create gdrive drive scope=drive
```

Remove everything, including SSH keys and logins made on this Mac, and put back the files it replaced:

```bash
bash ~/mac-setup/teardown.sh
```

Turn Paneru off:

```bash
paneru stop
```

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

Reopen Brave and click Enable on Bitwarden. Log out of Bitwarden before teardown, which removes it and its data. Allow Paneru under Privacy & Security > Accessibility when macOS asks. Keep an external monitor above or below the laptop, not beside it.
