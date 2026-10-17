# Exit Steam End Stream

**One script, two automatic actions:** When you exit Steam Big Picture through its **Power menu**, this script **ends your Moonlight/Artemis streaming session AND closes the leftover Steam desktop window on the Windows host**. Steam itself stays running in the system tray—no need to manually close the window or terminate Steam.

Made for **Apollo/Sunshine hosts** and **Artemis/Moonlight clients**. The installer configures a Steam Big Picture launcher for [Apollo](https://github.com/ClassicOldSong/Apollo), which is based on [Sunshine](https://github.com/LizardByte/Sunshine). Tested with **Apollo + Artemis**; standalone Sunshine and standard Moonlight have not been independently tested with these setup instructions.

## Quick start: Download and run the BAT

1. **[Download `ExitSteamEndStream.bat`](https://raw.githubusercontent.com/SuttonX/End-Steam-End-Stream/main/ExitSteamEndStream.bat)** and save it to your Windows host PC.
2. **Double-click the downloaded BAT file** and follow the installer prompts. There is nothing to extract and no separate PowerShell script to download.
3. Follow the Notepad instructions the installer opens to set up the **Steam Big Picture** application in Apollo. The installer also copies the application **Command** to your clipboard.
4. Make sure **both Apollo continuation checkboxes** are enabled as shown below. Save the application settings.
5. Connect through Artemis/Moonlight and launch the configured Steam Big Picture app. When you're done, use Big Picture's **Power menu to exit**: the stream ends and the leftover Steam desktop window closes automatically, while Steam remains running in the tray.

For the full configuration and troubleshooting details, see the sections below.

## Why use it?

When Steam Big Picture is launched through a game-streaming host, exiting Big Picture can leave Steam's regular desktop window open on the host PC, or leave the stream active longer than expected. This launcher handles **both** parts of the exit: it allows Apollo to end the streaming session and automatically closes Steam's desktop window. Steam continues running in the system tray.

### Features

- **One BAT file:** No separate PowerShell files to download or configure manually.
- **Two automatic actions on exit:** Ends the Artemis/Moonlight streaming session **and** closes the regular Steam desktop window after exiting Big Picture via its Power menu; **does not terminate the Steam client**.
- **Stream-friendly exit:** The launcher and cleanup helper run separately so the cleanup does not need to be placed in Apollo's Undo Command.
- **Controller Guide-button handling:** Temporarily disables Windows Game Bar's Xbox/Guide-button interception during the session, then restores the original setting afterward.
- **Optional startup movie override:** Offers to suppress the Big Picture startup movie with a blank override, and can restore the normal movie later.
- **Automatic Apollo setup instructions:** Copies the required launch command to the clipboard, opens Apollo's web interface, and displays step-by-step instructions in Notepad.
- **Diagnostic logging:** Records Steam window cleanup activity to a log that is replaced on each new session.

## Requirements

- Windows 10 or 11
- Steam installed on the host PC
- [Apollo](https://github.com/ClassicOldSong/Apollo) installed and configured as the streaming host (built on [Sunshine](https://github.com/LizardByte/Sunshine))
- An [Artemis](https://github.com/ClassicOldSong/moonlight-android) or [Moonlight](https://moonlight-stream.org/) streaming client (tested with Artemis)
- Windows PowerShell 5.1 (included with supported Windows installations)

> **Tested configuration:** Apollo + Artemis, with Steam already running on the host. **Sunshine + Moonlight** is part of the same streaming ecosystem, but standalone Sunshine and standard Moonlight have **not** been tested with this installer. Apollo-specific setup steps and paths may need adaptation for Sunshine.

## Installation

1. **[Download `ExitSteamEndStream.bat`](https://raw.githubusercontent.com/SuttonX/End-Steam-End-Stream/main/ExitSteamEndStream.bat)** to your Windows host PC.
2. **Double-click the BAT file to run it.** You can inspect the script before running it.
3. If prompted, choose whether to disable Steam's Big Picture startup movie. This is optional. **If you choose to change the movie, the installer may restart Steam**, so close any active games first.
4. The installer writes the launcher to:

   ```text
   %LOCALAPPDATA%\Apollo\SteamBigPicture.ps1
   ```

5. The installer copies the Apollo launch command to your clipboard, opens `https://localhost:47990`, and displays setup instructions in Notepad.
6. In Apollo, open **Applications**, then edit your **Steam Big Picture** application entry. Paste the copied text into its **Command** field.
7. Configure the Apollo application as shown below and **Save**.

### Important Apollo application settings

| Setting | Value |
| --- | --- |
| **Command** | Paste the command copied by the installer |
| **Run as Admin / Elevated** | **Unchecked** |
| **Detached Commands** | **Empty** |
| **Command Preparations** | **No rows** (remove even empty rows) |
| **Continue streaming if the application exits quickly** | **Checked** |
| **Continue streaming until all app processes exit** | **Checked** |
| **Undo Command** | **None** |

**Both continuation checkboxes are important.** Disabling them caused unreliable Steam window cleanup and stream-disconnect problems during testing. Do not add an extra close command to Apollo: the installed launcher already handles cleanup.

The generated Command will resemble this (the installer supplies your actual Windows profile path):

```powershell
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\YOUR_USER\AppData\Local\Apollo\SteamBigPicture.ps1"
```

## How it works

1. Apollo launches the installed PowerShell script.
2. The script temporarily changes the Windows Game Bar Guide-button setting and opens Steam Big Picture.
3. Once Big Picture appears, it starts an independent, hidden cleanup helper.
4. When Big Picture closes, the launcher finishes and restores the original Game Bar setting.
5. The helper looks for Steam's desktop window (`steamwebhelper.exe`, window title `Steam`) and sends a standard Windows `WM_CLOSE` message.
6. When the desktop window is confirmed absent, the helper exits. **Steam remains running in the system tray.**

The helper **does not send a second `steam://close/bigpicture` command** after Big Picture has already exited. This avoids the redundant command that caused problems in earlier versions.

## Optional: Disable or restore the startup movie

During installation, you can choose to create a blank file at Steam's Big Picture startup-movie override location. The installer checks for existing overrides and will not overwrite a nonempty custom movie.

To restore the default startup movie, **run the same BAT again**. If a blank override is detected, you'll be offered the option to remove it. A restoration run only restores the movie; run the installer again afterward if you also want to reinstall the launcher.

Changing the startup movie may restart Steam. The installer attempts to restart it silently in the tray.

## Troubleshooting

**Steam's desktop window remains open**

- Verify **both Apollo continuation checkboxes are checked**.
- Remove any Apollo **Undo Command**, **Detached Commands**, and **Command Preparations** rows associated with this launcher.
- Confirm Apollo's **Command** points to the generated `SteamBigPicture.ps1` file.
- Run another session and inspect the cleanup log:

  ```text
  %LOCALAPPDATA%\Apollo\SteamBigPicture-Cleanup.log
  ```

  To copy the last 200 lines to your clipboard, run this in PowerShell:

  ```powershell
  Get-Content "$env:LOCALAPPDATA\Apollo\SteamBigPicture-Cleanup.log" -Tail 200 | Set-Clipboard
  ```

**Artemis/Moonlight shows a disconnect error or the stream takes too long to end**

Check the two continuation settings above, ensure there are no extra Undo Commands, and avoid running the launcher elevated. The cleanup helper should run separately rather than as an Apollo Undo Command.

**Big Picture doesn't launch**

Make sure Steam is installed, running, and able to enter Big Picture normally. The launcher waits up to 30 seconds for the Big Picture window to appear.

**Log file size**

The cleanup log is **overwritten for each new session**, not appended indefinitely.

## Files created by the installer

| File | Purpose |
| --- | --- |
| `%LOCALAPPDATA%\Apollo\SteamBigPicture.ps1` | Installed streaming launcher |
| `%LOCALAPPDATA%\Apollo\SteamBigPicture.ps1.bak` | Backup of an existing launcher when reinstalling |
| `%LOCALAPPDATA%\Apollo\SteamBigPicture-Cleanup.log` | Per-session diagnostic log |
| `%TEMP%\SteamBigPicture-Apollo-Instructions.txt` | Apollo setup instructions |

If selected, the optional startup-movie override is created inside Steam's `config\uioverrides\movies` folder.

## Uninstall

1. In Apollo, remove this launcher's **Command** from the Steam Big Picture application entry, or restore your previous command.
2. Delete `%LOCALAPPDATA%\Apollo\SteamBigPicture.ps1` if you no longer need it. You can also remove its `.bak` and the diagnostic log.
3. If you enabled the optional startup-movie override, run the BAT file and choose to **restore** the original movie before deleting the installer.

The temporary Game Bar setting is designed to be restored when the launcher exits normally. If Windows or PowerShell is forcibly terminated, check the Game Bar setting manually if the Guide button behaves differently afterward.

## Notes

This is a community utility and is **not affiliated with Valve, Steam, Apollo, Sunshine, Artemis, or Moonlight**. It is provided as-is. Review scripts before executing them, especially if your Steam or Apollo installation is customized.

## Feedback and issues

If you encounter a reproducible issue, open a GitHub issue and include your Windows version, Apollo/Sunshine version, Artemis/Moonlight client version, relevant application settings, and the cleanup log (after reviewing it for any information you don't want to share).