import SpriteKit

final class PaddleNode: SKShapeNode {
    private var baseSize: CGSize
    private var cornerRadius: CGFloat
    private var snapDistance: CGFloat
    private var scale: CGFloat
    private(set) var widthMultiplier: CGFloat = 1

    init(size: CGSize, cornerRadius: CGFloat, snapDistance: CGFloat, scale: CGFloat) {
        self.baseSize = size
        self.cornerRadius = cornerRadius
        self.snapDistance = snapDistance
        self.scale = scale
        super.init()
        configureAppearance()
        applySize(multiplier: 1)
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

        if hypot(target.x - position.x, target.y - position.y) <= snapDistance {
            position = target
        }
    }

    func setWidthMultiplier(_ multiplier: CGFloat) {
        applySize(multiplier: multiplier)
    }

    func updateMetrics(size: CGSize, cornerRadius: CGFloat, snapDistance: CGFloat, scale: CGFloat) {
        baseSize = size
        self.cornerRadius = cornerRadius
        self.snapDistance = snapDistance
        self.scale = scale
        configureAppearance()
        applySize(multiplier: widthMultiplier)
    }

    private func configureAppearance() {
        fillColor = SKColor(red: 0.18, green: 0.96, blue: 0.61, alpha: 0.95)
        strokeColor = SKColor.white.withAlphaComponent(0.3)
        lineWidth = 1 * scale
        glowWidth = 2 * scale
        name = "paddle"
    }

    private func applySize(multiplier: CGFloat) {
        widthMultiplier = max(0.2, multiplier)
        let size = CGSize(width: baseSize.width * widthMultiplier, height: baseSize.height)
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        self.path = path

        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.paddle
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        physicsBody?.collisionBitMask = PhysicsCategory.ball
    }
}
