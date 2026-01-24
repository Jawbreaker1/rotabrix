import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var gameCenter: GameCenterManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.blue.opacity(0.5), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        headerSection
                        contentSection
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            gameCenter.refreshLeaderboard()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            if GameCenterConfig.contexts.count > 1 {
                Picker("Leaderboard", selection: $gameCenter.selectedContextID) {
                    ForEach(GameCenterConfig.contexts) { context in
                        Text(context.title)
                            .tag(context.id)
                    }
                }
            } else {
                Text(GameCenterConfig.contexts.first?.title ?? "All Time")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            if let alias = gameCenter.playerAlias, gameCenter.isAuthenticated {
                Text("Signed in as \(alias)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch gameCenter.leaderboardState {
        case .idle:
            statusView(title: "Loading", message: "Fetching scores...")
        case .disabled:
            statusView(title: "Game Center Off", message: "Enable Game Center in Settings.")
        case .unauthenticated:
            statusView(
                title: "Not Signed In",
                message: gameCenter.authErrorMessage ?? "Sign in to Game Center on your iPhone.",
                actionTitle: "Retry",
                action: { gameCenter.authenticateIfNeeded() }
            )
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        case .error(let message):
            statusView(
                title: "Unable to Load",
                message: message,
                actionTitle: "Retry",
                action: { gameCenter.refreshLeaderboard() }
            )
        case .loaded:
            if gameCenter.leaderboardEntries.isEmpty {
                statusView(title: "No Scores Yet", message: "Play a round to set the first score.")
            } else {
                leaderboardList
            }
        }
    }

    private var leaderboardList: some View {
        VStack(spacing: 8) {
            ForEach(gameCenter.leaderboardEntries) { entry in
                LeaderboardRow(entry: entry)
            }

            if let localEntry = gameCenter.localEntry,
               !gameCenter.leaderboardEntries.contains(where: { $0.id == localEntry.id }) {
                Divider()
                    .overlay(Color.white.opacity(0.2))
                Text("Your Rank")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                LeaderboardRow(entry: localEntry)
            }
        }
    }

    private func statusView(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
                .foregroundColor(.white)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct LeaderboardRow: View {
    let entry: GameCenterManager.LeaderboardEntry

    var body: some View {
        HStack(spacing: 8) {
            Text("#\(entry.rank)")
                .font(.caption.weight(.semibold))
                .frame(width: 30, alignment: .leading)
                .foregroundColor(.white.opacity(0.85))

            Text(entry.displayName)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.white)

            Spacer(minLength: 6)

            Text("\(entry.score)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(entry.isLocalPlayer ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(entry.isLocalPlayer ? 0.5 : 0.15), lineWidth: 1)
        )
    }
}
