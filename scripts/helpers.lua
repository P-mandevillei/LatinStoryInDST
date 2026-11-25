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
