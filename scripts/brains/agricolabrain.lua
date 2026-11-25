local Work = Class(BehaviourNode, function(self, inst)
  BehaviourNode._ctor(self, "FarmWork")
  self.inst = inst
end)

function Work:Visit()
  self.status = RUNNING
  local inst, farm = self.inst, self.inst._farm
  if inst.sg:HasStateTag("busy") then self:Sleep(.25); return end
  if inst.components.talker:IsTalking()
    or (inst._conversation_until ~= nil and GetTime() < inst._conversation_until) then
    inst.components.locomotor:Stop()
    self:Sleep(.25)
    return
  end
  if farm ~= nil and farm:IsValid() then
    if self.target == nil or not self.target:IsValid() then
      local crops = {}
      for _, crop in ipairs(farm._crops) do
        if crop:IsValid() then table.insert(crops, crop) end
      end
      self.target = #crops > 0 and crops[math.random(#crops)] or nil
    end
    if self.target ~= nil then
      if inst:IsNear(self.target, 1.2) then
        inst:FacePoint(self.target.Transform:GetWorldPosition())
        inst.sg:GoToState(self.target._ripe and "harvest" or "tend", self.target)
        self.target = nil
      else
        inst.components.locomotor:GoToPoint(self.target:GetPosition())
      end
    end
  end
  self:Sleep(.25)
end

function Work:OnStop()
  self.inst.components.locomotor:Stop()
end

local AgricolaBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function AgricolaBrain:OnStart()
  self.bt = BT(self.inst, Work(self.inst))
end
return AgricolaBrain
