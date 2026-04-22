# SSH 配置说明

## SSH 保活设置

为了防止 SSH 连接因长时间无操作而断开，已在 `~/.ssh/config` 中配置了全局保活参数：

```ssh-config
# 全局 SSH 保活设置
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes
```

### 参数说明

- **ServerAliveInterval 60**  
  每 60 秒向服务器发送一次保活包，保持连接活跃

- **ServerAliveCountMax 3**  
  如果连续 3 次保活包没有收到响应，则断开连接  
  总超时时间 = 60秒 × 3 = 180秒（3分钟）

- **TCPKeepAlive yes**  
  启用 TCP 层面的保活机制，提供额外的连接保持

### 配置位置

SSH 配置文件位于：`~/.ssh/config`

这些设置对所有 SSH 连接生效，包括：
- WezTerm 中的 SSH 连接
- 命令行中的 `ssh` 命令
- 其他使用 SSH 的工具

### 当前配置的主机

```ssh-config
Host dev_108
  HostName 172.31.169.108
  User root
  Port 2222

Host dev_108_2404
  HostName 172.31.169.108
  User root
  Port 2232

Host dev_108_2404_3
  HostName 172.31.169.108
  User root
  Port 2234
```

### 使用方式

在 WezTerm 中直接使用配置的主机名连接：

```bash
ssh dev_108
ssh dev_108_2404
ssh dev_108_2404_3
```
