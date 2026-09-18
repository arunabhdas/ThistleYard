# OffsideGolf — art direction and asset pipeline

Current source includes generated painted sheets, a menu illustration, procedural supporting shapes and original synthesized audio. This document separates those assets from the final production target. The supplied mocks remain references, not bundled artwork. Human art approval and physical-device visual review are still release gates.

## Identity

Original pastoral illustration with coastal light, rounded foliage and human-scale details. The mocks' appeal comes from warm cream against deep green, sunlit grass, flowers, broad tree masses and a small expressive golfer. Preserve that emotional warmth without copying franchise characters, identifiable scenes or compositions.

Gameplay uses a stable 65° elevated projection. Menus may use more dramatic illustrated landscapes, but avoid presenting a horizon inside the playable ground plane. Gentle atmospheric haze and overlapping planes provide depth. Do not add labels, signs or branding to every patch of scenery.

## Palette and typography

| Token | Initial sRGB hex | Role |
|---|---|---|
| pine | #123F35 | Text, primary controls, strong outlines |
| cream | #F5F1DF | Panels and warm highlights |
| meadow | #8EBA66 | Fairway midtone |
| grassShadow | #47764D | Rough and terrain separation |
| sunlitGreen | #C4D779 | Green and light accents |
| sea | #4D929F | Water base |
| seaDeep | #2C6476 | Water depth |
| sand | #E2C58E | Bunkers |
| clay | #BF6650 | Lighthouse roof and sparse warm accents |
| mist | #CEDFD7 | Distant haze |

Colors are starting values, not prevalidated contrast guarantees. Text uses pine/cream pairings; never white fine text on light grass. Aim guides use a dark outline plus light core. Bunkers have grain and a rim, water has shore highlights/waves, rough has texture; hazard recognition never depends only on hue.

Use the system serif design for large menu titles and the system rounded/sans design for controls and numerals. SwiftUI semantic text styles enable Dynamic Type. Handwriting is optional for one short decorative tagline, not instructions or numbers. Avoid shipping an unlicensed font from a mock.

## Composition rules

- Broad terrain silhouettes before detail. Keep the intended landing lane, ball and cup free of high-frequency flowers/rocks.
- Three depth groups: distant scenic backdrop, playable terrain/objects, sparse foreground framing. Foreground fades when it occludes the ball/target.
- No mechanically repeated tile grid. Build fairways from smooth masks with a few reusable texture variations, edge tufts, asymmetrical clusters and unique landmarks.
- Warm light from upper left; soft contact shadows anchor feet, trees and ball. Ball shadow remains on the ground while the sprite rises.
- One hero landmark per hole and a shared distant lighthouse. Reuse foliage with mirrored variants only where light direction remains plausible.
- Water: small looping highlights, shoreline foam, isolated ripples and a short splash. No heavy full-screen refraction or reflection pass in MVP.
- Bunkers: irregular warm sand patches, soft rims, sparse rake texture; small impact marks can fade. No deformable terrain mesh.

## Golfer

Approximately 3.5 heads tall; readable cap, oversized shoes/hands and a compact club silhouette. Cute does not require a child identity. Use expressive posture rather than detailed facial animation at gameplay scale. Four skin palettes, three hair silhouettes and four outfit palettes are available from the start. Clothing is not gender locked. One rig/base animation set; consistent masks/tintable regions avoid multiplying entire sprite sheets for every color combination.

Eight authored body facings now provide twelve key poses each, with no mirroring. The original `golfer_poses_sheet.png` is the southeast view; seven `golfer_<direction>.png` sheets complete the set. A right-handed stance places body heading 90° clockwise from shot aim: aiming north selects an east-facing golfer standing west of the ball. `GolferAnimationController` selects poses and adds subtle breathing, practice rotation, celebration and reposition transforms. These are 96 authored key poses, not a separately drawn 12–18 fps animation sequence. Left-handed controls change layout, not golfer handedness.

| Clip | Initial duration | Key rule |
|---|---:|---|
| idle | 2–4 s loop | Low-amplitude breathing, occasional glance |
| aim | 0.25 s + hold | Feet and ball remain anchored |
| practice | 0.8 s | Never launches or scores a ball |
| backswing + downswing | 0.55 s | Impact marker at 0.55 s from committed swing start |
| followThrough | 0.35 s | Launch has already occurred |
| watchBall | Loop/hold | Ends when simulation settles |
| putt | Core-clock key pose | Current core impact is 0.55 s, shared with full swing |
| celebrate | ≤1.2 s | Small fist lift/smile; skippable |
| disappointed | ≤0.6 s | Gentle shrug, no shaming |
| reposition | 0.3 s | Brief step/fade at settled position, no input lock |

The source manifest [`ArtSource/golfer-poses-manifest.json`](ArtSource/golfer-poses-manifest.json) records the sheets, twelve-cell order and remaining review limits. [`ArtSource/directional-golfer-prompts.json`](ArtSource/directional-golfer-prompts.json) records the generation prompts and corrected variants. `GolferFacing` owns foot/nape registrations; the seven new directions use explicit approximate anchors pending final artist registration. The controller samples `GameState.swingProgress` and `activeShotElapsed`; core alone emits impact. Reduced motion suppresses decorative transforms while preserving pose/event semantics. A selective shader remaps painted skin/outfit regions; procedural cap-compatible hair overlays provide the three choices. All 48 palette/hair combinations need smallest-size and physical-device review.

## Asset families

The complete production family target includes the following; the current runtime uses the shared sheets, procedural shapes and labeled controls described below rather than separate authored sprites for every item.

Golfer body/hair/outfit layers; six club icons and in-hand club sprites; ball and shadow; trees/shrubs; grass/rough/green masks; sand; water/foam; flowers; rocks/cliffs; bridge; flag/cup; windmill, shed, lookout, arch, farmhouse, hide, pavilion, cabin and lighthouse; leaves/birds/clouds; splash/sand/grass particles; accessible UI symbols.

Use SF Symbols for initial UI affordances where suitable and original assets where the identity requires them. Club icons must be distinguished by labels as well as shape. UI panels are SwiftUI shapes/material-free opaque fallbacks where contrast requires; do not bake text into images.

## Files, naming and export

Source records stay outside the bundle under `ArtSource/`; export runtime assets into `_OffsideGolf-frontend-iOS/App/Resources/Textures/`. Production handoff is being assembled in [`ArtSource/GENERATED_ASSETS.md`](ArtSource/GENERATED_ASSETS.md), the [golfer pose manifest](ArtSource/golfer-poses-manifest.json), and runtime [`AssetManifest.json`](_OffsideGolf-frontend-iOS/App/Resources/AssetManifest.json). Generated/original describes provenance, not final approval. Retain source, method, license/rights review, revision, dimensions, pivot and review status for each export. Logical IDs such as `windmill` resolve through `ArtLibrary`; they are not file paths. More granular direction/frame filenames can be introduced when the expanded animation family exists.

- PNG RGBA, sRGB, transparent background for sprites; transparent edge colors dilated to avoid dark fringes.
- Current golfer cells are 362×362 px, in a 1448×1086 four-column/three-row sheet, rendered at 58 points with per-cell foot registration. Preserve consistent bounds and inspect at minimum gameplay size.
- Common environment sprites 128–512 px; landmarks at most 1024 px. Terrain chunks normally 1024 px or below; do not export a single enormous nine-hole texture.
- Export source at sufficient resolution for @2x/@3x output; verify sampling on actual phones. Large scene textures are sized by their maximum screen coverage and zoom, not arbitrary device scale multiplication.
- Keep at least 2–4 px extrusion/padding between packed sprite frames. Avoid prepacking multiple independent frames into one texture unless the loader records exact subrects.
- Audio source WAV 48 kHz; runtime short SFX mono where spatial stereo is unnecessary, music/ambient compressed stereo with seamless loop points. Normalize consistently and leave headroom; no clipped impact peaks.

## Runtime sheets, crops and texture budget

Current assets use shared PNG sheets rather than generated `.atlas` directories. `ArtLibrary` maps twelve environment cells in a 4×3 sheet; `GolferRenderer` maps twelve pose cells per directional sheet. These are ordinary `SKTexture(rect:in:)` subtextures. The golfer retains at most three facing sheets in an LRU cache and loads PNG data without the global `UIImage(named:)` cache. The menu uses its separate `CoastMenu.imageset` asset-catalog illustration. TerrainRenderer combines masks/shapes, painted fills and procedural details; animations remain node/controller code rather than `.sks` scenes.

`SKShapeNode.fillTexture` sampled the full backing sheet instead of respecting packed subtexture UV rectangles, causing neighboring terrain materials to appear inside masks. The implementation crops the 2×2 terrain sheet into four independent 627×627 CGImages and creates standalone textures for shape fills. Environment/golfer sprite subrects remain shared. Grass fills receive a low-contrast color wash so their painted blades read as distant surface texture, not oversized objects. Keep this distinction when changing the asset loader: replacing terrain crops with sheet subrects reintroduces the visual defect.

The following estimates come from actual PNG dimensions, assuming one four-byte RGBA plane and excluding compression, mipmaps, CPU/GPU duplication and framework overhead:

| Runtime image | Pixels | One RGBA plane |
|---|---:|---:|
| `coast_menu.png` | 1536×1024 | 6.000 MiB |
| `coast_environment_sheet.png` | 1448×1086 | 5.999 MiB |
| `golfer_poses_sheet.png` | 1448×1086 | 5.999 MiB |
| Seven additional golfer sheets | 7 × 1448×1086 | 41.995 MiB total; at most three golfer sheets retained by the renderer |
| `terrain_sheet.png` | 1254×1254 | 5.999 MiB |
| Four independent terrain crops together | 4 × 627×627 | 5.999 MiB |

All source images total about 66 MiB of uncompressed planes; separately materialized terrain crops add about 6 MiB. With three golfer sheets retained instead of all eight, the intended active image-plane subtotal is about 42 MiB including menu, environment and terrain/crops. This is an accounting estimate, **not measured resident texture memory**: CGImage backing sharing, retained scenes, SpriteKit uploads, deferred releases and mipmaps change actual cost. The app icon is not a scene texture and is excluded. Retain the 96 MiB texture target and measure on baseline hardware with Instruments/Metal tools before declaring budget compliance.

`ArtLibrary.preload()` preloads environment and ground textures. Do not assume all asset families or next-hole preparation are preloaded merely because the helper exists. Reusable node factories use immutable placement data; collision geometry remains in hole JSON, not an artist-authored scene file. Expand atlas families only when asset volume and measured residency justify it.

## Audio source and exports

[`ArtSource/Audio/generate_audio.py`](ArtSource/Audio/generate_audio.py) synthesizes the original effects/music/ambience with deterministic NumPy processing and FFmpeg export. Eight short effects are mono WAV; four loop masters are stereo 48 kHz PCM WAV outside the app bundle, exported as lossless ALAC M4A runtime files. [`App/Resources/Audio/provenance.json`](App/Resources/Audio/provenance.json) records method, duration, peak and checksums. No third-party recording or composition is embedded. The sparse 48-second music loop includes long silence; this is the current intermittent-music mechanism, not a generative music scheduler.

`AudioManager` applies independent music/ambient/SFX/UI levels, limits one-shot voices, deduplicates semantic events and respects interruption/background state. `.ambient` mixing follows silent-mode behavior; haptics have independent opt-out. Physical-device listening, loop comfort, balance, actual silent-switch behavior and tactile review remain required even when policy tests and asset decoding pass.

## Production stages and quality gate

1. Greybox terrain and original vector placeholders establish readable play. Mark their status in the asset manifest.
2. Approve one representative hole's ground, golfer and vegetation at actual gameplay size.
3. Replace shared placeholders with cohesive original assets; verify every animation direction and palette combination.
4. Dress all nine holes using shared families and one unique landmark each. Review portrait/landscape safe areas.
5. Add restrained ambient motion and audio, then profile on baseline devices.
6. Release review: no placeholder status, missing license record, visible seams, illegible controls, ball occlusion, repeated obvious tile pattern or excessive visual motion.

The painted menu/environment/terrain/eight-facing golfer family replaces the original all-procedural presentation, while supporting geometry, UI and effects remain procedural. Final production approval still requires palette/registration review, comfortable pose transitions and the physical-device release checks above. Reference PNGs and questionnaire screenshots remain excluded from the app bundle.
