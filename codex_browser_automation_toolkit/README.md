# Codex 浏览器自动化工具包

这是一套面向 Windows 的 Codex 浏览器自动化工具包，用于让 Codex 通过浏览器 MCP 接管 Chrome 或 Edge。

这套内容覆盖两种常见场景：

- 启动专用自动化浏览器窗口
- 通过 Chrome AutoConnect 连接真实已登录的 Chrome 会话

如果目标是操作已经登录的网站，优先使用 Chrome AutoConnect。

## 目录说明

- `README.md`
  安装说明、使用方式、验证结论和常见边界说明。
- `scripts/install_codex_browser_automation.ps1`
  全局安装脚本。负责写入 Codex 配置并安装浏览器启动器。
- `scripts/start_codex_browser.ps1`
  浏览器启动脚本。用于启动专用自动化 Chrome 或 Edge 窗口。
- `docs/VALIDATION.md`
  验证流程、常见故障和排查建议。

## 获取方式

这套内容可以通过任意一种方式分发：

- 直接从仓库下载 `codex_browser_automation_toolkit/` 目录
- 打包成 zip 后再分发

无论使用哪种方式，拿到文件之后都还需要在本机执行一次安装脚本，安装才会真正写入当前用户的 Codex 全局配置。

## 安装步骤

在 `codex_browser_automation_toolkit` 目录中执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect
```

执行完成后：

1. 如果 Codex 已经打开，先重启 Codex。
2. 正常打开 Chrome。
3. 访问 `chrome://inspect/#remote-debugging`。
4. 打开 `Allow remote debugging for this browser instance`。
5. 如果页面或浏览器出现提示，按要求启用 target discovery 并完成授权。
6. 之后即可让 Codex 通过浏览器 MCP 操作当前这套真实 Chrome 会话。

如果拿到的是 zip 压缩包，先解压，再进入解压后的 `codex_browser_automation_toolkit` 目录执行同样的命令。

## 推荐使用方式：让 Codex 带领完成安装

如果希望尽量减少手动操作，推荐把 `codex_browser_automation_toolkit` 目录放到桌面，再把下面这段提示词发给 Codex。

使用时只需要把路径改成本机实际路径：

```text
本机已经有浏览器自动化工具包，路径是：
C:\Users\当前用户名\Desktop\codex_browser_automation_toolkit

请先阅读这个目录里的 README.md 和 docs\VALIDATION.md，
然后一步一步带领完成安装、Chrome 设置和验证。

如需执行命令，请先说明用途，再直接执行。
目标是让 Codex 能接管这台机器真实已登录的 Chrome。
```

如果工具包不在桌面，也可以把上面的路径替换成下载目录、项目目录或任何本机实际路径。

## 全局安装位置

在 Windows 上，安装脚本会把内容写入这些位置：

- `%LOCALAPPDATA%\CodexBrowserAutomation`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Chrome.cmd`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Edge.cmd`
- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\AGENTS.md`

如果采用真实已登录 Chrome 模式，Codex 配置里会写入类似下面这一段：

```toml
[mcp_servers.chrome-devtools]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--autoConnect"]
```

## 已验证结果

在 2026 年 3 月 11 日，这条链路已经在真实 Windows 环境中完成验证：

1. 已执行 `install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect`
2. 已在 Chrome 的 `chrome://inspect/#remote-debugging` 中启用远程调试发现能力
3. `npx chrome-devtools-mcp@latest --autoConnect` 已验证可以成功连接
4. Codex 已成功连接真实 Chrome，会打开新的真实 Chrome 窗口并访问 `https://www.google.com/ncr`
5. Codex 已成功进入 `https://app.mokahr.com/`，并在登录后页面完成站内点击跳转验证

这说明：

- Codex 可以接管真实已登录的 Chrome
- Codex 可以在登录后网站中继续执行点击、跳转和读取页面内容
- 这已经足够证明浏览器自动化链路可用，不需要先编写具体业务脚本才能验证能力

## 两种 Chrome 模式的区别

### 1. 专用自动化窗口模式

通过仓库里的启动脚本拉起一个专用自动化浏览器窗口。

特点：

- 稳定
- 适合专门的自动化环境
- 不是日常正在使用的真实登录会话

### 2. Chrome AutoConnect 模式

直接连接已经在运行中的真实 Chrome 会话。

特点：

- 保留真实登录态
- 适合验证登录后站点
- 适合在真实浏览器里完成轻量自动化操作

如果目标是“让 Codex 操作已登录网站”，应优先使用 AutoConnect。

## 需要避免的错误路径

当目标是“真实已登录 Chrome”时，不要使用下面这些路径：

- 使用带 isolated context 的 `new_page`
- 使用 `--browser-url=http://127.0.0.1:9222` 去连接专用调试浏览器
- 试图通过 remote debugging 参数直接调起默认真实 Chrome profile

这些做法很容易进入隔离出来的自动化浏览器实例，常见表现是：浏览器虽然能打开，但登录态不对，或者打开的并不是预期中的真实窗口。

## 适合怎样分享

推荐把这套内容作为一个完整目录共享，而不是只单独发某一个脚本。

推荐保留以下结构：

- `README.md` 负责安装说明和入口说明
- `scripts/` 放安装与启动脚本
- `docs/` 放验证与排障说明

这样更适合长期维护，也更方便他人在不同机器上重复安装和验证。
