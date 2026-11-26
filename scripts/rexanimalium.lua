local StoryItems = require("storyitems")
local Rex = {}

function Rex.Setup(inst)
  inst.displaynamefn = function() return "Rex animalium" end
  if not TheWorld.ismastersim then return end
  if inst.components.libelluscelebration == nil then inst:AddComponent("libelluscelebration") end
  if inst._libellus_rex_voice ~= nil and inst._libellus_rex_voice:IsValid() then return end
  -- A replicated child owns the talker, constructed before its SetPristine.
  -- The native king keeps his trader, stategraph, sleep, and minigame logic.
  local voice = SpawnPrefab("rex_voice")
  if voice ~= nil then
    voice.entity:SetParent(inst.entity)
    voice.Transform:SetPosition(0, 0, 0)
    inst._libellus_rex_voice = voice
    inst:ListenForEvent("onremove", function() if voice:IsValid() then voice:Remove() end end)
  end
  inst.GiveLibellusGift = function(inst, prefab, player)
    local item = SpawnPrefab(prefab)
    if item == nil then return false end
    StoryItems.NameGift(item)
    local x, _, z = inst.Transform:GetWorldPosition()
    local px, _, pz = player.Transform:GetWorldPosition()
    local dx, dz = px-x, pz-z
    local length = math.sqrt(dx*dx + dz*dz)
    if length > 0 then dx, dz = dx/length, dz/length else dx, dz = 0, 1 end
    item.Transform:SetPosition(x + dx*3, 2, z + dz*3)
    if item.Physics ~= nil then item.Physics:SetVel(dx*2, 5, dz*2) end
    return true
  end
end

return Rex
