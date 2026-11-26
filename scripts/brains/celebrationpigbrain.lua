local HELPERS = require("helpers")
local Run = Class(BehaviourNode, function(self, inst)
  BehaviourNode._ctor(self, "Celebrate")
  self.inst = inst
end)
function Run:Visit()
  self.status = RUNNING
  local inst, party = self.inst, self.inst.components.libelluspigcelebrant
  if party.king == nil or not party.king:IsValid() or inst.components.health:IsDead() then
    self:Sleep(HELPERS.CLOSING_CHECK_INTERVAL)
    return
  end
  if inst.sg:HasStateTag("busy") then self:Sleep(HELPERS.CLOSING_CHECK_INTERVAL); return end
  if self.target == nil or GetTime() >= self.turntime
    or inst:GetDistanceSqToPoint(self.target) <= HELPERS.CLOSING_PIG_ARRIVAL_DISTANCE^2 then
    self.angle = (self.angle or math.random()*2*math.pi)+math.pi
    self.target = HELPERS.FindClosingPoint(party.king:GetPosition(), self.angle,
      math.random(HELPERS.CLOSING_PIG_MIN_RADIUS, HELPERS.CLOSING_PIG_MAX_RADIUS))
    self.turntime = GetTime()+HELPERS.CLOSING_PIG_TURN_INTERVAL
  end
  if self.target ~= nil then inst.components.locomotor:GoToPoint(self.target, nil, true) end
  self:Sleep(HELPERS.CLOSING_CHECK_INTERVAL)
end
function Run:OnStop() self.inst.components.locomotor:Stop() end
local PigBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function PigBrain:OnStart() self.bt = BT(self.inst, Run(self.inst)) end
return PigBrain
