require("stategraphs/commonstates")

local states = {}
CommonStates.AddIdle(states)
CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states)
CommonStates.AddHopStates(states, true)

return StateGraph("publius", states, {
  CommonHandlers.OnLocomote(true, true),
  CommonHandlers.OnHop()
}, "idle")
