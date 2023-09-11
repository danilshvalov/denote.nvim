local co = coroutine

local run = function(func, callback)
  assert(type(func) == "function", "type error :: expected func")
  local thread = co.create(func)
  local step = nil
  step = function(...)
    local stat, ret = co.resume(thread, ...)
    assert(stat, ret)
    if co.status(thread) == "dead" then
      (callback or function() end)(ret)
    else
      assert(type(ret) == "function", "type error :: expected func")
      ret(step)
    end
  end
  step()
end

local wrap = function(func)
  assert(type(func) == "function", "type error :: expected func")
  local factory = function(...)
    local params = { ... }
    local thunk = function(step)
      table.insert(params, step)
      return func(unpack(params))
    end
    return co.yield(thunk)
  end
  return factory
end

return {
  run = run,
  wrap = wrap,
}
