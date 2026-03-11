# Codex 浏览器自动化

这是一套可复用的 Windows 浏览器自动化安装包，用来让 Codex 具备浏览器 MCP 能力。

它重点支持两种使用方式：

- 专用自动化浏览器窗口
- Chrome AutoConnect 连接真实已登录 Chrome 会话

如果你的目标是“让 Codex 直接操作我平时已经登录的网站”，优先使用 Chrome AutoConnect。

## 包含内容

- `scripts/install_codex_browser_automation.ps1`
  全局安装脚本。负责写入 Codex 配置、安装浏览器启动器。
- `scripts/start_codex_browser.ps1`
  浏览器启动脚本。用于启动专用自动化 Chrome 或 Edge 窗口。
- `docs/VALIDATION.md`
  验证步骤和常见故障说明。

## 同事快速安装

同事拿到这套内容有两种常见方式：

- 直接从仓库下载 `codex_browser_automation/` 目录
- 直接收到一个打包好的 zip 压缩包

但要注意：

只拿到文件还不够，Codex 不会因为这些文件存在于磁盘上就自动完成全局安装。
对方仍然需要在自己的 Windows 电脑上手动执行一次安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect
```

执行完以后：

1. 如果 Codex 已经开着，先重启 Codex。
2. 正常打开 Chrome。
3. 访问 `chrome://inspect/#remote-debugging`。
4. 打开 `Allow remote debugging for this browser instance`。
5. 如果页面或浏览器弹出提示，按要求启用 target discovery 并确认授权。
6. 之后就可以让 Codex 用浏览器 MCP 去接管这套真实 Chrome 会话。

## 可以直接复制给同事的话术

你把 `codex_browser_automation/` 这个目录拿下来，然后在 Windows 里进入该目录，执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect
```

执行完后，重启 Codex，正常打开 Chrome，进入 `chrome://inspect/#remote-debugging`，打开 `Allow remote debugging for this browser instance`，按提示授权。之后就可以让 Codex 直接操作你真实已登录的 Chrome。

如果你拿到的是 zip 压缩包，先解压，再进入解压出来的 `codex_browser_automation` 目录执行同样的命令。

## 全局安装会写到哪里

在 Windows 上，这个安装脚本会把相关内容写到这些位置：

- `%LOCALAPPDATA%\CodexBrowserAutomation`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Chrome.cmd`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Edge.cmd`
- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\AGENTS.md`

如果使用真实已登录 Chrome，会在 Codex 配置里写入类似下面这一段：

```toml
[mcp_servers.chrome-devtools]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--autoConnect"]
```

## 已验证结果

在 2026 年 3 月 11 日，这条链路已经在真实 Windows 环境中完成验证：

1. 已执行 `install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect`
2. 已在 Chrome 的 `chrome://inspect/#remote-debugging` 中开启远程调试发现能力
3. `npx chrome-devtools-mcp@latest --autoConnect` 已验证可以连接
4. Codex 成功连接真实 Chrome，会打开新的真实 Chrome 窗口并访问 `https://www.google.com/ncr`
5. Codex 成功进入 `https://app.mokahr.com/`，并在登录后页面完成站内点击跳转验证

这说明：

- Codex 能接管真实已登录 Chrome
- Codex 能在登录后网站里继续自动化点击和导航
- 对同事来说，这已经足够证明“Codex 浏览器操作可用”，不需要先专门写一份业务自动化脚本

## 关键使用规则

这套方案里有两种不同的 Chrome 路径，不要混淆：

- Dedicated profile 模式
  通过脚本启动一个专用自动化浏览器，稳定，但不是你日常登录中的真实 Chrome
- AutoConnect 模式
  直接连接你已经在运行的真实 Chrome 会话，适合登录态站点验证和真实浏览器操作

如果目标是“让 Codex 操作真实已登录网站”，应优先使用 AutoConnect。

## 需要避免的错误路径

当目标是“真实已登录 Chrome”时，不要走这些路径：

- 使用带 isolated context 的 `new_page`
- 使用 `--browser-url=http://127.0.0.1:9222` 去连接专用调试浏览器
- 试图用 remote debugging 参数直接调起默认真实 Chrome profile

这些做法很容易把你带到一个隔离出来的自动化浏览器实例里，表现为：浏览器能打开，但登录态不对，或者和用户预期不是同一个窗口。

## 推荐分享方式

建议把这套内容作为知识库里的独立子目录共享，而不是拆成几篇零散文档。

这样脚本和说明会放在一起：

- README 负责安装说明和分享入口
- `scripts/` 放安装与启动脚本
- `docs/` 放验证和排障说明
