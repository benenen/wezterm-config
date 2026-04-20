local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local domains = require('config.domains')
local ssh = require('utils.ssh')
local workspace_picker = require('utils.workspace-picker')
local act = wezterm.action
local nf = wezterm.nerdfonts

local mod = {}

workspace_picker.setup({
	keybinds = nil, -- Disable automatic keybinding setup
   labels = {
		workspace = "🏢",
		zoxide = "📁",
		current = "👈",
		create_new = "✨",
	},
   colors = {
		workspace_prefix = "#b8bb26",
		zoxide_prefix = "#fb4934",
		current_indicator = "#b8bb26",
		text = "#ebdbb2",
		path = "#928374",
	},
})

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
   mod.CTRL = 'SUPER' 
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT' -- to not conflict with Windows key shortcuts
   mod.SUPER_REV = 'ALT|CTRL'
   mod.CTRL = 'CTRL'

end

local function build_ssh_domain_choices()
   local choices = {}
   local choices_data = {}

   for idx, domain in ipairs(domains.ssh_domains) do
      table.insert(choices, {
         id = tostring(idx),
         label = nf.md_ssh .. ' ' .. domain.name,
      })
      table.insert(choices_data, {
         ssh_domain = domain,
      })
   end

   return choices, choices_data
end

local function spawn_ssh_domain_in_new_tab(window, _pane, domain)
   if not domain or not domain.name or domain.name == '' then
      wezterm.log_error('failed to resolve SSH domain name')
      return
   end

   local mux_window = window.mux_window and window:mux_window() or nil
   if not mux_window or not mux_window.spawn_tab then
      wezterm.log_error('failed to resolve mux window for SSH spawn')
      return
   end

   local session_name = ssh.resolve_next_root_tmux_session_name(mux_window)
   if not session_name then
      wezterm.log_error('failed to resolve tmux session name for SSH tab')
      return
   end

   local ok, new_tab = pcall(function()
      return mux_window:spawn_tab({
         domain = { DomainName = domain.name },
         args = ssh.build_remote_program_args(session_name),
      })
   end)
   if not ok or not new_tab then
      wezterm.log_error('failed to spawn SSH domain in new tab')
      return
   end

   if new_tab and new_tab.activate then
      new_tab:activate()
   end
end

local function split_current_pane(window, pane, direction)
   local domain_name = pane.get_domain_name and pane:get_domain_name() or nil
   local split_config = {
      direction = direction,
      domain = 'CurrentPaneDomain',
   }

   if ssh.is_ssh_domain_name(domain_name) then
      local mux_windows = wezterm.mux and wezterm.mux.all_windows and wezterm.mux.all_windows() or {}
      local session_name = ssh.resolve_next_pane_tmux_session_name_from_windows(mux_windows)
      if not session_name then
         wezterm.log_error('failed to resolve tmux session name for split SSH pane')
         return
      end

      split_config.args = ssh.build_remote_program_args(session_name)
   end

   local new_pane = pane:split(split_config)
   if not new_pane or not ssh.is_ssh_domain_name(domain_name) then
      return
   end
end

local ssh_domain_choices, ssh_domain_choices_data = build_ssh_domain_choices()

-- stylua: ignore
local keys = {
   -- misc/useful --
   { key = 'F1', mods = 'NONE', action = 'ActivateCopyMode' },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   {
      key = 'F5',
      mods = 'NONE',
      -- action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
      action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_workspace_selector(win, pane)
		end),
   },
   {
      key = 'F6',
      mods = 'NONE',
      action = act.InputSelector({
         title = 'InputSelector: SSH Domains',
         choices = ssh_domain_choices,
         fuzzy = true,
         fuzzy_description = nf.md_ssh .. ' Select SSH domain: ',
         action = wezterm.action_callback(function(window, pane, id, _label)
            if not id then
               return
            end

            spawn_ssh_domain_in_new_tab(window, pane, ssh_domain_choices_data[tonumber(id)].ssh_domain)
         end),
      }),
   },
   { key = 'F11', mods = 'NONE',    action = act.ToggleFullScreen },
   { key = 'F12', mods = 'NONE',    action = act.ShowDebugOverlay },
   { key = 'f',   mods = mod.SUPER, action = act.Search({ CaseInSensitiveString = '' }) },
   {
      key = 'u',
      mods = mod.SUPER_REV,
      action = wezterm.action.QuickSelectArgs({
         label = 'open url',
         patterns = {
            '\\((https?://\\S+)\\)',
            '\\[(https?://\\S+)\\]',
            '\\{(https?://\\S+)\\}',
            '<(https?://\\S+)>',
            '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
         },
         action = wezterm.action_callback(function(window, pane)
            local url = window:get_selection_text_for_pane(pane)
            wezterm.log_info('opening: ' .. url)
            wezterm.open_with(url)
         end),
      }),
   },

   -- cursor movement --
   { key = 'LeftArrow',  mods = mod.SUPER,     action = act.SendString '\u{1b}OH' },
   { key = 'RightArrow', mods = mod.SUPER,     action = act.SendString '\u{1b}OF' },
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString '\u{15}' },

   -- copy/paste --
   {
      key = 'c',
      mods = mod.CTRL,
      action = wezterm.action_callback(function(window, pane)
         local has_selection = window:get_selection_text_for_pane(pane) ~= ''
         if has_selection then
            window:perform_action(act.CopyTo('Clipboard'), pane)
            window:perform_action(act.ClearSelection, pane)
         else
            window:perform_action(act.SendKey({ key = 'c', mods = 'CTRL' }), pane)
         end
      end),
   },
   { key = 'v',          mods = mod.CTRL,  action = act.PasteFrom('Clipboard') },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   { key = 't',          mods = mod.SUPER_REV, action = act.SpawnTab({ DomainName = 'wsl:ubuntu-fish' }) },
   { key = 'w',          mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },

   -- tabs: navigation
   { key = '[',          mods = mod.SUPER,     action = act.ActivateTabRelative(-1) },
   { key = ']',          mods = mod.SUPER,     action = act.ActivateTabRelative(1) },
   { key = '[',          mods = mod.SUPER_REV, action = act.MoveTabRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.MoveTabRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   { key = '9',          mods = mod.SUPER,     action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- window --
   -- window: spawn windows
   { key = 'n',          mods = mod.SUPER,     action = act.SpawnWindow },

   -- window: zoom window
   {
      key = '-',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         if dimensions.is_full_screen then
            return
         end
         local new_width = dimensions.pixel_width - 50
         local new_height = dimensions.pixel_height - 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = '=',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         if dimensions.is_full_screen then
            return
         end
         local new_width = dimensions.pixel_width + 50
         local new_height = dimensions.pixel_height + 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = 'Enter',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         window:maximize()
      end)
   },

   -- background controls --
   {
      key = [[/]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = [[,]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      action = act.InputSelector({
         title = 'InputSelector: Select Background',
         choices = backdrops:choices(),
         fuzzy = true,
         fuzzy_description = 'Select Background: ',
         action = wezterm.action_callback(function(window, _pane, idx)
            if not idx then
               return
            end
            ---@diagnostic disable-next-line: param-type-mismatch
            backdrops:set_img(window, tonumber(idx))
         end),
      }),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
   },

   -- panes --
   -- panes: split panes
   {
      key = 'e',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, pane)
         split_current_pane(window, pane, 'Bottom')
      end),
   },
   {
      key = 'd',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, pane)
         split_current_pane(window, pane, 'Right')
      end),
   },

   -- panes: zoom+close pane
   { key = 'Enter', mods = mod.SUPER,     action = act.TogglePaneZoomState },
   { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },

   -- panes: navigation
   { key = 'k',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Up') },
   { key = 'j',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Down') },
   { key = 'h',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Left') },
   { key = 'l',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Right') },
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

   -- panes: scroll pane
   -- { key = 'u',        mods = mod.SUPER, action = act.ScrollByLine(-5) },
   -- { key = 'd',        mods = mod.SUPER, action = act.ScrollByLine(5) },
   { key = 'PageUp',   mods = 'NONE',    action = act.ScrollByPage(-0.75) },
   { key = 'PageDown', mods = 'NONE',    action = act.ScrollByPage(0.75) },

   -- key-tables --
   -- resizes fonts
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- resize panes
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
}

-- stylua: ignore
local key_tables = {
   resize_font = {
      { key = 'k',      action = act.IncreaseFontSize },
      { key = 'j',      action = act.DecreaseFontSize },
      { key = 'r',      action = act.ResetFontSize },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'k',      action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'j',      action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'h',      action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'l',      action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
}

local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
}

return {
   disable_default_key_bindings = true,
   -- disable_default_mouse_bindings = true,
   leader = { key = 'Space', mods = mod.SUPER_REV },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
