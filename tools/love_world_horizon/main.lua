local function close(a, b, epsilon)
  return math.abs(a - b) <= (epsilon or 1e-6)
end

local function check(condition, message)
  if not condition then error("WORLD HORIZON: " .. message, 0) end
end

local function wrapPi(a)
  while a > math.pi do a = a - math.pi * 2 end
  while a < -math.pi do a = a + math.pi * 2 end
  return a
end

function love.load()
  local ok, err = pcall(function()
    local fakeVoxel = {
      camera = nil,
      pushQuad = function(indices)
        for i = 1, 6 do indices[i] = i end
      end,
      newMesh = function() return nil end,
      draw = function() end,
    }
    local fakeMat = {
      translate = function() return {} end,
      rotateY = function() return {} end,
      scale = function() return {} end,
      mul = function() return {} end,
    }
    local V = {
      require = function(name)
        if name == "Voxel3D" then return fakeVoxel end
        if name == "Mat4" then return fakeMat end
        error("unexpected module " .. tostring(name))
      end,
    }
    local WorldHorizon = assert(loadfile("payload_world_horizon.lua"))(V)

    local nested = { field = { townMap = { locations = {
      PALLET_TOWN = { x = 2, y = 11 },
      ROUTE_1 = { coords = { col = 2, row = 10 } },
      VIRIDIAN_FOREST = { x = 2, y = 4 },
    } } } }
    local pallet = WorldHorizon.coordsFor(nested, "PALLET_TOWN")
    check(pallet and pallet.x == 2 and pallet.y == 11,
          "nested x/y Town Map entry was not resolved")
    local route = WorldHorizon.coordsFor(nested, "ROUTE_1")
    check(route and route.x == 2 and route.y == 10,
          "nested coords col/row entry was not resolved")

    local direct = { field = { townMap = {
      TEST = { col = 7, row = 9 },
    } } }
    local test = WorldHorizon.coordsFor(direct, "TEST")
    check(test and test.x == 7 and test.y == 9,
          "direct Town Map entry was not resolved")
    check(WorldHorizon.coordsFor({}, "TEST") == nil,
          "missing Town Map data did not select fallback")

    local origin = { x = 0, y = 0 }
    check(close(WorldHorizon.bearing(origin, { x = 0, y = -1 }), 0),
          "north bearing is not zero")
    check(close(WorldHorizon.bearing(origin, { x = 1, y = 0 }), math.pi / 2),
          "east bearing is not +pi/2")
    check(close(math.abs(WorldHorizon.bearing(origin, { x = 0, y = 1 })),
                math.pi), "south bearing is not pi")
    check(close(WorldHorizon.bearing(origin, { x = -1, y = 0 }),
                -math.pi / 2), "west bearing is not -pi/2")
    local ab = WorldHorizon.bearing({ x = 2, y = 11 }, { x = 0, y = 8 })
    local ba = WorldHorizon.bearing({ x = 0, y = 8 }, { x = 2, y = 11 })
    check(close(math.abs(wrapPi(ab - ba)), math.pi),
          "reciprocal landmark bearings are not opposite")

    local transitionData = { field = { townMap = { locations = {
      A = { x = 0, y = 0 }, B = { x = 0, y = 2 },
      VIRIDIAN_FOREST = { x = 2, y = 4 },
    } } } }
    WorldHorizon.invalidate()
    local a0 = WorldHorizon.transitionAnchor(transitionData, "A", 0)
    check(a0 and close(a0.y, 0), "cold anchor did not start at destination")
    local b0 = WorldHorizon.transitionAnchor(transitionData, "B", 10)
    local bm = WorldHorizon.transitionAnchor(transitionData, "B", 10.3)
    local b1 = WorldHorizon.transitionAnchor(transitionData, "B", 10.6)
    check(close(b0.y, 0), "transition jumped on the destination frame")
    check(close(bm.y, 1), "0.6-second transition midpoint is wrong")
    check(close(b1.y, 2), "transition did not settle on destination")
    check(WorldHorizon.transitionAnchor(transitionData, "MISSING", 11) == nil,
          "cold/missing destination did not fall back")

    local cards = WorldHorizon.cardsFor(nested, pallet)
    check(#cards == 1 and cards[1].id == "viridian-forest",
          "Pallet did not select the Viridian Forest card")
    check(close(cards[1].distance, 7) and close(cards[1].bearing, 0),
          "forest card distance/bearing is wrong from Pallet")
    check(#cards <= WorldHorizon.MAX_VISIBLE,
          "visible-card cap was exceeded")
    check(WorldHorizon.MAX_VISIBLE == 8,
          "Quest visible-card budget changed")
    check(WorldHorizon.ATLAS_BYTES == 4 * 1024 * 1024,
          "Quest atlas budget is not exactly 4 MiB RGBA")

    -- The two OpenXR eyes must consume an identical transition anchor.
    WorldHorizon.invalidate()
    fakeVoxel.camera = { view = {}, proj = {} }
    local left = WorldHorizon.anchorForDraw(transitionData, "A", 20)
    local right = WorldHorizon.anchorForDraw(transitionData, "A", 20.05)
    check(left and right and close(left.x, right.x) and close(left.y, right.y),
          "stereo eyes received different cold anchors")
    local leftB = WorldHorizon.anchorForDraw(transitionData, "B", 21)
    local rightB = WorldHorizon.anchorForDraw(transitionData, "B", 21.1)
    check(close(leftB.x, rightB.x) and close(leftB.y, rightB.y),
          "stereo eyes received different transition anchors")
    fakeVoxel.camera = nil

    WorldHorizon.invalidate()
    local debug = WorldHorizon.debugState()
    check(debug.meshes == 0 and not debug.atlasLoaded
          and debug.transitionMap == nil,
          "invalidate retained transition or GPU resources")
  end)

  local report = ok
    and "PASS: location-aware bearings, transitions, stereo and Quest budgets"
    or tostring(err)
  print(report)
  local output = io.open("tools/love_world_horizon/result.txt", "wb")
  if output then output:write(report .. "\n"); output:close() end
  love.event.quit(ok and 0 or 1)
end
