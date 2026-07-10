return {
  -- core: engine defaults -- doc editing, movement/selection, window/root nav, find & replace
  {
    ["ctrl+shift+p"] = "core:find-command",
    ["ctrl+p"] = "core:find-file",
    ["ctrl+o"] = "core:open-file",
    ["ctrl+n"] = "core:new-doc",
    ["alt+return"] = "core:toggle-fullscreen",

    ["alt+shift+j"] = "root:split-left",
    ["alt+shift+l"] = "root:split-right",
    ["alt+shift+i"] = "root:split-up",
    ["alt+shift+k"] = "root:split-down",
    ["alt+j"] = "root:switch-to-left",
    ["alt+l"] = "root:switch-to-right",
    ["alt+i"] = "root:switch-to-up",
    ["alt+k"] = "root:switch-to-down",

    ["ctrl+w"] = "root:close",
    ["ctrl+tab"] = "root:switch-to-next-tab",
    ["ctrl+shift+tab"] = "root:switch-to-previous-tab",
    ["ctrl+pageup"] = "root:move-tab-left",
    ["ctrl+pagedown"] = "root:move-tab-right",
    ["alt+1"] = "root:switch-to-tab-1",
    ["alt+2"] = "root:switch-to-tab-2",
    ["alt+3"] = "root:switch-to-tab-3",
    ["alt+4"] = "root:switch-to-tab-4",
    ["alt+5"] = "root:switch-to-tab-5",
    ["alt+6"] = "root:switch-to-tab-6",
    ["alt+7"] = "root:switch-to-tab-7",
    ["alt+8"] = "root:switch-to-tab-8",
    ["alt+9"] = "root:switch-to-tab-9",

    ["ctrl+f"] = "find-replace:find",
    ["ctrl+r"] = "find-replace:replace",
    ["f3"] = "find-replace:repeat-find",
    ["shift+f3"] = "find-replace:previous-find",
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
    ["ctrl+d"] = { "find-replace:select-next", "doc:select-word" },
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

  -- core: empty view (shown when no file is open)
  {
    ["ctrl+o"]       = "empty-view:open-file",
    ["ctrl+shift+o"] = "empty-view:open-folder",
  }
,

  -- core: log view
  {
    ["ctrl+c"] = "log:copy-selection",
    ["ctrl+a"] = "log:select-all",
  }
,

  -- plugins/tab: cycling, jump-to-tab, lifecycle, reorder
  {
    -- cycle
    ["ctrl+tab"]       = "tab:next",
    ["ctrl+shift+tab"] = "tab:prev",

    -- jump to tab N  (Ctrl+1 … Ctrl+9, VSCode-style)
    ["ctrl+1"] = "tab:go-1",
    ["ctrl+2"] = "tab:go-2",
    ["ctrl+3"] = "tab:go-3",
    ["ctrl+4"] = "tab:go-4",
    ["ctrl+5"] = "tab:go-5",
    ["ctrl+6"] = "tab:go-6",
    ["ctrl+7"] = "tab:go-7",
    ["ctrl+8"] = "tab:go-8",
    ["ctrl+9"] = "tab:go-9",

    -- lifecycle
    ["ctrl+t"]       = "tab:new",
    ["ctrl+shift+w"] = "tab:close",

    -- reorder
    ["ctrl+shift+pageup"]   = "tab:move-left",
    ["ctrl+shift+pagedown"] = "tab:move-right",
  }
,

  -- plugins/window: focus, split, close, resize
  {
    -- ── focus (Alt + hjkl, like VEX) ─────────────────────────────────────────
    ["alt+h"] = "window:focus-left",
    ["alt+j"] = "window:focus-down",
    ["alt+k"] = "window:focus-up",
    ["alt+l"] = "window:focus-right",
    ["alt+w"] = "window:focus-next",
    ["alt+p"] = "window:focus-prev-window",
    -- ── split ─────────────────────────────────────────────────────────────────
    ["ctrl+\\"]        = "window:vsplit",
    ["ctrl+shift+\\"]  = "window:split",

    -- ── close ─────────────────────────────────────────────────────────────────
    ["alt+c"] = "window:close",
    ["alt+o"] = "window:only",

    -- ── resize (Alt + arrow keys, like VEX) ───────────────────────────────────
    ["alt+right"] = "window:increase-width",
    ["alt+left"]  = "window:decrease-width",
    ["alt+up"]    = "window:increase-height",
    ["alt+down"]  = "window:decrease-height",
    ["alt+="]     = "window:equalize",
  }
,

  -- plugins/treeview: tree actions (toggle/focus/new-file)
  {
    ["f2"]            = {"treeview:toggle", "treeview:focus-and-refresh"},
    ["f3"]            = {"treeview:focus"},
    ["f4"]            = {"find-replace:repeat-find"},
    ["ctrl+\\"]       = "treeview:toggle",
    ["ctrl+shift+e"]  = "treeview:focus",
    ["ctrl+shift+n"]  = "treeview:new-file",
    ["ctrl+shift+alt+n"] = "treeview:new-directory",
  }
,

  -- plugins/treeview: list navigation (up/down/open/collapse/rename/delete/refresh)
  {
    ["up"]            = "treeview:select-previous",
    ["down"]          = "treeview:select-next",
    ["return"]        = "treeview:open-cursor-item",
    ["keypad enter"]  = "treeview:open-cursor-item",
    ["left"]          = "treeview:collapse-or-parent",
    ["right"]         = "treeview:expand-or-child",
    ["ctrl+r"]        = "treeview:rename-key",
    ["delete"]        = "treeview:delete-key",
    ["ctrl+shift+r"]  = "treeview:refresh-key",
  }
,

  -- plugins/core/autocomplete: popup navigation
  {
    ["tab"]    = "autocomplete:complete",
    ["up"]     = "autocomplete:previous",
    ["down"]   = "autocomplete:next",
    ["escape"] = "autocomplete:cancel",
  }
,

  -- plugins/core/session: recent files/dirs, save
  {
    ["ctrl+shift+r"] = "session:open-recent",
    ["ctrl+shift+d"] = "session:open-recent-dirs",
    ["ctrl+alt+s"]   = "session:save",
  }
,

  -- plugins/core/projectsearch: refresh, find, result navigation
  {
    ["f5"]           = "project-search:refresh",
    ["ctrl+shift+f"] = "project-search:find",
    ["up"]           = "project-search:select-previous",
    ["down"]         = "project-search:select-next",
    ["return"]       = "project-search:open-selected",
  }
,

}
