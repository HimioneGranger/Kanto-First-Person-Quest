-- Location-aware horizon cards for Kanto in First Person.
-- payload-version: 1
--
-- This is deliberately a small first slice.  The accepted panorama remains
-- underneath as a safe fallback; this module adds only original-art landmark
-- cards whose bearings come from Gen1Recomp's imported Town Map coordinates.
-- Nothing is built per eye or per frame: one atlas, one quad, and a bounded
-- list of at most eight cards.

local V = ...

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")

local WorldHorizon = {}

WorldHorizon.TRANSITION_SECONDS = 0.6
WorldHorizon.MAX_VISIBLE = 8
WorldHorizon.ATLAS_WIDTH = 2048
WorldHorizon.ATLAS_HEIGHT = 512
WorldHorizon.ATLAS_BYTES = 2048 * 512 * 4

local RADIUS = 880       -- just inside the accepted panorama at r=900
local Y_BOTTOM = -1

-- The atlas starts with one approved card.  Future cards occupy the unused
-- transparent quarter without increasing the Quest texture allocation.
local CARD_TYPES = {
  forest = {
    u0 = 0, v0 = 0, u1 = 0.75, v1 = 1,
    width = 480, height = 160,
  },
}

local LANDMARKS = {
  { id = "viridian-forest", mapId = "VIRIDIAN_FOREST",
    card = "forest", maxDistance = 8 },
}

local atlasImage, atlasFailed = nil, false
local meshes = {}
local transition = { mapId = nil, from = nil, to = nil, started = 0 }
local stereo = { pending = false, mapId = nil, anchor = nil }

local function status(message)
  _G.__ds_world_horizon_status = message
end

local function copyPoint(p)
  return p and { x = p.x, y = p.y } or nil
end

local function clamp(n, low, high)
  return math.max(low, math.min(high, n))
end

local function nowSeconds()
  if love and love.timer and love.timer.getTime then
    local ok, n = pcall(love.timer.getTime)
    if ok and type(n) == "number" then return n end
  end
  return os.clock()
end

-- Matches Gen1Recomp's TownMap.entryCoords contract: current extractors nest
-- entries under .locations, while API patches may expose the map directly;
-- an entry may store x/y, col/row, or a nested coords table.
function WorldHorizon.coordsFor(data, mapId)
  local field = type(data) == "table" and data.field or nil
  local townMap = type(field) == "table" and field.townMap or nil
  if type(townMap) ~= "table" then return nil end
  local locations = type(townMap.locations) == "table"
                    and townMap.locations or townMap
  local entry = type(locations) == "table" and locations[mapId] or nil
  if type(entry) ~= "table" then return nil end
  local c = type(entry.coords) == "table" and entry.coords or entry
  local x = tonumber(c.x or c.col)
  local y = tonumber(c.y or c.row)
  if not (x and y) then return nil end
  return { x = x, y = y }
end

-- Zero is north, +pi/2 east, pi south and -pi/2 west.  World-space +X is
-- east and +Z is south, so this bearing never depends on gaze or recentering.
function WorldHorizon.bearing(viewer, landmark)
  if not (viewer and landmark) then return nil end
  local east = landmark.x - viewer.x
  local north = viewer.y - landmark.y
  if east == 0 and north == 0 then return 0 end
  return math.atan2(east, north)
end

function WorldHorizon.distance(viewer, landmark)
  if not (viewer and landmark) then return nil end
  local dx, dy = landmark.x - viewer.x, landmark.y - viewer.y
  return math.sqrt(dx * dx + dy * dy)
end

local function lerpPoint(a, b, t)
  local s = t * t * (3 - 2 * t) -- smoothstep, with no velocity snap at ends
  return { x = a.x + (b.x - a.x) * s,
           y = a.y + (b.y - a.y) * s }
end

local function currentTransitionAnchor(now)
  if not transition.to then return nil end
  if not transition.from then return copyPoint(transition.to) end
  local t = clamp((now - transition.started)
                  / WorldHorizon.TRANSITION_SECONDS, 0, 1)
  if t >= 1 then
    transition.from = nil
    return copyPoint(transition.to)
  end
  return lerpPoint(transition.from, transition.to, t)
end

-- Resolve once per logical view.  A map change starts from the interpolated
-- position already on screen, so an interrupted transition cannot jump.
function WorldHorizon.transitionAnchor(data, mapId, now)
  now = tonumber(now) or nowSeconds()
  local target = WorldHorizon.coordsFor(data, mapId)
  if not target then
    transition = { mapId = nil, from = nil, to = nil, started = now }
    stereo.pending = false
    return nil
  end
  if transition.mapId == nil then
    transition = { mapId = mapId, from = nil,
                   to = copyPoint(target), started = now }
  elseif transition.mapId ~= mapId then
    local visible = currentTransitionAnchor(now) or copyPoint(transition.to)
    transition = { mapId = mapId, from = visible,
                   to = copyPoint(target), started = now }
  else
    -- A content patch may correct coordinates while the map remains loaded.
    -- Treat that like a destination change instead of teleporting the card.
    if transition.to.x ~= target.x or transition.to.y ~= target.y then
      local visible = currentTransitionAnchor(now) or copyPoint(transition.to)
      transition = { mapId = mapId, from = visible,
                     to = copyPoint(target), started = now }
    end
  end
  return currentTransitionAnchor(now)
end

-- VoxelScene calls Backdrop.draw once for each OpenXR eye.  The first eye
-- advances the transition and the second reuses that exact anchor, preventing
-- a tiny left/right transform disagreement.  Non-VR draws advance normally.
function WorldHorizon.anchorForDraw(data, mapId, now)
  local cam = Voxel3D.camera
  local isStereo = type(cam) == "table" and cam.view ~= nil and cam.proj ~= nil
  if isStereo and stereo.pending and stereo.mapId == mapId and stereo.anchor then
    stereo.pending = false
    return copyPoint(stereo.anchor)
  end
  local anchor = WorldHorizon.transitionAnchor(data, mapId, now)
  if isStereo and anchor then
    stereo = { pending = true, mapId = mapId, anchor = copyPoint(anchor) }
  else
    stereo.pending = false
  end
  return anchor
end

function WorldHorizon.cardsFor(data, viewer)
  local out = {}
  if not viewer then return out end
  for _, landmark in ipairs(LANDMARKS) do
    local at = WorldHorizon.coordsFor(data, landmark.mapId)
    local d = at and WorldHorizon.distance(viewer, at) or nil
    if d and d > 0.01 and d <= landmark.maxDistance then
      out[#out + 1] = {
        id = landmark.id, card = landmark.card,
        at = at, distance = d,
        bearing = WorldHorizon.bearing(viewer, at),
      }
      if #out >= WorldHorizon.MAX_VISIBLE then break end
    end
  end
  return out
end

local function atlas()
  if atlasImage or atlasFailed then return atlasImage end
  local ok, img = pcall(function()
    local path = rawget(_G, "__ds_horizon_atlas_path")
                 or "mods/DRAMATIC_SHAPE/lib/horizon-atlas.png"
    local i = love.graphics.newImage(path)
    i:setWrap("clamp", "clamp")
    i:setFilter("nearest", "nearest")
    return i
  end)
  if ok and img then
    atlasImage = img
  else
    atlasFailed = true
    status("world atlas missing; legacy panorama retained")
  end
  return atlasImage
end

local function cardMesh(kind)
  if meshes[kind] ~= nil then return meshes[kind] or nil end
  local c = CARD_TYPES[kind]
  if not c then meshes[kind] = false return nil end
  local vertices = {
    { -0.5, 0, 0, c.u0, c.v1, 1 },
    {  0.5, 0, 0, c.u1, c.v1, 1 },
    {  0.5, 1, 0, c.u1, c.v0, 1 },
    { -0.5, 1, 0, c.u0, c.v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  meshes[kind] = Voxel3D.newMesh(vertices, indices) or false
  return meshes[kind] or nil
end

local function gameData()
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then return Game.data end
  return nil
end

function WorldHorizon.draw(state)
  local map = state and state.map
  local mapId = map and map.id
  local data = gameData()
  if not (mapId and data) then
    status("no Town Map data; legacy panorama retained")
    return false
  end
  local viewer = WorldHorizon.anchorForDraw(data, mapId)
  local cards = WorldHorizon.cardsFor(data, viewer)
  if #cards == 0 then
    status("no nearby landmark card; legacy panorama retained")
    return false
  end
  local tex = atlas()
  if not tex then return false end

  local p = state.player
  local px = (p and p.px) or 0
  local pz = (p and p.py) or 0
  local drawn = 0
  for _, entry in ipairs(cards) do
    local c = CARD_TYPES[entry.card]
    local quad = c and cardMesh(entry.card) or nil
    if quad then
      local b = entry.bearing
      local x = px + math.sin(b) * RADIUS
      local z = pz - math.cos(b) * RADIUS
      local yaw = math.atan2(px - x, pz - z)
      local scale = clamp(1.25 / (0.75 + entry.distance * 0.22),
                          0.35, 1.10)
      local model = Mat4.mul(Mat4.translate(x, Y_BOTTOM, z),
                    Mat4.mul(Mat4.rotateY(yaw),
                             Mat4.scale(c.width * scale,
                                        c.height * scale, 1)))
      Voxel3D.draw(quad, tex, model)
      drawn = drawn + 1
    end
  end
  status(("world cards=%d map=%s atlas=4MiB"):format(drawn, mapId))
  return drawn > 0
end

function WorldHorizon.debugState()
  local meshCount = 0
  for _, m in pairs(meshes) do if m then meshCount = meshCount + 1 end end
  return { atlasLoaded = atlasImage ~= nil, atlasFailed = atlasFailed,
           meshes = meshCount, transitionMap = transition.mapId,
           maxVisible = WorldHorizon.MAX_VISIBLE,
           atlasBytes = WorldHorizon.ATLAS_BYTES }
end

function WorldHorizon.invalidate()
  for kind, mesh in pairs(meshes) do
    if mesh then pcall(mesh.release, mesh) end
    meshes[kind] = nil
  end
  if atlasImage then pcall(atlasImage.release, atlasImage) end
  atlasImage, atlasFailed = nil, false
  transition = { mapId = nil, from = nil, to = nil, started = 0 }
  stereo = { pending = false, mapId = nil, anchor = nil }
end

_G.__ds_live = rawget(_G, "__ds_live") or {}
_G.__ds_live.WorldHorizon = WorldHorizon
_G.__ds_live.V = _G.__ds_live.V or V

return WorldHorizon
