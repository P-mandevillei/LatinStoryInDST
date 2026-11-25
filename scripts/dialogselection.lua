local DIALOG = require("libellus")
local Selection = {}

local function GetChapter(chapter)
  return type(chapter) == "string" and chapter:match("^ch%d+$") ~= nil
    and DIALOG[chapter] or nil
end

function Selection.GetChapterOptions()
  local options = {}
  for chapter, lines in pairs(DIALOG) do
    if GetChapter(chapter) ~= nil and #lines > 0 then
      table.insert(options, {text = "Chapter " .. chapter:sub(3), data = chapter})
    end
  end
  table.sort(options, function(a, b)
    return tonumber(a.data:sub(3)) < tonumber(b.data:sub(3))
  end)
  return options
end

function Selection.GetLineOptions(chapter)
  local options = {}
  for line = 1, #(GetChapter(chapter) or {}) do
    table.insert(options, {text = tostring(line), data = line})
  end
  return options
end

function Selection.GetCurrent(player)
  if player ~= nil and player._libellus_chapter ~= nil then
    return player._libellus_chapter:value(), player._libellus_dialog:value()
  end
end

-- The RPC supplies its own sending player. Only progress is changed here.
function Selection.Apply(player, chapter, line)
  local lines = GetChapter(chapter)
  if lines == nil or type(line) ~= "number" or line ~= math.floor(line)
    or line < 1 or line > #lines or player == nil or not player:IsValid() then
    return false
  end
  local progress = player.components.libellusprogress
  return progress ~= nil and progress:SetProgress(chapter, line) or false
end

return Selection
