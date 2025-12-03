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

    func showMessage(_ text: String, fontSize: CGFloat = 16, duration: TimeInterval = 1.2) {
        messageLabel.removeAllActions()
        messageLabel.fontSize = fontSize
        messageLabel.text = text
        messageLabel.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.15),
            .wait(forDuration: duration),
            .fadeAlpha(to: 0, duration: 0.25)
        ]))
    }

    func showCountdown(_ text: String, fontSize: CGFloat = 18, duration: TimeInterval = 0.8) {
        messageLabel.removeAllActions()
        messageLabel.fontSize = fontSize
        messageLabel.text = text
        messageLabel.alpha = 0
        messageLabel.setScale(0.7)

        let fadeIn = SKAction.fadeAlpha(to: 1, duration: duration * 0.3)
        fadeIn.timingMode = .easeOut
        let scaleUp = SKAction.scale(to: 1.12, duration: duration * 0.3)
        scaleUp.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: duration * 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: duration * 0.4)
        fadeOut.timingMode = .easeIn
        let scaleDown = SKAction.scale(to: 0.6, duration: duration * 0.4)
        scaleDown.timingMode = .easeIn

        messageLabel.run(.sequence([
            .group([fadeIn, scaleUp]),
            hold,
            .group([fadeOut, scaleDown]),
            .scale(to: 1, duration: 0)
        ]))
    }

    func animateMultiplier(_ value: Int) {
        multiplierLabel.removeAllActions()
        multiplierLabel.text = "x\(value)"
        let bump = SKAction.sequence([
            .group([
                .scale(to: 1.75, duration: 0.16),
                .fadeAlpha(to: 1, duration: 0.16)
            ]),
            .scale(to: 1.0, duration: 0.2)
        ])
        bump.timingMode = .easeInEaseOut
        multiplierLabel.run(bump, withKey: "multiplierBump")
    }

    func animateScoreBoost(delta: Int) {
        guard delta >= 300 else { return }
        scoreLabel.removeAllActions()
        let bump = SKAction.sequence([
            .group([
                .scale(to: 1.24, duration: 0.12),
                .fadeAlpha(to: 1, duration: 0.12)
            ]),
            .scale(to: 1.0, duration: 0.18)
        ])
        bump.timingMode = .easeInEaseOut
        scoreLabel.run(bump, withKey: "scoreBump")
    }
}
