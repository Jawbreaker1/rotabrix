import SpriteKit

final class DropNode: SKShapeNode {
    let descriptor: DropDescriptor

    init(descriptor: DropDescriptor) {
        self.descriptor = descriptor

        let size = CGSize(width: 16, height: 16)
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)

        super.init()

        self.path = path
        lineWidth = 1.2
        glowWidth = 0
        isAntialiased = true
        fillColor = DropNode.fillColor(for: descriptor.kind)
        strokeColor = DropNode.strokeColor(for: descriptor.kind)
        name = "drop"

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 10
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.text = DropNode.symbol(for: descriptor.kind)
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension DropNode {
    static func fillColor(for kind: DropKind) -> SKColor {
        switch kind {
        case .extraLife:
            return SKColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.9)
        case .multiBall:
            return SKColor(red: 0.18, green: 0.65, blue: 0.95, alpha: 0.9)
        case .paddleGrow:
            return SKColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.9)
        case .paddleShrink:
            return SKColor(red: 0.95, green: 0.3, blue: 0.25, alpha: 0.9)
        case .rotation:
            return SKColor(red: 0.62, green: 0.45, blue: 0.95, alpha: 0.9)
        case .points(let amount):
            switch amount {
            case _ where amount >= 10_000:
                return SKColor(red: 0.98, green: 0.88, blue: 0.3, alpha: 0.9)
            case _ where amount >= 1_000:
                return SKColor(red: 0.3, green: 0.85, blue: 0.9, alpha: 0.9)
            default:
                return SKColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.9)
            }
        case .gun:
            return SKColor(red: 0.45, green: 0.9, blue: 1.0, alpha: 0.9)
        }
    }

    static func strokeColor(for kind: DropKind) -> SKColor {
        fillColor(for: kind).withAlphaComponent(0.75)
    }

    static func symbol(for kind: DropKind) -> String {
        switch kind {
        case .extraLife:
            return "+"
        case .multiBall:
            return "MB"
        case .paddleGrow:
            return "G"
        case .paddleShrink:
            return "S"
        case .rotation(let angle):
            let degrees = Int(abs(angle * 180 / .pi))
            return "R\(degrees)"
        case .points(let amount):
            switch amount {
            case _ where amount >= 10_000:
                return "10k"
            case _ where amount >= 1_000:
                return "1k"
            default:
                return "+"
            }
        case .gun:
            return "LZ"
        }
    }
}
