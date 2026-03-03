# GraVol Control

Glass-style, full-screen iOS volume controller with safer tilt detection and quick triggers.

## Features

- Tilt toward you: volume up
- Tilt away: volume down
- Full-window glass UI for iPhone 14 and newer
- Scrollable layout so no controls are cropped on smaller screens
- Animated volume dial (current volume + change speed)
- One-thumb controls: up/down, presets, recenter, trigger-angle dial, step
- Bottom-left info button with in-app usage guide
- Quick trigger setup from inside app:
  - Open Shortcuts directly
  - Trigger setup sheet (Shortcut, Home Screen widget, Action Button, Back Tap)

## iOS Constraints (Important)

- Lock-screen finger drawing is not available to third-party apps.
- Back Tap cannot be read directly by app code.
- Practical flow:
  1. Back Tap runs a Shortcut
  2. Shortcut opens this app
  3. Tilt control runs while app is active
  4. Action Button is supported only on models that have it (iPhone 15 Pro and newer)

## Motion Safety Improvements

- Recenter baseline to your natural hold position
- Sustained tilt requirement before changing volume
- Rotation-noise filtering to reduce accidental triggers
- Instant pause using top-right `Tilt Ready` toggle
- Bridge readiness status so you can confirm button-to-volume link is active

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
4. For best behavior, tap `Recenter` once after launch.

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

## Action Button Setup (if available)

1. Create `Start GraVol` shortcut (`Open App -> GraVol Control`).
2. Go to `Settings -> Action Button`.
3. Choose `Shortcut`, then select `Start GraVol`.
