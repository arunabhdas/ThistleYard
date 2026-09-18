# OffsideGolf — final product decisions

Approved through 28 individual questions on 2026-09-17. These decisions take precedence over illustrative examples in `PROMPT.md` and text baked into the mocks.

| # | Answer | Agreed decision |
|---|---|---|
| 1 | B | Fixed elevated 60–70° view; camera follows and zooms without changing pitch. |
| 2 | B | 2.5D layered painted sprites, subtle parallax, soft shadows. |
| 3 | B | Preserve the mocks' palette, illustration character and rounded panels; simplify gameplay branding and controls. |
| 4 | D | iPhone and iPad initially; Apple TV and visionOS explicitly deferred. |
| 5 | C | Portrait and landscape on both device families. |
| 6 | A | Swift, SwiftUI, SpriteKit; GameplayKit only if useful, AVFoundation, lightweight local persistence; GameKit later. |
| 7 | B | Semi-realistic casual golf with forgiving execution and believable physics. |
| 8 | A | Approximately 2–3 minutes per hole and a resumable 15–25-minute round. |
| 9 | B | Aim first; pull back and release in a dedicated lower-screen swing area. |
| 10 | A | Aim, power and club only; club defines loft/spin response; no timing-based mishits. |
| 11 | B | Approximate flight arc and landing circle accounting for wind/elevation, with subtle hazard warnings. |
| 12 | B | Six clubs: Driver, 5 Iron, 7 Iron, Pitching Wedge, Sand Wedge, Putter. |
| 13 | C | Automatic club recommendation with manual override. |
| 14 | B | Believable arcade launch, drag, wind, bounce, terrain friction, gentle slopes, bunkers and water penalties. |
| 15 | B | Gentle putting slopes, optional arrows and fine power control using the same gesture. |
| 16 | B | Nine independently loaded holes with shared scenery and landmarks. |
| 17 | B | Whispering Coast: cliffs, meadows, gardens and a signature lighthouse. |
| 18 | B | Gradually introduce mechanics, then combine them on later holes. |
| 19 | C | Simple trunk and canopy collisions; sufficiently high shots clear trees. |
| 20 | B | One base golfer; a small selection of skin tones, hairstyles and outfit colors; no gender-locked clothing. |
| 21 | B | Mock-inspired 3–4-head proportions; essential expressive animations and brief repositioning. |
| 22 | A | Develop original art/audio alongside gameplay; track and replace placeholders. |
| 23 | A | One-time paid download; no ads or in-app purchases. |
| 24 | A | Scores, scorecards, per-hole/course personal bests and replayable holes; no XP or stars. |
| 25 | A | Intermittent gentle music, birds/wind/water, detailed effects/UI sounds, subtle haptics; no crowds. |
| 26 | A | Game Center in phase 2. |
| 27 | A | Complete local saves after completed shots; cloud later. |
| 28 | A | VoiceOver where practical, Dynamic Type menus, reduced motion, contrast guides, non-color hazards, redundant feedback, left-handed controls, untimed slider/button alternative. |

## Engineering assumptions

These are implementation defaults, not additional user answers. They can change through measured testing without reopening the product questionnaire.

- iOS/iPadOS 17 minimum, Swift 6 language mode; verify using the installed Xcode 26.5 toolchain. Baseline performance devices: iPhone 12 and iPad 9th generation. Simulator results do not establish device performance.
- Use 65° orthographic-style projection, SI units in simulation and yards/mph in the initial English UI. Keep unit conversion at the presentation boundary.
- One local profile and one resumable round; practice holes do not replace the round or count toward a full-course personal best.
- Whispering Coast totals par 35 and 2,848 yards. Distances and physics coefficients are initial tuning values, versioned with content.
- Cosmetic choices are available immediately: four skin palettes, three hair silhouettes, four outfit palettes. No cosmetic economy.
- Local play requires no account or network. No third-party analytics, remote configuration or monetization SDK in the MVP.
- M0 is a launch/course-preview foundation, not playable golf. Each later milestone adds a working vertical slice; do not imply final art, performance or release readiness before verification.

## Scope guardrails

The mock's XP level, locked future courses, angle dial and repeated slogans are not requirements. Remove them from the MVP. Keep the leaf motif and warm voice, use the tagline only on the main menu, and show numeric score explanations alongside golf terminology.

The approved 2.5D view cannot reproduce the mocks' deep perspective and horizon while keeping accurate scale everywhere. Use a coherent elevated projection for play; reserve more dramatic landscape compositions for menu illustrations.
