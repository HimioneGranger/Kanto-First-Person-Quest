local FILES = {
  "main.lua",
  "jump_button.lua",
  "payload_backdrop.lua",
  "payload_ceiling.lua",
  "payload_flora.lua",
  "payload_jump.lua",
  "payload_sky.lua",
  "transform_birds.lua",
}

function love.load()
  local failed = false
  local report = {}
  local function note(line)
    report[#report + 1] = line
    print(line)
  end
  for _, path in ipairs(FILES) do
    local handle, openErr = io.open(path, "rb")
    if not handle then
      note("FAIL: " .. path .. ": " .. tostring(openErr))
      failed = true
    else
      local source = handle:read("*a")
      handle:close()
      local chunk, syntaxErr = loadstring(source, "@" .. path)
      if not chunk then
        note("FAIL: " .. path .. ": " .. tostring(syntaxErr))
        failed = true
      end
    end
  end
  if not failed then note("PASS: all Kanto Quest Lua files compile") end
  local output = io.open("tools/love_syntax/result.txt", "wb")
  if output then
    output:write(table.concat(report, "\n") .. "\n")
    output:close()
  end
  love.event.quit(failed and 1 or 0)
end
