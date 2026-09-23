local common = {}


function common.is_utf8_cont(char)
  if type(char) ~= "string" or #char == 0 then return false end
  local byte = char:byte(1, 1)
  if byte == nil then return false end
  return byte >= 0x80 and byte < 0xc0
end


function common.utf8_chars(text)
  if type(text) ~= "string" then
    return function() return nil end
  end
  local ok, t = pcall(require, "core.text.utf8")
  if ok and t and t.chars then return t.chars(text) end
  return text:gmatch("[%z\1-\127\194-\244][\128-\191]*")
end


function common.utf8_len(text)
  local ok, t = pcall(require, "core.text.utf8")
  if ok and t and t.len then return t.len(text) end
  local n = 0
  for _ in common.utf8_chars(text) do n = n + 1 end
  return n
end

function common.visual_text(text, opts)
  if type(text) ~= "string" then return "" end
  local ok, t = pcall(require, "core.text")
  if not ok or not t then return text end
  local ok2, res = pcall(t.visual, text, opts)
  if ok2 and type(res) == "string" then return res end
  return text
end


function common.clamp(n, lo, hi)
  return math.max(math.min(n, hi), lo)
end


function common.round(n)
  return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
end


function common.lerp(a, b, t)
  if type(a) ~= "table" then
    return a + (b - a) * t
  end
  local res = {}
  for k, v in pairs(b) do
    res[k] = common.lerp(a[k], v, t)
  end
  return res
end


function common.color(str)
  local r, g, b, a = str:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    r = tonumber(r, 16)
    g = tonumber(g, 16)
    b = tonumber(b, 16)
    a = 1
  elseif str:match("rgba?%s*%([%d%s%.,]+%)") then
    local f = str:gmatch("[%d.]+")
    r = (f() or 0)
    g = (f() or 0)
    b = (f() or 0)
    a = f() or 1
  else
    error(string.format("bad color string '%s'", str))
  end
  return r, g, b, a * 0xff
end


local function compare_score(a, b)
  return a.score > b.score
end

local function fuzzy_match_items(items, needle)
  local res = {}
  for _, item in ipairs(items) do
    local score = system.fuzzy_match(tostring(item), needle)
    if score then
      table.insert(res, { text = item, score = score })
    end
  end
  table.sort(res, compare_score)
  for i, item in ipairs(res) do
    res[i] = item.text
  end
  return res
end


function common.fuzzy_match(haystack, needle)
  if type(haystack) == "table" then
    return fuzzy_match_items(haystack, needle)
  end
  return system.fuzzy_match(haystack, needle)
end


function common.path_suggest(text)
  local path, name = text:match("^(.-)([^/\\]*)$")
  local files = system.list_dir(path == "" and "." or path) or {}
  local res = {}
  for _, file in ipairs(files) do
    file = path .. file
    local info = system.get_file_info(file)
    if info then
      if info.type == "dir" then
        file = file .. PATHSEP
      end
      if file:lower():find(text:lower(), nil, true) == 1 then
        table.insert(res, file)
      end
    end
  end
  return res
end


function common.match_pattern(text, pattern, ...)
  if type(pattern) == "string" then
    return text:find(pattern, ...)
  end
  for _, p in ipairs(pattern) do
    local s, e = common.match_pattern(text, p, ...)
    if s then return s, e end
  end
  return false
end


function common.draw_text(font, color, text, align, x,y,w,h, opts)
  if font == nil or text == nil then return x, y end
  text = common.visual_text(text, opts)
  local tw, th = font:get_width(text), font:get_height(text)
  if align == "center" then
    x = x + (w - tw) / 2
  elseif align == "right" then
    x = x + (w - tw)
  end
  y = common.round(y + (h - th) / 2)
  return renderer.draw_text(font, text, x, y, color), y + th
end


function common.bench(name, fn, ...)
  local start = system.get_time()
  local res = fn(...)
  local t = system.get_time() - start
  local ms = t * 1000
  local per = (t / (1 / 60)) * 100
  print(string.format("*** %-16s : %8.3fms %6.2f%%", name, ms, per))
  return res
end

function common.ensure_dir(path)
  if type(path) ~= "string" or path == "" then return end
  local IS_WIN = PATHSEP == "\\"
  local dir = path:match("^(.+)[\\/][^\\/]+$")
  if not dir or dir == "" then return end
  -- guard against command injection: only allow sane path chars
  if dir:find('["\n\r`$&|;]') then return end
  if IS_WIN then
    os.execute(string.format('mkdir "%s" 2>nul', dir))
  else
    os.execute(string.format('mkdir -p "%s"', dir))
  end
end


return common
