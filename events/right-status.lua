---@type Wezterm
local wezterm = require('wezterm')
local agent_deck = require('agent-deck')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')
local backdrops = require('utils.backdrops')
local system_info = require('utils.system-info')

local nf = wezterm.nerdfonts
local attr = Cells.attr

---@alias Event.RightStatusOptionsInput { date_format?: string }

---@alias Event.RightStatusOptions { date_format: string }

---Setup options for the right status bar
---@type OptsValidator
local EVENT_OPTS = OptsValidator:new({
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
})

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local BACKDROP_SWITCH_INTERVAL = 300
local last_backdrop_switch = os.time()

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   agent_working  = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_waiting  = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_idle     = { fg = '#89b4fa', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_inactive = { fg = '#6c7086', bg = 'rgba(0, 0, 0, 0.4)' },
   date           = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery        = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   hostname       = { fg = '#f5c2e7', bg = 'rgba(0, 0, 0, 0.4)' },
   separator      = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' }
}

local cells = Cells:new()

cells
   :add_segment('agent_working_icon', '', colors.agent_working)
   :add_segment('agent_working_text', '', colors.agent_working, attr(attr.intensity('Bold')))
   :add_segment('agent_waiting_icon', '', colors.agent_waiting)
   :add_segment('agent_waiting_text', '', colors.agent_waiting, attr(attr.intensity('Bold')))
   :add_segment('agent_idle_icon', '', colors.agent_idle)
   :add_segment('agent_idle_text', '', colors.agent_idle, attr(attr.intensity('Bold')))
   :add_segment('agent_inactive_icon', '', colors.agent_inactive)
   :add_segment('agent_inactive_text', '', colors.agent_inactive, attr(attr.intensity('Bold')))
   :add_segment('agent_separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('hostname_separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('hostname_icon', '', colors.hostname)
   :add_segment('hostname_text', '', colors.hostname, attr(attr.intensity('Bold')))

---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---Get agent status information for display
---@return string working_icon
---@return string working_text
---@return string waiting_icon
---@return string waiting_text
---@return string idle_icon
---@return string idle_text
---@return string inactive_icon
---@return string inactive_text
---@return boolean has_agents
local function agent_status_info()
   local counts = agent_deck.count_agents_by_status()
   local working_count = counts.working or 0
   local waiting_count = counts.waiting or 0
   local idle_count = counts.idle or 0
   local inactive_count = counts.inactive or 0

   local working_icon = working_count > 0 and '● ' or ''
   local working_text = working_count > 0 and tostring(working_count) .. ' working ' or ''
   local waiting_icon = waiting_count > 0 and '◔ ' or ''
   local waiting_text = waiting_count > 0 and tostring(waiting_count) .. ' waiting ' or ''
   local idle_icon = idle_count > 0 and '○ ' or ''
   local idle_text = idle_count > 0 and tostring(idle_count) .. ' idle ' or ''
   local inactive_icon = inactive_count > 0 and '◌ ' or ''
   local inactive_text = inactive_count > 0 and tostring(inactive_count) .. ' inactive' or ''

   local has_agents = working_count > 0 or waiting_count > 0 or idle_count > 0 or inactive_count > 0

   return working_icon, working_text, waiting_icon, waiting_text, idle_icon, idle_text, inactive_icon, inactive_text, has_agents
end

---Get system information for display (hostname only)
---@return string hostname_icon
---@return string hostname_text
---@return boolean has_hostname
local function system_info_display()
   local hostname = system_info.system_info()

   local hostname_icon = hostname ~= '' and nf.md_server .. ' ' or ''
   local hostname_text = hostname ~= '' and hostname or ''
   local has_hostname = hostname ~= ''

   return hostname_icon, hostname_text, has_hostname
end

---@param opts? Event.RightStatusOptionsInput Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   ---@cast valid_opts Event.RightStatusOptions

   wezterm.on('update-status', function(window, _pane)
      local now = os.time()
      if now - last_backdrop_switch >= BACKDROP_SWITCH_INTERVAL then
         backdrops:random(window)
         last_backdrop_switch = now
      end

      -- Update agent states for all panes
      for _, mux_tab in ipairs(window:mux_window():tabs()) do
         for _, p in ipairs(mux_tab:panes()) do
            agent_deck.update_pane(p)
         end
      end

      local battery_text, battery_icon = battery_info()
      local working_icon, working_text, waiting_icon, waiting_text, idle_icon, idle_text, inactive_icon, inactive_text, has_agents = agent_status_info()
      local hostname_icon, hostname_text, has_hostname = system_info_display()

      cells
         :update_segment_text('agent_working_icon', working_icon)
         :update_segment_text('agent_working_text', working_text)
         :update_segment_text('agent_waiting_icon', waiting_icon)
         :update_segment_text('agent_waiting_text', waiting_text)
         :update_segment_text('agent_idle_icon', idle_icon)
         :update_segment_text('agent_idle_text', idle_text)
         :update_segment_text('agent_inactive_icon', inactive_icon)
         :update_segment_text('agent_inactive_text', inactive_text)
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)
         :update_segment_text('hostname_icon', hostname_icon)
         :update_segment_text('hostname_text', hostname_text)

      local segments = {}
      if has_agents then
         segments = {
            'agent_working_icon', 'agent_working_text',
            'agent_waiting_icon', 'agent_waiting_text',
            'agent_idle_icon', 'agent_idle_text',
            'agent_inactive_icon', 'agent_inactive_text',
            'agent_separator'
         }
      end

      table.insert(segments, 'date_icon')
      table.insert(segments, 'date_text')
      table.insert(segments, 'separator')
      table.insert(segments, 'battery_icon')
      table.insert(segments, 'battery_text')

      if has_hostname then
         table.insert(segments, 'hostname_separator')
         table.insert(segments, 'hostname_icon')
         table.insert(segments, 'hostname_text')
      end

      window:set_right_status(
         wezterm.format(cells:render(segments))
      )
   end)
end

return M
