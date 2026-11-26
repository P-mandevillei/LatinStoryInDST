local HELPERS = require("helpers")

local SenexShorePush = Class(function(self, inst)
  self.inst = inst
  inst:ListenForEvent("gotosleep", function() self:Enable() end)
  inst:ListenForEvent("onwakeup", function() self:Disable() end)
  inst:ListenForEvent("death", function() self:Disable() end)
end)

function SenexShorePush:CanPush(doer)
  local inst = self.inst
  return self.destination == nil and inst.components.sleeper:IsAsleep()
    and not inst.components.health:IsDead() and doer ~= nil and doer:IsValid()
    and doer:HasTag("player") and not doer:HasTag("playerghost") and not doer.loadingprotection
    and doer.components.health ~= nil and not doer.components.health:IsDead()
    and doer:GetCurrentPlatform() == inst:GetCurrentPlatform()
    and doer:IsNear(inst, 3)
end

function SenexShorePush:IsClearOfObstacles(point)
  local inst = self.inst
  local boat = self.ship or inst:GetCurrentPlatform() or inst._ship
  local radius = inst:GetPhysicsRadius(0) + .15
  -- boat_item_collision is an invisible, boat-sized mesh with NOBLOCK, but
  -- unlike the player boundary it has no NOCLICK tag. It must not block a
  -- scripted shove of a character across its own deck.
  for _, ent in ipairs(TheSim:FindEntities(point.x, 0, point.z, radius + 4,
    nil, {"FX", "DECOR", "INLIMBO", "NOCLICK", "NOBLOCK"})) do
    -- The shove passes over deck furniture, including parented attachments.
    -- GetCurrentPlatform also follows parents, so mast lamps/sails inherit it.
    if ent ~= inst and ent ~= self.pusher and ent ~= boat
      and (boat == nil or ent:GetCurrentPlatform() ~= boat) then
      local other = ent:GetPhysicsRadius(0)
      if other > 0 and ent:GetDistanceSqToPoint(point) < (radius + other)^2 then return false end
    end
  end
  return true
end

function SenexShorePush:IsClearLand(point)
  local inst, map = self.inst, TheWorld.Map
  local radius = inst:GetPhysicsRadius(0) + .15
  for i = 0, 8 do
    local angle = i * math.pi / 4
    local x = point.x + (i == 8 and 0 or math.cos(angle) * radius)
    local z = point.z + (i == 8 and 0 or math.sin(angle) * radius)
    if not map:IsLandTileAtPoint(x, 0, z) or not map:IsPassableAtPoint(x, 0, z)
      or map:IsPointNearHole(Vector3(x, 0, z)) then return false end
  end
  local platform = inst._ship
  if platform ~= nil and platform:IsValid() then
    local r = platform.components.walkableplatform.platform_radius or TUNING.BOAT.RADIUS
    if platform:GetDistanceSqToPoint(point) <= (r + radius)^2 then return false end
  end
  return self:IsClearOfObstacles(point)
end

function SenexShorePush:Enable()
  if self.inst.components.pushable ~= nil then return end
  self.inst:AddComponent("pushable")
  local pushable = self.inst.components.pushable
  pushable:SetPushingSpeed(HELPERS.SENEX_PUSH_SPEED)
  pushable:SetTargetDist(1.2)
  pushable:SetMinDist(.7)
  pushable:SetMaxDist(2.5)
  pushable:SetOnStartPushingFn(function(inst, doer)
    if not self:CanPush(doer) then pushable:StopPushing(); return end
    self.pusher = doer
    local from, player = inst:GetPosition(), doer:GetPosition()
    -- Sleep states are busy, so EntityScript:FacePoint silently refuses this
    -- turn. A shove must explicitly face away from the pusher before aiming.
    inst:ForceFacePoint(from.x * 2 - player.x, 0, from.z * 2 - player.z)
    self:BeginShove()
    -- The native action supplies the push animation, but movement is a single
    -- shove: it continues after the player releases the secondary button.
    pushable:StopPushing()
  end)
  pushable:SetOnStopPushingFn(function() if self.destination == nil then self.pusher = nil end end)
end

function SenexShorePush:IsOnDeck(point, platform, wholebody)
  if platform == nil or not platform:IsValid() then return false end
  local radius = platform.components.walkableplatform.platform_radius or TUNING.BOAT.RADIUS
  if wholebody then radius = radius - self.inst:GetPhysicsRadius(0) - .15 end
  return radius > 0 and platform:GetDistanceSqToPoint(point) <= radius^2
end

function SenexShorePush:FindDestination(from, dx, dz, platform)
  local radius = platform ~= nil and platform.components.walkableplatform.platform_radius or TUNING.BOAT.RADIUS
  local distance = math.max(HELPERS.SENEX_PUSH_DISTANCE, radius * 2 + 2)
  local deck, land = platform ~= nil and from or nil, nil
  local water = 0
  for step = .25, distance, .25 do
    local point = Vector3(from.x + dx * step, 0, from.z + dz * step)
    if not self:IsClearOfObstacles(point) then break end
    local ondeck = self:IsOnDeck(point, platform, false)
    local onland = TheWorld.Map:IsLandTileAtPoint(point.x, 0, point.z)
    if onland and (not TheWorld.Map:IsPassableAtPoint(point.x, 0, point.z)
      or TheWorld.Map:IsPointNearHole(point)) then break end
    water = (ondeck or onland) and 0 or water + .25
    if water > HELPERS.SENEX_SHORE_GAP then break end
    if self:IsOnDeck(point, platform, true) then deck = point end
    if self:IsClearLand(point) then land = point end
  end
  -- Prefer the furthest safe landing along the shove. With no reachable land,
  -- stop at the last point that still fits the whole body on the boat.
  return land or deck, land ~= nil
end

function SenexShorePush:BeginShove()
  local inst = self.inst
  local from, platform = inst:GetPosition(), inst:GetCurrentPlatform()
  local angle = inst.Transform:GetRotation() * math.pi / 180
  local target, onshore = self:FindDestination(from, math.cos(angle), -math.sin(angle), platform)
  if target == nil or inst:GetDistanceSqToPoint(target) < .01 then return end
  self.origin, self.destination, self.ship, self.landing_on_shore = from, target, platform, onshore
  if platform ~= nil then
    local pos = platform:GetPosition()
    self.deckoffset = Vector3(from.x - pos.x, 0, from.z - pos.z)
    self.destinationoffset = Vector3(target.x - pos.x, 0, target.z - pos.z)
  end
  self.progress = 0
  self.duration = math.max(.3, math.sqrt(inst:GetDistanceSqToPoint(target)) / HELPERS.SENEX_PUSH_SPEED)
  inst:StartUpdatingComponent(self)
end

function SenexShorePush:GetOrigin()
  if self.ship ~= nil and self.ship:IsValid() and self.deckoffset ~= nil then
    return self.ship:GetPosition() + self.deckoffset
  end
  return self.origin
end

function SenexShorePush:GetDestination()
  if not self.landing_on_shore and self.ship ~= nil and self.ship:IsValid() then
    return self.ship:GetPosition() + self.destinationoffset
  end
  return self.destination
end

function SenexShorePush:ClearShove()
  self.origin, self.destination, self.ship, self.deckoffset = nil, nil, nil, nil
  self.destinationoffset, self.landing_on_shore, self.pusher = nil, nil, nil
  self.inst:StopUpdatingComponent(self)
end

function SenexShorePush:RestoreOrigin()
  if self.origin ~= nil then
    self.inst.Physics:Teleport(self:GetOrigin():Get())
    if self.ship ~= nil and self.ship:IsValid() then
      self.ship.components.walkableplatform:AddEntityToPlatform(self.inst)
    end
  end
  self:ClearShove()
end

function SenexShorePush:OnUpdate(dt)
  if self.destination == nil then return end
  local target = self:GetDestination()
  if not self.inst.components.sleeper:IsAsleep() or self.inst.components.health:IsDead()
    or (self.ship ~= nil and not self.ship:IsValid())
    or (self.landing_on_shore and not self:IsClearLand(target))
    or (not self.landing_on_shore and not self:IsOnDeck(target, self.ship, true)) then
    self:RestoreOrigin()
    return
  end
  self.progress = math.min(1, self.progress + dt / self.duration)
  local from, t = self:GetOrigin(), self.progress
  self.inst.Physics:Teleport(from.x + (target.x - from.x) * t, 0, from.z + (target.z - from.z) * t)
  if t >= 1 then
    if self.landing_on_shore then
      if self.ship ~= nil then
        self.ship.components.walkableplatform:RemoveObject(self.inst)
        self.ship:RemovePlatformFollower(self.inst)
      end
      self.inst._shore_home = target
    end
    self:ClearShove()
  end
end

function SenexShorePush:Disable()
  self:RestoreOrigin()
  if self.inst.components.pushable ~= nil then self.inst:RemoveComponent("pushable") end
end

-- Saves taken halfway across a gap restore the last safe deck position.
function SenexShorePush:OnSave()
  if self.origin ~= nil then
    local point = self:GetOrigin()
    return {origin = {x = point.x, z = point.z}, onshore = self.ship == nil}
  end
end

function SenexShorePush:OnLoad(data)
  if data ~= nil and data.origin ~= nil then
    self.inst:DoTaskInTime(0, function(inst)
      inst.Physics:Teleport(data.origin.x, 0, data.origin.z)
      if not data.onshore and inst._ship ~= nil and inst._ship:IsValid() then
        inst._ship.components.walkableplatform:AddEntityToPlatform(inst)
      end
    end)
  end
end

SenexShorePush.OnRemoveFromEntity = SenexShorePush.Disable
return SenexShorePush
