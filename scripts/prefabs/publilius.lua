local HELPERS = require("helpers")
local function voicefn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()
  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = HELPERS.STORY_NPC_FONT_SIZE
  inst.components.talker.offset = Vector3(0, -HELPERS.PUBLILIUS_VOICE_OFFSET, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst.persists = false
  return inst
end
local function fn()
  -- Keep native Vargling traits, feeding, petting, sleep, boat hops, and AI.
  local inst = Prefabs.critter_puppy.fn()
  inst.displaynamefn = function() return "Publilius" end
  if not TheWorld.ismastersim then return inst end
  local voice = SpawnPrefab("publilius_voice")
  if voice ~= nil then
    voice.entity:SetParent(inst.entity)
    voice.Transform:SetPosition(0, 0, 0)
    inst._libellus_voice = voice
    inst:ListenForEvent("onremove", function() if voice:IsValid() then voice:Remove() end end)
  end
  local save, load = inst.OnSave, inst.OnLoad
  inst.OnSave = function(inst, data)
    data.owneruserid = inst._libellus_owneruserid
    if save ~= nil then return save(inst, data) end
  end
  inst.OnLoad = function(inst, data)
    if data ~= nil then inst._libellus_owneruserid = data.owneruserid end
    if load ~= nil then load(inst, data) end
  end
  return inst
end
return Prefab("publilius", fn, nil, {"critter_puppy", "publilius_voice"}),
  Prefab("publilius_voice", voicefn)
