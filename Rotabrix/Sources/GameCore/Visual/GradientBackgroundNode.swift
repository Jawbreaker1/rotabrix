import SpriteKit
import CoreGraphics

final class GradientBackgroundNode: SKSpriteNode {
    init(size: CGSize) {
        let texture = GradientBackgroundNode.makeTexture(size: size)
        super.init(texture: texture, color: .clear, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        zPosition = -60
        blendMode = .screen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        self.size = size
        self.texture = GradientBackgroundNode.makeTexture(size: size)
    }

    private static func makeTexture(size: CGSize) -> SKTexture {
        let width = max(Int(size.width), 2)
        let height = max(Int(size.height), 2)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            SKColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1).cgColor,
            SKColor(red: 0.09, green: 0.16, blue: 0.36, alpha: 1).cgColor,
            SKColor(red: 0.00, green: 0.30, blue: 0.55, alpha: 1).withAlphaComponent(0.9).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.6, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return SKTexture()
        }

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        let radius = max(size.width, size.height) * 0.8
        context?.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )

        if let cgImage = context?.makeImage() {
            return SKTexture(cgImage: cgImage)
        }

        return SKTexture()
    }
}
