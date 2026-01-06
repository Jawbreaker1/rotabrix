# Tasks

Investigate and update each item with findings and next actions.

## P0
- [ ] Small watch screens: layout feels too large and cramped on small Apple Watch sizes; brick height scaling looks off. (Scaling pass implemented for sizes and speeds; needs device validation.)

## P1
- [ ] Rotation near paddle: during rotation, the ball can end up behind or pass through the paddle when close to it. (Paused physics through finishRotation; needs validation.)
- [ ] Difficulty settings: add easy/normal/hard modes and tune parameters per mode. (Implemented speed/score multipliers; needs playtest.)
- [ ] Audio and music: add momentary SFX and haptics (hits, drops, rotation, countdown); check for crackle on simulator.
- [ ] Balance: tune ball speed ramp, drop rates, and gun cadence on device; verify top-row spacing across watch sizes.
- [ ] HUD polish: refine score/multiplier FX, add hit/miss/drop feedback, wire haptics.
- [ ] Performance validation: profile particle-heavy moments (explosions, lasers, fireworks) on real hardware.
- [ ] Testing: add unit tests for level generator (fill rules, seeding), geometry helpers, scoring math.
- [ ] Music volume control: retest start-screen crown volume HUD clamp on hardware to ensure no edge wrap/stickiness.
- [ ] UI positioning experiments: revisit gear placement and settings close button positioning after device verification.

## Investigation Notes
- Small watch screens: current sizing is mostly fixed (paddle, ball, drops, brick spacing/heights, HUD) so smaller screens get the same pixel sizes as Ultra; LevelGenerator clamps brick cell height to 24 and brick height to 18, so bricks never scale down (e.g., 136x170/38mm and 205x251/Ultra both end up at 18px brick height); HUD status background height is fixed at 56, which eats a large share of the vertical playfield on compact sizes.
- Small watch screens: added an Ultra-based scale factor (min dimension ratio, max 1.0) and applied it to gameplay sizes + speeds; needs device/simulator verification on smallest sizes. SwiftUI overlays (start/game over/high score/settings) are not scaled yet.
- Rotation near paddle: finishRotation repositions the paddle (applyPaddleLayout) after rotation while physics is active and without adjusting ball positions relative to the new paddle edge; combined with bounds swapping for landscape, this can move the paddle relative to the ball and leave the ball behind/inside the paddle.
- Difficulty: settings now persist easy/normal/hard; easy scales speed/score to 0.5x, hard scales to 1.5x. Needs balancing on device.
