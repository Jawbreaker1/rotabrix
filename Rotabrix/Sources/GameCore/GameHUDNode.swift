import SpriteKit
import CoreGraphics

final class GameHUDNode: SKNode {
    private let statusBackground = SKShapeNode(rectOf: CGSize(width: 148, height: 46), cornerRadius: 12)
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo")
    private let livesLabel = SKLabelNode(fontNamed: "Menlo")
    private let multiplierLabel = SKLabelNode(fontNamed: "Menlo")
    private let messageLabel = SKLabelNode(fontNamed: "Menlo")

    override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        statusBackground.fillColor = SKColor.black.withAlphaComponent(0.35)
        statusBackground.strokeColor = SKColor.white.withAlphaComponent(0.15)
        statusBackground.lineWidth = 1
        statusBackground.zPosition = -1
        addChild(statusBackground)

        scoreLabel.fontSize = 14
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.text = "Score: 0"
        scoreLabel.fontColor = SKColor.white
        addChild(scoreLabel)

        multiplierLabel.fontSize = 14
        multiplierLabel.horizontalAlignmentMode = .center
        multiplierLabel.verticalAlignmentMode = .center
        multiplierLabel.text = "x1"
        multiplierLabel.fontColor = SKColor(red: 0.18, green: 0.95, blue: 0.78, alpha: 1)
        addChild(multiplierLabel)

        livesLabel.fontSize = 13
        livesLabel.horizontalAlignmentMode = .left
        livesLabel.verticalAlignmentMode = .center
        livesLabel.text = "Lives: 3"
        livesLabel.fontColor = SKColor.white
        addChild(livesLabel)

        messageLabel.fontSize = 16
        messageLabel.fontColor = SKColor.white.withAlphaComponent(0.85)
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        messageLabel.alpha = 0
        addChild(messageLabel)
    }

    func update(score: Int, multiplier: Int, lives: Int) {
        scoreLabel.text = "Score: \(score)"
        multiplierLabel.text = "x\(multiplier)"
        livesLabel.text = "Lives: \(max(lives, 0))"
    }

    func layout(in rect: CGRect) {
        let top = rect.maxY - 18
        let centerX = rect.midX
        scoreLabel.position = CGPoint(x: rect.minX + 12, y: top)
        livesLabel.position = CGPoint(x: rect.minX + 12, y: top - 18)
        multiplierLabel.position = CGPoint(x: centerX, y: top)

        let backgroundWidth = max(120, min(rect.width - 16, 200))
        statusBackground.path = CGPath(roundedRect: CGRect(x: -backgroundWidth / 2, y: -27, width: backgroundWidth, height: 56), cornerWidth: 12, cornerHeight: 12, transform: nil)
        statusBackground.position = CGPoint(x: centerX, y: top - 16)
        messageLabel.position = CGPoint(x: centerX, y: rect.midY)
    }

    func showMessage(_ text: String, duration: TimeInterval = 1.2) {
        messageLabel.removeAllActions()
        messageLabel.text = text
        messageLabel.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.15),
            .wait(forDuration: duration),
            .fadeAlpha(to: 0, duration: 0.25)
        ]))
    }
}
