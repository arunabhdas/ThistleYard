# OffsideGolf — product requirements

Status: agreed product direction; implementation proceeds by milestones in `IMPLEMENTATION_PLAN.md`. `DECISIONS.md` records all answers. This document describes the release target, not the current implementation.

## Vision and audience

OffsideGolf is a delightful, premium casual golf game: small swings, brighter days. A player should understand a first shot within seconds, enjoy the landscape between decisions and improve through aim, club choice, power and reading the course. Target adults and families seeking a calm short-session game, including people unfamiliar with golf vocabulary. No timers, random execution failures, purchase pressure or social obligations.

The original visual identity combines warm sunlight, rich greens, rounded vegetation, painted textures and small expressive actions. References are the nine supplied mocks; no franchise characters, copied scenes or recognizable protected designs.

## Platforms and constraints

- iPhone and iPad; portrait and both landscape directions. iPad also supports upside-down portrait and resizable windows. Layout follows usable geometry rather than device-name checks.
- iOS/iPadOS 17 minimum; Swift 6, SwiftUI menus/HUD, SpriteKit rendering, Foundation domain models and AVFoundation audio.
- Paid download, offline first, no ads, purchases, backend or login. Apple TV/visionOS are future adaptations, not current build targets.
- Aim for 60 FPS on baseline hardware. Fast transitions, low latency and thermal stability must be measured on devices before release.

## Core experience

Choose or confirm club → aim → read distance/wind → set power → release → synchronized golfer impact and ball launch → camera tracks flight and landing → ball bounces/rolls → next-shot setup → putt → hole result → scorecard/next hole.

Count a played stroke at committed impact. Show “Shot 2” while preparing the second shot and “Strokes 1” where completed strokes are displayed. Penalties are separate score events; update the displayed total immediately. Do not defer stroke bookkeeping until the ball stops.

Each hole takes roughly 2–3 minutes; nine holes target 15–25 minutes. Save after every completed shot and allow resuming across app restarts. Hole intros last at most 2 seconds and are skippable; automatic celebrations at most 1.5 seconds before the player can continue.

## MVP scope

| Area | Release requirement |
|---|---|
| Golf | Six distinct clubs; aim and power; stable per-hole wind; approximate preview; deterministic flight, bounce, roll and putting. |
| Terrain | Tee, fairway, rough, deep rough, green, bunker, water and out of bounds; slopes; simple trunk/canopy obstacles. |
| Content | Nine authored, independently loaded Whispering Coast holes; coherent landmarks and increasing difficulty. |
| Character | One base golfer, limited immediately available customization, essential synchronized animation set. |
| Feedback | Ball shadow/trail, readable wind, impact/landing/cup sounds, subtle optional haptics, calm short reactions. |
| Progress | Standard numeric golf scoring, scorecards, personal bests, individual-hole practice. |
| Reliability | Versioned local saves, recoverable load errors, safe lifecycle interruptions, settings persistence. |
| Accessibility | Baseline listed below, designed into controls and overlays. |

No manual loft/spin controls, timing meter, “Perfect” rating, XP, stars, purchasable items, club upgrades, daily challenges or multiplayer.

## Controls and HUD

Aim by dragging a target marker on the course or adjusting accessible aim controls. A dedicated swing pad captures a backward drag, shows 0–100% power and shoots on release above a dead zone. Horizontal motion inside the pad does not change aim. A cancel region and explicit Cancel button prevent accidental shots. Lock club/aim during charging; rotation, backgrounding and pause cancel an uncommitted drag without a stroke.

Offer equivalent untimed controls: aim adjustment, power slider, club picker and Swing button. This mode follows the same shot model and scoring. Mirror the pad/club panel for left-handed preference without reversing aiming or wind directions.

Portrait: small top row (hole/par, wind, pause), distance by target, bottom club chip and swing pad. Landscape: top status row, narrow thumb panel at the chosen side, leaving the course unobscured. Large iPad windows cap control widths rather than stretching buttons. HUD never displays a permanent angle dial or oversized logo.

Club recommendation considers lie, achievable carry and target distance. Manual selection remains until the shot finishes or the player requests the suggestion again. Approximate trajectory uses actual physics but deliberately coarsens presentation; its landing circle represents guidance resolution, not hidden randomness.

## Screens and navigation

| Screen | MVP behavior |
|---|---|
| System launch | Lightweight static cream/leaf treatment; no mandatory splash delay. |
| Main menu | New Round, Continue only when a save exists, Practice, Golfer, Settings. One tagline. |
| Course overview | Whispering Coast summary and nine holes. No empty future-course cards; a multi-course picker is unnecessary. |
| Golfer | Small set of appearance choices, preview, accessible names and selected states. |
| Hole intro | Name, par, length, one useful tip; short overview and Skip. |
| Gameplay | Responsive HUD and course; no separate loading spinner during a normal shot. |
| Pause | Resume, Settings, Restart Hole, Quit to Menu; confirm destructive replacement of current progress. |
| Hole complete | Strokes, par, plain-language result (e.g. “Birdie · 1 under par”), Next Hole and Scorecard. |
| Scorecard | Per-hole par/strokes/difference, total, unfinished markers; no score assigned to unplayed holes. |
| Course complete | Full result, best-score comparison, replay/practice/menu. |
| Settings | Four volume groups, haptics, controls, reduced effects, aiming contrast, slope arrows, tutorial replay. |

New Round asks before replacing an existing round. Practice uses a separate ephemeral session and keeps the saved round. Restarting a hole marks the round as assisted; it remains finishable but cannot replace an unassisted course record.

## Course and tutorial

See `COURSE.md` for nine complete briefs and diagrams. Hole 1 teaches aim/power/release with no dangerous required carry. Hole 2 introduces club changes. Hole 3 introduces meaningful wind. Later holes add bunkers, recovery, water carry, slopes and combined route choices. Prompts are anchored to the relevant control, advance after successful actions and can be skipped/replayed. A failed shot provides a brief useful hint, never a scolding message.

## Art, audio and accessibility

See `ART_DIRECTION.md` for palette, composition, exports, atlas budgets and asset ownership. Placeholder art is tracked explicitly; final art cannot be inferred from a functional prototype.

Audio groups: music, ambient, SFX and UI. Intermittent music leaves space for birds, wind and shoreline sounds. Pool short effects; crossfade ambience between biomes. Honor interruptions, volume settings and silent-mode policy; choose ambient/mixing audio session behavior for this casual game. No microphone permission. Haptics occur at impact, water, cup and major actions, with independent opt-out and a no-op fallback on unsupported devices.

Accessibility baseline:

- VoiceOver labels, logical focus, adjustable aim/power, club descriptions and discrete shot-result announcements. Avoid reading per-frame position changes. Full nonvisual route navigation is not a launch guarantee.
- Dynamic Type menus through accessibility sizes with scrolling; HUD provides expandable readable details instead of clipped text.
- Touch targets at least 44×44 points; no required timed action or multi-finger gesture.
- Reduced motion removes parallax, intro travel, camera emphasis and celebrations; essential ball tracking uses short, restrained transitions.
- Contrast mode provides an outlined aim line and target; hazard symbols/text supplement color. Test normal text at 4.5:1 and large text/meaningful graphics at 3:1.
- Left-handed placement and untimed control alternative; audio/haptics never carry unique information.

## Release acceptance

1. A new player can make the first shot within 30 seconds without reading a manual; validate with at least five first-time testers.
2. All nine holes can be completed, paused, resumed and scored correctly in both orientations on iPhone/iPad.
3. Identical shot inputs/content versions produce trajectories within the tolerances in `GAMEPLAY.md`; presentation refresh rate cannot alter outcome.
4. Hazards, tree collisions, putting and penalties satisfy automated boundary tests. No double counting on duplicate events.
5. Saves survive force termination after settled shots; a corrupt current save can recover from a last-good backup without silent deletion.
6. VoiceOver menu/control walkthrough, accessibility text-size pass, reduced-motion pass and non-color hazard identification pass on actual devices.
7. On iPhone 12/iPad 9 at normal thermal state: sustained 60 FPS target, p95 frame time ≤16.7 ms over a representative 10-minute route; no recurrent >33 ms spikes outside loading. Log misses and optimize before claiming compliance.
8. Cold launch to interactive menu ≤2 seconds, cached hole transitions ≤1 second, peak working set ≤250 MB and texture budget ≤96 MB on baseline devices; measure release builds. These are budgets, not current measurements.
9. No unresolved crash, scoring loss, save loss, stuck ball or inaccessible required action. No placeholder asset or unlicensed asset in the release bundle.
10. Archive/signing, physical-device smoke, privacy/store declarations, app icon, screenshots and TestFlight processing pass the M13 gate.

## Phase 2

Additional courses, expanded cosmetics, weather, challenges, Game Center achievements/leaderboards, iCloud sync, replay/ghosts, Apple TV controls and visionOS presentation. Reassess club upgrades carefully: changing ranges can invalidate course balance and records. No phase-2 service or UI is implemented speculatively.
