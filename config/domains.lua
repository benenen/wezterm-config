local wezterm = require('wezterm')
local platform = require('utils.platform')

local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ---@type SshDomain[]
   ssh_domains = wezterm.default_ssh_domains(),

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   ---@type UnixDomain[]
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   ---@type WslDomain[]
   wsl_domains = {},
}

return options
