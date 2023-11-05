local async = require("denote.async")
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

local read_input = async.wrap(vim.ui.input)

local select_item = async.wrap(vim.ui.select)

local function read_keywords(note)
  local keywords = read_input({ prompt = "Enter keywords: " })
  if not keywords then
    return
  end

  note.keywords = vim.list_extend(
    note.keywords or {},
    vim
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
  )

  note.keywords = utils.remove_duplicates(note.keywords)

  if options.keywords.sort then
    table.sort(note.keywords)
  end

  return true
end

---@type fun(note: Note)[]
local handlers = {
  function(note)
    local title = read_input({ prompt = "Enter title: " })
    if not title then
      return
    end

    note.title = vim.trim(title)
    return true
  end,
  read_keywords,
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

local function select_file(files)
  local titles = vim.iter(files):map(utils.extract_title):totable()

  local max_length = 0
  for index, title in ipairs(titles) do
    max_length =
      math.max(max_length, utf8.len(title) + math.ceil(math.sqrt(index)))
  end

  return select_item(files, {
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
  })
end

function M.select_note()
  async.run(function()
    local files = M.get_files()
    local titles = vim.iter(files):map(utils.extract_title):totable()

    local find_offset = function(number)
      local result = 0
      while number >= 10 do
        number = number / 10
        result = result + 1
      end
      return result
    end

    local max_length = 0
    for index, title in ipairs(titles) do
      max_length = math.max(max_length, utf8.len(title) + find_offset(index))
    end

    local index = 0
    local filename = select_item(files, {
      prompt = "Select note: ",
      format_item = function(filename)
        index = index + 1
        local title = utils.extract_title(filename)
        vim.print(title, index)
        title = title
          .. string.rep(" ", max_length - utf8.len(title) - find_offset(index))

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
    })

    if filename then
      vim.cmd.edit(vim.fs.joinpath(options.directory, filename))
    end
  end)
end

function M.make_filename(note)
  return note:filename({ keywords = options.keywords })
end

function M.new_note()
  return async.run(function()
    local note = M.read_note_data()
    if not note then
      return
    end

    note.extension = ".org"

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

local function get_ts_matches(root, query, buffer)
  local matches = {}
  for _, match, _ in query:iter_matches(root, buffer) do
    local items = {}
    for id, matched_node in pairs(match) do
      local name = query.captures[id]
      local text = vim.treesitter.get_node_text(matched_node, buffer)
      items[name] = {
        node = matched_node,
        text = text,
      }
    end
    table.insert(matches, items)
  end
  return matches
end

local function update_keywords(note)
  -- local tree = vim.treesitter.get_parser(0, "org"):parse()[1]
  -- local query = vim.treesitter.query.parse(
  --   "org",
  --   "(directive name: (expr) @name value: (value) @value)"
  -- )

  -- local matches = get_ts_matches(tree:root(), query, 0)

  -- for _, match in ipairs(matches) do
  --   if match.name.text == "filetags" then
  --     local start_row, start_col, end_row, end_col = match.value.node:range()
  --     vim.api.nvim_buf_set_text(
  --       0,
  --       start_row,
  --       start_col,
  --       end_row,
  --       end_col,
  --       { org.fields.keywords.serialize(note) }
  --     )
  --   end
  -- end

  local serializer = Serializer:new({
    note = note,
    fields = org.fields,
  })

  local filename = M.make_filename(note)
  local path = vim.fs.joinpath(options.directory, filename)

  vim.cmd.edit(path)

  local lines = org.front_matter(serializer)
  vim.api.nvim_buf_set_lines(0, 0, #lines, false, lines)
end

local function rename_note(old_filename, new_filename)
  vim.uv.fs_rename(
    vim.fs.normalize(vim.fs.joinpath(options.directory, old_filename)),
    vim.fs.normalize(vim.fs.joinpath(options.directory, new_filename))
  )
  vim.cmd.edit(vim.fs.joinpath(options.directory, new_filename))
end

function M.add_keyword()
  async.run(function()
    local path = vim.api.nvim_buf_get_name(0)
    if not utils.is_note(path) then
      vim.print("Not a Denote file")
      return
    end

    local note = Note.from_filename(path)
    local old_filename = note:filename({ keywords = options.keywords })

    read_keywords(note)

    local new_filename = note:filename({ keywords = options.keywords })
    rename_note(old_filename, new_filename)

    update_keywords(note)
    vim.cmd.write()
  end)
end

function M.remove_keyword()
  local path = vim.api.nvim_buf_get_name(0)
  if not utils.is_note(path) then
    vim.print("Not a Denote file")
    return
  end

  local note = Note.from_filename(path)
  if #note.keywords == 0 then
    return
  end

  local old_filename = note:filename({ keywords = options.keywords })

  async.run(function()
    local keyword = select_item(note.keywords, { prompt = "Select keywords" })
    if not keyword then
      return
    end

    note.keywords = vim
      .iter(note.keywords)
      :filter(function(value)
        return value ~= keyword
      end)
      :totable()

    local new_filename = note:filename({ keywords = options.keywords })
    rename_note(old_filename, new_filename)

    update_keywords(note)
    vim.cmd.write()
  end)
end

function M.get_link_under_cursor()
  local found_link = nil
  local links = {}
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  for url, text in line:gmatch("%[%[(.-)%]%[(.-)%]%]") do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find("%[%[(.-)%]%[(.-)%]%]", start_from)
    if col >= from and col <= to then
      found_link = { url = url, text = text, from = from, to = to }
      break
    end
    table.insert(links, { url = url, text = text, from = from, to = to })
  end
  return found_link
end

function M.goto_link_under_cursor()
  local link = M.get_link_under_cursor()
  if not link then
    return
  end

  local id = vim.split(link.url, ":")[2]
  local filename = vim.iter(M.get_files()):find(function(filename)
    return utils.extract_id(filename) == id
  end)
  if not filename then
    return
  end

  vim.cmd.edit(vim.fs.joinpath(options.directory, filename))
end

function M.create_link()
  async.run(function()
    local path = vim.api.nvim_buf_get_name(0)
    if not utils.is_note(path) then
      vim.print("Not a Denote file")
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local files = vim
      .iter(M.get_files())
      :filter(function(filename)
        return filename ~= vim.fs.basename(path)
      end)
      :totable()

    local filename = select_file(files)
    if not filename then
      return
    end

    vim.api.nvim_buf_set_text(
      0,
      cursor[1] - 1,
      cursor[2],
      cursor[1] - 1,
      cursor[2],
      {
        string.format(
          "[[denote:%s][%s]]",
          utils.extract_id(filename),
          utils.extract_title(filename)
        ),
      }
    )
  end)
end

return M
