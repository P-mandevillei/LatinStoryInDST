-- Wilson-based NPCs use the player's sleeping animations, rather than the
-- creature sleep_pre/sleep_pst names supplied by CommonStates.
return function(states)
  table.insert(states, State{
    name = "sleep", tags = {"busy", "sleeping"},
    onenter = function(inst)
      inst.components.locomotor:Stop()
      inst.AnimState:PlayAnimation("dozy")
      inst.AnimState:PushAnimation("sleep_loop", true)
    end,
    events = {EventHandler("onwakeup", function(inst) inst.sg:GoToState("wake") end)},
  })
  table.insert(states, State{
    name = "wake", tags = {"busy", "waking"},
    onenter = function(inst) inst.AnimState:PlayAnimation("wakeup") end,
    events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)},
  })
end
