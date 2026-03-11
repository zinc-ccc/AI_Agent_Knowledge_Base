param(
    [ValidateSet("Chrome", "Edge")]
    [string]$Browser = "Edge",
    [int]$Port = 9222,
    [string]$ProfileRoot = "",
    [int]$StartupTimeoutSeconds = 60,

    # Chrome profile mode: Dedicated (default), Auto, or SignedIn
    # Auto and SignedIn require explicit non-default ChromeUserDataDir override
    [ValidateSet("Dedicated", "Auto", "SignedIn")]
    [string]$ChromeProfileMode = "Dedicated",

    # Optional explicit Chrome user-data and profile directory overrides
    [string]$ChromeUserDataDir = "",
    [string]$ChromeProfileDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BrowserExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $candidates = switch ($Name) {
        "Chrome" {
            @(
                "C:\Program Files\Google\Chrome\Application\chrome.exe",
                "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
                (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
            )
        }
        "Edge" {
            @(
                "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe")
            )
        }
        default {
            @()
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "$Name is not installed, or it is not in a standard install path."
}

function Test-DevToolsEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PortNumber
    )

    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:$PortNumber/json/version" -TimeoutSec 2
    }
    catch {
        return $null
    }
}

function Get-SignedInChromeProfile {
    $localStatePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Local State"
    if (-not (Test-Path -LiteralPath $localStatePath)) {
        return $null
    }

    try {
        $localState = Get-Content -LiteralPath $localStatePath -Raw | ConvertFrom-Json
        if ($localState.PSObject.Properties['profile'] -and
            $localState.profile.PSObject.Properties['info_cache']) {

            $candidates = @()
            foreach ($profileKey in $localState.profile.info_cache.PSObject.Properties.Name) {
                $profileInfo = $localState.profile.info_cache.$profileKey

                # Skip system profiles
                if (-not ($profileInfo.PSObject.Properties['name'])) {
                    continue
                }
                if ($profileInfo.name -eq 'System Profile' -or
                    $profileInfo.name -eq 'Default Profile' -or
                    $profileInfo.name -eq 'Guest Profile') {
                    continue
                }

                # Check for sign-in indicators (genuinely signed-in profiles have these)
                $signinScore = 0
                if ($profileInfo.PSObject.Properties['gaia_id'] -and $profileInfo.gaia_id) {
                    $signinScore += 4
                }
                if ($profileInfo.PSObject.Properties['user_name'] -and $profileInfo.user_name) {
                    $signinScore += 3
                }
                if ($profileInfo.PSObject.Properties['gaia_name'] -and $profileInfo.gaia_name) {
                    $signinScore += 2
                }
                if ($profileInfo.PSObject.Properties['gaia_given_name'] -and $profileInfo.gaia_given_name) {
                    $signinScore += 1
                }

                # Only consider profiles with at least one sign-in indicator
                if ($signinScore -gt 0) {
                    $candidates += @{
                        Key = $profileKey
                        Score = $signinScore
                        LastUsed = if ($profileInfo.PSObject.Properties['last_used']) { $profileInfo.last_used } else { 0 }
                        Name = $profileInfo.name
                    }
                }
            }

            if ($candidates.Count -gt 0) {
                # Sort by signinScore descending, then by last_used descending
                $best = $candidates | Sort-Object -Property @{Expression = 'Score'; Descending = $true }, @{Expression = 'LastUsed'; Descending = $true } | Select-Object -First 1
                return $best.Key
            }
        }
    }
    catch {
        return $null
    }

    return $null
}

function Test-ChromeRunning {
    $chromeProcesses = Get-Process -Name chrome -ErrorAction SilentlyContinue
    if ($chromeProcesses) {
        return $true
    }
    return $false
}

function Launch-Browser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string]$UserDataDir,
        [Parameter(Mandatory = $true)]
        [int]$PortNumber,
        [string]$ProfileDir = ""
    )

    $arguments = @(
        "--remote-debugging-port=$PortNumber",
        "--remote-debugging-address=127.0.0.1",
        "--user-data-dir=`"$UserDataDir`"",
        "--no-first-run",
        "--no-default-browser-check",
        "--new-window",
        "about:blank"
    )

    if ($ProfileDir) {
        $arguments += "--profile-directory=`"$ProfileDir`""
    }

    if ($Name -eq "Chrome") {
        $cmdLine = '/c start "" "{0}" {1}' -f $Executable, ($arguments -join ' ')
        Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdLine | Out-Null
        if ($ProfileDir) {
            Write-Host "Launched Chrome window with profile: $ProfileDir"
        } else {
            Write-Host "Launched dedicated Chrome window."
        }
        return
    }

    $process = Start-Process -FilePath $Executable -ArgumentList $arguments -PassThru
    Write-Host "Launched dedicated $Name window, PID=$($process.Id)"
}

if (-not $ProfileRoot) {
    $ProfileRoot = Join-Path $env:LOCALAPPDATA "CodexBrowserAutomation\profiles"
}

$existing = Test-DevToolsEndpoint -PortNumber $Port
if ($existing) {
    Write-Host "A debug browser is already running on 127.0.0.1:$Port."
    Write-Host "Current Browser: $($existing.Browser)"
    Write-Host "Close the current debug browser first if you want to switch browsers."
    exit 0
}

$browserExe = Get-BrowserExecutable -Name $Browser

if ($Browser -eq "Chrome") {
    $userDataDir = $null
    $profileDir = ""

    if ($ChromeUserDataDir) {
        # Explicit user-specified non-default Chrome profile path
        $userDataDir = $ChromeUserDataDir
        $profileDir = $ChromeProfileDir
    }
    elseif ($ChromeProfileMode -eq "Dedicated") {
        # Dedicated profile: stable default, uses browserUrl/9222
        $userDataDir = Join-Path $ProfileRoot "chrome"
    }
    elseif ($ChromeProfileMode -eq "SignedIn" -or $ChromeProfileMode -eq "Auto") {
        # SignedIn or Auto mode: Chrome 136+ blocks remote debugging on default user data dir
        # This is a security change - --remote-debugging-port no longer works on the default profile
        # Users should either:
        # 1. Use Dedicated mode with a fresh profile (browserUrl/9222)
        # 2. Use --autoConnect in the MCP config to attach to a live signed-in Chrome session
        Write-Host "ERROR: ChromeProfileMode $ChromeProfileMode is not supported for the default Chrome user data directory."
        Write-Host ""
        Write-Host "Chrome 136+ (including Chrome 145) blocks remote debugging on the default"
        Write-Host "user data directory (Google\Chrome\User Data) as a security measure."
        Write-Host ""
        Write-Host "SUPPORTED OPTIONS:"
        Write-Host ""
        Write-Host "1. Dedicated profile mode (recommended, stable):"
        Write-Host "   .\Start Codex Browser - Chrome.cmd -ChromeProfileMode Dedicated"
        Write-Host "   This creates a fresh profile specifically for Codex automation,"
        Write-Host "   and connects via browserUrl (http://127.0.0.1:9222)."
        Write-Host ""
        Write-Host "2. Live signed-in Chrome session with autoConnect (Chrome 144+ only):"
        Write-Host "   a. Reinstall with: .\install_codex_browser_automation.ps1 -ChromeMcpMode AutoConnect"
        Write-Host "   b. Open Chrome normally and go to chrome://inspect/#remote-debugging"
        Write-Host "   c. Enable 'Chrome' and 'Target discovery' options"
        Write-Host "   d. Approve the Chrome prompt when it appears"
        Write-Host "   e. Codex MCP will attach to your live session using --autoConnect"
        Write-Host ""
        Write-Host "3. Advanced: Explicit non-default profile override"
        Write-Host "   If you have a custom signed-in profile in a non-default location:"
        Write-Host "   .\Start Codex Browser - Chrome.cmd -ChromeUserDataDir `"C:\Path\To\Custom\User Data`" -ChromeProfileDir `"Profile 1`""
        Write-Host ""
        Write-Host "For more information, see: docs\CODEX_BROWSER_AUTOMATION_STANDARD.md"
        exit 1
    }
    else {
        # Should not reach here due to ValidateSet, but handle gracefully
        $userDataDir = Join-Path $ProfileRoot "chrome"
    }

    $null = New-Item -ItemType Directory -Force -Path $userDataDir

    Launch-Browser -Name $Browser -Executable $browserExe -UserDataDir $userDataDir -PortNumber $Port -ProfileDir $profileDir

    if ($profileDir) {
        Write-Host "Using signed-in profile: $profileDir"
        Write-Host "User data root: $userDataDir"
    }
    else {
        Write-Host "Dedicated profile: $userDataDir"
    }
}
else {
    # Edge always uses dedicated profile
    $profileDir = Join-Path $ProfileRoot "edge"
    $null = New-Item -ItemType Directory -Force -Path $profileDir

    Launch-Browser -Name $Browser -Executable $browserExe -UserDataDir $profileDir -PortNumber $Port
    Write-Host "Dedicated profile: $profileDir"
}

$expectedMarker = if ($Browser -eq 'Chrome') { 'Chrome/' } else { 'Edg/' }
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Milliseconds 500
    $status = Test-DevToolsEndpoint -PortNumber $Port
    if ($status) {
        if ($status.Browser -notlike "*$expectedMarker*") {
            throw "The detected debug browser is $($status.Browser), which does not match the requested $Browser."
        }

        Write-Host "DevTools is ready: $($status.Browser)"
        Write-Host "Codex can now attach through the browser MCP."
        exit 0
    }
} while ((Get-Date) -lt $deadline)

throw @"
$Browser started, but port $Port was not ready within ${StartupTimeoutSeconds} seconds.
Troubleshooting:
1. Close any other $Browser windows that are already using the same profile.
2. Make sure only one debug browser is using this port at a time.
3. For Chrome, keep the cmd.exe launch path used by this script instead of switching back to Start-Process.
4. Confirm local security software is not blocking --remote-debugging-port.
5. If using a signed-in Chrome profile, ensure no other Chrome processes are running.
"@
