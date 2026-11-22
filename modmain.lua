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
  "test"
}

-- name prefabs
HELPERS.add_quote("test", "This is a test", "test display")

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