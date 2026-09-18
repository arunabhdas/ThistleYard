# OffsideGolf verification — 2026-09-18

## Implemented scope

M0–M11 now have a playable app implementation: nine JSON-authored holes, six clubs, 120 Hz deterministic simulation, wind and terrain, swept hazards/trees, precise putting, camera states, eight-facing golfer pose animation/customization, adaptive HUD and tutorial, audio/haptics, settings, versioned records and atomic local saves with explicit recovery. The original supplied mocks were reviewed before design. Original generated art and synthesized audio have provenance in `ArtSource`.

M12 and M13 have local polish/release preparation, with unsigned archives. They remain gated by physical-device performance and sensory/accessibility checks, final art review, signing and actual TestFlight validation. No 60 FPS, battery, resident-memory, minimum-device or store-acceptance claim follows from simulator tests.

## Environment

- Xcode 26.5 (17F42), Swift 6.3.2 compiler, Swift 6 language mode; deployment iOS/iPadOS 17.
- iPhone 17 Pro and iPad (A16), iOS 26.5 simulators.
- A paired iPhone 16 Pro Max was detected, but no signing identity or project Team ID is configured. It has not been installed or tested physically.
- The 2026-09-18 runs below used iPhone 17 Pro `1A96FECC-23A6-4A9F-95E3-A25599361DC9` and iPad (A16) `2A4CAB14-1BA6-415E-8BA7-4E2DDFC719D4`, both iOS 26.5.
- Baseline iPhone 12/iPad 9 and minimum-OS runtime verification remain outstanding.

## Verified results

| Check | Result | Local evidence |
|---|---|---|
| Final Release core suite | 66 tests passed; 31 actual-course playability scenarios | `/tmp/offsidegolf-final-core.log` |
| Real nine-hole iPhone UI round | Passed: 32 real-control shots, all nine results, scorecard, relaunch and retained personal best | `/tmp/OffsideGolf-full-round1.xcresult` (round test passed; an unrelated settings test in that bundle failed and was subsequently fixed) |
| Menu image regression | Passed after moving the native SwiftUI image into the asset catalog; actual rendered pixels inspected | `/tmp/OffsideGolf-menu-fix.xcresult` |
| Debug core suite | 71 tests passed, including five DEBUG-only command tests and the complete course search | `/tmp/offsidegolf-final-core-debug.log` |
| iPhone combined regression | 48 hosted tests + 8 UI tests passed | `/tmp/OffsideGolf-final-phone3.xcresult` |
| Additional iPhone gameplay flows | 2 UI tests passed: real river penalty/recovery and assisted nine-hole record exclusion | `/tmp/OffsideGolf-extra-flows.xcresult` |
| Final presentation checks, iPhone | 48 hosted tests + 5 gameplay UI tests passed | `/tmp/OffsideGolf-polish-phone.xcresult` |
| Real nine-hole iPad UI round | Passed: all nine results, 32-stroke scorecard and retained personal best | `/tmp/OffsideGolf-final-ipad.xcresult` (an earlier restart-dialog test failed in this bundle; the final run below verifies its fix) |
| Final presentation checks, iPad | 48 hosted tests + 6 gameplay UI tests passed, including the restart fix, water recovery and assisted round | `/tmp/OffsideGolf-polish-ipad.xcresult` |
| Directional-art hosted regression, iPhone (2026-09-18) | 55 hosted tests passed, 0 failed, 0 skipped; includes seven directional decode/cache/render tests | `/tmp/OffsideGolf-directional-platform.xcresult` |
| Directional-art focused UI, iPhone (2026-09-18) | 2 UI tests passed: precise shot/replay and drag shot with rotation | `/tmp/OffsideGolf-directional-ui.xcresult` |
| Directional-art focused UI, iPad (2026-09-18) | 1 UI test passed: precise shot/replay | `/tmp/OffsideGolf-directional-ipad.xcresult` |
| Debug core suite (2026-09-18) | 71 tests passed, including the five DEBUG-only command tests and all 31 course playability scenarios | `scratchpad/CoreBuild` run log |
| Release core suite (2026-09-18) | 66 tests passed optimized; the five DEBUG-only command tests are correctly absent | `scratchpad/CoreRelease` run log |

The nine-hole UI test is separate from the eight earlier combined regressions. Across those runs there are 11 distinct UI cases, each with a passing execution on both device families; totals do not count repeated executions as new tests.

The directional-art runs are focused follow-up evidence after the earlier green iPhone/iPad presentation suites. They do not replace the broader historical matrix or claim that every UI case was rerun in these three bundles. The eight-facing golfer extension is verified below.

## Eight-facing golfer verification

The golfer is now drawn from eight authored body facings with no mirroring. `golfer_poses_sheet.png` remains the southeast view and seven `golfer_<direction>.png` sheets complete the set, each a 4x3 grid of the same twelve key poses. `GolferFacingTests` covers this with seven cases, all passing on both device families:

| Case | What it establishes |
|---|---|
| `testEightShotDirectionsSelectRightHandedBodyFacing` | Each of the eight shot aims selects the body heading 90 degrees clockwise from aim, at any aim magnitude |
| `testNearestFacingWrapsAcrossNorthAndInvalidAimKeepsFallback` | Sector boundaries wrap correctly across north; zero, NaN and infinite aims return the caller's fallback rather than a wrong facing |
| `testEveryFacingUsesAllTwelveDistinctTopLeftRowMajorCells` | All eight sheets resolve twelve distinct cells in top-left row-major order, converted to SpriteKit's bottom-left rect convention |
| `testRenderingChangesFacingAndStanceWithoutMutatingGameOrMirroring` | Facing changes swap the texture and move the stance to the correct side of the ball, leave `GameState` byte-identical, and never apply a negative x scale |
| `testFacingCacheRetainsThreeMostRecentlyUsedSheets` | The renderer keeps exactly the three most recently used sheets, evicting by true least-recent use, so rotating through all eight does not accumulate image memory |
| `testActualBundledSheetsDecodeAndRenderAllEightFacings` | Every sheet is present in the built bundle, decodes at 1448x1086 with an alpha channel, and yields 362x362 pose cells |
| `testEightFacingRenderedVisualAttachments` | Each facing is rendered through a real `SKView` and captured as a PNG attachment |

The captured renders are retained as [`verification/screenshots/golfer-facing-<direction>.png`](verification/screenshots). Inspecting the actual pixels confirms eight genuinely distinct views of one consistent character: north, northeast and northwest show the back of the cap with no face; east and west are opposite profiles rather than one mirrored image; south faces the viewer. Cream cap, green polo, brown shorts, cream shoes, tan skin, warm upper-left light and the club are consistent across all eight.

The three-sheet cache is a deliberate memory bound, and the arithmetic behind it is worth stating. Each sheet is 1448x1086, so a decoded RGBA copy is 6.0 MiB. The cap therefore holds about 18 MiB of golfer texture memory, where an unbounded cache of all eight would reach 48 MiB. That is arithmetic from known dimensions, not a measurement: actual resident memory depends on the format SpriteKit chooses and on when it releases evicted textures. Confirming it, and deciding whether these sheets should ship compressed, is M12 work.

Registration is not finished. The southeast sheet keeps its twelve measured per-pose foot and nape anchors; the seven new directions use one approximate foot anchor and a per-direction nape column. That is adequate for the hair overlay at gameplay scale but is explicitly pending final per-frame artist registration, and the shape of the character at smallest on-device scale has had no human approval. These remain M6 and M12 gates.

## End-to-end contract

The full-round UI test reads a fixture of quantized whole-degree aims and whole-percent powers, selects clubs/ranges through real menus, moves the actual power slider, corrects rounding with visible buttons, taps Swing and waits for each stroke/settle/result. It never teleports or calls instant completion. It checks hole scores `[3,3,4,2,5,4,3,4,4]`, total 32, final persistence after process termination, and absence of a spurious Continue entry. This proves a route through the authored course, not that every player shot is optimal or that difficulty is fully user-tested.

Core playability tests also exercise conservative routes at authored wind extremes, aggressive routes on the dog-leg and river, and a deliberate river penalty followed by recovery. Deterministic fixtures check flight, wind, swept contact, bounce/roll, slopes, cup speed, frame scheduling, idempotent scoring, state transitions and checkpoint restoration.

Hosted tests exercise actual atomic file writes/backups, interrupted-shot restore, unsupported schemas, compatibility recovery, failing I/O and retry, save queue ordering, record version isolation, camera/projection, animation/impact, resource decoding and audio policy. Simulator UI tests cover cancellation, drag and untimed controls, pause/restart confirmation, backgrounding, rotation, large text, tutorial preference retention and process termination/resume.

## Release archive inspection

A fresh Release archive built successfully without code signing on 2026-09-18 at `/tmp/OffsideGolf-directional-candidate.xcarchive`. Version 0.1.0 (2), bundle `ai.offside.OffsideGolf`, iOS 17 minimum and iPhone/iPad families are present. The archive contains ten course JSON files (manifest plus nine holes), twelve runtime audio files, the terrain and environment sheets, all eight golfer facing sheets, compiled menu/icon assets and `PrivacyInfo.xcprivacy`. Source masters, mocks, tests, scripts and DEBUG marker strings are absent.

The seven added facing sheets carry a real cost: the final app bundle is about 28,424 KiB and contains 42 files; the executable is 994,216 bytes. Nothing here measures what this does to launch time or resident memory on baseline hardware. Texture compression and residency are open M12 items, and this number is the reason they matter. The current file list is retained in [archive inspection](verification/archive-inspection.json).

This is not a signed install, distribution validation, privacy report from Organizer, processed TestFlight build or App Store approval. Owner signing, actual minimum-device testing and final store/account details remain in [release checklist](RELEASE_CHECKLIST.md).

## Bugs caught and corrected

- Main-menu scrolling could draw the brand over the clock/notch while the navigation bar was hidden. `MainMenuView` now masks its safe viewport with a 12 pt top fade over an opaque cream background. Actual screenshots show the overlap [before](verification/screenshots/menu-safearea-before.png) and the clear status bar [after](verification/screenshots/menu-safearea-after.png). A screenshot regression detected 5,392 menu-ink pixels in the protected area before the fix and zero afterward. Four iPhone launch/UI tests passed in `/tmp/OffsideGolf-menu-safearea-green.xcresult` (including rotation, navigation and largest-text course access); the same status-bar regression passed on iPad in `/tmp/OffsideGolf-menu-safearea-ipad.xcresult`.
- Swing advisory layout: reproducing the out-of-bounds warning increased the controls' height by about 22 pt at normal text size, shifting the pad during calibration. Advice now uses a reserved row sized for all messages at the current width/Dynamic Type size; inactive messages are hidden from accessibility. The course-boundary copy is “Shot may leave the course.” Regression evidence: `/tmp/OffsideGolf-swing-advisory-green.xcresult`, eight GameSession tests (including warning appear/clear/cancel layout checks at 270/370 pt widths and normal/largest accessibility text) and two real-control UI flows passed. The preceding red run reproduced the height change at all four configurations.
- SpriteKit shape fills sampled the full terrain sheet instead of the intended subtexture; four independent CGImage crops now prevent material bleed.
- SwiftUI could not resolve the loose menu PNG through its asset-catalog lookup; `CoastMenu.imageset` fixes the blank panel. Rendered-image regression coverage remains.
- Flag/golfer/ball markers now compensate for camera scale; hill/valley inverse projection accounts for elevation.
- Shot predictions no longer assume 75% power while the HUD says 0%. Before charging, the player sees an aiming line; actual selected power produces the arc/landing guide. Cancellation clears stale prediction and hazard warnings immediately.
- Pull input captures aim, while untimed charging still permits aim adjustment. Resize, background and pause invalidate uncommitted gestures.
- Save completion gates committed simulation and final navigation; a completed round no longer resurrects Continue on disappearance. App-level background saving covers settings and scorecards as well as gameplay.
- Records are isolated by course/content/physics version. Practice affects hole bests only; assisted tools/overlays persist ineligibility before showing detailed information.
- Initial save loading gates editable screens. Explicit retry/backup recovery never silently erases an unreadable/future save.
- Replaying tutorial help retains the chosen control accessibility preference. Restarting a hole requires explicit confirmation.

## Commands

```sh
xcodegen generate --spec OffsideGolf/_OffsideGolf-frontend-iOS/project.yml
swift test --package-path OffsideGolf/Packages/OffsideGolfCore --scratch-path /tmp/OffsideGolfFullCore -c release
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,id=1A96FECC-23A6-4A9F-95E3-A25599361DC9' -derivedDataPath /tmp/OffsideGolfFullBuild CODE_SIGNING_ALLOWED=NO test
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,id=2A4CAB14-1BA6-415E-8BA7-4E2DDFC719D4' -derivedDataPath /tmp/OffsideGolfFullBuild CODE_SIGNING_ALLOWED=NO test-without-building
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/OffsideGolfFullRelease -archivePath /tmp/OffsideGolf-release-candidate.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

Use a fresh `-resultBundlePath` for retained XCTest evidence and substitute installed simulator IDs. Temporary logs/results can be cleaned by the OS; representative screenshots and this report are retained in the workspace. No commit, upload, tester invitation or external publication was performed. [M0 verification](verification/M0_VERIFICATION.md) is historical evidence, not current feature status.
