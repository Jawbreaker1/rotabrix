Rotabrix

A fast, colorful brick‑breaker for Apple Watch with Digital Crown precision and a signature twist: the playfield can rotate by 90°/180° (sometimes as a power‑up, sometimes as an “anti‑bonus”). The aim is short, intense runs that make you want to hit one more round.

## Current Status – 2026‑01‑02 Codex Session
- Build succeeds in the watchOS simulator; start → countdown → play flow is in place, with a high-score celebration screen and fireworks before returning to start.
- Gameplay now scales sizes and speeds to smaller watch resolutions using the Ultra as the reference size.
- Settings now include difficulty (Easy/Normal/Hard) that adjusts ball speed and score payouts.
- Rotation handling keeps physics paused through layout updates to avoid paddle/ball mismatch near rotation.
- Targeting a 1.0.1 release after device validation on small screens.

⸻

Vision & Goals
	•	Short sessions: 45–120 seconds is the sweet spot; some runs may go longer, but pace should encourage quick retries.
	•	High legibility: the ball is always extremely visible (contrast, halo, trail). No clutter that obscures gameplay.
	•	Neon / sci‑fi look: 80s‑inspired glow, parallax stars + subtle gradient/vignette.
	•	One‑more‑run: instant restarts, smart difficulty ramp, daily variation.

Platform & Tech (overview)
	•	watchOS (SwiftUI shell + SpriteKit playfield).
	•	60 FPS when possible. Haptics on hits, power‑ups, misses, level transitions.
	•	Digital Crown for paddle (with easing/inertia). Adjustable sensitivity.

⸻

Game Modes
	•	Arcade: endless progression, increasing speed/difficulty.
	•	Daily: seeded layout of the day (all players share the same seed each day).
	•	(Optional) Blitz 60: exactly 60 seconds — maximize score within the time limit.

Core Loop
	1.	Start → generate a seeded level.
	2.	Play: break bricks, collect/avoid drops.
	3.	Level clear or life lost → quick transition → next level or instant restart.
	4.	Scoring, multipliers, and daily goals keep the loop addictive.

⸻

Controls
	•	Digital Crown = paddle movement along the screen’s bottom edge (after rotation, Crown input is remapped to the new axis).
	•	Easing: the paddle follows target position with a touch of damping — premium feel without sluggishness.
	•	Instant Restart: a fast gesture/press (TBD) to immediately retry.

Rotation Twist (signature)
	•	Event/power‑up: the world rotates ±90° or 180°.
	•	Fairness: short physics freeze (≈0.3–0.4 s); the ball cannot die during the animation; the paddle snaps to the new “bottom” edge.
	•	Telegraphing: clear icon + appropriate haptic (e.g., directional cues for ±90°, a stronger pulse for 180°).

⸻

Scoring & Multipliers
	•	Base points: per brick (higher for tougher bricks).
	•	Streak multiplier: hit X bricks without a miss → multiplier increases.
	•	Finesse bonus: near‑edge paddle hits (skill shots) grant extra points and optional spin.
	•	Chain reactions: lasers, multiball, and explosive bricks can cascade for bonus.

Brick Types & Drops
	•	Standard / Tough / Unbreakable (unbreakable for lane shaping and pacing).
	•	Explosive bricks: detonate on hit and damage/destroy adjacent bricks; can chain into nearby explosives for satisfying bursts.
	•	Moving bricks (later levels) to add variety.
	•	Drops: some destroyed bricks release items that fall toward the paddle.

Power‑ups (positive)
	•	Expand: wider paddle for a short time.
	•	Magnet: paddle can catch the ball (tap to release) — used sparingly.
	•	Multiball: spawn 2–3 balls.
	•	Laser: vertical shots (ammo‑limited).
	•	Pierce: first collision passes through.
	•	Slow‑Mo: brief slow‑motion (ball remains highlighted).
	•	Shield: one‑time safety net behind the paddle.

Anti‑bonuses (avoid)
	•	Rotate: immediate ±90°/180° rotation.
	•	Shrink: smaller paddle.
	•	Speed‑Up: sharp ball acceleration.
	•	Reverse: temporarily inverted Crown input.
	•	Bomb: hazardous area effect (punishes greedy catches).

⸻

Level & Layout Generation
	•	Seeded pseudo‑random per level; weighted patterns (rows, diagonals, islands, gaps).
	•	Progression: denser bricks, more tough/unbreakable blocks, and occasional movers at higher levels.
	•	Fairness: guaranteed start channel so the first return isn’t unfair.
	•	Rare specials: e.g., gold bricks (high points), explosive variants, teleporters (TBD).

Difficulty Curve & DDA
	•	User-selectable difficulty (Easy/Normal/Hard) scales base ball speed and score payouts.
	•	Tempo ramps gradually (ball speed, drop frequency).
	•	Drop rates adapt to performance (friendlier after an early miss, harsher under long streaks).
	•	No bosses — focus on flow within short sessions.

⸻

Art Direction
	•	Palette: dark space base (blue/black) + 2–3 neon accent colors (teal, magenta, yellow).
	•	Parallax stars: 2–3 layers (slow/medium/fast) + rare meteors.
	•	Gradient & vignette: subtle gradient wash + soft vignette for depth.
	•	Ball: white core + soft neon halo (additive blend) + clear trail for motion readability.
	•	Bricks: small edge highlights + inner shadow; “damaged” variants for multi‑hit types.
	•	UI: minimal, high‑contrast, unobtrusive.

Effects & Particles
	•	Collision sparks: quick, bright particles on wall/paddle contacts.
	•	Brick explosions: shards + glow dust (fast decay); explosive bricks trigger area damage and can chain.
	•	Ball trail: short‑lived trail that helps track high‑speed motion.
	•	Reduce Motion: swap heavy effects for gentle fades if enabled in system settings.

Audio & Haptics
	•	Haptics:
	•	Light for normal hits, medium for power‑ups, strong for life loss/180° rotation.
	•	Audio: start + gameplay music loops ship in `Rotabrix Watch App/Audio` (`StartScreen.mp3`, `Gameplay.mp3`) and play with `.ambient` session (respects silent mode). SFX still to be added (pew/laser/neon ticks).

Audio Files
	•	Place music in `Rotabrix Watch App/Audio/` (filenames above). Already bundled in the project.

⸻

Watch UX
	•	Instant Restart on miss or level clear.
	•	Short, meaningful sessions; keep menus minimal.
	•	Sensitivity slider and difficulty selection in Settings.
	•	Complication for quick‑launch and daily seed display.

Performance & Budgets
	•	Target 60 FPS; keep node counts low (reuse, pool particles).
	•	Texture atlas; rasterize expensive effect nodes.
	•	Avoid heavy CIFilters across many nodes in real time; pre‑bake where possible.

⸻

Meta / Progression (lightweight)
	•	Cosmetic themes (unlock via milestones).
	•	Achievements (local / optional Game Center).
	•	Daily leaderboard (if Game Center is enabled later).

Accessibility
	•	High‑contrast mode (extra‑visible ball/paddle).
	•	Reduce Motion support.
	•	Color‑blind palettes (alternative accents).

⸻

Roadmap (MVP → polish)
	•	MVP gameplay: Crown paddle, ball physics, 3 brick types (incl. explosive), score, lives.
	•	Rotation twist with fairness (freeze + snap).
	•	Procedural levels + seeded Daily mode.
	•	Effects: trail, sparks, explosions.
	•	Haptics map (hit/miss/power‑up/rotation).
	•	UI: pause, restart, sensitivity.
	•	Performance pass and QA on real watches.
	•	Polish: cosmetic themes, achievements.
	•	Release prep: icon, screenshots, metadata.

License
	•	e.g., MIT License (to be decided before making the repo public).
