local core   = require "core"
local config = require "core.config"
local Doc    = require "core.doc"

local times = setmetatable({}, { __mode = "k" })

local function update_time(doc)
  if not doc.filename then return end
  local info = system.get_file_info(doc.filename)
  if info then times[doc] = info.modified end
end

local function reload_doc(doc)
  local fp = io.open(doc.filename, "r")
  if not fp then return end
  local text = fp:read("*a")
  fp:close()

  local sel = { doc:get_selection() }
  doc:remove(1, 1, math.huge, math.huge)
  doc:insert(1, 1, text:gsub("\r", ""):gsub("\n$", ""))
  doc:set_selection(table.unpack(sel))

  update_time(doc)
  doc:clean()
  core.log_quiet("Auto-reloaded doc \"%s\"", doc.filename)
end

core.add_thread(function()
  while true do
    for _, doc in ipairs(core.docs) do
      local info = system.get_file_info(doc.filename or "")
      if info and times[doc] ~= info.modified then
        reload_doc(doc)
      end
      coroutine.yield(0.05)
    end
    coroutine.yield(config.project_scan_rate)
  end
end)

table.insert(Doc._after_load, update_time)
table.insert(Doc._after_save, update_time)
