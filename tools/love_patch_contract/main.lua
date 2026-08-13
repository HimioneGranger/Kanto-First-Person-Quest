local BASE = "mods/DRAMALESS_SHAPE"
local ENGINE_FILES = {
  "main.lua",
  "lib/VoxelScene.lua",
  "lib/FirstPerson.lua",
  "lib/Structures.lua",
  "lib/ChunkMesher.lua",
  "lib/VoxelBattleScene.lua",
}
local PATCHED_ENGINE_FILES = {
  "main.lua",
  "lib/VoxelScene.lua",
  "lib/FirstPerson.lua",
  "lib/Structures.lua",
  "lib/ChunkMesher.lua",
}

local function hostRead(path)
  local handle, err = io.open(path, "rb")
  if not handle then return nil, err end
  local data = handle:read("*a")
  handle:close()
  return data
end

local function fail(message)
  error("PATCH CONTRACT: " .. message, 0)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local function injectQ4BattleProps(source)
  source = source:gsub("\r\n", "\n")
  local anchor = "    Voxel3D.draw(terrain, atlasFor(host), nil)\n"
  local first, last = source:find(anchor, 1, true)
  check(first ~= nil, "q4 migration fixture lost its battle anchor")
  local block = anchor
    .. "    -- ds_fp_ceilings __ds_btl_props\n"
    .. "    pcall(function()\n"
    .. "      local live = rawget(_G, \"__ds_live\")\n"
    .. "      if live and live.Flora and live.Flora.battleProps then\n"
    .. "        live.Flora.battleProps(host, neighbors)\n"
    .. "      end\n"
    .. "    end)\n"
  return source:sub(1, first - 1) .. block .. source:sub(last + 1)
end

local function count(text, needle)
  local n, pos = 0, 1
  while true do
    local at = text:find(needle, pos, true)
    if not at then return n end
    n, pos = n + 1, at + #needle
  end
end

local function firstDifference(a, b)
  if not a or not b then return -1 end
  local limit = math.min(#a, #b)
  for i = 1, limit do
    if a:byte(i) ~= b:byte(i) then return i end
  end
  if #a ~= #b then return limit + 1 end
  return 0
end

local function fixture(version)
  local root = assert(os.getenv("KANTO_TEST_DRAMALESS"),
                      "KANTO_TEST_DRAMALESS is required")
  local files, originals, writes, removes = {}, {}, {}, {}
  for _, rel in ipairs(ENGINE_FILES) do
    local data = assert(hostRead(root .. "/" .. rel))
    files[BASE .. "/" .. rel] = data
    originals[rel] = data
  end
  local manifest = assert(hostRead(root .. "/manifest.json"))
  manifest = manifest:gsub('"version"%s*:%s*"[^"]+"',
                           '"version": "' .. version .. '"', 1)
  files[BASE .. "/manifest.json"] = manifest

  local fs = {}
  function fs.read(path) return files[path] end
  function fs.write(path, data)
    files[path] = data
    writes[path] = (writes[path] or 0) + 1
    return true
  end
  function fs.remove(path)
    files[path] = nil
    removes[path] = (removes[path] or 0) + 1
    return true
  end
  function fs.createDirectory() return true end
  function fs.getDirectoryItems(path)
    if path == "mods" then return { "DRAMALESS_SHAPE" } end
    return {}
  end
  function fs.getRealDirectory(path)
    if files[path] ~= nil then return "TEST_SAVE" end
    return nil
  end
  function fs.getSaveDirectory() return "TEST_SAVE" end
  love.filesystem = fs

  local defaults, remove = {}, false
  local options = {}
  function options:define(rows)
    for _, row in ipairs(rows or {}) do
      if row.key and defaults[row.key] == nil then defaults[row.key] = row.default end
    end
  end
  function options:get(key)
    if key == "remove" then return remove end
    return defaults[key]
  end

  local mod = {
    exports = {},
    options = options,
    hooks = { wrap = function() end },
    content = { render_pipelines = { register = function() end } },
    log = { info = function() end, warn = function() end,
            error = function() end },
  }
  function mod:read(path) return hostRead(path) end

  local function run(removePatch)
    remove = removePatch and true or false
    local chunk = assert(loadfile("main.lua"))
    local init = assert(chunk())
    init(mod)
  end

  return {
    files = files,
    originals = originals,
    writes = writes,
    removes = removes,
    run = run,
  }
end

function love.load()
  local ok, err = pcall(function()
    local q3 = fixture("2.0.0-quest.3")
    q3.run(false)

    local scene = assert(q3.files[BASE .. "/lib/VoxelScene.lua"])
    check(count(scene, "pcall(Backdrop.draw, state)") == 1,
          "backdrop draw not applied exactly once")
    check(count(scene, "pcall(Ceiling.draw, state, atlasFor)") == 1,
          "ceiling draw not applied exactly once")
    check(scene:find("withinRenderDistance", 1, true),
          "Dramaless 2.0 neighbour culling was removed")
    check(scene:find("Mat4.translate(nb.ox, 0, nb.oy)", 1, true)
          < scene:find("pcall(Ceiling.draw, state, atlasFor)", 1, true),
          "ceiling/flora precede neighbour terrain")

    local first = assert(q3.files[BASE .. "/lib/FirstPerson.lua"])
    check(count(first, "Jump.eyeOffset") == 1, "jump eye patch missing/duplicated")
    check(count(first, "Jump.swayX") == 1, "jump X patch missing/duplicated")
    check(count(first, "Jump.swayZ") == 1, "jump Z patch missing/duplicated")

    local structures = assert(q3.files[BASE .. "/lib/Structures.lua"])
    check(structures:find("__ds_tree_lift", 1, true), "tree lift missing")
    check(structures:find("__ds_round_tomb", 1, true), "tree tombstone missing")
    local mesher = assert(q3.files[BASE .. "/lib/ChunkMesher.lua"])
    check(mesher:find("__ds_round_mapkey", 1, true), "tree base map key missing")
    check(mesher:find("fastchunks", 1, true), "fast-chunk patch missing")
    local battle = assert(q3.files[BASE .. "/lib/VoxelBattleScene.lua"])
    check(battle == q3.originals["lib/VoxelBattleScene.lua"],
          "fresh q5 modified Dramaless 2.0's native battle provider")
    check(not battle:find("__ds_btl_props", 1, true),
          "fresh q5 injected the retired 2.0 battle hook")
    check(q3.files[BASE .. "/lib/VoxelBattleScene.lua.pre-ceiling"] == nil,
          "fresh q5 backed up an untouched 2.0 battle provider")
    check(q3.files[BASE .. "/lib/BattleScene.lua"] == nil,
          "patcher fabricated the removed legacy battle file")

    for _, rel in ipairs(PATCHED_ENGINE_FILES) do
      local pre = q3.files[BASE .. "/" .. rel .. ".pre-ceiling"]
      check(pre == q3.originals[rel],
            rel .. " lacks an exact pristine backup"
            .. " (backup=" .. tostring(pre ~= nil)
            .. ", sourceChanged="
            .. tostring(q3.files[BASE .. "/" .. rel] ~= q3.originals[rel])
            .. ", writes="
            .. tostring(q3.writes[BASE .. "/" .. rel .. ".pre-ceiling"])
            .. ", backupLen=" .. tostring(pre and #pre)
            .. ", originalLen=" .. tostring(#q3.originals[rel])
            .. ", firstDiff=" .. tostring(firstDifference(pre, q3.originals[rel]))
            .. ")")
    end

    -- A second enabled boot is idempotent: every marker remains singular.
    q3.run(false)
    scene = assert(q3.files[BASE .. "/lib/VoxelScene.lua"])
    check(count(scene, "pcall(Backdrop.draw, state)") == 1,
          "second boot duplicated scene layers")
    battle = assert(q3.files[BASE .. "/lib/VoxelBattleScene.lua"])
    check(battle == q3.originals["lib/VoxelBattleScene.lua"],
          "second boot modified Dramaless 2.0's native battle provider")

    -- Explicit removal restores every base-owned source byte-for-byte.
    q3.run(true)
    for _, rel in ipairs(ENGINE_FILES) do
      local restored = q3.files[BASE .. "/" .. rel]
      check(restored == q3.originals[rel],
            rel .. " did not roll back exactly"
            .. " (restoredLen=" .. tostring(restored and #restored)
            .. ", originalLen=" .. tostring(#q3.originals[rel])
            .. ", firstDiff="
            .. tostring(firstDifference(restored, q3.originals[rel])) .. ")")
    end

    -- Upgrading an existing q4 install strips only q4's exact marked flora
    -- call. The pristine backup stays available until explicit REMOVE PATCH.
    local migrate = fixture("2.0.0-quest.3")
    migrate.run(false)
    local battlePath = BASE .. "/lib/VoxelBattleScene.lua"
    local pristineBattle = migrate.originals["lib/VoxelBattleScene.lua"]
    local nativeBattle = pristineBattle:gsub("\r\n", "\n")
    migrate.files[battlePath] = injectQ4BattleProps(pristineBattle)
    migrate.files[battlePath .. ".pre-ceiling"] = pristineBattle
    migrate.files["ds_fp_ceiling_written.txt"] =
      (migrate.files["ds_fp_ceiling_written.txt"] or "")
      .. battlePath .. "\n"
    migrate.run(false)
    check(migrate.files[battlePath] == nativeBattle,
          "q5 did not strip q4's battle flora block exactly")
    check(migrate.files[battlePath .. ".pre-ceiling"] == pristineBattle,
          "q5 discarded q4's pristine battle rollback backup")
    migrate.run(false)
    check(migrate.files[battlePath] == nativeBattle,
          "q5 battle cleanup is not idempotent")
    migrate.run(true)
    check(migrate.files[battlePath] == pristineBattle,
          "q4-to-q5 battle cleanup broke explicit rollback")
    check(migrate.files[battlePath .. ".pre-ceiling"] == nil,
          "explicit rollback left the q4 battle backup behind")

    -- Unknown versions may log outside the base but must not touch base files.
    local future = fixture("2.0.1-quest.0")
    future.run(false)
    for _, rel in ipairs(ENGINE_FILES) do
      check(future.files[BASE .. "/" .. rel] == future.originals[rel],
            "unknown version modified " .. rel)
      check(future.writes[BASE .. "/" .. rel] == nil,
            "unknown version wrote " .. rel)
    end
  end)

  local report
  if ok then
    report = "PASS: live Kanto patch/apply/idempotence/rollback/refusal contract"
    print(report)
    local output = io.open("tools/love_patch_contract/result.txt", "wb")
    if output then output:write(report .. "\n"); output:close() end
    love.event.quit(0)
  else
    report = tostring(err)
    print(report)
    local output = io.open("tools/love_patch_contract/result.txt", "wb")
    if output then output:write(report .. "\n"); output:close() end
    love.event.quit(1)
  end
end
