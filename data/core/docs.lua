local function install(core, Doc)
  function core.push_clip_rect(x, y, w, h)
    local x2, y2, w2, h2 = table.unpack(core.clip_rect_stack[#core.clip_rect_stack])
    local r,  b,  r2, b2 = x+w, y+h, x2+w2, y2+h2
    x, y = math.max(x, x2), math.max(y, y2)
    b, r = math.min(b, b2), math.min(r, r2)
    w, h = r-x, b-y
    table.insert(core.clip_rect_stack, { x, y, w, h })
    renderer.set_clip_rect(x, y, w, h)
  end

  function core.pop_clip_rect()
    table.remove(core.clip_rect_stack)
    renderer.set_clip_rect(table.unpack(core.clip_rect_stack[#core.clip_rect_stack]))
  end

  function core.open_doc(filename)
    if filename then
      local abs = system.absolute_path(filename)
      for _, doc in ipairs(core.docs) do
        if doc.filename and abs == system.absolute_path(doc.filename) then
          return doc
        end
      end
    end
    local doc = Doc(filename)
    table.insert(core.docs, doc)
    core.log_quiet(filename and 'Opened doc "%s"' or "Opened new doc", filename)
    return doc
  end

  function core.get_views_referencing_doc(doc)
    local res   = {}
    local views = core.root_view.root_node:get_children()
    for _, view in ipairs(views) do
      if view.doc == doc then table.insert(res, view) end
    end
    return res
  end

  function core.reload_module(name)
    local old = package.loaded[name]
    package.loaded[name] = nil
    local new = require(name)
    if type(old) == "table" then
      for k, v in pairs(new) do old[k] = v end
      package.loaded[name] = old
    end
  end
end

return { install = install }
