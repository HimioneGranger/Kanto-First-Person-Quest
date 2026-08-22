local function finish(ok, message)
  local report = (ok and "PASS: " or "FAIL: ") .. message
  local output = io.open("tools/love_archive_mount/result.txt", "wb")
  if output then output:write(report .. "\n"); output:close() end
  print(report)
  love.event.quit(ok and 0 or 1)
end

function love.load()
  local path = assert(os.getenv("KANTO_TEST_ARCHIVE"),
                      "KANTO_TEST_ARCHIVE is required")
  local handle, openErr = io.open(path, "rb")
  if not handle then return finish(false, tostring(openErr)) end
  local data = handle:read("*a")
  handle:close()
  local fd = love.filesystem.newFileData(data, "kanto_test.zip")
  if not fd then return finish(false, "newFileData failed") end
  if not love.filesystem.mount(fd, "kanto_mount") then
    return finish(false, "PhysicsFS in-memory mount failed")
  end
  local root = "kanto_mount"
  if not love.filesystem.getInfo(root .. "/manifest.json", "file") then
    local items = love.filesystem.getDirectoryItems(root) or {}
    if #items == 1 then root = root .. "/" .. items[1] end
  end
  local manifest = love.filesystem.read(root .. "/manifest.json")
  local worldModule = love.filesystem.getInfo(
    root .. "/payload_world_horizon.lua", "file")
  local worldAtlas = love.filesystem.getInfo(root .. "/horizon-atlas.png", "file")
  love.filesystem.unmount(fd)
  if not manifest or not manifest:find('"id"%s*:%s*"ds_fp_ceiling"') then
    return finish(false, "mounted archive has no Kanto manifest")
  end
  if not (worldModule and worldAtlas) then
    return finish(false, "mounted archive lacks world-horizon runtime assets")
  end
  finish(true, "PhysicsFS mounted Kanto archive, manifest and horizon assets")
end
