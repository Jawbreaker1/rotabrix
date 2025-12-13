import WatchKit

enum Haptic {
    case paddleHit
    case lifeLost

    static var isEnabled = true

    static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    static func play(_ haptic: Haptic) {
        guard isEnabled else { return }
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        switch haptic {
        case .paddleHit:
            device.play(.click)
        case .lifeLost:
            device.play(.failure)
        }
        #endif
    }
}
