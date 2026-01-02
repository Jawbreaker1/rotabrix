import SpriteKit

final class BrickNode: SKShapeNode {
    let descriptor: BrickDescriptor
    private(set) var hitPoints: Int
    private let auraNode: SKShapeNode
    private let scale: CGFloat
    var scoreValue: Int { descriptor.kind.baseScore }

    var isExplosive: Bool {
        if case .explosive = descriptor.kind { return true }
        return false
    }

    var isUnbreakable: Bool {
        if case .unbreakable = descriptor.kind { return true }
        return false
    }

    init(descriptor: BrickDescriptor, scale: CGFloat) {
        self.descriptor = descriptor
        self.hitPoints = descriptor.kind.hitPoints
        self.scale = scale

        let size = descriptor.frame.size
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let cornerRadius = 4 * scale
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        self.auraNode = BrickNode.makeAuraNode(for: rect, scale: scale)

        super.init()

        self.path = path
        lineWidth = 1 * scale
        strokeColor = SKColor.white.withAlphaComponent(0.25)
        glowWidth = (isExplosive ? 3 : 1) * scale
        alpha = isUnbreakable ? 0.7 : 0.95
        name = "brick"
        zPosition = 2

        addChild(auraNode)
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
        let color = BrickNode.fillColor(for: descriptor.kind, remaining: hitPoints)
        fillColor = color
        updateAuraColor(using: color)
    }

    private func updateAuraColor(using color: SKColor) {
        auraNode.fillColor = color.withAlphaComponent(0.23)
        auraNode.strokeColor = color.withAlphaComponent(0.48)
        auraNode.lineWidth = 1.0 * scale
        auraNode.glowWidth = 2.2 * scale
        auraNode.blendMode = .add
    }

    private static func makeAuraNode(for rect: CGRect, scale: CGFloat) -> SKShapeNode {
        let inset: CGFloat = -1.7 * scale
        let auraRect = rect.insetBy(dx: inset, dy: inset)
        let path = CGPath(roundedRect: auraRect, cornerWidth: 6 * scale, cornerHeight: 6 * scale, transform: nil)
        let node = SKShapeNode(path: path)
        node.zPosition = -1
        node.alpha = 0.88
        node.isAntialiased = true
        node.fillColor = .clear
        node.strokeColor = .clear
        node.lineJoin = .round
        node.lineCap = .round
        node.blendMode = .add
        node.glowWidth = 0
        return node
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
