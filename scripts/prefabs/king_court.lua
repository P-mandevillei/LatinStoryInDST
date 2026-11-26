local HELPERS = require("helpers")
local function Boss(name, base)
  return Prefab(name, function()
    -- Construct the real boss on both client and server. Its components,
    -- animation bank, combat events, special attacks, and loot stay native.
    local inst = Prefabs[base].fn()
    inst:AddTag("libellus_court")
    inst.displaynamefn = function() return "Animus Magnus" end
    if not TheWorld.ismastersim then return inst end
    inst.components.health:SetMaxHealth(HELPERS.KING_COURT_HEALTH)
    inst._king_native_brain = require("brains/"..base.."brain")
    inst:AddComponent("kingguard")
    if base == "deerclops" then
      inst.ignorebase = true
      inst.WantsToLeave = function() return false end
      local callbacks = inst.worldstatewatching ~= nil and inst.worldstatewatching.stopwinter or nil
      local copy = {}
      for _, fn in ipairs(callbacks or {}) do table.insert(copy, fn) end
      for _, fn in ipairs(copy) do inst:StopWatchingWorldState("stopwinter", fn) end
    elseif base == "beequeen" then
      local sleep = inst.OnEntitySleep
      inst.OnEntitySleep = function(inst)
        sleep(inst)
        -- Wild queens despawn ten seconds after leaving every player's view.
        -- This queen is a persistent member of the castle's saved court.
        if inst._sleeptask ~= nil then inst._sleeptask:Cancel(); inst._sleeptask = nil end
      end
    end
    if base == "dragonfly" then
      local sleep = inst.OnEntitySleep
      inst.OnEntitySleep = function(inst)
        sleep(inst)
        if inst.sleeptask ~= nil then inst.sleeptask:Cancel(); inst.sleeptask = nil end
      end
      local load = inst.OnLoad
      inst.OnLoad = function(inst, data, ...)
        -- Native load resets a wild fight and heals it to full. This boss
        -- belongs to a saved encounter and must retain its saved health.
        local copy = {}
        for k, v in pairs(data or {}) do copy[k] = v end
        copy.playercombat = nil
        load(inst, copy, ...)
      end
    end
    return inst
  end, nil, {base})
end
return Boss("animus_dragonfly", "dragonfly"), Boss("animus_deerclops", "deerclops"),
  Boss("animus_bearger", "bearger"), Boss("animus_beequeen", "beequeen")
