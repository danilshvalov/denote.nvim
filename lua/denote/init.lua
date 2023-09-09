local async = require("plenary.async")
local const = require("denote.const")
local options = require("denote.config").options
local utils = require("denote.utils")
local utf8 = require("denote.utf8")
local Note = require("denote.objects.note")
local org = require("denote.filetypes.org")
local Serializer = require("denote.objects.serializer")

local M = {}

function M.get_files()
  return vim
    .iter(vim.fs.dir(options.directory, { depth = 1000 }))
    :filter(function(_, type)
      return type == "file"
    end)
    :map(function(filename, _)
      return filename
    end)
    :filter(function(filename)
      return utils.is_note(vim.fs.joinpath(options.directory, filename))
    end)
    :totable()
end

local read_input = async.wrap(vim.ui.input, 2)

---@type fun(note: Note)[]
local handlers = {
  function(note)
    local title = read_input({ prompt = "Note title: " })
    if not title then
      return
    end

    note.title = vim.trim(title)
    return true
  end,
  function(note)
    local keywords = read_input({ prompt = "Note keywords: " })
    if not keywords then
      return
    end

    note.keywords = vim
      .iter(vim.split(keywords, ",", { trimempty = true }))
      :map(function(value)
        value = utf8.gsub(value, "%p+", "")
        value = vim.trim(value)
        return value
      end)
      :filter(function(value)
        return #value > 0
      end)
      :totable()

    note.keywords = utils.remove_duplicates(note.keywords)

    if options.keywords.sort then
      table.sort(note.keywords)
    end

    return true
  end,
}

function M.read_note_data()
  local note = Note:new()

  note.id = utils.generate_id()
  note.date = os.time()

  for _, handler in ipairs(handlers) do
    if not handler(note) then
      return
    end
  end

  return note
end

function M.select_note()
  local files = M.get_files()
  local titles = vim.iter(files):map(utils.extract_title):totable()

  local max_length = 0
  for _, title in ipairs(titles) do
    max_length = math.max(max_length, utf8.len(title))
  end

  vim.ui.select(files, {
    prompt = "Select note: ",
    format_item = function(filename)
      local title = utils.extract_title(filename)
      title = title .. string.rep(" ", max_length - utf8.len(title))

      local keywords = table.concat(
        vim
          .iter(utils.extract_keywords(filename))
          :map(function(value)
            return "#" .. value
          end)
          :totable(),
        " "
      )

      return title .. "  " .. keywords
    end,
  }, function(filename)
    if filename then
      vim.cmd.edit(vim.fs.joinpath(options.directory, filename))
    end
  end)
end

function M.make_filename(note)
  local parts = {
    note.id,
    "--",
    utils.sluggify_name(note.title),
  }

  if #note.keywords > 0 then
    table.insert(parts, "__")
    table.insert(
      parts,
      table.concat(
        utils.sluggify_keywords(note.keywords, options.keywords),
        "_"
      )
    )
  end

  table.insert(parts, ".org")

  return table.concat(parts)
end

function M.new_note()
  return async.run(function()
    local note = M.read_note_data()
    if not note then
      return
    end

    local serializer = Serializer:new({
      note = note,
      fields = org.fields,
    })

    local filename = M.make_filename(note)
    local path = vim.fs.joinpath(options.directory, filename)

    vim.cmd.edit(path)

    local lines = org.front_matter(serializer)
    vim.api.nvim_buf_set_lines(0, 0, 1, true, lines)
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
  end)
end

return M
