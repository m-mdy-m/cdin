-- Main render loop: step() polls SDL events, updates views, draws a frame.
-- run() drives the loop at config.fps and yields to the coroutine scheduler.

local config = require "core.config"

local function install(core)
  local run_threads = coroutine.wrap(function()
    while true do
      local max_time = 1 / config.fps - 0.004
      local ran_any  = false

      for k, thread in pairs(core.threads) do
        if thread.wake < system.get_time() then
          local _, wait = assert(coroutine.resume(thread.cr))
          if coroutine.status(thread.cr) == "dead" then
            if type(k) == "number" then table.remove(core.threads, k)
            else                        core.threads[k] = nil
            end
          elseif wait then
            thread.wake = system.get_time() + wait
          end
          ran_any = true
        end
        if system.get_time() - core.frame_start > max_time then
          coroutine.yield()
        end
      end

      if not ran_any then coroutine.yield() end
    end
  end)

  function core.step()
    local did_keymap  = false
    local mouse_moved = false
    local mouse       = { x = 0, y = 0, dx = 0, dy = 0 }

    for type, a, b, c, d in system.poll_event do
      if type == "mousemoved" then
        mouse_moved = true
        mouse.x, mouse.y   = a, b
        mouse.dx, mouse.dy = mouse.dx + c, mouse.dy + d
      elseif type == "textinput" and did_keymap then
        did_keymap = false
      else
        local _, res = core.try(core.on_event, type, a, b, c, d)
        did_keymap   = res or did_keymap
      end
      core.redraw = true
    end
    if mouse_moved then
      core.try(core.on_event, "mousemoved", mouse.x, mouse.y, mouse.dx, mouse.dy)
    end

    local width, height = renderer.get_size()
    core.root_view.size.x, core.root_view.size.y = width, height
    core.root_view:update()
    if not core.redraw then return false end
    core.redraw = false

    for i = #core.docs, 1, -1 do
      local doc = core.docs[i]
      if #core.get_views_referencing_doc(doc) == 0 then
        table.remove(core.docs, i)
        core.log_quiet('Closed doc "%s"', doc:get_name())
      end
    end

    local name  = core.active_view:get_name()
    local title = (name ~= "---") and (name .. " - cdin") or "cdin"
    if title ~= core.window_title then
      system.set_window_title(title)
      core.window_title = title
    end

    renderer.begin_frame()
    core.clip_rect_stack[1] = { 0, 0, width, height }
    renderer.set_clip_rect(table.unpack(core.clip_rect_stack[1]))
    core.root_view:draw()
    renderer.end_frame()
    return true
  end

  function core.run()
    while true do
      core.frame_start = system.get_time()
      local did_redraw = core.step()
      run_threads()
      if not did_redraw and not system.window_has_focus() then
        system.wait_event(0.25)
      end
      local elapsed = system.get_time() - core.frame_start
      system.sleep(math.max(0, 1 / config.fps - elapsed))
    end
  end
end

return { install = install }
