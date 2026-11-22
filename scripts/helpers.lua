local HELPERS = {}
local GLOBAL = _G


HELPERS.CHARACTERS = {
  "WILLOW", "WOLFGANG", "WENDY", "WX78", "WICKERBOTTOM",
  "WOODIE", "WAXWELL", "WATHGRITHR", "WEBBER", "WINONA",
  "WARLY", "WORTOX", "WORMWOOD", "WURT", "WALTER", "WANDA"
}
HELPERS.DIALOG_INTERVAL = 5
HELPERS.START_INTERVAL = 2
HELPERS.BUSY_INTERVAL = 2
HELPERS.REPEAT_INTERVAL = 20
HELPERS.CHECK_PROGRESS_INTERVAL = 2

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