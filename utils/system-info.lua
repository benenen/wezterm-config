-- System Information Module for WezTerm
-- Collects hostname information

local M = {}

--- Execute shell command and return output
---@param cmd string
---@return string|nil
local function exec_command(cmd)
   local success, handle = pcall(io.popen, cmd)
   if not success or not handle then
      return nil
   end

   local result = handle:read('*a')
   handle:close()

   return result
end

--- Get hostname
---@return string Short hostname or empty string
function M.get_hostname()
   local output = exec_command('hostname -s')
   if not output then
      return ''
   end

   -- Trim whitespace
   local hostname = output:match('^%s*(.-)%s*$')
   return hostname or ''
end

-- Cache for hostname (rarely changes)
local hostname_cache = nil

--- Get hostname with caching
---@return string hostname
function M.system_info()
   if not hostname_cache then
      hostname_cache = M.get_hostname()
   end
   return hostname_cache
end

return M
