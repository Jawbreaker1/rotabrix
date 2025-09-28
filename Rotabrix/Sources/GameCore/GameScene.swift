import SpriteKit
import CoreGraphics

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidStart(_ scene: GameScene, score: Int)
    func gameScene(_ scene: GameScene, didUpdateScore score: Int)
    func gameSceneDidEnd(_ scene: GameScene, finalScore: Int)
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private let playfieldNode = SKNode()
    private let brickLayer = SKNode()
    private let dropLayer = SKNode()
    private let hud = GameHUDNode()
    private let parallaxNode = SKNode()
    private var boundaryNode: SKShapeNode?
    private var backgroundNode: GradientBackgroundNode?
    private var starLayers: [SKEmitterNode] = []

    private var paddle: PaddleNode!
    private var ball: BallNode!

    private let levelGenerator = LevelGenerator()
    private var currentLayout: LevelLayout?

    private var orientation: PlayfieldOrientation = .bottom
    private var rotationIndex: Int = 0
    private var paddleTarget: CGFloat = 0.5

    private var score = 0
    private var multiplier = 1
    private var streak = 0
    private var lives = GameConfig.livesPerRun
    private var levelIndex = 1

    private var rotationTimer: TimeInterval = 0
    private var rotationInterval: TimeInterval = GameConfig.rotationBaseInterval
    private var isRotationInProgress = false
    private var storedVelocity: CGVector = .zero
    private var sceneReady = false
    private var queuedStart = false
    private var isGameActive = false
    private var isStartScreenActive = true

    private var lastUpdateTime: TimeInterval = 0
    private var currentLevelNumber: Int = 1

    private let backgroundPalettes: [[SKColor]] = [
        [
            SKColor(red: 0.02, green: 0.03, blue: 0.10, alpha: 1),
            SKColor(red: 0.07, green: 0.18, blue: 0.32, alpha: 1),
            SKColor(red: 0.13, green: 0.45, blue: 0.78, alpha: 0.85)
        ],
        [
            SKColor(red: 0.05, green: 0.02, blue: 0.12, alpha: 1),
            SKColor(red: 0.32, green: 0.00, blue: 0.36, alpha: 1),
            SKColor(red: 0.82, green: 0.24, blue: 0.54, alpha: 0.85)
        ],
        [
            SKColor(red: 0.01, green: 0.06, blue: 0.05, alpha: 1),
            SKColor(red: 0.00, green: 0.35, blue: 0.25, alpha: 1),
            SKColor(red: 0.42, green: 0.95, blue: 0.74, alpha: 0.85)
        ],
        [
            SKColor(red: 0.06, green: 0.03, blue: 0.07, alpha: 1),
            SKColor(red: 0.38, green: 0.15, blue: 0.06, alpha: 1),
            SKColor(red: 0.94, green: 0.53, blue: 0.19, alpha: 0.9)
        ]
    ]

    weak var gameDelegate: GameSceneDelegate?

    private let ballLaunchActionKey = "ballLaunchAction"

    private var portraitPlayfieldBounds: CGRect {
        let inset = GameConfig.playfieldInset
        return CGRect(
            x: -size.width / 2 + inset,
            y: -size.height / 2 + inset,
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset * 2)
        )
    }

    private var landscapePlayfieldBounds: CGRect {
        let inset = GameConfig.playfieldInset
        let width = max(0, size.height - inset * 2)
        let height = max(0, size.width - inset * 2)
        return CGRect(
            x: -width / 2,
            y: -height / 2,
            width: width,
            height: height
        )
    }

    private var currentPlayfieldBounds: CGRect {
        switch orientation {
        case .right, .left:
            return landscapePlayfieldBounds
        case .bottom, .top:
            return portraitPlayfieldBounds
        }
    }

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func sceneDidLoad() {
        super.sceneDidLoad()
        backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupBackground()

        addChild(playfieldNode)
        brickLayer.zPosition = 1
        parallaxNode.zPosition = -8
        playfieldNode.addChild(parallaxNode)
        playfieldNode.addChild(brickLayer)
        playfieldNode.addChild(dropLayer)

        setupBounds()
        setupPaddle()
        setupBall()
        setupHUD()
        sceneReady = true

        applyStartScreenPresentation()

        if queuedStart {
            queuedStart = false
            startNewGame()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard oldSize != size else { return }
        setupBackground()
        setupBounds()
        playfieldNode.zRotation = CGFloat(rotationIndex) * (.pi / 2)
        relayoutBricks(in: currentPlayfieldBounds)
        applyPaddleLayout(targetOverride: nil)
        dropLayer.removeAllChildren()
        clampBallWithinPlayfield()
    }

    func startNewGame() {
        guard sceneReady else {
            queuedStart = true
            return
        }

        score = 0
        multiplier = 1
        streak = 0
        lives = GameConfig.livesPerRun
        levelIndex = 1
        orientation = .bottom
        rotationIndex = orientation.rawValue
        paddleTarget = 0.5
        rotationTimer = 0
        rotationInterval = GameConfig.rotationBaseInterval
        isRotationInProgress = false
        lastUpdateTime = 0
        physicsWorld.speed = 1
        isGameActive = true

        playfieldNode.removeAllActions()
        playfieldNode.zRotation = 0
        setupBounds()
        applyPaddleLayout(targetOverride: 0.5)

        hud.update(score: score, multiplier: multiplier, lives: lives)
        hud.showMessage("Ready")
        gameDelegate?.gameSceneDidStart(self, score: score)
        gameDelegate?.gameScene(self, didUpdateScore: score)

        levelGenerator.reset()
        dropLayer.removeAllChildren()
        currentLevelNumber = 1
        applyBackgroundPalette(forLevel: currentLevelNumber)
        loadNextLevel()
        resetBall(launchAfter: GameConfig.ballLaunchDelay)
        setStartScreenPresentation(active: false)
    }

    func updatePaddleTarget(normalized value: CGFloat) {
        paddleTarget = value.clamped(to: 0...1)
    }

    func normalizedTarget(forTouch location: CGPoint, in viewSize: CGSize) -> CGFloat {
        guard viewSize.width > 0, viewSize.height > 0 else { return paddleTarget }

        let xScene = (location.x / viewSize.width) * size.width - size.width / 2
        let yScene = (1 - location.y / viewSize.height) * size.height - size.height / 2
        let scenePoint = CGPoint(x: xScene, y: yScene)
        let point = playfieldNode.convert(scenePoint, from: self)

        let layout = currentPaddleEdgeLayout()
        let dx = layout.end.x - layout.start.x
        let dy = layout.end.y - layout.start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return paddleTarget }

        let px = point.x - layout.start.x
        let py = point.y - layout.start.y
        let projection = (px * dx + py * dy) / lengthSquared
        return projection.clamped(to: 0...1)
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard delta > 0 else { return }
        guard isGameActive else { return }

        if !isRotationInProgress {
            let layout = currentPaddleEdgeLayout()
            let target = layout.point(at: paddleTarget)
            paddle.moveToward(target, delta: CGFloat(delta))
            paddle.zRotation = 0
        }

        ball.clampVelocity(maxSpeed: GameConfig.ballMaximumSpeed)
        rotationTimer += delta

        if rotationTimer > rotationInterval {
            queueRotation()
        }

        checkLifeLoss()
    }

    // MARK: - Setup

    private func setupBounds() {
        let rect = currentPlayfieldBounds

        boundaryNode?.removeFromParent()
        let path = CGMutablePath()
        let corner: CGFloat = 32
        let left = rect.minX
        let right = rect.maxX
        let top = rect.maxY
        let bottom = rect.minY

        path.move(to: CGPoint(x: left, y: bottom + corner))
        path.addLine(to: CGPoint(x: left, y: top - corner))
        path.addQuadCurve(to: CGPoint(x: left + corner, y: top), control: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right - corner, y: top))
        path.addQuadCurve(to: CGPoint(x: right, y: top - corner), control: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom + corner))

        let boundary = SKShapeNode(path: path)
        boundary.strokeColor = SKColor.white.withAlphaComponent(0.2)
        boundary.lineWidth = 2
        boundary.glowWidth = 9
        boundary.name = "boundary"

        boundary.physicsBody = SKPhysicsBody(edgeChainFrom: path)
        boundary.physicsBody?.categoryBitMask = PhysicsCategory.boundary
        boundary.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        boundary.physicsBody?.collisionBitMask = PhysicsCategory.ball
        boundary.physicsBody?.friction = 0
        boundary.physicsBody?.restitution = 1

        playfieldNode.addChild(boundary)
        boundaryNode = boundary

        configureParallax(for: rect)
        updateHUDLayout()
    }

    private func setupPaddle() {
        paddle = PaddleNode(size: GameConfig.paddleSize)
        let layout = currentPaddleEdgeLayout()
        paddle.position = layout.point(at: paddleTarget)
        paddle.zPosition = 5
        playfieldNode.addChild(paddle)
    }

    private func setupBall() {
        ball = BallNode(radius: GameConfig.ballRadius)
        ball.position = CGPoint(x: 0, y: -currentPlayfieldBounds.height / 4)
        ball.zPosition = 6
        playfieldNode.addChild(ball)
        ball.setTrailTarget(playfieldNode)
    }

    private func setupHUD() {
        hud.layout(in: currentPlayfieldBounds)
        hud.zPosition = 20
        addChild(hud)
    }

    private func updateHUDLayout() {
        hud.layout(in: currentPlayfieldBounds)
    }

    // MARK: - Gameplay

    private func loadNextLevel() {
        brickLayer.removeAllChildren()
        let baseSize = portraitPlayfieldBounds.size
        let layout = levelGenerator.nextLayout(for: baseSize, seed: GameConfig.levelSeedBase &+ UInt64(levelIndex))
        currentLayout = layout
        currentLevelNumber = layout.levelNumber
        applyBackgroundPalette(forLevel: currentLevelNumber)
        levelIndex = layout.levelNumber + 1

        let bounds = currentPlayfieldBounds

        for descriptor in layout.bricks {
            let brick = BrickNode(descriptor: descriptor)
            brick.position = positionForBrick(descriptor: descriptor, layout: layout, in: bounds)
            brickLayer.addChild(brick)
        }
    }

    private func resetBall(launchAfter delay: TimeInterval = GameConfig.ballLaunchDelay, freezePhysics: Bool = false) {
        guard let body = ball.physicsBody else { return }

        body.velocity = .zero

        let center = CGPoint(x: currentPlayfieldBounds.midX, y: currentPlayfieldBounds.midY)
        let toCenter = CGVector(dx: center.x - paddle.position.x, dy: center.y - paddle.position.y)

        let direction: CGVector
        if toCenter.magnitude > 0.001 {
            let inverse = 1 / toCenter.magnitude
            direction = CGVector(dx: toCenter.dx * inverse, dy: toCenter.dy * inverse)
        } else {
            direction = orientationInteriorDirection()
        }

        let offsetDistance = GameConfig.paddleSize.height + GameConfig.ballRadius * 2
        let offset = CGVector(dx: direction.dx * offsetDistance, dy: direction.dy * offsetDistance)

        ball.position = CGPoint(
            x: paddle.position.x + offset.dx,
            y: paddle.position.y + offset.dy
        )

        clampBallWithinPlayfield()
        ball.isHidden = false

        if freezePhysics {
            physicsWorld.speed = 0
        }

        removeAction(forKey: ballLaunchActionKey)

        let launch = SKAction.run { [weak self] in
            guard let self, let physicsBody = self.ball.physicsBody else { return }
            if freezePhysics {
                self.physicsWorld.speed = 1
            }
            let angle = CGFloat.random(in: (.pi / 4)...(.pi * 3 / 4))
            physicsBody.velocity = CGVector(
                dx: cos(angle) * GameConfig.ballInitialSpeed,
                dy: sin(angle) * GameConfig.ballInitialSpeed
            ).rotated(by: self.orientationBaseAngle())
        }

        if delay > 0 {
            let wait = SKAction.wait(forDuration: delay)
            run(.sequence([wait, launch]), withKey: ballLaunchActionKey)
        } else {
            run(launch, withKey: ballLaunchActionKey)
        }
    }

    private func queueRotation() {
        guard !isRotationInProgress else { return }
        guard isGameActive else { return }
        isRotationInProgress = true
        rotationTimer = 0

        let options: [CGFloat] = [.pi / 2, -.pi / 2, .pi]
        let choice = options.randomElement() ?? .pi / 2
        storedVelocity = ball.physicsBody?.velocity ?? .zero

        hud.showMessage(choice == .pi ? "180 Spin" : (choice > 0 ? "Rotate +90" : "Rotate -90"))
        let freeze = SKAction.run { [weak self] in self?.physicsWorld.speed = 0 }
        let wait = SKAction.wait(forDuration: GameConfig.rotationFreezeDuration)
        let rotate = SKAction.rotate(byAngle: choice, duration: GameConfig.rotationAnimationDuration)
        rotate.timingMode = .easeInEaseOut
        let resume = SKAction.run { [weak self] in self?.finishRotation(by: choice) }

        playfieldNode.run(.sequence([freeze, wait, rotate, resume]))
    }

    private func finishRotation(by angle: CGFloat) {
        physicsWorld.speed = 1
        isRotationInProgress = false
        multiplier = max(1, multiplier - 1)
        hud.update(score: score, multiplier: multiplier, lives: lives)

        rotationIndex = (rotationIndex + quarterTurns(for: angle) + 4) % 4
        orientation = PlayfieldOrientation(rawValue: rotationIndex) ?? .bottom
        playfieldNode.zRotation = CGFloat(rotationIndex) * (.pi / 2)
        setupBounds()
        relayoutBricks(in: currentPlayfieldBounds)
        applyPaddleLayout(targetOverride: nil)
        hud.layout(in: currentPlayfieldBounds)
        dropLayer.removeAllChildren()
        clampBallWithinPlayfield()

        let rotatedVelocity = storedVelocity.rotated(by: angle)
        ball.physicsBody?.velocity = rotatedVelocity
        storedVelocity = .zero

        rotationInterval = max(7, rotationInterval * 0.93)
    }

    private func checkLifeLoss() {
        guard let body = ball.physicsBody, lives > 0 else { return }
        let limit: CGFloat = 48

        let bounds = currentPlayfieldBounds

        let localEdgeMid = CGPoint(x: bounds.midX, y: bounds.minY)
        let localCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        let edgePoint = playfieldNode.convert(localEdgeMid, to: self)
        let centerPoint = playfieldNode.convert(localCenter, to: self)

        let outwardDx = edgePoint.x - centerPoint.x
        let outwardDy = edgePoint.y - centerPoint.y
        let outwardLength = sqrt(outwardDx * outwardDx + outwardDy * outwardDy)

        if outwardLength > 0 {
            let unitX = outwardDx / outwardLength
            let unitY = outwardDy / outwardLength

            let ballPoint = playfieldNode.convert(ball.position, to: self)
            let offsetX = ballPoint.x - edgePoint.x
            let offsetY = ballPoint.y - edgePoint.y

            let distanceBeyondEdge = offsetX * unitX + offsetY * unitY

            if distanceBeyondEdge > limit {
                loseLife()
            }
        }

        body.velocity = body.velocity.limited(minSpeed: GameConfig.ballInitialSpeed * 0.75, maxSpeed: GameConfig.ballMaximumSpeed)
    }

    private func applyPaddleLayout(targetOverride: CGFloat?) {
        orientation = PlayfieldOrientation(rawValue: rotationIndex) ?? orientation
        let layout = currentPaddleEdgeLayout()

        let resolvedTarget: CGFloat
        if let override = targetOverride {
            resolvedTarget = override.clamped(to: 0...1)
        } else {
            resolvedTarget = paddleTarget.clamped(to: 0...1)
        }

        paddleTarget = resolvedTarget
        let targetPoint = layout.point(at: resolvedTarget)
        paddle.position = targetPoint
        paddle.zRotation = 0
        updateHUDLayout()
        rotationIndex = orientation.rawValue
    }

    private func setupBackground() {
        let currentSize = size
        if let background = backgroundNode {
            background.updateSize(currentSize)
        } else {
            let node = GradientBackgroundNode(size: currentSize)
            addChild(node)
            backgroundNode = node
        }
    }

private func configureParallax(for rect: CGRect) {
        parallaxNode.removeAllChildren()
        starLayers.removeAll()

        let layers: [(parallax: CGFloat, speed: CGFloat, alpha: CGFloat, colors: [SKColor], birthRate: CGFloat, scale: CGFloat)] = [
            (
                0.25,
                26,
                0.55,
                [
                    SKColor(white: 0.95, alpha: 1),
                    SKColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 1)
                ],
                14,
                0.46
            ),
            (
                0.55,
                34,
                0.65,
                [
                    SKColor(white: 0.95, alpha: 1),
                    SKColor(red: 1.0, green: 0.8, blue: 0.55, alpha: 1),
                    SKColor(red: 1.0, green: 0.55, blue: 0.45, alpha: 1)
                ],
                18,
                0.54
            ),
            (
                1.0,
                42,
                0.75,
                [
                    SKColor(white: 0.95, alpha: 1),
                    SKColor(red: 1.0, green: 0.88, blue: 0.5, alpha: 1),
                    SKColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1)
                ],
                24,
                0.64
            )
        ]

        for (index, entry) in layers.enumerated() {
            let (parallax, speed, alpha, colors, birthRate, scale) = entry
            let layer = makeStarLayer(
                parallax: parallax,
                speed: speed,
                alpha: alpha,
                colors: colors,
                birthRate: birthRate,
                baseScale: scale,
                rect: rect
            )
            layer.zPosition = CGFloat(-4 + index)
            parallaxNode.addChild(layer)
            starLayers.append(layer)
        }
    }

    private func makeStarLayer(
        parallax: CGFloat,
        speed: CGFloat,
        alpha: CGFloat,
        colors: [SKColor],
        birthRate: CGFloat,
        baseScale: CGFloat,
        rect: CGRect
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.starTexture
        emitter.particleBirthRate = birthRate
        let absoluteSpeed = max(speed, 12)
        let travelDistance = rect.height + 80
        emitter.particleLifetime = travelDistance / absoluteSpeed
        emitter.particleAlpha = alpha
        emitter.particleAlphaRange = 0.28
        emitter.particleAlphaSpeed = -0.08
        emitter.particleColor = colors.first ?? SKColor(white: 0.95, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleSpeed = absoluteSpeed
        emitter.particleSpeedRange = absoluteSpeed * 0.12
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 24
        emitter.particleScale = baseScale + 0.18 * parallax
        emitter.particleScaleRange = baseScale * 0.65
        emitter.particleScaleSpeed = -0.01
        emitter.particlePositionRange = CGVector(dx: rect.width + 40, dy: rect.height * 0.1)
        emitter.position = CGPoint(x: 0, y: rect.height / 2 + 24)
        emitter.advanceSimulationTime(Double(travelDistance / absoluteSpeed))
        emitter.particleBlendMode = .add

        if colors.count > 1 {
            let count = colors.count - 1
            let times = colors.enumerated().map { index, _ in
                count == 0 ? 0.0 : Double(index) / Double(count)
            }
            let sequence = SKKeyframeSequence(keyframeValues: colors, times: times.map { NSNumber(value: $0) })
            emitter.particleColorSequence = sequence
        } else {
            emitter.particleColorSequence = nil
        }

        return emitter
    }

    private static let starTexture: SKTexture = {
        let size = CGSize(width: 4, height: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = Int(size.width)
        let height = Int(size.height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return SKTexture() }

        context.setFillColor(SKColor.white.cgColor)
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.6, dy: 0.6)
        context.fillEllipse(in: rect)

        guard let cgImage = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }()

    private func quarterTurns(for angle: CGFloat) -> Int {
        let tolerance: CGFloat = 0.001
        if abs(abs(angle) - .pi) < tolerance {
            return 2
        }
        return angle > 0 ? 1 : -1
    }

    private struct PaddleEdgeLayout {
        let start: CGPoint
        let end: CGPoint

        func point(at normalized: CGFloat) -> CGPoint {
            let clamped = normalized.clamped(to: 0...1)
            return CGPoint(
                x: start.x + (end.x - start.x) * clamped,
                y: start.y + (end.y - start.y) * clamped
            )
        }
    }

    private func currentPaddleEdgeLayout() -> PaddleEdgeLayout {
        let rect = currentPlayfieldBounds
        let lane = GameConfig.paddleLaneInset
        let edge = GameConfig.paddleEdgeInset

        return PaddleEdgeLayout(
            start: CGPoint(x: rect.minX + edge, y: rect.minY + lane),
            end: CGPoint(x: rect.maxX - edge, y: rect.minY + lane)
        )
    }

    private func loseLife() {
        lives -= 1
        multiplier = 1
        streak = 0
        hud.update(score: score, multiplier: multiplier, lives: lives)

        if lives <= 0 {
            hud.showMessage("Game Over")
            gameOver()
        } else {
            hud.showMessage(
                "Ball Lost",
                fontSize: GameConfig.ballLostMessageFontSize,
                duration: GameConfig.ballRespawnDelayAfterMiss
            )
            resetBall(
                launchAfter: GameConfig.ballRespawnDelayAfterMiss,
                freezePhysics: true
            )
        }
    }

    private func gameOver() {
        isGameActive = false
        physicsWorld.speed = 0
        rotationTimer = 0
        isRotationInProgress = false
        playfieldNode.removeAllActions()
        removeAction(forKey: ballLaunchActionKey)
        ball.physicsBody?.velocity = .zero
        ball.removeAllActions()
        setStartScreenPresentation(active: true)
        gameDelegate?.gameSceneDidEnd(self, finalScore: score)
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard let aNode = contact.bodyA.node, let bNode = contact.bodyB.node else { return }

        if let brick = (aNode as? BrickNode) ?? (bNode as? BrickNode), aNode.name == "ball" || bNode.name == "ball" {
            handleBrickHit(brick)
        }

        if (aNode.name == "paddle" && bNode.name == "ball") || (aNode.name == "ball" && bNode.name == "paddle") {
            handlePaddleHit()
        }
    }

    private func handleBrickHit(_ brick: BrickNode) {
        if brick.applyHit() {
            addScore(for: brick)
            runExplosion(at: brick.position, explosive: brick.isExplosive)
            brick.removeFromParent()

            if brick.isExplosive {
                triggerExplosionChain(from: brick.position, radius: 60)
            }

            if brickLayer.children.compactMap({ $0 as? BrickNode }).allSatisfy({ $0.isUnbreakable }) {
                levelCleared()
            }
        } else {
            streak += 1
        }
    }

    private func handlePaddleHit() {
        streak += 1
        if streak % 6 == 0 {
            multiplier = min(10, multiplier + 1)
        }
        hud.update(score: score, multiplier: multiplier, lives: lives)

        guard let body = ball.physicsBody else { return }
        let ballScenePosition = playfieldNode.convert(ball.position, to: self)
        let paddleScenePosition = playfieldNode.convert(paddle.position, to: self)
        let contactVector = CGVector(
            dx: ballScenePosition.x - paddleScenePosition.x,
            dy: ballScenePosition.y - paddleScenePosition.y
        )

        let baseAngle = orientationBaseAngle()
        let canonicalImpact = contactVector.rotated(by: -baseAngle)
        let axisSign: CGFloat = orientation == .bottom ? 1 : -1
        let maxOffset = GameConfig.paddleSize.width / 2
        let normalized = (canonicalImpact.dx * axisSign / maxOffset).clamped(to: CGFloat(-1)...CGFloat(1))
        let speed = max(body.velocity.magnitude, GameConfig.ballInitialSpeed)
        let angleOffset = normalized * (.pi / 4)
        let newAngle = baseAngle + (.pi / 2) + angleOffset
        body.velocity = CGVector(dx: cos(newAngle) * speed, dy: sin(newAngle) * speed)
    }

    private func levelCleared() {
        hud.showMessage("Level \(levelIndex - 1) Clear")
        rotationInterval = max(6, rotationInterval * 0.9)
        run(.wait(forDuration: 1)) { [weak self] in
            guard let self else { return }
            self.loadNextLevel()
            self.resetBall(launchAfter: GameConfig.ballLaunchDelay)
        }
    }

    private func addScore(for brick: BrickNode) {
        let bonus = brick.isExplosive ? GameConfig.scorePerChainBonus : 0
        score += (brick.scoreValue + bonus) * multiplier
        hud.update(score: score, multiplier: multiplier, lives: lives)
        gameDelegate?.gameScene(self, didUpdateScore: score)
    }

    private func runExplosion(at point: CGPoint, explosive: Bool) {
        let radius: CGFloat = explosive ? 76 : 42
        let pulse = SKShapeNode(circleOfRadius: radius)
        pulse.position = point
        pulse.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.12, alpha: 0.55)
        pulse.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.05, alpha: 0.2)
        pulse.lineWidth = 2.4
        pulse.alpha = 0.95
        pulse.zPosition = 15
        pulse.blendMode = .add
        playfieldNode.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: explosive ? 4.5 : 2.9, duration: 0.75),
                .fadeOut(withDuration: 0.75)
            ]),
            .removeFromParent()
        ]))

        let sparkEmitter = makeExplosionEmitter(big: explosive)
        sparkEmitter.position = point
        playfieldNode.addChild(sparkEmitter)
        sparkEmitter.run(.sequence([
            .wait(forDuration: sparkEmitter.particleLifetime * 1.4),
            .removeFromParent()
        ]))

        let shardEmitter = makeShardEmitter(big: explosive)
        shardEmitter.position = point
        playfieldNode.addChild(shardEmitter)
        shardEmitter.run(.sequence([
            .wait(forDuration: shardEmitter.particleLifetime * 1.2),
            .removeFromParent()
        ]))
    }

    private func triggerExplosionChain(from point: CGPoint, radius: CGFloat) {
        let affected = brickLayer.children.compactMap { $0 as? BrickNode }.filter { brick in
            brick.position.distance(to: point) <= radius && !brick.isUnbreakable
        }

        for target in affected {
            addScore(for: target)
            runExplosion(at: target.position, explosive: false)
            target.removeFromParent()
        }

        if brickLayer.children.compactMap({ $0 as? BrickNode }).allSatisfy({ $0.isUnbreakable }) {
            levelCleared()
        }
    }

    private func orientationBaseAngle() -> CGFloat {
        switch orientation {
        case .bottom: return 0
        case .right: return .pi / 2
        case .top: return .pi
        case .left: return -.pi / 2
        }
    }

    private func orientationInteriorDirection() -> CGVector {
        let angle = orientationBaseAngle() + (.pi / 2)
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private func positionForBrick(descriptor: BrickDescriptor, layout: LevelLayout, in bounds: CGRect) -> CGPoint {
        let halfOriginalWidth = max(layout.baseSize.width / 2, 1)
        let halfOriginalHeight = max(layout.baseSize.height / 2, 1)
        let normalizedX = descriptor.frame.midX / halfOriginalWidth
        let normalizedY = descriptor.frame.midY / halfOriginalHeight
        let centerX = bounds.midX + normalizedX * (bounds.width / 2)
        let centerY = bounds.midY + normalizedY * (bounds.height / 2)
        return CGPoint(x: centerX, y: centerY)
    }

    private func relayoutBricks(in bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard let layout = currentLayout else { return }

        for case let brick as BrickNode in brickLayer.children {
            brick.position = positionForBrick(descriptor: brick.descriptor, layout: layout, in: bounds)
        }
    }

    private func clampBallWithinPlayfield() {
        guard let ballNode = ball else { return }
        let bounds = currentPlayfieldBounds.insetBy(dx: GameConfig.ballRadius, dy: GameConfig.ballRadius)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let clampedX = ballNode.position.x.clamped(to: bounds.minX...bounds.maxX)
        let clampedY = ballNode.position.y.clamped(to: bounds.minY...bounds.maxY)
        ballNode.position = CGPoint(x: clampedX, y: clampedY)
    }

    func setStartScreenPresentation(active: Bool) {
        isStartScreenActive = active
        applyStartScreenPresentation()
    }

    private func applyStartScreenPresentation() {
        guard sceneReady else { return }
        let hidden = isStartScreenActive
        hud.isHidden = hidden
        brickLayer.isHidden = hidden
        dropLayer.isHidden = hidden
        paddle?.isHidden = hidden
        ball?.isHidden = hidden
        boundaryNode?.isHidden = hidden
    }

    private func paletteForLevel(_ level: Int) -> [SKColor] {
        guard !backgroundPalettes.isEmpty else { return GradientBackgroundNode.defaultPalette }
        let index = (level - 1).positiveModulo(of: backgroundPalettes.count)
        return backgroundPalettes[index]
    }

    private func applyBackgroundPalette(forLevel level: Int) {
        guard let background = backgroundNode else { return }
        background.updatePalette(paletteForLevel(level))
    }

    private func makeExplosionEmitter(big: Bool) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.starTexture
        emitter.numParticlesToEmit = big ? 96 : 62
        emitter.particleBirthRate = big ? 780 : 520
        emitter.particleLifetime = big ? 1.1 : 0.8
        emitter.particleLifetimeRange = big ? 0.35 : 0.22
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.25
        emitter.particleAlphaSpeed = -2.8
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            SKColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 1),
            SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
            SKColor(red: 0.65, green: 0.1, blue: 0.03, alpha: 1)
        ], times: [0, 0.4, 1])
        emitter.particleSpeed = big ? 420 : 300
        emitter.particleSpeedRange = big ? 220 : 160
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = big ? 0.68 : 0.52
        emitter.particleScaleRange = big ? 0.42 : 0.32
        emitter.particleScaleSpeed = -1.4
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = .pi * 1.9
        emitter.particleBlendMode = .add
        emitter.zPosition = 16
        emitter.particlePositionRange = CGVector(dx: 6, dy: 6)
        return emitter
    }

    private func makeShardEmitter(big: Bool) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.starTexture
        emitter.particleBirthRate = big ? 280 : 190
        emitter.numParticlesToEmit = big ? 28 : 18
        emitter.particleLifetime = big ? 1.4 : 1.0
        emitter.particleLifetimeRange = big ? 0.45 : 0.3
        emitter.particleAlpha = 0.9
        emitter.particleAlphaRange = 0.15
        emitter.particleAlphaSpeed = -0.95
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            SKColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1),
            SKColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 1),
            SKColor(red: 0.35, green: 0.05, blue: 0.02, alpha: 0.8)
        ], times: [0, 0.5, 1])
        emitter.particleSpeed = big ? 520 : 340
        emitter.particleSpeedRange = big ? 160 : 120
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = big ? 0.38 : 0.28
        emitter.particleScaleRange = big ? 0.22 : 0.18
        emitter.particleScaleSpeed = -0.45
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = .pi
        emitter.particleBlendMode = .add
        emitter.xAcceleration = 0
        emitter.yAcceleration = -420
        emitter.particlePositionRange = CGVector(dx: 4, dy: 4)
        emitter.zPosition = 16
        return emitter
    }
}

private extension CGFloat {
    static func random(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(Double.random(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}

private extension CGVector {
    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    func rotated(by angle: CGFloat) -> CGVector {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGVector(dx: dx * cosine - dy * sine, dy: dx * sine + dy * cosine)
    }

    func limited(minSpeed: CGFloat, maxSpeed: CGFloat) -> CGVector {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        let clamped = min(maxSpeed, max(minSpeed, mag))
        if mag == clamped { return self }
        let scale = clamped / mag
        return CGVector(dx: dx * scale, dy: dy * scale)
    }
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - x, point.y - y)
    }
}

private extension Int {
    func positiveModulo(of modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let remainder = self % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
