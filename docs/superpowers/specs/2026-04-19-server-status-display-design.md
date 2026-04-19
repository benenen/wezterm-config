# WezTerm 右侧状态栏服务器状态显示设计

**日期**: 2026-04-19  
**状态**: 已批准

## 概述

在 WezTerm 右侧状态栏中添加服务器状态信息显示，包括 CPU 使用率、内存使用率和主机名。

## 需求

### 功能需求

1. 显示实时 CPU 使用率百分比
2. 显示实时内存使用率百分比
3. 显示主机名（短格式）
4. 每次状态栏更新时刷新数据（实时更新）

### 显示顺序

```
Agent Status → [CPU/Memory] → Time → Battery → Hostname
```

- CPU 和 Memory 显示在 agent status 和时间之间
- Hostname 显示在电池图标之后
- 使用紧凑图标格式：`  3.2%   45%`

### 错误处理

- 命令执行失败时返回空字符串
- 只有成功获取到数据时才显示对应的图标和文本
- CPU/Memory 都失败时不显示该段及其分隔符
- Hostname 失败时不显示 hostname 段及其前置分隔符

## 架构设计

### 组件结构

```
utils/system-info.lua          # 新增：系统信息采集模块
events/right-status.lua        # 修改：集成系统信息显示
```

### 系统信息模块 (`utils/system-info.lua`)

**职责**：
- 执行系统命令获取 CPU、内存、主机名信息
- 解析命令输出
- 返回格式化的数据或空字符串（失败时）

**接口**：

```lua
-- 获取 CPU 使用率
-- @return string CPU 百分比（如 "3.2%"）或空字符串
function M.get_cpu_usage()

-- 获取内存使用率
-- @return string 内存百分比（如 "45%"）或空字符串
function M.get_memory_usage()

-- 获取主机名
-- @return string 短主机名或空字符串
function M.get_hostname()

-- 获取所有系统信息
-- @return string cpu_usage
-- @return string memory_usage
-- @return string hostname
function M.system_info()
```

**实现细节**：

1. **CPU 使用率获取**
   - 命令：`top -l 1 | grep "CPU usage"`
   - 解析：提取用户态 + 系统态百分比
   - 格式：保留一位小数，如 "3.2%"

2. **内存使用率获取**
   - 命令：`top -l 1 | grep "PhysMem"`
   - 解析：计算已使用内存占总内存的百分比
   - 格式：整数百分比，如 "45%"

3. **主机名获取**
   - 命令：`hostname -s`
   - 格式：去除首尾空白字符

4. **错误处理**
   - 使用 `pcall` 包装 `io.popen` 调用
   - 命令执行失败或解析失败时返回空字符串
   - 不抛出异常，确保状态栏不崩溃

### Right Status 集成 (`events/right-status.lua`)

**修改内容**：

1. **引入系统信息模块**
   ```lua
   local system_info = require('utils.system-info')
   ```

2. **添加 Cell 段定义**
   - `cpu_icon`: CPU 图标（nf.md_cpu_64_bit 或类似）
   - `cpu_text`: CPU 百分比文本
   - `memory_icon`: 内存图标（nf.md_memory 或类似）
   - `memory_text`: 内存百分比文本
   - `system_separator`: CPU/Memory 段后的分隔符
   - `hostname_icon`: 主机名图标（nf.md_server 或类似）
   - `hostname_text`: 主机名文本
   - `hostname_separator`: hostname 前的分隔符

3. **添加颜色定义**
   ```lua
   cpu      = { fg = '#94e2d5', bg = 'rgba(0, 0, 0, 0.4)' },
   memory   = { fg = '#cba6f7', bg = 'rgba(0, 0, 0, 0.4)' },
   hostname = { fg = '#f5c2e7', bg = 'rgba(0, 0, 0, 0.4)' },
   ```

4. **在 update-status 事件中调用**
   ```lua
   local cpu_usage, memory_usage, hostname = system_info.system_info()
   ```

5. **条件渲染逻辑**
   ```lua
   local has_system_info = cpu_usage ~= '' or memory_usage ~= ''
   local has_hostname = hostname ~= ''
   
   -- 构建 segments 列表时根据标志决定是否插入
   ```

6. **段顺序**
   ```lua
   segments = {
      -- Agent status segments (if has_agents)
      'agent_working_icon', 'agent_working_text', ...
      'agent_separator',  -- if has_agents
      
      -- System info segments (if has_system_info)
      'cpu_icon', 'cpu_text',
      'memory_icon', 'memory_text',
      'system_separator',  -- if has_system_info
      
      -- Time
      'date_icon', 'date_text',
      'separator',
      
      -- Battery
      'battery_icon', 'battery_text',
      
      -- Hostname (if has_hostname)
      'hostname_separator',  -- if has_hostname
      'hostname_icon', 'hostname_text',
   }
   ```

## 数据流

```
update-status 事件触发
    ↓
调用 system_info.system_info()
    ↓
并行执行三个 shell 命令
    ├─ top -l 1 (CPU)
    ├─ top -l 1 (Memory)
    └─ hostname -s
    ↓
解析命令输出
    ↓
返回格式化字符串或空字符串
    ↓
更新 cell 段文本
    ↓
根据数据可用性构建 segments 列表
    ↓
渲染到状态栏
```

## 性能考虑

1. **命令执行开销**
   - `top -l 1` 执行时间约 100-200ms
   - 可以优化为单次 `top` 调用同时获取 CPU 和内存
   - `hostname -s` 执行时间约 10ms

2. **更新频率**
   - 跟随 WezTerm 的 `update-status` 事件（约 1 秒一次）
   - 不需要额外的缓存机制（用户选择实时更新）

3. **优化建议**
   - 合并 CPU 和内存的 `top` 调用为一次
   - hostname 可以缓存（很少变化），但为简单起见初期不实现

## 图标选择

使用 Nerd Fonts 图标：
- CPU: `nf.md_cpu_64_bit` 或 `nf.fa_microchip`
- Memory: `nf.md_memory` 或 `nf.fa_memory`
- Hostname: `nf.md_server` 或 `nf.fa_server`

## 测试场景

1. **正常情况**：所有命令成功执行，显示完整信息
2. **CPU 获取失败**：只显示内存和主机名
3. **内存获取失败**：只显示 CPU 和主机名
4. **CPU 和内存都失败**：只显示主机名（如果成功）
5. **所有命令失败**：不显示任何系统信息段
6. **高 CPU/内存使用率**：验证显示格式正确

## 兼容性

- **平台**：macOS (Darwin)
- **依赖**：`top`, `hostname` 命令（macOS 系统自带）
- **WezTerm 版本**：当前配置使用的版本

## 未来扩展

- 支持 Linux 平台（使用不同的命令）
- 添加配置选项控制显示哪些信息
- 添加颜色阈值（如 CPU > 80% 时变红）
- 缓存 hostname 以减少命令执行
