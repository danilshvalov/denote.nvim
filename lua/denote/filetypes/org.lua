local utf8 = require("denote.utf8")
local options = require("denote.config").options
local utils = require("denote.utils")

local function match_tag(str, tag_name)
  return utf8.match(str, "^#%+" .. tag_name .. "%s*:") ~= nil
end

---@class FieldSpec
---@field match fun(line: string): boolean
---@field serialize fun(note: Note): string
---@field parse fun(note: Note, data: string): Note

---@class Spec
---@field front_matter fun(serializer: Serializer): string[]
---@field fields table<string, FieldSpec>
return {
  extension = "org",
  front_matter = function(serializer)
    return {
      "#+title:      " .. serializer:title(),
      "#+date:       " .. serializer:date(),
      "#+filetags:   " .. serializer:keywords(),
      "#+identifier: " .. serializer:id(),
      "",
    }
  end,
  fields = {
    id = {
      serialize = function(note)
        return note.id
      end,
    },
    date = {
      serialize = function(note)
        return tostring(os.date("[%F %a %R]", note.date))
      end,
    },
    title = {
      match = function(line)
        return match_tag(line, "title")
      end,
      serialize = function(note)
        return note.title
      end,
      parse = function(note, title)
        note.title = vim.trim(title)
        return note
      end,
    },
    keywords = {
      match = function(line)
        return match_tag(line, "filetags")
      end,
      serialize = function(note)
        local keywords = note.keywords
        if #keywords == 0 then
          return ""
        end
        return ":"
          .. table.concat(
            utils.sluggify_keywords(keywords, options.keywords),
            ":"
          )
          .. ":"
      end,
      parse = function(note, keywords)
        note.keywords = vim.split(keywords, ":", { trimempty = true })
        return note
      end,
    },
    link = {
      serialize = function(note)
        return utf8.format("[[denote:%s][%s]]", note.id, note.title)
      end,
    },
  },
}
