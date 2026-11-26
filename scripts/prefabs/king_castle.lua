local HELPERS = require("helpers")
local DIALOG = require("libellus")
local Scene = require("kingscene")
local prefabs = {"rex", "king_lupa", "animus_dragonfly", "animus_deerclops",
  "animus_bearger", "animus_beequeen", "wall_stone", "king_scene_light", "globalmapiconnamed"}

local function Alive(ent)
  return ent ~= nil and ent:IsValid() and (ent.components.health == nil or not ent.components.health:IsDead())
end
local function SpawnAt(inst, name, dx, dz)
  local ent = SpawnPrefab(name)
  if ent ~= nil then
    local x, _, z = inst.Transform:GetWorldPosition()
    ent.Transform:SetPosition(x+dx, 0, z+dz)
  end
  return ent
end
local function Floor(inst)
  local map, point = TheWorld.Map, inst:GetPosition()
  -- Native terrain has a four-unit grid. The outer 20x20 square is lush
  -- carpet; its central 12x12 world units are gold inside the 18x18 walls.
  -- This retains a visible carpet border without altering ocean tiles.
  local tx, tz = map:GetTileCoordsAtPoint(point.x, 0, point.z)
  for dx = -2, 2 do
    for dz = -2, 2 do
      if TileGroupManager:IsLandTile(map:GetTile(tx+dx, tz+dz)) then
        map:SetTile(tx+dx, tz+dz, math.abs(dx) < 2 and math.abs(dz) < 2
          and WORLD_TILES.COTL_GOLD or WORLD_TILES.CARPET2)
      end
    end
  end
end
local function Populate(inst)
  if inst._populated then return end
  inst._populated = true
  for _, ent in ipairs(HELPERS.GetCastleSiteEntities(inst:GetPosition())) do
    if HELPERS.CanClearForPasser(ent) then ent:Remove() end
  end
  Floor(inst)
  local half = HELPERS.CASTLE_SIZE/2
  for n = -half+1, half do
    for _, side in ipairs({-1, 1}) do
      local wall = SpawnAt(inst, "wall_stone", side*(half-.5), n-.5)
      if wall ~= nil then wall.components.health:SetPercent(1); table.insert(inst._walls, wall) end
      if n > -half+1 and n < half and math.abs(n-.5) >= 4 then
        wall = SpawnAt(inst, "wall_stone", n-.5, side*(half-.5))
        if wall ~= nil then wall.components.health:SetPercent(1); table.insert(inst._walls, wall) end
      end
    end
  end
  inst._king = SpawnAt(inst, "rex", 0, -2)
  if inst._king ~= nil then inst._king._castle = inst end
  local court = {
    {"animus_dragonfly", -5, -5}, {"animus_deerclops", 5, -5},
    {"animus_bearger", -5, 4}, {"animus_beequeen", 5, 4}, {"king_lupa", 0, 3},
  }
  for _, entry in ipairs(court) do
    local ent = SpawnAt(inst, entry[1], entry[2], entry[3])
    if ent ~= nil then
      ent._castle = inst
      ent.components.kingguard.offset = {x = entry[2], z = entry[3]+2}
      if entry[1] == "king_lupa" then inst._lupa = ent
      else table.insert(inst._guards, ent) end
    end
  end
end
local function EndNight(inst, player)
  if inst._night_clock == nil or (player ~= nil and inst._night_userid ~= player.userid) then return end
  Scene.RestoreClock(inst._night_clock)
  inst._night_clock, inst._night_userid = nil, nil
  Scene.WakeOthers()
  for _, light in ipairs(inst._lights) do if light:IsValid() then light:Remove() end end
  inst._lights = {}
end
local function BeginNight(inst, player)
  if inst._night_clock ~= nil and inst._night_userid ~= player.userid then return false end
  if inst._night_clock == nil then
    inst._night_clock = Scene.GetClock():OnSave()
    inst._night_userid = player.userid
    TheWorld:PushEvent("ms_setclocksegs", {day = 0, dusk = 0, night = 16})
    TheWorld:PushEvent("ms_setphase", "night")
    -- Keep the temporary scene from advancing cycles if its player waits a
    -- long time before seeing Lupa. Other simulation updates still run.
    Scene.HoldClock()
    for _, target in ipairs({player, inst._lupa}) do
      if target ~= nil and target:IsValid() then
        local light = SpawnPrefab("king_scene_light")
        if light ~= nil then
          light.entity:SetParent(target.entity)
          light.Transform:SetPosition(0, 1, 0)
          table.insert(inst._lights, light)
        end
      end
    end
  end
  Scene.SleepOthers(player, inst._lupa)
  return true
end
local function FindEscape(inst)
  local from = inst._lupa:GetPosition()
  local king = inst._king:GetPosition()
  -- Both wide exits are open. Search a continuous, body-wide land route,
  -- preferring the front exit and avoiding cliff-edge escape destinations.
  local best, distance
  for _, sign in ipairs({1, -1}) do
    for spread = -2, 2 do
      local dx, dz = spread*.1, sign
      local length = math.sqrt(dx*dx+dz*dz)
      dx, dz = dx/length, dz/length
      for step = 1, 32 do
        local point = Vector3(from.x+dx*step, 0, from.z+dz*step)
        local clear = true
        for _, side in ipairs({-.6, 0, .6}) do
          local sample = Vector3(point.x+dz*side, 0, point.z-dx*side)
          if not TheWorld.Map:IsPassableAtPoint(sample.x, 0, sample.z)
            or TheWorld.Map:IsPointNearHole(sample) then clear = false; break end
        end
        if not clear then break end
        local d = (point.x-king.x)^2+(point.z-king.z)^2
        if distance == nil or d > distance then best, distance = point, d end
      end
    end
  end
  return best or from
end
local function Summon(inst, bell)
  if not Alive(inst._king) then return end
  Scene.PrepareFootLanding(inst)
  local point = inst._king:GetPosition()
  local previous_target = TheWorld.components.bigfooter.targetPos
  if bell ~= nil then
    inst._king.sg:GoToState("ring")
    bell.components.instrument:Play(inst._king)
    if bell.components.finiteuses ~= nil then bell.components.finiteuses:Use(1) end
  else
    -- The dependency doesn't save in-flight foot tasks. Resume a pending
    -- stomp after loading without accepting or consuming another gift.
    TheWorld.components.bigfooter:SummonFoot(point)
  end
  local footer = TheWorld.components.bigfooter
  -- Its "no warning steps" configuration disables SummonFoot entirely.
  -- Still supply the requested central animated stomp for this story.
  if footer.targetPos == previous_target then
    footer.reset = false
    inst:DoTaskInTime(2, function()
      if not Alive(inst._king) then return end
      local foot = SpawnPrefab("bigfoot")
      if foot ~= nil then
        foot.Transform:SetPosition(point:Get())
        foot:TryPerformStep()
      end
    end)
  end
end
local function ReceiveBell(inst, player, bell)
  if inst._betrayed or not Alive(inst._king) then return false end
  inst._betrayed, inst._betrayeruserid = true, player.userid
  EndNight(inst)
  if Alive(inst._lupa) then inst._lupa.components.kingguard:Escape(FindEscape(inst)) end
  inst._court_rallying, inst._court_hold_until = true, nil
  for _, guard in ipairs(inst._guards) do
    if Alive(guard) then guard.components.kingguard:GatherForBell(player.userid) end
  end
  player.components.libellusprogress:OnKingBellReceived(inst)
  Summon(inst, bell)
  return true
end
local function CheckCourt(inst)
  if not inst._court_rallying then return end
  for _, guard in ipairs(inst._guards) do
    if Alive(guard) and not guard.components.kingguard:IsAtGatherPoint() then
      inst._court_hold_until = nil
      return
    end
  end
  -- The whole surviving court must arrive and remain beside Rex for the
  -- full pause; travel time never counts toward the four-second wait.
  inst._court_hold_until = inst._court_hold_until or GetTime()+HELPERS.KING_COURT_HOLD_TIME
  if GetTime() < inst._court_hold_until then return end
  inst._court_rallying, inst._court_hold_until = nil, nil
  for _, guard in ipairs(inst._guards) do
    if Alive(guard) then guard.components.kingguard:AttackPlayer(inst._betrayeruserid) end
  end
end
local function OnKingDeath(inst)
  inst._king_dead = true
  Scene.FinishFootLanding(inst)
  for _, player in ipairs(AllPlayers) do
    if player.userid == inst._betrayeruserid and player.components.libellusprogress ~= nil then
      player.components.libellusprogress:OnHumanKingDeath(inst)
    end
  end
end
local function CheckNight(inst)
  if inst._night_clock == nil then return end
  for _, player in ipairs(AllPlayers) do
    if player.userid == inst._night_userid then
      local progress = player.components.libellusprogress
      if progress ~= nil and progress.chapter == "ch6" and progress.dialog > DIALOG.CH6_SEP[1]
        and (progress.dialog <= DIALOG.CH6_SEP[2] or (progress.dialog == DIALOG.CH6_SEP[2] + 1
          and progress._ch6_pending ~= nil and progress._ch6_pending.line == DIALOG.CH6_SEP[2]))
        and not player:HasTag("playerghost") then
        Scene.SleepOthers(player, inst._lupa)
        Scene.GetClock():OnUpdate(0)
        return
      end
    end
  end
  EndNight(inst)
end
local function OnSave(inst, data)
  data.populated, data.betrayed, data.king_dead = inst._populated, inst._betrayed, inst._king_dead
  data.betrayeruserid = inst._betrayeruserid
  data.court_rallying = inst._court_rallying
  data.court_hold_remaining = inst._court_hold_until ~= nil
    and math.max(0, inst._court_hold_until-GetTime()) or nil
  data.night_clock = inst._night_clock
  local refs = {}
  for _, field in ipairs({"_king", "_lupa"}) do
    local ent = inst[field]
    if ent ~= nil and ent:IsValid() and ent.persists ~= false then
      data[field] = ent.GUID
      table.insert(refs, ent.GUID)
    end
  end
  for _, field in ipairs({"_guards", "_walls"}) do
    data[field] = {}
    for _, ent in ipairs(inst[field]) do
      if ent:IsValid() then table.insert(data[field], ent.GUID); table.insert(refs, ent.GUID) end
    end
  end
  return refs
end
local function OnLoadPostPass(inst, ents, data)
  if data == nil then return end
  for _, field in ipairs({"_king", "_lupa"}) do
    inst[field] = data[field] ~= nil and ents[data[field]] ~= nil and ents[data[field]].entity or nil
    if inst[field] ~= nil then inst[field]._castle = inst end
  end
  for _, field in ipairs({"_guards", "_walls"}) do
    for _, guid in ipairs(data[field] or {}) do
      if ents[guid] ~= nil then
        local ent = ents[guid].entity
        if field == "_guards" then ent._castle = inst end
        table.insert(inst[field], ent)
      end
    end
  end
  if inst._king ~= nil and not Alive(inst._king) then inst._king_dead = true end
  if inst._betrayed and not inst._king_dead then
    inst:DoTaskInTime(1, function() Summon(inst) end)
  end
end
local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddNetwork()
  inst.MiniMapEntity:SetIcon("pigking.png")
  inst.MiniMapEntity:SetPriority(10)
  inst.MiniMapEntity:SetDrawOverFogOfWar(true)
  inst:AddTag("NOBLOCK")
  inst:AddTag("NOCLICK")
  inst.displaynamefn = function() return "Regia" end
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst._guards, inst._walls, inst._lights = {}, {}, {}
  inst:AddComponent("maprevealable")
  inst.components.maprevealable:SetIconPrefab("globalmapiconnamed")
  inst.components.maprevealable:SetIcon("pigking.png")
  inst.components.maprevealable:SetIconPriority(10)
  inst.components.maprevealable:SetOnIconCreatedFn(function(_, icon) icon._target_displayname:set("Regia") end)
  inst.components.maprevealable:AddRevealSource("king_castle")
  inst.BeginNight, inst.EndNight = BeginNight, EndNight
  inst.ReceiveBell, inst.OnKingDeath = ReceiveBell, OnKingDeath
  inst.OnSave, inst.OnLoadPostPass = OnSave, OnLoadPostPass
  inst.OnLoad = function(inst, data)
    if data == nil then return end
    inst._populated, inst._betrayed, inst._king_dead = data.populated, data.betrayed, data.king_dead
    inst._betrayeruserid = data.betrayeruserid
    inst._court_rallying = data.court_rallying
    if data.court_hold_remaining ~= nil then
      inst._court_hold_until = GetTime()+math.max(0, data.court_hold_remaining)
    end
    -- Clock and per-entity sleep leases restore before a resumed conversation
    -- takes a new snapshot. No save can leave a world permanently at night.
    if data.night_clock ~= nil then
      inst:DoTaskInTime(0, function() Scene.RestoreClock(data.night_clock) end)
    end
  end
  inst:ListenForEvent("onremove", function() EndNight(inst); Scene.FinishFootLanding(inst) end)
  inst:DoTaskInTime(0, Populate)
  inst:DoPeriodicTask(.5, CheckNight)
  inst:DoPeriodicTask(HELPERS.KING_COURT_CHECK_INTERVAL, CheckCourt)
  return inst
end
return Prefab("king_castle", fn, nil, prefabs)
