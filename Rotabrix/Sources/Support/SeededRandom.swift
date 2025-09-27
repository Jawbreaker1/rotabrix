import CoreGraphics

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed != 0 ? seed : 0xDEADBEEFCAFEBABE
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58476D1CE4E5B9
        result = (result ^ (result >> 27)) &* 0x94D049BB133111EB
        result = result ^ (result >> 31)
        return result
    }

    mutating func nextUniform() -> Double {
        Double(next()) / Double(UInt64.max)
    }

    mutating func nextRange(_ range: ClosedRange<Double>) -> Double {
        let value = nextUniform()
        return range.lowerBound + (range.upperBound - range.lowerBound) * value
    }

    mutating func nextCGFloat(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(nextRange(Double(range.lowerBound)...Double(range.upperBound)))
    }
}
