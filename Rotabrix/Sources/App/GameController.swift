import Combine
import CoreGraphics
import SpriteKit
import WatchKit

final class GameController: ObservableObject {
    let scene: GameScene

    private let sceneSize: CGSize

    @Published private(set) var currentScore: Int = 0
    @Published private(set) var gameOverScore: Int?
    @Published private(set) var isGameRunning: Bool = false

    init() {
        #if os(watchOS)
        sceneSize = WKInterfaceDevice.current().screenBounds.size
        #else
        sceneSize = CGSize(width: 198, height: 230)
        #endif

        scene = GameScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        scene.gameDelegate = self
    }

    func startGame() {
        scene.startNewGame()
    }

    func updatePaddle(normalized value: CGFloat) {
        scene.updatePaddleTarget(normalized: value.clamped(to: 0...1))
    }

    func normalizedTarget(forTouch location: CGPoint, in viewSize: CGSize) -> CGFloat {
        scene.normalizedTarget(forTouch: location, in: viewSize)
    }

    func setStartScreenActive(_ active: Bool) {
        scene.setStartScreenPresentation(active: active)
    }
}

extension GameController: GameSceneDelegate {
    func gameSceneDidStart(_ scene: GameScene, score: Int) {
        DispatchQueue.main.async {
            self.isGameRunning = true
            self.currentScore = score
            self.gameOverScore = nil
        }
    }

    func gameScene(_ scene: GameScene, didUpdateScore score: Int) {
        DispatchQueue.main.async {
            self.currentScore = score
        }
    }

    func gameSceneDidEnd(_ scene: GameScene, finalScore: Int) {
        DispatchQueue.main.async {
            self.isGameRunning = false
            self.currentScore = finalScore
            self.gameOverScore = finalScore
        }
    }
}
