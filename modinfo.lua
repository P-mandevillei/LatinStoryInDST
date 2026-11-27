name = "latinPresentation"
description = [[
# Latin Libellus Presentation
- Final Project of Latin 1510 at Washington University in St. Louis
Go on an adventure to rescue your pet wolf and save the animal kingdom!
]]
author = "p_mandevillei"
version = "0.0.4"
forumthread = ""
icon_atlas = "modicon.xml"
icon = "modicon.tex"
client_only_mod = false
all_clients_require_mod = true
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
priority = -1e30
api_version = 10
-- Bigfoot Returns supplies the Old Bell and the replicated Biiigfoot encounter.
mod_dependencies = {
  {workshop = "workshop-2522543318"}
}
configuration_options = {
  {
    name = "casa_supplies",
    label = "Casa supply chest",
    hover = "Supply the chapter-two casa once with equipment, supplies, and a full-world map scroll.",
    options = {
      {description = "Disabled", data = false},
      {description = "Enabled", data = true}
    },
    default = false
  },
  {
    name = "dialog_selector",
    label = "Dialogue selector",
    hover = "Show chapter and line selection in the in-game pause menu.",
    options = {
      {description = "Disabled", data = false},
      {description = "Enabled", data = true}
    },
    default = false
  }
}
