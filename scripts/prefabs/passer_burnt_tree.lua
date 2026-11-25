local function PreserveTree(inst)
  if inst.components.timer ~= nil then inst.components.timer:StopTimer("decay") end
  inst.burntcone = true
  if inst.pineconetask ~= nil then inst.pineconetask:Cancel(); inst.pineconetask = nil end
  -- Native burnt trees cannot ignite or spread fire. Keep this prepared set
  -- from decaying or generating new vegetation before the later animation.
  inst:RemoveComponent("plantregrowth")
  inst:RemoveComponent("simplemagicgrower")
end

local function fn()
  local inst = Prefabs.evergreen.fn()
  -- Evergreen sets its own prefab name in its constructor. Restore ours so
  -- save records return through this constructor and retain the prepared set.
  inst:SetPrefabName("passer_burnt_tree")
  inst:SetPrefabNameOverride("evergreen")
  if not TheWorld.ismastersim then return inst end
  local onload = inst.OnLoad
  local onwake = inst.OnEntityWake
  inst.OnLoad = function(inst, data)
    onload(inst, data)
    PreserveTree(inst)
  end
  inst.OnEntityWake = function(inst)
    onwake(inst)
    PreserveTree(inst)
  end
  inst:OnLoad({burnt = true})
  inst:AddTag("libellus_burnt_tree")
  return inst
end

return Prefab("passer_burnt_tree", fn, nil, {"evergreen"})
