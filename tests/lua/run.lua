package.path = "tests/lua/?.lua;data/?.lua;data/?/init.lua;" .. package.path

rawset(_G, "SCALE", 1)
rawset(_G, "VERSION", "0.0.0-test")
rawset(_G, "PLATFORM", "test")
rawset(_G, "EXEDIR", ".")
rawset(_G, "EXEFILE", "./cdin")
rawset(_G, "ARGS", {})
rawset(_G, "PATHSEP", package.config:sub(1, 1))

local T = require "harness"


local function discover()
  local files = {}
  local win = package.config:sub(1, 1) == "\\"
  for _, dir in ipairs({ "tests/lua/unit", "tests/lua/integration" }) do
    local cmd
    if win then
      cmd = 'dir /b /a-d "' .. dir .. '\\*_test.lua"'
    else
      cmd = 'ls -1 ' .. dir .. '/*_test.lua 2>/dev/null'
    end
    local p = io.popen(cmd)
    if p then
      -- NB: generic-for variables are const in Lua 5.5 -> copy first.
      for iter_line in p:lines() do
        local name = iter_line:gsub("[\r\n]+$", "")
        if name:match("_test%.lua$") then
          -- `dir /b` may emit bare file names; make paths dir-qualified.
          if not name:find("/", 1, true) and not name:find("\\", 1, true) then
            name = dir .. "\\" .. name
          end
          files[#files + 1] = name
        end
      end
      p:close()
    end
  end
  return files
end

local files = {}
if arg and #arg > 0 then
  for i = 1, #arg do files[#files + 1] = arg[i] end
else
  files = discover()
end


T.reset()

local function on_error(msg)
  return debug.traceback(tostring(msg), 2)
end

local reports = {}
for _, file in ipairs(files) do
  T.begin(file)
  local a0, f0 = T.stats()
  local ok, err = xpcall(function()
    local chunk, lerr = loadfile(file)
    if not chunk then error(lerr, 0) end
    chunk()
  end, on_error)
  if not ok then
    T.add_failure(err) -- uncaught error counts as a failure w/ traceback
  end
  T.run_teardowns()
  T.unstub_all()
  local a1, f1 = T.stats()
  reports[#reports + 1] = { file = file, asserts = a1 - a0, failures = f1 - f0 }
end


for _, r in ipairs(reports) do
  if r.failures > 0 then
    print(string.format("[FAIL] %s (%d asserts, %d failure%s)",
      r.file, r.asserts, r.failures, r.failures == 1 and "" or "s"))
  else
    print(string.format("[OK]   %s (%d asserts)", r.file, r.asserts))
  end
end

local total, nfail, failures = T.stats()
if nfail > 0 then
  for _, f in ipairs(failures) do
    local msg = tostring(f.msg):gsub("\r\n", "\n"):gsub("\n", "\n  ")
    print("FAIL " .. f.file .. ": " .. msg)
  end
  print(string.format("LUA TESTS FAILED (%d failures)", nfail))
  os.exit(1)
end

print(string.format("LUA TESTS OK (%d asserts, %d files)", total, #files))
os.exit(0)
