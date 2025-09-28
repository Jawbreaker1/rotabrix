import SpriteKit
import CoreGraphics

final class GradientBackgroundNode: SKSpriteNode {
    private var palette: [SKColor]

    init(size: CGSize, palette: [SKColor] = GradientBackgroundNode.defaultPalette) {
        self.palette = palette
        let texture = GradientBackgroundNode.makeTexture(size: size, palette: palette)
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
        self.texture = GradientBackgroundNode.makeTexture(size: size, palette: palette)
    }

    func updatePalette(_ colors: [SKColor]) {
        let filtered = colors.isEmpty ? GradientBackgroundNode.defaultPalette : colors
        palette = filtered
        self.texture = GradientBackgroundNode.makeTexture(size: size, palette: palette)
    }

    private static func makeTexture(size: CGSize, palette: [SKColor]) -> SKTexture {
        let width = max(Int(size.width), 2)
        let height = max(Int(size.height), 2)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let stops = palette.isEmpty ? defaultPalette : palette
        let colors = stops.map { $0.cgColor } as CFArray
        let step = stops.count > 1 ? 1.0 / CGFloat(stops.count - 1) : 1.0
        let locations: [CGFloat] = stops.enumerated().map { index, _ in CGFloat(index) * step }
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

    static let defaultPalette: [SKColor] = [
        SKColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1),
        SKColor(red: 0.09, green: 0.16, blue: 0.36, alpha: 1),
        SKColor(red: 0.00, green: 0.30, blue: 0.55, alpha: 0.9)
    ]
}
