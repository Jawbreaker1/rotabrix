# Rotabrix Dev Status

This document captures the current state of the Apple Watch brick-breaker prototype as of this Codex session so we can pick up quickly next time.

## What’s Implemented (2025-12-01)
- **Start/high-score flow**: Start overlay, countdown into play, and a high-score celebration screen with fireworks before returning to start.
- **Core gameplay**: SpriteKit scene with Digital Crown + touch controls, paddle easing, ball physics, lives, seeded layouts, and 90°/180° rotations that freeze physics safely. Ball speed ramps per level; bricks fill the top three rows with deterministic but varied patterns (≥50% filled) and even spacing in portrait.
- **Scoring flair**: Dramatic multiplier bumps, boosted score pop for medium/large hits, tougher-brick nudge animation on ball hits, paddle hit “vibration,” and high-score tracking.
- **Drops & power-ups**: Extra life, multiball, paddle grow/shrink, forced rotation, gun mode, and point bundles with HUD messaging and rotation-aware collection.
- **Visual polish**: Gradient backgrounds per level, parallax stars, neon brick halos, ball halo/trail, laser FX, and celebratory fireworks for highscores.
- **Resilience improvements**: Countdown anchors the ball cleanly (no pre-launch wiggle), underside paddle scrapes exit outward, stalled-velocity recovery, and clear additional-ball cleanup.
- **Crown controls**: Smoothed deltas and noise filtering keep paddle motion predictable across simulator/hardware.

## Known Issues / TODO
1. **Audio & music** – Need to import/start loops for start screen and gameplay (via `WKAudioFilePlayer`), plus momentary SFX/haptics (hits, drops, rotation, countdown). Still some historical reports of simulator crackle to recheck once audio is in.
2. **Balance** – Tune ball speed ramp, drop rates, and gun cadence on device; ensure top-row spacing stays readable across watch sizes.
3. **HUD polish** – Further refine score/multiplier FX, add hit/miss/drop feedback, and wire haptics.
4. **Performance validation** – Profile particle-heavy moments (explosions, lasers, fireworks) on real hardware.
5. **Testing** – Add unit tests for level generator (fill rules, seeding), geometry helpers, and scoring math.

## Next Steps
1. Integrate background music loops (start + gameplay) with `WKAudioFilePlayer`, mixing allowed, and add basic SFX/haptics for hits/misses/rotations.
2. Playtest on hardware: confirm ball speed ramp, brick spacing legibility, underside scrape fix, and countdown anchoring feel.
3. Balance passes on drop probabilities and gun timing; verify >50% brick fill per row still holds across watch sizes.
4. Add targeted unit tests for seeded level layouts and scoring/multiplier increments.

## Testing Notes
- No automated tests yet. Primary build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rotabrix.xcodeproj -scheme 'Rotabrix Watch App' -destination 'generic/platform=watchOS Simulator' build`.
- Latest build succeeds locally; rerun after gameplay tweaks to ensure the watch target stays green.
- Manual verification on an Apple Watch Ultra 2 simulator (and real watch where possible) is still recommended to feel rotation → drop → laser interactions and assess visual balance.

Refer to `agent.md` for the broader roadmap when resuming development.
