local assets = {
  Asset("ANIM", "anim/bird_cage.zip"),
  Asset("ANIM", "anim/robin_build.zip")
}

local function OnWorkFinished(inst, worker)
  local grove = inst._grove
  if grove == nil or not grove:IsValid() or not grove:FreePasser(inst, worker) then
    inst.components.workable:SetWorkLeft(1)
    return
  end
  local fx = SpawnPrefab("collapse_small")
  if fx ~= nil then
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
  end
  inst:Remove()
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddNetwork()
  MakeObstaclePhysics(inst, .5)
  inst.MiniMapEntity:SetIcon("birdcage.png")
  -- Use the game's occupied-cage animations, including the actual bird symbols.
  inst.AnimState:SetBank("birdcage")
  inst.AnimState:SetBuild("bird_cage")
  inst.AnimState:AddOverrideBuild("robin_build")
  inst.AnimState:PlayAnimation("idle_bird", true)
  inst:AddTag("structure")
  inst:AddTag("libellus_passer")
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -400, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst:AddComponent("inspectable")
  inst:AddComponent("workable")
  inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
  inst.components.workable:SetWorkLeft(4)
  inst.components.workable:SetOnFinishCallback(OnWorkFinished)
  inst.components.workable:SetOnWorkCallback(function(inst)
    inst.AnimState:PlayAnimation("hit_bird")
    inst.AnimState:PushAnimation("idle_bird", true)
  end)
  inst:DoPeriodicTask(6, function()
    if not inst.components.talker:IsTalking() then
      inst.AnimState:PlayAnimation("flap")
      inst.AnimState:PushAnimation("idle_bird", true)
    end
  end)
  return inst
end

return Prefab("passer", fn, assets, {"collapse_small", "passer_free"})
