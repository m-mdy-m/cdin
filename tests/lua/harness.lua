local T = {}

local state = {
  asserts = 0,
  failures = {},      -- { { file = <name>, msg = <string> }, ... }
  current_file = "?",
}
local stubs = {}      -- _G name -> { present = bool, value = <orig> }
local teardowns = {}  -- callbacks run by run.lua after each test file

-- ── pretty values for default failure messages ──────────────────────

local function repr(v, depth)
  depth = depth or 0
  local t = type(v)
  if t == "string" then
    local s = v:gsub("\n", "\\n")
    if #s > 60 then s = s:sub(1, 57) .. "..." end
    return string.format("%q", s)
  elseif t == "table" then
    if depth >= 2 then return "{...}" end
    local parts, n = {}, 0
    for k, val in pairs(v) do
      n = n + 1
      if n <= 8 then
        local kk = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
        parts[#parts + 1] = kk .. "=" .. repr(val, depth + 1)
      end
    end
    if n > 8 then parts[#parts + 1] = "..." end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end
T.repr = repr

-- ── deep-enough equality ────────────────────────────────────────────

local function deep_eq(a, b, depth)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return false end -- scalars handled by ==
  depth = depth or 0
  if depth > 8 then return false end
  for k, v in pairs(a) do
    if not deep_eq(v, b[k], depth + 1) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end
T.deep_eq = deep_eq

-- ── failure recording ───────────────────────────────────────────────

local function add_failure(msg)
  state.failures[#state.failures + 1] = {
    file = state.current_file,
    msg = tostring(msg),
  }
end

-- ── assertions (each call counts as one assert) ─────────────────────

function T.eq(a, b, msg)
  state.asserts = state.asserts + 1
  if deep_eq(a, b) then return true end
  add_failure(msg or ("expected " .. repr(b) .. ", got " .. repr(a)))
  return false
end

function T.neq(a, b, msg)
  state.asserts = state.asserts + 1
  if not deep_eq(a, b) then return true end
  add_failure(msg or ("expected different values, both " .. repr(a)))
  return false
end

function T.ok(cond, msg)
  state.asserts = state.asserts + 1
  if cond then return true end
  add_failure(msg or ("expected truthy value, got " .. repr(cond)))
  return false
end

function T.fail(msg)
  state.asserts = state.asserts + 1
  add_failure(msg or "explicit failure")
  return false
end

function T.match(s, pattern, msg)
  state.asserts = state.asserts + 1
  if type(s) ~= "string" then
    add_failure((msg or "match") .. ": not a string: " .. repr(s))
    return false
  end
  if type(pattern) ~= "string" then
    add_failure((msg or "match") .. ": pattern is not a string: " .. repr(pattern))
    return false
  end
  if s:find(pattern) then return true end
  add_failure(msg or (repr(s) .. " does not match pattern " .. repr(pattern)))
  return false
end

-- ── runner API ──────────────────────────────────────────────────────

function T.begin(file)
  state.current_file = file or "?"
end

function T.reset()
  state.asserts = 0
  state.failures = {}
end

function T.stats()
  return state.asserts, #state.failures, state.failures
end

function T.add_failure(msg)
  add_failure(msg)
end

-- ── global stubs ─────────────────────────────────────────────────---

function T.stub(name, tbl)
  if stubs[name] == nil then
    local orig = rawget(_G, name)
    stubs[name] = { present = orig ~= nil, value = orig }
  end
  rawset(_G, name, tbl)
end

function T.unstub(name)
  local s = stubs[name]
  if s == nil then return end
  stubs[name] = nil
  if s.present then rawset(_G, name, s.value) else rawset(_G, name, nil) end
end

function T.unstub_all()
  local names = {}
  for name in pairs(stubs) do names[#names + 1] = name end
  for _, name in ipairs(names) do T.unstub(name) end
end

-- ── teardown hooks (e.g. clearing package.loaded entries) ───────────

function T.teardown(fn)
  teardowns[#teardowns + 1] = fn
end

function T.run_teardowns()
  local list = teardowns
  teardowns = {}
  for _, fn in ipairs(list) do pcall(fn) end
end

return T
