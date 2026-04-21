package.path = table.concat({
   './?.lua',
   './?/init.lua',
   package.path,
}, ';')

local ssh = require('utils.ssh')

local function assert_eq(actual, expected, label)
   if actual ~= expected then
      error(string.format('%s: expected %q, got %q', label, expected, actual))
   end
end

do
   assert_eq(ssh.build_tmux_session_name(3), 'wezterm-p3', 'build_tmux_session_name number')
   assert_eq(ssh.build_tmux_session_name('12'), 'wezterm-p12', 'build_tmux_session_name string')
end

do
   assert_eq(
      ssh.build_root_tmux_session_name(7, 9),
      'wezterm-p1',
      'build_root_tmux_session_name'
   )
end

do
   local cmd = ssh.build_remote_tmux_command('3')
   assert_eq(
      cmd,
      'SESSION_NAME=3; if [ -n "$TMUX" ]; then exec "${SHELL:-/bin/sh}" -l; elif command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; else exec "${SHELL:-/bin/sh}" -l; fi',
      'build_remote_tmux_command'
   )
end

do
   local resolved = ssh.resolve_pane_index_from_info({
      { index = 0, pane = { pane_id = function() return 10 end } },
      { index = 1, pane = { pane_id = function() return 11 end } },
   }, 11)
   assert_eq(resolved, 1, 'resolve_pane_index_from_info')
end

do
   local args = ssh.build_ssh_spawn_args('my-host', '2')
   assert_eq(args[1], 'ssh', 'ssh binary')
   assert_eq(args[2], '-t', 'ssh tty flag')
   assert_eq(args[3], 'my-host', 'ssh host')
   assert_eq(args[4], ssh.build_remote_tmux_command('2'), 'remote command')
end

do
   local args = ssh.build_remote_program_args('2')
   assert_eq(args[1], 'sh', 'remote shell binary')
   assert_eq(args[2], '-lc', 'remote shell flag')
   assert_eq(args[3], ssh.build_remote_tmux_command('2'), 'remote shell command')
end

do
   local session_name = ssh.resolve_next_pane_tmux_session_name_from_windows({
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 0, pane = { pane_id = function() return 2 end } },
                  { index = 1, pane = { pane_id = function() return 5 end } },
               }
            end,
         }
      end,
   })

   assert_eq(session_name, 'wezterm-p3', 'resolve_next_pane_tmux_session_name_from_windows')
end

do
   assert_eq(
      ssh.build_tmux_attach_input('5'),
      'SESSION_NAME=5; if [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then exec tmux new -A -s "$SESSION_NAME"; fi\n',
      'build_tmux_attach_input'
   )
end

do
   assert_eq(
      ssh.resolve_ssh_target({ remote_address = 'devbox.example.com', name = 'SSH:devbox' }),
      'devbox.example.com',
      'resolve_ssh_target remote_address'
   )
   assert_eq(
      ssh.resolve_ssh_target({
         remote_address = 'devbox.example.com',
         username = 'alice',
         name = 'SSH:devbox',
      }),
      'alice@devbox.example.com',
      'resolve_ssh_target username'
   )
   assert_eq(
      ssh.resolve_ssh_target({ name = 'SSH:devbox' }),
      'devbox',
      'resolve_ssh_target ssh prefix'
   )
   assert_eq(
      ssh.resolve_ssh_target({ name = 'SSHMUX:devbox' }),
      'devbox',
      'resolve_ssh_target sshmux prefix'
   )
end

do
   assert_eq(ssh.is_ssh_domain_name('SSH:devbox'), true, 'is_ssh_domain_name ssh')
   assert_eq(ssh.is_ssh_domain_name('SSHMUX:devbox'), true, 'is_ssh_domain_name sshmux')
   assert_eq(ssh.is_ssh_domain_name('local'), false, 'is_ssh_domain_name local')
end

do
   local session_name = ssh.resolve_tmux_session_name({
      pane_id = function()
         return 11
      end,
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 0, pane = { pane_id = function() return 10 end } },
                  { index = 1, pane = { pane_id = function() return 11 end } },
               }
            end,
         }
      end,
   })

   assert_eq(session_name, 'wezterm-p2', 'resolve_tmux_session_name')
end

do
   local session_name = ssh.resolve_root_tmux_session_name({
      window_id = function()
         return 3
      end,
   }, {
      tab_id = function()
         return 4
      end,
   })

   assert_eq(session_name, 'wezterm-p1', 'resolve_root_tmux_session_name')
end

do
   local session_name = ssh.resolve_next_root_tmux_session_name({
      window_id = function()
         return 5
      end,
      tabs = function()
         return { {}, {}, {} }
      end,
   })

   assert_eq(session_name, 'wezterm-p1', 'resolve_next_root_tmux_session_name')
end

do
   local fake_pane = {
      pane_id = function()
         return 11
      end,
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 0, pane = { pane_id = function() return 10 end } },
                  { index = 1, pane = { pane_id = function() return 11 end } },
               }
            end,
         }
      end,
   }

   assert_eq(ssh.resolve_pane_index(fake_pane), 1, 'resolve_pane_index')
end

do
   local first_session = ssh.resolve_tmux_session_name({
      pane_id = function()
         return 21
      end,
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 0, pane = { pane_id = function() return 21 end } },
               }
            end,
         }
      end,
   })
   local second_session = ssh.resolve_tmux_session_name({
      pane_id = function()
         return 22
      end,
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 1, pane = { pane_id = function() return 22 end } },
               }
            end,
         }
      end,
   })

   if first_session == second_session then
      error('unique tmux session names should differ across pane ids')
   end
end

do
   local root_session = ssh.resolve_root_tmux_session_name({
      window_id = function()
         return 1
      end,
   }, {
      tab_id = function()
         return 1
      end,
   })
   local pane_session = ssh.resolve_tmux_session_name({
      pane_id = function()
         return 1
      end,
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 0, pane = { pane_id = function() return 1 end } },
               }
            end,
         }
      end,
   })

   assert_eq(root_session, 'wezterm-p1', 'root tmux session name')
   assert_eq(pane_session, 'wezterm-p1', 'first pane tmux session name')
end

do
   local session_name = ssh.resolve_next_pane_tmux_session_name_from_windows({
      tab = function()
         return {
            panes_with_info = function()
               return {
                  { index = 2, pane = { pane_id = function() return 7 end } },
                  { index = 0, pane = { pane_id = function() return 5 end } },
               }
            end,
         }
      end,
   })

   assert_eq(session_name, 'wezterm-p4', 'resolve_next_pane_tmux_session_name_from_windows max index')
end
