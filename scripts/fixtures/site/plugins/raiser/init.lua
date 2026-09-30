-- A site plugin that raises at file scope, before it ever returns a table.
--
-- Distinct from bundled/plugins/broken, which returns a table and then
-- raises in init(): this one exercises the pcall around dofile itself.
error("raiser: raised at file scope on purpose")
