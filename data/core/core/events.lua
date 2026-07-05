-- SDL event dispatch: keyboard, mouse, text input, file drop, quit.

local function install(core, keymap)
  function core.on_event(type, ...)
    local did_keymap = false
    if     type == "textinput"    then core.root_view:on_text_input(...)
    elseif type == "keypressed"   then did_keymap = keymap.on_key_pressed(...)
    elseif type == "keyreleased"  then keymap.on_key_released(...)
    elseif type == "mousemoved"   then core.root_view:on_mouse_moved(...)
    elseif type == "mousepressed" then core.root_view:on_mouse_pressed(...)
    elseif type == "mousereleased" then core.root_view:on_mouse_released(...)
    elseif type == "mousewheel"   then core.root_view:on_mouse_wheel(...)
    elseif type == "filedropped"  then
      local filename, mx, my = ...
      local info = system.get_file_info(filename)
      if info and info.type == "dir" then
        system.exec(string.format("%q %q", EXEFILE, filename))
      else
        local ok, doc = core.try(core.open_doc, filename)
        if ok then
          local node = core.root_view.root_node:get_child_overlapping_point(mx, my)
          node:set_active_view(node.active_view)
          core.root_view:open_doc(doc)
        end
      end
    elseif type == "quit" then
      core.quit()
    end
    return did_keymap
  end
end

return { install = install }
