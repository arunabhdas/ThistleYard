# OffsideGolf — gameplay specification

This document describes the current v2 gameplay implementation and identifies remaining product targets. Values are arcade tuning, not regulation-golf fidelity. Changes require fixture review and a physics/content version bump. Core uses metres, seconds, radians and `Double`; 1 yard = 0.9144 m and 1 mph = 0.44704 m/s. Authored holes use physics version 2; legacy version 1 fixtures remain supported.

## Aim and power

Aim is a normalized nonzero ground-plane vector. Reject nonfinite or near-zero input; preserve the previous valid direction. Tapping/dragging a target updates aim; accessible adjustments currently use 1° buttons. A finer 0.25° action remains a possible accessibility refinement, not a shipped control. Initial aim points at an authored safe target, not through an obstacle directly at the pin.

The swing pad captures one touch. Downward displacement / 110 points maps linearly to power, clamped to [0,1]; scale the pad to remain reachable but keep its sensitivity setting independent of screen resolution. Below 8 points cancels on release. Dragging horizontally out by more than 80 points cancels. Interrupted touches, pause, rotation and control-mode changes cancel using an input generation. Core permits aim updates while charging so precise power can be selected before final aim; aim is frozen only on release. Release creates one immutable ShotInput with shot ID, club ID, direction and power. No loft/spin fields exposed to the player in MVP. A future schema can add modifiers without dormant controls today.

The accessible mode supplies identical inputs through aim controls, a 0–100% slider and Swing. All clubs use the same power semantic; no timed accuracy window or randomized deviation. Show “Strong”, “Soft” or contextual recovery feedback only if it conveys useful information; do not imply “Perfect” timing.

## Club catalog and recommendation

| Club | Nominal full carry (yd) | Launch angle | Lie role |
|---|---:|---:|---|
| Driver | 230 | 18° | Tee and broad fairway distance |
| 5 Iron | 180 | 28° | Long approach and lower flight |
| 7 Iron | 145 | 36° | Mid-range approach |
| Pitching Wedge | 100 | 48° | High short approach |
| Sand Wedge | 65 | 58° | Bunker escape and short lob |
| Putter | 30 maximum flat roll | 0° | Precision green and fringe roll |

Nominal carry is measured on flat fairway at zero wind with power 1 and a clear flight. Calibrate base launch speed by deterministic bisection to hit the nominal landing range within 0.25 yd under the configured drag law. Power scales launch speed by sqrt(power), making carry approximately linear. Do not apply an additional generic power multiplier after calibration.

Recommendation: Putter on green, Sand Wedge in bunker, otherwise the shortest legal club that can reach the chosen landing target at ≤90% power after lie effects; if none reaches, choose the longest legal carry. Evaluate carry on current wind/elevation through the same predictor. In deep rough exclude Driver. The player may override; display expected range changes before committing.

## Flight

SimulationConfig contains gravity 9.81 m/s², horizontal drag k = 0.04/s, wind coupling b = 0.016/s, fixedStep 1/120 s, ball radius 0.02135 m, stop thresholds, terrain catalog and cup settings. Coefficients are arcade tuning values.

Horizontal motion under constant wind vector w follows dv/dt = -k v + b w. For a step t, v∞ = (b/k)w, v(t) = v∞ + (v0-v∞)exp(-kt), and x(t) = x0 + v∞t + (v0-v∞)(1-exp(-kt))/k. Handle k=0 with its constant-acceleration limit; configuration forbids negative k. Vertical motion is z(t) = z0 + vz0*t - g*t²/2, vz(t) = vz0-g*t. This deliberately omits lift/Magnus simulation. Club-specific landing retention models the chosen club's stopping character instead of simulating spin vectors.

`BallState.altitude` is height above local terrain, with zero at ground contact; flight converts to world height for integration and back after terrain queries. `ballRadius` is a collision parameter rather than a permanent launch-height offset. Sweep flight segments against water and tree volumes; ground intersections use bounded subdivision/bisection (time tolerance 0.0001 s). Apply the earliest collision and integrate the remainder, with at most four contacts per tick. The global 30-second guard bounds pathological shots; do not treat contact-loop recovery as ordinary play.

## Wind and preview

`WindCondition` stores `towardDegrees` (0° north, 90° east) and `speedMPH`, deriving an m/s velocity. The HUD arrow points toward travel; current accessible text states speed and degrees clockwise from north. Named origin/destination phrases are a remaining copy refinement. Zero wind has no directional arrow. Values are stable for the hole. Tutorial Hole 1 is calm, Hole 2 gentle, Hole 3 explicitly teaches the arrow.

The preview runs the real simulator on a copied state, cached until club/aim/power/wind changes and throttled in `GameSession` to at most 10 updates/sec with one outstanding calculation and stale-result rejection. Draw a sparse arc and an approximate first-landing circle, not an exact rollout path. Long-shot circle radius is max(2 m, 3% of carry); round distances to whole yards. It visualizes approximate guidance only; no random shot dispersion exists. Predict collision/hazard warnings from the same simulation. On greens the displayed path is short and slope arrows are optional. Exact predicted endpoints are available internally for acceptance tests; guidance polish must avoid presenting an exact putting solution as a product promise.

Shot hazard advice occupies a reserved, text-size-aware row above the aim controls. It reads “Shot may leave the course” or “Water near the landing area” as appropriate. Showing, changing or clearing this advice must not resize the panel or shift the swing pad during power calibration. Inactive advice is hidden from accessibility and cannot intercept touches; cancelling or releasing clears the preview as before.

## Terrain

| Terrain | Rolling deceleration m/s² | Normal restitution | Tangential retention | Launch-speed factor |
|---|---:|---:|---:|---:|
| Tee | 1.25 | 0.32 | 0.78 | 1.00 |
| Fairway | 1.10 | 0.30 | 0.78 | 1.00 |
| Rough | 2.50 | 0.16 | 0.58 | 0.88 |
| Deep rough | 4.50 | 0.08 | 0.38 | 0.72 |
| Green | 0.45 | 0.22 | 0.82 | 1.00 |
| Bunker | 6.00 | 0.03 | 0.22 | 0.55; Sand Wedge 0.90 |
| Water | Terminal hazard | — | — | — |
| Out of bounds | Terminal hazard | — | — | — |

Terrain queries first use material precedence: water > bunker > green > tee > fairway > deep rough > rough, then authored numeric priority, then stable region ID. Outside bounds takes precedence over all interior regions. The course bounds classify everything outside as out of bounds. Missing v2 interior coverage defaults to rough; legacy v1 fixtures default to fairway. Aerial water contact happens at the water surface, not when the ground shadow first crosses water.

Bounce reflects the incoming normal component with restitution and scales tangent velocity by retention. Landing retention is further scaled by a club stop factor: Driver 1.00, 5 Iron .96, 7 Iron .92, Pitching Wedge .88, Sand Wedge .80. Bounce becomes rolling when upward normal velocity <0.45 m/s; green cup capture is evaluated before artificial settling. Material events drive bounded visual rings and audio feedback. Terrain deformation and persistent impact marks are not implemented.

## Rolling and putting

On slopes, acceleration is projected gravity plus friction opposing velocity; fixed-step integration limits the friction impulse so it cannot reverse velocity. Flat ground uses exact stopping time/distance. At rest, cancel downhill acceleration when its magnitude is at or below the material static threshold (1.15 × rolling deceleration); otherwise begin downhill motion. The current solver settles supported motion at ≤0.025 m/s without a separate 0.25-second dwell. Momentary uphill turnaround on an unsupported slope must resume downhill rather than settle.

Putting launches directly into rolling with v = sqrt(2*aGreen*Dmax*power), Dmax is the selected frozen 3, 10 or 30 yd range converted to metres (2.7432, 9.144 or 27.432 m). This gives a linear power-to-distance relationship on flat green. Near the cup, automatically choose a finer power range with visible maximum distance (3, 10 or 30 yd); the shot input records that range so replay is exact. Show the range before commitment. The selector can change while aiming/charging; release freezes it for the entire shot and checkpoint. Putter off-green uses the same launch speed with the actual surface resistance.

Author green slopes at 0–2% for the MVP. Capture uses a forgiving radius of 0.11 m around the cup and speed ≤1.4 m/s at crossing; centre height must be at ground contact. Sweep the rolling segment through the capture disk so fast frame intervals cannot skip it. A faster crossing continues across the cup; no random lip-out or dedicated lip sound is implemented. Airborne balls can enter only on descending intersection with the cup mouth at ground contact. Visual cup/ball scale is exaggerated consistently with the capture affordance.

If a ball cannot settle after 30 simulated seconds, the reducer freezes it at its latest valid position and reports `.timedOut`. A dedicated explanatory HUD message/diagnostic presentation remains a release check. This is a recovery guard, not an accepted normal shot outcome; QA treats repeatable triggers as bugs.

## Trees and hazards

Trees have a trunk cylinder and canopy ellipsoid with authored bottom/top heights. Trunk contact reflects with restitution .25; canopy contact retains .55 velocity and deflects along a deterministic contact normal. Ignore a just-contacted canopy until the ball exits it to prevent every tick reapplying damping. Above canopy height there is no contact. Fade foreground foliage covering the ball/target, without changing collisions.

Water: contact → splash event → one penalty → valid drop → shot complete. Out of bounds uses the same one-penalty recovery for this casual game. This is an explicit simplified rule, not full tournament stroke-and-distance. A struck shot still counts separately: first stroke into water plus penalty means 2 strokes taken and “Shot 3” next.

Choose the nearest authored safe drop associated with the crossed hazard that does not move closer to the pin than the last valid crossing; tie-break by drop ID. Validate lie, bounds and obstacle clearance. If no safe configured drop satisfies that rule, return to the pre-shot ball position. Never drop into another hazard. Bounds excursions trigger only when the actual ball centre leaves playable bounds, according to authored aerial boundary policy (MVP hard boundary).

Guarded phase transitions and committed shot IDs make stroke/penalty resolution idempotent; event IDs deduplicate presentation feedback. There is no separately persisted per-shot event ledger. Restart Hole resets that hole but marks the round assisted. No automatic stroke cap in the normal MVP; Pause always offers recovery/restart.

## Scoring and completion

Hole delta = `strokeCount - par`: the stored stroke count already includes penalties, so do not add `penaltyCount` again. One stroke is “Ace”, then -3 Albatross, -2 Eagle, -1 Birdie, 0 Par, +1 Bogey, +2 Double Bogey; other results display signed numeric difference and a plain-language phrase. An ace's numeric score still depends on par. Negative totals display “under par”; unplayed holes display a dash, never zero strokes.

Capture emits `cupCapture`, disables new shots and produces a result checkpoint. `GameContainer` advances through the nine manifest holes and gates continuation while saves are pending or failed. Full-round totals include completed holes only; restart or explicit recovery marks a round assisted and excludes it from a course personal best. Practice remains ephemeral and cannot replace a saved round. Eligible practice completion updates only the per-hole best. Course and hole records are separated by course/content/physics identity; older records without version fields decode as 1/1. Current v2 results do not overwrite those historical records. Final-result durability and the complete nine-hole UI path remain explicit verification gates.

`PlayerStore` queues checkpoints in gameplay order. Round simulation waits while a committed checkpoint is saving or failed, with visible Retry. The repository saves exact reducer state, including pending shot/clocks, rather than charging a second stroke through replay. Normal resume requires matching content/physics versions; acknowledged last-settled recovery preserves score and marks the round assisted.

## Deterministic acceptance fixtures

- Flat no-wind calibrated club at full power: first landing within 0.25 yd of nominal carry.
- Same shot, configuration, terrain and tick count: same result within 1e-6 m on the same toolchain; cross-device tolerance 0.01 m. Do not claim bitwise cross-platform determinism.
- 30/60/120 Hz render schedules integrating the same simulation duration: settled position within 0.01 m and identical score/events.
- Mirrored ±x crosswinds on flat symmetric terrain: opposite lateral displacement within 0.02 m; tailwind increases carry relative to headwind.
- Flat putt at half power and 10 yd range: stop at 5 yd ±0.10 yd under initial green tuning.
- Same 3 m/s incoming roll: bunker stops before rough, which stops before fairway, which stops before green.
- A rolling ball or flight segment intersecting the water surface across a narrow strip must splash even if both rendered endpoints are dry; a high carry remains airborne.
- Cup crossing at .5 m/s inside the capture radius completes once; crossing at 2 m/s does not capture.
- A duplicated impact/splash/capture event does not duplicate strokes/penalties/results.
- Pausing, rotating or backgrounding during charging never fires a shot. Resuming flight preserves shot ID and outcome.

## Current acceptance evidence and limits

The optimized core suite currently records 63 tests, including nine default-wind holes, 17 distinct wind-limit scenarios, four aggressive routes and one intentional river-recovery scenario (31 course scenarios). Inputs are quantized to the production 1° aim and 1% power controls; every played shot is compared with the shared predictor. The conservative default sequence scores [3, 3, 4, 2, 5, 4, 3, 4, 4], totaling 32 against par 35. This demonstrates deterministic playability, not novice difficulty or UI usability. UI fixtures live in `Tests/OffsideGolfUITests/Fixtures/course-sequences.json`; the current full UI run is separate evidence.

Nominal club distance means first landing, not total rollout. Current fairway retention and club stop factors create substantial arcade rollout: on actual Hole 1, 44% 5 Iron followed by a 63% medium-range putt is a verified two-stroke core smoke path; 45% 5 Iron can capture directly. Legacy v1 fixture percentages do not transfer to the authored v2 course. Physical-device performance, subjective tuning, accessible interaction and sound/haptic feedback still require review.
