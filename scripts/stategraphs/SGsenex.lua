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

table.insert(states, State {
  name = "sleep",
  tags = {"busy", "sleeping"},
  onenter = function(inst)
    inst:ClearBufferedAction()
    inst.components.locomotor:Stop()
    inst.AnimState:Hide("ARM_carry")
    inst.AnimState:Show("ARM_normal")
    inst.AnimState:PlayAnimation("dozy")
  end,
  events = {EventHandler("animover", function(inst) inst.sg:GoToState("sleeping") end)}
})
table.insert(states, State {
  name = "sleeping",
  tags = {"busy", "sleeping"},
  onenter = function(inst) inst.AnimState:PlayAnimation("sleep_loop", true) end
})
table.insert(states, State {
  name = "wake",
  tags = {"busy", "waking"},
  onenter = function(inst) inst.AnimState:PlayAnimation("wakeup") end,
  events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)},
  onexit = function(inst)
    if inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= nil then
      inst.AnimState:Show("ARM_carry")
      inst.AnimState:Hide("ARM_normal")
    end
  end
})

return StateGraph("senex", states, {
  CommonHandlers.OnLocomote(true, true),
  EventHandler("gotosleep", function(inst)
    if not inst.components.health:IsDead() then inst.sg:GoToState("sleep") end
  end),
  EventHandler("onwakeup", function(inst)
    if not inst.components.health:IsDead() then inst.sg:GoToState("wake") end
  end),
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
