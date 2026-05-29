local syntax = require "core.syntax"

syntax.add {
  files = { "%.ts$", "%.d.ts$", "%.tsx$" },
  comment = "//",
  patterns = {
    -- Comments
    { pattern = "//.-\n",               type = "comment"  },
    { pattern = { "/%*", "%*/" },       type = "comment"  },
    
    -- JSDoc comments (special highlighting for documentation)
    { pattern = { "/%*%*", "%*/" },     type = "comment2" },
    
    -- Strings with escaping support
    { pattern = { '"', '"', '\\' },     type = "string"   },
    { pattern = { "'", "'", '\\' },     type = "string"   },
    { pattern = { "`", "`", '\\' },     type = "string"   },
    
    -- Template literal expressions
    { pattern = { "${", "}" },          type = "operator", syntax = ".ts" },
    
    -- Numbers (hex, binary, octal, float, scientific notation)
    { pattern = "0[xX][%da-fA-F_]+",    type = "number"   },
    { pattern = "0[bB][01_]+",          type = "number"   },
    { pattern = "0[oO][0-7_]+",         type = "number"   },
    { pattern = "-?%d[%d_]*%.?[%d_]*[eE][-+]?%d+", type = "number" },
    { pattern = "-?%d[%d_]*%.%d[%d_]*", type = "number"   },
    { pattern = "-?%d[%d_]*",           type = "number"   },
    
    -- TypeScript type annotations
    { pattern = ":%s*[%a_][%w_%.]*",    type = "keyword2" },
    { pattern = "<%s*[%a_][%w_%.%s,]*%s*>", type = "keyword2" },
    
    -- Decorators
    { pattern = "@[%a_][%w_]*",         type = "special"  },
    
    -- Special TypeScript symbols
    { pattern = "=>",                   type = "operator" },
    { pattern = "%.%.%.",              type = "operator" }, -- spread operator
    { pattern = "%?%.",                type = "operator" }, -- optional chaining
    { pattern = "!%.",                 type = "operator" }, -- non-null assertion
    
    -- Regular operators
    { pattern = "[%+%-=/%*%^%%<>!~|&:?]", type = "operator" },
    
    -- Function calls
    { pattern = "[%a_][%w_]*%f[(]",     type = "function" },
    
    -- Arrow functions
    { pattern = "%(.-%)%s*=>",          type = "function" },
    
    -- Identifiers
    { pattern = "[%a_][%w_]*",          type = "symbol"   },
  },
  symbols = {
    -- Keywords
    ["abstract"]   = "keyword2",
    ["any"]        = "keyword2",
    ["arguments"]  = "keyword2",
    ["as"]         = "keyword2",
    ["async"]      = "keyword",
    ["await"]      = "keyword",
    ["boolean"]    = "keyword2",
    ["break"]      = "keyword",
    ["case"]       = "keyword",
    ["catch"]      = "keyword",
    ["class"]      = "keyword",
    ["const"]      = "keyword",
    ["constructor"]= "keyword",
    ["continue"]   = "keyword",
    ["debugger"]   = "keyword",
    ["declare"]    = "keyword2",
    ["default"]    = "keyword",
    ["delete"]     = "keyword",
    ["do"]         = "keyword",
    ["else"]       = "keyword",
    ["enum"]       = "keyword2",
    ["export"]     = "keyword",
    ["extends"]    = "keyword",
    ["false"]      = "literal",
    ["finally"]    = "keyword",
    ["for"]        = "keyword",
    ["from"]       = "keyword",
    ["function"]   = "keyword",
    ["get"]        = "keyword",
    ["if"]         = "keyword",
    ["implements"] = "keyword2",
    ["import"]     = "keyword",
    ["in"]         = "keyword",
    ["infer"]      = "keyword2",
    ["Infinity"]   = "literal",
    ["instanceof"] = "keyword",
    ["interface"]  = "keyword2",
    ["is"]         = "keyword2",
    ["keyof"]      = "keyword2",
    ["let"]        = "keyword",
    ["module"]     = "keyword2",
    ["namespace"]  = "keyword2",
    ["never"]      = "keyword2",
    ["new"]        = "keyword",
    ["null"]       = "literal",
    ["number"]     = "keyword2",
    ["object"]     = "keyword2",
    ["of"]         = "keyword2",
    ["package"]    = "keyword2",
    ["private"]    = "keyword2",
    ["protected"]  = "keyword2",
    ["public"]     = "keyword2",
    ["readonly"]   = "keyword2",
    ["require"]    = "keyword2",
    ["return"]     = "keyword",
    ["set"]        = "keyword",
    ["static"]     = "keyword",
    ["string"]     = "keyword2",
    ["super"]      = "keyword",
    ["switch"]     = "keyword",
    ["symbol"]     = "keyword2",
    ["this"]       = "keyword2",
    ["throw"]      = "keyword",
    ["true"]       = "literal",
    ["try"]        = "keyword",
    ["type"]       = "keyword2",
    ["typeof"]     = "keyword2",
    ["undefined"]  = "literal",
    ["unknown"]    = "keyword2",
    ["var"]        = "keyword",
    ["void"]       = "keyword",
    ["while"]      = "keyword",
    ["with"]       = "keyword",
    ["yield"]      = "keyword",
    
    -- Common built-in types
    ["Array"]      = "function",
    ["Date"]       = "function",
    ["Error"]      = "function",
    ["Map"]        = "function",
    ["Promise"]    = "function",
    ["Proxy"]      = "function",
    ["RegExp"]     = "function",
    ["Set"]        = "function",
    ["Symbol"]     = "function",
    ["WeakMap"]    = "function",
    ["WeakSet"]    = "function",
    
    -- Common utility functions
    ["console"]    = "function",
    ["document"]   = "function",
    ["Math"]       = "function",
    ["Object"]     = "function",
    ["parseInt"]   = "function",
    ["parseFloat"] = "function",
    ["setTimeout"] = "function",
    ["window"]     = "function",
  }
}
