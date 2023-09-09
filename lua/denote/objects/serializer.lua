---@class Serializer
---@field note Note
---@field fields table<string, FieldSpec>
local Serializer = {}

function Serializer:new(opts)
  local this = opts or {}
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param field? FieldSpec
function Serializer:__serialize_field(field)
  return field.serialize(self.note)
end

function Serializer:title()
  return self:__serialize_field(self.fields.title)
end

function Serializer:date()
  return self:__serialize_field(self.fields.date)
end

function Serializer:keywords()
  return self:__serialize_field(self.fields.keywords)
end

function Serializer:id()
  return self:__serialize_field(self.fields.id)
end

return Serializer
