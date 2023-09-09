local File = {}

function File.is_empty(path)
  return not vim.fn.filereadable(path) or vim.fn.getfsize(path) < 1
end

return File
