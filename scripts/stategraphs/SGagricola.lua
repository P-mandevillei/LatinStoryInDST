require("stategraphs/commonstates")

local function FinishWork(inst, ripe)
  local crop = inst.sg.statemem.crop
  if crop ~= nil and crop:IsValid() then crop:SetCrop(crop._crop, ripe) end
  inst.sg:GoToState("idle")
end

local states = {
  State{
    name = "tend",
    tags = {"busy"},
    onenter = function(inst, crop)
      inst.components.locomotor:Stop()
      inst.sg.statemem.crop = crop
      inst.AnimState:PlayAnimation("build_pre")
      inst.AnimState:PushAnimation("build_loop", true)
      inst.sg:SetTimeout(3)
    end,
    ontimeout = function(inst) FinishWork(inst, true) end,
  },
  State{
    name = "harvest",
    tags = {"busy"},
    onenter = function(inst, crop)
      inst.components.locomotor:Stop()
      inst.sg.statemem.crop = crop
      inst.AnimState:PlayAnimation("pickup")
      inst.AnimState:PushAnimation("pickup_pst", false)
      inst.sg:SetTimeout(1)
    end,
    ontimeout = function(inst) FinishWork(inst, false) end,
  },
}
require("stategraphs/libellussleepstates")(states)
CommonStates.AddIdle(states)
CommonStates.AddWalkStates(states)
return StateGraph("agricola", states, {CommonHandlers.OnLocomote(false, true)}, "idle")
