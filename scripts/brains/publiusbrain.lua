require "behaviours/follow"
require "behaviours/standstill"

local PubliusBrain = Class(Brain, function(self, inst)
  Brain._ctor(self, inst)
end)

function PubliusBrain:OnStart()
  self.bt = BT(self.inst, PriorityNode({
    Follow(self.inst, function() return self.inst.components.follower:GetLeader() end, 0, 2, 4),
    StandStill(self.inst)
  }, .25))
end

return PubliusBrain
