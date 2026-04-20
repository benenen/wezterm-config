---@type Wezterm
local wezterm = require('wezterm')
local launch_menu = require('config.launch').launch_menu
local domains = require('config.domains')
local Cells = require('utils.cells')
local ssh = require('utils.ssh')

local nf = wezterm.nerdfonts
local act = wezterm.action
local attr = Cells.attr

local M = {}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   label_text   = { fg = '#CDD6F4' },
   icon_default = { fg = '#89B4FA' },
   icon_wsl     = { fg = '#FAB387' },
   icon_ssh     = { fg = '#F38BA8' },
   icon_unix    = { fg = '#CBA6F7' },
}

local cells = Cells:new()
   :add_segment('icon_default', ' ' .. nf.oct_terminal .. ' ', colors.icon_default)
   :add_segment('icon_wsl', ' ' .. nf.cod_terminal_linux .. ' ', colors.icon_wsl)
   :add_segment('icon_ssh', ' ' .. nf.md_ssh .. ' ', colors.icon_ssh)
   :add_segment('icon_unix', ' ' .. nf.dev_gnu .. ' ', colors.icon_unix)
   :add_segment('label_text', '', colors.label_text, attr(attr.intensity('Bold')))

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

local function build_choices()
   local choices = {}
   local choices_data = {}
   local idx = 1

   -- Add launch menu items (DefaultDomain)
   for _, v in ipairs(launch_menu) do
      cells:update_segment_text('label_text', v.label)

      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_default', 'label_text' })),
      })
      table.insert(choices_data, {
         args = v.args,
         domain = 'DefaultDomain',
      })
      idx = idx + 1
   end

   -- Add WSL domains
   for _, v in ipairs(domains.wsl_domains) do
      cells:update_segment_text('label_text', v.name)

      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_wsl', 'label_text' })),
      })
      table.insert(choices_data, {
         domain = { DomainName = v.name },
      })
      idx = idx + 1
   end

   -- Add SSH domains
   for _, v in ipairs(domains.ssh_domains) do
      cells:update_segment_text('label_text', v.name)
      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_ssh', 'label_text' })),
      })
      table.insert(choices_data, {
         ssh_domain = v,
      })
      idx = idx + 1
   end

   -- Add Unix domains
   for _, v in ipairs(domains.unix_domains) do
      cells:update_segment_text('label_text', v.name)
      table.insert(choices, {
         id = tostring(idx),
         label = wezterm.format(cells:render({ 'icon_unix', 'label_text' })),
      })
      table.insert(choices_data, {
         domain = { DomainName = v.name },
      })
      idx = idx + 1
   end

   return choices, choices_data
end

local choices, choices_data = build_choices()

M.setup = function()
   wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
      if default_action and button == 'Left' then
         window:perform_action(default_action, pane)
      end

      if button == 'Right' then
         window:perform_action(
            act.InputSelector({
               title = 'InputSelector: Launch Menu',
               choices = choices,
               fuzzy = true,
               fuzzy_description = nf.md_rocket .. ' Select a lauch item: ',
               action = wezterm.action_callback(function(_window, _pane, id, label)
                  if not id and not label then
                     return
                  end
                  wezterm.log_info('you selected ', id, label)
                  wezterm.log_info(choices_data[tonumber(id)])
                  local choice = choices_data[tonumber(id)]
                  if choice.ssh_domain then
                     spawn_ssh_domain_in_new_tab(window, pane, choice.ssh_domain)
                     return
                  end

                  window:perform_action(act.SpawnCommandInNewTab(choice), pane)
               end),
            }),
            pane
         )
      end

      return false
   end)
end

return M
