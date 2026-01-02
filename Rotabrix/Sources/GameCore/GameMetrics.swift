import CoreGraphics

struct GameMetrics {
    static let referenceSize = CGSize(width: 205, height: 251)

    let scale: CGFloat

    init(sceneSize: CGSize) {
        self.scale = GameMetrics.scale(for: sceneSize)
    }

    static func scale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        let widthScale = size.width / referenceSize.width
        let heightScale = size.height / referenceSize.height
        return min(1, min(widthScale, heightScale))
    }

    func scaled(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    func scaled(_ size: CGSize) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}
