-- Fixture theme in the site, at SITE/X/themes/<name>/theme.lua.
--
-- That is the path an extension registers through
-- require("core.themes").add_root(), and the path a persisted
-- config.theme can name before the plugin that owns it has loaded.
return {
  name = "fixture-site",
  background = "#202020",
  text = "#c0c0c0",
  caret = "#ffff00",
  accent = "#ff8080",
}
