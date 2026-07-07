local function install(core)
  local listeners = {}

  function core.on(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
  end

  function core.off(event, fn)
    local lst = listeners[event]
    if not lst then return end
    for i = #lst, 1, -1 do
      if lst[i] == fn then table.remove(lst, i) end
    end
  end

  function core.emit(event, payload)
    local lst = listeners[event]
    if not lst then return end
    for _, fn in ipairs(lst) do
      core.try(fn, payload)
    end
  end
end

return { install = install }
