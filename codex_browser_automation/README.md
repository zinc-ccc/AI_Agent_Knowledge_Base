# Codex Browser Automation

This package captures a reusable Windows setup for Codex browser automation,
including Chrome AutoConnect support for attaching to a real signed-in Chrome
session.

## What this package contains

- `scripts/install_codex_browser_automation.ps1`
  Installs launchers and updates Codex global config.
- `scripts/start_codex_browser.ps1`
  Starts dedicated Chrome or Edge browser windows for stable automation use.
- `docs/VALIDATION.md`
  Team-facing validation steps and known pitfalls.

## Global install targets

When installed on Windows, the working setup is written to these locations:

- `%LOCALAPPDATA%\CodexBrowserAutomation`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Chrome.cmd`
- `%LOCALAPPDATA%\CodexBrowserAutomation\Start Codex Browser - Edge.cmd`
- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\AGENTS.md`

For a live signed-in Chrome session, the key config is:

```toml
[mcp_servers.chrome-devtools]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--autoConnect"]
```

## What was verified

On March 11, 2026, this flow was verified on a real Windows machine with a
real signed-in Chrome session:

1. `install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect` had
   already been applied.
2. Chrome remote debugging discovery was enabled at
   `chrome://inspect/#remote-debugging`.
3. `npx chrome-devtools-mcp@latest --autoConnect` connected successfully.
4. Codex connected to the real Chrome session, opened a fresh real Chrome
   window, and navigated to `https://www.google.com/ncr`.
5. Codex navigated to `https://app.mokahr.com/`, used the signed-in session,
   and successfully clicked from the dashboard into `候选人管理`.

That proves the key path:

- Codex can attach to a real signed-in Chrome session.
- Codex can operate real authenticated pages after login.
- This is enough for teammates to use Codex for browser operations without
  first building a business-specific automation script.

## Important operating rule

There are two different Chrome modes in this setup:

- Dedicated profile mode:
  a separate automation browser launched by the provided scripts.
- AutoConnect mode:
  attach to the user's already running real Chrome session.

For real signed-in validation, use AutoConnect and avoid creating isolated
automation contexts by mistake.

Do not use these paths when the goal is "real signed-in Chrome":

- `new_page` with an isolated browser context
- `--browser-url=http://127.0.0.1:9222`
- launching a new Chrome process against the default real profile with remote
  debugging flags

## Recommended sharing pattern

Use this package as a shareable subtree inside a knowledge-base repository so
that scripts and documentation stay grouped together instead of becoming more
top-level loose documents.
