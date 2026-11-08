# Windows build

- Godot 4.7.2 stable, official Windows x64 release template.
- The templates archive was verified against the official SHA512-SUMS.txt before extraction.
- Windows templates remain in `.export_tools/templates`; `export_presets.cfg` references them directly.
- Main scene: `res://main.tscn`.
- Export preset: `Windows Desktop`, release, embedded PCK, explicit selected resources.
- Backups, tests and build tools are excluded from the game.

Build:

```powershell
New-Item -ItemType Directory -Path dist -Force | Out-Null
# Replace the executable path with your local Godot console executable.
& 'C:\path\to\Godot_console.exe' --headless --path . --export-release 'Windows Desktop' 'dist/GTA6_Elektronika.exe'
```

Validation: standalone EXE resource loading without script errors, actual OpenGL rendering captured in `release_frame00000001.png`, ZIP extraction into an isolated temp directory outside the project, SHA256 match and successful standalone startup there. Gameplay/clock/pause/score/audio/catch tests were run against project sources. Official release templates ignore external `--script` overrides; those are not used as evidence of release gameplay tests.

EXE SHA256: `0A5E7AADCCBA9D537F19AF1D82EE08A98C6CE3F13495527CB3E145ED39E4490E`
