-- CachyOS Hyprland configuration with personal overrides.

-- Stow resolves this file to the repository. Keep CachyOS' modules in the
-- normal XDG config directory instead of requiring copies in this package.
local hypr_config = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/"
package.path = hypr_config .. "?.lua;" .. hypr_config .. "?/init.lua;" .. package.path

require("config.animations")
require("config.autostart")
require("config.colors")
require("config.decorations")
require("config.variables")
require("config.environment")
require("config.inputs")
require("config.user-inputs")
require("config.binds")
require("config.user-binds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")
