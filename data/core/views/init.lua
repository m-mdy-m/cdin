local View        = require "core.views.view"
local DocView     = require "core.views.docview"
local CommandView = require "core.views.commandview"
local StatusView  = require "core.views.statusview"
local LogView     = require "core.views.logview"
local TitleBar    = require "core.views.titlebar"

return {
  View        = View,
  DocView     = DocView,
  CommandView = CommandView,
  StatusView  = StatusView,
  LogView     = LogView,
  TitleBar    = TitleBar,
}
