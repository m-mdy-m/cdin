local native = _G.search

local search = {}

local default_opt = {}
local function pattern_lower(str)
  if str:sub(1, 1) == "%" then
    return str
  end
  return str:lower()
end

local function init_args(doc, line, col, text, opt)
  opt = opt or default_opt
  line, col = doc:sanitize_position(line, col)

  if opt.no_case then
    if opt.pattern then
      text = text:gsub("%%?.", pattern_lower)
    else
      text = text:lower()
    end
  end

  return doc, line, col, text, opt
end

function search.find(doc, line, col, text, opt)
  doc, line, col, text, opt = init_args(doc, line, col, text, opt)

  if native then
    return native.find_in_lines(
      doc.lines, line, col, text,
      opt.no_case or false,
      opt.pattern or false,
      opt.wrap    or false
    )
  end

  local nlines = #doc.lines
  for l = line, nlines do
    local line_text = doc.lines[l]
    if opt.no_case then
      line_text = line_text:lower()
    end
    local s, e = line_text:find(text, col, not opt.pattern)
    if s then return l, s, l, e + 1 end
    col = 1
  end

  if opt.wrap then
    return search.find(doc, 1, 1, text,
      { no_case = opt.no_case, pattern = opt.pattern })
  end
end

return search