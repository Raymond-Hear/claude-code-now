# Claude Code Now - Launch Claude Code instantly
# PowerShell script to launch Claude Code Now in current directory

# Error handling
$ErrorActionPreference = "Continue"
$LogDir = "$env:USERPROFILE\.claude-code-now-logs"
$LogFile = "$LogDir\claude-code-now-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Create log directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Log function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        Add-Content -Path $LogFile -Value "[$timestamp] [$Level] $Message" -ErrorAction SilentlyContinue
    } catch {}
}

# Show error dialog (visible even when launcher window is hidden)
function Show-Error {
    param([string]$Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "$Message`n`nLog file: $LogFile",
        "Claude Code Now",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

try {
    Write-Log "=== Claude Code Now Starting ==="
    Write-Log "Args: $($args -join ' ')"

    $LastDirFile = "$env:USERPROFILE\.claude-code-now-last-dir"

    # Determine target directory
    $FilteredArgs = @($args | Where-Object { $_ -ne "--debug" -and $_ -ne "-d" })

    if ($FilteredArgs.Count -gt 0) {
        $TargetDir = $FilteredArgs[0]
        Write-Log "Using arg directory: $TargetDir"
    } elseif (Test-Path $LastDirFile) {
        $TargetDir = Get-Content $LastDirFile
        Write-Log "Using last directory: $TargetDir"
    } else {
        $TargetDir = $env:USERPROFILE
        Write-Log "Using user home: $TargetDir"
    }

    # Check if directory exists
    if (-not (Test-Path $TargetDir -PathType Container)) {
        $msg = "Directory not found: $TargetDir"
        Write-Log $msg "ERROR"
        Show-Error $msg
        exit 1
    }

    # Find claude command
    $ClaudePath = $null
    $ClaudeCommand = Get-Command claude -ErrorAction SilentlyContinue
    if ($ClaudeCommand) {
        $ClaudePath = $ClaudeCommand.Source
        Write-Log "Found Claude via PATH: $ClaudePath"
    } else {
        Write-Log "Claude not in PATH, searching common locations..." "WARN"
        $PossiblePaths = @(
            "$env:APPDATA\npm\claude.cmd",
            "$env:ProgramFiles\nodejs\claude.cmd",
            "$env:LOCALAPPDATA\npm\claude.cmd"
        )
        foreach ($path in $PossiblePaths) {
            if (Test-Path $path) {
                $ClaudePath = $path
                Write-Log "Found Claude: $ClaudePath"
                break
            }
        }
    }

    if (-not $ClaudePath) {
        $msg = "Claude Code is not installed or not found in PATH.`n`nPlease run:`n  npm install -g @anthropic-ai/claude-code"
        Write-Log "Claude not found" "ERROR"
        Show-Error $msg
        exit 1
    }

    # Security check
    if ($ClaudePath -notmatch "claude(\.exe|\.cmd|\.ps1)?$") {
        $msg = "Security check failed: unexpected Claude path detected.`n`nPath: $ClaudePath"
        Write-Log $msg "ERROR"
        Show-Error $msg
        exit 1
    }

    Write-Log "Claude path: $ClaudePath"

    # Save current directory for next launch
    $TargetDir | Out-File -FilePath $LastDirFile -Encoding utf8

    # Launch Claude Code in a new dedicated window
    # Using Start-Process ensures the new window gets proper focus
    $escapedDir   = $TargetDir   -replace "'", "''"
    $escapedClaude = $ClaudePath -replace "'", "''"
    $launchCmd = "Set-Location '$escapedDir'; & '$escapedClaude' --permission-mode bypassPermissions; if (`$LASTEXITCODE -ne 0) { Write-Host ''; Write-Host 'Claude Code exited with code ' `$LASTEXITCODE -ForegroundColor Yellow; Read-Host 'Press Enter to close' }"

    Start-Process "powershell.exe" -ArgumentList @(
        "-NoExit", "-ExecutionPolicy", "Bypass", "-NoProfile", "-Command", $launchCmd
    ) -WindowStyle Normal

    Write-Log "Claude Code window launched"
    exit 0
}
catch {
    $msg = "Unexpected error: $($_.Exception.Message)"
    Write-Log "$msg`n$($_.ScriptStackTrace)" "ERROR"
    Show-Error $msg
    exit 1
}
