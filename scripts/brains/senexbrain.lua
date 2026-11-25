require "behaviours/chaseandattack"
require "behaviours/leash"
require "behaviours/standstill"

local function StayAboard(inst)
  local ship = inst._ship
  if ship ~= nil and ship:IsValid() and inst:GetCurrentPlatform() ~= ship then
    inst:ClearBufferedAction()
    inst.components.locomotor:Stop()
    local x, _, z = ship.Transform:GetWorldPosition()
    inst.Physics:Teleport(x + 2, 0, z)
    ship.components.walkableplatform:AddEntityToPlatform(inst)
    inst.sg:GoToState("idle")
    return true
  end
  return false
end

local SenexBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function SenexBrain:OnStart()
  self.bt = BT(self.inst, PriorityNode({
    ConditionNode(function() return StayAboard(self.inst) end, "StayAboard"),
    ChaseAndAttack(self.inst),
    Leash(self.inst, function()
      local ship = self.inst._ship
      return ship ~= nil and ship:IsValid() and ship:GetPosition() or nil
    end, 1, .5),
    StandStill(self.inst)
  }, .1))
end
return SenexBrain
