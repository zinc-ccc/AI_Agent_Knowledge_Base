# 验证说明

## 目标

验证 Codex 是否能够在 Windows 上接管真实已登录的 Chrome 会话，并继续操作登录后网站。

## 前提条件

在开始验证前，需要满足以下条件：

- 本机已经安装 Node.js，并且 `npx` 可用
- 已执行 `scripts/install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect`
- Chrome 是正常打开的真实浏览器，而不是专用自动化 profile
- 在 `chrome://inspect/#remote-debugging` 中已经启用当前浏览器实例的远程调试发现能力

## 推荐验证流程

1. 确认 `%USERPROFILE%\.codex\config.toml` 中使用的是 `--autoConnect`
2. 确认 `npx chrome-devtools-mcp@latest --autoConnect` 可以成功连接
3. 让真实 Chrome 自己打开一个新的真实窗口
4. 让 Codex 接管这个真实窗口
5. 先访问 `https://www.google.com/ncr` 进行轻量冒烟验证
6. 再访问真实目标站点
7. 登录完成后，执行一个无害的小操作，例如：
   - 打开列表页
   - 点击一个导航项
   - 读取一个仪表盘区域或表格区域

## 验证成功的信号

如果下面这些现象同时成立，基本可以判断链路已经打通：

- Codex 能列出真实 Chrome 的页面
- 页面保留了真实登录态
- 登录后站点中的点击和跳转可以正常完成
- Codex 能继续读取登录后页面内容

## 常见故障与判断方式

### 现象一：打开了一个新的未登录 Chrome

这通常意味着接管到的不是当前真实 Chrome，而是一个隔离出来的自动化浏览器实例。

优先检查：

- 是否误用了带 isolated context 的 `new_page`
- 是否误连到了 `9222` 专用调试浏览器
- 是否没有真正使用 `--autoConnect`

### 现象二：出现 DevToolsActivePort 或连接异常

这通常意味着 MCP 没有稳定附着在真实 Chrome 会话上。

优先检查：

- Chrome 当前实例是否已启用远程调试发现能力
- `chrome://inspect/#remote-debugging` 中的选项是否已经开启
- 操作路径中是否意外拉起了新的隔离自动化浏览器

### 现象三：网站能打开，但登录态丢失

这通常意味着当前连接到的是专用自动化 profile，而不是真实已登录会话。

优先检查：

- Codex 当前连接方式是否为 `--autoConnect`
- 当前浏览器是否是日常使用中的真实 Chrome
- 是否误用了 `--browser-url=http://127.0.0.1:9222`

## 推荐排查顺序

如果有人反馈“Codex 能开浏览器，但不能操作我已登录的网站”，建议按下面顺序排查：

1. 先确认是否真的使用了 AutoConnect
2. 再确认连接到的是不是用户真实 Chrome，而不是专用 profile
3. 再确认 Chrome 侧的 remote debugging discovery 是否已经开启
4. 最后再检查具体站点本身是否存在额外的人机验证、SSO 或页面权限限制

## 本次已完成的真实验证

2026 年 3 月 11 日，这套链路已经完成如下真实验证：

- 成功连接真实已登录 Chrome
- 成功访问 `https://www.google.com/ncr`
- 成功进入 `https://app.mokahr.com/`
- 登录后成功从仪表盘跳转到站内业务页面
- 成功读取登录后页面中的真实内容

这说明当前这套安装与接管方案不仅能启动浏览器，也能真正完成真实站点中的浏览器自动化操作。
