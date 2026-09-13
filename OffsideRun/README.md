# Offside Run

Offside Run is a native iOS SpriteKit endless runner prototype inspired by the feel of classic lane-running mobile games, with original cozy fantasy characters, forest adventure mechanics, and hand-painted storybook styling.

## Gameplay

- Swipe left or right to switch lanes.
- Swipe up to jump over low obstacles.
- Swipe down to slide under arches.
- Tap to swing the scout blade at maskling enemies.
- Collect crowns and four rune shards.
- Keep your hearts while the route speeds up.

Keyboard controls are included for the simulator:

- Left/right arrows or A/D: change lanes
- Up arrow/W/Space: jump
- Down arrow/S: slide
- J/K: strike

## Build

Generate the Xcode project:

```bash
cd "/Users/coder/repos/offsideai/githubrepos_workspace_active_1/jsx-viewer/Offside Run"
xcodegen generate
```

Then open:

```bash
open OffsideRun.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project OffsideRun.xcodeproj -scheme OffsideRun -destination 'generic/platform=iOS Simulator' -derivedDataPath Build/DerivedData CODE_SIGNING_ALLOWED=NO build
```
