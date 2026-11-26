local StoryItems = {}
local NAMES = {panflute = "Saxum Somni", bell = "Saxum Sacrum"}

function StoryItems.SetupNamed(inst)
  if not TheWorld.ismastersim then return end
  -- Present on restored native prefabs before their saved names are loaded.
  if inst.components.named == nil then inst:AddComponent("named") end
end

function StoryItems.NameGift(inst)
  local name = NAMES[inst.prefab]
  if name ~= nil then
    StoryItems.SetupNamed(inst)
    inst.components.named:SetName(name)
  end
end

function StoryItems.SetupPanFlute(inst)
  StoryItems.SetupNamed(inst)
  if not TheWorld.ismastersim then return end
  local instrument = inst.components.instrument
  local onplayed = instrument.onplayed
  instrument:SetOnPlayedFn(function(item, musician)
    if onplayed ~= nil then onplayed(item, musician) end
    local progress = musician.components.libellusprogress
    if progress ~= nil then progress:OnPanFlutePlayed() end
  end)
end

return StoryItems
