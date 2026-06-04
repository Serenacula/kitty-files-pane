# kitty-files-pane

A zsh script that adds a live-updating file browser pane to [Kitty](https://sw.kovidgoyal.net/kitty/).

Must be sourced from `.zshrc` — it cannot run standalone.

## Usage

```
files [--open] [--close] [--watch <window-id>] [--level <n>] [--size <1-100>]
```

Running `files` with no arguments toggles the pane open/closed. The pane opens in Kitty's `tall` layout and tracks the CWD of the calling window in real time, polling every 0.2s and redrawing when the directory contents change.

| Flag | Description |
|------|-------------|
| `--open` | Open the pane (no-op if already open) |
| `--close` | Close the pane |
| `--watch <id>` | Watch a different Kitty window ID instead of the current one |
| `--level <n>` | Tree depth (default: 1) |
| `--size <1-100>` | Pane width as a percentage (default: 20) |

Uses `eza` for display if available, falling back to `tree`, then `find`.
