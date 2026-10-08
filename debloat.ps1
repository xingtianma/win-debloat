

<# 
    Run in PowerShell as Administrator:
      irm https://raw.githubusercontent.com/xingtianma/win-debloat/main/debloat.ps1 | iex
 
    Meant to run after every Windows update
    Log files are saved to C:\ProgramData\win-debloat
#>
 
& {
    $ErrorActionPreference = 'Stop'
 
    # ================= SETTINGS =================
    $CreateRestorePoint = $true   # create safe point to go back to if borked 
    $DisableGameDVR     = $true   # background clip recording; set $false if you use Game Bar clips

    $AppsToRemove = @(
        'Microsoft.BingNews'                        # Microsoft News
        'Microsoft.BingWeather'                     # Weather
        'Microsoft.BingSearch'                      # Bing Search
        'Microsoft.GetHelp'                         # Get Help
        'Microsoft.Getstarted'                      # Tips
        'Microsoft.MicrosoftOfficeHub'              # Microsoft 365 hub
        'Microsoft.MicrosoftSolitaireCollection'    # Solitaire
        'Microsoft.PowerAutomateDesktop'            # Power Automate
        'Microsoft.WindowsFeedbackHub'              # Feedback Hub
        'Microsoft.WindowsMaps'                     # Maps
        'Clipchamp.Clipchamp'                       # Clipchamp
        'Microsoft.Windows.DevHome'                 # Dev Home
        'MicrosoftCorporationII.MicrosoftFamily'    # Family
        'MicrosoftCorporationII.QuickAssist'        # Quick Assist
        '7EE7776C.LinkedInforWindows'               # LinkedIn
        'Microsoft.Copilot'                         # Copilot
        'MSTeams'                                   # Teams (personal)
        'Microsoft.OutlookForWindows'               # New Outlook
        'Microsoft.YourPhone'                       # Phone Link
        'Microsoft.Todos'                           # To Do
        'Microsoft.MicrosoftStickyNotes'            # Sticky Notes
        'Microsoft.Office.OneNote'                  # OneNote
        'Microsoft.WindowsAlarms'                   # Clock / Alarms
        'Microsoft.WindowsSoundRecorder'            # Sound Recorder
        'Microsoft.GamingApp'                       # Xbox app
        'Microsoft.XboxGamingOverlay'               # Game Bar
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.Xbox.TCUI'
        '*SpotifyMusic*'
        '*Disney*'
        '*PrimeVideo*'
        '*Netflix*'
        '*TikTok*'
        '*Instagram*'
        '*Facebook*'
        '*CandyCrush*'
        '*BubbleWitch*'
        '*McAfee*'
    )
 
    # ================= HELPERS =================
    function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
    function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
    function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
 
    # Runs one section; if it fails, logs the error and moves on to the next section.
    function Invoke-Step($Name, [scriptblock]$Action) {
        Write-Step $Name
        try { & $Action }
        catch { Write-Warn "Failed: $($_.Exception.Message)" }
    }
 
    # Creates the registry key if needed, then sets the value.
    function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
 
    # ================= ADMIN CHECK =================
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Please run PowerShell as Administrator, then try again.' -ForegroundColor Red
        return
    }
 
    # ================= LOGGING =================
    $logDir  = Join-Path $env:ProgramData 'win-debloat'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logFile = Join-Path $logDir ('log-{0:yyyy-MM-dd_HH-mm-ss}.txt' -f (Get-Date))
    Start-Transcript -Path $logFile | Out-Null
 
    try {
        # ---------- Restore point ----------
        if ($CreateRestorePoint) {
            Invoke-Step 'Creating a System Restore point' {
                Enable-ComputerRestore -Drive "$env:SystemDrive\"
                # Windows normally allows only one restore point per 24 hours; lift that limit
                Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
                Checkpoint-Computer -Description 'Before win-debloat' -RestorePointType 'MODIFY_SETTINGS'
                Write-Ok 'Restore point created.'
            }
        }
 
        # ---------- Bloat apps ----------
        Invoke-Step 'Removing preinstalled apps' {
            $allProvisioned = Get-AppxProvisionedPackage -Online
            foreach ($app in $AppsToRemove) {
                $installed   = Get-AppxPackage -AllUsers -Name $app
                $provisioned = $allProvisioned | Where-Object DisplayName -like $app
                if (-not $installed -and -not $provisioned) { continue }
                try {
                    $installed   | Remove-AppxPackage -AllUsers
                    $provisioned | Remove-AppxProvisionedPackage -Online | Out-Null
                    Write-Ok "Removed $app"
                }
                catch {
                    Write-Warn "Could not remove ${app}: $($_.Exception.Message)"
                }
            }
        }
 
        # ---------- Stop apps coming back ----------
        Invoke-Step 'Stopping Windows from auto-installing suggested apps' {
            $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            foreach ($name in 'SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled',
                              'OemPreInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled') {
                Set-Reg $cdm $name 0
            }
            Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
            Write-Ok 'Done.'
        }
 
        # ---------- Power plan ----------
        Invoke-Step 'Setting the Ultimate Performance power plan' {
            $line = powercfg /list | Select-String 'Ultimate Performance' | Select-Object -First 1
            if (-not $line) {
                $line = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
            }
            $guid = [regex]::Match("$line", '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}').Value
            if ($guid) {
                powercfg /setactive $guid
                if ($LASTEXITCODE -ne 0) { throw 'powercfg could not activate the plan.' }
                Write-Ok 'Ultimate Performance is active.'
            }
            else {
                powercfg /setactive SCHEME_MIN
                if ($LASTEXITCODE -ne 0) { throw 'powercfg could not activate High Performance.' }
                Write-Ok 'Ultimate Performance unavailable; using High Performance instead.'
            }
        }
 
        # ---------- Gaming settings ----------
        Invoke-Step 'Applying gaming settings' {
            Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
            Write-Ok 'Game Mode on. Hardware-accelerated GPU scheduling on (needs a restart).'
            if ($DisableGameDVR) {
                Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
                Write-Ok 'Background game recording off.'
            }
        }
 
        # ---------- Telemetry ----------
        Invoke-Step 'Reducing telemetry' {
            foreach ($svc in 'DiagTrack', 'dmwappushservice') {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Disabled
                    Write-Ok "Disabled $svc"
                }
            }
            Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
        }
 
        Write-Host "`nAll done. Log saved to $logFile" -ForegroundColor Green
        Write-Host 'Restart your PC to apply everything.' -ForegroundColor Green
    }
    finally {
        Stop-Transcript | Out-Null
    }
}
 
