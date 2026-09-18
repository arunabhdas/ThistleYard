# M0 verification — 2026-09-17

## Scope completed

All 28 approved decisions are recorded, with PRD, architecture, gameplay/physics, nine-hole design, art direction, project structure, implementation milestones and acceptance criteria.

M0 implementation: native SwiftUI launch/course navigation; nine validated JSON hole briefs; original SpriteKit preview illustration; responsive portrait/landscape screens; Dynamic Type scrolling; explicit content load/retry state; a Foundation-only core package; Xcode project and test targets. The scene's view host owns its lifecycle explicitly. Source files are listed in the M0 section of `IMPLEMENTATION_PLAN.md` and marked in `PROJECT_STRUCTURE.md`.

**This is a buildable foundation, not a playable golf game.** No shot simulation, animated golfer, score persistence, production painted art, audio or final gameplay HUD is claimed at this checkpoint. M1 is the next implementation slice.

## Environment

- Xcode 26.5 (17F42), Swift 6.3.2 compiler, Swift 6 language mode.
- iPhone 17 Pro simulator, iOS 26.5.
- iPad (A16) simulator, iOS 26.5.
- Deployment target iOS/iPadOS 17; minimum-OS runtime and baseline physical hardware were not available in this verification run.

## Results

| Verification | Result | Evidence |
|---|---|---|
| Core validation suite | 11 tests, 0 failures | `/tmp/offsidegolf-core-green.log` |
| iPhone UI suite | 3 tests, 0 failures | `/tmp/OffsideGolf-M0-render-green.xcresult` |
| iPhone hosted platform suite | 3 tests, 0 failures | Same result bundle |
| iPad UI suite | 3 tests, 0 failures | `/tmp/OffsideGolf-M0-ipad-final.xcresult` |
| iPad hosted platform suite | 3 tests, 0 failures | Same result bundle |
| Debug simulator build | Passed as part of test build | `/tmp/offsidegolf-render-green.log` |
| Unsigned Release device build | Passed | `/tmp/offsidegolf-release-final.log` |
| Resource inspection | Only course/asset JSON; no mocks/questionnaire images | Release `.app` inspection |
| Device/orientation metadata | iPhone+iPad, requested portrait/landscape orientations | Built Info.plist inspection |
| Visual inspection | Menu/preview layouts checked in portrait/landscape; large-text screens reviewed | Screenshots below |

These represent 17 unique tests and 23 successful executions across the core and two simulator destinations. Xcode emits its incidental “AppIntents metadata extraction skipped” tool message because this app has no AppIntents dependency; there are no Swift source compilation warnings in the final build.

## Regression evidence

- Before semantic validation, the core suite produced 12 failing assertions for accepted invalid data. After validation, all 11 cases passed.
- The first launch-flow test failed against the launch-only scaffold, then passed after navigation/content implementation.
- Visual review exposed a blank SpriteView after returning to the menu even though navigation tests passed. Added an actual-pixel assertion excluding the caption badge: it failed in `/tmp/OffsideGolf-M0-render-red.xcresult`. Explicit per-host scene ownership fixed the panel; the same assertion now passes on both device families.
- Landscape capture initially used app-window screenshots that were cropped incorrectly by the test tooling. Final attachments use full-device screenshots; reviewed images show complete layouts.
- Independent review corrected terrain-aware projection inversion, putting-range math and save/config compatibility in the specifications. Initial source review found no additional major M0 defect beyond error-recovery coverage and landscape navigation checks, both now present. A final review of the rendering host and regression tests found no important remaining issues.

## Commands used

Run from the repository root. Local tool caches/simulator services required ordinary execution outside the filesystem sandbox; no project signing identity or external service was used.

```sh
xcodegen generate --spec OffsideGolf/_OffsideGolf-frontend-iOS/project.yml
swift test --package-path OffsideGolf/Packages/OffsideGolfCore --scratch-path /tmp/OffsideGolfCoreBuild
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,id=1A96FECC-23A6-4A9F-95E3-A25599361DC9' -derivedDataPath /tmp/OffsideGolfBuild -resultBundlePath /tmp/OffsideGolf-M0-render-green.xcresult CODE_SIGNING_ALLOWED=NO test
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,id=2A4CAB14-1BA6-415E-8BA7-4E2DDFC719D4' -derivedDataPath /tmp/OffsideGolfBuild -resultBundlePath /tmp/OffsideGolf-M0-ipad-final.xcresult CODE_SIGNING_ALLOWED=NO test-without-building
xcodebuild -project OffsideGolf/_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/OffsideGolfRelease CODE_SIGNING_ALLOWED=NO build
```

Result bundle paths must be new when rerunning. Simulator identifiers are local to this machine; substitute installed device identifiers. Logs/result bundles in `/tmp` are local evidence and may be cleaned by the OS; selected screenshots are retained in the repository.

## Visual evidence

- [iPhone portrait menu](verification/screenshots/iphone-iOS-menu.png)
- [iPhone landscape menu](verification/screenshots/iphone-iOS-landscape-menu.png)
- [iPhone portrait preview](verification/screenshots/iphone-iOS-hole-preview.png)
- [iPhone landscape preview](verification/screenshots/iphone-iOS-landscape-preview.png)
- [iPhone accessibility text size](verification/screenshots/iphone-iOS-large-text.png)
- [iPad portrait menu](verification/screenshots/ipad-iOS-menu.png)
- [iPad landscape menu](verification/screenshots/ipad-iOS-landscape-menu.png)
- [iPad accessibility text size](verification/screenshots/ipad-iOS-large-text.png)

The current illustration is a shared scenic placeholder, not a geometric map of each hole. Asset status is recorded in `App/Resources/AssetManifest.json`.

## Checkpoint checklist

- [x] Read and preserve supplied references and approved answers.
- [x] Write all requested specification deliverables before implementation.
- [x] Create an independently buildable OffsideGolf project without editing sibling applications.
- [x] Validate the bundled nine-hole manifest and reject malformed/unsupported content.
- [x] Verify navigation, rendering on return, rotation, background/foreground retention and large-text reachability.
- [x] Build Debug simulator and unsigned Release device configurations.
- [x] Review rendered screenshots and fix the discovered blank panel.
- [ ] Execute physical-device VoiceOver, haptic, audio and performance checks as those features arrive.
- [ ] Verify the minimum supported OS and baseline physical devices before release.
- [ ] Supply final painted assets, app icon, signed archive and TestFlight validation in later milestones.

No 60 FPS, battery, memory-budget, cold-launch timing or App Store readiness claim is made from these simulator tests. No commit or release upload was performed. Next checkpoint: M1, one playable calm hole from tee through putting and result.
