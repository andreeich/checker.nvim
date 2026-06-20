local M = {}
local parsers = require "checker.parsers"

local function make_absolute(path, cwd)
  if path:sub(1, 1) == "/" then
    return path
  end
  return cwd .. "/" .. path
end

local function find_config()
  local found = vim.fs.find(".checker.json", {
    upward = true,
    path = vim.fn.getcwd(),
    type = "file",
  })
  return found and found[1] or nil
end

local function load_config(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local raw = f:read "*a"
  f:close()
  local ok, entries = pcall(vim.json.decode, raw)
  if not ok or type(entries) ~= "table" then
    vim.notify("checker: failed to parse " .. path, vim.log.levels.ERROR)
    return nil
  end
  return entries
end

function M.run()
  local config_path = find_config()
  if not config_path then
    vim.notify("checker: no .checker.json found", vim.log.levels.WARN)
    return
  end

  local entries = load_config(config_path)
  if not entries or #entries == 0 then
    return
  end

  local valid = {}
  for _, entry in ipairs(entries) do
    local parse = type(entry.parser) == "function" and entry.parser
      or parsers[entry.parser]
    if not parse then
      vim.notify(
        "checker: unknown parser '" .. tostring(entry.parser) .. "'",
        vim.log.levels.ERROR
      )
    else
      table.insert(valid, { cmd = entry.cmd, parse = parse })
    end
  end

  if #valid == 0 then
    return
  end

  local cwd = vim.fn.getcwd()
  local all_results = {}
  local pending = #valid

  vim.notify("checker: running " .. pending .. " check(s)...", vim.log.levels.INFO)

  for _, checker in ipairs(valid) do
    local output = {}
    vim.fn.jobstart(checker.cmd, {
      cwd = cwd,
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          vim.list_extend(output, data)
        end
      end,
      on_stderr = function(_, data)
        if data then
          vim.list_extend(output, data)
        end
      end,
      on_exit = function(_, _code)
        for _, line in ipairs(output) do
          local entry = checker.parse(line)
          if entry then
            entry.filename = make_absolute(entry.filename, cwd)
            table.insert(all_results, entry)
          end
        end

        pending = pending - 1
        if pending == 0 then
          vim.schedule(function()
            vim.fn.setqflist(all_results)
            if #all_results == 0 then
              vim.notify("checker: no errors", vim.log.levels.INFO)
            else
              vim.cmd "copen"
              vim.notify(
                "checker: " .. #all_results .. " error(s)",
                vim.log.levels.WARN
              )
            end
          end)
        end
      end,
    })
  end
end

return M
