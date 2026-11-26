local HELPERS = require("helpers")
local DIALOG = require("libellus")
local Celebration = Class(function(self, inst)
  self.inst, self.participants = inst, {}
  inst:DoPeriodicTask(HELPERS.CLOSING_CHECK_INTERVAL, function() self:Update() end)
end)
function Celebration:Cheer()
  for _, pig in ipairs(self.participants) do
    if pig:IsValid() and not pig.components.health:IsDead() and pig.components.talker ~= nil then
      pig.components.talker:Say(DIALOG.ch6[DIALOG.CH6_SEP[7]].content, HELPERS.DIALOG_INTERVAL)
    end
  end
  self.nextcheer = GetTime()+HELPERS.CLOSING_CHEER_INTERVAL
end
function Celebration:Start()
  if self.untiltime ~= nil then return end
  self.untiltime = GetTime()+HELPERS.CLOSING_DURATION
  for _, pig in pairs(Ents) do
    if (pig.prefab == "pigman" or pig.prefab == "pigguard") and pig:IsValid()
      and not pig:HasTag("werepig") and not pig:HasTag("INLIMBO")
      and pig.components.health ~= nil and not pig.components.health:IsDead() then
      if pig.components.libelluspigcelebrant == nil then pig:AddComponent("libelluspigcelebrant") end
      if pig.components.libelluspigcelebrant:Join(self.inst) then table.insert(self.participants, pig) end
    end
  end
  self:Cheer()
end
function Celebration:Finish()
  self.untiltime, self.nextcheer = nil, nil
  for _, pig in ipairs(self.participants) do
    if pig:IsValid() and pig.components.libelluspigcelebrant ~= nil then
      pig:RemoveComponent("libelluspigcelebrant")
    end
  end
  self.participants = {}
end
function Celebration:Update()
  if self.untiltime == nil then return end
  if GetTime() >= self.untiltime then self:Finish()
  elseif GetTime() >= self.nextcheer then self:Cheer() end
end
function Celebration:OnSave()
  if self.untiltime == nil then return end
  local data = {remaining = math.max(0, self.untiltime-GetTime()),
    cheer_remaining = math.max(0, self.nextcheer-GetTime()), participants = {}}
  for _, pig in ipairs(self.participants) do
    if pig:IsValid() then table.insert(data.participants, pig.GUID) end
  end
  return data, data.participants
end
function Celebration:OnLoad(data)
  if data ~= nil then
    self.untiltime = GetTime()+math.max(0, data.remaining)
    self.nextcheer = GetTime()+math.max(0, data.cheer_remaining)
  end
end
function Celebration:LoadPostPass(ents, data)
  if data == nil then return end
  for _, guid in ipairs(data.participants or {}) do
    local pig = ents[guid] ~= nil and ents[guid].entity or nil
    if pig ~= nil and pig.components.libelluspigcelebrant ~= nil then
      pig.components.libelluspigcelebrant:Join(self.inst)
      table.insert(self.participants, pig)
    end
  end
end
function Celebration:OnRemoveFromEntity() self:Finish() end
Celebration.OnRemoveEntity = Celebration.OnRemoveFromEntity
return Celebration
