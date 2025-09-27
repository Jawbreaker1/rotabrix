import SpriteKit

final class PaddleNode: SKShapeNode {
    init(size: CGSize) {
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: GameConfig.paddleCornerRadius, cornerHeight: GameConfig.paddleCornerRadius, transform: nil)
        super.init()
        self.path = path
        fillColor = SKColor(red: 0.18, green: 0.96, blue: 0.61, alpha: 0.95)
        strokeColor = SKColor.white.withAlphaComponent(0.3)
        lineWidth = 1
        glowWidth = 2
        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.paddle
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        physicsBody?.collisionBitMask = PhysicsCategory.ball
        name = "paddle"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func moveToward(_ target: CGPoint, delta: CGFloat) {
        let framesPerSecond: CGFloat = 60
        let step = max(0, min(delta * framesPerSecond, 1.5))
        let responsiveness = GameConfig.paddleResponsiveness
        let lerpFactor = 1 - pow(1 - responsiveness, step)

        let dx = target.x - position.x
        let dy = target.y - position.y

        position.x += dx * lerpFactor
        position.y += dy * lerpFactor

        if hypot(target.x - position.x, target.y - position.y) <= GameConfig.paddleSnapDistance {
            position = target
        }
    }
}
