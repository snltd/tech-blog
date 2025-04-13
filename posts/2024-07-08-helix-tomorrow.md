---
title: "Helix Tomorrow Theme"
date: 2024-07-08
tags: [Helix]
category: articles
---

I started out on straight `vi`. Once, with a proper Space Cadet keyboard, I
flirted with Emacs, then finally saw sense and settled down with vim.

Every now and again I have a play with one of these fancy IDEs that they they
have now. But for me, IDE will always be a disk interface, and I didn't even
like that.

I thought I'd never change, but now I'm fully
[Helix](https://helix-editor.com/). I love its design, from the "select first,
act later" way it thinks, to the "LSP and tree-sitter" approach it has to any
and every language. I can't recommend it highly enough.

Nothing's perfect though, and nearly all the bundled Helix themes are dark. I
don't care for dark themes, or dark modes, or dark beer, or the dark web, or any
of that stuff. I want black(ish) ink on a white(ish) background like we had in
Ye Olde Dayes. I'm bored of Solarized Light now, and fully committed to
[Tomorrow](https://github.com/chriskempson/tomorrow-theme). So, I made a
Tomorrow theme for Helix. Here it is. Stick it in your\
`${HOME}/.config/helix/themes/` and you're done.

```toml
# Syntax highlighting
"type" = "blue"
"type.builtin" = "blue"
"constructor" = "orange"
"constant" = "orange"
"string" = "green"
"string.regexp" = "red"
"string.special" = "yellow"
"comment" = { fg = "dark_gray", modifiers = ["italic"] }
"variable" = "foreground"
"label" = "orange"
"punctuation" = "foreground"
"keyword" = "magenta"
"operator" = "orange"
"function" = "yellow"
"function.builtin" = "blue"
"tag" = "blue"
"namespace" = "blue"
"markup.heading" = "orange"
"markup.list" = "yellow"
"markup.bold" = { fg = "orange", modifiers = ["bold"] }
"markup.italic" = { fg = "orange", modifiers = ["italic"] }
"markup.strikethrough" = { modifiers = ["crossed_out"] }
"markup.raw.block" = "orange"
"markup.link.url" = { fg = "blue", modifiers = ["underlined"] }
"markup.link.text" = "yellow"
"markup.link.label" = "green"
"markup.quote" = "yellow"
"diff.plus" =  "green"
"diff.minus" = "red"
"diff.delta" = "yellow"
# My Ruby Things
"string.special.symbol" = "green"
"function.method" = "blue"
"variable.other.member" = "red"
"variable.parameter" = "orange"
"toml.variable.other.member" = "black"

# Interface
"ui.background"= { bg = "background" }
"ui.cursor" = { fg = "white", bg = "yellow" }
"ui.cursor.primary" = { fg = "white", bg = "orange" }
"ui.cursor.match" = "orange"
"ui.linenr" = "dark_gray"
"ui.linenr.selected" = "gray"
"ui.statusline" = { fg = "foreground", bg = "gray" }
"ui.statusline.normal" = { fg = "black", bg = "blue" }
"ui.statusline.insert" = { fg = "black", bg = "orange" }
"ui.statusline.select" = { fg = "black", bg = "magenta" }
"ui.cursorline" = { bg = "gray" }
"ui.popup" = { fg = "#7B91b3", bg = "gray" }
"ui.window" = "gray"
"ui.help" = { fg = "#7B91b3", bg = "gray" }
"ui.text" = "foreground"
"ui.text.focus" = { bg = "dark_gray", fg = "foreground" }
"ui.text.info" = "foreground"
"ui.virtual.whitespace" = "gray"
"ui.virtual.ruler" = { bg = "gray" }
"ui.virtual.inlay-hint" = { fg = "#c0c0c0", bg = "background" }  # bg original #ffaa3333
"ui.menu" = { fg = "dark_gray", bg = "light_gray" }
"ui.menu.selected" = { bg = "gray", fg = "black" }
"ui.selection" = { bg = "gray", fg = "black" }
"warning" = { fg = "black", modifiers = ["italic"] }
"error" = { fg = "red", modifiers = ["italic"] }
"info" = { fg = "gray", modifiers = ["italic"] }
"hint" = { fg = "blue", modifiers = ["italic"] }
"diagnostic.hint"= { underline = { color = "blue", style = "curl" } }
"diagnostic.info"= { underline = { color = "blue", style = "curl" } }
"diagnostic.warning"= { underline = { color = "yellow", style = "curl" } }
"diagnostic.error"= { underline = { color = "red", style = "curl" } }
"ui.bufferline" = { fg = "gray", bg = "background" }
"ui.bufferline.active" = { fg = "foreground", bg = "dark_gray" }
"ui.debug" = { fg = "orange"  }
"ui.highlight.frameline" = { bg = "#cfe0f2" }

"special" = "orange"

[palette]
background = "#fafafa"
foreground = "#4d4d4c"

black = "#000000"
white = "#efefef"
blue = "#4271ae"
light_blue = "#5795e6"
cyan = "#3e999f"
dark_gray = "#8e908c"
gray = "#d6d6d6"
green = "#718c00"
magenta = "#8959a8"
orange = "#f5871f"
red = "#c82829"
yellow = "#eab700"
light_gray = "#f0f0f0"
```
