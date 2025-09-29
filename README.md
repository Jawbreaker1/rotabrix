# Rotabrix Dev Status

This document captures the current state of the Apple Watch brick-breaker prototype as of this Codex session so we can pick up quickly next time.

## What’s Implemented (2025-09-28)
- **Start experience**: Full-screen SwiftUI start overlay with an oversized neon logo, hi-score tracking via `@AppStorage`, and animated transitions as the playfield fades in.
- **Core gameplay**: SpriteKit scene with Digital Crown + touch controls, paddle easing, ball physics, streak multipliers, lives, seeded level layouts, and 90°/180° playfield rotations that freeze physics and remap controls safely.
- **Drops & power-ups**: Procedural bricks now roll for extra life, multiball, paddle grow/shrink, forced rotation, gun (laser) mode, and point bundles (100/1k/10k). Drops animate toward the paddle, respect playfield rotation, and trigger HUD messaging.
- **Gun mode**: Paddle fires neon laser beams for five seconds; beams copy the retro glow treatment, destroy bricks on impact, and integrate with the existing scoring/drop pipeline.
- **Visual polish**: Gradient backgrounds per level, parallax stars, neon brick halos, ball halo/trail, laser impact FX, and updated start-button styling to reinforce the 80s sci-fi aesthetic.
- **Resilience improvements**: Ball respawns cancel stalled velocity cases, life loss resets temporary paddle modifiers, and multiball tracking removes extra balls cleanly.

## Known Issues / TODO
1. **Build environment warning** – `xcodebuild` currently fails on machines without Rosetta because the watch simulator still requests the x86_64 runtime (`WATCH_SIMULATOR_PATH` message). Install Rosetta or switch to an arm64-only sim config.
2. **Drop balance** – Spawn rates, fall speed, and laser pacing need tuning after on-device testing; current values are placeholders.
3. **HUD feedback** – Score and multiplier still update statically. Need animations and audio/haptic cues to sell big moments.
4. **Performance validation** – Particle-heavy scenes (explosions, lasers, stars) still need profiling on real hardware to confirm frame budget.

## Next Steps
1. Resolve the simulator/Rosetta dependency so CI and local builds pass without manual intervention.
2. Playtest on device to tune drop probabilities, gun cadence, and paddle resize durations.
3. Layer in HUD animations plus audio/haptics for hits, drops, and laser fire.
4. Author unit tests around geometry helpers (drop spawning, laser collision math) and add automation for the level generator.

## Testing Notes
- No automated tests yet. Primary build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rotabrix.xcodeproj -scheme 'Rotabrix Watch App' -destination 'generic/platform=watchOS Simulator' build`.
- Recent runs on this machine fail with `WATCH_SIMULATOR_PATH` because Rosetta isn’t installed; re-run after adding Rosetta or on native arm64 simulators.
- Manual verification on an Apple Watch Ultra 2 simulator is still recommended to feel rotation → drop → laser interactions and assess visual balance.

Refer to `agent.md` for the broader roadmap when resuming development.
