# OffsideGolf Implementation Plan

> The user authorized all remaining milestones on 2026-09-17. Continue through implementation, review and verification checkpoints without requesting renewed implementation permission. Release uploads and account actions remain separate from local implementation.

**Goal:** A polished offline nine-hole casual golf game. The source now contains the M1–M11 gameplay, course, presentation and persistence systems; final production-art, manual/device and release acceptance remains open.

**Architecture:** Foundation-only Swift 6 core; SwiftUI navigation/controls; SpriteKit rendering; AVFoundation audio; local actor-based storage. `PROJECT_STRUCTURE.md` maps actual files. Related small models are grouped rather than split into speculative files. XcodeGen is a development tool, not a runtime dependency.

**Specifications:** `DECISIONS.md`, `PRD.md`, `ARCHITECTURE.md`, `GAMEPLAY.md`, `COURSE.md`, `ART_DIRECTION.md`. Preserve these requirements when completing the open gates below.

## Status and evidence checkpoint — 2026-09-18

“Implemented” describes source and bounded test coverage, not release approval. Checked items below have implementation or stated verification evidence; unchecked items retain work that is unverified, incomplete or manual. A passing individual test does not make its containing failed result bundle a pass. `VERIFICATION.md` is the canonical running evidence record and may supersede this checkpoint.

**2026-09-18 directional follow-up (E9).** After the eight-facing golfer extension, the iPhone hosted platform suite passed 55 of 55, including seven PNG decode/cache/render tests with real SpriteKit captures. Two focused iPhone UI flows and one focused iPad UI flow also passed. Earlier green presentation suites remain the broader UI evidence; this follow-up is simulator evidence, so every physical-device, human-study and signing gate below is untouched by it.

| Milestone | Current status | Evidence and remaining gate |
|---|---|---|
| M0 | Foundation implemented; menu-return fix verified in isolation | Historical launch/tablet checks and targeted menu pass E5; final matrix remains |
| M1 | Playable hole implemented | Real control/cup/replay UI coverage; full nine-hole input path passed E4; novice first-play review remains |
| M2 | Six clubs, wind, recommendation, preview and alternate controls implemented | E1/E3/E5; subjective preview/gesture review remains |
| M3 | Deterministic terrain simulation implemented | E1; render interpolation is an explicit adaptation/open polish decision; baseline performance unmeasured |
| M4 | Hazards, tree contacts, penalties and assisted debug tools implemented | E1/E3, authored recovery scenarios; manual hazard/visual review remains |
| M5 | Camera, elevation projection and lifecycle/orientation handling implemented | E3/E5; final phone/tablet orientation and device matrix remains |
| M6 | Eight authored facings, golfer clock and customization implemented | Twelve key poses across all eight directions, verified rendering E8/E9; final per-frame registration and palette/device approval remain E7 |
| M7 | Menus, round flow, tutorial/settings and accessibility controls implemented | E3/E5/E8; final regression now green on both families; manual VoiceOver/largest-text review remains |
| M8 | Putting ranges, slope physics/guides and capture implemented | E1/E3 and real round E4; human green-reading/tuning review remains |
| M9 | Nine authored holes and complete round implemented | 31 core course scenarios E1/E8; real 32-stroke nine-hole UI/persisted PB E4, rerun green in the E8 bundles; final art/transition profiling remains |
| M10 | Original audio, category policy and haptics implemented | Policy/resource tests E3; physical silent mode/interruption/mix/haptics remain |
| M11 | Versioned durable saves, recovery and records implemented | Real-file/queue tests E2/E3; committed-shot resume/settings now passes E5; physical upgrade/termination matrix remains |
| M12 | Polish underway; acceptance open | No baseline physical traces, new-player study or final art approval; the E9 payload growth to 29.0 MB makes texture residency a measured open question |
| M13 | Local preparation only | Icon/privacy/catalog/checklist exist E6; owner signing, install/archive and TestFlight remain blocked/unverified |

Evidence references (local `/tmp` artifacts may be cleaned; retain final results/screenshots through `VERIFICATION.md`):

- **E1:** `/tmp/offsidegolf-full/core-final-release.log` and `core-progress.md`: optimized core checkpoint, 63 tests passed, including nine default routes, seventeen distinct wind-limit scenarios, four aggressive routes and one water-recovery scenario. This predates later record-migration tests; it is not a claim that the latest entire source tree has been rerun.
- **E2:** `/tmp/offsidegolf-record-versions-green.log`: nine save-model tests passed, including legacy version defaults and version-separated records. `/tmp/offsidegolf-full/persistence-report.md` records actual-file backup/write-failure and in-flight restore coverage.
- **E3:** `/tmp/OffsideGolf-full-check2.xcresult`: all 45 hosted platform tests passed on iPhone 17 Pro simulator, including content/camera/animation/audio/store/repository integration.
- **E4:** `/tmp/OffsideGolf-full-round1.xcresult`: `testNineHolesThroughRealControlsAndPersistedPersonalBest` passed, completing all nine with 32 strokes, checking the scorecard and persisted PB after relaunch. This bundle also contains an earlier resume/settings test failure, subsequently fixed; the bundle itself is not green.
- **E5:** `/tmp/OffsideGolf-full-check2.xcresult`: six of seven selected UI tests passed, including committed-shot termination/resume and persisted settings. `LaunchFlowTests.testExploreCourseOpenHoleAndReturnToMenu` failed on menu return in that run. The asset fix subsequently passed its isolated test in `/tmp/OffsideGolf-menu-fix.xcresult` (one test, no failures); the final combined rerun remains pending. The separate full-round test is E4, not part of this selected seven.
- **E6:** `/tmp/offsidegolf-full/release-report.md`, `RELEASE_CHECKLIST.md`: validated privacy/catalog preparation and source/bundle checks; no signed install, archive processing or TestFlight evidence.
- **E7:** `ArtSource/GENERATED_ASSETS.md`, `ArtSource/golfer-poses-manifest.json`, `ArtSource/directional-golfer-prompts.json`, runtime asset/audio manifests: provenance and production-candidate status. They do not establish human final-art approval.
- **E8:** The final green presentation suites remain `/tmp/OffsideGolf-polish-phone.xcresult` and `/tmp/OffsideGolf-polish-ipad.xcresult`, with the broader UI cases recorded in `VERIFICATION.md`.
- **E9:** `/tmp/OffsideGolf-directional-platform.xcresult` (55 hosted tests), `/tmp/OffsideGolf-directional-ui.xcresult` (two iPhone UI tests) and `/tmp/OffsideGolf-directional-ipad.xcresult` (one iPad UI test) verify the eight-facing golfer extension after XcodeGen regeneration.
- **E9:** Eight-facing golfer verification in `VERIFICATION.md` and the eight retained `verification/screenshots/golfer-facing-*.png` renders, plus the refreshed `verification/archive-inspection.json` confirming all eight sheets ship in an unsigned Release archive with no DEBUG markers and a 29,021,274-byte payload.

## Global constraints

- iOS/iPadOS 17 minimum; iPhone/iPad, portrait/landscape. Minimum-OS and baseline hardware are still distinct from the installed simulator runtime.
- No ads, IAP, accounts, cloud, Game Center or speculative phase-2 implementation.
- Six approved clubs, no manual spin/loft, timed accuracy or random shot dispersion.
- Pure deterministic simulation; render callbacks never determine scores.
- No force-unwrapped content or silent save reset. Unknown schemas remain protected.
- Each checkpoint records relevant tests, observed failures, fixes and verification limits.
- Mocks, questionnaire captures, PROMPT.md and unrelated projects remain references, excluded from runtime resources.
- A paired physical iPhone is available, but there is no configured owner development team/signing identity; installation is not yet possible. Availability does not count as physical validation.

## M0 — Launch, content and rendering foundation

**Files:** `App/{OffsideGolfApp,AppCoordinator}.swift`, `App/UI/{RootView,MainMenuView,CourseOverviewView,HolePreviewView}.swift`, `App/Presentation/CoursePreviewScene.swift`, `App/DesignSystem/GolfTheme.swift`, core `Content/CourseManifest.swift`, manifest JSON, project/test configuration.

**Contract:** `CourseManifest.decode(_:) throws` validates nine ordered unique hole IDs, text, par and distances; derived totals are par 35/2,848 yd. AppCoordinator has explicit loading/ready/failed states. Navigation owns scenes through an explicit SKView host.

- [x] Implement strict content validation, responsive menus/overview/preview and retry states.
- [x] Establish core, hosted-platform and UI tests plus historical iPhone/iPad builds/screenshots.
- [x] Fix the menu image asset lookup and pass the targeted menu-return pixel/navigation check (E5).
- [ ] Recheck final painted menu/navigation in the complete device/orientation/large-text matrix.

## M1 — One playable end-to-end hole

**Files:** core `Simulation/{Vector2,GameState,GameReducer,FlightSolver,RollSolver,CupCapture}.swift`, `Content/HoleDefinition.swift`; `App/Game/GameSession.swift`, `App/UI/{GameContainer,HUDView,SwingControls,HoleResultView}.swift`, `App/Presentation/{GameScene,WorldProjection,BallRenderer,TerrainRenderer}.swift`.

**Contract:** `GameReducer.send(_:)`, `advance(by:)`, read-only `state` and event batch. Private committed `ShotInput` freezes identity/club/direction/power/range. Core owns impact scoring; projection converts metre positions and altitude.

- [x] Cover legal shot, duplicate impact rejection, invalid/cancelled input, flat flight/roll, putt capture and result.
- [x] Load safe validated geometry by manifest ID and connect aim → power → release → impact → settle/cup → result/replay.
- [x] Complete a hole through real UI controls; all nine are now playable rather than previews.
- [ ] Observe human novice completion/first-shot comprehension; automation is not that study.

## M2 — Six clubs, wind, power and preview

**Files:** core `Golf/{GolfClubType,ShotPredictor}.swift`, `Simulation/SimulationConfig.swift`; `App/UI/{SwingControls,HUDView}.swift`, `App/Game/GameSession.swift`. Club/range/wind/recommendation types are grouped in these files; no runtime configuration JSON catalog is required.

- [x] Calibrate six nominal club ranges; test wind direction, invalid input and recommendation through the real simulator.
- [x] Implement auto recommendation, legal manual override, frozen committed input and coarsened arc/landing guidance.
- [x] Use the same core commands for pull/release and untimed 1° aim/1% power controls; persist left-handed/precise preferences.
- [x] Exercise club selection, aim, release, cancel and alternate controls in core/UI paths.
- [ ] Complete human touch/preview clarity review, including captured-pull multi-touch and smallest screens.

## M3 — Deterministic physics and terrain

**Files:** core `Content/TerrainDefinition.swift`, `Simulation/{ShotSimulation,CollisionSolver,SimulationEvent,FlightSolver,RollSolver,SimulationConfig}.swift`; `TerrainCollisionTests.swift`, `PhysicsTests.swift` and `RecoveryPuttingTests.swift`.

- [x] Cover friction order, bounce energy loss, thin-hazard sweeps, slope support/turnaround and 30/60/120 render schedules.
- [x] Implement analytical flight, swept contacts, bounce/roll, all materials, slopes and smooth elevation patches.
- [x] Bound catch-up to eight 1/120 s ticks; ignore anomalous gaps over 250 ms without changing physics step size. Add DEBUG collision/terrain/trajectory inspection.
- [ ] Evaluate previous/current-state render interpolation during polish. Current direct state sampling is a documented adaptation, not completed interpolation work.
- [ ] Run physical-device stress/energy/performance checks; deterministic correctness does not prove frame budgets.

## M4 — Hazards, trees and scoring recovery

**Files:** core `Simulation/{HazardResolver,CollisionSolver,GameReducer+Debug}.swift`; `App/UI/DebugToolsView.swift`, `App/Game/GameSession.swift` and round bookkeeping in `GameContainer`/`PlayerStore`.

- [x] Verify once-only water/OOB penalties, legal-drop/pre-shot fallback, canopy entry suppression and high clearance.
- [x] Implement trunk/canopy volumes, surface water contact, deterministic recovery and guarded scoring transitions. No separate ScoreLedger event-sourcing type is used.
- [x] Add DEBUG safe teleport, wind/power controls, hole selection, simulation speed, completion and authored JSON export; state-changing tools mark the run assisted.
- [x] Exercise authored drop safety and a deliberate actual-course river shot/recovery in core acceptance.
- [ ] Review actual hazard animations/feedback and Release exclusion in the final built artifact.

## M5 — Camera, lifecycle and orientation

**Files:** `App/Presentation/{GameCameraController,WorldProjection,GameScene}.swift`, session/container; `CameraTests.swift`, `WorldProjectionTests.swift`, existing gameplay/launch UI suites.

- [x] Implement fixed-pitch overview/setup/flight/landing/putting/celebration framing, elevation-aware projection/inversion and reduced-motion snapping.
- [x] Cover projection/fitting, frame-schedule convergence, pause/resume and input-generation cancellation.
- [x] Preserve committed state on pause/background and refit on resize without replacing the reducer.
- [ ] Complete final iPhone/iPad portrait/landscape and safe-area/largest-text matrix, including manual reduced-motion review.

## M6 — Golfer and first production art family

**Files:** `App/Presentation/{GolferRenderer,GolferAnimationController,ArtLibrary,TerrainRenderer}.swift`, `App/UI/GolferCustomizationView.swift`, `ArtSource/golfer-poses-manifest.json`, texture/provenance files; `AnimationTests.swift`.

- [x] Sample core swing/shot clocks; verify practice never launches, impact cannot duplicate and reduced motion retains semantics.
- [x] Produce original menu/environment/terrain/golfer candidates with recorded provenance; provide four skin/outfit palettes and three hair choices.
- [x] Implement twelve registered key poses, palette shader and hair overlays; independent terrain pixel crops correct SKShapeNode fill UV sampling.
- [x] Complete the eight-direction authored golfer family: eight sheets of twelve poses each, selected never mirrored, verified by seven tests and eight retained renders (E8/E9). One pose per clip is still not final frame animation, and the seven new directions still use approximate rather than per-frame measured anchors.
- [ ] Inspect every cosmetic registration, smallest-scale readability, occlusion and motion on device; approve production assets explicitly.

## M7 — Menus, HUD, tutorial and accessibility

**Files:** `App/UI/{GameContainer,MainMenuView,SettingsView,ScorecardView,SwingControls,HUDView}.swift`, `App/Game/PlayerStore.swift`, `Localizable.xcstrings`. Pause/tutorial panels are composed in GameContainer rather than separate scaffold types.

- [x] Implement new/continue/practice/golfer/settings/scorecard navigation, short tutorial prompts with persisted completion/replay, pause/resume and replacement/restart handling.
- [x] Add semantic labels, Dynamic Type scrolling, contrast/non-color cues, reduced motion, left-handed placement and untimed controls.
- [x] Exercise available navigation, rotation, alternate-control and settings/resume UI flows, including the targeted menu-return correction (E5).
- [x] Implement destructive restart confirmation with cancel, and retain chosen precise controls when replaying tutorial help.
- [x] Verify the new restart/cancel and tutorial-preference regressions in the final combined UI run. Restart-with-cancel passes in `testDragShotAndRotationPreserveProgress` and tutorial-replay preference retention in `testCommittedShotSurvivesTerminationAndSettingsPersist`, both green on iPhone and iPad in E8.
- [ ] Complete manual VoiceOver traversal, largest-text required-action reachability, contrast and tutorial skip/replay review on final UI/device builds.

## M8 — Putting precision and green reading

**Files:** core `Simulation/{RollSolver,CupCapture}.swift`, `Golf/GolfClubType.swift`; `SwingControls`, `TerrainRenderer`, `RecoveryPuttingTests.swift`.

- [x] Verify flat range calibration, static support, downhill restart and swept slow/fast cup crossings.
- [x] Implement frozen 3/10/30 yd ranges, optional slope arrows, short guide and cup feedback using the same input model.
- [x] Complete all nine greens through real simulator inputs; orientation does not alter world power calibration.
- [ ] Run human putting/green-reading sessions and confirm guidance never becomes unintended exact-path assistance.

## M9 — Complete Whispering Coast

**Files:** `Tools/author_course.py`, `App/Resources/Courses/Holes/whispering-coast-01.json` through `09.json`, shared scenery/landmarks; `CourseContentIntegrationTests.swift`, `CoursePlayabilityTests.swift`, platform `CourseContentTests.swift`, UI `RoundFlowTests.swift`.

- [x] Validate metre-based routes, IDs, par/yardage totals, wind ranges, safe tee/pin/drop positions, geometry and media references.
- [x] Author all nine with shared scenery, unique landmarks, hills/valley patches and no hole-number branches in simulation.
- [x] Complete the 31 conservative/wind-limit/aggressive/water-recovery core scenarios.
- [x] Complete an actual nine-hole UI round in 32 strokes, verify scorecard and relaunch-persisted PB (E4).
- [x] Add practice isolation, assisted eligibility and versioned record tests.
- [x] Rerun the full final regression after remaining fixes (E8): 66 of 66 on each device family with no failures or skips.
- [ ] Profile hole transitions and texture residency, and obtain visual course approval. The E9 payload growth makes residency a measurement, not an estimate.

## M10 — Audio and haptics

**Files:** `App/Platform/{AudioManager,AudioSettings,HapticManager}.swift`, `App/Resources/Audio`, `ArtSource/Audio`, `AudioManagerTests.swift`.

- [x] Test independent categories/clamping, semantic event deduplication, loop/background/interruption policy and haptic opt-out at narrow hardware seams.
- [x] Create eight original effects and four lossless ambient/music loops with source/provenance; wire semantic feedback and settings.
- [x] Implement ambient/mixing silent-mode policy, bounded voices and unsupported/inactive haptic fallback.
- [ ] Listen on physical devices: four sliders, silent switch, interruptions, loop comfort, tactile subtlety and redundant visual feedback.

## M11 — Durable progress and records

**Files:** core `Persistence/{PlayerProfile,SaveGame}.swift`, `Simulation/{GameCheckpoint,GameReducer+Checkpoint}.swift`; `App/Platform/FileGameRepository.swift`, `App/Game/PlayerStore.swift`; `SaveGameTests.swift`, `FileGameRepositoryTests.swift`, `PlayerStoreTests.swift`, `RoundFlowTests.swift`.

**Contract:** ordered actor-backed atomic schema-1 saves with last-good backup and explicit load results. Checkpoints restore exact active reducer state rather than replaying a shot from scratch. `lastSettledCheckpoint` supports acknowledged assisted recovery across compatible historical versions. Course records are keyed by course/content/physics; old absent version fields decode as 1/1.

- [x] Test actual-directory roundtrip, in-flight restore without duplicate stroke, corrupt-current backup, future-schema protection, version mismatch and actual write failure.
- [x] Persist profile/settings/cosmetics/tutorial, completed scores, active simulation, round state and versioned eligible records; no separate per-shot ledger is claimed.
- [x] Add Continue, replacement confirmation, load/save retry, acknowledged recovery and practice/assisted separation. Gate committed simulation while its save is pending/failed.
- [x] Verify committed-shot termination/resume and persisted precise controls in the corrected E5 UI run.
- [ ] Complete settled/impact/background/upgrade termination matrix on signed physical builds; preserve explicit errors and historical records across upgrades.

## M12 — Performance and polish

- [ ] Capture Release traces on baseline iPhone 12/iPad 9; measure CPU/GPU, frame pacing, memory, launch and energy rather than infer them from simulator tests.
- [ ] Tune texture residency, offscreen updates, particles, node/draw counts and transitions from those measurements. Current dimension-based texture estimates are not residency proof.
- [ ] Finish directional art, palette/occlusion/guide/camera polish, sensory balance and final placeholder/provenance review.
- [ ] Run the complete final core/platform/UI regression and at least five new-player sessions; record first-shot learning within 30 seconds and accessibility results.
- [ ] Meet PRD budgets or document a concrete remaining blocker; code completion alone does not close M12.

## M13 — TestFlight readiness

- [x] Prepare candidate app icon, privacy manifest, starter English catalog and `RELEASE_CHECKLIST.md`; validate metadata syntax and document source/API audit.
- [ ] Recheck current official Apple requirements and final binary privacy/API/resource declarations before submission; preparation evidence does not approve a final archive.
- [ ] Configure the owner's team/signing identity and final release metadata. A paired iPhone cannot install until this is available.
- [ ] Archive signed Release, inspect resources/DEBUG exclusion, install/upgrade and exercise saves on physical hardware.
- [ ] Complete owner-approved store screenshots/copy, age rating, privacy/support URLs, pricing/storefront details and App Store Connect ownership.
- [ ] Perform an authorized upload, actual TestFlight processing/install and crash smoke. An unsigned build or local archive is not TestFlight readiness or App Store acceptance.

## Verification commands

```sh
cd OffsideGolf
xcodegen generate --spec _OffsideGolf-frontend-iOS/project.yml
swift test --package-path Packages/OffsideGolfCore
swift test -c release --package-path Packages/OffsideGolfCore
xcodebuild -project _OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/OffsideGolfBuild CODE_SIGNING_ALLOWED=NO build
xcodebuild -project _OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/OffsideGolfBuild CODE_SIGNING_ALLOWED=NO test
```

Use installed simulator identifiers and a fresh result-bundle path. Optimized core runs are preferred for the expensive whole-course search. Repeat relevant UI suites on iPad and inspect the final Release artifact. Do not equate simulator success with physical performance, haptics, manual accessibility or shipping readiness.
