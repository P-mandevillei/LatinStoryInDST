-- Imported into the mod environment by modmain.lua.
local G = GLOBAL
local Selection = require("dialogselection")
local enabled = GetModConfigData("dialog_selector") == true

AddModRPCHandler(modname, "SetDialogProgress", function(player, chapter, line)
  if enabled then Selection.Apply(player, chapter, line) end
end)

if not enabled then return end

AddPlayerPostInit(function(inst)
  -- Create the same network fields on clients and the server.
  inst._libellus_chapter = G.net_string(inst.GUID, "libellus.chapter")
  inst._libellus_dialog = G.net_ushortint(inst.GUID, "libellus.dialog")
  if G.TheWorld.ismastersim then
    local chapter, line = inst.components.libellusprogress:GetProgress()
    inst._libellus_chapter:set(chapter)
    inst._libellus_dialog:set(line)
  end
end)

if G.TheNet:IsDedicated() then return end

local DialogSelectorScreen = require("screens/dialogselectorscreen")

local function AddSelectorButton(screen)
  local button = screen.menu:AddItem("Dialogue...", function()
    G.TheFrontEnd:PushScreen(DialogSelectorScreen(screen.owner, function(chapter, line)
      G.SendModRPCToServer(GetModRPC(modname, "SetDialogProgress"), chapter, line)
      -- Resume normally so an automatically paused server can process the RPC.
      screen:unpause()
    end))
  end)
  button:SetScale(.7)
  local spacing = math.abs(screen.menu.offset)
  screen.menu:SetPosition(0, spacing * (#screen.menu.items - 1) / 2)
  local width, height = screen.bg:GetSize()
  screen.bg:SetSize(width, height + spacing)
  if screen.bg.body ~= nil then
    local textwidth, textheight = screen.bg.body:GetRegionSize()
    screen.bg.body:SetRegionSize(textwidth, textheight + spacing)
  end
end

AddClassPostConstruct("screens/redux/pausescreen", function(screen)
  local BuildMenu = screen.BuildMenu
  screen.BuildMenu = function(self, ...)
    BuildMenu(self, ...)
    AddSelectorButton(self)
  end
  AddSelectorButton(screen)
end)
