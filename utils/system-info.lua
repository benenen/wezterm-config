-- System Information Module for WezTerm
-- Collects CPU, memory, and hostname information

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

--- Get CPU usage percentage
---@return string CPU percentage (e.g., "3.2%") or empty string
function M.get_cpu_usage()
   local output = exec_command('top -l 1 | grep "CPU usage"')
   if not output then
      return ''
   end

   -- Parse: "CPU usage: 11.62% user, 17.44% sys, 70.93% idle"
   -- Extract user and sys percentages
   local user = output:match('(%d+%.%d+)%% user')
   local sys = output:match('(%d+%.%d+)%% sys')

   if not user or not sys then
      return ''
   end

   local total = tonumber(user) + tonumber(sys)
   return string.format('%.1f%%', total)
end

--- Get memory usage percentage
---@return string Memory percentage (e.g., "45%") or empty string
function M.get_memory_usage()
   local output = exec_command('top -l 1 | grep "PhysMem"')
   if not output then
      return ''
   end

   -- Parse: "PhysMem: 15G used (2647M wired, 4261M compressor), 277M unused."
   -- Extract used and unused
   local used_str, used_unit = output:match('(%d+[%.%d]*)([GMK]) used')
   local unused_str, unused_unit = output:match('(%d+[%.%d]*)([GMK]) unused')

   if not used_str or not unused_str then
      return ''
   end

   -- Convert to MB
   local function to_mb(value, unit)
      local num = tonumber(value)
      if unit == 'G' then
         return num * 1024
      elseif unit == 'K' then
         return num / 1024
      else
         return num
      end
   end

   local used_mb = to_mb(used_str, used_unit)
   local unused_mb = to_mb(unused_str, unused_unit)
   local total_mb = used_mb + unused_mb

   if total_mb == 0 then
      return ''
   end

   local percentage = (used_mb / total_mb) * 100
   return string.format('%d%%', math.floor(percentage))
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

-- Cache for system information
local cache = {
   cpu = '',
   memory = '',
   hostname = '',
   last_update = 0,
}

local CACHE_TTL = 2000 -- Cache for 2 seconds (in milliseconds)

--- Get all system information with caching
---@return string cpu_usage
---@return string memory_usage
---@return string hostname
function M.system_info()
   local now = os.time() * 1000

   -- Return cached values if still fresh
   if now - cache.last_update < CACHE_TTL then
      return cache.cpu, cache.memory, cache.hostname
   end

   -- Update cache
   cache.cpu = M.get_cpu_usage()
   cache.memory = M.get_memory_usage()
   cache.hostname = M.get_hostname()
   cache.last_update = now

   return cache.cpu, cache.memory, cache.hostname
end

return M
