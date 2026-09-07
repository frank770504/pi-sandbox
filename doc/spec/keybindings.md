# Spec — Keybindings

Source: `~/.pi/agent/keybindings.json`

```json
{
    "tui.editor.cursorUp": ["up", "alt+k"],
    "tui.editor.cursorDown": ["down", "alt+j"],
    "tui.editor.cursorLeft": ["left", "alt+h"],
    "tui.editor.cursorRight": ["right", "alt+l"],
    "tui.input.newLine": ["alt+enter", "ctrl+j"]
}
```

| Binding | Keys | Intent |
|---|---|---|
| `tui.editor.cursorUp` | `up`, `alt+k` | Vim-style up in editor |
| `tui.editor.cursorDown` | `down`, `alt+j` | Vim-style down |
| `tui.editor.cursorLeft` | `left`, `alt+h` | Vim-style left |
| `tui.editor.cursorRight` | `right`, `alt+l` | Vim-style right |
| `tui.input.newLine` | `alt+enter`, `ctrl+j` | Insert newline in input |

Rationale: keep hands on home row for editor navigation (hjkl via alt), and add
an explicit newline binding since `enter` submits.
