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
