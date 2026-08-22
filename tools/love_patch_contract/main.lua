local BASE = "mods/DRAMALESS_SHAPE"
local ENGINE_FILES = {
  "main.lua",
  "lib/VoxelScene.lua",
  "lib/FirstPerson.lua",
  "lib/Structures.lua",
  "lib/ChunkMesher.lua",
  "lib/VoxelBattleScene.lua",
  "data/battle_arenas.lua",
}
local PATCHED_ENGINE_FILES = {
  "main.lua",
  "lib/VoxelScene.lua",
  "lib/FirstPerson.lua",
  "lib/Structures.lua",
  "lib/ChunkMesher.lua",
  "lib/VoxelBattleScene.lua",
  "data/battle_arenas.lua",
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
    check(q3.files[BASE .. "/lib/WorldHorizon.lua"] ~= nil,
          "location-aware horizon module was not installed")
    check(q3.files[BASE .. "/lib/horizon-atlas.png"] ~= nil,
          "location-aware horizon atlas was not installed")
    check(q3.files[BASE .. "/lib/Backdrop.lua"]:find(
            "cfg.worldhorizon == true", 1, true) ~= nil,
          "legacy backdrop lacks the disabled-by-default world-card gate")

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
    check(count(battle, "__ds_btl_props") == 1,
          "q6 battle tree-support hook missing or duplicated")
    check(q3.files[BASE .. "/lib/BattleScene.lua"] == nil,
          "patcher fabricated the removed legacy battle file")
    local arenas = assert(q3.files[BASE .. "/data/battle_arenas.lua"])
    check(count(arenas, "__ds_r7_wide") == 1,
          "Route 7 wide-camera override missing or duplicated")
    check(arenas:find(
      '["ROUTE_7"] = { x = 8, y = 8, shape = "narrow", cam = "wide" }',
      1, true), "Route 7 did not select Dramaless's wide rig")
    check(count(arenas, "__ds_r8_wide") == 1,
          "Route 8 wide-camera override missing or duplicated")
    check(arenas:find(
      '["ROUTE_8"] = { x = 25, y = 7, shape = "wide", cam = "wide" }',
      1, true), "Route 8 did not select Dramaless's wide rig")
    check(count(arenas, "__ds_r12_wide") == 1,
          "Route 12 water-arena override missing or duplicated")
    check(arenas:find(
      '["ROUTE_12"] = { x = 10, y = 4, shape = "wide", cam = "wide" }',
      1, true), "Route 12 did not move to the clear water arena")

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
    check(count(battle, "__ds_btl_props") == 1,
          "second boot duplicated the battle tree-support hook")
    arenas = assert(q3.files[BASE .. "/data/battle_arenas.lua"])
    check(count(arenas, "__ds_r7_wide") == 1,
          "second boot duplicated the Route 7 camera override")
    check(count(arenas, "__ds_r8_wide") == 1,
          "second boot duplicated the Route 8 camera override")
    check(count(arenas, "__ds_r12_wide") == 1,
          "second boot duplicated the Route 12 water-arena override")

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
    check(q3.files[BASE .. "/lib/WorldHorizon.lua"] == nil,
          "rollback left the owned world-horizon module installed")
    check(q3.files[BASE .. "/lib/horizon-atlas.png"] == nil,
          "rollback left the owned world-horizon atlas installed")

    -- Recreate an installed q7 state: its battle support plus Route 8 and
    -- Route 12 fixes are active, but Route 7 still uses Dramaless's native
    -- long lens. Prove q8 adds only the Route 7 camera seam through the
    -- maintenance (not fresh-apply) path while retaining the original backup.
    local migrate = fixture("2.0.0-quest.3")
    migrate.run(false)
    local battlePath = BASE .. "/lib/VoxelBattleScene.lua"
    local pristineBattle = migrate.originals["lib/VoxelBattleScene.lua"]
    local arenasPath = BASE .. "/data/battle_arenas.lua"
    local q7Arenas, reverted = migrate.files[arenasPath]:gsub(
      '  %["ROUTE_7"%] = { x = 8, y = 8, shape = "narrow",'
        .. ' cam = "wide" }, %-%- ds_fp_ceilings __ds_r7_wide',
      '  ["ROUTE_7"] = { x = 8, y = 8, shape = "narrow" },', 1)
    check(reverted == 1, "could not construct the installed q7 fixture")
    migrate.files[arenasPath] = q7Arenas
    migrate.run(false)
    check(count(migrate.files[battlePath], "__ds_btl_props") == 1,
          "q7-to-q8 migration disturbed battle tree supports")
    check(migrate.files[battlePath .. ".pre-ceiling"] == pristineBattle,
          "q7-to-q8 migration discarded the pristine battle backup")
    check(count(migrate.files[arenasPath], "__ds_r7_wide") == 1,
          "q7-to-q8 migration did not apply the Route 7 camera override")
    check(count(migrate.files[arenasPath], "__ds_r8_wide") == 1,
          "q7-to-q8 migration disturbed the Route 8 camera override")
    check(count(migrate.files[arenasPath], "__ds_r12_wide") == 1,
          "q7-to-q8 migration disturbed the Route 12 water arena")
    check(migrate.files[arenasPath .. ".pre-ceiling"]
          == migrate.originals["data/battle_arenas.lua"],
          "q6-to-q7 migration did not preserve the arena-data backup")
    migrate.run(false)
    check(count(migrate.files[battlePath], "__ds_btl_props") == 1,
          "q8 migration disturbed the battle hook on a second boot")
    check(count(migrate.files[arenasPath], "__ds_r7_wide") == 1,
          "q8 migration duplicated the Route 7 camera override")
    check(count(migrate.files[arenasPath], "__ds_r8_wide") == 1,
          "q7 migration duplicated the Route 8 camera override")
    check(count(migrate.files[arenasPath], "__ds_r12_wide") == 1,
          "q7 migration duplicated the Route 12 water arena")
    migrate.run(true)
    check(migrate.files[battlePath] == pristineBattle,
          "q7-to-q8 migration broke battle rollback")
    check(migrate.files[battlePath .. ".pre-ceiling"] == nil,
          "explicit rollback left the battle backup behind")
    check(migrate.files[arenasPath]
          == migrate.originals["data/battle_arenas.lua"],
          "q7-to-q8 arena migration broke exact rollback")
    check(migrate.files[arenasPath .. ".pre-ceiling"] == nil,
          "explicit rollback left the arena-data backup behind")

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
