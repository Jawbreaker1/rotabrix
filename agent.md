Rotabrix – Agent Brief
======================

Purpose
-------
Act as the live reference for anyone (human or AI) contributing code to Rotabrix. Capture the core promise, success metrics, and active priorities so contributors can decide what to build next without re-reading every document.

Game Snapshot
-------------
- Platform: watchOS app written in SwiftUI + SpriteKit, targeting 60 FPS on modern Apple Watch hardware.
- Core loop: launch, break bricks, collect/avoid drops, rotate the playfield as a signature twist, restart fast.
- Tone: neon, high-contrast visuals with premium feel (tight haptics, responsive paddle, readable ball trail).

MVP Outcomes
------------
1. **Feel** – Paddle responds smoothly to Digital Crown input with easing; ball physics are arcade-fast but fair.
2. **Signature** – Rotation events freeze physics briefly, remap controls, and never cause cheap deaths.
3. **Replayability** – Procedural level generator with seeded Daily mode and score tracking for short sessions.

Active Milestones
-----------------
1. **Tech Spike** – Stand up the watchOS project, SpriteKit scene, and Crown-driven paddle prototype.
2. **Gameplay Core** – Implement ball physics, collision handling for three brick types, scoring, lives, and basic HUD.
3. **Rotation System** – Add 90°/180° rotation events with animation, control remap, haptics, and safety window.
4. **Polish Layer** – Particle effects, audio hooks, difficulty ramps, and performance validation on device.

Non-Negotiables
---------------
- Maintain high legibility (ball halo/trail, uncluttered layout).
- Keep frame times low; profile SpriteKit nodes and reuse assets.
- Respect accessibility: high-contrast option, Reduce Motion variants, color-blind palettes.
- Instant restart flow; minimal friction between runs.

Workflow Notes
--------------
- Use Swift Packages or Xcode project groups to separate SpriteKit gameplay logic from UI shell.
- Prefer deterministic systems (seeded randomness) so Arcade and Daily modes share infrastructure.
- Author tests where practical (geometry utilities, generators). Visual systems rely on device testing later.
- Document complex systems in `docs/` (e.g., level generation, rotation logic, scoring formulas).

Current Files & Directories
---------------------------
- `README.md` – High-level vision and feature catalog.
- `docs/` – Deep dives per subsystem (seeded generation, effects, etc.). Create a new file per topic when scope grows.
- `Sources/` – Swift source once development begins. Organize into `App`, `GameCore`, `Systems`, `UI`.
- `Tests/` – Unit tests (use XCTest). Mirror `Sources/` structure.

Next Setup Tasks
----------------
- Flesh out the `docs/` directory with dedicated design briefs as systems come online.
- Initialize Swift package or Xcode project skeleton under `Sources/` once ready to code.
- Align on licensing before repo goes public.

