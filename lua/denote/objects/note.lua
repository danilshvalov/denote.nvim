---@class Note
---@field id string
---@field title string
---@field date integer
---@field keywords string[]
local Note = {}

function Note:new(opts)
  local this = opts or {}
  setmetatable(this, self)
  self.__index = self
  return this
end

return Note
