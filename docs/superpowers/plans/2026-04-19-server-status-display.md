# 服务器状态显示实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 WezTerm 右侧状态栏显示服务器状态信息（CPU、内存、主机名）

**Architecture:** 创建独立的系统信息采集模块，通过 shell 命令获取 macOS 系统状态，集成到现有的 right-status 模块中使用 cell-based 渲染系统显示

**Tech Stack:** Lua, WezTerm API, macOS shell commands (top, hostname)

---

## 文件结构

**新建文件：**
- `utils/system-info.lua` - 系统信息采集模块，负责执行命令和解析输出

**修改文件：**
- `events/right-status.lua` - 集成系统信息显示到状态栏

---

### Task 1: 创建系统信息采集模块

**Files:**
- Create: `utils/system-info.lua`

- [ ] **Step 1: 创建模块骨架和 CPU 使用率获取函数**

```lua
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

return M
```

- [ ] **Step 2: 添加内存使用率获取函数**

```lua
--- Get memory usage percentage
---@return string Memory percentage (e.g., "45%") or empty string
function M.get_memory_usage()
   local output = exec_command('top -l 1 | grep "PhysMem"')
   if not output then
      return ''
   end
   
   -- Parse: "PhysMem: 15G used (2647M wired, 4261M compressor), 277M unused."
   -- Extract used and unused
   local used_str = output:match('(%d+[%.%d]*)([GMK]) used')
   local used_unit = output:match('%d+[%.%d]*([GMK]) used')
   local unused_str = output:match('(%d+[%.%d]*)([GMK]) unused')
   local unused_unit = output:match('%d+[%.%d]*([GMK]) unused')
   
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
```

- [ ] **Step 3: 添加主机名获取函数**

```lua
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
```

- [ ] **Step 4: 添加聚合函数**

```lua
--- Get all system information
---@return string cpu_usage
---@return string memory_usage
---@return string hostname
function M.system_info()
   local cpu = M.get_cpu_usage()
   local memory = M.get_memory_usage()
   local hostname = M.get_hostname()
   
   return cpu, memory, hostname
end
```

- [ ] **Step 5: 测试模块功能**

创建测试脚本 `test_system_info.lua`:

```lua
local system_info = require('utils.system-info')

print('Testing system-info module...')
print('---')

local cpu = system_info.get_cpu_usage()
print('CPU: [' .. cpu .. ']')

local memory = system_info.get_memory_usage()
print('Memory: [' .. memory .. ']')

local hostname = system_info.get_hostname()
print('Hostname: [' .. hostname .. ']')

print('---')
local cpu2, mem2, host2 = system_info.system_info()
print('All: CPU=[' .. cpu2 .. '] Memory=[' .. mem2 .. '] Hostname=[' .. host2 .. ']')
```

运行测试:
```bash
cd /Users/tangchuanyu/.config/wezterm
lua test_system_info.lua
```

预期输出类似:
```
Testing system-info module...
---
CPU: [15.3%]
Memory: [82%]
Hostname: [macbook-pro]
---
All: CPU=[15.3%] Memory=[82%] Hostname=[macbook-pro]
```

- [ ] **Step 6: 清理测试文件并提交**

```bash
rm test_system_info.lua
git add utils/system-info.lua
git commit -m "feat(utils): add system info collection module

Add module to collect CPU usage, memory usage, and hostname
via shell commands for macOS.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 集成系统信息到右侧状态栏

**Files:**
- Modify: `events/right-status.lua`

- [ ] **Step 1: 引入系统信息模块并添加颜色定义**

在 `events/right-status.lua` 文件顶部，在现有 require 语句后添加:

```lua
local system_info = require('utils.system-info')
```

在 colors 表中添加新颜色（第 62-70 行附近）:

```lua
---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   agent_working  = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_waiting  = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_idle     = { fg = '#89b4fa', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_inactive = { fg = '#6c7086', bg = 'rgba(0, 0, 0, 0.4)' },
   cpu            = { fg = '#94e2d5', bg = 'rgba(0, 0, 0, 0.4)' },
   memory         = { fg = '#cba6f7', bg = 'rgba(0, 0, 0, 0.4)' },
   date           = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery        = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   hostname       = { fg = '#f5c2e7', bg = 'rgba(0, 0, 0, 0.4)' },
   separator      = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' }
}
```

- [ ] **Step 2: 添加系统信息 cell 段定义**

在 cells 定义部分（第 74-88 行附近），在 `agent_separator` 之后添加:

```lua
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
   :add_segment('cpu_icon', '', colors.cpu)
   :add_segment('cpu_text', '', colors.cpu, attr(attr.intensity('Bold')))
   :add_segment('memory_icon', '', colors.memory)
   :add_segment('memory_text', '', colors.memory, attr(attr.intensity('Bold')))
   :add_segment('system_separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('hostname_separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('hostname_icon', '', colors.hostname)
   :add_segment('hostname_text', '', colors.hostname, attr(attr.intensity('Bold')))
```

- [ ] **Step 3: 添加系统信息格式化函数**

在 `agent_status_info()` 函数之后（第 140 行附近）添加:

```lua
---Get system information for display
---@return string cpu_icon
---@return string cpu_text
---@return string memory_icon
---@return string memory_text
---@return string hostname_icon
---@return string hostname_text
---@return boolean has_system_info
---@return boolean has_hostname
local function system_info_display()
   local cpu_usage, memory_usage, hostname = system_info.system_info()
   
   local cpu_icon = cpu_usage ~= '' and nf.md_cpu_64_bit .. ' ' or ''
   local cpu_text = cpu_usage ~= '' and cpu_usage .. ' ' or ''
   local memory_icon = memory_usage ~= '' and nf.md_memory .. ' ' or ''
   local memory_text = memory_usage ~= '' and memory_usage or ''
   local hostname_icon = hostname ~= '' and nf.md_server .. ' ' or ''
   local hostname_text = hostname ~= '' and hostname or ''
   
   local has_system_info = cpu_usage ~= '' or memory_usage ~= ''
   local has_hostname = hostname ~= ''
   
   return cpu_icon, cpu_text, memory_icon, memory_text, hostname_icon, hostname_text, has_system_info, has_hostname
end
```

- [ ] **Step 4: 在 update-status 事件中调用系统信息函数**

在 `M.setup` 函数的 `update-status` 事件处理器中（第 167 行附近），在 `battery_info()` 调用之后添加:

```lua
      local battery_text, battery_icon = battery_info()
      local working_icon, working_text, waiting_icon, waiting_text, idle_icon, idle_text, inactive_icon, inactive_text, has_agents = agent_status_info()
      local cpu_icon, cpu_text, memory_icon, memory_text, hostname_icon, hostname_text, has_system_info, has_hostname = system_info_display()
```

- [ ] **Step 5: 更新 cell 段文本**

在 cells 更新部分（第 169-180 行附近），在 `agent_inactive_text` 之后添加:

```lua
      cells
         :update_segment_text('agent_working_icon', working_icon)
         :update_segment_text('agent_working_text', working_text)
         :update_segment_text('agent_waiting_icon', waiting_icon)
         :update_segment_text('agent_waiting_text', waiting_text)
         :update_segment_text('agent_idle_icon', idle_icon)
         :update_segment_text('agent_idle_text', idle_text)
         :update_segment_text('agent_inactive_icon', inactive_icon)
         :update_segment_text('agent_inactive_text', inactive_text)
         :update_segment_text('cpu_icon', cpu_icon)
         :update_segment_text('cpu_text', cpu_text)
         :update_segment_text('memory_icon', memory_icon)
         :update_segment_text('memory_text', memory_text)
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)
         :update_segment_text('hostname_icon', hostname_icon)
         :update_segment_text('hostname_text', hostname_text)
```

- [ ] **Step 6: 更新段渲染顺序**

替换 segments 构建逻辑（第 182-197 行）:

```lua
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

      if has_system_info then
         table.insert(segments, 'cpu_icon')
         table.insert(segments, 'cpu_text')
         table.insert(segments, 'memory_icon')
         table.insert(segments, 'memory_text')
         table.insert(segments, 'system_separator')
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
```

- [ ] **Step 7: 测试配置重载**

重新加载 WezTerm 配置:
- 按 `Cmd+Shift+R` 或重启 WezTerm
- 检查右侧状态栏是否显示系统信息
- 验证显示顺序: Agent Status → CPU/Memory → Time → Battery → Hostname

预期结果:
- 看到 CPU 图标和百分比（如  15.3%）
- 看到内存图标和百分比（如  82%）
- 看到主机名（如  macbook-pro）
- 各段之间有分隔符

- [ ] **Step 8: 提交更改**

```bash
git add events/right-status.lua
git commit -m "feat(right-status): add system info display

Display CPU usage, memory usage, and hostname in right status bar.
System info appears between agent status and time, hostname appears
after battery.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 验证和测试

**Files:**
- Test: `events/right-status.lua`
- Test: `utils/system-info.lua`

- [ ] **Step 1: 测试正常显示**

观察 WezTerm 右侧状态栏:
- 确认 CPU、内存、主机名都正确显示
- 确认图标和文本颜色正确
- 确认分隔符位置正确

- [ ] **Step 2: 测试错误处理 - 模拟命令失败**

临时修改 `utils/system-info.lua` 中的命令为无效命令:

```lua
function M.get_cpu_usage()
   local output = exec_command('invalid_command_cpu')
   -- ... rest of function
end
```

重载配置，验证:
- CPU 段不显示
- 其他段正常显示
- 状态栏不崩溃

恢复代码后重新测试。

- [ ] **Step 3: 测试高负载显示**

运行一个 CPU 密集型任务:
```bash
yes > /dev/null &
```

观察状态栏:
- CPU 百分比应该上升
- 显示格式保持正确

停止任务:
```bash
killall yes
```

- [ ] **Step 4: 验证性能影响**

观察 WezTerm 性能:
- 状态栏更新是否流畅
- 是否有明显延迟
- CPU 使用率是否合理

- [ ] **Step 5: 最终验证**

确认所有功能正常:
- [ ] CPU 使用率显示正确
- [ ] 内存使用率显示正确
- [ ] 主机名显示正确
- [ ] 显示顺序符合设计
- [ ] 错误处理正常工作
- [ ] 性能影响可接受

---

## 完成检查清单

- [ ] `utils/system-info.lua` 已创建并提交
- [ ] `events/right-status.lua` 已修改并提交
- [ ] 所有功能测试通过
- [ ] 错误处理测试通过
- [ ] 性能验证通过
- [ ] 代码符合现有风格
- [ ] 提交信息清晰完整
