local syntax   = require "core.syntax.syntax"
local tokenizer = require "core.syntax.tokenizer"

return {
  add      = syntax.add,
  get      = syntax.get,
  items    = syntax.items,
  tokenize   = tokenizer.tokenize,
  each_token = tokenizer.each_token,
}
