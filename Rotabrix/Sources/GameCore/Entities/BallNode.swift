import SpriteKit

final class BallNode: SKShapeNode {
    init(radius: CGFloat) {
        super.init()
        let path = CGPath(ellipseIn: CGRect(origin: CGPoint(x: -radius, y: -radius), size: CGSize(width: radius * 2, height: radius * 2)), transform: nil)
        self.path = path
        fillColor = SKColor.white
        strokeColor = SKColor.clear
        glowWidth = 4
        name = "ball"

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
}
