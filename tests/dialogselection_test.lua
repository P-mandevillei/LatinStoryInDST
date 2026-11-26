-- Run from the mod directory: lua tests/dialogselection_test.lua
package.path = "./scripts/?.lua;" .. package.path

function Class(base, ctor)
  if ctor == nil then ctor, base = base, nil end
  local class = {_ctor = ctor, _base = base}
  class.__index = class
  return setmetatable(class, {__index = base, __call = function(_, ...)
    local obj = setmetatable({}, class)
    ctor(obj, ...)
    return obj
  end})
end

local DIALOG = require("libellus")
local Selection = require("dialogselection")
local Progress = require("components/libellusprogress")
local count = 0
local function equal(a, b)
  assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function test(name, fn)
  fn()
  count = count + 1
  print("PASS " .. name)
end

local function NetVar(initial)
  return {set = function(self, value) self.data = value end,
    value = function(self) return self.data end, data = initial}
end
local function Player()
  local player = {GUID = 1, components = {}, IsValid = function() return true end}
  player.components.libellusprogress = Progress(player)
  return player, player.components.libellusprogress
end

local function Widget()
  local w = {children = {}, focus = {}, inst = {tasks = {}}}
  function w:AddChild(child) table.insert(self.children, child); return child end
  function w:SetPosition(x, y) self.x, self.y = x, y end
  function w:SetString(text) self.string = text end
  function w:SetRegionSize() end
  function w:EnableWordWrap() end
  function w:SetFocusChangeDir(direction, target) self.focus[direction] = target end
  function w:SetScale(value) self.scale = value end
  function w.inst:DoPeriodicTask(period, fn) table.insert(self.tasks, fn) end
  return w
end
CHATFONT = "chatfont"
MOVE_UP, MOVE_DOWN = "up", "down"
package.loaded["widgets/text"] = function() return Widget() end
package.loaded["widgets/redux/templates"] = {
  LabelSpinner = function(label, options)
    local w, spinner = Widget(), Widget()
    w.spinner = spinner
    spinner.options, spinner.index = options, 1
    function spinner:GetSelectedData() return self.options[self.index].data end
    function spinner:SetOptions(values)
      self.options = values
      self.index = math.min(self.index, #values)
    end
    function spinner:SetSelectedIndex(index) self.index = math.max(1, math.min(index, #self.options)) end
    function spinner:SetOnChangedFn(fn) self.onchanged = fn end
    function spinner:SetSelected(data)
      for i, option in ipairs(self.options) do
        if option.data == data then
          local changed = self.index ~= i
          self.index = i
          if changed and self.onchanged then self.onchanged(data) end
          return
        end
      end
    end
    return w
  end
}
local popped, pushed
TheFrontEnd = {
  PopScreen = function(_, screen) popped = screen end,
  PushScreen = function(_, screen) pushed = screen end
}
local Popup = Class(function(self, title, body, buttons)
  local widget = Widget()
  self.inst = widget.inst
  self.dialog = Widget()
  self.dialog.actions = Widget()
  self.buttons = buttons
end)
function Popup:Close() TheFrontEnd:PopScreen(self) end
package.loaded["screens/redux/popupdialog"] = Popup
local Screen = require("screens/dialogselectorscreen")

local function Integration(enabled, dedicated, mastersim)
  local result = {playerhooks = {}, screenhooks = {}, sent = {}}
  GLOBAL = {
    TheWorld = {ismastersim = mastersim ~= false},
    TheNet = {IsDedicated = function() return dedicated end},
    net_string = function() return NetVar("") end,
    net_ushortint = function() return NetVar(0) end,
    TheFrontEnd = TheFrontEnd,
    SendModRPCToServer = function(rpc, chapter, line)
      table.insert(result.sent, {rpc = rpc, chapter = chapter, line = line})
    end
  }
  modname = "latinPresentation"
  function GetModConfigData(name) equal(name, "dialog_selector"); return enabled end
  function AddModRPCHandler(namespace, name, fn)
    equal(namespace, modname)
    equal(name, "SetDialogProgress")
    result.rpc = fn
  end
  function GetModRPC(namespace, name) return namespace .. ":" .. name end
  function AddPlayerPostInit(fn) table.insert(result.playerhooks, fn) end
  function AddClassPostConstruct(path, fn)
    equal(path, "screens/redux/pausescreen")
    table.insert(result.screenhooks, fn)
  end
  dofile("scripts/dialogselector.lua")
  return result
end

test("chapter and line choices come from actual dialogue and exclude metadata", function()
  local chapters = Selection.GetChapterOptions()
  equal(#chapters, 4)
  equal(chapters[1].data, "ch1")
  equal(chapters[2].data, "ch2")
  equal(chapters[3].data, "ch3")
  equal(chapters[4].data, "ch4")
  for _, chapter in ipairs(chapters) do
    local lines = Selection.GetLineOptions(chapter.data)
    equal(#lines, #DIALOG[chapter.data])
    for i, option in ipairs(lines) do equal(option.data, i) end
  end
  equal(#Selection.GetLineOptions("CH1_SEP"), 0)
end)

test("selection sets only progress and respects later revision checks", function()
  local player, progress = Player()
  local publius, casa = {}, {}
  progress._publius, progress._casa = publius, casa
  local revision = progress._progress_revision
  equal(Selection.Apply(player, "ch2", 12), true)
  equal(progress.chapter, "ch2")
  equal(progress.dialog, 12)
  equal(progress._publius, publius)
  equal(progress._casa, casa)
  equal(progress:SetProgress("ch1", 2, revision), false)
  equal(progress.dialog, 12)
end)

test("invalid chapters and line numbers cannot change progress", function()
  local player, progress = Player()
  local invalid = {{"CH1_SEP", 1}, {"ch99", 1}, {nil, 1}, {1, 1}, {"ch1", 0},
    {"ch1", -1}, {"ch1", 11}, {"ch1", 1.5}, {"ch1", "2"}, {"ch1", nil},
    {"ch1", math.huge}, {"ch1", 0/0}, {"ch1", {}}}
  for _, request in ipairs(invalid) do
    equal(Selection.Apply(player, request[1], request[2]), false)
    equal(progress.chapter, "ch1")
    equal(progress.dialog, 1)
  end
  equal(Selection.Apply(nil, "ch1", 1), false)
  equal(Selection.Apply({IsValid = function() return false end}, "ch1", 1), false)
  equal(Selection.Apply({components = {}, IsValid = function() return true end}, "ch1", 1), false)
end)

test("disabled option registers no UI or network fields and ignores requests", function()
  local api = Integration(false, false)
  equal(#api.playerhooks, 0)
  equal(#api.screenhooks, 0)
  local player, progress = Player()
  api.rpc(player, "ch2", 8)
  equal(progress.chapter, "ch1")
end)

test("dedicated server creates synchronized progress without UI", function()
  local api = Integration(true, true)
  equal(#api.playerhooks, 1)
  equal(#api.screenhooks, 0)
  local player, progress = Player()
  api.playerhooks[1](player)
  equal(player._libellus_chapter:value(), "ch1")
  api.rpc(player, "ch2", 9)
  equal(player._libellus_chapter:value(), "ch2")
  equal(player._libellus_dialog:value(), 9)
  progress:SetProgress("ch2", 10)
  equal(player._libellus_dialog:value(), 10)
  local saved = progress:OnSave()
  local restored, restoredprogress = Player()
  api.playerhooks[1](restored)
  restoredprogress:OnLoad(saved)
  equal(restored._libellus_chapter:value(), "ch2")
  equal(restored._libellus_dialog:value(), 10)
end)

test("clients create matching network fields without the server component", function()
  local api = Integration(true, false, false)
  local player = {GUID = 1, components = {}}
  api.playerhooks[1](player)
  equal(player.components.libellusprogress, nil)
  equal(player._libellus_chapter:value(), "")
  equal(player._libellus_dialog:value(), 0)
end)

test("screen displays and selects current progress, with matching line choices", function()
  local api = Integration(true, false)
  local player, progress = Player()
  api.playerhooks[1](player)
  progress:SetProgress("ch2", 12)
  local screen = Screen(player, function() error("must not apply while choosing") end)
  equal(screen.current.string, "Current: Chapter 2, line 12")
  equal(screen.chapter.spinner:GetSelectedData(), "ch2")
  equal(screen.line.spinner:GetSelectedData(), 12)
  equal(screen.preview.string, DIALOG.ch2[12].name .. ": " .. DIALOG.ch2[12].content)
  screen.chapter.spinner:SetSelected("ch1")
  equal(#screen.line.spinner.options, 10)
  equal(screen.line.spinner:GetSelectedData(), 1)
  equal(progress.dialog, 12)
  equal(screen.chapter.spinner.focus[MOVE_DOWN], screen.line.spinner)
  equal(screen.line.spinner.focus[MOVE_DOWN], screen.dialog.actions)
end)

test("live current-position updates do not overwrite an edited selection", function()
  local api = Integration(true, false)
  local player, progress = Player()
  api.playerhooks[1](player)
  local screen = Screen(player, function() end)
  screen.line.spinner:SetSelected(4)
  progress:SetProgress("ch2", 5)
  screen.inst.tasks[1]()
  equal(screen.current.string, "Current: Chapter 2, line 5")
  equal(screen.chapter.spinner:GetSelectedData(), "ch1")
  equal(screen.line.spinner:GetSelectedData(), 4)
end)

test("a delayed network snapshot initializes once without losing user edits", function()
  local api = Integration(true, false, false)
  local player = {GUID = 1, components = {}}
  api.playerhooks[1](player)
  local screen = Screen(player, function() end)
  equal(screen.current.string, "Current: loading...")
  screen.line.spinner:SetSelected(7)
  player._libellus_chapter:set("ch2")
  player._libellus_dialog:set(9)
  screen.inst.tasks[1]()
  equal(screen.current.string, "Current: Chapter 2, line 9")
  equal(screen.chapter.spinner:GetSelectedData(), "ch1")
  equal(screen.line.spinner:GetSelectedData(), 7)
end)

test("a completed chapter shows its actual position and offers valid lines", function()
  local api = Integration(true, false)
  local player, progress = Player()
  api.playerhooks[1](player)
  progress:SetProgress("ch1", 11)
  local screen = Screen(player, function() end)
  equal(screen.current.string, "Current: Chapter 1, line 11")
  equal(screen.line.spinner:GetSelectedData(), 10)
end)

test("pause menu rebuilds once per button and Apply sends only the selected numbers", function()
  local api = Integration(true, false)
  local player, progress = Player()
  api.playerhooks[1](player)
  local pause = {owner = player}
  function pause:BuildMenu()
    self.menu = Widget()
    self.menu.offset, self.menu.items = -50, {Widget(), Widget(), Widget()}
    function self.menu:AddItem(label, cb)
      local button = Widget()
      button.label, button.cb = label, cb
      table.insert(self.items, button)
      return button
    end
    self.bg = {width = 190, height = 180}
    function self.bg:GetSize() return self.width, self.height end
    function self.bg:SetSize(w, h) self.width, self.height = w, h end
  end
  function pause:unpause() self.resumed = true end
  pause:BuildMenu()
  api.screenhooks[1](pause)
  equal(#pause.menu.items, 4)
  equal(pause.bg.height, 230)
  pause:BuildMenu()
  equal(#pause.menu.items, 4)
  equal(pause.bg.height, 230)
  pause.menu.items[4].cb()
  local screen = pushed
  screen.chapter.spinner:SetSelected("ch2")
  screen.line.spinner:SetSelected(7)
  screen.buttons[2].cb()
  equal(#api.sent, 0)
  equal(progress.dialog, 1)
  equal(popped, screen)
  pause.menu.items[4].cb()
  screen = pushed
  screen.chapter.spinner:SetSelected("ch2")
  screen.line.spinner:SetSelected(8)
  screen.buttons[1].cb()
  equal(#api.sent, 1)
  equal(api.sent[1].rpc, "latinPresentation:SetDialogProgress")
  equal(api.sent[1].chapter, "ch2")
  equal(api.sent[1].line, 8)
  equal(popped, screen)
  equal(pause.resumed, true)
  api.rpc(player, api.sent[1].chapter, api.sent[1].line)
  equal(progress.chapter, "ch2")
  equal(progress.dialog, 8)
end)

print(count .. " dialogue selection tests passed")
