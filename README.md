# Claude Sessions

A DankMaterialShell plugin for people running several Claude Code sessions at once: when a session finishes its turn, post a DMS notification — clicking it jumps straight back to that terminal window.

同时开好几个 Claude Code 会话时，光靠提示音分不清是哪一个跑完了。这个插件把「哪个会话结束了」显示在通知里，点一下就跳回对应的终端。

> 个人自用插件，由 AI 辅助开发。使用前请读 [DISCLAIMER.md](DISCLAIMER.md)。

<img src="claude-pixel.png" width="96" alt="通知头像">

## 原理

Claude Code 自己会把状态写进终端标题：

| 标题 | 含义 |
|---|---|
| `◑ 项目名` | 正在干活 |
| `✳ 项目名` | 空闲，等你输入 |

插件每 2 秒读一次 `kitten @ ls`，找出前台进程是 `claude` 的 pane，观察 `◑ → ✳` 的跳变。跳变即「这一轮结束」，于是发通知。

点击通知时跑 `focus-pane.sh`，分三步 —— 单靠任何一步都不够：

1. `qs ipc call notifications close`：关掉 DMS 通知中心。那个弹层是 `keyboard interactivity: exclusive` 的，它开着的时候 niri 的 `focused-window` 是 `null`，任何聚焦请求都会被静默忽略。
2. `kitten @ focus-window --match id:<pane>`：切 kitty 内部的焦点。它同时会请求合成器抬起窗口，但 niri 把它当「抢焦点」处理 —— 用户最后一次输入落在别的表面（比如刚点的通知）时会被拒绝，而命令照样返回 0。
3. `niri msg action focus-window --id <niri 窗口 id>`：用标题把 kitty pane 映射到 niri 窗口（`app_id == "kitty"`，标题去掉状态字形后比对），直接让合成器聚焦。合成器 IPC 不受抢焦点限制。

点击动作之后，插件还会对这条通知发一次 `CloseNotification`（id 由 `notify-send -p` 提供）。DMS 的弹窗动作按钮本身只负责收起弹窗；Quickshell 在动作被 invoke 时会顺带关掉非 `resident` 的通知，所以通常 DMS 自己就会把条目移走。这一步是兜底，保证条目不会留在通知中心的等候区。历史记录不受影响——通知到达时已经单独记过一份。

**Claude Code 侧不需要任何配置**：没有 hook，不动 `settings.json`。

## 依赖

- `kitty`，且 `~/.config/kitty/kitty.conf` 里有 `allow_remote_control yes`
- `notify-send`（libnotify ≥ 0.8，需要 `-A` 和 `-w`）
- `niri` 与 `python3`（第三步用；没有 niri 时跳过，退回只做第二步）
- DankMaterialShell（在 v1.6.3 上测试）

## 安装

目录名必须是 `claudeSessions` —— 插件内部按这个路径找头像和脚本。

直接克隆进插件目录：

```bash
git clone https://github.com/Atom462/dms-claude-sessions.git \
  ~/.config/DankMaterialShell/plugins/claudeSessions
```

或者克隆到别处再软链接：

```bash
git clone https://github.com/Atom462/dms-claude-sessions.git ~/projects/dms-claude-sessions
ln -s ~/projects/dms-claude-sessions ~/.config/DankMaterialShell/plugins/claudeSessions
```

启用：

```bash
qs ipc call plugins enable claudeSessions
```

或者在 DMS 设置 → 插件里打开。改完代码后重载：

```bash
qs ipc call plugins reload claudeSessions
```

## 卸载

```bash
qs ipc call plugins disable claudeSessions
rm -rf ~/.config/DankMaterialShell/plugins/claudeSessions
```

## 排查

插件把每个事件都写进 `~/.cache/claudeSessions.log`：

```
2026-10-22 20:22:24  finished pane=14 name=Claude 常用插件配置
2026-10-22 20:22:24  action=[default] id=140 pane=14
2026-10-22 20:22:24  close id=140 exit=0
2026-10-22 20:22:24  pane 14 -> niri 56 rc=0 title=[✳ Claude 常用插件配置]
2026-10-22 20:22:24  focus pane=14 exit=0
```

`action=[default]` 说明点击传回来了；`pane X -> niri Y rc=0` 说明找到了对应的合成器窗口。

## 已知限制

- 只能看到 kitty 里的会话。别的终端（foot、alacritty…）看不到 —— kitty 的远程控制是唯一能拿到 pane 标题和 id 的途径。
- 机器上开了多个 kitty 实例时，只认第一个（`pgrep -x kitty | head -n1`）。
- 依赖 Claude Code 的标题约定（`✳` / `◑`）。哪天上游改了字形，改 `idleGlyph` 即可。
- 通知比真实结束晚最多 2 秒（轮询间隔）。
- 第三步靠标题匹配 niri 窗口。两个会话标题完全相同（比如两个同名项目）时，会跳到先找到的那个。
- 非 niri 的合成器用不了第三步，只能退回 kitty 自己的聚焦请求 —— 可能被合成器当成抢焦点拒掉。

## 测试环境

- Arch Linux
- niri 26.04
- kitty 0.49.2
- DankMaterialShell v1.6.3
- Quickshell 0.3.2
