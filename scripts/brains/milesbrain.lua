require "behaviours/chaseandattack"
require "behaviours/leash"
require "behaviours/standstill"

local MilesBrain = Class(Brain, function(self, inst)
  Brain._ctor(self, inst)
end)

function MilesBrain:OnStart()
  self.bt = BT(self.inst, PriorityNode({
    ChaseAndAttack(self.inst),
    Leash(self.inst, function() return self.inst._guardpoint end, 1, .5),
    StandStill(self.inst)
  }, .1))
end

return MilesBrain
