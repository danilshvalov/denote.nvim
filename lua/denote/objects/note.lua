local utils = require("denote.utils")

---@class Note
---@field id string
---@field title string
---@field date integer
---@field keywords string[]
---@field extension string
local Note = {}

function Note:new(opts)
  opts = opts or {}

  local this = {}
  this.id = opts.id
  this.title = opts.title
  this.keywords = opts.keywords or {}
  this.date = opts.date or os.time()
  this.extension = opts.extension

  setmetatable(this, self)
  self.__index = self
  return this
end

function Note.from_filename(filename)
  filename = vim.fs.basename(filename)
  local id = utils.extract_id(filename)
  return Note:new({
    id = id,
    title = utils.extract_title(filename),
    keywords = utils.extract_keywords(filename),
    date = utils.date_to_time(id),
    extension = utils.get_file_extension(filename),
  })
end

function Note:filename(opts)
  local parts = {
    self.id,
    "--",
    utils.sluggify_name(self.title),
  }

  if #self.keywords > 0 then
    table.insert(parts, "__")
    table.insert(
      parts,
      table.concat(utils.sluggify_keywords(self.keywords, opts.keywords), "_")
    )
  end

  table.insert(parts, self.extension)

  return table.concat(parts)
end

return Note
