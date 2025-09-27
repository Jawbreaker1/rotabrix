Sources
=======

Swift code lives here once the watchOS project scaffolding is created. Suggested grouping:
- `App/` – SwiftUI App entry point and watch-specific UI.
- `GameCore/` – SpriteKit scenes, physics, collision handling.
- `Systems/` – Supporting systems (level generation, scoring, drops, rotation).
- `Support/` – Shared helpers, extensions, configuration.

Organize gameplay code so it can later be extracted into a Swift package if needed.

