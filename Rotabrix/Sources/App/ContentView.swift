import SwiftUI
import SpriteKit
import Combine
import WatchKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = GameController()
    @StateObject private var crownSystem = CrownInputSystem()
    @FocusState private var isFocused: Bool
    @State private var crownValue: Double = 0
    @State private var overlay: OverlayState = .start
    @State private var lastScore: Int?
    @AppStorage("rotabrix.highScore") private var highScore = 0
    @AppStorage("rotabrix.musicVolume") private var musicVolume: Double = 0.6
    @AppStorage("rotabrix.soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("rotabrix.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("rotabrix.crownSensitivity") private var crownSensitivity: Double = GameConfig.defaultCrownSensitivity
    @AppStorage("rotabrix.difficulty") private var difficultyRaw: String = GameDifficulty.medium.rawValue
    @AppStorage("rotabrix.gameCenterEnabled") private var gameCenterEnabled: Bool = true
    @State private var showingSettings = false
    @State private var showingLeaderboard = false
    @StateObject private var gameCenter = GameCenterManager()
    private let audioManager = AudioManager.shared

    private var difficulty: GameDifficulty {
        GameDifficulty(rawValue: difficultyRaw) ?? .medium
    }

    private var difficultyBinding: Binding<GameDifficulty> {
        Binding(
            get: { GameDifficulty(rawValue: difficultyRaw) ?? .medium },
            set: { difficultyRaw = $0.rawValue }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: controller.scene)
                    .ignoresSafeArea()

                switch overlay {
                case .start:
                    StartScreenView(
                        highScore: highScore,
                        lastScore: lastScore,
                        volume: $musicVolume,
                        onStart: { startGame() },
                        onSettings: { showingSettings = true },
                        onLeaderboard: { showingLeaderboard = true },
                        gameCenterEnabled: gameCenterEnabled
                    )
                    .allowsHitTesting(!showingSettings)
                    .transition(.opacity)
                case .gameOver(let score):
                    GameOverView(score: score) { endGameOver() }
                        .transition(.opacity)
                case .highScore(let score):
                    HighScoreCelebrationView(score: score) {
                        endCelebration()
                    }
                        .transition(.opacity)
                case .playing:
                    controlOverlay(size: proxy.size)
                }
            }
            .overlay {
                if showingSettings {
                    NavigationStack {
                        SettingsView(
                            soundEnabled: $soundEnabled,
                            hapticsEnabled: $hapticsEnabled,
                            gameCenterEnabled: $gameCenterEnabled,
                            crownSensitivity: $crownSensitivity,
                            difficulty: difficultyBinding,
                            onClose: { showingSettings = false }
                        )
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(action: { showingSettings = false }) {
                                    Image(systemName: "xmark")
                                }
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                }
            }
            .sheet(isPresented: $showingLeaderboard) {
                LeaderboardView(gameCenter: gameCenter)
            }
            .onChange(of: crownValue) { _, newValue in
                let normalized = crownSystem.process(value: newValue)
                if overlay == .playing {
                    controller.updatePaddle(normalized: CGFloat(normalized))
                }
            }
            .onChange(of: overlay) { _, state in
                switch state {
                case .start:
                    audioManager.playStartScreenLoop()
                default:
                    audioManager.stopStartScreenLoop()
                }
            }
            .onChange(of: musicVolume) { _, newValue in
                audioManager.setVolume(newValue)
            }
            .onChange(of: soundEnabled) { _, enabled in
                audioManager.setEnabled(enabled)
                if enabled {
                    if controller.isGameRunning {
                        audioManager.playGameplayLoop()
                    } else if overlay == .start {
                        audioManager.playStartScreenLoop()
                    }
                }
            }
            .onChange(of: hapticsEnabled) { _, enabled in
                Haptic.setEnabled(enabled)
            }
            .onChange(of: gameCenterEnabled) { _, enabled in
                gameCenter.setEnabled(enabled)
            }
            .onChange(of: crownSensitivity) { _, newValue in
                crownSystem.setSensitivity(newValue)
            }
            .onChange(of: difficultyRaw) { _, newValue in
                let difficulty = GameDifficulty(rawValue: newValue) ?? .medium
                controller.setDifficulty(difficulty)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    audioManager.setEnabled(soundEnabled)
                    if soundEnabled {
                        if controller.isGameRunning {
                            audioManager.playGameplayLoop()
                        } else {
                            audioManager.playStartScreenLoop()
                        }
                    }
                case .inactive, .background:
                    audioManager.stopAll()
                @unknown default:
                    break
                }
            }
            .onAppear {
                overlay = .start
                crownSystem.reset(position: 0.5, crownValue: crownValue)
                crownSystem.setSensitivity(crownSensitivity)
                controller.updatePaddle(normalized: 0.5)
                controller.setStartScreenActive(true)
                controller.setDifficulty(difficulty)
                audioManager.preparePlayers()
                audioManager.setVolume(musicVolume)
                audioManager.setEnabled(soundEnabled)
                Haptic.setEnabled(hapticsEnabled)
                gameCenter.setEnabled(gameCenterEnabled)
                if soundEnabled {
                    audioManager.playStartScreenLoop()
                }
            }
            .onDisappear {
                isFocused = false
                audioManager.stopAll()
            }
            .onReceive(controller.$isGameRunning) { isRunning in
                if isRunning {
                    audioManager.stopStartScreenLoop()
                    audioManager.playGameplayLoop()
                } else {
                    audioManager.stopGameplayLoop()
                }
            }
            .onReceive(controller.$gameOverScore) { score in
                guard let score else { return }
                gameCenter.submitScore(score)
                lastScore = score
                let isNewHigh = score > highScore
                if isNewHigh {
                    highScore = score
                }
                controller.setStartScreenActive(true)
                crownSystem.overridePosition(0.5, crownValue: crownValue)
                controller.updatePaddle(normalized: 0.5)
                audioManager.stopGameplayLoop()
                if isNewHigh {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        overlay = .highScore(score)
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        overlay = .gameOver(score)
                    }
                }
            }
        }
    }
}

extension ContentView {
    private func startGame() {
        crownSystem.reset(position: 0.5, crownValue: crownValue)
        controller.updatePaddle(normalized: 0.5)
        controller.setStartScreenActive(false)
        controller.startGame()
        audioManager.stopStartScreenLoop()
        audioManager.playGameplayLoop()
        withAnimation(.easeInOut(duration: 0.2)) {
            overlay = .playing
        }
        DispatchQueue.main.async {
            isFocused = true
        }
    }

    @ViewBuilder
    private func controlOverlay(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTouch(value.location, in: size)
                    }
                    .onEnded { value in
                        handleTouch(value.location, in: size)
                    }
            )
            .focusable(true)
            .focused($isFocused)
            .digitalCrownRotation(
                $crownValue,
                from: -Double.greatestFiniteMagnitude,
                through: Double.greatestFiniteMagnitude,
                by: 0.001,
                sensitivity: .low,
                isContinuous: true,
                isHapticFeedbackEnabled: false
            )
            .hideCrownAccessory()
            .ignoresSafeArea()
    }

    private func handleTouch(_ location: CGPoint, in size: CGSize) {
        if !isFocused { isFocused = true }
        let normalized = controller.normalizedTarget(forTouch: location, in: size)
        let clamped = Double(normalized.clamped(to: 0...1))
        crownSystem.overridePosition(clamped, crownValue: crownValue)
        controller.updatePaddle(normalized: normalized.clamped(to: 0...1))
    }

    private func endCelebration() {
        withAnimation(.easeOut(duration: 0.2)) {
            overlay = .start
        }
        DispatchQueue.main.async {
            isFocused = false
        }
    }

    private func endGameOver() {
        withAnimation(.easeOut(duration: 0.2)) {
            overlay = .start
        }
        DispatchQueue.main.async {
            isFocused = false
        }
    }
}

private enum OverlayState: Equatable {
    case start
    case gameOver(Int)
    case highScore(Int)
    case playing
}

private struct OverlayMetrics {
    static let referenceSize = CGSize(width: 205, height: 251)

    let scale: CGFloat

    init(size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            scale = 1
            return
        }
        let widthScale = size.width / Self.referenceSize.width
        let heightScale = size.height / Self.referenceSize.height
        let baseScale = min(widthScale, heightScale)
        let boosted = baseScale * 1.35
        scale = min(1.35, boosted)
    }

    func scaled(_ value: CGFloat) -> CGFloat {
        value * scale
    }
}

private struct StartScreenView: View {
    let highScore: Int
    let lastScore: Int?
    @Binding var volume: Double
    let onStart: () -> Void
    let onSettings: () -> Void
    let onLeaderboard: () -> Void
    let gameCenterEnabled: Bool

    @FocusState private var isVolumeFocused: Bool
    @State private var crownVolumeValue: Double = 0.6
    @State private var showVolumeHUD = false
    @State private var hideHUDWorkItem: DispatchWorkItem?
    @State private var didAppear = false
    @State private var lastRawCrownValue: Double = 0.6

    var body: some View {
        GeometryReader { proxy in
            let metrics = OverlayMetrics(size: proxy.size)
            let horizontalPadding = metrics.scaled(16)
            let verticalPadding = metrics.scaled(18)
            let iconSize = metrics.scaled(18)
            let safeTop = proxy.safeAreaInsets.top
            let iconTopPadding = max(metrics.scaled(6), min(safeTop, metrics.scaled(10)))
            let hudTopPadding = iconTopPadding + iconSize + metrics.scaled(6)
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.6), Color.blue.opacity(0.65), Color.black]),
                    center: .center,
                    angle: .degrees(55)
                )
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()

                VStack(spacing: metrics.scaled(14)) {
                    Spacer(minLength: metrics.scaled(24))

                    NeonTitle(text: "Rotabrix", scale: metrics.scale)
                        .frame(maxWidth: .infinity, alignment: .center)

                    ScoreBlock(lastScore: lastScore, highScore: highScore, scale: metrics.scale)

                    Spacer(minLength: metrics.scaled(14))

                    Button(action: onStart) {
                        Text("Start")
                            .font(.system(size: 18 * metrics.scale, weight: .semibold))
                            .padding(.horizontal, metrics.scaled(36))
                            .padding(.vertical, metrics.scaled(10))
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.pink, Color.orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color.cyan.opacity(0.65), radius: metrics.scaled(8))
                            )
                            .foregroundColor(Color.black)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(1)

                    Spacer(minLength: metrics.scaled(24))
                }
                .frame(height: proxy.size.height)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
            }
            .overlay(alignment: .topTrailing) {
                if showVolumeHUD {
                    VolumeHUDView(volume: volume, scale: metrics.scale)
                        .transition(.opacity)
                        .padding(.top, hudTopPadding)
                        .padding(.trailing, metrics.scaled(8))
                }
            }
            .overlay(alignment: .topLeading) {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, metrics.scaled(8))
                .padding(.top, iconTopPadding)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onLeaderboard) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!gameCenterEnabled)
                .opacity(gameCenterEnabled ? 1 : 0.35)
                .padding(.trailing, metrics.scaled(8))
                .padding(.top, iconTopPadding)
            }
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownVolumeValue,
            from: -1000,
            through: 1000,
            by: 0.02,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .focused($isVolumeFocused)
        .onAppear {
            crownVolumeValue = min(max(volume, 0), 1)
            lastRawCrownValue = crownVolumeValue
            isVolumeFocused = true
            DispatchQueue.main.async {
                didAppear = true
            }
        }
        .onDisappear {
            isVolumeFocused = false
            hideHUDWorkItem?.cancel()
        }
        .onChange(of: crownVolumeValue) { _, newValue in
            handleCrownChange(newValue)
        }
    }

    private func handleCrownChange(_ newValue: Double) {
        let delta = newValue - lastRawCrownValue
        lastRawCrownValue = newValue

        guard abs(delta) > 0.0001 else { return }

        let nextVolume = min(max(volume + delta, 0), 1)
        if nextVolume != volume {
            volume = nextVolume
        }
        presentVolumeHUD()
    }

    private func presentVolumeHUD() {
        guard didAppear else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            showVolumeHUD = true
        }
        hideHUDWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) { showVolumeHUD = false }
        }
        hideHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }
}

private struct VolumeHUDView: View {
    let volume: Double
    let scale: CGFloat

    var body: some View {
        let clamped = max(0, min(1, volume))
        let size = 58 * scale
        let lineWidth = 6 * scale
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
                )
                .shadow(color: .black.opacity(0.35), radius: 6 * scale, x: 0, y: 3 * scale)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    LinearGradient(colors: [.cyan, .pink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            Image(systemName: clamped > 0.66 ? "speaker.wave.3.fill" : clamped > 0.33 ? "speaker.wave.2.fill" : (clamped > 0.05 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundColor(.white)
        }
        .accessibilityLabel("Music volume")
        .accessibilityValue(String(format: "%.0f percent", clamped * 100))
    }
}

private struct GameOverView: View {
    let score: Int
    let onComplete: () -> Void

    @State private var didSchedule = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.black, Color.red.opacity(0.55), Color.blue.opacity(0.4)],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.38))

            VStack(spacing: 10) {
                Text("Game Over")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, .red.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .red.opacity(0.6), radius: 8)

                Text("\(score)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6)
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            guard !didSchedule else { return }
            didSchedule = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onComplete()
            }
        }
    }
}

private struct HighScoreCelebrationView: View {
    let score: Int
    let onComplete: () -> Void

    @State private var didSchedule = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.black, Color.blue.opacity(0.6), Color.pink.opacity(0.5)],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.35))

            SpriteView(scene: HighScoreFireworksScene(size: WKInterfaceDevice.current().screenBounds.size))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("HIGH SCORE!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .yellow.opacity(0.7), radius: 10)
                    .scaleEffect(1.05)

                Text("\(score)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(0.7), radius: 12)
            }
        }
        .onAppear {
            guard !didSchedule else { return }
            didSchedule = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                onComplete()
            }
        }
    }
}

private struct ScoreBlock: View {
    let lastScore: Int?
    let highScore: Int
    let scale: CGFloat

    private var hasLast: Bool {
        if let lastScore {
            return lastScore > 0
        }
        return false
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: scaled(6)) {
                if let lastScore, hasLast {
                    ScoreBadge(label: "Last", value: lastScore, scale: scale)
                }
                ScoreBadge(label: "High", value: highScore, scale: scale)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: scaled(8)) {
                if let lastScore, hasLast {
                    ScoreBadge(label: "Last", value: lastScore, scale: scale)
                }
                ScoreBadge(label: "High", value: highScore, scale: scale)
            }
            .frame(maxWidth: .infinity)

            compactLine
        }
    }

    private var compactLine: some View {
        let text = hasLast ? "Last \(lastScore ?? 0) | High \(highScore)" : "High \(highScore)"
        return Text(text)
            .font(.system(size: 18 * scale, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * scale
    }
}

private struct ScoreBadge: View {
    let label: String
    let value: Int
    let scale: CGFloat

    var body: some View {
        Text("\(label): \(value)")
            .font(.system(size: 16 * scale, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16 * scale)
            .padding(.vertical, 7 * scale)
            .background(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            )
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
    }
}

private struct NeonTitle: View {
    let text: String
    let scale: CGFloat

    var body: some View {
        let upper = text.uppercased()
        let baseFont = Font.system(size: 44 * scale, weight: .black, design: .rounded)
        let base = Text(upper)
            .font(baseFont)
            .kerning(1.1)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)

        return base
            .overlay(
                AngularGradient(
                    gradient: Gradient(colors: [.cyan, .white, .purple, .pink]),
                    center: .center
                )
                .mask(
                    base
                )
            )
            .foregroundColor(.white.opacity(0.25))
            .shadow(color: .cyan.opacity(0.8), radius: 10, x: 0, y: 0)
            .shadow(color: .purple.opacity(0.7), radius: 16, x: 0, y: 0)
            .shadow(color: .pink.opacity(0.5), radius: 20, x: 0, y: 0)
            .layoutPriority(1)            // keep width preference
    }
}

private struct SettingsView: View {
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var gameCenterEnabled: Bool
    @Binding var crownSensitivity: Double
    @Binding var difficulty: GameDifficulty
    let onClose: () -> Void

    private var sensitivityLabel: String {
        String(format: "%.1f", crownSensitivity)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = OverlayMetrics(size: proxy.size)
            let cardPadding = metrics.scaled(12)
            let cardCornerRadius = metrics.scaled(12)
            let sectionSpacing = metrics.scaled(12)
            let horizontalPadding = metrics.scaled(14)
            let topPadding = metrics.scaled(6)
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()
                LinearGradient(
                    colors: [Color.black, Color.blue.opacity(0.45), Color.purple.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: sectionSpacing) {
                        VStack(spacing: metrics.scaled(8)) {
                            Toggle(isOn: $soundEnabled) {
                                Label("Sound", systemImage: "speaker.wave.2.fill")
                                    .foregroundColor(.white)
                            }
                            .tint(.cyan)

                            Toggle(isOn: $hapticsEnabled) {
                                Label("Vibration", systemImage: "waveform.path")
                                    .foregroundColor(.white)
                            }
                            .tint(.cyan)

                            Toggle(isOn: $gameCenterEnabled) {
                                Label("Game Center", systemImage: "trophy.fill")
                                    .foregroundColor(.white)
                            }
                            .tint(.cyan)
                        }
                        .padding(cardPadding)
                            .background(
                                RoundedRectangle(cornerRadius: cardCornerRadius)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cardCornerRadius)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )

                        VStack(alignment: .leading, spacing: metrics.scaled(8)) {
                            HStack(spacing: metrics.scaled(6)) {
                                Image(systemName: "speedometer")
                                    .foregroundColor(.white)
                                Text("Difficulty")
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            DifficultySelector(selection: $difficulty, scale: metrics.scale)
                        }
                        .padding(cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: cardCornerRadius)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )

                        VStack(alignment: .leading, spacing: metrics.scaled(8)) {
                            HStack(spacing: metrics.scaled(6)) {
                                Image(systemName: "dial.medium")
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: -2) {
                                    Text("Crown")
                                    Text("Sensitivity")
                                }
                                .foregroundColor(.white)
                                Spacer()
                                Text(sensitivityLabel)
                                    .font(.system(size: 12 * metrics.scale))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Slider(
                                value: $crownSensitivity,
                                in: GameConfig.crownSensitivityRange,
                                step: 0.02
                            )
                            .tint(.orange)
                        }
                        .padding(cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: cardCornerRadius)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )

                        Text("Game by Bird Disk")
                            .font(.system(size: 16 * metrics.scale, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, metrics.scaled(16))
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
    }
}

private struct DifficultySelector: View {
    @Binding var selection: GameDifficulty
    let scale: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            optionRow(horizontal: true)
            optionRow(horizontal: false)
        }
    }

    @ViewBuilder
    private func optionRow(horizontal: Bool) -> some View {
        if horizontal {
            HStack(spacing: 6 * scale) {
                options
            }
        } else {
            VStack(spacing: 6 * scale) {
                options
            }
        }
    }

    private var options: some View {
        ForEach(GameDifficulty.allCases) { difficulty in
            DifficultyOptionButton(
                title: difficulty.displayName,
                isSelected: difficulty == selection,
                scale: scale
            ) {
                selection = difficulty
            }
        }
    }
}

private struct DifficultyOptionButton: View {
    let title: String
    let isSelected: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14 * scale, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 8 * scale)
                        .fill(isSelected ? Color.cyan.opacity(0.35) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * scale)
                        .stroke(Color.white.opacity(isSelected ? 0.65 : 0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HideCrownAccessory: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 10.0, *) {
            content.digitalCrownAccessory(.hidden)
        } else {
            content
        }
    }
}

private extension View {
    func hideCrownAccessory() -> some View {
        modifier(HideCrownAccessory())
    }
}

#Preview {
    ContentView()
}

// Lightweight fireworks scene for the high-score celebration.
final class HighScoreFireworksScene: SKScene {
    private var lastSpawn: TimeInterval = 0

    override func sceneDidLoad() {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - lastSpawn > 0.25 {
            spawnFirework()
            lastSpawn = currentTime
        }
    }

    private func spawnFirework() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.sparkTexture
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = 80
        emitter.particleLifetime = 1.2
        emitter.particleLifetimeRange = 0.4
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 260
        emitter.particleSpeedRange = 120
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -0.9
        emitter.particleScale = 0.45
        emitter.particleScaleRange = 0.18
        emitter.particleScaleSpeed = -0.35
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            SKColor(red: 1, green: 0.9, blue: 0.5, alpha: 1),
            SKColor(red: 0.4, green: 0.9, blue: 1, alpha: 1),
            SKColor(red: 1, green: 0.4, blue: 0.8, alpha: 1)
        ], times: [0, 0.5, 1])
        emitter.particleBlendMode = .add
        emitter.position = randomPosition()

        addChild(emitter)
        emitter.particleBirthRate = 200
        emitter.run(.sequence([
            .wait(forDuration: 0.05),
            .run { emitter.particleBirthRate = 0 },
            .wait(forDuration: 1.6),
            .removeFromParent()
        ]))
    }

    private func randomPosition() -> CGPoint {
        let inset: CGFloat = 24
        let x = CGFloat.random(in: inset...(size.width - inset)) - size.width / 2
        let y = CGFloat.random(in: inset...(size.height - inset)) - size.height / 2
        return CGPoint(x: x, y: y)
    }

    private static let sparkTexture: SKTexture = {
        let size = CGSize(width: 6, height: 6)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }

        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        context.setFillColor(SKColor.white.cgColor)
        context.fillEllipse(in: rect)

        guard let cgImage = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }()
}
