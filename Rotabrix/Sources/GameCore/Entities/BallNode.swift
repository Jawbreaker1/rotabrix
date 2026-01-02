import SpriteKit

final class BallNode: SKShapeNode {
    private var trailEmitter: SKEmitterNode?
    private var haloNode: SKNode?
    private var radius: CGFloat
    private var scale: CGFloat

    init(radius: CGFloat, scale: CGFloat) {
        self.radius = radius
        self.scale = scale
        super.init()
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateMetrics(radius: CGFloat, scale: CGFloat) {
        let targetNode = trailEmitter?.targetNode
        let previousVelocity = physicsBody?.velocity
        let previousDynamic = physicsBody?.isDynamic ?? true
        self.radius = radius
        self.scale = scale
        configureAppearance()
        trailEmitter?.targetNode = targetNode
        physicsBody?.velocity = previousVelocity ?? .zero
        physicsBody?.isDynamic = previousDynamic
    }

    func launch(speed: CGFloat, angle: CGFloat) {
        guard let body = physicsBody else { return }
        let vector = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        body.velocity = vector
    }

    func clampVelocity(maxSpeed: CGFloat) {
        guard let body = physicsBody else { return }
        let v = body.velocity
        let magnitude = sqrt(v.dx * v.dx + v.dy * v.dy)
        if magnitude > maxSpeed {
            let scale = maxSpeed / max(magnitude, 0.001)
            body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
        }
    }

    func setTrailTarget(_ node: SKNode?) {
        trailEmitter?.targetNode = node
    }

    private func configureAppearance() {
        let diameter = radius * 2
        let path = CGPath(
            ellipseIn: CGRect(origin: CGPoint(x: -radius, y: -radius), size: CGSize(width: diameter, height: diameter)),
            transform: nil
        )
        self.path = path
        fillColor = SKColor.white
        strokeColor = SKColor.clear
        glowWidth = 1.5 * scale
        name = "ball"

        haloNode?.removeFromParent()
        trailEmitter?.removeFromParent()

        let halo = BallNode.makeHaloNode(radius: radius, scale: scale)
        addChild(halo)
        haloNode = halo

        let trail = BallNode.makeTrailEmitter(radius: radius, scale: scale)
        addChild(trail)
        trailEmitter = trail

        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.allowsRotation = false
        physicsBody?.friction = 0
        physicsBody?.linearDamping = 0
        physicsBody?.angularDamping = 0
        physicsBody?.restitution = 1
        physicsBody?.categoryBitMask = PhysicsCategory.ball
        physicsBody?.contactTestBitMask = PhysicsCategory.brick | PhysicsCategory.paddle | PhysicsCategory.boundary
        physicsBody?.collisionBitMask = PhysicsCategory.brick | PhysicsCategory.paddle | PhysicsCategory.boundary
    }
}

private extension BallNode {
    static func makeHaloNode(radius: CGFloat, scale: CGFloat) -> SKNode {
        let haloRadius = radius * 1.45
        let node = SKShapeNode(circleOfRadius: haloRadius)
        let glowColor = SKColor(red: 1.0, green: 0.2, blue: 0.35, alpha: 1)
        node.fillColor = glowColor.withAlphaComponent(0.22)
        node.strokeColor = glowColor.withAlphaComponent(0.4)
        node.lineWidth = 1.2 * scale
        node.zPosition = -1
        node.glowWidth = 5.2 * scale
        node.alpha = 0.9
        node.blendMode = .add
        return node
    }

    static func makeTrailEmitter(radius: CGFloat, scale: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = BallNode.trailTexture
        emitter.particleBirthRate = 260
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.22
        emitter.particlePositionRange = CGVector(dx: radius * 0.85, dy: radius * 0.85)
        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 32 * scale
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.18
        emitter.particleAlphaSpeed = -0.9
        emitter.particleScale = 0.42 * scale
        emitter.particleScaleRange = 0.22 * scale
        emitter.particleScaleSpeed = -0.45 * scale
        emitter.particleColor = SKColor(red: 0.18, green: 0.95, blue: 0.98, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.emissionAngleRange = .pi
        emitter.particleBlendMode = .add
        emitter.zPosition = -2
        emitter.targetNode = nil
        emitter.advanceSimulationTime(0.35)
        return emitter
    }

    static let trailTexture: SKTexture = {
        let size = CGSize(width: 10, height: 10)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = Int(size.width)
        let height = Int(size.height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return SKTexture() }

        let gradientColors = [
            SKColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.9).cgColor,
            SKColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) else {
            return SKTexture()
        }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: size.width / 2,
            options: [.drawsAfterEndLocation]
        )

        guard let cgImage = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }()
}
