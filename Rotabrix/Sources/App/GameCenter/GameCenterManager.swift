import Foundation
import GameKit
import Combine

@MainActor
final class GameCenterManager: ObservableObject {
    struct LeaderboardEntry: Identifiable, Hashable {
        let id: String
        let rank: Int
        let score: Int
        let displayName: String
        let isLocalPlayer: Bool
    }

    enum LeaderboardState: Equatable {
        case idle
        case disabled
        case unauthenticated
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var isEnabled: Bool = true
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var playerAlias: String?
    @Published private(set) var authErrorMessage: String?
    @Published var selectedContextID: String {
        didSet {
            if selectedContextID != oldValue {
                UserDefaults.standard.set(selectedContextID, forKey: selectedContextKey)
                refreshLeaderboard()
            }
        }
    }
    @Published private(set) var leaderboardState: LeaderboardState = .idle
    @Published private(set) var leaderboardEntries: [LeaderboardEntry] = []
    @Published private(set) var localEntry: LeaderboardEntry?

    private let pendingScoresKey = "rotabrix.pendingGameCenterScores"
    private let selectedContextKey = "rotabrix.selectedLeaderboardContext"
    private var pendingRefresh = false

    private let leaderboardRange = NSRange(location: 1, length: 10)

    init() {
        let savedContext = UserDefaults.standard.string(forKey: selectedContextKey)
        selectedContextID = GameCenterConfig.contexts.first(where: { $0.id == savedContext })?.id
            ?? GameCenterConfig.defaultContextID
    }

    var selectedContext: LeaderboardContext {
        GameCenterConfig.contexts.first(where: { $0.id == selectedContextID })
            ?? GameCenterConfig.contexts.first!
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            authenticateIfNeeded()
        } else {
            leaderboardState = .disabled
            leaderboardEntries = []
            localEntry = nil
        }
    }

    func authenticateIfNeeded() {
        guard isEnabled else { return }
        let localPlayer = GKLocalPlayer.local

        if localPlayer.isAuthenticated {
            updateAuthenticationState(error: nil, needsSignIn: false)
            return
        }

        localPlayer.authenticateHandler = { [weak self] error in
            Task { @MainActor in
                self?.updateAuthenticationState(error: error, needsSignIn: true)
            }
        }
    }

    func refreshLeaderboard() {
        guard isEnabled else {
            leaderboardState = .disabled
            return
        }
        guard isAuthenticated else {
            leaderboardState = .unauthenticated
            pendingRefresh = true
            authenticateIfNeeded()
            return
        }
        loadLeaderboard()
    }

    func submitScore(_ score: Int) {
        guard isEnabled else { return }
        guard score > 0 else { return }
        let leaderboardID = GameCenterConfig.primaryLeaderboardID

        guard isAuthenticated else {
            queuePendingScore(score, leaderboardID: leaderboardID)
            authenticateIfNeeded()
            return
        }

        reportScore(score, leaderboardID: leaderboardID) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.queuePendingScore(score, leaderboardID: leaderboardID)
                self?.authErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func updateAuthenticationState(error: Error?, needsSignIn: Bool) {
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        if isAuthenticated {
            playerAlias = GKLocalPlayer.local.displayName
            authErrorMessage = nil
            flushPendingScores()
            if pendingRefresh {
                pendingRefresh = false
                loadLeaderboard()
            }
            return
        }

        playerAlias = nil
        if needsSignIn {
            authErrorMessage = "Sign in to Game Center on your iPhone."
        } else if let error {
            authErrorMessage = error.localizedDescription
        }
    }

    private func loadLeaderboard() {
        leaderboardState = .loading
        let context = selectedContext

        GKLeaderboard.loadLeaderboards(IDs: [context.leaderboardID]) { [weak self] leaderboards, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error {
                    self.leaderboardState = .error(error.localizedDescription)
                    return
                }
                guard let leaderboard = leaderboards?.first else {
                    self.leaderboardState = .error("Leaderboard not found.")
                    return
                }

                leaderboard.loadEntries(
                    for: context.playerScope,
                    timeScope: context.timeScope,
                    range: self.leaderboardRange
                ) { localEntry, entries, _, error in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let error {
                            self.leaderboardState = .error(error.localizedDescription)
                            return
                        }

                        let localRank = localEntry?.rank
                        let mappedEntries = entries?.map {
                            self.mapEntry($0, localRank: localRank)
                        } ?? []
                        self.leaderboardEntries = mappedEntries
                        self.localEntry = localEntry.map { self.mapEntry($0, localRank: $0.rank) }
                        self.leaderboardState = .loaded
                    }
                }
            }
        }
    }

    private func mapEntry(_ entry: GKLeaderboard.Entry, localRank: Int?) -> LeaderboardEntry {
        let displayName = entry.player.displayName
        let id = "\(entry.rank)-\(displayName)"
        let isLocal = localRank.map { $0 == entry.rank } ?? false
        return LeaderboardEntry(
            id: id,
            rank: entry.rank,
            score: Int(entry.score),
            displayName: displayName,
            isLocalPlayer: isLocal
        )
    }

    private struct PendingScore: Codable {
        let leaderboardID: String
        var value: Int
    }

    private func queuePendingScore(_ score: Int, leaderboardID: String) {
        var pending = loadPendingScores()
        if let index = pending.firstIndex(where: { $0.leaderboardID == leaderboardID }) {
            pending[index].value = max(pending[index].value, score)
        } else {
            pending.append(PendingScore(leaderboardID: leaderboardID, value: score))
        }
        savePendingScores(pending)
    }

    private func flushPendingScores() {
        let pending = loadPendingScores()
        guard !pending.isEmpty else { return }
        savePendingScores([])

        for item in pending {
            reportScore(item.value, leaderboardID: item.leaderboardID) { [weak self] error in
                guard error != nil else { return }
                Task { @MainActor in
                    self?.queuePendingScore(item.value, leaderboardID: item.leaderboardID)
                }
            }
        }
    }

    private func reportScore(_ score: Int, leaderboardID: String, completion: @escaping (Error?) -> Void) {
        let localPlayer = GKLocalPlayer.local
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: localPlayer,
            leaderboardIDs: [leaderboardID]
        ) { error in
            completion(error)
        }
    }

    private func loadPendingScores() -> [PendingScore] {
        guard let data = UserDefaults.standard.data(forKey: pendingScoresKey) else { return [] }
        return (try? JSONDecoder().decode([PendingScore].self, from: data)) ?? []
    }

    private func savePendingScores(_ scores: [PendingScore]) {
        guard let data = try? JSONEncoder().encode(scores) else { return }
        UserDefaults.standard.set(data, forKey: pendingScoresKey)
    }
}
