local utf8 = require "core.text.utf8"

local bidi = {}

local function class_of(cp)
  -- R: Hebrew, Arabic, Persian blocks; AL treated as R here.
  if (cp >= 0x0590 and cp <= 0x08FF) or (cp >= 0xFB00 and cp <= 0xFDFF)
    or (cp >= 0xFE00 and cp <= 0xFEFF) then
    return "R"
  end
  -- EN: ASCII + extended Arabic-Indic digits
  if (cp >= 0x0030 and cp <= 0x0039) or (cp >= 0x0660 and cp <= 0x0669)
    or (cp >= 0x06F0 and cp <= 0x06F9) then
    return "EN"
  end
  -- L: everything else printable (incl. Latin, CJK)
  if cp == 0x20 or cp == 0x09 then return "WS" end
  return "L"
end

function bidi.is_rtl_char(cp)
  return class_of(cp) == "R"
end

-- Base direction of a paragraph: first strong char wins, else LTR.
function bidi.base_dir(text)
  if type(text) ~= "string" then return "ltr" end
  local pos, n = 1, #text
  while pos <= n do
    local cp, next_pos = utf8.decode(text, pos)
    local c = class_of(cp)
    if c == "R" then return "rtl" end
    if c == "L" then return "ltr" end
    pos = next_pos
  end
  return "ltr"
end

function bidi.has_rtl(text)
  if type(text) ~= "string" then return false end
  local pos, n = 1, #text
  while pos <= n do
    local cp, next_pos = utf8.decode(text, pos)
    if class_of(cp) == "R" then return true end
    pos = next_pos
  end
  return false
end

-- Split into directional runs; neutrals attach to surroundings.
local function runs(text)
  local out, cur, cur_cls = {}, {}, nil
  local pos, n = 1, #text
  while pos <= n do
    local cp, next_pos = utf8.decode(text, pos)
    local cls = class_of(cp)
    local chunk = text:sub(pos, next_pos - 1)
    if cls == "WS" or cls == "EN" then
      -- neutrals/numbers join the current run (simplification)
      if #cur == 0 then cur_cls = "L" end
      cur[#cur + 1] = chunk
    else
      if cur_cls ~= nil and cls ~= cur_cls then
        out[#out + 1] = { cls = cur_cls, text = table.concat(cur) }
        cur = {}
      end
      cur_cls = cls
      cur[#cur + 1] = chunk
    end
    pos = next_pos
  end
  if #cur > 0 then out[#out + 1] = { cls = cur_cls or "L", text = table.concat(cur) } end
  return out
end

-- Reverse the characters inside one RTL run (char-wise, not byte-wise).
local function reverse_chars(s)
  local chars = {}
  for c in utf8.chars(s) do chars[#chars + 1] = c end
  local out = {}
  for i = #chars, 1, -1 do out[#out + 1] = chars[i] end
  return table.concat(out)
end

-- Logical -> visual order for display. `dir` is "ltr", "rtl" or "auto".
function bidi.visual(text, dir)
  if type(text) ~= "string" or text == "" then return text or "" end
  dir = dir or "auto"
  local base = dir == "auto" and bidi.base_dir(text) or dir
  local rs = runs(text)
  if base == "rtl" then
    -- reverse run order, then mirror chars inside RTL runs
    local out = {}
    for i = #rs, 1, -1 do
      local r = rs[i]
      out[#out + 1] = r.cls == "R" and reverse_chars(r.text) or r.text
    end
    return table.concat(out)
  end
  -- LTR paragraph: only mirror RTL runs in place
  for i, r in ipairs(rs) do
    if r.cls == "R" then rs[i] = { cls = r.cls, text = reverse_chars(r.text) } end
  end
  local out = {}
  for _, r in ipairs(rs) do out[#out + 1] = r.text end
  return table.concat(out)
end

return bidi
