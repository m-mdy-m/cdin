local core    = require "core"
local command = require "core.input.command"
local config  = require "core.config"
local keymap  = require "core.input.keymap"
local fs      = require "core.fs"
local common  = require "core.utils.common"
local style   = require "core.style"

local M = {}

-- ── Path helpers ──────────────────────────────────────────────────

local function path_join(a, b)
  return a .. "/" .. b
end

local function path_dir(p)
  return p:match("^(.-)[/\\][^\\/]+$") or "."
end

local function path_basename(p)
  return p:match("[^/\\]+$") or p
end

-- ── Plugin discovery ──────────────────────────────────────────────
-- Each plugin is a .lua file directly in a category directory.
-- Structure: data/plugins/<category>/<name>.lua
-- User plugins go in: data/plugins/local/<name>.lua
-- Module name: plugins.<category>.<name>

local CATEGORIES = { "core", "languages", "vim", "window", "treeview", "tab", "optional", "local" }

local function get_builtin_plugins()
  local plugins = {}
  local base = EXEDIR .. "/data/plugins"

  for _, cat in ipairs(CATEGORIES) do
    if cat ~= "local" then
      local cat_dir = path_join(base, cat)
      local entries = system.list_dir(cat_dir) or {}
      for _, name in ipairs(entries) do
        if name:match("%.lua$") then
          local plugin_name = name:gsub("%.lua$", "")
          local modname = "plugins." .. cat .. "." .. plugin_name
          plugins[modname] = {
            modname     = modname,
            name        = plugin_name,
            category    = cat,
            source      = "builtin",
            file_path   = path_join(cat_dir, name),
            short_name  = plugin_name,
          }
        end
      end
    end
  end

  return plugins
end

local function get_local_plugins()
  local plugins = {}
  local local_dir = config.plugin_install_path
  if not local_dir or not fs.exists(local_dir) then return plugins end

  local entries = system.list_dir(local_dir) or {}
  for _, name in ipairs(entries) do
    if name:match("%.lua$") then
      local plugin_name = name:gsub("%.lua$", "")
      local modname = "plugins.local." .. plugin_name
      plugins[modname] = {
        modname     = modname,
        name        = plugin_name,
        category    = "local",
        source      = "local",
        file_path   = path_join(local_dir, name),
        short_name  = plugin_name,
      }
    end
  end

  -- Also check for subdirectories (git-style installed plugins)
  local sub_entries = system.list_dir(local_dir) or {}
  for _, name in ipairs(sub_entries) do
    local full = path_join(local_dir, name)
    local info = system.get_file_info(full)
    if info and info.type == "dir" then
      local modname = "plugins.local." .. name
      plugins[modname] = {
        modname     = modname,
        name        = name,
        category    = "local",
        source      = "local",
        file_path   = full,
        short_name  = name,
        is_dir      = true,
      }
    end
  end

  return plugins
end

local function get_all_plugins()
  local all = {}
  for k, v in pairs(get_builtin_plugins()) do all[k] = v end
  for k, v in pairs(get_local_plugins()) do all[k] = v end
  return all
end

-- ── Status helpers ────────────────────────────────────────────────

local function is_essential(short_name)
  for _, e in ipairs(config.essential_plugins) do
    if e == short_name then return true end
  end
  return false
end

local function is_optional_plugin(short_name)
  return config.optional_plugins[short_name] ~= nil
end

local function get_plugin_status(plugin)
  local short = plugin.short_name
  local modname = plugin.modname

  if is_essential(short) then
    return "essential"
  end

  if plugin.source == "local" then
    -- User-installed plugin: always considered installed
    -- Check if enabled via config.plugins
    if config.plugins and config.plugins[modname] == false then
      return "disabled"
    elseif is_optional_plugin(short) and config.optional_plugins[short] == false then
      return "disabled"
    else
      return "enabled"
    end
  end

  -- Built-in plugin
  if is_optional_plugin(short) then
    if config.optional_plugins[short] == false then
      return "disabled"
    else
      return "enabled"
    end
  end

  -- Default: enabled by default
  if config.plugins and config.plugins[modname] == false then
    return "disabled"
  elseif config.plugins_enabled_by_default ~= false then
    return "enabled"
  end

  return "enabled"
end

-- ── Install / Uninstall / Toggle ──────────────────────────────────

local function install_plugin(short_name)
  local local_dir = config.plugin_install_path
  if not local_dir then
    core.error("plugin-manager: no plugin_install_path configured")
    return false
  end

  -- Find the plugin in builtin locations
  local src_path = nil
  for _, cat in ipairs(CATEGORIES) do
    if cat ~= "local" then
      local candidate = path_join(EXEDIR .. "/data/plugins/" .. cat, short_name .. ".lua")
      if fs.exists(candidate) then
        src_path = candidate
        break
      end
    end
  end

  if not src_path then
    core.error("plugin-manager: could not find builtin plugin '%s'", short_name)
    return false
  end

  fs.mkdir_all(local_dir)
  local dest_path = path_join(local_dir, short_name .. ".lua")
  local ok, err = fs.copy_all(src_path, dest_path)
  if ok then
    if not config.plugins then config.plugins = {} end
    config.plugins["plugins.local." .. short_name] = true
    core.log("plugin-manager: installed %s -> %s", short_name, dest_path)
    return true
  else
    core.error("plugin-manager: copy failed: %s", err)
    return false
  end
end

local function uninstall_plugin(short_name)
  local local_dir = config.plugin_install_path
  if not local_dir then return false end

  local dest_path = path_join(local_dir, short_name .. ".lua")
  if fs.exists(dest_path) then
    local ok = os.remove(dest_path)
    if ok then
      if config.plugins then config.plugins["plugins.local." .. short_name] = nil end
      core.log("plugin-manager: uninstalled %s", short_name)
      return true
    end
  end

  -- Also check for directory-style install
  local dir_path = path_join(local_dir, short_name)
  local info = system.get_file_info(dir_path)
  if info and info.type == "dir" then
    local ok, err = fs.remove_all(dir_path)
    if ok then
      if config.plugins then config.plugins["plugins.local." .. short_name] = nil end
      core.log("plugin-manager: uninstalled %s (directory)", short_name)
      return true
    end
  end

  core.error("plugin-manager: %s is not installed locally", short_name)
  return false
end

local function toggle_plugin(modname, short_name, enable)
  if is_essential(short_name) then
    core.log("plugin-manager: %s is essential, cannot toggle", short_name)
    return false
  end

  if is_optional_plugin(short_name) then
    config.optional_plugins[short_name] = enable
  else
    if not config.plugins then config.plugins = {} end
    config.plugins[modname] = enable
  end
  core.log("plugin-manager: %s %s", short_name, enable and "enabled" or "disabled")
  return true
end

-- ── Menu building ─────────────────────────────────────────────────

local function build_menu_items()
  local plugins = get_all_plugins()
  local items = {}

  -- Group by category
  local by_category = {}
  for modname, plugin in pairs(plugins) do
    local cat = plugin.category
    if not by_category[cat] then by_category[cat] = {} end
    table.insert(by_category[cat], plugin)
  end

  -- Sort categories
  local sorted_cats = {}
  for cat in pairs(by_category) do sorted_cats[#sorted_cats + 1] = cat end
  table.sort(sorted_cats)

  for _, cat in ipairs(sorted_cats) do
    local cat_plugins = by_category[cat]
    table.sort(cat_plugins, function(a, b) return a.name < b.name end)

    -- Category header
    items[#items + 1] = {
      text = "── " .. cat:upper() .. " ──",
      info = "",
      _is_header = true,
    }

    for _, plugin in ipairs(cat_plugins) do
      local status = get_plugin_status(plugin)
      local short = plugin.short_name

      local status_char
      if status == "essential" then
        status_char = "x"
      elseif status == "enabled" then
        status_char = "x"
      elseif status == "disabled" then
        status_char = "-"
      else
        status_char = " "
      end

      local info_parts = { plugin.source }
      if status == "essential" then table.insert(info_parts, "essential") end
      if status == "disabled" then table.insert(info_parts, "disabled") end
      if status == "not_installed" then table.insert(info_parts, "not installed") end

      items[#items + 1] = {
        text = string.format("[%s] %s", status_char, short),
        info = table.concat(info_parts, ", "),
        _modname   = plugin.modname,
        _short     = short,
        _status    = status,
        _category  = plugin.category,
        _source    = plugin.source,
        _installed = plugin.source == "local",
      }
    end
  end

  return items
end

-- ── Menu actions ──────────────────────────────────────────────────

local function open_menu()
  local items = build_menu_items()

  local function submit(text, item)
    if not item or item._is_header then return end
    local short = item._short
    local modname = item._modname
    local status = item._status

    if status == "essential" then
      core.log("plugin-manager: %s is essential", short)
      return
    end

    if status == "enabled" then
      -- Toggle off
      toggle_plugin(modname, short, false)
      core.log("plugin-manager: %s disabled", short)
    elseif status == "disabled" then
      -- Toggle on
      toggle_plugin(modname, short, true)
      core.log("plugin-manager: %s enabled", short)
    elseif not item._installed then
      -- Install
      install_plugin(short)
      core.log("plugin-manager: installed %s", short)
    end
  end

  local function suggest(text)
    local t = text:match("^%s*(.-)%s*$") or ""
    if t == "" then return items end
    local lo = t:lower()
    local res = {}
    for _, item in ipairs(items) do
      if item._is_header then
        res[#res + 1] = item
      elseif item.text:lower():find(lo, 1, true) then
        res[#res + 1] = item
      end
    end
    return res
  end

  local label = "Plugin Manager  [x=active  -=disabled]  (key/up-down/tab)"

  core.command_view:enter(
    label,
    submit,
    suggest
  )
end

-- ── Command definitions ───────────────────────────────────────────

command.add(nil, {
  ["plugin-manager:open"] = function()
    open_menu()
  end,

  ["plugin-manager:install"] = function(name)
    if not name or name == "" then
      core.command_view:enter("Install Plugin", function(text)
        text = text:match("^%s*(.-)%s*$") or ""
        if text == "" then return end
        if install_plugin(text) then
          core.log("plugin-manager: installed %s", text)
        end
      end, function() return {} end)
    else
      install_plugin(name)
    end
  end,

  ["plugin-manager:uninstall"] = function(name)
    if not name or name == "" then
      core.command_view:enter("Uninstall Plugin", function(text)
        text = text:match("^%s*(.-)%s*$") or ""
        if text == "" then return end
        if uninstall_plugin(text) then
          core.log("plugin-manager: uninstalled %s", text)
        end
      end, function() return {} end)
    else
      uninstall_plugin(name)
    end
  end,

  ["plugin-manager:toggle"] = function(modname, short_name, enable)
    toggle_plugin(modname, short_name, enable)
  end,

  ["plugin-manager:list"] = function()
    local plugins = get_all_plugins()
    local sorted = {}
    for modname, plugin in pairs(plugins) do
      sorted[#sorted + 1] = plugin
    end
    table.sort(sorted, function(a, b) return a.modname < b.modname end)
    for _, plugin in ipairs(sorted) do
      local status = get_plugin_status(plugin)
      local sc = status == "enabled" and "x" or status == "disabled" and "-" or " "
      core.log("  [%s] %s (%s) [%s]", sc, plugin.short_name, plugin.category, status)
    end
  end,
})

-- ── Keymap ────────────────────────────────────────────────────────

keymap.add {
  ["shift+m"] = "plugin-manager:open",
}

return M
