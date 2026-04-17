local M = {}

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
      'SESSION_NAME=%s; if command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; else exec "${SHELL:-/bin/sh}" -l; fi',
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
      'SESSION_NAME=%s; if command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; fi\n',
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
