local HELPERS = {}
local GLOBAL = _G


HELPERS.CHARACTERS = {
  "WILLOW", "WOLFGANG", "WENDY", "WX78", "WICKERBOTTOM",
  "WOODIE", "WAXWELL", "WATHGRITHR", "WEBBER", "WINONA",
  "WARLY", "WORTOX", "WORMWOOD", "WURT", "WALTER", "WANDA"
}
HELPERS.DIALOG_INTERVAL = 5
HELPERS.START_INTERVAL = 7
HELPERS.BUSY_INTERVAL = 2
HELPERS.REPEAT_INTERVAL = 25
HELPERS.CHECK_PROGRESS_INTERVAL = 2
HELPERS.PUBLIUS_MEETING_DISTANCE = 3
HELPERS.PUBLIUS_SPAWN_MIN_DISTANCE = 8
HELPERS.PUBLIUS_SPAWN_MAX_DISTANCE = 64
HELPERS.PUBLIUS_SPAWN_RETRY_INTERVAL = 20
HELPERS.CASA_SPAWN_MIN_DISTANCE = 24
HELPERS.CASA_SPAWN_MAX_DISTANCE = 64
HELPERS.CASA_SPAWN_RETRY_INTERVAL = 20
HELPERS.CASA_HALF_SIZE = 7
HELPERS.CASA_NEAR_DISTANCE = 18
HELPERS.CASA_CHECK_INTERVAL = .1
HELPERS.SOLDIER_HEALTH = 1000
HELPERS.SOLDIER_DAMAGE = 25
HELPERS.FARM_SIZE = 9
HELPERS.FARM_SPAWN_RETRY_INTERVAL = 20
HELPERS.AGRICOLA_MEETING_DISTANCE = 5
HELPERS.NAVIS_SPAWN_RETRY_INTERVAL = 20
HELPERS.NAVIS_SEE_DISTANCE = 25
HELPERS.NAVIS_NEAR_DISTANCE = 12
HELPERS.SENEX_HEALTH = 1000
HELPERS.SENEX_DAMAGE = 25
HELPERS.SENEX_CHECK_INTERVAL = .1
HELPERS.PASSER_SPAWN_RETRY_INTERVAL = 20
HELPERS.PASSER_SEE_DISTANCE = 25
HELPERS.PASSER_MEETING_DISTANCE = 5
HELPERS.PASSER_REFLECTION_DELAY = 15
HELPERS.PASSER_GROVE_SIZE = 27
HELPERS.PASSER_FIREBREAK = 16
HELPERS.PASSER_GROVE_OFFSET = HELPERS.PASSER_GROVE_SIZE / 2 + HELPERS.PASSER_FIREBREAK + 3

function HELPERS.CanClearForPasser(ent)
  if ent:HasTag("structure") or ent:HasTag("character") or ent:HasTag("player")
    or ent:HasTag("libellus_burnt_tree") or ent._libellus_owneruserid ~= nil then return false end
  if ent.components.inventoryitem ~= nil then
    return ent.components.inventoryitem:GetGrandOwner() == nil
  end
  return ent:HasTag("tree") or ent:HasTag("plant") or ent:HasTag("grass")
    or ent:HasTag("sapling") or ent:HasTag("stump")
    or (ent.components.health == nil and
      (ent.components.pickable ~= nil or ent.components.workable ~= nil))
end

-- The cage stands in front of the clearing, beyond even the firebreak.
function HELPERS.GetPasserClearing(point, dx, dz)
  return GLOBAL.Vector3(point.x + dx * HELPERS.PASSER_GROVE_OFFSET, 0,
    point.z + dz * HELPERS.PASSER_GROVE_OFFSET)
end

function HELPERS.GetPasserClearingEntities(center)
  local half = HELPERS.PASSER_GROVE_SIZE / 2 + HELPERS.PASSER_FIREBREAK
  local result = {}
  for _, ent in ipairs(GLOBAL.TheSim:FindEntities(center.x, 0, center.z, half * math.sqrt(2),
    nil, {"FX", "DECOR", "INLIMBO"})) do
    local x, _, z = ent.Transform:GetWorldPosition()
    if math.abs(x - center.x) <= half and math.abs(z - center.z) <= half then
      table.insert(result, ent)
    end
  end
  return result
end

function HELPERS.CanPreparePasserSite(point, dx, dz)
  local map = GLOBAL.TheWorld.Map
  if map:GetTileAtPoint(point.x, 0, point.z) ~= GLOBAL.WORLD_TILES.FOREST
    or not map:IsPassableAtPoint(point.x, 0, point.z) or map:IsPointNearHole(point) then return false end
  for _, ent in ipairs(GLOBAL.TheSim:FindEntities(point.x, 0, point.z, 2,
    nil, {"FX", "DECOR", "INLIMBO"})) do
    if ent:GetPhysicsRadius(0) > 0 or ent:HasTag("structure") then return false end
  end
  local center = HELPERS.GetPasserClearing(point, dx, dz)
  local half = HELPERS.PASSER_GROVE_SIZE / 2
  for x = -half, half, 3 do
    for z = -half, half, 3 do
      local sample = GLOBAL.Vector3(center.x + x, 0, center.z + z)
      if not map:IsPassableAtPoint(sample.x, 0, sample.z) or map:IsPointNearHole(sample) then return false end
    end
  end
  for _, ent in ipairs(HELPERS.GetPasserClearingEntities(center)) do
    if not HELPERS.CanClearForPasser(ent) then return false end
  end
  return true
end

function HELPERS.FindPasserSpawnPoint(origin)
  local map = GLOBAL.TheWorld.Map
  local width, height = map:GetSize()
  local points = {}
  for x = 0, width - 1 do
    for z = 0, height - 1 do
      if map:GetTile(x, z) == GLOBAL.WORLD_TILES.FOREST then
        local px, _, pz = map:GetTileCenterPoint(x, z)
        table.insert(points, {point = GLOBAL.Vector3(px, 0, pz), distance = (px-origin.x)^2 + (pz-origin.z)^2})
      end
    end
  end
  table.sort(points, function(a, b) return a.distance < b.distance end)
  local head = 1
  local directions = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
  while head <= #points do
    local band, limit = {}, (math.sqrt(points[head].distance) + 16)^2
    while head <= #points and points[head].distance <= limit do
      table.insert(band, points[head].point)
      head = head + 1
    end
    while #band > 0 do
      local point = table.remove(band, math.random(#band))
      local first = math.random(4)
      for i = 0, 3 do
        local dir = directions[(first + i - 1) % 4 + 1]
        if HELPERS.CanPreparePasserSite(point, dir[1], dir[2]) then return point, dir[1], dir[2] end
      end
    end
  end
end

-- Search outward from the saved spawn, randomizing the bearing in each band.
-- Check the whole hull footprint against land, void, and existing platforms.
function HELPERS.FindNavisSpawnPoint(origin)
  local map = GLOBAL.TheWorld.Map
  local width, height = map:GetSize()
  local limit = math.sqrt(width * width + height * height) * GLOBAL.TILE_SCALE
    + math.sqrt(origin.x * origin.x + origin.z * origin.z)
  local clearance = GLOBAL.TUNING.BOAT.RADIUS + .5
  for radius = 12, limit, 8 do
    local count = math.ceil(2 * math.pi * radius / 8)
    local bearing = math.random() * 2 * math.pi
    for i = 1, count do
      local angle = bearing + i * 2 * math.pi / count
      local point = GLOBAL.Vector3(origin.x + math.cos(angle) * radius, 0,
        origin.z + math.sin(angle) * radius)
      local clear = map:IsOceanAtPoint(point.x, 0, point.z)
      for edge = 1, 24 do
        local theta = edge * 2 * math.pi / 24
        if not clear or not map:IsOceanAtPoint(point.x + math.cos(theta) * clearance, 0,
          point.z + math.sin(theta) * clearance) then
          clear = false
          break
        end
      end
      for dx = -clearance, clearance, 1 do
        if not clear then break end
        for dz = -clearance, clearance, 1 do
          if dx * dx + dz * dz <= clearance * clearance
            and not map:IsOceanAtPoint(point.x + dx, 0, point.z + dz) then
            clear = false
            break
          end
        end
        if not clear then break end
      end
      if clear then
        for _, ent in ipairs(GLOBAL.TheSim:FindEntities(point.x, 0, point.z, clearance + 2,
          nil, {"FX", "DECOR", "INLIMBO", "NOCLICK"})) do
          if ent:GetPhysicsRadius(0) > 0 or ent:HasTag("structure") then
            clear = false
            break
          end
        end
      end
      if clear then return point end
    end
  end
end

-- Connected savanna tiles define candidate biomes. Rank them by their nearest
-- tile to the player's original spawn, then randomize placement within one.
function HELPERS.FindFarmSpawnPoint(origin)
  local map = GLOBAL.TheWorld.Map
  local width, height = map:GetSize()
  local remaining = {}
  for x = 0, width - 1 do
    for z = 0, height - 1 do
      if map:GetTile(x, z) == GLOBAL.WORLD_TILES.SAVANNA then
        remaining[x * height + z] = {x = x, z = z}
      end
    end
  end
  local regions = {}
  while next(remaining) ~= nil do
    local key, start = next(remaining)
    remaining[key] = nil
    local queue, points, head, distance = {start}, {}, 1, math.huge
    while head <= #queue do
      local tile = queue[head]
      head = head + 1
      local x, _, z = map:GetTileCenterPoint(tile.x, tile.z)
      table.insert(points, GLOBAL.Vector3(x, 0, z))
      distance = math.min(distance, (x - origin.x)^2 + (z - origin.z)^2)
      for _, offset in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
        local nx, nz = tile.x + offset[1], tile.z + offset[2]
        local neighbor = nx * height + nz
        if nx >= 0 and nx < width and nz >= 0 and nz < height and remaining[neighbor] ~= nil then
          table.insert(queue, remaining[neighbor])
          remaining[neighbor] = nil
        end
      end
    end
    table.insert(regions, {points = points, distance = distance})
  end
  table.sort(regions, function(a, b) return a.distance < b.distance end)
  for _, region in ipairs(regions) do
    local points = region.points
    while #points > 0 do
      local i = math.random(#points)
      local point = points[i]
      points[i] = points[#points]
      points[#points] = nil
      local clear = true
      for dx = -HELPERS.FARM_SIZE / 2, HELPERS.FARM_SIZE / 2, 1.5 do
        for dz = -HELPERS.FARM_SIZE / 2, HELPERS.FARM_SIZE / 2, 1.5 do
          local sample = GLOBAL.Vector3(point.x + dx, 0, point.z + dz)
          if map:GetTileAtPoint(sample.x, 0, sample.z) ~= GLOBAL.WORLD_TILES.SAVANNA
            or not map:IsPassableAtPoint(sample.x, 0, sample.z) or map:IsPointNearHole(sample) then
            clear = false
            break
          end
        end
        if not clear then break end
      end
      if clear then
        for _, ent in ipairs(GLOBAL.TheSim:FindEntities(point.x, 0, point.z, HELPERS.FARM_SIZE,
          nil, {"FX", "DECOR", "INLIMBO", "NOCLICK"})) do
          if ent:HasTag("structure") or ent:GetPhysicsRadius(0) > 0 then
            clear = false
            break
          end
        end
      end
      if clear then return point end
    end
  end
end

-- Keep the entire courtyard on clear land, including the hound's enclosure.
function HELPERS.FindCasaSpawnPoint(origin)
  local function IsClear(point)
    local map = GLOBAL.TheWorld.Map
    local margin = HELPERS.CASA_HALF_SIZE + 1
    for x = -margin, margin, 2 do
      for z = -margin, margin, 2 do
        local sample = GLOBAL.Vector3(point.x + x, 0, point.z + z)
        if not map:IsPassableAtPoint(sample.x, 0, sample.z)
          or map:IsPointNearHole(sample) then
          return false
        end
      end
    end
    local ents = GLOBAL.TheSim:FindEntities(point.x, 0, point.z, margin * 1.5,
      nil, {"FX", "DECOR", "INLIMBO", "NOBLOCK", "NOCLICK"})
    for _, ent in ipairs(ents) do
      if ent:GetPhysicsRadius(0) > 0 then
        return false
      end
    end
    return true
  end

  for radius = HELPERS.CASA_SPAWN_MIN_DISTANCE, HELPERS.CASA_SPAWN_MAX_DISTANCE, 4 do
    local offset = GLOBAL.FindWalkableOffset(origin, math.random() * 2 * math.pi,
      radius, 24, true, false, function(point)
        -- DST walls occupy the centres of one-unit grid cells.
        return IsClear(GLOBAL.Vector3(math.floor(point.x) + .5, 0, math.floor(point.z) + .5))
      end)
    if offset ~= nil then
      local point = origin + offset
      return GLOBAL.Vector3(math.floor(point.x) + .5, 0, math.floor(point.z) + .5)
    end
  end
end

-- Search outwards so Publius waits on the closest suitable grassland.
function HELPERS.FindPubliusSpawnPoint(origin)
  local function IsGrassland(point)
    local map = GLOBAL.TheWorld.Map
    return map:GetTileAtPoint(point.x, 0, point.z) == GLOBAL.WORLD_TILES.GRASS
      and map:IsPassableAtPoint(point.x, 0, point.z)
      and not map:IsPointNearHole(point)
  end

  for radius = HELPERS.PUBLIUS_SPAWN_MIN_DISTANCE, HELPERS.PUBLIUS_SPAWN_MAX_DISTANCE, 4 do
    local offset = GLOBAL.FindWalkableOffset(
      origin, 0, radius, math.ceil(2 * math.pi * radius / 4), true, false, IsGrassland
    )
    if offset ~= nil then
      return origin + offset
    end
  end
end

function HELPERS.add_quote(prefab_name, display_name, generic, characters)
  prefab_name = string.upper(prefab_name)
  GLOBAL.STRINGS.NAMES[prefab_name] = display_name
  GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE[prefab_name] = generic
  characters = characters or {}
  for _, ch in ipairs(HELPERS.CHARACTERS) do
    GLOBAL.STRINGS.CHARACTERS[ch].DESCRIBE[prefab_name] = characters[ch] or generic
  end
end

return HELPERS
