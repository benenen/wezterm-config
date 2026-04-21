# tmux 配置 README

这份说明面向一个很实用的目标: `tmux` 里能顺畅上下滚动，底部状态栏也别太土。

文档里的配置偏向:

- 鼠标滚轮可直接翻历史
- 复制模式使用 `vim` 风格按键
- 底部 bar 简洁、清晰、稍微有一点配色
- 左侧 bar 显示 `git` 图标和当前 branch 名
- 适配当前机器上的 `tmux 3.5a`

另外仓库里也放了一份带注释的示例配置，可以直接看:

- [tmux/.tmux.conf](~/.config/wezterm/tmux/.tmux.conf)

## 推荐配置

把下面内容放进 `~/.tmux.conf`:

```tmux
# tmux example config
# 目标:
# 1. 能直接上下滚动历史
# 2. 复制模式接近 vim 手感
# 3. 底部状态栏比默认更清爽
# 4. 不依赖插件, 开箱即用

##### Terminal / colors ######################################################

# 告诉 tmux 终端能力, 避免颜色显示异常.
set -g default-terminal "tmux-256color"

# 对常见终端补充 truecolor 支持.
set -ga terminal-overrides ",xterm-256color:Tc"

##### Scrolling / copy mode ##################################################

# 开启鼠标支持:
# - 可以直接滚轮上下翻历史
# - 可以点击切 pane / window
# - 在复制模式里也能用鼠标选择
set -g mouse on

# 把历史缓冲调大一点, 免得日志刷没了.
set -g history-limit 50000

# 复制模式使用 vim 风格按键.
setw -g mode-keys vi

# 进入复制模式后:
# - v 开始选择
# - y 复制并退出
# - 鼠标拖选后不会立刻复制
# - 右键复制并退出
# - Escape 取消
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi MouseDragEnd1Pane send -X stop-selection
bind -T copy-mode-vi MouseDown3Pane send -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi Escape send -X cancel

# macOS 下把选中内容直接送进系统剪贴板.
bind -T copy-mode-vi Y send -X copy-pipe-and-cancel "pbcopy"

##### Window / pane behavior #################################################

# 窗口和 pane 从 1 开始编号, 更符合直觉.
set -g base-index 1
setw -g pane-base-index 1

# 关闭某个 window 后自动重排编号.
set -g renumber-windows on

# 最后一个 window 被关掉时不要直接把 session 踢掉.
set -g detach-on-destroy off

##### Status bar #############################################################

# 状态栏放在底部.
set -g status-position bottom

# 每 5 秒刷新一次右侧时间等信息.
set -g status-interval 5

# window 列表靠左排列.
set -g status-justify left

# 整体配色:
# - 深色底
# - 淡色字
set -g status-style "bg=#1f2335,fg=#c0caf5"

# 命令提示和复制模式高亮用更亮的颜色, 方便区分状态.
set -g message-style "bg=#7aa2f7,fg=#1f2335"
set -g mode-style "bg=#bb9af7,fg=#1f2335"

# 预留左右内容长度, 避免信息被截断得太快.
set -g status-left-length 24
set -g status-right-length 80

# 左边显示 session 名.
set -g status-left '#[fg=#1f2335,bg=#7aa2f7,bold] #S  #[fg=#7aa2f7,bg=#24283b]#[fg=#c0caf5,bg=#24283b] #{b:pane_current_path} #[default]'

# 普通 window 样式.
set -g window-status-format "#[fg=#7aa2f7] #I:#W "

# 当前 window 更亮, 一眼能看出来.
set -g window-status-current-format "#[fg=#1f2335,bg=#9ece6a,bold] #I:#W #[default]"

# 右边显示主机名、日期、时间.
set -g status-right "#[fg=#bb9af7]#h #[fg=#565f89]| #[fg=#e0af68]%Z #[fg=#7dcfff]%Y-%m-%d #[fg=#e0af68]%H:%M "

##### Handy binds ############################################################

# 分屏时继承当前 pane 的工作目录.
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# 快速重载配置.
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"

##### Notes ##################################################################

# 常用操作:
# - Ctrl-a [   进入滚动 / 复制模式
# - 滚轮        直接翻历史
# - Ctrl-a |   左右分屏
# - Ctrl-a -   上下分屏
# - Ctrl-a r   重载配置
```

## 这份配置解决了什么

### 1. 上下滚动

`tmux` 默认不是普通终端的滚动逻辑。要滚历史内容，常见有两种方式:

- 直接用鼠标滚轮: `set -g mouse on`
- 进入复制模式再滚: 默认是 `prefix` + `[`

如果你更习惯 `vim`:

- `prefix` + `[` 进入滚动 / 复制模式
- `j` / `k` 上下移动
- `Ctrl-u` / `Ctrl-d` 半页滚动
- `g` 跳到顶部
- `G` 跳到底部
- `v` 开始选择
- `y` 复制并退出
- `Y` 复制到 macOS 系统剪贴板

### 2. 底部状态栏

这版 bar 走的是简洁路线:

- 左侧显示当前 session 名
- 如果当前 pane 在 git 仓库里，session 后面会追加一个 ` branch-name` 胶囊块
- 中间显示 window 列表
- 右侧显示主机名、日期、时间
- 当前 window 用更亮的块状高亮

如果你只想要“比默认好看一点”，这套已经够用了，而且不依赖插件。

这次 git 信息的风格是:

- `session` 保留原来的蓝色块
- `git` 分支用单独的蓝色深底块
- 只显示图标和 branch 名，不额外塞脏状态标记

为了避免你输入命令时 git 段闪烁，README 里的方案不再把 `git` 命令直接写进 `status-left`，而是:

- 状态栏只读取 `@git_branch`
- 后台脚本在切 pane、切 window、新建 pane 时更新这个值
- 重载配置时也会立即刷新一次

如果你想在同一个 pane 里执行完 `git checkout` 后也自动更新，最稳的是再配一层 shell hook:

- `zsh` 的 `precmd` 在每条命令执行完后刷新一次
- `zsh` 的 `chpwd` 在切目录后刷新一次

这样既不会闪，又能在日常输入命令时自动跟上分支变化。

## 安装 / 重载

首次使用:

```sh
mkdir -p ~/.config/tmux
${EDITOR:-vim} ~/.tmux.conf
tmux source-file ~/.tmux.conf
```

如果你已经在 `tmux` 里:

```sh
tmux source-file ~/.tmux.conf
```

或者直接按上面配置里的快捷键:

```text
prefix + r
```

## 常用快捷键建议

这份 README 默认把前缀键改成了 `Ctrl-a`:

- `Ctrl-a c`: 新建 window
- `Ctrl-a ,`: 重命名 window
- `Ctrl-a |`: 左右分屏
- `Ctrl-a -`: 上下分屏
- `Ctrl-a [`: 进入滚动 / 复制模式
- `Ctrl-a d`: 暂时离开当前 session

如果你不想改前缀键，把下面三行删掉就行:

```tmux
unbind C-b
set -g prefix C-a
bind C-a send-prefix
```

## 可选美化

如果你还想继续折腾，可以往下加:

- `tmux-resurrect`: 保存 / 恢复 session
- `tmux-continuum`: 自动保存
- `catppuccin/tmux`: 更完整的主题

但建议先把基础滚动和状态栏配好，再决定要不要上插件，不然维护成本会上去。

## 和 WezTerm 搭配时的建议

你现在主要在用 `wezterm`，和 `tmux` 叠在一起时建议注意两点:

- 滚动历史优先交给 `tmux`，这样远程机器里也一致
- 如果 `wezterm` 和 `tmux` 都抢相似快捷键，优先保留你最常用的那一层

通常比较稳的组合是:

- `wezterm` 负责标签页、窗口、字体、背景
- `tmux` 负责 session、pane、远程开发、历史滚动

## 后续可以怎么扩展

如果你下一步想直接落地，我建议按这个顺序:

1. 先把上面的配置放进 `~/.tmux.conf`
2. 确认滚轮和 `prefix + [` 的滚动手感
3. 再微调状态栏颜色和左右信息

如果你愿意，我下一步可以直接帮你把这份 README 对应的 `~/.tmux.conf` 也写出来。
