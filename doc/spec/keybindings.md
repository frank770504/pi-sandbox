# Spec — Keybindings

Canonical source: [`config/pi/keybindings.json`](../../config/pi/keybindings.json), installed to `~/.pi/agent/keybindings.json`.

```json
{
  "$schema": "https://pi.dev/schemas/keybindings.schema.json",
  "tui.editor.cursorUp": ["up", "ctrl+alt+k"],
  "tui.editor.cursorDown": ["down", "ctrl+alt+j"],
  "tui.editor.cursorLeft": ["left", "ctrl+alt+h"],
  "tui.editor.cursorRight": ["right", "ctrl+alt+l"],
  "tui.input.newLine": ["alt+enter", "ctrl+j"],

  "tui.altScreen.lineUp": "alt+k",
  "tui.altScreen.lineDown": "alt+j",
  "tui.altScreen.halfPageUp": "alt+u",
  "tui.altScreen.halfPageDown": "alt+e",
  "tui.altScreen.top": ["ctrl+home", "alt+g"],
  "tui.altScreen.bottom": "ctrl+end"
}
```

| Binding | Keys | Intent |
|---|---|---|
| `tui.editor.cursorUp` | `up`, `ctrl+alt+k` | Vim-style up in editor |
| `tui.editor.cursorDown` | `down`, `ctrl+alt+j` | Vim-style down |
| `tui.editor.cursorLeft` | `left`, `ctrl+alt+h` | Vim-style left |
| `tui.editor.cursorRight` | `right`, `ctrl+alt+l` | Vim-style right |
| `tui.input.newLine` | `alt+enter`, `ctrl+j` | Insert newline in input |
| `tui.altScreen.lineUp` | `alt+k` | Scroll transcript up one line |
| `tui.altScreen.lineDown` | `alt+j` | Scroll transcript down one line |
| `tui.altScreen.halfPageUp` | `alt+u` | Scroll transcript up half a page |
| `tui.altScreen.halfPageDown` | `alt+e` | Scroll transcript down half a page |
| `tui.altScreen.top` | `ctrl+home`, `alt+g` | Jump to the top of the transcript |
| `tui.altScreen.bottom` | `ctrl+end` | Jump to the bottom of the transcript |

Rationale: keep the editor on the home row with `ctrl+alt` + `hjkl`, but
separate the transcript so scrolling never steals editor keys. Transcript
scrolling uses bare `alt` + `j`/`k` (line), `e`/`u` (half page), and `g`
(top), with `PgUp`/`PgDn` and `ctrl+Home`/`ctrl+End` retained for paging.
`ctrl+alt+d` and `ctrl+alt+end` are deliberately unused because they collide
with system bindings, and `alt+b`/`alt+f` stay free for the editor's word
motions.
