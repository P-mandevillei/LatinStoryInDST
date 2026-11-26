local HELPERS = require("helpers")
local assets = {
  Asset("ANIM", "anim/player_basic.zip"),
  Asset("ANIM", "anim/player_actions.zip"),
  Asset("ANIM", "anim/player_actions_uniqueitem.zip"),
  Asset("ANIM", "anim/player_knockedout.zip"),
  Asset("ANIM", "anim/waxwell.zip"),
}
local function Dress(inst)
  if inst.components.health:IsDead() then return end
  for _, entry in ipairs({{EQUIPSLOTS.HEAD, "ruinshat"},
    {EQUIPSLOTS.BODY, "armorruins"}, {EQUIPSLOTS.HANDS, "cane"}}) do
    if inst.components.inventory:GetEquippedItem(entry[1]) == nil then
      local item = SpawnPrefab(entry[2])
      if item ~= nil then inst.components.inventory:Equip(item) end
    end
  end
end
local function AcceptTest(inst, item, giver)
  local progress = giver ~= nil and giver.components.libellusprogress or nil
  return inst._castle ~= nil and not inst._castle._betrayed
    and progress ~= nil and progress:IsKingTradeReady(inst._castle)
    and (item.prefab ~= "bell" or TheWorld.components.bigfooter ~= nil)
end
local function OnAccept(inst, giver, item)
  if item.prefab == "bell" and inst._castle ~= nil then
    inst._castle:ReceiveBell(giver, item)
  end
end
local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddDynamicShadow()
  inst.entity:AddNetwork()
  MakeCharacterPhysics(inst, 75, .5)
  inst.Transform:SetFourFaced()
  inst.DynamicShadow:SetSize(1.3, .6)
  inst.AnimState:SetBank("wilson")
  inst.AnimState:SetBuild("waxwell")
  inst.AnimState:PlayAnimation("idle_loop", true)
  for _, symbol in ipairs({"ARM_carry", "HAT", "HAIR_HAT", "HEAD_HAT",
    "HEAD_HAT_NOHELM", "HEAD_HAT_HELM"}) do inst.AnimState:Hide(symbol) end
  inst:AddTag("character")
  inst:AddTag("libellus_court")
  inst:AddTag("trader")
  inst:AddTag("alltrader")
  inst:AddTag("sleeper")
  inst.displaynamefn = function() return "Rex" end
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -400, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst:AddComponent("inspectable")
  inst:AddComponent("locomotor")
  inst:AddComponent("health")
  inst.components.health:SetMaxHealth(HELPERS.KING_HEALTH)
  inst:AddComponent("combat")
  inst:AddComponent("inventory")
  inst:AddComponent("lootdropper")
  inst:AddComponent("sleeper")
  inst.components.sleeper:SetSleepTest(function() return false end)
  inst:AddComponent("trader")
  inst.components.trader.acceptnontradable = true
  inst.components.trader.deleteitemonaccept = false
  inst.components.trader:SetAcceptTest(AcceptTest)
  inst.components.trader:SetOnAccept(OnAccept)
  inst:SetStateGraph("SGrex")
  inst:ListenForEvent("death", function(inst)
    if inst._castle ~= nil then inst._castle:OnKingDeath() end
  end)
  inst:DoTaskInTime(0, Dress)
  return inst
end
return Prefab("rex", fn, assets, {"ruinshat", "armorruins", "cane", "bell"})
