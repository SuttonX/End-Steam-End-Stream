## End Steam End Stream v1.0.0

Initial public release.

Automatically ends Moonlight/Artemis streaming sessions and closes the leftover Steam desktop window when exiting Steam Big Picture through its Power menu, without terminating Steam itself.

### Features
- Ends the streaming session when Steam Big Picture exits.
- Closes the leftover Steam desktop window while keeping Steam running in the system tray.
- One-click Windows installer with setup instructions.
- Installs to `%LOCALAPPDATA%\ESES`.
- Diagnostic logging and optional Big Picture startup movie override.

### Installation
Download and run `EndSteamEndStream.bat` on your Windows host, then follow the generated instructions to configure the Steam Big Picture application in Apollo or Sunshine.

Tested with Apollo + Artemis. Standalone Sunshine and standard Moonlight have not been independently tested.

See the [README](https://github.com/SuttonX/End-Steam-End-Stream#readme) for details.
