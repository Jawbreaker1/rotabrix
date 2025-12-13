import Foundation
import CoreGraphics

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        Swift.min(limits.upperBound, Swift.max(limits.lowerBound, self))
    }
}

extension ClosedRange where Bound == CGFloat {
    func clampedValue(_ value: CGFloat) -> CGFloat {
        Swift.min(upperBound, Swift.max(lowerBound, value))
    }
}

extension ClosedRange where Bound == Double {
    func clampedValue(_ value: Double) -> Double {
        Swift.min(upperBound, Swift.max(lowerBound, value))
    }
}
