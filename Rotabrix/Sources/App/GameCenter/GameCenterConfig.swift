import GameKit

struct LeaderboardContext: Identifiable, Hashable {
    let id: String
    let leaderboardID: String
    let title: String
    let playerScope: GKLeaderboard.PlayerScope
    let timeScope: GKLeaderboard.TimeScope
}

enum GameCenterConfig {
    // Update to match the leaderboard ID created in App Store Connect.
    static let primaryLeaderboardID = "rotabrix.highscore.alltime"

    static let contexts: [LeaderboardContext] = [
        LeaderboardContext(
            id: "global-alltime",
            leaderboardID: primaryLeaderboardID,
            title: "All Time (Global)",
            playerScope: .global,
            timeScope: .allTime
        )
    ]

    static let defaultContextID = contexts.first?.id ?? "global-alltime"
}
