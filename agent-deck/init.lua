-- Agent Deck - AI Agent Status Detection for WezTerm
-- Detects and monitors AI coding agents in terminal panes

local wezterm = require('wezterm')

local M = {}

-- Internal state
local state = {
   agent_states = {},  -- pane_id -> { agent_type, status, last_update }
}

-- Default agent configurations
local default_agents = {
   claude = {
      patterns = { 'claude', 'claude%-code' },
      executable_patterns = {
         '@anthropic%-ai/claude%-code',
         '/claude%-code/',
         '/claude$',
         '^claude%s*$',
      },
   },
   opencode = {
      patterns = { 'opencode' },
      executable_patterns = {
         'opencode%-darwin',
         'opencode%-linux',
         '/opencode$',
      },
   },
   aider = { patterns = { 'aider' } },
   gemini = { patterns = { 'gemini' } },
   codex = { patterns = { 'codex' } },
}

-- Default status patterns
local default_status_patterns = {
   working = {
      'esc to interrupt',
      'esc interrupt',
      'thinking',
      'pondering',
      'processing',
      'analyzing',
      'generating',
      'writing',
      'reading',
      'searching',
      'delegating work',
      'planning next steps',
      'gathering context',
      'searching the codebase',
      'searching the web',
      'making edits',
      'running commands',
      'gathering thoughts',
      'considering next steps',
      'working on it',
      'let me',
      'i will',
      'i am',
      'creating',
      'updating',
      'modifying',
   },
   waiting = {
      'esc to cancel',
      'yes, allow once',
      'yes, allow always',
      'no, and tell',
      'do you trust',
      'run this command',
      'execute this',
      'continue%?',
      'proceed%?',
      '%(y/n%)',
      '%(Y/n%)',
      '%[y/n%]',
      '%[Y/n%]',
      '%(y/N%)',
      '%(Y/N%)',
      '%[y/N%]',
      '%[Y/N%]',
      'approve this plan',
      'press enter to continue',
      'enter confirm',
      'esc dismiss',
      'type your own answer',
      'allow command',
      '%[y/n/e/a%]',
      '%[y/N/e/a%]',
   },
   idle = {
      '^>%s*$',
      '^> $',
      '^>$',
   },
}

-- Configuration
local config = {
   agents = default_agents,
   status_patterns = default_status_patterns,
   max_lines = 100,
}

--- Strip ANSI escape codes from text
---@param text string
---@return string
local function strip_ansi(text)
   if not text then return '' end
   local result = text
   result = result:gsub('\27%[%d*;?%d*;?%d*[A-Za-z]', '')
   result = result:gsub('\27%].-\007', '')
   result = result:gsub('\27%].-\27\\', '')
   result = result:gsub('\27%[%?%d+[hl]', '')
   result = result:gsub('\27%[%d*[ABCDEFGJKST]', '')
   result = result:gsub('\27%[%d*;%d*[Hf]', '')
   result = result:gsub('\27%[%d*m', '')
   result = result:gsub('\27%[[0-9;]*m', '')
   result = result:gsub('\r', '')
   return result
end

--- Check if string matches any pattern
---@param str string
---@param patterns table
---@return boolean
local function matches_any(str, patterns)
   if not str or not patterns then return false end
   local str_lower = str:lower()

   for _, pattern in ipairs(patterns) do
      local success, result = pcall(function()
         return str_lower:find(pattern:lower())
      end)
      if success and result then return true end
      if not success and str_lower:find(pattern:lower(), 1, true) then
         return true
      end
   end
   return false
end

--- Get last N lines from text
---@param text string
---@param n number
---@return string
local function get_last_lines(text, n)
   if not text then return '' end
   local lines = {}
   for line in text:gmatch('[^\n]+') do
      table.insert(lines, line)
   end
   local start = math.max(1, #lines - n + 1)
   local result = {}
   for i = start, #lines do
      table.insert(result, lines[i])
   end
   return table.concat(result, '\n')
end

--- Detect agent type from pane
---@param pane userdata
---@return string|nil
local function detect_agent(pane)
   -- Try to get process info
   local success, process_info = pcall(function()
      return pane:get_foreground_process_info()
   end)

   if success and process_info then
      local executable = process_info.executable or ''
      local name = process_info.name or ''

      for agent_name, agent_config in pairs(config.agents) do
         -- Check executable patterns
         if agent_config.executable_patterns then
            if matches_any(executable, agent_config.executable_patterns) or
               matches_any(name, agent_config.executable_patterns) then
               return agent_name
            end
         end

         -- Check generic patterns
         if matches_any(executable, agent_config.patterns) or
            matches_any(name, agent_config.patterns) then
            return agent_name
         end
      end
   end

   -- Fallback: check pane title
   local title_success, pane_title = pcall(function()
      return pane:get_title()
   end)

   if title_success and pane_title then
      for agent_name, agent_config in pairs(config.agents) do
         if matches_any(pane_title, agent_config.patterns) then
            return agent_name
         end
      end
   end

   return nil
end

--- Detect agent status from pane content
---@param pane userdata
---@return string
local function detect_status(pane)
   -- Try to get pane text
   local success, text = pcall(function()
      return pane:get_lines_as_text(config.max_lines)
   end)

   if not success or not text or text == '' then
      -- Try logical lines as fallback
      success, text = pcall(function()
         return pane:get_logical_lines_as_text(config.max_lines)
      end)
   end

   if not success or not text or text == '' then
      return 'inactive'
   end

   local clean_text = strip_ansi(text)

   -- Priority 1: Check last 5 lines for idle (prompt ready)
   local last_lines = get_last_lines(clean_text, 5)
   for line in last_lines:gmatch('[^\n]+') do
      local trimmed = line:match('^%s*(.-)%s*$') or ''
      -- Check for ">" prompt (Claude/OpenCode)
      if trimmed == '>' or trimmed:match('^>%s') then
         return 'idle'
      end
      if matches_any(trimmed, config.status_patterns.idle) then
         return 'idle'
      end
   end

   -- Priority 2: Check last 30 lines for waiting (needs input)
   local recent_text = get_last_lines(clean_text, 30)
   if matches_any(recent_text, config.status_patterns.waiting) then
      return 'waiting'
   end

   -- Priority 3: Check last 10 lines for working (actively processing)
   local very_recent = get_last_lines(clean_text, 10)
   if matches_any(very_recent, config.status_patterns.working) then
      return 'working'
   end

   -- Default to idle if agent is detected but no specific status found
   return 'idle'
end

--- Update agent state for a pane
---@param pane userdata
---@return table|nil
function M.update_pane(pane)
   local pane_id = pane:pane_id()
   local agent_type = detect_agent(pane)

   if not agent_type then
      state.agent_states[pane_id] = nil
      return nil
   end

   local status = detect_status(pane)
   local agent_state = {
      agent_type = agent_type,
      status = status,
      last_update = os.time() * 1000,
   }

   state.agent_states[pane_id] = agent_state
   return agent_state
end

--- Get agent state for a pane
---@param pane_id number
---@return table|nil
function M.get_agent_state(pane_id)
   return state.agent_states[pane_id]
end

--- Get all agent states
---@return table
function M.get_all_agent_states()
   return state.agent_states
end

--- Count agents by status
---@return table
function M.count_agents_by_status()
   local counts = { working = 0, waiting = 0, idle = 0, inactive = 0 }
   for _, agent_state in pairs(state.agent_states) do
      local s = agent_state.status or 'inactive'
      counts[s] = (counts[s] or 0) + 1
   end
   return counts
end

--- Configure the module
---@param opts table
function M.setup(opts)
   if opts then
      if opts.agents then
         config.agents = opts.agents
      end
      if opts.status_patterns then
         config.status_patterns = opts.status_patterns
      end
      if opts.max_lines then
         config.max_lines = opts.max_lines
      end
      if opts.debug then
         config.debug = opts.debug
      end
   end
end

--- Debug: Get last lines from a pane (for troubleshooting)
---@param pane userdata
---@param n number
---@return string
function M.debug_get_pane_text(pane, n)
   local success, text = pcall(function()
      return pane:get_lines_as_text(n or 20)
   end)
   if success and text then
      return strip_ansi(text)
   end
   return ''
end

return M
