local HELPERS = require("helpers")

local FlyToGrove = Class(BehaviourNode, function(self, inst)
  BehaviourNode._ctor(self, "FlyToGrove")
  self.inst = inst
end)

function FlyToGrove:Visit()
  self.status = RUNNING
  local inst, target = self.inst, self.inst._flight_target
  if target ~= nil and not inst._arrived and not inst._landing then
    if inst._flight_started == nil then
      inst._flight_started = GetTime()
      inst._flight_from = inst:GetPosition()
      inst._flight_last_update = GetTime()
      local from = inst._flight_from
      inst._flight_distance = math.sqrt((target.x-from.x)^2 + (target.z-from.z)^2)
      inst:FacePoint(target:Get())
      inst.sg:GoToState("flight")
    end
    local speed = inst._flight_speed or HELPERS.PASSER_FLIGHT_SPEED
    if inst._guide_userid ~= nil then
      for _, player in ipairs(AllPlayers) do
        if player.userid == inst._guide_userid and player.components.locomotor ~= nil then
          speed = player.components.locomotor:GetWalkSpeed()
          break
        end
      end
    end
    local dt = GetTime() - inst._flight_last_update
    inst._flight_last_update = GetTime()
    local point = inst:GetPosition()
    local dx, dz = target.x-point.x, target.z-point.z
    local remaining = math.sqrt(dx*dx + dz*dz)
    local step = math.min(remaining, speed*dt)
    local t = inst._flight_distance > 0 and 1 - (remaining-step)/inst._flight_distance or 1
    local from = inst._flight_from
    inst.Transform:SetPosition(remaining > 0 and point.x + dx*step/remaining or target.x,
      from.y*(1-t) + math.sin(math.pi*t)*HELPERS.PASSER_FLIGHT_HEIGHT,
      remaining > 0 and point.z + dz*step/remaining or target.z)
    if step >= remaining then
      inst.Transform:SetPosition(target:Get())
      inst._landing = true
      inst.sg:GoToState("land")
    end
  end
  self:Sleep(inst._arrived and 2 or .05)
end

local PasserBrain = Class(Brain, function(self, inst) Brain._ctor(self, inst) end)
function PasserBrain:OnStart()
  self.bt = BT(self.inst, FlyToGrove(self.inst))
end
return PasserBrain
