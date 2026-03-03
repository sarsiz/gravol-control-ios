# GraVol Control

Tilt-based system volume control for iPhone, with quick launch via Shortcut/Back Tap.

## Features

- Tilt toward you: volume up
- Tilt away: volume down
- Animated volume dial (shows current volume and change speed)
- Large one-thumb controls: up/down, presets, sensitivity, step size
- Quick actions:
  - Open Shortcuts app
  - In-app guide to add Shortcuts widget on Home Screen

## iOS Constraints (Important)

- Lock-screen finger drawing is not available to third-party apps.
- Back Tap cannot be read directly by app code.
- Practical flow:
  1. Back Tap runs a Shortcut
  2. Shortcut opens this app
  3. Tilt control runs while app is active

## Security and Secret Safety

This repository is configured to avoid committing common secret files:

- `.env`, `.env.*`
- `*.pem`, `*.p12`, provisioning files
- `Secrets.plist`, `GoogleService-Info.plist`
- common credentials JSON patterns

Before every push, run:

```bash
rg -n "(api[_-]?key|secret|token|password|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|AKIA[0-9A-Z]{16})" . --hidden --glob '!.git/**'
```

If this finds anything sensitive, remove it from git history before pushing.

## Build and Run

1. Open `/Users/sarsiz/Desktop/Code Projects/iOS app/GraVol Control/GraVolControl.xcodeproj` in Xcode.
2. Set your signing team and unique bundle id.
3. Build and run on a real iPhone.

## Back Tap Setup

1. Open Shortcuts:
   - Create shortcut: `Start GraVol`
   - Add action: `Open App` -> `GraVol Control`
2. iPhone Settings:
   - `Accessibility` -> `Touch` -> `Back Tap`
   - Choose `Double Tap` or `Triple Tap`
   - Assign `Start GraVol`

## Home Screen Widget Setup (Shortcuts Widget)

1. Long-press Home Screen -> tap `+`
2. Add `Shortcuts` widget
3. Edit widget and choose `Start GraVol`

This gives one-tap launch from Home Screen.
