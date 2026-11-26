require("stategraphs/commonstates")

local states = {}
require("stategraphs/libellussleepstates")(states)
CommonStates.AddIdle(states)
CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states)
-- The default jump_* animations are creature hops. Wilson's boat hops use a
-- separate asset and boat_jump_* names; missing loop/post animations hide him
-- and prevent the landing animation from completing.
CommonStates.AddHopStates(states, true, {
  pre = "boat_jump_pre",
  loop = "boat_jump_loop",
  pst = "boat_jump_pst"
}, nil, "turnoftides/common/together/boat/jump_on", nil, {start_embarking_pre_frame = 4 * FRAMES})

return StateGraph("publius", states, {
  CommonHandlers.OnLocomote(true, true),
  CommonHandlers.OnHop()
}, "idle")
