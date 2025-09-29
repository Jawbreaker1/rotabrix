import SwiftUI
import SpriteKit
import Combine

struct ContentView: View {
    @StateObject private var controller = GameController()
    @FocusState private var isFocused: Bool
    @State private var crownValue: Double = 0.5
    @State private var showStartScreen = true
    @State private var lastScore: Int?
    @AppStorage("rotabrix.highScore") private var highScore = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: controller.scene)
                    .ignoresSafeArea()

                if showStartScreen {
                    StartScreenView(highScore: highScore, lastScore: lastScore) {
                        startGame()
                    }
                    .transition(.opacity)
                } else {
                    controlOverlay(size: proxy.size)
                }
            }
            .onChange(of: crownValue) { newValue in
                guard !showStartScreen else { return }
                controller.updatePaddle(normalized: CGFloat(newValue.clamped(to: 0...1)))
            }
            .onAppear {
                crownValue = 0.5
                controller.setStartScreenActive(true)
                if !showStartScreen {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
            }
            .onDisappear {
                isFocused = false
            }
            .onReceive(controller.$gameOverScore) { score in
                guard let score else { return }
                lastScore = score
                if score > highScore {
                    highScore = score
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    showStartScreen = true
                }
                controller.setStartScreenActive(true)
                DispatchQueue.main.async {
                    isFocused = false
                }
            }
        }
    }
}

extension ContentView {
    private func startGame() {
        crownValue = 0.5
        controller.updatePaddle(normalized: 0.5)
        controller.setStartScreenActive(false)
        controller.startGame()
        withAnimation(.easeInOut(duration: 0.2)) {
            showStartScreen = false
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
                from: 0,
                through: 1,
                by: 0.005,
                sensitivity: .high,
                isContinuous: true,
                isHapticFeedbackEnabled: true
            )
            .hideCrownAccessory()
    }

    private func handleTouch(_ location: CGPoint, in size: CGSize) {
        if !isFocused { isFocused = true }
        let normalized = Double(controller.normalizedTarget(forTouch: location, in: size))
        crownValue = normalized
        controller.updatePaddle(normalized: CGFloat(normalized))
    }
}

private struct StartScreenView: View {
    let highScore: Int
    let lastScore: Int?
    let onStart: () -> Void

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
