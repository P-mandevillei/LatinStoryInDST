local assets = {
  Asset("ANIM", "anim/bird_cage.zip"),
  Asset("ANIM", "anim/robin_build.zip")
}

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
  inst:DoPeriodicTask(6, function()
    if not inst.components.talker:IsTalking() then
      inst.AnimState:PlayAnimation("flap")
      inst.AnimState:PushAnimation("idle_bird", true)
    end
  end)
  return inst
end

return Prefab("passer", fn, assets)
