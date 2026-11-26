-- The peaceful formation, gathering at Rex, and Lupa's escape use custom movement. The
-- four hostile Animi use their original boss brains and stategraphs.
local CourtMove = Class(BehaviourNode, function(self, inst)
  BehaviourNode._ctor(self, "CourtMove")
  self.inst = inst
end)
local HELPERS = require("helpers")
function CourtMove:Visit()
  self.status = RUNNING
  local inst, guard = self.inst, self.inst.components.kingguard
  local destination = guard:GetDestination()
  if destination ~= nil and not inst.sg:HasStateTag("busy") then
    local point = inst:GetPosition()
    local distance = guard.followuserid ~= nil and HELPERS.LUPA_FOLLOW_DISTANCE or HELPERS.KING_COURT_STOP_DISTANCE
    if (destination.x-point.x)^2 + (destination.z-point.z)^2 > distance^2 then
      inst.components.locomotor:GoToPoint(destination, nil, guard.escaping == true or guard.followuserid ~= nil)
    else
      inst.components.locomotor:Stop()
    end
  elseif destination == nil then
    inst.components.locomotor:Stop()
  end
  self:Sleep(HELPERS.KING_COURT_MOVE_INTERVAL)
end
function CourtMove:OnStop() self.inst.components.locomotor:Stop() end
local CourtBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function CourtBrain:OnStart() self.bt = BT(self.inst, CourtMove(self.inst)) end
return CourtBrain
