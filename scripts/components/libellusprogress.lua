local DIALOG = require("libellus")
local HELPERS = require("helpers")

-- Story position persists with the player; dialogue timers restart on entry.
local LibellusProgress = Class(function(self, inst)
  self.inst = inst
  self.chapter = "ch1"
  self.dialog = 1 -- The next line to speak.
  self._progress_revision = 0 -- Runtime only; invalidates stale progress updates.
end)

function LibellusProgress:GetProgress()
  return self.chapter, self.dialog
end

-- Pass an expected revision to commit only if no other update has intervened.
-- Not passing in expected_revision makes a hard update; all event updates should be hard
function LibellusProgress:SetProgress(chapter, dialog, expected_revision)
  if expected_revision ~= nil and expected_revision ~= self._progress_revision then
    return false
  end

  self.chapter = chapter
  self.dialog = dialog
  self._ch6_pending = nil
  self._ch6_trade_ready = chapter == "ch6" and dialog == DIALOG.CH6_SEP[4] or nil
  if self._castle ~= nil and self._castle:IsValid()
    and (chapter ~= "ch6" or dialog <= DIALOG.CH6_SEP[1]
      or dialog > DIALOG.CH6_SEP[2] + 1) then self._castle:EndNight(self.inst) end
  if chapter ~= "ch3" or dialog ~= DIALOG.CH3_SEP[2] + 1 then self._ch3_reflection_time = nil end
  self._progress_revision = self._progress_revision + 1
  if self.inst._libellus_chapter ~= nil then
    self.inst._libellus_chapter:set(chapter)
    self.inst._libellus_dialog:set(dialog)
  end
  return true
end

function LibellusProgress:OnSave()
  local point = self._spawnpoint
  local data = {
    chapter = self.chapter,
    dialog = self.dialog,
    casa_cleared = self._casa_cleared,
    rex_panflute_received = self._rex_panflute_received,
    rex_bell_received = self._rex_bell_received,
    ch6_trade_ready = self._ch6_trade_ready,
    ch6_pending = self._ch6_pending ~= nil and {
      line = self._ch6_pending.line,
      remaining = math.max(0, self._ch6_pending.untiltime - GetTime()),
    } or nil,
    passer_to_rex_remaining = self._passer_to_rex_time ~= nil
      and math.max(0, self._passer_to_rex_time - GetTime()) or nil,
    ch3_reflection_remaining = self._ch3_reflection_time ~= nil
      and math.max(0, self._ch3_reflection_time - GetTime()) or nil,
    spawnpoint = point ~= nil and {x = point.x, y = point.y, z = point.z} or nil
  }
  -- Once recruited, save Publius with the player just like DST's pets. This
  -- carries him across shards and avoids leaving a second copy in the world.
  local publius = self._publius
  if publius ~= nil and publius:IsValid() and publius.persists == false then
    publius.temp_save_platform_pos = true
    data.publius = publius:GetSaveRecord()
    publius.temp_save_platform_pos = nil
  end
  return data
end

function LibellusProgress:OnLoad(data)
  if data ~= nil then
    self:SetProgress(data.chapter, data.dialog)
    self._casa_cleared = data.casa_cleared
    self._rex_panflute_received, self._rex_bell_received = data.rex_panflute_received, data.rex_bell_received
    if data.ch6_trade_ready ~= nil then self._ch6_trade_ready = data.ch6_trade_ready end
    if data.ch6_pending ~= nil then
      self._ch6_pending = {line = data.ch6_pending.line,
        untiltime = GetTime()+math.max(0, data.ch6_pending.remaining), revision = self._progress_revision}
    end
    if data.passer_to_rex_remaining ~= nil then
      self._passer_to_rex_time = GetTime() + math.max(0, data.passer_to_rex_remaining)
    end
    if data.ch3_reflection_remaining ~= nil then
      self._ch3_reflection_time = GetTime() + math.max(0, data.ch3_reflection_remaining)
    end
    if data.spawnpoint ~= nil then
      local point = data.spawnpoint
      self._spawnpoint = Vector3(point.x, point.y, point.z)
    end
    if data.publius ~= nil then
      data.publius.is_snapshot_save_record = self.inst.is_snapshot_user_session
      self._publius = SpawnSaveRecord(data.publius)
      data.publius.is_snapshot_save_record = nil
      if self._publius ~= nil then
        self._publius.persists = false
        if self.inst.migrationpets ~= nil then
          table.insert(self.inst.migrationpets, self._publius)
        end
      end
    end
  end
end

function LibellusProgress:OnRemoveEntity()
  if self._castle ~= nil and self._castle:IsValid() then self._castle:EndNight(self.inst) end
  local publius = self._publius
  if publius ~= nil and publius:IsValid() and publius.persists == false then
    publius:Remove()
  end
end

function LibellusProgress:EnsurePublius()
  if self._publius ~= nil and self._publius:IsValid() then
    return self._publius
  end

  -- A player's entity changes on reconnect; the NPC's saved owner does not.
  if self.inst.userid ~= nil then
    for _, ent in pairs(Ents) do
      if ent.prefab == "publius" and ent._libellus_owneruserid == self.inst.userid then
        self._publius = ent
        return ent
      end
    end
  end

  self._spawnpoint = self._spawnpoint or self.inst:GetPosition()
  if self._next_spawn_retry ~= nil and GetTime() < self._next_spawn_retry then
    return
  end
  self._next_spawn_retry = GetTime() + HELPERS.PUBLIUS_SPAWN_RETRY_INTERVAL

  local point = HELPERS.FindPubliusSpawnPoint(self._spawnpoint)
  if point == nil then
    return -- Keep polling if nearby grassland is temporarily obstructed.
  end
  local publius = SpawnPrefab("publius")
  if publius ~= nil then
    publius.Transform:SetPosition(point:Get())
    publius._libellus_owneruserid = self.inst.userid
    self._publius = publius
  end
  return publius
end

function LibellusProgress:EnsureCasa()
  if TheWorld:HasTag("cave") then return end
  if self._casa ~= nil and self._casa:IsValid() then return self._casa end

  if self.inst.userid ~= nil then
    for _, ent in pairs(Ents) do
      if ent.prefab == "casa" and ent._libellus_owneruserid == self.inst.userid then
        self._casa = ent
        return ent
      end
    end
  end

  self._spawnpoint = self._spawnpoint or self.inst:GetPosition()
  if self._next_casa_retry ~= nil and GetTime() < self._next_casa_retry then return end
  self._next_casa_retry = GetTime() + HELPERS.CASA_SPAWN_RETRY_INTERVAL
  local point = HELPERS.FindCasaSpawnPoint(self._spawnpoint)
  if point == nil then return end
  local casa = SpawnPrefab("casa")
  if casa ~= nil then
    casa.Transform:SetPosition(point:Get())
    casa._libellus_owneruserid = self.inst.userid
    self._casa = casa
  end
  return casa
end

function LibellusProgress:EnsureFarm()
  if TheWorld:HasTag("cave") then return end
  if self._farm ~= nil and self._farm:IsValid() then return self._farm end
  if self.inst.userid ~= nil then
    for _, ent in pairs(Ents) do
      if ent.prefab == "agricola_farm" and ent._libellus_owneruserid == self.inst.userid then
        self._farm = ent
        return ent
      end
    end
  end
  self._spawnpoint = self._spawnpoint or self.inst:GetPosition()
  if self._next_farm_retry ~= nil and GetTime() < self._next_farm_retry then return end
  self._next_farm_retry = GetTime() + HELPERS.FARM_SPAWN_RETRY_INTERVAL
  local point = HELPERS.FindFarmSpawnPoint(self._spawnpoint)
  if point == nil then return end
  local farm = SpawnPrefab("agricola_farm")
  if farm ~= nil then
    farm.Transform:SetPosition(point:Get())
    farm._libellus_owneruserid = self.inst.userid
    self._farm = farm
  end
  return farm
end

function LibellusProgress:EnsureNavis()
  if TheWorld:HasTag("cave") then return end
  if self._navis ~= nil and self._navis:IsValid() then return self._navis end
  if self.inst.userid ~= nil then
    for _, ent in pairs(Ents) do
      if ent.prefab == "navis" and ent._libellus_owneruserid == self.inst.userid then
        self._navis = ent
        return ent
      end
    end
  end
  self._spawnpoint = self._spawnpoint or self.inst:GetPosition()
  if self._next_navis_retry ~= nil and GetTime() < self._next_navis_retry then return end
  self._next_navis_retry = GetTime() + HELPERS.NAVIS_SPAWN_RETRY_INTERVAL
  local point = HELPERS.FindNavisSpawnPoint(self._spawnpoint)
  if point == nil then return end
  local navis = SpawnPrefab("navis")
  if navis ~= nil then
    navis.Transform:SetPosition(point:Get())
    navis._libellus_owneruserid = self.inst.userid
    self._navis = navis
  end
  return navis
end

function LibellusProgress:EnsurePasser()
  if TheWorld:HasTag("cave") then return end
  if self._passer_grove ~= nil and self._passer_grove:IsValid() then return self._passer_grove end
  if self.inst.userid ~= nil then
    for _, ent in pairs(Ents) do
      if ent.prefab == "passer_grove" and ent._libellus_owneruserid == self.inst.userid then
        self._passer_grove = ent
        return ent
      end
    end
  end
  self._spawnpoint = self._spawnpoint or self.inst:GetPosition()
  if self._next_passer_retry ~= nil and GetTime() < self._next_passer_retry then return end
  self._next_passer_retry = GetTime() + HELPERS.PASSER_SPAWN_RETRY_INTERVAL
  local point, dx, dz = HELPERS.FindPasserSpawnPoint(self._spawnpoint)
  if point == nil then return end
  local grove = SpawnPrefab("passer_grove")
  if grove ~= nil then
    grove.Transform:SetPosition(point:Get())
    grove._libellus_owneruserid = self.inst.userid
    grove._grove_dx, grove._grove_dz = dx, dz
    self._passer_grove = grove
  end
  return grove
end

function LibellusProgress:GetPasser()
  local passer = self._passer_grove ~= nil and self._passer_grove:IsValid() and self._passer_grove._passer or nil
  return passer ~= nil and passer:IsValid() and passer or nil
end

-- There is one human king per surface world. All players share the castle;
-- each player's sight triggers and right to offer a gift remain independent.
function LibellusProgress:EnsureCastle()
  if TheWorld:HasTag("cave") then return end
  if self._castle ~= nil and self._castle:IsValid() then return self._castle end
  for _, ent in pairs(Ents) do
    if ent.prefab == "king_castle" and ent:IsValid() then self._castle = ent; return ent end
  end
  if TheWorld._libellus_castle_retry ~= nil and GetTime() < TheWorld._libellus_castle_retry then return end
  TheWorld._libellus_castle_retry = GetTime()+HELPERS.CASTLE_SPAWN_RETRY_INTERVAL
  local point = HELPERS.FindCastleSpawnPoint()
  if point == nil then return end
  local castle = SpawnPrefab("king_castle")
  if castle ~= nil then castle.Transform:SetPosition(point:Get()); self._castle = castle end
  return castle
end

function LibellusProgress:OnPasserFreed(grove)
  if self._passer_grove ~= grove and (grove._libellus_owneruserid == nil
    or grove._libellus_owneruserid ~= self.inst.userid) then return end
  self._passer_grove = grove
  local chapter_number = tonumber(self.chapter:match("^ch(%d+)$"))
  if chapter_number ~= nil and chapter_number < 4 then
    self:SetProgress("ch4", 1)
  end
end

-- Ambient line eleven is independent of story progress, but never interrupts
-- this bird's conversation with any player.
function LibellusProgress:CheckPasserSight(inst)
  local passer = self:GetPasser()
  if passer ~= nil and not passer:HasTag("libellus_passer_free")
    and not inst.loadingprotection and not inst:HasTag("playerghost")
    and inst:IsNear(passer, HELPERS.PASSER_SEE_DISTANCE) and CanEntitySeeTarget(inst, passer)
    and not passer.components.talker:IsTalking()
    and (passer._conversation_until == nil or GetTime() >= passer._conversation_until)
    and (self._next_passer_greeting == nil or GetTime() >= self._next_passer_greeting) then
    passer.components.talker:Say(DIALOG.ch3[DIALOG.CH3_SEP[4]].content, HELPERS.DIALOG_INTERVAL)
    if passer.components.talker:IsTalking() then
      self._next_passer_greeting = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.REPEAT_INTERVAL
    end
  end
  inst:DoTaskInTime(HELPERS.CHECK_PROGRESS_INTERVAL, function(inst) self:CheckPasserSight(inst) end)
end

function LibellusProgress:EnsureRex()
  if self._rex ~= nil and self._rex:IsValid() then return self._rex end
  local origin = self._spawnpoint or self.inst:GetPosition()
  local nearest, distance = nil, math.huge
  for _, ent in pairs(Ents) do
    if ent.prefab == "pigking" and ent:IsValid() then
      local point = ent:GetPosition()
      local d = (point.x-origin.x)^2 + (point.z-origin.z)^2
      if d < distance then nearest, distance = ent, d end
    end
  end
  self._rex = nearest
  return nearest
end

function LibellusProgress:GuidePasserToRex()
  local passer, king = self:GetPasser(), self:EnsureRex()
  if passer == nil or not passer:HasTag("libellus_passer_free") or passer._rex_guided or king == nil then return end
  local point, from = king:GetPosition(), passer:GetPosition()
  local dx, dz = from.x-point.x, from.z-point.z
  local length = math.sqrt(dx*dx + dz*dz)
  if length > 0 then dx, dz = dx/length, dz/length else dx, dz = 0, 1 end
  local locomotor = self.inst.components.locomotor
  local speed = locomotor ~= nil and locomotor:GetWalkSpeed() or TUNING.WILSON_WALK_SPEED
  passer._rex_guided = true
  passer:StartFlight(Vector3(point.x + dx*3.5, 0, point.z + dz*3.5), speed, self.inst.userid)
end

function LibellusProgress:GetShip()
  local ship = self._navis ~= nil and self._navis:IsValid() and self._navis._ship or nil
  return ship ~= nil and ship:IsValid() and ship or nil
end

function LibellusProgress:GetSenex()
  local senex = self._navis ~= nil and self._navis:IsValid() and self._navis._senex or nil
  return senex ~= nil and senex:IsValid() and not senex.components.health:IsDead() and senex or nil
end

function LibellusProgress:GetAgricola()
  local farmer = self._farm ~= nil and self._farm:IsValid() and self._farm._agricola or nil
  return farmer ~= nil and farmer:IsValid() and farmer or nil
end

local function IsBusy(inst)
  local talker = inst.components.talker
  return talker == nil or inst.loadingprotection or inst:HasTag("playerghost")
    or (inst.sg ~= nil and inst.sg:HasStateTag("busy")) or talker:IsTalking()
end

function LibellusProgress:IsNearPublius()
  return self._publius ~= nil and self._publius:IsValid()
    and self.inst:IsNear(self._publius, HELPERS.PUBLIUS_MEETING_DISTANCE)
end

function LibellusProgress:IdleState(_, _, _, _)
  return HELPERS.CHECK_PROGRESS_INTERVAL
end

function LibellusProgress:ScheduleDialogLoop(delay)
  if self._dialog_task ~= nil then self._dialog_task:Cancel() end
  self._dialog_task = self.inst:DoTaskInTime(delay, function(inst)
    self._dialog_task = nil
    self:DialogLoop(inst)
  end)
end

function LibellusProgress:DialogLoop(inst)
  if self._dialog_task ~= nil then self._dialog_task:Cancel(); self._dialog_task = nil end
  local publius = not inst.loadingprotection and self:EnsurePublius() or nil
  if not inst.loadingprotection then
    self:EnsureCasa()
    self:EnsureFarm()
    self:EnsureNavis()
    self:EnsureCastle()
    local grove = self:EnsurePasser()
    if grove ~= nil and grove._released then self:OnPasserFreed(grove) end
    if self._casa_cleared and self._casa ~= nil and self._casa:IsValid() then
      self._casa:ClearEncounter()
    end
  end
  if not self._checking_casa_entry then
    self._checking_casa_entry = true
    self:CheckCasaEntry(inst)
  end
  if not self._checking_passer_sight then
    self._checking_passer_sight = true
    self:CheckPasserSight(inst)
  end
  -- Progress points past the last line as soon as it starts. Wait until both
  -- speech bubbles finish before starting the permanent follower relationship.
  if publius ~= nil and (self.chapter ~= "ch1" or self.dialog > DIALOG.CH1_SEP[3])
    and inst.components.talker ~= nil and not inst.components.talker:IsTalking()
    and not publius.components.talker:IsTalking()
  then
    publius.components.follower:SetLeader(inst)
    publius.persists = false
  end

  local chapter, dialog = self:GetProgress()
  if self:UpdateChapterSixScene() then
    self:ScheduleDialogLoop(HELPERS.CHECK_PROGRESS_INTERVAL)
    return
  end
  chapter, dialog = self:GetProgress()
  if chapter == "ch5" then self:PrepareChapterFiveSenex(inst) end
  if chapter == "ch4" and dialog > DIALOG.CH4_SEP[1]
    and (self._passer_to_rex_time == nil or GetTime() >= self._passer_to_rex_time) then
    self:GuidePasserToRex()
  end
  local ship_dialog = (chapter == "ch3" and dialog > DIALOG.CH3_SEP[1]
    and dialog <= DIALOG.CH3_SEP[2]) or (chapter == "ch5"
    and dialog > DIALOG.CH5_SEP[1] and dialog <= DIALOG.CH5_SEP[2])
  if (self._entry_speech_until ~= nil and GetTime() < self._entry_speech_until)
    or (self._flute_speech_until ~= nil and GetTime() < self._flute_speech_until)
    or inst.loadingprotection or inst:HasTag("playerghost") or inst.components.talker == nil
    or (not ship_dialog and chapter ~= "ch6" and (IsBusy(inst) or (publius ~= nil and IsBusy(publius)))) then
    self:ScheduleDialogLoop(HELPERS.BUSY_INTERVAL)
    return
  end

  local revision = self._progress_revision
  local say_func = self.IdleState
  if chapter == "ch1" then
    if dialog <= DIALOG.CH1_SEP[1] then say_func = self.SayChapterOneIntro
    elseif dialog <= DIALOG.CH1_SEP[2] then say_func = self.SayChapterOneIntro2
    elseif dialog <= DIALOG.CH1_SEP[3] then say_func = self.SayChapterOneMeeting end
  elseif chapter == "ch2" then
    if dialog <= DIALOG.CH2_SEP[1] then say_func = self.SayChapterTwoApproach
    elseif dialog == DIALOG.CH2_SEP[3] then say_func = self.SayChapterTwoWait
    elseif dialog <= DIALOG.CH2_SEP[4] and dialog > DIALOG.CH2_SEP[3] then
      say_func = self.SayChapterTwoFarmer
    end
  elseif chapter == "ch3" then
    if dialog <= DIALOG.CH3_SEP[2] then say_func = self.SayChapterThreeShip
    elseif dialog <= DIALOG.CH3_SEP[3] then say_func = self.SayChapterThreeReflection
    elseif dialog <= DIALOG.CH3_SEP[5] then say_func = self.SayChapterThreePasser end
  elseif chapter == "ch4" and dialog <= DIALOG.CH4_SEP[1] then
    say_func = self.SayChapterFourPasser
  elseif chapter == "ch4" and dialog <= DIALOG.CH4_SEP[2] then
    say_func = self.SayChapterFourRex
  elseif chapter == "ch5" then
    if dialog <= DIALOG.CH5_SEP[1] then say_func = self.SayChapterFiveGifts
    elseif dialog <= DIALOG.CH5_SEP[2] then say_func = self.SayChapterFiveSenex end
  elseif chapter == "ch6" and dialog <= DIALOG.CH6_SEP[5] then
    say_func = self.SayChapterSix
  end
  local delay = say_func(self, inst, chapter, dialog, revision)
  self:ScheduleDialogLoop(delay)
end

function LibellusProgress:SetChapterSixPending(line)
  self._ch6_pending = {line = line, untiltime = GetTime()+HELPERS.DIALOG_INTERVAL,
    revision = self._progress_revision}
end

function LibellusProgress:UpdateChapterSixScene()
  local castle = self._castle
  if castle == nil or not castle:IsValid() then return false end
  if self.inst.loadingprotection or self.inst:HasTag("playerghost") then
    castle:EndNight(self.inst)
    return true
  end
  local pending = self._ch6_pending
  if pending ~= nil and pending.revision ~= self._progress_revision then self._ch6_pending = nil; pending = nil end
  if pending ~= nil then
    if GetTime() < pending.untiltime then return true end
    self._ch6_pending = nil
    if pending.line == DIALOG.CH6_SEP[1] and self.chapter == "ch6"
      and self.dialog == DIALOG.CH6_SEP[1] + 1 then
      castle:BeginNight(self.inst)
    elseif pending.line == DIALOG.CH6_SEP[2] then
      castle:EndNight(self.inst)
    elseif pending.line == DIALOG.CH6_SEP[3] and self.chapter == "ch6"
      and self.dialog == DIALOG.CH6_SEP[4] then
      self._ch6_trade_ready = true
    elseif pending.line == DIALOG.CH6_SEP[5] and self.chapter == "ch6"
      and self.dialog == DIALOG.CH6_SEP[5] then
      self:SetProgress("ch6", DIALOG.CH6_SEP[5] + 1)
    end
  end
  if self.chapter == "ch6" and self.dialog > DIALOG.CH6_SEP[1] and self.dialog <= DIALOG.CH6_SEP[2] then
    if not castle:BeginNight(self.inst) then return true end
  elseif self.chapter ~= "ch6" or self.dialog <= DIALOG.CH6_SEP[1] or self.dialog > DIALOG.CH6_SEP[2] then
    castle:EndNight(self.inst)
  end
  return false
end

function LibellusProgress:IsKingTradeReady(castle)
  return self._castle == castle and self.chapter == "ch6" and self.dialog == DIALOG.CH6_SEP[4]
    and self._ch6_trade_ready == true and self._ch6_pending == nil
end

function LibellusProgress:OnKingBellReceived(castle)
  if not self:IsKingTradeReady(castle) then return end
  self:SetProgress("ch6", DIALOG.CH6_SEP[5])
  castle._king.components.talker:Say(DIALOG.ch6[DIALOG.CH6_SEP[4]].content, HELPERS.DIALOG_INTERVAL)
  self:SetChapterSixPending(DIALOG.CH6_SEP[4])
  self:ScheduleDialogLoop(HELPERS.CHECK_PROGRESS_INTERVAL)
end

function LibellusProgress:OnHumanKingDeath(castle)
  if self._castle == castle and self.chapter == "ch6" and self.dialog == DIALOG.CH6_SEP[5] then
    self:ScheduleDialogLoop(HELPERS.CHECK_PROGRESS_INTERVAL)
  end
end

function LibellusProgress:SayChapterSix(inst, chapter, dialog, revision)
  local castle = self._castle
  if castle == nil or not castle:IsValid() then return HELPERS.CHECK_PROGRESS_INTERVAL end
  local king, lupa = castle._king, castle._lupa
  local target = dialog <= DIALOG.CH6_SEP[1] and castle or (dialog <= DIALOG.CH6_SEP[2] and lupa or king)
  if dialog == DIALOG.CH6_SEP[4] then return HELPERS.CHECK_PROGRESS_INTERVAL end -- Gift event only.
  if dialog == DIALOG.CH6_SEP[5] then
    if not castle._betrayed or not castle._king_dead or castle._betrayeruserid ~= inst.userid then
      return HELPERS.CHECK_PROGRESS_INTERVAL
    end
  elseif dialog == 1 or dialog == DIALOG.CH6_SEP[1] + 1 or dialog == DIALOG.CH6_SEP[2] + 1 then
    if target == nil or not target:IsValid()
      or not inst:IsNear(target, dialog == 1 and HELPERS.CASTLE_SEE_DISTANCE or HELPERS.KING_SEE_DISTANCE)
      or not CanEntitySeeTarget(inst, target) then return HELPERS.CHECK_PROGRESS_INTERVAL end
  end
  local line = DIALOG.ch6[dialog]
  local actors = {Octavia = inst, Publius = self._publius, Lupa = lupa, Rex = king}
  local speaker = actors[line.name]
  if speaker == nil or not speaker:IsValid() or speaker.components.talker == nil
    or speaker.components.talker:IsTalking() then return HELPERS.BUSY_INTERVAL end
  if target ~= nil and target:IsValid() and speaker ~= target then
    speaker:FacePoint(target.Transform:GetWorldPosition())
  end
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d == DIALOG.CH6_SEP[5] and d or d+1 end,
    function()
      if dialog == DIALOG.CH6_SEP[1] or dialog == DIALOG.CH6_SEP[2]
        or dialog == DIALOG.CH6_SEP[3] or dialog == DIALOG.CH6_SEP[5] then self:SetChapterSixPending(dialog) end
      return HELPERS.DIALOG_INTERVAL
    end)
end

function LibellusProgress:Say(
  inst, chapter, dialog, revision, content, update_func, delay_func
)
  local talker = inst.components.talker
  talker:Say(content, HELPERS.DIALOG_INTERVAL)
  if not talker:IsTalking() then
    return HELPERS.BUSY_INTERVAL
  end

  -- A speech event may have advanced the story into a different state.
  local currentchapter, currentdialog = self:GetProgress()
  if currentchapter ~= chapter or currentdialog ~= dialog then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end

  local next_chapter, next_dialog = update_func(dialog)
  -- Say may synchronously invoke an event handler, including one that changes
  -- progress away and back to the same values. Its newer update takes priority.
  if not self:SetProgress(next_chapter, next_dialog, revision) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  return delay_func(next_chapter, next_dialog)
end

function LibellusProgress:SayChapterOneIntro(inst, chapter, dialog, revision)
  return self:Say(
    inst, chapter, dialog, revision,
    DIALOG.ch1[dialog].content,
    function(d) return chapter, d+1 end,
    function(_,_) return HELPERS.DIALOG_INTERVAL end
  )
end

function LibellusProgress:SayChapterOneIntro2(inst, chapter, dialog, revision)
  if self:IsNearPublius() then
    self:SetProgress(chapter, DIALOG.CH1_SEP[2]+1)
    return self:SayChapterOneMeeting(inst, chapter, dialog+1, self._progress_revision)
  end

  if self._next_intro2_time ~= nil and GetTime() < self._next_intro2_time then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  return self:Say(
    inst, chapter, dialog, revision,
    DIALOG.ch1[dialog].content,
    function(d) return chapter, d end,
    function(_,_)
      self._next_intro2_time = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.REPEAT_INTERVAL
      return HELPERS.CHECK_PROGRESS_INTERVAL
    end
  )
end

function LibellusProgress:SayChapterOneMeeting(inst, chapter, dialog, revision)
  if not self:IsNearPublius() then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end

  local line = DIALOG[chapter][dialog]
  local actors = {Octavia = inst, Publius = self._publius}
  local speaker = actors[line.name]
  if speaker == nil or IsBusy(speaker) then
    return HELPERS.BUSY_INTERVAL
  end

  inst:FacePoint(self._publius.Transform:GetWorldPosition())
  self._publius:FacePoint(inst.Transform:GetWorldPosition())
  return self:Say(
    speaker, chapter, dialog, revision, line.content,
    function(d)
      if d < DIALOG.CH1_SEP[3] then
        return chapter, d+1
      else
        return "ch2", 1
      end
    end,
    function(_,_) return HELPERS.DIALOG_INTERVAL end
  )
end

function LibellusProgress:SayChapterTwoLine(inst, chapter, dialog, revision)
  local line = DIALOG[chapter][dialog]
  local actors = {Octavia = inst, Publius = self._publius}
  local speaker = actors[line.name]
  if speaker == nil or not speaker:IsValid() or speaker.components.talker == nil
    or IsBusy(speaker) then
    return HELPERS.BUSY_INTERVAL
  end
  local facing = actors[line.facing]
  if facing ~= nil and facing:IsValid() then
    speaker:FacePoint(facing.Transform:GetWorldPosition())
  end
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d)
      return chapter, d+1
    end,
    function() return HELPERS.DIALOG_INTERVAL end)
end

function LibellusProgress:SayChapterTwoApproach(inst, chapter, dialog, revision)
  local casa = self._casa
  if casa == nil or not casa:IsValid()
    or (dialog == 1 and not inst:IsNear(casa, HELPERS.CASA_NEAR_DISTANCE)) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  return self:SayChapterTwoLine(inst, chapter, dialog, revision)
end

-- Entry detection runs independently of speech timing and story progress.
function LibellusProgress:CheckCasaEntry(inst)
  local casa = self._casa
  local inside = casa ~= nil and casa:IsValid() and casa:Contains(inst)
    and not inst.loadingprotection and not inst:HasTag("playerghost")
  if inside and not self._inside_casa and not casa._encounter_cleared then
    self:SayChapterTwoEntry(inst)
  end
  self._inside_casa = inside
  inst:DoTaskInTime(HELPERS.CASA_CHECK_INTERVAL, function(inst)
    self:CheckCasaEntry(inst)
  end)
end

function LibellusProgress:SayChapterTwoEntry(inst)
  for _, soldier in ipairs(self._casa._soldiers) do
    if soldier:IsValid() and not soldier.components.health:IsDead()
      and soldier.components.talker ~= nil then
      local line = DIALOG.ch2[math.random(DIALOG.CH2_SEP[1] + 1, DIALOG.CH2_SEP[2] - 1)]
      soldier:FacePoint(inst.Transform:GetWorldPosition())
      soldier.components.talker:Say(line.content, HELPERS.DIALOG_INTERVAL)
    end
  end
  local talker = inst.components.talker
  if talker == nil then return end
  if self._publius ~= nil and self._publius:IsValid() then
    inst:FacePoint(self._publius.Transform:GetWorldPosition())
  end
  talker:Say(DIALOG.ch2[DIALOG.CH2_SEP[2]].content, HELPERS.DIALOG_INTERVAL)
  if not talker:IsTalking() then return end
  self._entry_speech_until = GetTime() + HELPERS.DIALOG_INTERVAL
  local speech_end = self._entry_speech_until
  inst:DoTaskInTime(HELPERS.DIALOG_INTERVAL, function()
    -- Reentry can restart line five. Only the latest speech may advance,
    -- and its completion must never rewind a later story event.
    if self._entry_speech_until ~= speech_end then return end
    local chapter, dialog = self:GetProgress()
    if chapter == "ch2" and dialog > DIALOG.CH2_SEP[1]
      and dialog <= DIALOG.CH2_SEP[2] then
      self:SetProgress("ch2", DIALOG.CH2_SEP[3])
    end
  end)
end

function LibellusProgress:SayChapterTwoWait(inst, chapter, dialog, revision)
  local farmer = self:GetAgricola()
  if farmer ~= nil and inst:IsNear(farmer, HELPERS.AGRICOLA_MEETING_DISTANCE) then
    self:SetProgress(chapter, DIALOG.CH2_SEP[3] + 1)
    return self:SayChapterTwoFarmer(inst, chapter, DIALOG.CH2_SEP[3] + 1, self._progress_revision)
  end
  if self._next_ch2_repeat_time ~= nil and GetTime() < self._next_ch2_repeat_time then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  local publius = self._publius
  if publius == nil or not publius:IsValid() or IsBusy(publius) then
    return HELPERS.BUSY_INTERVAL
  end
  publius:FacePoint(inst.Transform:GetWorldPosition())
  return self:Say(publius, chapter, dialog, revision, DIALOG.ch2[dialog].content,
    function(d) return chapter, d end,
    function()
      self._next_ch2_repeat_time = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.REPEAT_INTERVAL
      return HELPERS.CHECK_PROGRESS_INTERVAL
    end)
end

function LibellusProgress:SayChapterTwoFarmer(inst, chapter, dialog, revision)
  local farmer = self:GetAgricola()
  if farmer == nil or not inst:IsNear(farmer, HELPERS.AGRICOLA_MEETING_DISTANCE) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  farmer._conversation_until = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.BUSY_INTERVAL
  if self._farmer_finish_revision == revision then return HELPERS.CHECK_PROGRESS_INTERVAL end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Agricola" and farmer or inst
  if IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  inst:FacePoint(farmer.Transform:GetWorldPosition())
  farmer:FacePoint(inst.Transform:GetWorldPosition())
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d < DIALOG.CH2_SEP[4] and d + 1 or d end,
    function()
      if dialog == DIALOG.CH2_SEP[4] then
        local finish_revision = self._progress_revision
        self._farmer_finish_revision = finish_revision
        inst:DoTaskInTime(HELPERS.DIALOG_INTERVAL, function()
          if self:SetProgress("ch3", 1, finish_revision) then
            self._casa_cleared = true
            if self._casa ~= nil and self._casa:IsValid() then self._casa:ClearEncounter() end
          end
        end)
      end
      return HELPERS.DIALOG_INTERVAL
    end)
end

function LibellusProgress:SayChapterThreeShip(inst, chapter, dialog, revision)
  local ship = self:GetShip()
  local first = dialog == DIALOG.CH3_SEP[1]
  if ship == nil or not inst:IsNear(ship, first and HELPERS.NAVIS_SEE_DISTANCE or HELPERS.NAVIS_NEAR_DISTANCE)
    or (first and not CanEntitySeeTarget(inst, ship)) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  local actors = {Octavia = inst, Publius = self._publius, Senex = self:GetSenex()}
  local line = DIALOG[chapter][dialog]
  local speaker = actors[line.name]
  -- Boarding combat continues during the exchange; speech bubbles still wait
  -- for their own speaker's preceding line to finish.
  if speaker == nil or not speaker:IsValid() or speaker.components.talker == nil
    or speaker.components.talker:IsTalking() then
    return HELPERS.BUSY_INTERVAL
  end
  local facing = actors[line.facing]
  if facing ~= nil and facing:IsValid() then
    speaker:FacePoint(facing.Transform:GetWorldPosition())
  end
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d + 1 end,
    function()
      local delay = HELPERS.DIALOG_INTERVAL
      if dialog == DIALOG.CH3_SEP[2] then
        delay = delay + HELPERS.PASSER_REFLECTION_DELAY
        self._ch3_reflection_time = GetTime() + delay
      end
      return delay
    end)
end

function LibellusProgress:SayChapterThreeReflection(inst, chapter, dialog, revision)
  if dialog == DIALOG.CH3_SEP[2] + 1 then
    self._ch3_reflection_time = self._ch3_reflection_time or GetTime() + HELPERS.PASSER_REFLECTION_DELAY
    if GetTime() < self._ch3_reflection_time then
      return math.min(HELPERS.CHECK_PROGRESS_INTERVAL, self._ch3_reflection_time - GetTime())
    end
  end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Publius" and self._publius or inst
  if speaker == nil or not speaker:IsValid() or IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d + 1 end,
    function() return HELPERS.DIALOG_INTERVAL end)
end

function LibellusProgress:SayChapterThreePasser(inst, chapter, dialog, revision)
  local passer = self:GetPasser()
  if passer == nil or not inst:IsNear(passer, HELPERS.PASSER_MEETING_DISTANCE) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  passer._conversation_until = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.BUSY_INTERVAL
  if self._passer_finish_revision == revision then return HELPERS.CHECK_PROGRESS_INTERVAL end
  if IsBusy(passer) then return HELPERS.BUSY_INTERVAL end
  if dialog == DIALOG.CH3_SEP[4] then
    if not self:SetProgress(chapter, dialog + 1, revision) then return HELPERS.CHECK_PROGRESS_INTERVAL end
    dialog, revision = dialog + 1, self._progress_revision
  end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Passer" and passer or inst
  if IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  inst:FacePoint(passer.Transform:GetWorldPosition())
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d < DIALOG.CH3_SEP[5] and d + 1 or d end,
    function()
      if dialog == DIALOG.CH3_SEP[5] then
        local finish_revision = self._progress_revision
        self._passer_finish_revision = finish_revision
        inst:DoTaskInTime(HELPERS.DIALOG_INTERVAL, function()
          self:SetProgress("ch4", 1, finish_revision)
        end)
      end
      return HELPERS.DIALOG_INTERVAL
    end)
end

function LibellusProgress:SayChapterFourPasser(inst, chapter, dialog, revision)
  local passer = self:GetPasser()
  if passer == nil or not passer:HasTag("libellus_passer_free") or not passer._arrived then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Passer" and passer or inst
  if IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  passer._conversation_until = GetTime() + HELPERS.DIALOG_INTERVAL + HELPERS.BUSY_INTERVAL
  passer:FacePoint(inst.Transform:GetWorldPosition())
  inst:FacePoint(passer.Transform:GetWorldPosition())
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d + 1 end,
    function()
      if dialog == DIALOG.CH4_SEP[1] then self._passer_to_rex_time = GetTime() + HELPERS.DIALOG_INTERVAL end
      return HELPERS.DIALOG_INTERVAL
    end)
end

function LibellusProgress:FinishChapterFourRex(revision)
  if revision ~= self._progress_revision then return end
  local king = self:EnsureRex()
  if king == nil then self._rex_finish_revision = nil; return end
  if not self._rex_panflute_received then
    self._rex_panflute_received = king:GiveLibellusGift("panflute", self.inst)
  end
  if not self._rex_bell_received then
    self._rex_bell_received = king:GiveLibellusGift("bell", self.inst)
  end
  if self._rex_panflute_received and self._rex_bell_received then
    if king.sg ~= nil and king.sg:HasStateTag("idle") then king.sg:GoToState("cointoss") end
    if self:SetProgress("ch5", 1, revision) then self:DialogLoop(self.inst) end
  else
    self.inst:DoTaskInTime(HELPERS.CHECK_PROGRESS_INTERVAL, function() self:FinishChapterFourRex(revision) end)
  end
end

function LibellusProgress:SayChapterFourRex(inst, chapter, dialog, revision)
  local king = self:EnsureRex()
  if king == nil or not inst:IsNear(king, HELPERS.REX_MEETING_DISTANCE)
    or (king.IsMinigameActive ~= nil and king:IsMinigameActive())
    or (king.sg ~= nil and king.sg.mem ~= nil and king.sg.mem.sleeping)
    or (self._passer_to_rex_time ~= nil and GetTime() < self._passer_to_rex_time) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  if self._rex_finish_revision == revision then return HELPERS.CHECK_PROGRESS_INTERVAL end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Rex animalium" and king._libellus_rex_voice or inst
  if speaker == nil or not speaker:IsValid() or IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  inst:FacePoint(king.Transform:GetWorldPosition())
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d < DIALOG.CH4_SEP[2] and d + 1 or d end,
    function()
      if dialog == DIALOG.CH4_SEP[2] then
        self._rex_finish_revision = self._progress_revision
        local finish_revision = self._progress_revision
        inst:DoTaskInTime(HELPERS.DIALOG_INTERVAL, function() self:FinishChapterFourRex(finish_revision) end)
      end
      return HELPERS.DIALOG_INTERVAL
    end)
end

function LibellusProgress:PrepareChapterFiveSenex(inst)
  local senex = self:GetSenex()
  if senex == nil then return end
  senex:PrepareStorySleep()
  if not inst.loadingprotection and not inst:HasTag("playerghost")
    and inst:IsNear(senex, HELPERS.SENEX_MEETING_DISTANCE)
    and CanEntitySeeTarget(inst, senex) then
    senex:WakeForStory()
  end
end

function LibellusProgress:SayChapterFiveGifts(inst, chapter, dialog, revision)
  local king = self:EnsureRex()
  local actors = {Octavia = inst, Publius = self._publius,
    ["Rex animalium"] = king ~= nil and king._libellus_rex_voice or nil}
  local line = DIALOG[chapter][dialog]
  local speaker = actors[line.name]
  if speaker == nil or not speaker:IsValid() or IsBusy(speaker) then return HELPERS.BUSY_INTERVAL end
  local facing = actors[line.facing]
  if facing ~= nil and facing:IsValid() then speaker:FacePoint(facing.Transform:GetWorldPosition()) end
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d + 1 end,
    function() return HELPERS.DIALOG_INTERVAL end)
end

function LibellusProgress:SayChapterFiveSenex(inst, chapter, dialog, revision)
  local senex = self:GetSenex()
  if senex == nil or not inst:IsNear(senex, HELPERS.SENEX_MEETING_DISTANCE)
    or not CanEntitySeeTarget(inst, senex) or senex.components.sleeper:IsAsleep()
    or senex.sg:HasStateTag("waking") then return HELPERS.CHECK_PROGRESS_INTERVAL end
  local line = DIALOG[chapter][dialog]
  local speaker = line.name == "Senex" and senex or inst
  if speaker.components.talker == nil or speaker.components.talker:IsTalking() then return HELPERS.BUSY_INTERVAL end
  speaker:FacePoint((speaker == inst and senex or inst).Transform:GetWorldPosition())
  return self:Say(speaker, chapter, dialog, revision, line.content,
    function(d) return chapter, d + 1 end,
    function() return HELPERS.DIALOG_INTERVAL end)
end

-- The native instrument invokes this only when a play action takes effect.
-- Line seventeen is repeatable and does not rewind an ongoing conversation.
function LibellusProgress:OnPanFlutePlayed()
  local inst = self.inst
  if not inst.loadingprotection and not inst:HasTag("playerghost") and inst.components.talker ~= nil then
    inst.components.talker:Say(DIALOG.ch5[DIALOG.CH5_SEP[3]].content, HELPERS.DIALOG_INTERVAL)
    if inst.components.talker:IsTalking() then self._flute_speech_until = GetTime() + HELPERS.DIALOG_INTERVAL end
  end
end

return LibellusProgress
