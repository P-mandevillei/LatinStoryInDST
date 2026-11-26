local CourtBrain = require("brains/kingcourtbrain")
local KingGuard = Class(function(self, inst)
  self.inst = inst
  self.offset = {x = 0, z = 0}
  inst.components.combat:SetShouldAggroFn(function(_, target)
    return self.hostile and self:IsStoryTarget(target)
  end)
  local native_targetfn = inst.components.combat.targetfn
  inst.components.combat:SetRetargetFunction(1, function()
    -- Dragonfly and Bee Queen refresh their native group-target lists here;
    -- their summons and special moves depend on those side effects.
    if self.hostile and native_targetfn ~= nil then native_targetfn(inst) end
    return self:FindTarget(), true
  end)
  inst.components.combat:SetKeepTargetFunction(function(_, target) return self:IsStoryTarget(target) end)
  -- Native area attacks must not kill the king or the escaping Lupa.
  local can_target = inst.components.combat.CanTarget
  inst.components.combat.CanTarget = function(combat, target, ...)
    return target ~= nil and not target:HasTag("libellus_court")
      and can_target(combat, target, ...)
  end
  inst:SetBrain(CourtBrain)
  inst:DoPeriodicTask(1, function() self:Update() end)
end)
function KingGuard:IsStoryTarget(target)
  return target ~= nil and target:IsValid() and target:HasTag("player")
    and target.userid == self.enemyuserid and not target:HasTag("playerghost")
    and not target.loadingprotection and target.components.health ~= nil
    and not target.components.health:IsDead()
end
function KingGuard:FindTarget()
  if not self.hostile then return end
  for _, player in ipairs(AllPlayers) do
    if self:IsStoryTarget(player) then return player end
  end
end
function KingGuard:GetDestination()
  if self.escaping then return self.escape end
  local king = self.inst._castle ~= nil and self.inst._castle._king or nil
  if king ~= nil and king:IsValid() then
    local point = king:GetPosition()
    return Vector3(point.x+self.offset.x, 0, point.z+self.offset.z)
  end
end
function KingGuard:AttackPlayer(userid)
  self.hostile, self.enemyuserid = true, userid
  self:Update()
end
function KingGuard:Escape(point)
  self.escaping, self.escape, self.hostile = true, point, false
  self.inst:AddTag("groundpound_immune")
  self.inst.components.combat:DropTarget()
  if self.inst.components.sleeper ~= nil then self.inst.components.sleeper:WakeUp() end
  self.inst:ClearBufferedAction()
  self.inst.components.locomotor.runspeed = 12
  self.inst:SetBrain(CourtBrain)
end
function KingGuard:Update()
  local inst = self.inst
  if inst.components.health:IsDead() then return end
  if self.hostile then
    if not self._native_active then
      self._native_active = true
      inst:SetBrain(inst._king_native_brain)
      if inst.components.sleeper ~= nil then inst.components.sleeper:WakeUp() end
      if inst.components.knownlocations ~= nil then
        inst.components.knownlocations:RememberLocation("spawnpoint", inst:GetPosition(), false)
      end
    end
    local target = self:FindTarget()
    if target ~= nil then inst.components.combat:SetTarget(target) end
  end
end
function KingGuard:OnSave()
  return {hostile = self.hostile, enemyuserid = self.enemyuserid, offset = self.offset,
    escaping = self.escaping, escape = self.escape ~= nil and {x = self.escape.x, z = self.escape.z} or nil}
end
function KingGuard:OnLoad(data)
  if data == nil then return end
  self.hostile, self.enemyuserid = data.hostile, data.enemyuserid
  self.offset, self.escaping = data.offset or self.offset, data.escaping
  if data.escape ~= nil then self:Escape(Vector3(data.escape.x, 0, data.escape.z)) end
end
return KingGuard
