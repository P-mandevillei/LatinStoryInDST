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
-- Not passing in expected_revision makes a hard update
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
  return {chapter = self.chapter, dialog = self.dialog}
end

function LibellusProgress:OnLoad(data)
  if data ~= nil then
    self:SetProgress(data.chapter, data.dialog)
  end
end

function LibellusProgress:IdleState(_, _, _, _)
  return HELPERS.CHECK_PROGRESS_INTERVAL
end

function LibellusProgress:DialogLoop(inst)
  local talker = inst.components.talker
  if talker == nil then
    return
  end
  if inst.loadingprotection or (inst.sg ~= nil and inst.sg:HasStateTag("busy")) or talker:IsTalking() then
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
    elseif dialog <= DIALOG.CH1_SEP[2] then say_func = self.SayChapterOneIntro2 end
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

  local nextdialog = update_func(dialog)
  -- Say may synchronously invoke an event handler, including one that changes
  -- progress away and back to the same values. Its newer update takes priority.
  if not self:SetProgress(chapter, nextdialog, revision) then
    return HELPERS.CHECK_PROGRESS_INTERVAL
  end
  return delay_func(nextdialog)
end

function LibellusProgress:SayChapterOneIntro(inst, chapter, dialog, revision)
  return self:Say(
    inst, chapter, dialog, revision,
    DIALOG.ch1[dialog].content,
    function(d) return d+1 end,
    function(_) return HELPERS.DIALOG_INTERVAL end
  )
end

function LibellusProgress:SayChapterOneIntro2(inst, chapter, dialog, revision)
  return self:Say(
    inst, chapter, dialog, revision,
    DIALOG.ch1[dialog].content,
    function(d) return d end,
    function(_) return HELPERS.DIALOG_INTERVAL + HELPERS.REPEAT_INTERVAL end
  )
end

return LibellusProgress
