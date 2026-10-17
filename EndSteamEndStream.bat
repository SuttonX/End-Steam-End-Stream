@echo off
setlocal
set "SS_INSTALLER=%~f0"
set "SS_PAYLOAD=%TEMP%\SteamBigPicture-Setup-%RANDOM%-%RANDOM%.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SS_INSTALLER);$m=[regex]::Match($s,'(?m)^::PS_PAYLOAD_START\r?\n');if(-not $m.Success){throw 'Payload not found'};[IO.File]::WriteAllText($env:SS_PAYLOAD,$s.Substring($m.Index+$m.Length),(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 goto :failed
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%SS_PAYLOAD%"
set "SS_EXIT=%ERRORLEVEL%"
del /q "%SS_PAYLOAD%" >nul 2>&1
if "%SS_EXIT%"=="20" (
    echo.
    echo Startup movie restoration is complete.
    echo No launcher installation or Apollo setup was performed.
    echo To install the launcher, run this BAT file again.
    echo.
    pause
    exit /b 0
)
if not "%SS_EXIT%"=="0" goto :failed
exit /b 0
:failed
echo.
echo Installation failed. Review the error above.
pause
exit /b 1
::PS_PAYLOAD_START
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Ask([string]$message) {
    $answer = [System.Windows.Forms.MessageBox]::Show($message, 'Steam Big Picture - Setup',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Find-Steam {
    $paths = @()
    $running = Get-Process steam -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running -and $running.Path) { $paths += $running.Path }
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        $reg = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($reg) {
            foreach ($prop in @('SteamExe','SteamPath','InstallPath')) {
                $v = $reg.$prop
                if ($v) {
                    if ($v -match '(?i)steam\.exe$') { $paths += $v }
                    else { $paths += (Join-Path $v 'steam.exe') }
                }
            }
        }
    }
    if (${env:ProgramFiles(x86)}) { $paths += (Join-Path ${env:ProgramFiles(x86)} 'Steam\steam.exe') }
    if ($env:ProgramFiles) { $paths += (Join-Path $env:ProgramFiles 'Steam\steam.exe') }
    foreach ($candidate in $paths) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    return $null
}

function Restart-SteamSilent([string]$steamExe) {
    if (-not $steamExe) { return }
    $running = [bool](Get-Process steam -ErrorAction SilentlyContinue)
    if ($running) {
        Write-Host 'Closing Steam to apply the startup movie change...'
        # Ask Steam to close normally; never force-close an active game.
        Start-Process -FilePath $steamExe -ArgumentList '-shutdown'
        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Process steam -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 300
        }
        if (Get-Process steam -ErrorAction SilentlyContinue) {
            [System.Windows.Forms.MessageBox]::Show('Steam did not exit within 45 seconds. The installer will not force-close it. Exit Steam normally and restart it to apply the movie change.', 'Steam Big Picture') | Out-Null
            return
        }
    }
    Write-Host 'Starting Steam silently...'
    Start-Process -FilePath $steamExe -ArgumentList '-silent' -WorkingDirectory (Split-Path -Parent $steamExe)
}

function Update-Movie([string]$action, [string]$movie) {
    # An admin retry is only requested if permissions actually prevent the operation.
    $work = {
        param($action, $movie)
        $ErrorActionPreference = 'Stop'
        if ($action -eq 'create') {
            if (Test-Path -LiteralPath $movie) { throw 'An override already exists; refusing to overwrite it.' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $movie) -Force | Out-Null
            [System.IO.File]::WriteAllBytes($movie, [byte[]]@())
            & attrib.exe +R $movie | Out-Null
        } else {
            if (-not (Test-Path -LiteralPath $movie)) { return }
            if ((Get-Item -LiteralPath $movie).Length -ne 0) { throw 'Refusing to delete a nonempty custom movie.' }
            & attrib.exe -R $movie | Out-Null
            # Compatibility with an older installer that denied deletion to this user.
            & icacls.exe $movie /remove:d "$env:USERNAME" 2>$null | Out-Null
            Remove-Item -LiteralPath $movie -Force -ErrorAction Stop
        }
    }
    try {
        & $work $action $movie
    } catch [System.UnauthorizedAccessException] {
        if (-not (Ask 'Steam requires administrator permission to change the movie override. Retry as administrator?')) { throw }
        $tmp = Join-Path $env:TEMP ('SteamMovieAdmin_' + [guid]::NewGuid().ToString('N') + '.ps1')
        $body = 'param($action,$movie)' + "`r`n" + $work.ToString() + "`r`n" + '& $work $action $movie'
        # Build a standalone script rather than rely on environment variables across elevation.
        $body = 'param($action,$movie)' + "`r`n" + '$work = {' + $work.ToString() + '}' + "`r`n" + '& $work $action $movie'
        [IO.File]::WriteAllText($tmp, $body, (New-Object Text.UTF8Encoding($false)))
        try {
            $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" "{1}" "{2}"' -f $tmp,$action,$movie
            $proc = Start-Process powershell.exe -ArgumentList $argLine -Verb RunAs -Wait -PassThru
            if ($proc.ExitCode -ne 0) { throw 'Administrator operation failed.' }
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

$installDir = Join-Path $env:LOCALAPPDATA 'Apollo'
$launcherPath = Join-Path $installDir 'SteamBigPicture.ps1'
$markerPath = Join-Path $installDir 'SteamBigPicture.MovieOverrideOwned'
$steamExe = Find-Steam
$changed = $false

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
if ($steamExe) {
    $movie = Join-Path (Split-Path -Parent $steamExe) 'config\uioverrides\movies\bigpicture_startup.webm'
    try {
        if (Test-Path -LiteralPath $movie) {
            $size = (Get-Item -LiteralPath $movie).Length
            if ($size -eq 0) {
                if (Ask 'A blank Steam Big Picture startup movie override exists. Remove it and restore the normal startup movie?') {
                    Update-Movie 'remove' $movie
                    Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
                    $changed = $true
                    # Restoration-only run: do not install the launcher or open Apollo.
                    Restart-SteamSilent $steamExe
                    Write-Host ''
                    Write-Host 'The blank startup movie override was removed.'
                    Write-Host 'No launcher installation or Apollo setup was performed.'
                    Write-Host 'Run this BAT again if you want to install the launcher.'
                    exit 20
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show('An existing custom Steam startup movie was found. It will not be modified.', 'Steam Big Picture') | Out-Null
            }
        } elseif (Ask 'Disable the Steam Big Picture startup movie by creating a blank override? Steam will be restarted automatically if it is running; save any active games first. You can run this installer again to remove the override.') {
            Update-Movie 'create' $movie
            [IO.File]::WriteAllText($markerPath, $movie, (New-Object Text.UTF8Encoding($false)))
            $changed = $true
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not change the Steam movie override:`r`n$($_.Exception.Message)`r`n`r`nNo launcher installation has been performed.", 'Installer warning') | Out-Null
        exit 1
    }
} else {
    [System.Windows.Forms.MessageBox]::Show('Steam installation was not detected. The optional movie override will be skipped; launcher installation will continue.', 'Installer notice') | Out-Null
}

if (Test-Path -LiteralPath $launcherPath) {
    Copy-Item -LiteralPath $launcherPath -Destination ($launcherPath + '.bak') -Force
}

$launcherText = @'
$gameBarKey = "HKCU:\Software\Microsoft\GameBar"
$valueName = "UseNexusForGameBarEnabled"
$originalValue = $null
$settingExisted = $false

try {
    $current = Get-ItemProperty -Path $gameBarKey -Name $valueName -ErrorAction SilentlyContinue
    if ($null -ne $current) {
        $settingExisted = $true
        $originalValue = $current.$valueName
    }

    New-Item -Path $gameBarKey -Force | Out-Null
    New-ItemProperty -Path $gameBarKey -Name $valueName -Value 0 -PropertyType DWord -Force | Out-Null

    Add-Type -Namespace Native -Name SteamClose -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
"@

    Start-Process "steam://open/bigpicture"

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 100
        $bigPicture = Get-Process steamwebhelper -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -eq "Steam Big Picture Mode" }
    } until ($bigPicture -or (Get-Date) -ge $deadline)

    if (-not $bigPicture) { throw "Steam Big Picture did not launch within 30 seconds." }

    # Prepare desktop Steam cleanup while Big Picture is still running.
    # Launching the helper cannot delay Apollo's disconnect at exit time.
    $cleanup = {
        $logPath = Join-Path (Join-Path $env:LOCALAPPDATA 'Apollo') 'SteamBigPicture-Cleanup.log'
        function Log-Cleanup([string]$message) {
            try {
                Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('{0:yyyy-MM-dd HH:mm:ss.fff} [PID {1}] {2}' -f (Get-Date), $PID, $message)
            } catch { }
        }
        try {
            # Start a fresh log for each cleanup-helper invocation.
            Set-Content -LiteralPath $logPath -Encoding UTF8 -Value ('Steam Big Picture cleanup diagnostic started {0:yyyy-MM-dd HH:mm:ss.fff}; PID {1}' -f (Get-Date), $PID)
            Log-Cleanup 'Helper launched; loading native WM_CLOSE API.'
            Add-Type -Namespace Native -Name SteamClose -MemberDefinition '[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);' -ErrorAction Stop
            Log-Cleanup 'WM_CLOSE API loaded; waiting for Big Picture window to disappear.'
            while (Get-Process steamwebhelper -ErrorAction SilentlyContinue |
                   Where-Object { $_.MainWindowTitle -eq 'Steam Big Picture Mode' }) {
                Start-Sleep -Milliseconds 100
            }
            Log-Cleanup 'Big Picture window disappeared; scanning for desktop Steam window.'
            $sawDesktopWindow = $false
            $attempts = 0
            $accepted = 0
            $lastWindowSignature = ''
            for ($i = 0; $i -lt 150; $i++) {
                $windows = @(Get-Process steamwebhelper -ErrorAction SilentlyContinue |
                    Where-Object { $_.MainWindowTitle -eq 'Steam' -and $_.MainWindowHandle -ne 0 })
                if ($windows.Count -gt 0) { $sawDesktopWindow = $true }
                $signature = ($windows | ForEach-Object { '{0}:{1}' -f $_.Id, $_.MainWindowHandle }) -join ','
                if ($signature -ne $lastWindowSignature) {
                    Log-Cleanup ('Desktop window state at check {0}: {1}' -f $i, $(if ($signature) { $signature } else { '(none)' }))
                    $lastWindowSignature = $signature
                }
                foreach ($window in $windows) {
                    $attempts++
                    $ok = [Native.SteamClose]::PostMessage($window.MainWindowHandle, 0x0010,
                        [IntPtr]::Zero, [IntPtr]::Zero)
                    if ($ok) { $accepted++ }
                    if ($attempts -le 3 -or ($attempts % 20) -eq 0 -or -not $ok) {
                        Log-Cleanup ('WM_CLOSE attempt {0}, PID {1}, handle {2}, accepted={3}, Win32Error={4}' -f $attempts, $window.Id, $window.MainWindowHandle, $ok, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
                    }
                }
                if ($sawDesktopWindow -and $windows.Count -eq 0) {
                    Log-Cleanup 'Desktop Steam window was seen and is now absent; ending watcher.'
                    break
                }
                Start-Sleep -Milliseconds 100
            }
            Log-Cleanup ('Helper finished. SawWindow={0}; Attempts={1}; Accepted={2}' -f $sawDesktopWindow, $attempts, $accepted)
        } catch {
            Log-Cleanup ('HELPER ERROR: ' + $_.Exception.ToString())
        }
    }.ToString()
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanup))
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-EncodedCommand', $encoded) | Out-Null

    # The main process exits as soon as Big Picture closes.
    while (Get-Process steamwebhelper -ErrorAction SilentlyContinue |
           Where-Object { $_.MainWindowTitle -eq "Steam Big Picture Mode" }) {
        Start-Sleep -Milliseconds 100
    }

}
catch { Write-Error $_ }
finally {
    if ($settingExisted) {
        New-ItemProperty -Path $gameBarKey -Name $valueName -Value $originalValue -PropertyType DWord -Force | Out-Null
    } else {
        Remove-ItemProperty -Path $gameBarKey -Name $valueName -ErrorAction SilentlyContinue
    }
}
'@
[IO.File]::WriteAllText($launcherPath, $launcherText, (New-Object Text.UTF8Encoding($false)))


$command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $launcherPath + '"'
Set-Clipboard -Value $command
$instructionsPath = Join-Path $env:TEMP 'SteamBigPicture-Apollo-Instructions.txt'
$instructions = @"
Steam Big Picture - Apollo Setup
================================

The Apollo Command has already been copied to your clipboard:

$command

1. Open https://localhost:47990 (if not already opened in your browser window).
2. Click Applications in the navigation bar at the top.
   Find Steam Big Picture and click Edit to open its settings.
3. In the Command field, replace the existing text with the command
   copied above (Ctrl+V). This field is below Emulated Gamepad Type.
4. Leave Run as Admin UNCHECKED, directly below the Command field.
5. Under Detached Commands, make sure NO commands are listed.
   If any exist, remove them; the Add Detached Command button can remain.
6. Under Command Preparations, make sure there are NO command rows.
   Each row has Do Command and Undo Command fields. Click the
   trash-can button at the right of each row to remove it entirely,
   even if its fields look empty.
7. Leave the streaming continuation checkboxes at their existing values.
   The launcher closes only Steam's windows, not the Steam client.
   Do not add an Undo Command or Command Preparations rows.
   Cleanup diagnostics are saved to:
   %LOCALAPPDATA%\Apollo\SteamBigPicture-Cleanup.log
8. Click the Save button (at the top or bottom of the page).

You do not need to change the other settings or checkboxes.

Installed Launcher: $launcherPath

The installed path includes your own Windows username automatically.
On another PC, the installer generates that PC's user-specific path.

Run this same BAT again to add or remove the optional blank Steam
startup movie override.

Close this Notepad window when finished.
"@
[IO.File]::WriteAllText($instructionsPath, $instructions, (New-Object Text.UTF8Encoding($false)))
try { Start-Process 'https://localhost:47990' } catch { }

if ($changed -and $steamExe) {
    Restart-SteamSilent $steamExe
}

# Open instructions last, after the browser and any Steam restart prompts.
$notepad = Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $instructionsPath + '"') -PassThru
Start-Sleep -Milliseconds 500
try {
    $shell = New-Object -ComObject WScript.Shell
    [void]$shell.AppActivate($notepad.Id)
} catch { }