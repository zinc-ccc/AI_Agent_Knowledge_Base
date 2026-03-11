param(
    [string]$InstallRoot = "",
    [string]$CodexHome = "",
    [switch]$SkipCodexConfig,
    [switch]$SkipCodexAgents,
    [switch]$SkipDesktopShortcut,
    [switch]$SkipPrerequisiteCheck,

    # Chrome MCP connection mode: BrowserUrl (default) or AutoConnect
    # BrowserUrl: Uses http://127.0.0.1:9222 for dedicated profile (stable, Chrome 120+)
    # AutoConnect: Uses --autoConnect to attach to live signed-in Chrome session (Chrome 144+)
    [ValidateSet("BrowserUrl", "AutoConnect")]
    [string]$ChromeMcpMode = "BrowserUrl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Backup-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $Path -Destination "$Path.$timestamp.bak" -Force
    }
}

function Ensure-ParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        $null = New-Item -ItemType Directory -Force -Path $parent
    }
}

function Read-LinesAsArrayList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $buffer = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
            [void]$buffer.Add($line)
        }
    }

    return ,$buffer
}

function Set-Or-AppendSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Header,
        [Parameter(Mandatory = $true)]
        [string[]]$SectionLines
    )

    Ensure-ParentDirectory -Path $Path
    $lines = Read-LinesAsArrayList -Path $Path

    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (($lines[$i]).Trim() -eq $Header) {
            $start = $i
            break
        }
    }

    if ($start -ge 0) {
        $end = $lines.Count
        for ($j = $start + 1; $j -lt $lines.Count; $j++) {
            if (($lines[$j]) -match '^\s*\[.+\]\s*$') {
                $end = $j
                break
            }
        }

        for ($k = $end - 1; $k -ge $start; $k--) {
            $lines.RemoveAt($k)
        }
    }
    elseif ($lines.Count -gt 0 -and ($lines[$lines.Count - 1]).Trim() -ne "") {
        [void]$lines.Add("")
    }

    foreach ($sectionLine in $SectionLines) {
        [void]$lines.Add($sectionLine)
    }

    [System.IO.File]::WriteAllLines($Path, [string[]]$lines.ToArray())
}


function Test-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

if (-not $InstallRoot) {
    $InstallRoot = Join-Path $env:LOCALAPPDATA "CodexBrowserAutomation"
}

if (-not $CodexHome) {
    $CodexHome = Join-Path $env:USERPROFILE ".codex"
}


if (-not $SkipPrerequisiteCheck -and -not $SkipCodexConfig) {
    if (-not (Test-CommandAvailable -CommandName "npx")) {
        throw "npx was not found. Install Node.js LTS first, or rerun with -SkipCodexConfig if you only want the browser launchers."
    }
}

$null = New-Item -ItemType Directory -Force -Path $InstallRoot
$null = New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot "profiles\chrome")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot "profiles\edge")

$installedStartScript = Join-Path $InstallRoot "start_codex_browser.ps1"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "start_codex_browser.ps1") -Destination $installedStartScript -Force

$chromeCmdPath = Join-Path $InstallRoot "Start Codex Browser - Chrome.cmd"
$edgeCmdPath = Join-Path $InstallRoot "Start Codex Browser - Edge.cmd"
Set-Content -LiteralPath $chromeCmdPath -Value @(
    '@echo off',
    ('powershell -ExecutionPolicy Bypass -File "{0}" -Browser Chrome' -f $installedStartScript)
) -Encoding ASCII
Set-Content -LiteralPath $edgeCmdPath -Value @(
    '@echo off',
    ('powershell -ExecutionPolicy Bypass -File "{0}" -Browser Edge' -f $installedStartScript)
) -Encoding ASCII

if (-not $SkipDesktopShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ($desktop -and (Test-Path -LiteralPath $desktop)) {
        try {
            Copy-Item -LiteralPath $chromeCmdPath -Destination (Join-Path $desktop "Start Codex Browser - Chrome.cmd") -Force
            Copy-Item -LiteralPath $edgeCmdPath -Destination (Join-Path $desktop "Start Codex Browser - Edge.cmd") -Force
        }
        catch {
            Write-Warning "Desktop launcher copy failed, but the main installation completed. You can still run the .cmd files from the install directory."
        }
    }
}

if (-not $SkipCodexConfig) {
    $configPath = Join-Path $CodexHome "config.toml"
    Backup-IfExists -Path $configPath

    if ($ChromeMcpMode -eq "AutoConnect") {
        Set-Or-AppendSection -Path $configPath -Header "[mcp_servers.chrome-devtools]" -SectionLines @(
            "[mcp_servers.chrome-devtools]",
            'command = "cmd"',
            'args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--autoConnect"]',
            'env = { SystemRoot = "C:\\Windows", PROGRAMFILES = "C:\\Program Files" }',
            'startup_timeout_ms = 20000'
        )
    }
    else {
        # BrowserUrl mode (default)
        Set-Or-AppendSection -Path $configPath -Header "[mcp_servers.chrome-devtools]" -SectionLines @(
            "[mcp_servers.chrome-devtools]",
            'command = "cmd"',
            'args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"]',
            'env = { SystemRoot = "C:\\Windows", PROGRAMFILES = "C:\\Program Files" }',
            'startup_timeout_ms = 20000'
        )
    }
}

if (-not $SkipCodexAgents) {
    $agentsPath = Join-Path $CodexHome "AGENTS.md"
    $markerStart = "<!-- BEGIN CODEX_BROWSER_AUTOMATION_SOP -->"
    $markerEnd = "<!-- END CODEX_BROWSER_AUTOMATION_SOP -->"
    $sopBlock = @(
        '<!-- BEGIN CODEX_BROWSER_AUTOMATION_SOP -->',
        '# Browser Automation SOP',
        '',
        'When browser automation tools are available through MCP, treat them as the default way to operate Chrome and Edge for multi-step web tasks.',
        '',
        '## Operating policy',
        '- Use browser automation for navigation, clicking, form filling, tab management, playback control, and repeated UI workflows.',
        '- Stop and ask the user to take over for CAPTCHA, 2FA, QR login, payment confirmation, or any other human-verification checkpoint.',
        '- After the user says login or verification is complete, re-check the active page state before continuing.',
        '',
        '## Page-observation rule',
        'After any action that may open a new tab, popup, or page transition, do not immediately wait on or inspect the old page.',
        '',
        'Always follow this sequence:',
        '1. Call the page-listing tool.',
        '2. If a new relevant page exists, switch to it.',
        '3. Wait for the target element or page readiness on the correct page.',
        '4. Only then inspect the page or continue the next action.',
        '',
        'In short: action -> list pages -> switch if needed -> wait -> inspect.',
        '',
        '## Reliability checks',
        '- If a click seems to do nothing, inspect page list changes before assuming failure.',
        '- If the page still looks stale, check for modal dialogs, blocked popups, or partial navigation.',
        '- Prefer stable selectors and clear success checks for repeated workflows.',
        '',
        '## Collaboration boundary',
        '- Use automation to assist a human in the same browser session.',
        '- Do not present the workflow as bypassing site protections or impersonating a user beyond the user''s own instructed browser actions.',
        '<!-- END CODEX_BROWSER_AUTOMATION_SOP -->'
    )

    Backup-IfExists -Path $agentsPath
    Ensure-ParentDirectory -Path $agentsPath

    $existingLines = Read-LinesAsArrayList -Path $agentsPath
    $startIndex = -1
    $endIndex = -1
    for ($i = 0; $i -lt $existingLines.Count; $i++) {
        if (($existingLines[$i]).Trim() -eq $markerStart) {
            $startIndex = $i
        }
        if (($existingLines[$i]).Trim() -eq $markerEnd) {
            $endIndex = $i
            break
        }
    }

    if ($startIndex -ge 0 -and $endIndex -ge $startIndex) {
        for ($j = $endIndex; $j -ge $startIndex; $j--) {
            $existingLines.RemoveAt($j)
        }
    }
    elseif ($existingLines.Count -gt 0 -and ($existingLines[$existingLines.Count - 1]).Trim() -ne "") {
        [void]$existingLines.Add("")
    }

    foreach ($line in $sopBlock) {
        [void]$existingLines.Add($line)
    }

    [System.IO.File]::WriteAllLines($agentsPath, [string[]]$existingLines.ToArray())
}

Write-Host "Installation completed."
Write-Host "Install directory: $InstallRoot"
Write-Host "Launchers:"
Write-Host "- $chromeCmdPath"
Write-Host "- $edgeCmdPath"
Write-Host ""
Write-Host "Next steps:"
if ($ChromeMcpMode -eq "AutoConnect") {
    Write-Host "- Open Chrome normally and go to chrome://inspect/#remote-debugging"
    Write-Host "- Enable 'Chrome' and 'Target discovery' options"
    Write-Host "- Approve the Chrome prompt when it appears"
    Write-Host "- Codex MCP will attach to your live session using --autoConnect"
}
else {
    Write-Host "- Open a launcher (Chrome uses Dedicated mode by default)"
    Write-Host "- Sign in to your common websites in that dedicated browser window"
}









