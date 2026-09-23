local utf8 = {}

function utf8.is_cont(byte)
  return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

function utf8.len(text)
  if type(text) ~= "string" then return 0 end
  local n = 0
  for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    n = n + 1
  end
  return n
end

function utf8.chars(text)
  if type(text) ~= "string" then
    return function() return nil end
  end
  return text:gmatch("[%z\1-\127\194-\244][\128-\191]*")
end

-- Byte offset of the n-th character (1-based). Nil-safe.
function utf8.offset(text, n)
  if type(text) ~= "string" or type(n) ~= "number" or n < 1 then return nil end
  local pos, count = 1, 0
  local bytes = #text
  while pos <= bytes do
    count = count + 1
    if count == n then return pos end
    local b = text:byte(pos)
    local step = 1
    if b >= 0xF0 then step = 4
    elseif b >= 0xE0 then step = 3
    elseif b >= 0xC0 then step = 2 end
    pos = pos + step
  end
  return nil
end

-- Replace invalid sequences with U+FFFD. Used on file load.
function utf8.sanitize(text)
  if type(text) ~= "string" then return "" end
  local out, i, n = {}, 1, #text
  while i <= n do
    local b = text:byte(i)
    local step, ok = 1, true
    if b < 0x80 then step = 1
    elseif b >= 0xC2 and b <= 0xDF then step = 2
    elseif b >= 0xE0 and b <= 0xEF then step = 3
    elseif b >= 0xF0 and b <= 0xF4 then step = 4
    else ok = false end
    if ok then
      for k = 1, step - 1 do
        local c = text:byte(i + k)
        if c == nil or c < 0x80 or c > 0xBF then ok = false break end
      end
      -- reject overlongs / surrogates / > U+10FFFF
      if ok and step > 1 then
        local c1 = text:byte(i + 1) or 0
        if step == 2 and b == 0xC0 then ok = false end
        if step == 3 and b == 0xE0 and c1 < 0xA0 then ok = false end
        if step == 3 and b == 0xED and c1 > 0x9F then ok = false end
        if step == 4 and b == 0xF0 and c1 < 0x90 then ok = false end
        if step == 4 and b == 0xF4 and c1 > 0x8F then ok = false end
      end
    end
    if ok then
      out[#out + 1] = text:sub(i, i + step - 1)
      i = i + step
    else
      out[#out + 1] = "\239\191\189" -- U+FFFD
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Decode one codepoint at byte pos. Returns cp, next_pos.
function utf8.decode(text, pos)
  pos = pos or 1
  local b = text:byte(pos)
  if b == nil then return nil, pos end
  if b < 0x80 then return b, pos + 1 end
  local c1 = text:byte(pos + 1)
  if b >= 0xC2 and b <= 0xDF and c1 and c1 >= 0x80 and c1 <= 0xBF then
    return (b - 0xC0) * 64 + (c1 - 0x80), pos + 2
  end
  local c2 = text:byte(pos + 2)
  if b >= 0xE0 and b <= 0xEF and c1 and c2
    and c1 >= 0x80 and c1 <= 0xBF and c2 >= 0x80 and c2 <= 0xBF then
    return (b - 0xE0) * 4096 + (c1 - 0x80) * 64 + (c2 - 0x80), pos + 3
  end
  local c3 = text:byte(pos + 3)
  if b >= 0xF0 and b <= 0xF4 and c1 and c2 and c3
    and c1 >= 0x80 and c1 <= 0xBF and c2 >= 0x80 and c2 <= 0xBF
    and c3 >= 0x80 and c3 <= 0xBF then
    return (b - 0xF0) * 262144 + (c1 - 0x80) * 4096 + (c2 - 0x80) * 64 + (c3 - 0x80), pos + 4
  end
  return 0xFFFD, pos + 1
end

function utf8.encode(cp)
  cp = cp or 0xFFFD
  if cp < 0x80 then return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 64), 0x80 + (cp % 64))
  elseif cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 4096),
      0x80 + (math.floor(cp / 64) % 64), 0x80 + (cp % 64))
  else
    cp = math.min(cp, 0x10FFFF)
    return string.char(0xF0 + math.floor(cp / 262144),
      0x80 + (math.floor(cp / 4096) % 64),
      0x80 + (math.floor(cp / 64) % 64), 0x80 + (cp % 64))
  end
end

return utf8
