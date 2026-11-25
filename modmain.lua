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
  "lupa"
}

-- name prefabs
HELPERS.add_quote("test", "This is a test", "test display")
HELPERS.add_quote("publius", "Publius", "Poeta est.")
HELPERS.add_quote("casa", "Casa Octaviae", "Casa mea pulchra est.")
HELPERS.add_quote("miles", "Miles", "Militem timeo!")
HELPERS.add_quote("lupa", "Lupa", "Lupam bene curo et amo.")

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
