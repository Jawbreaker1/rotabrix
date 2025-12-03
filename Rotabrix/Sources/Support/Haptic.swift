import WatchKit

enum Haptic {
    case paddleHit
    case lifeLost

    static func play(_ haptic: Haptic) {
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
