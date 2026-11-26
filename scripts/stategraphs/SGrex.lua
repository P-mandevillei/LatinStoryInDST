require("stategraphs/commonstates")
local states = {
  State{
    name = "ring",
    tags = {"busy", "playing"},
    onenter = function(inst)
      inst.components.locomotor:Stop()
      inst.AnimState:OverrideSymbol("bell01", "bell", "bell01")
      inst.AnimState:PlayAnimation("action_uniqueitem_pre")
      inst.AnimState:PushAnimation("bell", false)
      inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/glommer_bell")
      inst.sg:SetTimeout(2.5)
    end,
    ontimeout = function(inst) inst.sg:GoToState("idle") end,
    onexit = function(inst) inst.AnimState:ClearOverrideSymbol("bell01") end,
  },
}
require("stategraphs/libellussleepstates")(states)
CommonStates.AddIdle(states)
CommonStates.AddSimpleState(states, "death", "death", {"busy", "dead"})
return StateGraph("rex", states, {
  CommonHandlers.OnDeath(),
  EventHandler("gotosleep", function(inst)
    if not inst.components.health:IsDead() then inst.sg:GoToState("sleep") end
  end),
}, "idle")
