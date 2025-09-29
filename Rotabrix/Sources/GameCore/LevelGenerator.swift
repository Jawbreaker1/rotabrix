import CoreGraphics

struct BrickDescriptor {
    enum Kind {
        case standard
        case tough
        case explosive
        case unbreakable

        var hitPoints: Int {
            switch self {
            case .standard: return 1
            case .tough: return 3
            case .explosive: return 1
            case .unbreakable: return .max
            }
        }

        var baseScore: Int {
            switch self {
            case .standard: return GameConfig.scorePerStandardBrick
            case .tough: return GameConfig.scorePerToughBrick
            case .explosive: return GameConfig.scorePerExplosiveBrick
            case .unbreakable: return 0
            }
        }
    }

    let frame: CGRect
    let kind: Kind
    let drop: DropDescriptor?
}

struct LevelLayout {
    let bricks: [BrickDescriptor]
    let seed: UInt64
    let levelNumber: Int
    let baseSize: CGSize
}

final class LevelGenerator {
    private var levelIndex: Int = 1

    func reset() {
        levelIndex = 1
    }

    func nextLayout(for size: CGSize, seed: UInt64? = nil) -> LevelLayout {
        let levelSeed: UInt64
        if let seed = seed {
            levelSeed = seed
        } else {
            levelSeed = GameConfig.levelSeedBase &+ UInt64(levelIndex)
        }

        var random = SeededRandom(seed: levelSeed)
        let bricks = buildBricks(size: size, random: &random)
        let layout = LevelLayout(bricks: bricks, seed: levelSeed, levelNumber: levelIndex, baseSize: size)
        levelIndex += 1
        return layout
    }

    private func buildBricks(size: CGSize, random: inout SeededRandom) -> [BrickDescriptor] {
        var descriptors: [BrickDescriptor] = []
        let columns = GameConfig.brickColumns
        let rows = GameConfig.brickRows

        let usableWidth = size.width
        let topMargin = GameConfig.brickTopMargin
        let bottomMargin = GameConfig.paddleLaneInset + GameConfig.paddleSize.height * 1.5 + GameConfig.brickBottomMargin
        let usableHeight = max(40, size.height - topMargin - bottomMargin)

        let cellWidth = usableWidth / CGFloat(columns)
        let brickWidth = cellWidth - GameConfig.brickSpacing
        let rawCellHeight = usableHeight / CGFloat(rows)
        let cellHeight = rawCellHeight.clamped(to: GameConfig.brickCellHeightMin...GameConfig.brickCellHeightMax)
        let brickHeight = min(GameConfig.brickHeight, cellHeight - GameConfig.brickSpacing)
        let startY = size.height / 2 - topMargin - cellHeight / 2
        let bottomLimit = -size.height / 2 + bottomMargin

        for row in 0..<rows {
            for column in 0..<columns {
                let centerX = (-usableWidth / 2) + cellWidth * CGFloat(column) + cellWidth / 2
                let centerY = startY - CGFloat(row) * cellHeight

                let origin = CGPoint(x: centerX - brickWidth / 2, y: centerY - brickHeight / 2)
                let frame = CGRect(origin: origin, size: CGSize(width: brickWidth, height: brickHeight))

                if frame.minY <= bottomLimit { continue }

                let kind = pickKind(forRow: row, random: &random)
                let drop = pickDrop(for: kind, random: &random)
                let descriptor = BrickDescriptor(frame: frame, kind: kind, drop: drop)
                descriptors.append(descriptor)
            }
        }

        return descriptors
    }

    private func pickKind(forRow row: Int, random: inout SeededRandom) -> BrickDescriptor.Kind {
        let roll = random.nextUniform()
        if row == 0 && roll < 0.2 {
            return .unbreakable
        }

        if roll < 0.1 {
            return .explosive
        } else if roll < 0.35 {
            return .tough
        } else {
            return .standard
        }
    }

    private func pickDrop(for kind: BrickDescriptor.Kind, random: inout SeededRandom) -> DropDescriptor? {
        guard kind != .unbreakable else { return nil }

        let dropChance: Double
        switch kind {
        case .standard:
            dropChance = 0.14
        case .tough:
            dropChance = 0.2
        case .explosive:
            dropChance = 0.22
        case .unbreakable:
            dropChance = 0
        }

        if random.nextUniform() > dropChance {
            return nil
        }

        let roll = random.nextUniform()

        if roll < 0.16 {
            return DropDescriptor(kind: .extraLife)
        } else if roll < 0.32 {
            return DropDescriptor(kind: .multiBall(count: 2))
        } else if roll < 0.48 {
            return DropDescriptor(kind: .paddleGrow)
        } else if roll < 0.64 {
            return DropDescriptor(kind: .paddleShrink)
        } else if roll < 0.78 {
            let rotationAngles: [CGFloat] = [.pi / 2, -.pi / 2, .pi]
            let index = Int(random.nextUniform() * Double(rotationAngles.count)) % rotationAngles.count
            return DropDescriptor(kind: .rotation(angle: rotationAngles[index]))
        } else if roll < 0.9 {
            return DropDescriptor(kind: .gun)
        } else {
            let pointOptions = [100, 1000, 10_000]
            let index = Int(random.nextUniform() * Double(pointOptions.count)) % pointOptions.count
            return DropDescriptor(kind: .points(amount: pointOptions[index]))
        }
    }
}
