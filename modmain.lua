print("<------------------- LatinPresentation -------------------->")
local HELPERS = require("helpers")

-- add texture & anim files
Assets = {
  Asset("ATLAS", "images/test.xml"),
  Asset("IMAGE", "images/test.tex"),

  Asset("ANIM", "anim/test.zip")
}

-- register prefabs
PrefabFiles = {
  "test",
  "publius",
  "casa",
  "miles",
  "lupa",
  "agricola",
  "agricola_farm",
  "agricola_crop",
  "navis",
  "senex",
  "passer",
  "passer_free",
  "passer_grove",
  "passer_burnt_tree",
  "rex_voice"
}

-- name prefabs
HELPERS.add_quote("test", "This is a test", "test display")
HELPERS.add_quote("publius", "Publius", "Poeta est.")
HELPERS.add_quote("casa", "Casa Octaviae", "Casa mea pulchra est.")
HELPERS.add_quote("miles", "Miles", "Militem timeo!")
HELPERS.add_quote("lupa", "Lupa", "Lupam bene curo et amo.")
HELPERS.add_quote("agricola", "Agricola", "Agricola bonus est.")
HELPERS.add_quote("senex", "Senex", "Militi similis est.")
HELPERS.add_quote("passer", "Passer", "Passer calidus est.")
HELPERS.add_quote("passer_free", "Passer", "Passer a me liberatur!")

AddPrefabPostInit("pigking", require("rexanimalium").Setup)
local storyitems = require("storyitems")
AddPrefabPostInit("panflute", storyitems.SetupPanFlute)
AddPrefabPostInit("bell", storyitems.SetupNamed)

modimport("items/hugTest.lua")

AddPlayerPostInit(function(inst)
  if not GLOBAL.TheWorld.ismastersim then
    return
  end

  inst:AddComponent("libellusprogress")
  inst:DoTaskInTime(HELPERS.START_INTERVAL, function(inst)
    inst.components.libellusprogress:DialogLoop(inst)
  end)
end)

modimport("scripts/dialogselector.lua")
