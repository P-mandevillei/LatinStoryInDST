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
  self._progress_revision = self._progress_revision + 1
  return true
end

function LibellusProgress:OnSave()
  local point = self._spawnpoint
  local data = {
    chapter = self.chapter,
    dialog = self.dialog,
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

function LibellusProgress:DialogLoop(inst)
  local publius = not inst.loadingprotection and self:EnsurePublius() or nil
  -- Progress points past the last line as soon as it starts. Wait until both
  -- speech bubbles finish before starting the permanent follower relationship.
  if publius ~= nil and (self.chapter ~= "ch1" or self.dialog > DIALOG.CH1_SEP[3])
    and inst.components.talker ~= nil and not inst.components.talker:IsTalking()
    and not publius.components.talker:IsTalking()
  then
    publius.components.follower:SetLeader(inst)
    publius.persists = false
  end

  if IsBusy(inst) or (publius ~= nil and IsBusy(publius)) then
    inst:DoTaskInTime(HELPERS.BUSY_INTERVAL, function(inst)
      self:DialogLoop(inst)
    end)
    return
  end

  local chapter, dialog = self:GetProgress()
  local revision = self._progress_revision
  local say_func = self.IdleState
  if chapter == "ch1" then
    if dialog <= DIALOG.CH1_SEP[1] then say_func = self.SayChapterOneIntro
    elseif dialog <= DIALOG.CH1_SEP[2] then say_func = self.SayChapterOneIntro2
    elseif dialog <= DIALOG.CH1_SEP[3] then say_func = self.SayChapterOneMeeting end
  end
  local delay = say_func(self, inst, chapter, dialog, revision)
  inst:DoTaskInTime(delay, function(inst)
    self:DialogLoop(inst)
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

return LibellusProgress
