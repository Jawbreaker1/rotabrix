import CoreGraphics

enum PlayfieldOrientation: Int, CaseIterable {
    case bottom = 0
    case right = 1
    case top = 2
    case left = 3

    var angle: CGFloat {
        switch self {
        case .bottom: return 0
        case .right: return .pi / 2
        case .top: return .pi
        case .left: return -.pi / 2
        }
    }

    func rotated(clockwise quarterTurns: Int) -> PlayfieldOrientation {
        let count = PlayfieldOrientation.allCases.count
        let newIndex = (rawValue + quarterTurns % count + count) % count
        return PlayfieldOrientation(rawValue: newIndex) ?? .bottom
    }

    func next(for angle: CGFloat) -> PlayfieldOrientation {
        if angle > 0 {
            return rotated(clockwise: 1)
        } else if angle < 0 {
            return rotated(clockwise: -1)
        } else {
            return rotated(clockwise: 2) // 180°
        }
    }

    func paddlePosition(normalized value: CGFloat, in size: CGSize, inset: CGFloat) -> CGPoint {
        func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            let minValue = Swift.min(lower, upper)
            let maxValue = Swift.max(lower, upper)
            return Swift.min(maxValue, Swift.max(minValue, value))
        }

        let clamped = clamp(value, lower: 0.0, upper: 1.0)
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        let xMin = -halfWidth + inset
        let xMax = halfWidth - inset
        let yMin = -halfHeight + inset
        let yMax = halfHeight - inset

        func lerp(_ minValue: CGFloat, _ maxValue: CGFloat, _ t: CGFloat) -> CGFloat {
            minValue + (maxValue - minValue) * t
        }

        switch self {
        case .bottom:
            let x = lerp(xMin, xMax, clamped)
            return CGPoint(x: x, y: yMin)
        case .top:
            let x = lerp(xMin, xMax, clamped)
            return CGPoint(x: x, y: yMax)
        case .right:
            let y = lerp(yMin, yMax, 1.0 - clamped)
            return CGPoint(x: xMax, y: y)
        case .left:
            let y = lerp(yMin, yMax, clamped)
            return CGPoint(x: xMin, y: y)
        }
    }

}
