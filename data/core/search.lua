local native = _G.search   -- the C module registered as "search"

local M = {}

local function fuzzy_match_lua(str, ptn)
  local score, run = 0, 0
  local si, pi = 1, 1
  local slen, plen = #str, #ptn
  while si <= slen and pi <= plen do
    local sc = str:sub(si, si)
    local pc = ptn:sub(pi, pi)
    if sc == " " then si = si + 1
    elseif pc == " " then pi = pi + 1
    elseif sc:lower() == pc:lower() then
      score = score + run * 10 - (sc ~= pc and 1 or 0)
      run = run + 1
      pi  = pi  + 1
      si  = si  + 1
    else
      score = score - 10
      run = 0
      si  = si + 1
    end
  end
  if pi <= plen then return nil end   -- pattern not consumed
  return score - (slen - si + 1)     -- length penalty
end

function M.fuzzy_match(str, pattern)
  if native then
    return native.fuzzy_match(str, pattern)
  end
  return fuzzy_match_lua(str, pattern)
end

function M.fuzzy_sort(items, pattern, key)
  key = key or tostring
  local scored = {}
  for _, item in ipairs(items) do
    local s = M.fuzzy_match(key(item), pattern)
    if s then
      scored[#scored + 1] = { item = item, score = s }
    end
  end
  table.sort(scored, function(a, b) return a.score > b.score end)
  local out = {}
  for _, v in ipairs(scored) do
    out[#out + 1] = v.item
  end
  return out
end

function M.find_in_lines(lines, start_line, start_col,
                          text, no_case, is_pattern, wrap)
  if native then
    return native.find_in_lines(lines, start_line, start_col,
                                 text, no_case, is_pattern, wrap)
  end
  local col = start_col
  local function scan(from, to)
    for l = from, to do
      local lt = lines[l]
      if lt then
        local t = no_case and lt:lower() or lt
        local s, e = t:find(no_case and text:lower() or text,
                            col, not is_pattern)
        if s then return l, s, l, e + 1 end
      end
      col = 1
    end
  end
  local ls, cs, le, ce = scan(start_line, #lines)
  if ls then return ls, cs, le, ce end
  if wrap then
    col = 1
    return scan(1, #lines)
  end
end

return M