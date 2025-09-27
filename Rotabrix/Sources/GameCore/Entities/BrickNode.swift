import SpriteKit

final class BrickNode: SKShapeNode {
    let descriptor: BrickDescriptor
    private(set) var hitPoints: Int
    var scoreValue: Int { descriptor.kind.baseScore }

    var isExplosive: Bool {
        if case .explosive = descriptor.kind { return true }
        return false
    }

    var isUnbreakable: Bool {
        if case .unbreakable = descriptor.kind { return true }
        return false
    }

    init(descriptor: BrickDescriptor) {
        self.descriptor = descriptor
        self.hitPoints = descriptor.kind.hitPoints

        let size = descriptor.frame.size
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)

        super.init()

        self.path = path
        lineWidth = 1
        strokeColor = SKColor.white.withAlphaComponent(0.25)
        glowWidth = isExplosive ? 3 : 1
        alpha = isUnbreakable ? 0.7 : 0.95
        name = "brick"
        zPosition = 2

        updateFillColor()

        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.brick
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        physicsBody?.collisionBitMask = PhysicsCategory.ball
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyHit() -> Bool {
        guard !isUnbreakable else { return false }
        hitPoints = max(hitPoints - 1, 0)
        updateFillColor()
        return hitPoints == 0
    }

    private func updateFillColor() {
        fillColor = BrickNode.fillColor(for: descriptor.kind, remaining: hitPoints)
    }

    private static func fillColor(for kind: BrickDescriptor.Kind, remaining: Int) -> SKColor {
        switch kind {
        case .standard:
            return SKColor(red: 0.16, green: 0.92, blue: 0.85, alpha: 0.9)
        case .tough:
            let ratio = CGFloat(remaining) / CGFloat(max(kind.hitPoints, 1))
            let base = SKColor(red: 0.78, green: 0.27, blue: 0.96, alpha: 0.9)
            return base.withAlphaComponent(0.5 + 0.4 * ratio)
        case .explosive:
            return SKColor(red: 0.97, green: 0.55, blue: 0.18, alpha: 0.95)
        case .unbreakable:
            return SKColor(red: 0.55, green: 0.63, blue: 0.72, alpha: 0.75)
        }
    }
}
