local REVEAL_SPACING = 30 -- Matches the native debug map-reveal grid.

local function TeachMap(self, player)
  local explorer = player ~= nil and player:HasTag("player")
    and player.player_classified ~= nil and player.player_classified.MapExplorer or nil
  if explorer == nil then return false, "NOEXPLORER" end

  -- Map dimensions are in tiles; RevealArea takes world coordinates. Use the
  -- reader's private explorer so other players keep their own exploration.
  local width, height = TheWorld.Map:GetSize()
  local halfwidth, halfheight = width * TILE_SCALE / 2, height * TILE_SCALE / 2
  for column = 0, math.ceil(width * TILE_SCALE / REVEAL_SPACING) do
    local x = math.min(-halfwidth + column * REVEAL_SPACING, halfwidth)
    for row = 0, math.ceil(height * TILE_SCALE / REVEAL_SPACING) do
      local z = math.min(-halfheight + row * REVEAL_SPACING, halfheight)
      explorer:RevealArea(x, 0, z)
    end
  end
  player:PushEvent("learnmap", {map = self.inst})
  self.inst:Remove()
  return true
end

local function fn()
  -- Reuse the native scroll's art, inventory replication, and Teach action.
  local inst = Prefabs.mapscroll.fn()
  inst.displaynamefn = function() return "World Map" end
  if not TheWorld.ismastersim then return inst end

  inst.components.inventoryitem:ChangeImageName(TheWorld.worldprefab == "cave" and "mapscroll_cave" or "mapscroll")
  inst.components.maprecorder.TeachMap = TeachMap
  return inst
end

return Prefab("libellus_worldmap", fn, nil, {"mapscroll"})
