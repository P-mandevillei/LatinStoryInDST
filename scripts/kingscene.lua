local Scene = {}
function Scene.GetClock()
  return TheWorld.net ~= nil and TheWorld.net.components.clock or TheWorld.components.clock
end
function Scene.HoldClock()
  local owner, clock = TheWorld.net or TheWorld, Scene.GetClock()
  owner:StopUpdatingComponent(clock)
  clock:OnUpdate(0)
end
function Scene.RestoreClock(snapshot)
  local owner, clock = TheWorld.net or TheWorld, Scene.GetClock()
  clock:OnLoad(snapshot)
  clock:OnUpdate(0)
  owner:StartUpdatingComponent(clock, not TheNet:IsDedicated())
end
function Scene.PrepareFootLanding(castle)
  if castle._foot_water_check ~= nil then return end
  local footer = TheWorld.components.bigfooter
  castle._foot_water_check = footer.CheckForWater
  castle._foot_water_wrapper = function(self, point)
    local center = castle:GetPosition()
    if math.abs(point.x-center.x) <= 9 and math.abs(point.z-center.z) <= 9 then
      -- Bigfoot Returns' legacy tile-ID comparison classifies modern Gold
      -- Flooring as water. Use current land checks only inside this castle,
      -- so the central foot lands on Rex rather than shifting to its carpet.
      for i = 0, 7 do
        local angle = i*math.pi/4
        local x, z = point.x+4*math.cos(angle), point.z+4*math.sin(angle)
        if not TileGroupManager:IsLandTile(TheWorld.Map:GetTileAtPoint(x, 0, z)) then return true end
      end
      return nil
    end
    return castle._foot_water_check(self, point)
  end
  footer.CheckForWater = castle._foot_water_wrapper
end
function Scene.FinishFootLanding(castle)
  local footer = TheWorld.components.bigfooter
  if footer ~= nil and footer.CheckForWater == castle._foot_water_wrapper then
    footer.CheckForWater = castle._foot_water_check
  end
  castle._foot_water_check, castle._foot_water_wrapper = nil, nil
end
function Scene.SleepOthers(player, lupa)
  for _, ent in pairs(Ents) do
    if ent ~= player and ent ~= lupa and ent:IsValid() and not ent:HasTag("INLIMBO")
      and not ent:HasTag("playerghost") and not ent:HasTag("wall") and not ent:HasTag("structure")
      and (ent.components.sleeper ~= nil or ent.components.grogginess ~= nil
        or ent:HasTag("character") or ent:HasTag("companion") or ent:HasTag("king")
        or (ent.components.health ~= nil and ent.components.combat ~= nil)) then
      if ent.components.libelluscastlesleep == nil then ent:AddComponent("libelluscastlesleep") end
      ent.components.libelluscastlesleep:Begin()
    end
  end
end
function Scene.WakeOthers()
  for _, ent in pairs(Ents) do
    if ent:IsValid() and ent.components.libelluscastlesleep ~= nil then
      ent.components.libelluscastlesleep:Finish()
      ent:RemoveComponent("libelluscastlesleep")
    end
  end
end
function Scene.SetupFoot(inst)
  if not TheWorld.ismastersim then return end
  local stomp = inst.Stomp
  inst.Stomp = function(inst, ...)
    stomp(inst, ...)
    -- Tie the scripted death to the real animated foot landing, including
    -- dependency configurations whose damage cannot kill a crowned king.
    for _, ent in pairs(Ents) do
      if ent.prefab == "king_castle" and ent._betrayed and not ent._king_dead then
        local king = ent._king
        if king ~= nil and king:IsValid() and inst:IsNear(king, 2) then
          king.components.health:DoDelta(-king.components.health.maxhealth, false,
            "bigfoot", true, inst, true)
        end
      end
    end
  end
end
return Scene
