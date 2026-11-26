local HELPERS = require("helpers")
local CelebrationBrain = require("brains/celebrationpigbrain")
local Celebrant = Class(function(self, inst) self.inst = inst end)
function Celebrant:Join(king)
  local inst = self.inst
  if self.king == king then return true end
  local point
  if self.original == nil then
    point = HELPERS.FindClosingPoint(king:GetPosition(), math.random()*2*math.pi,
      math.random(HELPERS.CLOSING_PIG_MIN_RADIUS, HELPERS.CLOSING_PIG_MAX_RADIUS))
    if point == nil then return false end
    local from = inst:GetPosition()
    self.original = {x = from.x, z = from.z}
    self.platform = inst:GetCurrentPlatform()
    if self.platform ~= nil then
      local origin = self.platform:GetPosition()
      self.platformoffset = {x = from.x-origin.x, z = from.z-origin.z}
    end
  end
  self.oldbrain = self.oldbrain or inst.brainfn
  self.king = king
  inst:ClearBufferedAction()
  inst.components.combat:DropTarget()
  if inst.components.sleeper ~= nil then
    self.old_sleep_test = self.old_sleep_test or inst.components.sleeper.sleeptestfn
    inst.components.sleeper:WakeUp()
    inst.components.sleeper:SetSleepTest(function() return false end)
  end
  inst.components.locomotor:Stop()
  if point ~= nil then inst.Physics:Teleport(point:Get()) end
  inst:SetBrain(CelebrationBrain)
  -- Native pig run_pre/run_loop are the raised-arms running animations.
  inst.sg:GoToState("run_start")
  return true
end
function Celebrant:Finish()
  if self.original == nil then return end
  local inst, original = self.inst, self.original
  self.original, self.king = nil, nil
  if not inst:IsValid() or inst.components.health:IsDead() then return end
  inst.components.locomotor:Stop()
  if inst.components.sleeper ~= nil then inst.components.sleeper:SetSleepTest(self.old_sleep_test) end
  if self.platform ~= nil and self.platform:IsValid() and self.platformoffset ~= nil then
    local center = self.platform:GetPosition()
    inst.Physics:Teleport(center.x+self.platformoffset.x, 0, center.z+self.platformoffset.z)
  elseif TheWorld.Map:IsPassableAtPoint(original.x, 0, original.z) then
    inst.Physics:Teleport(original.x, 0, original.z)
  end
  inst.sg:GoToState("idle")
  inst:SetBrain(self.oldbrain or require(inst.prefab == "pigguard" and "brains/pigguardbrain" or "brains/pigbrain"))
end
function Celebrant:OnSave()
  if self.original == nil then return end
  local data = {original = self.original, platformoffset = self.platformoffset}
  if self.platform ~= nil and self.platform:IsValid() then
    data.platform = self.platform.GUID
    return data, {data.platform}
  end
  return data
end
function Celebrant:OnLoad(data)
  if data == nil then return end
  self.original, self.platformoffset = data.original, data.platformoffset
  -- A missing owner (e.g. a removed Pig King) must not strand a pig in its
  -- temporary brain. Post-pass reconnects a live celebration before this task.
  self.inst:DoTaskInTime(0, function() if self.king == nil then self:Finish() end end)
end
function Celebrant:LoadPostPass(ents, data)
  self.platform = data ~= nil and data.platform ~= nil and ents[data.platform] ~= nil
    and ents[data.platform].entity or nil
end
function Celebrant:OnRemoveFromEntity() self:Finish() end
return Celebrant
