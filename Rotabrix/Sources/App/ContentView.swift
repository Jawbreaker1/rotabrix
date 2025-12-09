import SwiftUI
import SpriteKit
import Combine
import WatchKit

struct ContentView: View {
    @StateObject private var controller = GameController()
    @StateObject private var crownSystem = CrownInputSystem()
    @FocusState private var isFocused: Bool
    @State private var crownValue: Double = 0
    @State private var overlay: OverlayState = .start
    @State private var lastScore: Int?
    @AppStorage("rotabrix.highScore") private var highScore = 0
    @AppStorage("rotabrix.musicVolume") private var musicVolume: Double = 0.6
    private let audioManager = AudioManager.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: controller.scene)
                    .ignoresSafeArea()

                switch overlay {
                case .start:
                    StartScreenView(highScore: highScore, lastScore: lastScore, volume: $musicVolume) {
                        startGame()
                    }
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
            .onChange(of: crownValue) { newValue in
                let normalized = crownSystem.process(value: newValue)
                if overlay == .playing {
                    controller.updatePaddle(normalized: CGFloat(normalized))
                }
            }
            .onChange(of: overlay) { state in
                switch state {
                case .start:
                    audioManager.playStartScreenLoop()
                default:
                    audioManager.stopStartScreenLoop()
                }
            }
            .onChange(of: musicVolume) { newValue in
                audioManager.setVolume(newValue)
            }
            .onAppear {
                overlay = .start
                crownSystem.reset(position: 0.5, crownValue: crownValue)
                controller.updatePaddle(normalized: 0.5)
                controller.setStartScreenActive(true)
                audioManager.preparePlayers()
                audioManager.setVolume(musicVolume)
                audioManager.playStartScreenLoop()
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

private struct StartScreenView: View {
    let highScore: Int
    let lastScore: Int?
    @Binding var volume: Double
    let onStart: () -> Void

    @FocusState private var isVolumeFocused: Bool
    @State private var crownVolumeValue: Double = 0.6
    @State private var showVolumeHUD = false
    @State private var hideHUDWorkItem: DispatchWorkItem?
    @State private var didAppear = false
    @State private var lastRawCrownValue: Double = 0.6

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.6), Color.blue.opacity(0.65), Color.black]),
                    center: .center,
                    angle: .degrees(55)
                )
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    Spacer(minLength: 24)

                    NeonTitle(text: "Rotabrix")
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 8) {
                        if let lastScore, lastScore > 0 {
                            ScoreBadge(label: "Last Score", value: lastScore)
                        }

                    ScoreBadge(label: "High Score", value: highScore)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 14)

                    Button(action: onStart) {
                        Text("Start")
                            .font(.headline)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.pink, Color.orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color.cyan.opacity(0.65), radius: 8)
                            )
                            .foregroundColor(Color.black)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 24)
                }
                .frame(height: proxy.size.height)
                .padding(.vertical, 18)
                .padding(.horizontal, 16)
            }
            .overlay(alignment: .topTrailing) {
                if showVolumeHUD {
                    VolumeHUDView(volume: volume)
                        .transition(.opacity)
                        .padding(.top, 6)
                        .padding(.trailing, 8)
                }
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
        .onChange(of: crownVolumeValue) { newValue in
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

    var body: some View {
        let clamped = max(0, min(1, volume))
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 58, height: 58)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                )
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    LinearGradient(colors: [.cyan, .pink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(-90))

            Image(systemName: clamped > 0.66 ? "speaker.wave.3.fill" : clamped > 0.33 ? "speaker.wave.2.fill" : (clamped > 0.05 ? "speaker.wave.1.fill" : "speaker.slash.fill"))
                .font(.system(size: 18, weight: .semibold))
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

private struct ScoreBadge: View {
    let label: String
    let value: Int

    var body: some View {
        Text("\(label): \(value)")
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
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

    var body: some View {
        let upper = text.uppercased()
        let baseFont = Font.system(size: 40, weight: .black, design: .rounded)
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
