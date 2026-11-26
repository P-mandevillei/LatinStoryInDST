local brain = require("brains/passerbrain")
local assets = {
  Asset("ANIM", "anim/crow.zip"),
  Asset("ANIM", "anim/robin_build.zip")
}

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddDynamicShadow()
  inst.entity:AddNetwork()
  inst.Transform:SetTwoFaced()
  inst.DynamicShadow:SetSize(1, .75)
  inst.AnimState:SetBank("crow")
  inst.AnimState:SetBuild("robin_build")
  inst.AnimState:PlayAnimation("idle", true)
  inst:AddTag("NOBLOCK")
  inst:AddTag("companion")
  inst:AddTag("libellus_passer_free")
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -200, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst:AddComponent("inspectable")
  inst.StartFlight = function(inst, target, speed, guideuserid)
    inst._flight_target, inst._flight_speed, inst._guide_userid = target, speed, guideuserid
    inst._arrived, inst._landing, inst._flight_started = nil, nil, nil
    inst.sg:GoToState("idle")
    if inst.brain ~= nil then inst.brain:ForceUpdate() end
  end
  inst:SetStateGraph("SGpasser")
  inst:SetBrain(brain)
  inst.OnSave = function(inst, data)
    local target = inst._flight_target
    data.target = target ~= nil and {x = target.x, z = target.z} or nil
    data.arrived = inst._arrived
    data.speed, data.guideuserid, data.rex_guided = inst._flight_speed, inst._guide_userid, inst._rex_guided
  end
  inst.OnLoad = function(inst, data)
    if data ~= nil then
      inst._arrived = data.arrived
      inst._flight_speed, inst._guide_userid, inst._rex_guided = data.speed, data.guideuserid, data.rex_guided
      if data.target ~= nil then inst._flight_target = Vector3(data.target.x, 0, data.target.z) end
    end
  end
  return inst
end

return Prefab("passer_free", fn, assets)
