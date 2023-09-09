local ft = require("denote.filetypes")

local M = {}

M.options = {
  directory = "~/denote",
  filetype = "org",
  filetypes = {
    -- org = {
    --   extension = ft.org.extension,
    --   date = ft.org.date,
    --   front_matter = ft.org.front_matter,
    -- },
  },
  formats = {
    date = nil,
  },
  keywords = {
    sort = true,
    multi_word = true,
  },
  templates = {},
}

return M
