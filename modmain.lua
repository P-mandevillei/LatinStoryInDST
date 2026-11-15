print("<------------------- LatinPresentation -------------------->")

-- add texture files
Assets = {
  Asset("ATLAS", "images/test.xml"),
  Asset("IMAGE", "images/test.tex")
}
-- register prefabs
PrefabFiles = {
  "test"
}

local CHARACTERS = {
  "WILLOW", "WOLFGANG", "WENDY", "WX78", "WICKERBOTTOM",
  "WOODIE", "WAXWELL", "WATHGRITHR", "WEBBER", "WINONA",
  "WARLY", "WORTOX", "WORMWOOD", "WURT", "WALTER", "WANDA"
}
local function add_quote(prefab_name, display_name, generic, characters)
  prefab_name = string.upper(prefab_name)
  GLOBAL.STRINGS.NAMES[prefab_name] = display_name
  GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE[prefab_name] = generic
  for _, ch in ipairs(CHARACTERS) do
    GLOBAL.STRINGS.CHARACTERS[ch].DESCRIBE[prefab_name] = characters[ch] or generic
  end
end

-- name prefabs
add_quote("test", "This is a test", "test display", {})