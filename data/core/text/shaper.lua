local utf8 = require "core.text.utf8"

local shaper = {}

-- cp -> { isol, fina, init, medi, dual } (dual=false => right-joining only)
local FORMS = {
  [0x0621] = {0xFE80,nil,nil,nil,false}, -- hamza: non-joining, isolated form only
  [0x0622] = {0xFE81,0xFE82,nil,nil,false},
  [0x0623] = {0xFE83,0xFE84,nil,nil,false},
  [0x0624] = {0xFE85,0xFE86,nil,nil,false},
  [0x0625] = {0xFE87,0xFE88,nil,nil,false},
  [0x0626] = {0xFE89,0xFE8A,0xFE8B,0xFE8C,true},
  [0x0627] = {0xFE8D,0xFE8E,nil,nil,false},
  [0x0628] = {0xFE8F,0xFE90,0xFE91,0xFE92,true},
  [0x0629] = {0xFE93,0xFE94,nil,nil,false},
  [0x062A] = {0xFE95,0xFE96,0xFE97,0xFE98,true},
  [0x062B] = {0xFE99,0xFE9A,0xFE9B,0xFE9C,true},
  [0x062C] = {0xFE9D,0xFE9E,0xFE9F,0xFEA0,true},
  [0x062D] = {0xFEA1,0xFEA2,0xFEA3,0xFEA4,true},
  [0x062E] = {0xFEA5,0xFEA6,0xFEA7,0xFEA8,true},
  [0x062F] = {0xFEA9,0xFEAA,nil,nil,false},
  [0x0630] = {0xFEAB,0xFEAC,nil,nil,false},
  [0x0631] = {0xFEAD,0xFEAE,nil,nil,false},
  [0x0632] = {0xFEAF,0xFEB0,nil,nil,false},
  [0x0633] = {0xFEB1,0xFEB2,0xFEB3,0xFEB4,true},
  [0x0634] = {0xFEB5,0xFEB6,0xFEB7,0xFEB8,true},
  [0x0635] = {0xFEB9,0xFEBA,0xFEBB,0xFEBC,true},
  [0x0636] = {0xFEBD,0xFEBE,0xFEBF,0xFEC0,true},
  [0x0637] = {0xFEC1,0xFEC2,0xFEC3,0xFEC4,true},
  [0x0638] = {0xFEC5,0xFEC6,0xFEC7,0xFEC8,true},
  [0x0639] = {0xFEC9,0xFECA,0xFECB,0xFECC,true},
  [0x063A] = {0xFECD,0xFECE,0xFECF,0xFED0,true},
  [0x0641] = {0xFED1,0xFED2,0xFED3,0xFED4,true},
  [0x0642] = {0xFED5,0xFED6,0xFED7,0xFED8,true},
  [0x0643] = {0xFED9,0xFEDA,0xFEDB,0xFEDC,true},
  [0x0644] = {0xFEDD,0xFEDE,0xFEDF,0xFEE0,true},
  [0x0645] = {0xFEE1,0xFEE2,0xFEE3,0xFEE4,true},
  [0x0646] = {0xFEE5,0xFEE6,0xFEE7,0xFEE8,true},
  [0x0647] = {0xFEE9,0xFEEA,0xFEEB,0xFEEC,true},
  [0x0648] = {0xFEED,0xFEEE,nil,nil,false},
  [0x0649] = {0xFEEF,0xFEF0,nil,nil,false},
  [0x064A] = {0xFEF1,0xFEF2,0xFEF3,0xFEF4,true},
  -- Persian / Urdu extensions
  [0x067E] = {0xFB56,0xFB57,0xFB58,0xFB59,true},
  [0x0686] = {0xFB7A,0xFB7B,0xFB7C,0xFB7D,true},
  [0x0698] = {0xFB8A,0xFB8B,nil,nil,false},
  [0x06A9] = {0xFB8E,0xFB8F,0xFB90,0xFB91,true},
  [0x06AF] = {0xFB92,0xFB93,0xFB94,0xFB95,true},
  [0x06CC] = {0xFBFC,0xFBFD,0xFBFE,0xFBFF,true},
}

local function is_mark(cp)
  return (cp >= 0x064B and cp <= 0x0652) or cp == 0x0670
    or (cp >= 0x06D6 and cp <= 0x06DC) or (cp >= 0x06DF and cp <= 0x06E4)
    or (cp >= 0x06E7 and cp <= 0x06E8) or cp == 0x06EA
end

local LAM = 0x0644
local LIG = {
  [0x0627] = {0xFEFB,0xFEFC},
  [0x0622] = {0xFEF5,0xFEF6},
  [0x0623] = {0xFEF7,0xFEF8},
  [0x0625] = {0xFEF9,0xFEFA},
}

local function can_join_left(cp) -- can this char connect to the previous one?
  local f = FORMS[cp]
  if cp == 0x0640 then return true end -- tatweel
  if f == nil then return false end
  return f[2] ~= nil -- has a final form => can be joined into from the right
end

local function can_join_right(cp) -- can this char connect to the next one?
  local f = FORMS[cp]
  if cp == 0x0640 then return true end
  if f == nil then return false end
  return f[5] == true
end

function shaper.needs_shaping(text)
  if type(text) ~= "string" then return false end
  local pos, n = 1, #text
  while pos <= n do
    local cp, next_pos = utf8.decode(text, pos)
    if FORMS[cp] then return true end
    pos = next_pos
  end
  return false
end

-- Shape logical-order text -> logical-order presentation forms.
-- (Bidi reordering happens separately in core.text.bidi.)
function shaper.shape(text)
  if type(text) ~= "string" or text == "" then return text or "" end
  if not shaper.needs_shaping(text) then return text end
  -- decode to codepoints, skipping marks attachment bookkeeping
  local cps, marks = {}, {}
  local pos, n = 1, #text
  while pos <= n do
    local cp, next_pos = utf8.decode(text, pos)
    cps[#cps + 1] = cp
    marks[#marks + 1] = nil
    pos = next_pos
  end
  -- attach marks to previous base char
  local bases = {}
  for i, cp in ipairs(cps) do
    if is_mark(cp) and #bases > 0 then
      local b = bases[#bases]
      b.marks[#b.marks + 1] = cp
    else
      bases[#bases + 1] = { cp = cp, marks = {} }
    end
  end
  local lig_start, lig_consumed = {}, {}
  for i, b in ipairs(bases) do
    local nxt = bases[i + 1]
    if b.cp == LAM and not lig_consumed[i] and nxt and LIG[nxt.cp]
      and #nxt.marks == 0 and #b.marks == 0 then
      lig_start[i] = true
      lig_consumed[i + 1] = true
    end
  end

  local function joins_left(i)  -- can bases[i] connect to the previous base?
    if lig_consumed[i] then return false end -- mid-ligature: no separate glyph
    if lig_start[i] then return true end
    return can_join_left(bases[i].cp)
  end
  local function joins_right(i)  -- can bases[i] connect to the next base?
    if lig_consumed[i] then return false end
    if lig_start[i] then return false end -- alef half never joins onward
    return can_join_right(bases[i].cp)
  end
  local function prev_glyph(i)
    local j = i - 1
    while j >= 1 and lig_consumed[j] do j = j - 1 end
    return j >= 1 and j or nil
  end
  local function next_glyph(i)
    local j = i + 1
    if lig_consumed[j] then j = j + 1 end -- ligature's alef half: skip to what follows it
    return bases[j] and j or nil
  end

  local out = {}
  for i, b in ipairs(bases) do
    local cp = b.cp
    if lig_start[i] then
      local nxt = bases[i + 1]
      local p = prev_glyph(i)
      local join_prev = p ~= nil and joins_right(p) and joins_left(i)
      local pair = LIG[nxt.cp]
      out[#out + 1] = utf8.encode(join_prev and pair[2] or pair[1])
    elseif lig_consumed[i] then
      -- alef half of a ligature already emitted above: nothing to draw
    elseif FORMS[cp] then
      local p, nx = prev_glyph(i), next_glyph(i)
      local join_prev = p ~= nil and joins_right(p) and joins_left(i)
      local join_next = nx ~= nil and joins_right(i) and joins_left(nx)
      local f = FORMS[cp]
      local form
      if join_prev and join_next and f[4] then form = f[4]
      elseif join_prev and f[2] then form = f[2]
      elseif join_next and f[3] then form = f[3]
      else form = f[1] end
      out[#out + 1] = utf8.encode(form or cp)
      for _, m in ipairs(b.marks) do out[#out + 1] = utf8.encode(m) end
    else
      out[#out + 1] = utf8.encode(cp)
      for _, m in ipairs(b.marks) do out[#out + 1] = utf8.encode(m) end
    end
  end
  return table.concat(out)
end

return shaper