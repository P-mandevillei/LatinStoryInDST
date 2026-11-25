local PopupDialogScreen = require("screens/redux/popupdialog")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local DIALOG = require("libellus")
local Selection = require("dialogselection")

local DialogSelectorScreen = Class(PopupDialogScreen, function(self, owner, onapply)
  PopupDialogScreen._ctor(self, "Dialogue progress", nil, {
    {text = "Apply", cb = function() self:Apply() end},
    {text = "Cancel", cb = function() self:Close() end}
  }, nil, "bigger")
  self.owner = owner
  self.onapply = onapply

  self.current = self.dialog:AddChild(Text(CHATFONT, 25))
  self.current:SetPosition(0, 115)
  self.current:SetString("Current: loading...")

  self.chapter = self.dialog:AddChild(TEMPLATES.LabelSpinner(
    "Chapter", Selection.GetChapterOptions(), 150, 240))
  self.chapter:SetPosition(0, 65)
  local chapter = self.chapter.spinner:GetSelectedData()
  self.line = self.dialog:AddChild(TEMPLATES.LabelSpinner(
    "Line", Selection.GetLineOptions(chapter), 150, 240))
  self.line:SetPosition(0, 15)

  self.preview = self.dialog:AddChild(Text(CHATFONT, 24))
  self.preview:SetPosition(0, -45)
  self.preview:SetRegionSize(520, 55)
  self.preview:EnableWordWrap(true)

  self.chapter.spinner:SetOnChangedFn(function(selected)
    self._selection_changed = true
    self.line.spinner:SetOptions(Selection.GetLineOptions(selected))
    self.line.spinner:SetSelectedIndex(1)
    self:UpdatePreview()
  end)
  self.line.spinner:SetOnChangedFn(function()
    self._selection_changed = true
    self:UpdatePreview()
  end)

  self.chapter.spinner:SetFocusChangeDir(MOVE_DOWN, self.line.spinner)
  self.line.spinner:SetFocusChangeDir(MOVE_UP, self.chapter.spinner)
  self.line.spinner:SetFocusChangeDir(MOVE_DOWN, self.dialog.actions)
  self.dialog.actions:SetFocusChangeDir(MOVE_UP, self.line.spinner)
  self.default_focus = self.chapter.spinner

  self:UpdateCurrent()
  self:UpdatePreview()
  -- Poll the replicated values so this also updates on a listen server, where
  -- changing a network field need not generate a client dirty event.
  self.inst:DoPeriodicTask(.25, function() self:UpdateCurrent() end)
end)

function DialogSelectorScreen:UpdateCurrent()
  local chapter, line = Selection.GetCurrent(self.owner)
  if chapter == nil or chapter == "" or line == 0 then return end
  self.current:SetString("Current: Chapter " .. chapter:sub(3) .. ", line " .. line)
  if not self._initialized_selection then
    self._initialized_selection = true
    -- A late network update must not overwrite a choice already being edited.
    if not self._selection_changed and DIALOG[chapter] ~= nil then
      self.chapter.spinner:SetSelected(chapter)
      self.line.spinner:SetSelectedIndex(math.min(line, #DIALOG[chapter]))
      self:UpdatePreview()
      self._selection_changed = false
    end
  end
end

function DialogSelectorScreen:UpdatePreview()
  local chapter = self.chapter.spinner:GetSelectedData()
  local line = DIALOG[chapter][self.line.spinner:GetSelectedData()]
  self.preview:SetString(line.name .. ": " .. line.content)
end

function DialogSelectorScreen:Apply()
  local chapter = self.chapter.spinner:GetSelectedData()
  local line = self.line.spinner:GetSelectedData()
  self:Close()
  self.onapply(chapter, line)
end

return DialogSelectorScreen
