import CoreGraphics

enum DropKind: Equatable {
    case extraLife
    case multiBall(count: Int)
    case paddleGrow
    case paddleShrink
    case rotation(angle: CGFloat)
    case points(amount: Int)
    case gun
}

struct DropDescriptor: Equatable {
    let kind: DropKind
}
