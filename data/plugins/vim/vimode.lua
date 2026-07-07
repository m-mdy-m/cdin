local core        = require "core"
local config      = require "core.config"
local command     = require "core.input.command"
local keymap      = require "core.input.keymap"
local DocView     = require "core.views.docview"
local CommandView = require "core.views.commandview"
local ex          = require "plugins.vim.ex"

require "plugins.vim.fmenu"

if config.vim_mode_enabled == nil then
  config.vim_mode_enabled = true
end


config.vim_ex_history_max = 100

local MODE_NORMAL = "normal"
local MODE_INSERT = "insert"
local MODE_VISUAL = "visual"

local PENDING_TIMEOUT = 0.6   

local pending     = nil
local count_buf   = ""
local history_pos = nil

local function active_docview()
  local v = core.active_view
  if v and v:is(DocView) and not v:is(CommandView) then return v end
  return nil
end

local function get_mode(view)
  return view.vim_mode or MODE_NORMAL
end

local function set_mode(view, mode)
  view.vim_mode = mode
  core.redraw = true
end
local MOTIONS = {
  h = { "doc:move-to-previous-char",       "doc:select-to-previous-char"       },
  l = { "doc:move-to-next-char",           "doc:select-to-next-char"           },
  j = { "doc:move-to-next-line",           "doc:select-to-next-line"           },
  k = { "doc:move-to-previous-line",       "doc:select-to-previous-line"       },
  w = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end"       },
  b = { "doc:move-to-previous-word-start", "doc:select-to-previous-word-start" },
  e = { "doc:move-to-next-word-end",       "doc:select-to-next-word-end"       },
}


local function ex_suggest(text)
  
  local bare = text:sub(1,1) == ":" and text:sub(2) or text
  return ex.suggest(bare)
end

local function open_ex_commandline()
  history_pos = nil   

  core.command_view:enter(
    "",                  
    function(text)
      
      ex.submit(text)
    end,
    ex_suggest,
    function()           
      history_pos = nil
    end
  )
  
  core.command_view:set_text(":")
end

local function ex_history_prev()
  if core.active_view ~= core.command_view then return false end
  local hist = ex.history
  if #hist == 0 then return true end
  if not history_pos then
    history_pos = #hist
  else
    history_pos = math.max(1, history_pos - 1)
  end
  core.command_view:set_text(":" .. hist[history_pos])
  return true
end

local function ex_history_next()
  if core.active_view ~= core.command_view then return false end
  local hist = ex.history
  if not history_pos then return true end
  history_pos = history_pos + 1
  if history_pos > #hist then
    history_pos = nil
    core.command_view:set_text(":")
  else
    core.command_view:set_text(":" .. hist[history_pos])
  end
  return true
end


local function handle_key(k)
  if not config.vim_mode_enabled then return false end

  if core.active_view == core.command_view then
    if k == "up"   and keymap.modkeys.ctrl then return ex_history_prev() end
    if k == "down" and keymap.modkeys.ctrl then return ex_history_next() end
    return false
  end

  if k:find("ctrl") or k:find("alt") then return false end
  if keymap.modkeys.ctrl or keymap.modkeys.alt or keymap.modkeys.altgr then
    return false
  end

  local shift = keymap.modkeys.shift

  if shift and k == ";" or k == "escape" then
    open_ex_commandline()
    return true
  end
  if k == "m" then
    command.perform("vim-fmenu:open")
    return true
  end
  local view = active_docview()

  if k == "escape" then
    if view then
      local mode = get_mode(view)
      if mode == MODE_INSERT then
        set_mode(view, MODE_NORMAL)
        command.perform("doc:move-to-previous-char")
      elseif mode == MODE_VISUAL then
        set_mode(view, MODE_NORMAL)
        command.perform("doc:select-none")
      else
        command.perform("doc:select-none")
      end
      pending  = nil
      count_buf = ""
      return true  
    end
    return false
  end

  if not view then return false end

  local mode = get_mode(view)

  if mode == MODE_INSERT then
    return false
  end

  if mode == MODE_VISUAL and not shift then
    if k == "d" or k == "x" then
      command.perform("doc:cut")
      set_mode(view, MODE_NORMAL)
      return true
    elseif k == "y" then
      command.perform("doc:copy")
      command.perform("doc:select-none")
      set_mode(view, MODE_NORMAL)
      return true
    elseif k == ">" then
      command.perform("doc:indent")
      return true
    elseif k == "<" then
      command.perform("doc:unindent")
      return true
    end
  end

  -- digit prefix for Ngt
  if mode == MODE_NORMAL and not shift and k:match("^%d$") then
    if k ~= "0" or count_buf ~= "" then
      count_buf = count_buf .. k
      return true
    end
  end

  -- Ctrl+w prefix handler
  if k == "ctrl+w" then
    pending   = { key = "ctrl_w", t = system.get_time() }
    count_buf = ""
    return true
  end
  if pending and pending.key == "ctrl_w" then
    pending   = nil
    count_buf = ""
    local wmap = {
      h="window:focus-left", j="window:focus-down",
      k="window:focus-up",   l="window:focus-right",
      w="window:focus-next", p="window:focus-prev-window",
      t="window:focus-first",b="window:focus-last",
      s="window:split",      v="window:vsplit",
      c="window:close",      o="window:only",
      n="window:new",
    }
    local wmap_shift = {
      W="window:focus-prev",
    }
    local wmap_sym = {
      ["+"]=  "window:increase-height",
      ["-"]=  "window:decrease-height",
      [">"]=  "window:increase-width",
      ["<"]=  "window:decrease-width",
      ["="]=  "window:equalize",
    }
    local wcmd = wmap[k] or wmap_shift[k] or wmap_sym[k]
    if wcmd then command.perform(wcmd) end
    return true
  end

  -- gt / gT / Ngt  (resolved when second key after "g" is t or T)
  if mode == MODE_NORMAL and pending and pending.key == "g" then
    if k == "t" and not shift then
      pending = nil
      local ok, tabM = pcall(require, "plugins.tab.manager")
      if ok then
        local n = tonumber(count_buf)
        count_buf = ""
        if n then tabM.go_to(n) else tabM.next() end
      end
      return true
    elseif k == "t" and shift then
      pending   = nil
      count_buf = ""
      local ok, tabM = pcall(require, "plugins.tab.manager")
      if ok then tabM.prev() end
      return true
    end
  end

  if mode == MODE_NORMAL and not shift
     and (k == "g" or k == "d" or k == "y" or k == "c") then
    if pending and pending.key == k
    and system.get_time() - pending.t < PENDING_TIMEOUT then
      pending = nil
      if k == "g" then
        command.perform("doc:move-to-start-of-doc")
      elseif k == "d" then
        command.perform("doc:delete-lines")
      elseif k == "y" then
        command.perform("doc:select-lines")
        command.perform("doc:copy")
        command.perform("doc:select-none")
      elseif k == "c" then
        command.perform("doc:delete-lines")
        set_mode(view, MODE_INSERT)
      end
    else
      pending = { key = k, t = system.get_time() }
    end
    return true
  end

  if pending and pending.key ~= k and pending.key ~= "ctrl_w" then
    pending = nil
    count_buf = ""
  end

  if shift then
    if     k == "g" then command.perform("doc:move-to-end-of-doc")
    elseif k == "i" then
      command.perform("doc:move-to-start-of-line")
      set_mode(view, MODE_INSERT)
    elseif k == "a" then
      command.perform("doc:move-to-end-of-line")
      set_mode(view, MODE_INSERT)
    elseif k == "o" then
      command.perform("doc:move-to-start-of-line")
      command.perform("doc:newline-above")
      set_mode(view, MODE_INSERT)
    elseif k == "n" then command.perform("find-replace:previous-find")
    elseif k == "4" then command.perform("doc:move-to-end-of-line") 
    elseif k == "6" then command.perform("doc:move-to-start-of-line") 
    elseif k == "d" then
      -- D: delete to end of line
      command.perform("doc:select-to-end-of-line")
      command.perform("doc:cut")
    elseif k == "j" then
      -- J: join next line
      command.perform("doc:move-to-end-of-line")
      command.perform("doc:delete")
    end
    return true
  end

  if MOTIONS[k] then
    command.perform(mode == MODE_VISUAL and MOTIONS[k][2] or MOTIONS[k][1])
    return true
  end

  if k == "v" then
    if mode == MODE_VISUAL then
      command.perform("doc:select-none")
      set_mode(view, MODE_NORMAL)
    else
      set_mode(view, MODE_VISUAL)
    end
    return true
  end

  if k == "i" then set_mode(view, MODE_INSERT); return true end

  if k == "a" then
    command.perform("doc:move-to-next-char")
    set_mode(view, MODE_INSERT)
    return true
  end

  if k == "o" then
    command.perform("doc:move-to-end-of-line")
    command.perform("doc:newline")
    set_mode(view, MODE_INSERT)
    return true
  end

  if k == "0" then command.perform("doc:move-to-start-of-line"); return true end

  if k == "x" then
    command.perform("doc:select-to-next-char")
    command.perform("doc:cut")
    return true
  end

  if k == "p" then
    command.perform("doc:paste")
    return true
  end

  if k == "u" then command.perform("doc:undo"); return true end
  if k == "r" then
    command.perform("doc:redo")
    return true
  end

  if k == "/" then command.perform("find-replace:find");        return true end
  if k == "n" then command.perform("find-replace:repeat-find"); return true end
  if k == "*" then
    local doc = view.doc
    local line, col = doc:get_selection()
    local word = doc:get_text(line, col, line, math.huge)
    word = word:match("^([%w_]+)") or ""
    if word ~= "" then
      command.perform("find-replace:find")
    end
    return true
  end

  if k == "m" then
    command.perform("vim-fmenu:open")
    return true
  end
  if k == "tab" then
    command.perform("root:switch-to-next-tab")
    return true
  end
  if #k == 1 then return true end

  return false
end


local original_on_key_pressed = keymap.on_key_pressed

function keymap.on_key_pressed(k)
  local ok, handled = core.try(handle_key, k)
  if ok and handled then
    if system.suppress_next_textinput then
      system.suppress_next_textinput()
    end
    return true
  end
  return original_on_key_pressed(k)
end

function core.get_vim_mode_label()
  if not config.vim_mode_enabled then return nil end
  local v = core.active_view
  if v and v:is(DocView) and not v:is(CommandView) then
    local mode = get_mode(v)
    if     mode == MODE_INSERT then return "[INSERT]"
    elseif mode == MODE_VISUAL then return "[VISUAL]"
    else                            return "[NORMAL]"
    end
  end
  return nil
end