# GraVol Control (SwiftUI Starter)

This starter implements:

- Tilt phone toward you to increase system volume
- Tilt phone away from you to decrease system volume
- `Start GraVol` App Intent for Shortcuts/Siri/Button triggers

## iOS Constraints

- Apps cannot directly detect Back Tap events.
- Use Back Tap to run a Shortcut that opens this app.
- Continuous lock-screen/background gyro monitoring is not supported for this use case.

## Project Setup

1. Create a new iOS SwiftUI app in Xcode.
2. Copy these folders into the app target:
   - `App`
   - `Features`
   - `Services`
   - `Intents`
3. Ensure all files are checked for your app target.
4. Build and run once to register app intents.

## Back Tap Setup

1. Open Shortcuts and create `Start GraVol` shortcut:
   - Action: `Open App` -> select your app
2. iPhone Settings:
   - `Accessibility` -> `Touch` -> `Back Tap`
   - Choose `Double Tap` or `Triple Tap`
   - Assign `Start GraVol` shortcut

When you back tap, iOS runs the shortcut and opens your app. Tilt control starts automatically when the app is active.

## Tuning

- `Tilt Sensitivity`: larger values require stronger tilt.
- `Volume Step`: how much each update changes volume.
