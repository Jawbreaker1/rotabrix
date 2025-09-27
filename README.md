# Rotabrix Dev Status

This document captures the current state of the Apple Watch brick-breaker prototype as of this Codex session so we can pick up quickly next time.

## What’s Implemented (2025-09-23)
- **Start experience**: Full-screen SwiftUI start overlay with neon title, high-score tracking via `@AppStorage`, and a dedicated start button; scoreboard, bricks, paddle, and ball hide automatically until play begins.
- **SwiftUI + SpriteKit core**: Watch app launches into `GameScene` with Digital Crown + touch controls mediated by `GameController`.
- **Procedural bricks**: `LevelGenerator` seeds 6×6 layouts across standard/tough/explosive/unbreakable tiles with playfield-aware spacing.
- **Gameplay loop**: Paddle easing, ball physics, scoring, streak multipliers, lives, level transitions, and 90°/180° rotations with freeze and velocity remap.
- **HUD + effects**: Compact scoreboard HUD, gradient background, three-layer starfield, neon brick palette, paddle and ball FX groundwork.

## Known Issues / TODO
1. **Paddle orientation bug** – After rotations the paddle still snaps to the original bottom edge and life-loss detection misses the rotated “down” side. Orientation math in `currentPaddleEdgeLayout` needs a rewrite.
2. **Rotation physics polish** – Ball velocity can stall after several bounces or rotations; enforce a higher post-rotation minimum and adjust paddle deflection for orientation.
3. **Starfield contrast** – Particle layers are still faint on device; revisit blend modes, alpha, and layering once gameplay bugs are fixed.
4. **Corner clearance** – Paddle can tuck into rounded corners at extremes; revisit `paddleLaneInset` / `paddleEdgeInset` or paddle width.
5. **Input sync** – Minor lag when alternating Digital Crown and touch, likely due to crown value re-centering.

## Next Steps
1. Fix paddle orientation/life detection after rotations (focus on `GameScene.finishRotation`, `currentPaddleEdgeLayout`, and related life-loss logic).
2. Re-tune velocity preservation across rotations and paddle impacts; add min-speed guard after rotations.
3. Iterate on starfield/gradient contrast once gameplay alignment is resolved.
4. Validate paddle clearance on 49 mm hardware or simulator; adjust Insets or paddle size accordingly.

## Testing Notes
- Still no automated tests. Build/run with `xcodebuild -project Rotabrix.xcodeproj -scheme 'Rotabrix Watch App' -destination 'generic/platform=watchOS Simulator'` (requires full Xcode toolchain).
- Manual verification on Apple Watch Ultra 2 simulator recommended to reproduce orientation bug and confirm start screen transitions.

Refer to `agent.md` for the broader roadmap when resuming development.
