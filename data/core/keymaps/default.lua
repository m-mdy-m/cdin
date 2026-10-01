return {
  -- core: engine defaults -- doc editing, movement/selection, window/root nav
  --
  -- Every binding here names a command this runtime registers. The
  -- user-facing workflows — the command palette, find file, open file, open
  -- folder — are not here: they are optional plugins that own their own
  -- keystrokes, so an editor with no extensions has no dead keys, and an
  -- editor with them gets ctrl+shift+p, ctrl+p and ctrl+o from the plugin
  -- that implements them.
  {
    ["ctrl+n"] = "core:new-doc",
    ["alt+return"] = "core:toggle-fullscreen",
    ["ctrl+shift+l"] = "core:open-log",

    ["alt+shift+j"] = "root:split-left",
    ["alt+shift+l"] = "root:split-right",
    ["alt+shift+i"] = "root:split-up",
    ["alt+shift+k"] = "root:split-down",
    ["alt+j"] = "root:switch-to-left",
    ["alt+l"] = "root:switch-to-right",
    ["alt+i"] = "root:switch-to-up",
    ["alt+k"] = "root:switch-to-down",

    ["ctrl+w"] = "root:close",
    ["ctrl+pageup"] = "root:move-pane-view-left",
    ["ctrl+pagedown"] = "root:move-pane-view-right",
    ["alt+1"] = "root:switch-to-pane-view-1",
    ["alt+2"] = "root:switch-to-pane-view-2",
    ["alt+3"] = "root:switch-to-pane-view-3",
    ["alt+4"] = "root:switch-to-pane-view-4",
    ["alt+5"] = "root:switch-to-pane-view-5",
    ["alt+6"] = "root:switch-to-pane-view-6",
    ["alt+7"] = "root:switch-to-pane-view-7",
    ["alt+8"] = "root:switch-to-pane-view-8",
    ["alt+9"] = "root:switch-to-pane-view-9",

    ["ctrl+g"] = "doc:go-to-line",
    ["ctrl+s"] = "doc:save",
    ["ctrl+shift+s"] = "doc:save-as",

    ["ctrl+z"] = "doc:undo",
    ["ctrl+y"] = "doc:redo",
    ["ctrl+x"] = "doc:cut",
    ["ctrl+c"] = "doc:copy",
    ["ctrl+v"] = "doc:paste",
    ["escape"] = { "command:escape", "doc:select-none" },
    ["tab"] = { "command:complete", "doc:indent" },
    ["shift+tab"] = "doc:unindent",
    ["backspace"] = "doc:backspace",
    ["shift+backspace"] = "doc:backspace",
    ["ctrl+backspace"] = "doc:delete-to-previous-word-start",
    ["ctrl+shift+backspace"] = "doc:delete-to-previous-word-start",
    ["delete"] = "doc:delete",
    ["shift+delete"] = "doc:delete",
    ["ctrl+delete"] = "doc:delete-to-next-word-end",
    ["ctrl+shift+delete"] = "doc:delete-to-next-word-end",
    ["return"] = { "command:submit", "doc:newline" },
    ["keypad enter"] = { "command:submit", "doc:newline" },
    ["ctrl+return"] = "doc:newline-below",
    ["ctrl+shift+return"] = "doc:newline-above",
    ["ctrl+j"] = "doc:join-lines",
    ["ctrl+a"] = "doc:select-all",
    -- find-replace plugin prepends "find-replace:select-next" to this
    -- stroke via keymap.add() at load time; see data/plugins/findreplace/init.lua.
    ["ctrl+d"] = "doc:select-word",
    ["ctrl+l"] = "doc:select-lines",
    ["ctrl+/"] = "doc:toggle-line-comments",
    ["ctrl+up"] = "doc:move-lines-up",
    ["ctrl+down"] = "doc:move-lines-down",
    ["ctrl+shift+d"] = "doc:duplicate-lines",
    ["ctrl+shift+k"] = "doc:delete-lines",

    ["left"] = "doc:move-to-previous-char",
    ["right"] = "doc:move-to-next-char",
    ["up"] = { "command:select-previous", "doc:move-to-previous-line" },
    ["down"] = { "command:select-next", "doc:move-to-next-line" },
    ["ctrl+left"] = "doc:move-to-previous-word-start",
    ["ctrl+right"] = "doc:move-to-next-word-end",
    ["ctrl+["] = "doc:move-to-previous-block-start",
    ["ctrl+]"] = "doc:move-to-next-block-end",
    ["home"] = "doc:move-to-start-of-line",
    ["end"] = "doc:move-to-end-of-line",
    ["ctrl+home"] = "doc:move-to-start-of-doc",
    ["ctrl+end"] = "doc:move-to-end-of-doc",
    ["pageup"] = "doc:move-to-previous-page",
    ["pagedown"] = "doc:move-to-next-page",

    ["shift+left"] = "doc:select-to-previous-char",
    ["shift+right"] = "doc:select-to-next-char",
    ["shift+up"] = "doc:select-to-previous-line",
    ["shift+down"] = "doc:select-to-next-line",
    ["ctrl+shift+left"] = "doc:select-to-previous-word-start",
    ["ctrl+shift+right"] = "doc:select-to-next-word-end",
    ["ctrl+shift+["] = "doc:select-to-previous-block-start",
    ["ctrl+shift+]"] = "doc:select-to-next-block-end",
    ["shift+home"] = "doc:select-to-start-of-line",
    ["shift+end"] = "doc:select-to-end-of-line",
    ["ctrl+shift+home"] = "doc:select-to-start-of-doc",
    ["ctrl+shift+end"] = "doc:select-to-end-of-doc",
    ["shift+pageup"] = "doc:select-to-previous-page",
    ["shift+pagedown"] = "doc:select-to-next-page",
  }

,

  -- core: log view
  {
    ["ctrl+c"] = "log:copy-selection",
    ["ctrl+a"] = "log:select-all",
    -- Two streams, one key each: the editor's own log_items, and the C
    -- logger's file, which is where boot failures live.
    ["ctrl+s+l"]      = "log:switch-source",
    ["ctrl+r"]  = "log:reload",
  }
,
}