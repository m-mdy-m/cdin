-- Initializes the core state table: docs, threads, clip-rect stack,
-- project file list, and the four root UI views.

local function setup_state(core)
  core.frame_start     = 0
  core.clip_rect_stack = {{ 0, 0, 0, 0 }}
  core.log_items       = {}
  core.docs            = {}
  core.threads         = setmetatable({}, { __mode = "k" })
  core.project_files   = {}
  core.redraw          = true
end

local function setup_views(core, RootView, CommandView, StatusView, TitleBar)
  core.root_view    = RootView()
  core.command_view = CommandView()
  core.status_view  = StatusView()
  core.title_bar    = TitleBar()

  core.root_view.root_node:split("up",   core.title_bar,    true)
  core.root_view.root_node.b:split("down", core.command_view, true)
  core.root_view.root_node.b.b:split("down", core.status_view, true)
end

return {
  setup_state = setup_state,
  setup_views = setup_views,
}
