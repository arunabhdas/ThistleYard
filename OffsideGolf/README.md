# OffsideGolf

A premium, offline casual golf game for iPhone and iPad, inspired by the original coastal artwork in `mocks/`.

## Start here

1. [Final decisions](DECISIONS.md)
2. [Product requirements](PRD.md)
3. [Architecture](ARCHITECTURE.md)
4. [Gameplay and physics](GAMEPLAY.md)
5. [Nine-hole course](COURSE.md)
6. [Art direction](ART_DIRECTION.md)
7. [Project structure](PROJECT_STRUCTURE.md)
8. [Implementation plan](IMPLEMENTATION_PLAN.md)
9. [Milestone acceptance](ACCEPTANCE_CRITERIA.md)
10. [Verification and current status](VERIFICATION.md)

## Current implementation

Whispering Coast is playable from tee to cup across all nine holes. The app includes six clubs, wind, deterministic flight/bounce/roll, terrain and tree collisions, water penalties, putting ranges, animated camera/golfer, both touch control modes, a scorecard, original painted assets, categorized audio, haptics, local saves and recovery, settings, customization and a short tutorial. DEBUG tools support course authoring and make assisted runs ineligible for records.

The complete nine-hole UI flow has passed on iPhone and iPad, including the 32-stroke scorecard and personal best after relaunch. See [verification](VERIFICATION.md) for per-device results and remaining gates. This is a playable release candidate under development: signed physical-device testing, baseline performance, manual accessibility/audio and final art review remain outstanding. No TestFlight upload has occurred.

## Open and run

Open `_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj`, select the **OffsideGolf** scheme and an iPhone or iPad simulator, then Run. Requires Xcode with Swift 6 support; verified toolchain and simulator versions are recorded in `VERIFICATION.md`. Deployment target is iOS/iPadOS 17.

From `OffsideGolf`, run `./_OffsideGolf-frontend-iOS/setup.sh` to regenerate and build the project. It asks before opening Xcode; use `--no-open` for build-only automation.

The generated project is included. To regenerate it after changing targets/resources, install XcodeGen and run from this folder:

```sh
cd _OffsideGolf-frontend-iOS && xcodegen generate
```

The app has no third-party runtime dependencies. The local `OffsideGolfCore` package owns validated content, deterministic simulation, golf rules and versioned save models. Choose your own signing team before running on a physical device; no team identifier is borrowed from sibling apps.

## Verify

```sh
swift test --package-path Packages/OffsideGolfCore
xcodebuild -project _OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/OffsideGolfBuild CODE_SIGNING_ALLOWED=NO build
xcodebuild -project _OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj -scheme OffsideGolf -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/OffsideGolfBuild CODE_SIGNING_ALLOWED=NO test
```

Use an installed simulator name from `xcrun simctl list devices available`. Core tests run on macOS without a simulator and exercise the actual nine-hole JSON, conservative routes, wind limits and hazard recovery. Hosted tests cover camera, animation, projection, audio policy, save I/O and app integration. UI tests use real controls for all nine holes, putting, pause, cancellation, rotation, large text, settings and termination/resume. Each run uses an isolated save directory; screenshots remain in its result bundle. The complete UI round takes about eleven minutes on the tested simulator.

## Content and assets

`_OffsideGolf-frontend-iOS/App/Resources/Courses/whispering-coast.json` contains the nine hole briefs. Playable metre-based geometry lives in `_OffsideGolf-frontend-iOS/App/Resources/Courses/Holes/*.json`. Edit those files directly, or change `Tools/author_course.py` and regenerate the coherent first course:

```sh
python3 Tools/author_course.py
```

Regeneration replaces all nine authored geometry files, so preserve deliberate manual edits first. Validators reject unsafe tees/pins/drops, malformed geometry, unsupported versions and inconsistent course totals. Change the appropriate content/physics version when tuning would invalidate saves or records. [Course design](COURSE.md) documents the schema and authoring workflow.

Original painted runtime assets, audio and provenance are documented in [art direction](ART_DIRECTION.md) and `ArtSource/GENERATED_ASSETS.md`. Source masters, reference mocks, questionnaire screenshots and developer scripts stay outside the app bundle. The golfer has twelve key poses in each of eight authored facings, with a three-sheet texture cache. Final cosmetic/registration review at physical-device scale remains a production quality gate.

## Release preparation

[Release checklist](RELEASE_CHECKLIST.md) tracks signing, privacy, archive inspection, device checks and TestFlight. [Store draft](APP_STORE_DRAFT.md) contains editable listing and beta notes. Supply the owner's signing team and real support/privacy/contact details; do not reuse credentials from sibling apps. An unsigned local archive is not an installable or uploaded TestFlight build.
