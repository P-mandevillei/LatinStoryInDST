-- Temporary, saved per-entity sleep lease. Restoring on load also handles a
-- player saving on another shard or a scene interrupted by disconnecting.
local CastleSleep = Class(function(self, inst)
  self.inst = inst
end)
function CastleSleep:Begin()
  if self.saved ~= nil then self:Force(); return end
  local inst = self.inst
  local sleeper, groggy = inst.components.sleeper, inst.components.grogginess
  self.saved = {
    asleep = sleeper ~= nil and sleeper:IsAsleep() or false,
    deep = sleeper ~= nil and sleeper:IsInDeepSleep() or false,
    sleep_remaining = sleeper ~= nil and math.max(0, (sleeper.testtime or 0)
      - (GetTime()-(sleeper.lasttesttime or GetTime()))) or nil,
    knockedout = groggy ~= nil and groggy:IsKnockedOut() or false,
    grog_amount = groggy ~= nil and groggy.grog_amount or nil,
  }
  if sleeper ~= nil then self._wake_test = sleeper.waketestfn end
  if groggy ~= nil then self._come_to_test = groggy.cometotestfn end
  self._runtime = true
  inst:StopBrain("libellus_castle_night")
  if inst.components.combat ~= nil then inst.components.combat:DropTarget() end
  if inst.components.locomotor ~= nil then inst.components.locomotor:Stop() end
  self:Force()
end
function CastleSleep:Force()
  local inst = self.inst
  if self.saved == nil or (inst.components.health ~= nil and inst.components.health:IsDead()) then return end
  local sleeper, groggy = inst.components.sleeper, inst.components.grogginess
  if groggy ~= nil then
    groggy.cometotestfn = function() return false end
    if not groggy:IsKnockedOut() then groggy:KnockOut() end
  elseif sleeper ~= nil then
    sleeper.waketestfn = function() return false end
    if not sleeper:IsAsleep() then sleeper:GoToSleep() end
    sleeper:StopTesting()
  end
  -- Our stationary humanoids, and creatures without a native sleeper, still
  -- need a visible rest state. Native sleepers keep their own SG animations.
  if sleeper == nil and groggy == nil then
    if inst.sg ~= nil and inst.sg.sg.states.sleep ~= nil then
      if not inst.sg:HasStateTag("sleeping") then inst.sg:GoToState("sleep") end
    elseif inst.prefab == "lupa" then
      inst.AnimState:PlayAnimation("sleep_loop", true)
      self._hound_rest = true
    elseif inst.AnimState ~= nil then
      if inst.sg ~= nil and inst.sg.sg.states.idle ~= nil then inst.sg:GoToState("idle") end
      inst.AnimState:Pause()
      self._paused = true
    end
  end
end
function CastleSleep:Finish()
  local saved, inst = self.saved, self.inst
  if saved == nil then return end
  self.saved = nil
  local sleeper, groggy = inst.components.sleeper, inst.components.grogginess
  if sleeper ~= nil then
    -- After a load, the prefab has constructed its original wake function.
    if self._runtime then sleeper.waketestfn = self._wake_test end
    if saved.asleep then
      sleeper:GoToSleep(saved.deep and saved.sleep_remaining or nil)
    else
      sleeper:WakeUp()
    end
  elseif groggy == nil and inst.sg ~= nil and inst.sg:HasStateTag("sleeping") then
    inst:PushEvent("onwakeup")
    if inst.sg:HasStateTag("sleeping") then inst.sg:GoToState("idle") end
  end
  if groggy ~= nil then
    if self._runtime then groggy.cometotestfn = self._come_to_test end
    if not saved.knockedout then groggy:ComeTo() end
    groggy.grog_amount = saved.grog_amount or 0
  end
  if self._paused and inst.AnimState ~= nil then inst.AnimState:Resume() end
  if self._hound_rest then inst.AnimState:PlayAnimation("idle", true) end
  inst:RestartBrain("libellus_castle_night")
end
function CastleSleep:OnSave() return self.saved end
function CastleSleep:OnLoad(data)
  self.saved = data
  self.inst:DoTaskInTime(0, function() self:Finish() end)
end
function CastleSleep:OnRemoveFromEntity() self:Finish() end
return CastleSleep
