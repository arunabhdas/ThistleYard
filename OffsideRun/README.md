# Offside Run

Offside Run is a native iOS SpriteKit endless runner prototype inspired by the feel of classic lane-running mobile games, with original cozy fantasy characters, forest adventure mechanics, and hand-painted storybook styling.

## Gameplay

The app opens on a SwiftUI landing screen that explains the obstacles, controls, collectibles, and goal. Tap **Start Run** to play. The game-over screen offers **Back to menu** to return to it.

- Swipe left or right to switch lanes.
- Each obstacle shows a colored badge as it approaches telling you the one move that clears it:
  - **▲ JUMP** (orange): swipe up to jump over a log.
  - **▼ SLIDE** (blue): swipe down to slide under an arch.
  - **✕ SWING** (pink): tap to swing the scout blade at a maskling.
- The same legend sits at the bottom of the screen during a run.
- Collect crowns and four rune shards.
- Keep your hearts while the route speeds up.

Keyboard controls are included for the simulator:

- Left/right arrows or A/D: change lanes
- Up arrow/W/Space: jump
- Down arrow/S: slide
- J/K: strike

## Build

The quickest way is the setup script, which regenerates the project (if `xcodegen` is installed), builds for the iOS Simulator, and then asks whether to open it in Xcode:

```bash
cd OffsideRun
./setup.sh            # build, then prompt before opening Xcode
./setup.sh --open     # build and open Xcode without prompting
./setup.sh --no-open  # build only
./setup.sh --clean    # wipe Build/DerivedData first
```

Or do the steps by hand. Generate the Xcode project:

```bash
cd OffsideRun
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
