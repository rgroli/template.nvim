local temp = {}
local uv = vim.loop
local api = vim.api
local fn = vim.fn
temp.temp_dir = ''
temp.author = ''
temp.email = ''

--@private
local function get_template(dir)
  return vim.split(fn.globpath(dir,'*'),'\n')
end

function temp.get_temp_list()
  local all_temps = vim.split(fn.globpath(temp.temp_dir,'*/*'),'\n')
  local list = {}
  for _,v in pairs(all_temps) do
    v = v:sub(#temp.temp_dir, -1)
    local ft,tp = unpack(vim.split(v,'/',{trimempty = true }))
    if list[ft] == nil then
      list[ft] = {}
    end
    tp = tp:gsub('%.%w+',"")
    table.insert(list[ft],tp)
  end
  return list
end

local expr = {
'{{_date_}}', '{{_cursor_}}','{{_file_name_}}','{{_author_}}','{{_email_}}'
}

local expand_expr = {
  [expr[1]] = function(line)
    local date = os.date('%Y-%m-%d %H:%M:%S')
    return line:gsub(expr[1],date)
  end,
  [expr[2]] = function(line)
    return line:gsub(expr[2],"")
  end,
  [expr[3]] = function(line)
    local file_name = vim.fn.expand('%:t:r')
    return line:gsub(expr[3],file_name)
  end,
  [expr[4]] = function(line)
    return line:gsub(expr[4],temp.author)
  end,
  [expr[5]] = function(line)
    return line:gsub(expr[5],temp.email)
  end
}

local is_windows = vim.loop.os_uname().sysname == "Windows"
local sep = is_windows and '\\' or '/'

local function create_and_load(file)
  local current_path = vim.fn.getcwd()
  file = current_path .. sep .. file
  local ok, fd = pcall(uv.fs_open, file, "w", 420)
  if not ok then
    vim.notify("Couldn't create file " .. file)
    return
  end
  uv.fs_close(fd)

  vim.cmd(':e ' .. file)
end

function temp:generate_template(params)
  local param_list = vim.split(params,' ')
  local param

  if #param_list > 1 then
    create_and_load(param_list[1])
    param = param_list[2]
  else
    param = params
  end

  local current_buf = api.nvim_get_current_buf()
  local dir = self.temp_dir .. vim.bo.filetype
  local temps = get_template(dir)
  local index = 0

  for i,file in pairs(temps) do
    if file:find(param) then
      index = i
      break
    end
  end

  local lines = {}
  local cursor_pos = {}
  local lnum = 0

  for line in io.lines(temps[index]) do
    lnum = lnum + 1
    for idx,key in pairs(expr) do
      if line:find(key) then
        line = expand_expr[expr[idx]](line)

        if idx == 2 then
          cursor_pos = { lnum , 2}
        end
      end
    end
    table.insert(lines,line)
  end

  if vim.fn.line2byte('$') ~= -1 then
    local content = api.nvim_buf_get_lines(current_buf,0,-1,false)
    for _,line in pairs(content) do
      table.insert(lines,line)
    end
  end

  api.nvim_buf_set_lines(current_buf,0,-1,false,lines)

  if next(cursor_pos) ~= nil then
    api.nvim_win_set_cursor(0,cursor_pos)
    vim.cmd('startinsert!')
  end
end

function temp.get_all_temps()
  return vim.split(fn.globpath(temp.temp_dir,'*/*'),'\n')
end

return temp