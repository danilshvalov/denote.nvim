local const = require("denote.const")
local utf8 = require("denote.utf8")

local M = {}

function M.generate_id()
  return os.date(const.id.format)
end

function M.capitalize(str)
  return utf8.gsub(str, "^%l", utf8.upper)
end

function M.sluggify_name(str)
  str = utf8.gsub(str, "%p+", " ")
  str = utf8.gsub(str, "[%s_]+", "-")
  str = utf8.gsub(str, "%-%-+", "-")
  str = utf8.gsub(str, "^-", "")
  str = utf8.gsub(str, "-$", "")
  str = utf8.lower(str)
  return str
end

function M.sluggify_name_and_join(str)
  str = M.sluggify_name(str)
  str = utf8.gsub(str, "%-*", "")
  return str
end

function M.sluggify_signature(str)
  str = utf8.gsub(str, "%p+", " ")
  str = utf8.gsub(str, "[%s_]+", "=")
  str = utf8.gsub(str, "%=%=+", "=")
  str = utf8.gsub(str, "^=", "")
  str = utf8.gsub(str, "=$", "")
  str = utf8.lower(str)
  return str
end

function M.sluggify_keywords(keywords, opts)
  opts = opts or {}
  return vim
    .iter(keywords)
    :map(opts.multi_word and M.sluggify_name or M.sluggify_name_and_join)
    :totable()
end

function M.desluggify(str)
  str = M.capitalize(str)
  str = utf8.gsub(str, "%-+", " ")
  return str
end

function M.extract_id(str)
  return utf8.match(str, const.id.regexp)
end

function M.date_to_time(str)
  local pattern = "(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)"
  local year, month, day, hour, min, sec = str:match(pattern)
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = min,
    sec = sec,
  })
end

function M.extract_title(filename)
  return M.desluggify(utf8.match(filename, "%-%-([^_.]+)"))
end

---@param filename string
---@return string[]
function M.extract_keywords(filename)
  return vim.split(utf8.match(filename, "__([^.]+)"), "_", { trimempty = true })
end

function M.is_note(path)
  path = vim.fs.normalize(path)
  local filename = vim.fs.basename(path) or ""
  return vim.fn.isdirectory(path) == 0
    and vim.fn.filereadable(path) == 1
    and utf8.match(filename, "^" .. const.id.regexp) ~= nil
end

function M.remove_duplicates(values)
  local seen = {}
  local result = {}
  for _, value in ipairs(values) do
    if not seen[value] then
      table.insert(result, value)
    end
    seen[value] = true
  end
  return result
end

return M
