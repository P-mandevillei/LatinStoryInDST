local states = {
  State{
    name = "idle",
    tags = {"idle"},
    onenter = function(inst) inst.AnimState:PlayAnimation("idle", true) end,
  },
  State{
    name = "flight",
    tags = {"busy", "flight"},
    onenter = function(inst)
      inst.AnimState:PlayAnimation("takeoff_diagonal_pre")
      inst.sg:SetTimeout(.2)
    end,
    ontimeout = function(inst) inst.AnimState:PlayAnimation("takeoff_diagonal_loop", true) end,
  },
  State{
    name = "land",
    tags = {"busy"},
    onenter = function(inst)
      inst.AnimState:PlayAnimation("land")
      inst.sg:SetTimeout(.5)
    end,
    ontimeout = function(inst)
      inst._arrived, inst._landing = true, nil
      inst.sg:GoToState("idle")
    end,
  },
}
return StateGraph("passer", states, {}, "idle")
