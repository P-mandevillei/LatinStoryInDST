-- Only the peaceful formation and Lupa's escape are custom movement. The
-- four hostile Animi use their original boss brains and stategraphs.
local CourtMove = Class(BehaviourNode, function(self, inst)
  BehaviourNode._ctor(self, "CourtMove")
  self.inst = inst
end)
function CourtMove:Visit()
  self.status = RUNNING
  local inst, guard = self.inst, self.inst.components.kingguard
  local destination = guard:GetDestination()
  if destination ~= nil and not inst.sg:HasStateTag("busy") then
    local point = inst:GetPosition()
    if (destination.x-point.x)^2 + (destination.z-point.z)^2 > .5^2 then
      inst.components.locomotor:GoToPoint(destination, nil, guard.escaping == true)
    else
      inst.components.locomotor:Stop()
    end
  end
  self:Sleep(.25)
end
function CourtMove:OnStop() self.inst.components.locomotor:Stop() end
local CourtBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function CourtBrain:OnStart() self.bt = BT(self.inst, CourtMove(self.inst)) end
return CourtBrain
