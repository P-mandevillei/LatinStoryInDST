name = "latinPresentation"
description = "Latin Final Project Libellus Presentation"
author = "p_mandevillei"
version = "0.0.1"
forumthread = ""
-- icon_atlas = ""
-- icon = ""
client_only_mod = false
all_clients_require_mod = true
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
priority = -1e30
api_version = 10
configuration_options = {
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
