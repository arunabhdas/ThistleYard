# OffsideGolf — project structure

This is the implemented layout, not a list of planned scaffolding. `_OffsideGolf-frontend-iOS/project.yml` is the XcodeGen source of truth; the generated `_OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj` is included so opening the app does not require a generator. XcodeGen and the Python authoring tools are development dependencies only.

```text
OffsideGolf/
├── DECISIONS.md / PRD.md / ARCHITECTURE.md / GAMEPLAY.md
├── COURSE.md / ART_DIRECTION.md / PROJECT_STRUCTURE.md
├── IMPLEMENTATION_PLAN.md / ACCEPTANCE_CRITERIA.md / README.md / VERIFICATION.md
├── _OffsideGolf-frontend-iOS/project.yml / _OffsideGolf-frontend-iOS/OffsideGolf.xcodeproj/
├── _OffsideGolf-frontend-iOS/
│   ├── App/
│   │   ├── OffsideGolfApp.swift         # composition root and PlayerStore injection
│   │   ├── AppCoordinator.swift         # course manifest loading/retry
│   │   ├── Info.plist
│   │   ├── Game/ … UI/ … Presentation/ … Platform/ … DesignSystem/
│   │   └── Resources/                   # courses, textures, audio, privacy and catalogs
├── Packages/OffsideGolfCore/
│   ├── Package.swift
│   ├── Sources/OffsideGolfCore/
│   │   ├── Content/CourseManifest.swift / HoleDefinition.swift / TerrainDefinition.swift
│   │   ├── Golf/GolfClubType.swift / ShotPredictor.swift
│   │   ├── Simulation/
│   │   │   ├── Vector2.swift / GameState.swift / GameReducer.swift
│   │   │   ├── GameCheckpoint.swift / GameReducer+Checkpoint.swift
│   │   │   ├── GameReducer+Debug.swift   # compiled only with DEBUG
│   │   │   ├── SimulationConfig.swift / SimulationEvent.swift / ShotTimer.swift
│   │   │   └── ShotSimulation.swift / FlightSolver.swift / RollSolver.swift
│   │   │       CollisionSolver.swift / CupCapture.swift / HazardResolver.swift
│   │   └── Persistence/PlayerProfile.swift / SaveGame.swift
│   └── Tests/OffsideGolfCoreTests/
│       ├── CourseManifestTests.swift / HoleDefinitionTests.swift
│       ├── GameReducerTests.swift / PhysicsTests.swift / ClubWindTests.swift
│       ├── TerrainCollisionTests.swift / RecoveryPuttingTests.swift
│       ├── SaveGameTests.swift / DebugCommandsTests.swift
│       ├── CourseContentIntegrationTests.swift / CoursePlayabilityTests.swift
│       └── Fixtures/manifest.json / hole-1.json
│   └── Tests/
│       ├── OffsideGolfPlatformTests/     # hosted integration and presentation tests
│       └── OffsideGolfUITests/           # simulator UI flows and fixtures
├── Tools/author_course.py
├── ArtSource/
│   ├── golfer-poses-manifest.json
│   ├── GENERATED_ASSETS.md              # production art provenance handoff (being assembled)
│   └── Audio/generate_audio.py / *.wav  # source loop masters, not runtime bundle
├── verification/                        # retained checks/screenshots
└── PROMPT.md / mocks/ / specification/   # reference material, not app resources
```

Core deliberately groups related small types: `GameState.swift` includes phase, command, ball and result values; `GolfClubType.swift` includes putting range and wind; `ShotPredictor.swift` includes recommendation; `TerrainDefinition.swift` includes region/tree/drop/decoration geometry; `SaveGame.swift` includes round scores and codec/result/error types. No separate `Rules/`, `Geometry/`, configuration JSON catalogs, animation runtime JSON, `AssetLoader`, `AmbientAnimator` or generic repository protocols exist merely to match the original plan.

Apple frameworks stay in `_OffsideGolf-frontend-iOS/App`. Audio exposes hardware protocols for policy tests; the file actor is exercised with real temporary directories. Source art/provenance remain under `ArtSource/`, while only runtime textures/audio and metadata go into `_OffsideGolf-frontend-iOS/App/Resources/`. Environment and golfer cells use sheet subrects; terrain fills use independent pixel crops for correct SpriteKit shape UV sampling.

The shared scheme builds the iOS application and runs hosted platform/UI tests; core tests run with Swift Package Manager. Whole-course core integration tests also read the committed App JSON, so they require the complete checkout. Use Release configuration for the more expensive course playability search. Test presence does not establish a passing latest UI run; consult `VERIFICATION.md`.

Deployment targets remain iOS/iPadOS 17, iPhone/iPad, portrait and landscape. Bundle ID is `ai.offside.OffsideGolf`; the owner's signing team and physical-device/distribution checks are release setup. There is no Apple TV, visionOS, cloud, Game Center or third-party analytics target.
