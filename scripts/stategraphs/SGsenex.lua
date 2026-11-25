require("stategraphs/commonstates")

local states = {}
CommonStates.AddIdle(states)
CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states)
CommonStates.AddCombatStates(states, {
  attacktimeline = {
    TimeEvent(8 * FRAMES, function(inst)
      local target = inst.sg.statemem.target
      -- Recheck at impact, including when the target exits during the swing.
      if inst:CanGuardTarget(target) then
        inst.components.combat:DoAttack(target)
      else
        inst.components.combat:DropTarget()
      end
    end)
  }
}, {attack = "atk", hit = "hit", death = "death"})

return StateGraph("senex", states, {
  CommonHandlers.OnLocomote(true, true),
  EventHandler("doattack", function(inst, data)
    local target = data ~= nil and data.target or inst.components.combat.target
    if not inst.components.health:IsDead() and inst:CanGuardTarget(target)
      and (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit")) then
      inst:FacePoint(target.Transform:GetWorldPosition())
      -- The shared attack handler does not forward its target to the state.
      inst.sg:GoToState("attack", target)
    end
  end),
  -- Keep hit reactions independent of player-only electrocution states.
  EventHandler("attacked", function(inst)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
      inst.sg:GoToState("hit")
    end
  end),
  CommonHandlers.OnDeath()
}, "idle")
