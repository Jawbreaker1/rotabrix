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

private struct LevelPattern {
    let rows: [String]
}

final class LevelGenerator {
    private var levelIndex: Int = 1

    func reset(seed: UInt64? = nil) {
        levelIndex = 1
    }

    func nextLayout(for size: CGSize, seed: UInt64? = nil) -> LevelLayout {
        _ = seed // seed kept for compatibility; layouts are predetermined
        let pattern = Self.prebuiltPatterns[min(levelIndex - 1, Self.prebuiltPatterns.count - 1)]
        let bricks = buildBricks(size: size, pattern: pattern)
        let layout = LevelLayout(
            bricks: bricks,
            seed: UInt64(levelIndex),
            levelNumber: levelIndex,
            baseSize: size
        )
        levelIndex = min(levelIndex + 1, Self.prebuiltPatterns.count)
        return layout
    }

    private func buildBricks(size: CGSize, pattern: LevelPattern) -> [BrickDescriptor] {
        var descriptors: [BrickDescriptor] = []
        let columns = GameConfig.brickColumns
        let rows = GameConfig.brickRows

        let usableWidth = size.width
        let topMargin = min(GameConfig.brickTopMargin, size.height * GameConfig.brickTopMarginFraction)
        let baseBottomMargin = GameConfig.paddleLaneInset + GameConfig.paddleSize.height * 1.5 + GameConfig.brickBottomMargin
        let bottomMargin = min(baseBottomMargin, size.height * GameConfig.brickBottomMarginFraction)
        let usableHeight = max(40, size.height - topMargin - bottomMargin)

        let cellWidth = usableWidth / CGFloat(columns)
        let brickWidth = cellWidth - GameConfig.brickSpacing
        let rawCellHeight = usableHeight / CGFloat(rows)
        let cellHeight = rawCellHeight.clamped(to: GameConfig.brickCellHeightMin...GameConfig.brickCellHeightMax)
        let brickHeight = max(10, cellHeight - GameConfig.brickSpacing)
        let startY = size.height / 2 - topMargin - cellHeight / 2
        let bottomLimit = -size.height / 2 + bottomMargin

        for (rowIndex, rowString) in pattern.rows.prefix(rows).enumerated() {
            let centerY = startY - CGFloat(rowIndex) * cellHeight
            let minY = centerY - brickHeight / 2
            if minY <= bottomLimit { continue }

            for (columnIndex, char) in rowString.enumerated() where columnIndex < columns {
                guard let cell = brickCell(for: char) else { continue }
                let centerX = (-usableWidth / 2) + cellWidth * CGFloat(columnIndex) + cellWidth / 2
                let origin = CGPoint(x: centerX - brickWidth / 2, y: centerY - brickHeight / 2)
                let frame = CGRect(origin: origin, size: CGSize(width: brickWidth, height: brickHeight))

                let descriptor = BrickDescriptor(frame: frame, kind: cell.kind, drop: cell.drop)
                descriptors.append(descriptor)
            }
        }

        return descriptors
    }

    private func brickCell(for symbol: Character) -> (kind: BrickDescriptor.Kind, drop: DropDescriptor?)? {
        switch symbol {
        case "s", "S":
            return (.standard, nil)
        case "t", "T":
            return (.tough, nil)
        case "x", "X":
            return (.explosive, nil)
        case "u", "U":
            return (.unbreakable, nil)
        case "m", "M":
            return (.standard, DropDescriptor(kind: .multiBall(count: 3)))
        case "l", "L":
            return (.standard, DropDescriptor(kind: .extraLife))
        case "g", "G":
            return (.standard, DropDescriptor(kind: .gun))
        case "p", "P":
            return (.standard, DropDescriptor(kind: .points(amount: 1_000)))
        case "b", "B":
            return (.standard, DropDescriptor(kind: .paddleGrow))
        case "c", "C":
            return (.standard, DropDescriptor(kind: .paddleShrink))
        case ".":
            return nil
        default:
            return nil
        }
    }

    // 50 hand-crafted, symmetrical layouts (top 3 rows only).
    private static let prebuiltPatterns: [LevelPattern] = [
        LevelPattern(rows: ["ssttss", "s.xx.s", "s.mm.s"]),
        LevelPattern(rows: ["ttbctt", "s....s", "ttsstt"]),
        LevelPattern(rows: ["ssxxss", "..g...", "ssxxss"]),
        LevelPattern(rows: ["uussuu", "ubmmbu", "uussuu"]),
        LevelPattern(rows: [".ssll.", "ssttss", ".ssll."]),
        LevelPattern(rows: ["ss..ss", "xx..xx", "ss..ss"]),
        LevelPattern(rows: ["ssttss", "..mm..", "ssttss"]),
        LevelPattern(rows: [".sspp.", "ssppss", ".sspp."]),
        LevelPattern(rows: ["..xx..", "ssssss", "..xx.."]),
        LevelPattern(rows: ["ssuuss", ".gggg.", "ssuuss"]),
        LevelPattern(rows: ["ssssss", "s....s", "s....s"]),
        LevelPattern(rows: ["ssssss", "ssssss", "......"]),
        LevelPattern(rows: ["..ss..", "ssssss", "..ss.."]),
        LevelPattern(rows: [".ssss.", "..ss..", "......"]),
        LevelPattern(rows: ["..ss..", ".ssss.", "..ss.."]),
        LevelPattern(rows: ["s....s", ".ssss.", "s....s"]),
        LevelPattern(rows: ["..tt..", "tttttt", "..tt.."]),
        LevelPattern(rows: ["ss..ss", "ss..ss", "..ss.."]),
        LevelPattern(rows: ["ssssss", "..ss..", "ssssss"]),
        LevelPattern(rows: ["ssttss", "s....s", "ssttss"]),
        LevelPattern(rows: [".ss.ss", ".ssss.", "..ss.."]),
        LevelPattern(rows: ["uuuuuu", "u....u", "uuuuuu"]),
        LevelPattern(rows: ["ssxxss", "s....s", "ssxxss"]),
        LevelPattern(rows: ["..xx..", ".xxxx.", "..xx.."]),
        LevelPattern(rows: [".tttt.", "ss..ss", ".tttt."]),
        LevelPattern(rows: ["ssssss", ".xx.xx", "ssssss"]),
        LevelPattern(rows: ["ss..ss", "..ss..", "ss..ss"]),
        LevelPattern(rows: [".ssss.", "ssssss", ".ssss."]),
        LevelPattern(rows: ["s.xx.s", "s.xx.s", "s.xx.s"]),
        LevelPattern(rows: [".ssts.", "..ss..", ".ssts."]),
        LevelPattern(rows: ["ssssss", ".ss.ss", "ssssss"]),
        LevelPattern(rows: [".ss.ss", "ssssss", ".ss.ss"]),
        LevelPattern(rows: ["tttttt", ".ssss.", "tttttt"]),
        LevelPattern(rows: ["ss..ss", "ssttss", "ss..ss"]),
        LevelPattern(rows: ["..ss..", "ss..ss", "..ss.."]),
        LevelPattern(rows: ["ssssss", "s.tt.s", "ssssss"]),
        LevelPattern(rows: ["ssxxss", "..ss..", "ssxxss"]),
        LevelPattern(rows: [".ssmm.", "ss..ss", ".ssmm."]),
        LevelPattern(rows: ["ssssss", "..mm..", "ssssss"]),
        LevelPattern(rows: ["ssggss", "s....s", "ssggss"]),
        LevelPattern(rows: ["ssssss", "s.pp.s", "ssssss"]),
        LevelPattern(rows: [".ssll.", "ssssss", ".ssll."]),
        LevelPattern(rows: ["ss..ss", "ssttss", "..mm.."]),
        LevelPattern(rows: ["ssttss", "..xx..", "ssttss"]),
        LevelPattern(rows: ["xxxxxx", "x....x", "xxxxxx"]),
        LevelPattern(rows: [".sstt.", "..xx..", ".ttss."]),
        LevelPattern(rows: ["ssuuss", "s....s", "ssuuss"]),
        LevelPattern(rows: ["uussuu", "..ss..", "uussuu"]),
        LevelPattern(rows: ["ss..ss", "ss..ss", "ss..ss"]),
        LevelPattern(rows: ["..xx..", "xx..xx", "..xx.."]),
        LevelPattern(rows: ["ssssss", ".tttt.", "ssssss"]),
        LevelPattern(rows: [".sspp.", "ssppss", ".sspp."]),
        LevelPattern(rows: ["ss..ss", ".mm.mm", "ss..ss"]),
        LevelPattern(rows: [".gggg.", "gg..gg", ".gggg."]),
        LevelPattern(rows: ["ssttss", "ssttss", "..ss.."]),
        LevelPattern(rows: ["xxssxx", "..ss..", "xxssxx"]),
        LevelPattern(rows: [".sstt.", "ssttss", ".ttss."]),
        LevelPattern(rows: [".ssxx.", "ssssss", ".xxss."]),
        LevelPattern(rows: ["ttsstt", "ss..ss", "ttsstt"]),
        LevelPattern(rows: ["xxxxxx", "..gg..", "xxxxxx"])
    ]
}
