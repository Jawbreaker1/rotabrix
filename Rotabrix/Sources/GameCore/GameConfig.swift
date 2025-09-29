import CoreGraphics
import Foundation

enum GameConfig {
    static let paddleSize = CGSize(width: 70, height: 12)
    static let paddleCornerRadius: CGFloat = 6
    static let paddleMoveDamping: CGFloat = 0.18
    static let paddleSnapDistance: CGFloat = 2
    static let paddleLaneInset: CGFloat = 30
    static let paddleResponsiveness: CGFloat = 0.32
    static let paddleEdgeInset: CGFloat = 8

    static let ballRadius: CGFloat = 6
    static let ballInitialSpeed: CGFloat = 340
    static let ballMaximumSpeed: CGFloat = 540

    static let brickRows = 6
    static let brickColumns = 6
    static let brickSpacing: CGFloat = 6
    static let brickHeight: CGFloat = 18
    static let playfieldInset: CGFloat = 6
    static let brickTopMargin: CGFloat = 46
    static let brickBottomMargin: CGFloat = 64
    static let brickCellHeightMin: CGFloat = 24
    static let brickCellHeightMax: CGFloat = 32

    static let levelSeedBase: UInt64 = 0xBA11C0DE
    static let crownSensitivity: Double = 0.0125

    static let rotationFreezeDuration: TimeInterval = 0.35
    static let rotationAnimationDuration: TimeInterval = 0.4
    static let rotationBaseInterval: TimeInterval = 16

    static let ballLaunchDelay: TimeInterval = 0.45
    static let ballRespawnDelayAfterMiss: TimeInterval = 0.9
    static let ballLostMessageFontSize: CGFloat = 19

    static let livesPerRun = 3
    static let scorePerStandardBrick = 100
    static let scorePerToughBrick = 200
    static let scorePerExplosiveBrick = 150
    static let scorePerChainBonus = 75

    static let dropFallSpeed: CGFloat = 95
    static let paddleGrowMultiplier: CGFloat = 2
    static let paddleShrinkMultiplier: CGFloat = 0.5
    static let paddleEffectDuration: TimeInterval = 8
    static let maxLives = 6

    static let gunEffectDuration: TimeInterval = 5
    static let gunFireInterval: TimeInterval = 0.25
    static let gunBeamDuration: TimeInterval = 0.18
    static let gunBeamGlowWidth: CGFloat = 6
    static let gunBeamLineWidth: CGFloat = 2
}
