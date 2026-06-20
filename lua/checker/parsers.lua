local M = {}

-- src/foo.ts(10,5): error TS2345: message
M.tsc = function(line)
  local file, row, col, kind, msg =
    line:match "^(.+)%((%d+),(%d+)%): (%a+) TS%d+: (.+)"
  if not file then
    return nil
  end
  return {
    filename = file,
    lnum = tonumber(row),
    col = tonumber(col),
    text = msg,
    type = kind == "error" and "E" or "W",
  }
end

-- eslint --format unix: /path/file.ts:10:5: message [Error/rule]
M.eslint = function(line)
  local file, row, col, msg = line:match "^(.+):(%d+):(%d+): (.+)"
  if not file then
    return nil
  end
  local bracket = msg:match "%[(%a+)/"
  local type = (bracket and bracket:lower() == "error") and "E" or "W"
  return {
    filename = file,
    lnum = tonumber(row),
    col = tonumber(col),
    text = msg,
    type = type,
  }
end

return M
