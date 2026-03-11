# Validation Guide

## Goal

Verify that Codex can control a real signed-in Chrome session on Windows
without replacing the user's existing browsing context.

## Preconditions

- Node.js and `npx` are available.
- `install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect` has run.
- The user opens Chrome normally, not via a dedicated automation profile.
- In Chrome, `chrome://inspect/#remote-debugging` has:
  - `Allow remote debugging for this browser instance`
  - target discovery enabled if prompted

## Quick validation sequence

1. Confirm the global Codex config uses `--autoConnect`.
2. Confirm `npx chrome-devtools-mcp@latest --autoConnect` can connect.
3. Let the real Chrome process open a new real window.
4. Have Codex attach to that real Chrome window.
5. Navigate to `https://www.google.com/ncr` for a low-risk smoke test.
6. Navigate to the real target site.
7. After login, perform one harmless site action such as:
   - open a list page
   - click a navigation item
   - read a table or dashboard section

## Expected success signals

- Codex can list the real Chrome pages.
- The page keeps the user's signed-in state.
- Navigation and click actions work on the authenticated site.
- Codex can read post-login page content.

## Common failure modes

### Symptom: a new unsigned Chrome appears

Likely cause:

- an isolated automation browser was created instead of attaching to the real
  session

Avoid:

- `new_page` with isolated context
- dedicated `9222` browser mode when the goal is live signed-in Chrome

### Symptom: DevToolsActivePort or connection errors

Likely causes:

- MCP lost attachment to the real Chrome session
- Chrome remote debugging discovery was not enabled for this browser instance
- the action path tried to create a separate automation browser unexpectedly

### Symptom: the site opens but is not logged in

Likely cause:

- Codex attached to a dedicated automation profile instead of the user's real
  browser session

## Recommended team message

If a teammate says "Codex can open Chrome but cannot operate my logged-in
site", first verify whether they are actually using AutoConnect against their
real Chrome session or accidentally using the dedicated profile path.
