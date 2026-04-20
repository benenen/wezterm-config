local M = {}

function M.build_tmux_session_name(pane_id)
   if pane_id == nil then
      return nil
   end

   local normalized = tostring(pane_id)
   if normalized == '' then
      return nil
   end

   return 'wezterm-p' .. normalized
end

function M.resolve_tmux_session_name(pane)
   if not pane or not pane.pane_id then
      return nil
   end

   local ok, pane_id = pcall(function()
      return pane:pane_id()
   end)
   if not ok then
      return nil
   end

   return M.build_tmux_session_name(pane_id)
end

function M.build_root_tmux_session_name(window_id, tab_id)
   if window_id == nil or tab_id == nil then
      return nil
   end

   local normalized_window_id = tostring(window_id)
   local normalized_tab_id = tostring(tab_id)
   if normalized_window_id == '' or normalized_tab_id == '' then
      return nil
   end

   return string.format('wezterm-w%st%s', normalized_window_id, normalized_tab_id)
end

function M.resolve_root_tmux_session_name(window, tab)
   if not window or not tab or not window.window_id or not tab.tab_id then
      return nil
   end

   local ok_window, window_id = pcall(function()
      return window:window_id()
   end)
   if not ok_window then
      return nil
   end

   local ok_tab, tab_id = pcall(function()
      return tab:tab_id()
   end)
   if not ok_tab then
      return nil
   end

   return M.build_root_tmux_session_name(window_id, tab_id)
end

function M.resolve_next_root_tmux_session_name(mux_window)
   if not mux_window or not mux_window.window_id or not mux_window.tabs then
      return nil
   end

   local ok_window, window_id = pcall(function()
      return mux_window:window_id()
   end)
   if not ok_window then
      return nil
   end

   local ok_tabs, tabs = pcall(function()
      return mux_window:tabs()
   end)
   if not ok_tabs or type(tabs) ~= 'table' then
      return nil
   end

   return M.build_root_tmux_session_name(window_id, #tabs)
end

function M.resolve_next_pane_tmux_session_name_from_windows(windows)
   local max_pane_id = 0

   for _, mux_window in ipairs(windows or {}) do
      local ok_tabs, tabs = pcall(function()
         return mux_window:tabs()
      end)
      if ok_tabs and type(tabs) == 'table' then
         for _, tab in ipairs(tabs) do
            local ok_panes, panes = pcall(function()
               return tab:panes()
            end)
            if ok_panes and type(panes) == 'table' then
               for _, pane in ipairs(panes) do
                  local ok_pane_id, pane_id = pcall(function()
                     return pane:pane_id()
                  end)
                  if ok_pane_id and type(pane_id) == 'number' and pane_id > max_pane_id then
                     max_pane_id = pane_id
                  end
               end
            end
         end
      end
   end

   return M.build_tmux_session_name(max_pane_id + 1)
end

function M.resolve_pane_index_from_info(panes, current_pane_id)
   for _, info in ipairs(panes or {}) do
      local pane = info.pane
      if pane and pane:pane_id() == current_pane_id then
         return info.index or 0
      end
   end

   return 0
end

function M.build_remote_tmux_command(session_name)
   return string.format(
      'SESSION_NAME=%s; if [ -n "$TMUX" ]; then exec "${SHELL:-/bin/sh}" -l; elif command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; else exec "${SHELL:-/bin/sh}" -l; fi',
      session_name
   )
end

function M.build_ssh_spawn_args(host, session_name)
   return { 'ssh', '-t', host, M.build_remote_tmux_command(session_name) }
end

function M.build_remote_program_args(session_name)
   return { 'sh', '-lc', M.build_remote_tmux_command(session_name) }
end

function M.build_tmux_attach_input(session_name)
   return string.format(
      'SESSION_NAME=%s; if [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; fi\n',
      session_name
   )
end

function M.resolve_ssh_target(domain)
   if not domain then
      return nil
   end

   local target = domain.remote_address
   if not target or target == '' then
      local name = domain.name or ''
      target = name:gsub('^SSHMUX:', ''):gsub('^SSH:', '')
   end

   if domain.username and domain.username ~= '' then
      return string.format('%s@%s', domain.username, target)
   end

   return target
end

function M.resolve_pane_index(pane)
   if not pane or not pane.pane_id or not pane.tab then
      return 0
   end

   local ok, tab = pcall(function()
      return pane:tab()
   end)
   if not ok or not tab or not tab.panes_with_info then
      return 0
   end

   local ok_panes, panes = pcall(function()
      return tab:panes_with_info()
   end)
   if not ok_panes then
      return 0
   end

   return M.resolve_pane_index_from_info(panes, pane:pane_id())
end

function M.is_ssh_domain_name(domain_name)
   if not domain_name or domain_name == '' then
      return false
   end

   return domain_name:match('^SSH:') ~= nil or domain_name:match('^SSHMUX:') ~= nil
end

return M
