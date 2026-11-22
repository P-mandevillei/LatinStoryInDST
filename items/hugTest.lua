-- *************************** Huggable test component ************************

-- arg1: name/id
-- arg2: str shows up when the action is performed
-- arg3: callback function
AddAction("HUG", "Awww Soooo Cuteee!!!! :)", function(act)
  if act.invobject then -- check if the object exists
    act.invobject.components.huggable:Hug(act.doer)
    return true
  end
  return false
end)
-- arg1: type of action we want to create (5 types)
-- arg2: name of component
AddComponentAction("INVENTORY", "huggable", function(inst, doer, actions, right)
  if doer.replica.inventory:GetActiveItem() == nil and (doer.replica.rider == nil or not doer.replica.rider:IsRiding()) then
    table.insert(actions, GLOBAL.ACTIONS.HUG) -- id of the action
  end
end)

-- State{
--   name = "",
--   tags = {},
--   onenter = function(inst) end,
--   onexit = function(inst) end,
--   onupdate = function(inst) end, -- called as long as the entity is in state
--   ontimeout = function(inst) end,
--   events = {}, -- event handlers active when the entity is in state
--   timeline = {}, -- time events used when the state is running
--   server_states = {} -- used by client to sync with server
-- }

local hug_state = GLOBAL.State({
  name = "my_custom_hug_state",
  tags = {"doing", "busy"},
  onenter = function(inst)
    inst.components.locomotor:Stop()
    inst.AnimState:Show("ARM_carry")
    inst.AnimState:Hide("ARM_normal")
    inst.AnimState:PlayAnimation("action_uniqueitem_pre")
    inst.AnimState:PushAnimation("idle_willow", false)
    inst.AnimState:OverrideSymbol("swap_object", "bernie_build", "swap_bernie")
    inst.AnimState:OverrideSymbol("swap_object_bernie", "bernie_build", "swap_bernie_idle_willow")
  end,
  onexit = function(inst)
    inst.AnimState:Show("ARM_normal")
    inst.AnimState:Hide("ARM_carry")
  end,

  events = {
    GLOBAL.EventHandler("animqueueover", function(inst)
      inst.sg:GoToState("idle")
    end)
  },
  timeline = {
    GLOBAL.TimeEvent(50*GLOBAL.FRAMES, function(inst)
      inst:PerformBufferedAction()
    end)
  }
})
local hug_state_client = GLOBAL.State({
  name = "my_custom_hug_state",
  server_states = {"my_custom_hug_state"},
  forward_server_states = true,
  onenter = function(inst) inst.sg:GoToState("action_uniqueitem_busy") end
})
-- arg1: what state graph we are editting
-- arg2: what action handler to add
AddStategraphState("wilson_client", hug_state_client)
AddStategraphState("wilson", hug_state)
AddStategraphActionHandler(
  "wilson",
  GLOBAL.ActionHandler(GLOBAL.ACTIONS.HUG, "my_custom_hug_state") -- arg2: state name
)
AddStategraphActionHandler(
  "wilson_client",
  GLOBAL.ActionHandler(GLOBAL.ACTIONS.HUG, "my_custom_hug_state") -- arg2: state name
)