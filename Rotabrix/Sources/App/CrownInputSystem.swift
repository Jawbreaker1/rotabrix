import Foundation
import Combine

@MainActor
final class CrownInputSystem: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private(set) var normalizedPosition: Double

    private var targetPosition: Double
    private var filteredDelta: Double = 0
    private var lastCrownValue: Double
    private var lastTimestamp: CFTimeInterval?
    private var lastDirection: Double = 0

    init(initialPosition: Double = 0.5, initialCrownValue: Double = 0) {
        let clamped = initialPosition.clamped(to: 0...1)
        normalizedPosition = clamped
        targetPosition = clamped
        lastCrownValue = initialCrownValue
    }

    func process(value: Double, timestamp: CFTimeInterval? = nil) -> Double {
        let time = timestamp ?? Self.currentTimestamp()
        let dt = resolveDeltaTime(for: time)

        var delta = value - lastCrownValue
        lastCrownValue = value
        delta = delta.clamped(to: -GameConfig.crownRawDeltaClamp...GameConfig.crownRawDeltaClamp)

        let direction = delta.sign
        if direction != 0, lastDirection != 0, direction != lastDirection,
           abs(delta) < GameConfig.crownDirectionalGrace {
            delta = 0
        } else if direction != 0 {
            lastDirection = direction
        }

        if abs(delta) < GameConfig.crownNoiseThreshold {
            delta = 0
        }

        let deltaFilter = smoothingResponse(for: dt, base: GameConfig.crownDeltaFilterFactor)
        filteredDelta += (delta - filteredDelta) * deltaFilter

        targetPosition = (targetPosition + filteredDelta * GameConfig.crownPositionGain).clamped(to: 0...1)

        let positionResponse = smoothingResponse(for: dt, base: GameConfig.crownPositionSmoothing)
        normalizedPosition += (targetPosition - normalizedPosition) * positionResponse
        normalizedPosition = normalizedPosition.clamped(to: 0...1)

        if abs(normalizedPosition - targetPosition) < 0.0001 {
            normalizedPosition = targetPosition
        }

        return normalizedPosition
    }

    func reset(position: Double, crownValue: Double, timestamp: CFTimeInterval? = nil) {
        let clamped = position.clamped(to: 0...1)
        normalizedPosition = clamped
        targetPosition = clamped
        filteredDelta = 0
        lastDirection = 0
        lastCrownValue = crownValue
        lastTimestamp = timestamp ?? Self.currentTimestamp()
    }

    func overridePosition(_ value: Double, crownValue: Double? = nil, timestamp: CFTimeInterval? = nil) {
        reset(position: value, crownValue: crownValue ?? lastCrownValue, timestamp: timestamp)
    }

    private func resolveDeltaTime(for time: CFTimeInterval) -> Double {
        let dt: Double
        if let previous = lastTimestamp {
            dt = (time - previous).clamped(to: GameConfig.crownMinUpdateInterval...GameConfig.crownMaxUpdateInterval)
        } else {
            dt = GameConfig.crownMinUpdateInterval
        }
        lastTimestamp = time
        return dt
    }

    private func smoothingResponse(for dt: Double, base: Double) -> Double {
        guard base > 0 else { return 1 }
        let reference = GameConfig.crownSmoothingReferenceFPS
        return 1 - pow(1 - base, dt * reference)
    }

    private static func currentTimestamp() -> CFTimeInterval {
        CFAbsoluteTimeGetCurrent()
    }
}

private extension Double {
    var sign: Double {
        if self > 0 { return 1 }
        if self < 0 { return -1 }
        return 0
    }
}
