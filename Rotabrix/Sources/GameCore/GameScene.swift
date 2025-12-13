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
    private var additionalBalls: [BallNode] = []

    private let levelGenerator = LevelGenerator()
    private var runSeed: UInt64 = GameConfig.levelSeedBase
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
    private var storedBallVelocities: [ObjectIdentifier: CGVector] = [:]
    private var sceneReady = false
    private var isCountdownActive = false
    private var queuedStart = false
    private var isGameActive = false
    private var isStartScreenActive = true
    private var isBallRespawning = false
    private let stalledVelocityThreshold = GameConfig.ballInitialSpeed * 0.25
    private var paddleScaleEffectRemaining: TimeInterval = 0
    private var gunEffectRemaining: TimeInterval = 0
    private var laserCooldown: TimeInterval = 0
    private var paddleHitShakeCooldown: TimeInterval = 0
    private var paddleHapticCooldown: TimeInterval = 0
    private var currentBallSpeedMultiplier: CGFloat = 1.0

    private var lastUpdateTime: TimeInterval = 0
    private var currentLevelNumber: Int = 1

    private let transitionLayer = SKNode()
    private var isLevelTransitionActive = false

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
    private let countdownActionKey = "countdownAction"
    private var activeBalls: [BallNode] {
        var balls: [BallNode] = []
        balls.append(ball)
        balls.append(contentsOf: additionalBalls)
        return balls
    }
    private var activeDrops: [DropNode] {
        dropLayer.children.compactMap { $0 as? DropNode }
    }

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

    private var hudBounds: CGRect {
        CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
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
        setupTransitionLayer()
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
        clampBallsWithinPlayfield()
        updateTransitionLayerLayout()
    }

    func startNewGame() {
        guard sceneReady else {
            queuedStart = true
            return
        }

        runSeed = GameConfig.levelSeedBase
        levelGenerator.reset(seed: runSeed)
        clearAdditionalBalls()

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
        physicsWorld.speed = 0
        isGameActive = false
        isCountdownActive = true
        isBallRespawning = false
        paddleScaleEffectRemaining = 0
        applyPaddleScale(multiplier: 1)
        gunEffectRemaining = 0
        laserCooldown = 0
        transitionLayer.removeAllChildren()
        transitionLayer.removeAllActions()
        transitionLayer.isHidden = true
        isLevelTransitionActive = false
        currentBallSpeedMultiplier = 1.0

        playfieldNode.removeAllActions()
        playfieldNode.zRotation = 0
        setupBounds()
        applyPaddleLayout(targetOverride: 0.5)

        paddle.alpha = 1
        hud.alpha = 1
        ball.isHidden = false

        hud.update(score: score, multiplier: multiplier, lives: lives)
        hud.showMessage("Ready")
        gameDelegate?.gameSceneDidStart(self, score: score)
        gameDelegate?.gameScene(self, didUpdateScore: score)

        dropLayer.removeAllChildren()
        currentLevelNumber = 1
        applyBackgroundPalette(forLevel: currentLevelNumber)
        loadNextLevel()
        anchorBallForServe()
        setStartScreenPresentation(active: false)
        startCountdown()
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

        if isCountdownActive {
            let layout = currentPaddleEdgeLayout()
            let target = layout.point(at: paddleTarget)
            paddle.moveToward(target, delta: CGFloat(delta))
            paddle.zRotation = 0

            // Keep the ball attached to the paddle while physics is paused.
            let anchor = anchoredBallPosition()
            ball.position = anchor
            clampBallsWithinPlayfield()
            return
        }

        guard isGameActive else { return }

        if isRotationInProgress {
            updatePaddleScaleTimer(delta: delta)
            return
        }
        paddleHitShakeCooldown = max(0, paddleHitShakeCooldown - delta)
        paddleHapticCooldown = max(0, paddleHapticCooldown - delta)

        if !isRotationInProgress {
            let layout = currentPaddleEdgeLayout()
            let target = layout.point(at: paddleTarget)
            paddle.moveToward(target, delta: CGFloat(delta))
            paddle.zRotation = 0
        }

        for ballNode in activeBalls {
            ballNode.clampVelocity(maxSpeed: GameConfig.ballMaximumSpeed)
            dislodgeIfAxisAligned(ballNode)
        }

        if isBallRespawning {
            rotationTimer = 0
        } else {
            rotationTimer += delta
            if rotationTimer > rotationInterval {
                queueRotation()
            }
            checkLifeLoss()
            restoreBallVelocityIfStalled()
        }

        updateDrops(delta: delta)
        updatePaddleScaleTimer(delta: delta)
        updateGun(delta: delta)
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
        hud.layout(in: hudBounds)
        hud.zPosition = 20
        addChild(hud)
    }

    private func updateHUDLayout() {
        hud.layout(in: hudBounds)
    }

    private func setupTransitionLayer() {
        transitionLayer.zPosition = 200
        transitionLayer.isHidden = true
        addChild(transitionLayer)
    }

    private func updateTransitionLayerLayout() {
        for case let cover as SKSpriteNode in transitionLayer.children {
            cover.size = size
        }
    }

    // MARK: - Gameplay

    private func loadNextLevel() {
        brickLayer.removeAllChildren()
        let baseSize = portraitPlayfieldBounds.size
        let layout = levelGenerator.nextLayout(for: baseSize)
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

    private func clearAdditionalBalls() {
        for extra in additionalBalls {
            extra.removeAllActions()
            extra.removeFromParent()
        }
        additionalBalls.removeAll()
    }

    private func anchoredBallPosition() -> CGPoint {
        let center = CGPoint(x: currentPlayfieldBounds.midX, y: currentPlayfieldBounds.midY)
        let toCenter = CGVector(dx: center.x - paddle.position.x, dy: center.y - paddle.position.y)
        let direction: CGVector
        if toCenter.magnitude > 0.001 {
            direction = toCenter.normalized
        } else {
            direction = CGVector(dx: 0, dy: 1)
        }
        let offsetDistance = GameConfig.paddleSize.height + GameConfig.ballRadius * 2
        let offset = CGVector(dx: direction.dx * offsetDistance, dy: direction.dy * offsetDistance)
        return CGPoint(
            x: paddle.position.x + offset.dx,
            y: paddle.position.y + offset.dy
        )
    }

    private func anchorBallForServe() {
        clearAdditionalBalls()
        if ball.parent == nil {
            playfieldNode.addChild(ball)
            ball.setTrailTarget(playfieldNode)
        }

        ball.physicsBody?.velocity = .zero
        ball.physicsBody?.isDynamic = false

        ball.position = anchoredBallPosition()

        clampBallsWithinPlayfield()
        ball.isHidden = false
    }

    private func applyPaddleScale(multiplier: CGFloat, duration: TimeInterval? = nil) {
        let clampedMultiplier = max(0.3, min(multiplier, 3))
        paddle.setWidthMultiplier(clampedMultiplier)
        applyPaddleLayout(targetOverride: nil)
        if let duration {
            paddleScaleEffectRemaining = duration
        } else {
            paddleScaleEffectRemaining = 0
        }
    }

    private func updatePaddleScaleTimer(delta: TimeInterval) {
        guard paddleScaleEffectRemaining > 0 else { return }
        paddleScaleEffectRemaining = max(0, paddleScaleEffectRemaining - delta)
        if paddleScaleEffectRemaining == 0 {
            applyPaddleScale(multiplier: 1)
        }
    }

    private func spawnAdditionalBalls(count: Int) {
        guard count > 0 else { return }
        let baseVelocity = ball.physicsBody?.velocity ?? .zero
        let fallbackDirection = orientationInteriorDirection()
        let baseVector: CGVector
        if baseVelocity.magnitude >= stalledVelocityThreshold {
            baseVector = baseVelocity
        } else {
            baseVector = CGVector(dx: fallbackDirection.dx * GameConfig.ballInitialSpeed,
                                  dy: fallbackDirection.dy * GameConfig.ballInitialSpeed)
        }

        let baseAngle = atan2(baseVector.dy, baseVector.dx)
        let baseSpeed = max(baseVector.magnitude, GameConfig.ballInitialSpeed)
        let spread: CGFloat = .pi / 12

        for index in 0..<count {
            let newBall = BallNode(radius: GameConfig.ballRadius)
            newBall.position = ball.position
            newBall.zPosition = 6
            newBall.setTrailTarget(playfieldNode)
            playfieldNode.addChild(newBall)

            let offset = CGFloat(index) - CGFloat(count - 1) / 2
            let angle = baseAngle + offset * spread
            newBall.physicsBody?.velocity = CGVector(
                dx: cos(angle) * baseSpeed,
                dy: sin(angle) * baseSpeed
            )

            additionalBalls.append(newBall)
        }
    }

    private func spawnDrop(for descriptor: DropDescriptor, at position: CGPoint) {
        let drop = DropNode(descriptor: descriptor)
        drop.position = position
        drop.zPosition = 4
        drop.zRotation = playfieldNode.zRotation
        drop.alpha = 0
        dropLayer.addChild(drop)
        drop.run(.fadeIn(withDuration: 0.1))
    }

    private func updateDrops(delta: TimeInterval) {
        guard !activeDrops.isEmpty else { return }

        let step = CGFloat(delta) * GameConfig.dropFallSpeed

        let bounds = currentPlayfieldBounds
        let localEdgeMid = CGPoint(x: bounds.midX, y: bounds.minY)
        let localCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let edgePoint = playfieldNode.convert(localEdgeMid, to: self)
        let centerPoint = playfieldNode.convert(localCenter, to: self)
        let outwardDx = edgePoint.x - centerPoint.x
        let outwardDy = edgePoint.y - centerPoint.y
        let outwardLength = sqrt(outwardDx * outwardDx + outwardDy * outwardDy)

        let unitX: CGFloat = outwardLength > 0 ? outwardDx / outwardLength : 0
        let unitY: CGFloat = outwardLength > 0 ? outwardDy / outwardLength : 0

        for drop in activeDrops {
            drop.position.y -= step
            drop.zRotation = playfieldNode.zRotation

            if handleDropCollection(drop) {
                continue
            }

            let dropPoint = dropLayer.convert(drop.position, to: self)
            let offsetX = dropPoint.x - edgePoint.x
            let offsetY = dropPoint.y - edgePoint.y
            let distanceBeyondEdge = offsetX * unitX + offsetY * unitY

            if distanceBeyondEdge > 24 {
                drop.removeAllActions()
                drop.removeFromParent()
            }
        }
    }

    private func updateGun(delta: TimeInterval) {
        guard gunEffectRemaining > 0 else { return }
        gunEffectRemaining = max(0, gunEffectRemaining - delta)
        laserCooldown = max(0, laserCooldown - delta)

        if laserCooldown == 0 {
            fireLaser()
            laserCooldown = GameConfig.gunFireInterval
        }

        if gunEffectRemaining == 0 {
            laserCooldown = 0
        }
    }

    private func activateGunEffect() {
        gunEffectRemaining = GameConfig.gunEffectDuration
        laserCooldown = 0
    }

    private func fireLaser() {
        let direction = CGVector(dx: 0, dy: 1)
        let origin = paddle.position
        let maxDimension = max(currentPlayfieldBounds.width, currentPlayfieldBounds.height) + 120
        let endPoint = CGPoint(
            x: origin.x + direction.dx * maxDimension,
            y: origin.y + direction.dy * maxDimension
        )

        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: endPoint)

        let beam = SKShapeNode(path: path)
        beam.strokeColor = SKColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.95)
        beam.glowWidth = GameConfig.gunBeamGlowWidth
        beam.lineWidth = GameConfig.gunBeamLineWidth
        beam.alpha = 0.0
        beam.zPosition = 9

        let halo = SKShapeNode(path: path)
        halo.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.8, alpha: 0.8)
        halo.glowWidth = GameConfig.gunBeamGlowWidth * 1.2
        halo.lineWidth = GameConfig.gunBeamLineWidth * 0.5
        halo.alpha = 0.0
        halo.zPosition = 8

        playfieldNode.addChild(halo)
        playfieldNode.addChild(beam)

        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.04)
        let fadeOut = SKAction.fadeOut(withDuration: GameConfig.gunBeamDuration)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeIn, fadeOut, remove])
        beam.run(sequence)
        halo.run(sequence)

        if let impact = firstBrickHitByLaser(from: origin, to: endPoint) {
            handleBrickHit(impact.brick, source: .laser)
            spawnLaserImpact(at: impact.point)
        }
    }

    private func firstBrickHitByLaser(from start: CGPoint, to end: CGPoint) -> (brick: BrickNode, point: CGPoint)? {
        var closest: (brick: BrickNode, distance: CGFloat, point: CGPoint)?

        for case let brick as BrickNode in brickLayer.children {
            let frame = brick.frame
            if let impactPoint = lineSegmentIntersection(with: frame, from: start, to: end) {
                let distance = start.distance(to: impactPoint)
                if closest == nil || distance < closest!.distance {
                    closest = (brick, distance, impactPoint)
                }
            }
        }

        return closest.map { ($0.brick, $0.point) }
    }

    private func spawnLaserImpact(at point: CGPoint) {
        let pulse = SKShapeNode(circleOfRadius: 10)
        pulse.position = point
        pulse.fillColor = SKColor(red: 0.9, green: 1.0, blue: 1.0, alpha: 0.5)
        pulse.strokeColor = SKColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.9)
        pulse.lineWidth = 1.5
        pulse.glowWidth = 6
        pulse.zPosition = 9
        playfieldNode.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: 2.4, duration: 0.2),
                .fadeOut(withDuration: 0.2)
            ]),
            .removeFromParent()
        ]))
    }

    private func lineSegmentIntersection(with rect: CGRect, from start: CGPoint, to end: CGPoint) -> CGPoint? {
        if rect.contains(start) { return start }

        let bottomLeft = CGPoint(x: rect.minX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.minY)
        let topLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let topRight = CGPoint(x: rect.maxX, y: rect.maxY)

        let edges: [(CGPoint, CGPoint)] = [
            (bottomLeft, bottomRight),
            (bottomRight, topRight),
            (topRight, topLeft),
            (topLeft, bottomLeft)
        ]

        var closestPoint: CGPoint?
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for (edgeStart, edgeEnd) in edges {
            if let intersection = segmentIntersection(p1: start, p2: end, p3: edgeStart, p4: edgeEnd) {
                let distance = start.distance(to: intersection)
                if distance < closestDistance {
                    closestDistance = distance
                    closestPoint = intersection
                }
            }
        }

        return closestPoint
    }

    private func segmentIntersection(p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint) -> CGPoint? {
        let r = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let s = CGPoint(x: p4.x - p3.x, y: p4.y - p3.y)
        let denominator = cross(r, s)
        if abs(denominator) < 0.0001 { return nil }

        let qp = CGPoint(x: p3.x - p1.x, y: p3.y - p1.y)
        let t = cross(qp, s) / denominator
        let u = cross(qp, r) / denominator

        if t < 0 || t > 1 || u < 0 || u > 1 { return nil }

        return CGPoint(x: p1.x + r.x * t, y: p1.y + r.y * t)
    }

    private func cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return a.x * b.y - a.y * b.x
    }

    private func handleDropCollection(_ drop: DropNode) -> Bool {
        let dropPoint = dropLayer.convert(drop.position, to: playfieldNode)
        let catchZone = paddle.frame.insetBy(dx: -14, dy: -6)

        if catchZone.contains(dropPoint) {
            drop.removeAllActions()
            drop.removeFromParent()
            applyDropEffect(drop.descriptor)
            return true
        }

        return false
    }

    private func applyDropEffect(_ descriptor: DropDescriptor) {
        switch descriptor.kind {
        case .extraLife:
            if lives < GameConfig.maxLives {
                lives += 1
            }
            hud.update(score: score, multiplier: multiplier, lives: lives)
            hud.showMessage("Extra Life!")

        case .multiBall(let count):
            spawnAdditionalBalls(count: max(1, count))
            hud.showMessage("Multiball!")

        case .paddleGrow:
            applyPaddleScale(multiplier: GameConfig.paddleGrowMultiplier, duration: GameConfig.paddleEffectDuration)
            hud.showMessage("Paddle +")

        case .paddleShrink:
            applyPaddleScale(multiplier: GameConfig.paddleShrinkMultiplier, duration: GameConfig.paddleEffectDuration)
            hud.showMessage("Paddle -")

        case .rotation(let angle):
            startRotation(by: angle, label: rotationLabel(for: angle))

        case .gun:
            activateGunEffect()
            hud.showMessage("Laser!")

        case .points(let amount):
            let delta = amount * multiplier
            score += delta
            hud.update(score: score, multiplier: multiplier, lives: lives)
            hud.showMessage("+\(amount * multiplier)")
            hud.animateScoreBoost(delta: delta)
            gameDelegate?.gameScene(self, didUpdateScore: score)
        }
    }

    private func resetBall(launchAfter delay: TimeInterval = GameConfig.ballLaunchDelay, freezePhysics: Bool = false, reanchor: Bool = true) {
        guard let body = ball.physicsBody else { return }

        clearAdditionalBalls()
        if ball.parent == nil {
            playfieldNode.addChild(ball)
            ball.setTrailTarget(playfieldNode)
        }

        body.velocity = .zero
        body.isDynamic = false

        if reanchor {
            ball.position = anchoredBallPosition()
            clampBallsWithinPlayfield()
        }

        ball.isHidden = false

        if freezePhysics {
            physicsWorld.speed = 0
        }

        removeAction(forKey: ballLaunchActionKey)

        isBallRespawning = true
        rotationTimer = 0

        let launch = SKAction.run { [weak self] in
            guard let self, let physicsBody = self.ball.physicsBody else { return }
            if freezePhysics {
                self.physicsWorld.speed = 1
            }
            physicsBody.isDynamic = true
            let angle = CGFloat.random(in: (.pi / 4)...(.pi * 3 / 4))
            let speed = GameConfig.ballInitialSpeed * self.currentBallSpeedMultiplier
            physicsBody.velocity = CGVector(
                dx: cos(angle) * speed,
                dy: sin(angle) * speed
            ).rotated(by: self.orientationBaseAngle())
            self.isBallRespawning = false
            self.rotationTimer = 0
            self.restoreBallVelocityIfStalled()
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
        guard !isBallRespawning else { return }

        let options: [CGFloat] = [.pi / 2, -.pi / 2, .pi]
        let choice = options.randomElement() ?? .pi / 2
        startRotation(by: choice, label: rotationLabel(for: choice))
    }

    private func startRotation(by angle: CGFloat, label: String) {
        guard !isRotationInProgress else { return }
        guard isGameActive else { return }
        guard !isBallRespawning else { return }

        isRotationInProgress = true
        rotationTimer = 0

        storedBallVelocities = activeBalls.reduce(into: [:]) { result, node in
            if let velocity = node.physicsBody?.velocity {
                result[ObjectIdentifier(node)] = velocity
            }
        }

        hud.showMessage(label)
        let freeze = SKAction.run { [weak self] in self?.physicsWorld.speed = 0 }
        let wait = SKAction.wait(forDuration: GameConfig.rotationFreezeDuration)
        let rotate = SKAction.rotate(byAngle: angle, duration: GameConfig.rotationAnimationDuration)
        rotate.timingMode = .easeInEaseOut
        let resume = SKAction.run { [weak self] in self?.finishRotation(by: angle) }

        playfieldNode.run(.sequence([freeze, wait, rotate, resume]))
    }

    private func rotationLabel(for angle: CGFloat) -> String {
        if abs(abs(angle) - .pi) < 0.01 {
            return "180 Spin"
        } else if angle > 0 {
            return "Rotate +90"
        } else {
            return "Rotate -90"
        }
    }

    private func restoreBallVelocityIfStalled() {
        guard !isBallRespawning else { return }
        guard !isRotationInProgress else { return }
        guard physicsWorld.speed > 0 else { return }

        let bounds = currentPlayfieldBounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for ballNode in activeBalls {
            guard let body = ballNode.physicsBody else { continue }
            if body.velocity.magnitude < stalledVelocityThreshold {
                let toCenter = CGVector(dx: center.x - ballNode.position.x, dy: center.y - ballNode.position.y)
                let baseDirection: CGVector
                if toCenter.magnitude > 0.001 {
                    baseDirection = toCenter.normalized
                } else {
                    baseDirection = orientationInteriorDirection()
                }
                let baseAngle = atan2(baseDirection.dy, baseDirection.dx)
                let jitter = CGFloat.random(in: (-.pi / 6)...(.pi / 6))
                let angle = baseAngle + jitter
                let speed = GameConfig.ballInitialSpeed
                body.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            }
        }
    }

    private func dislodgeIfAxisAligned(_ ballNode: BallNode) {
        guard let body = ballNode.physicsBody else { return }
        let v = body.velocity
        let speed = v.magnitude
        guard speed > 0 else { return }

        let absDx = abs(v.dx) / speed
        let absDy = abs(v.dy) / speed
        let epsilon = GameConfig.ballAxisAlignmentEpsilon

        // If the ball is traveling nearly perfectly vertical or horizontal, add a slight angle jitter.
        if absDx < epsilon || absDy < epsilon {
            var angle = atan2(v.dy, v.dx)
            let jitter = CGFloat.random(in: (-.pi / 24)...(.pi / 24))
            angle += jitter
            let newSpeed = max(speed, GameConfig.ballInitialSpeed)
            body.velocity = CGVector(dx: cos(angle) * newSpeed, dy: sin(angle) * newSpeed)
        }
    }

    @discardableResult
    private func handleBallExit(_ ballNode: BallNode) -> Bool {
        ballNode.removeAllActions()
        ballNode.removeFromParent()

        if ballNode === ball {
            if let replacement = additionalBalls.first {
                additionalBalls.removeFirst()
                ball = replacement
                ball.setTrailTarget(playfieldNode)
                return false
            } else {
                return true
            }
        }

        if let index = additionalBalls.firstIndex(where: { $0 === ballNode }) {
            additionalBalls.remove(at: index)
        }

        return false
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
        hud.layout(in: hudBounds)
        dropLayer.removeAllChildren()
        clampBallsWithinPlayfield()

        for ballNode in activeBalls {
            let id = ObjectIdentifier(ballNode)
            let original = storedBallVelocities[id] ?? ballNode.physicsBody?.velocity ?? .zero
            ballNode.physicsBody?.velocity = original.rotated(by: angle)
        }
        storedBallVelocities.removeAll()

        restoreBallVelocityIfStalled()

        rotationInterval = max(7, rotationInterval * 0.93)
    }

    private func checkLifeLoss() {
        guard lives > 0 else { return }

        let balls = activeBalls
        // If somehow all balls have been removed while the game is active, treat it as a miss.
        guard !balls.isEmpty else {
            loseLife()
            return
        }

        let limit: CGFloat = 48
        let bounds = currentPlayfieldBounds
        let boundsWithMargin = bounds.insetBy(dx: -16, dy: -16)

        let localEdgeMid = CGPoint(x: bounds.midX, y: bounds.minY)
        let localCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        let edgePoint = playfieldNode.convert(localEdgeMid, to: self)
        let centerPoint = playfieldNode.convert(localCenter, to: self)

        let outwardDx = edgePoint.x - centerPoint.x
        let outwardDy = edgePoint.y - centerPoint.y
        let outwardLength = sqrt(outwardDx * outwardDx + outwardDy * outwardDy)

        guard outwardLength > 0 else { return }

        let unitX = outwardDx / outwardLength
        let unitY = outwardDy / outwardLength

        for ballNode in balls {
            guard let body = ballNode.physicsBody else { continue }

            let ballPoint = playfieldNode.convert(ballNode.position, to: self)
            let localBall = playfieldNode.convert(ballPoint, from: self)
            let orphaned = ballNode.parent == nil || ballNode.scene == nil

            if orphaned || !boundsWithMargin.contains(localBall) {
                if handleBallExit(ballNode) {
                    loseLife()
                    return
                } else {
                    continue
                }
            }

            let offsetX = ballPoint.x - edgePoint.x
            let offsetY = ballPoint.y - edgePoint.y

            let distanceBeyondEdge = offsetX * unitX + offsetY * unitY

            if distanceBeyondEdge > limit {
                if handleBallExit(ballNode) {
                    loseLife()
                    return
                } else {
                    continue
                }
            }

            body.velocity = body.velocity.limited(
                minSpeed: GameConfig.ballInitialSpeed * 0.75,
                maxSpeed: GameConfig.ballMaximumSpeed
            )
        }
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
        Haptic.play(.lifeLost)

        if lives <= 0 {
            hud.showMessage("Game Over")
            gameOver()
        } else {
            isGameActive = false
            physicsWorld.speed = 0
            hud.showMessage(
                "Ball Lost",
                fontSize: GameConfig.ballLostMessageFontSize,
                duration: GameConfig.ballRespawnDelayAfterMiss
            )
            clearAdditionalBalls()
            dropLayer.removeAllChildren()
            paddleScaleEffectRemaining = 0
            applyPaddleScale(multiplier: 1)
            gunEffectRemaining = 0
            laserCooldown = 0
            isBallRespawning = true
            let wait = SKAction.wait(forDuration: GameConfig.ballRespawnDelayAfterMiss)
            let prep = SKAction.run { [weak self] in
                self?.anchorBallForServe()
            }
            let countdown = SKAction.run { [weak self] in
                self?.startCountdown()
            }
            run(.sequence([wait, prep, countdown]), withKey: countdownActionKey)
        }
    }

    private func gameOver() {
        isGameActive = false
        isCountdownActive = false
        physicsWorld.speed = 0
        rotationTimer = 0
        isRotationInProgress = false
        isBallRespawning = false
        playfieldNode.removeAllActions()
        removeAction(forKey: countdownActionKey)
        removeAction(forKey: ballLaunchActionKey)
        clearAdditionalBalls()
        for node in activeBalls {
            node.physicsBody?.velocity = .zero
            node.removeAllActions()
        }
        transitionLayer.removeAllChildren()
        transitionLayer.removeAllActions()
        transitionLayer.isHidden = true
        isLevelTransitionActive = false
        paddle.alpha = 1
        hud.alpha = 1
        ball.isHidden = false
        paddleScaleEffectRemaining = 0
        applyPaddleScale(multiplier: 1)
        gunEffectRemaining = 0
        laserCooldown = 0
        dropLayer.removeAllChildren()
        setStartScreenPresentation(active: true)
        gameDelegate?.gameSceneDidEnd(self, finalScore: score)
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard let aNode = contact.bodyA.node, let bNode = contact.bodyB.node else { return }

        let isBallA = aNode.name == "ball"
        let isBallB = bNode.name == "ball"

        if let brick = (aNode as? BrickNode) ?? (bNode as? BrickNode), isBallA || isBallB {
            let ballNode = (isBallA ? aNode : bNode) as? BallNode
            let impactDirection: CGVector?
            if let velocity = ballNode?.physicsBody?.velocity, velocity.magnitude > 0.001 {
                impactDirection = velocity
            } else if let ballNode {
                let delta = CGVector(dx: brick.position.x - ballNode.position.x,
                                     dy: brick.position.y - ballNode.position.y)
                impactDirection = delta
            } else {
                impactDirection = nil
            }
            handleBrickHit(brick, source: .ball(impactDirection))
        }

        if (aNode.name == "paddle" && isBallB) || (bNode.name == "paddle" && isBallA) {
            let ballNode = (isBallA ? aNode : bNode) as? BallNode
            if let ballNode {
                handlePaddleHit(for: ballNode)
            }
        }
    }

    private enum HitSource {
        case ball(CGVector?)
        case laser
    }

    private func handleBrickHit(_ brick: BrickNode, source: HitSource = .ball(nil)) {
        if brick.applyHit() {
            addScore(for: brick)
            runExplosion(at: brick.position, explosive: brick.isExplosive)
            let dropDescriptor = brick.descriptor.drop
            let dropPosition: CGPoint? = dropDescriptor.map { _ in
                brickLayer.convert(brick.position, to: dropLayer)
            }
            brick.removeFromParent()

            if let descriptor = dropDescriptor, let position = dropPosition {
                spawnDrop(for: descriptor, at: position)
            }

            if brick.isExplosive {
                triggerExplosionChain(from: brick.position, radius: 60)
            }

            if brickLayer.children.compactMap({ $0 as? BrickNode }).allSatisfy({ $0.isUnbreakable }) {
                levelCleared()
            }
        } else {
            if brick.isUnbreakable {
                return
            }
            streak += 1
            if case .ball(let direction) = source,
               brick.descriptor.kind.hitPoints > 1,
               let dir = direction?.normalized {
                let offset = CGVector(dx: dir.dx * 3, dy: dir.dy * 3)
                let nudge = SKAction.moveBy(x: offset.dx, y: offset.dy, duration: 0.08)
                nudge.timingMode = .easeOut
                let returnMove = SKAction.moveBy(x: -offset.dx, y: -offset.dy, duration: 0.12)
                returnMove.timingMode = .easeIn
                brick.run(.sequence([nudge, returnMove]), withKey: "brickNudge")
            }
        }
    }

    private func handlePaddleHit(for ballNode: BallNode) {
        streak += 1
        let oldMultiplier = multiplier
        if streak % 6 == 0 {
            multiplier = min(10, multiplier + 1)
        }
        hud.update(score: score, multiplier: multiplier, lives: lives)
        if multiplier != oldMultiplier {
            hud.animateMultiplier(multiplier)
        }

        guard let body = ballNode.physicsBody else { return }
        let ballScenePosition = playfieldNode.convert(ballNode.position, to: self)
        let paddleScenePosition = playfieldNode.convert(paddle.position, to: self)
        let contactVector = CGVector(
            dx: ballScenePosition.x - paddleScenePosition.x,
            dy: ballScenePosition.y - paddleScenePosition.y
        )

        // If the ball scraped under/behind the paddle, shove it back into the playfield and fire it inward.
        let interiorDirection = orientationInteriorDirection()
        let interiorDot = contactVector.dx * interiorDirection.dx + contactVector.dy * interiorDirection.dy
        if interiorDot < 0 {
            // If the ball contacted the underside/outside, keep it heading outward to avoid stickiness.
            let speed = max(body.velocity.magnitude, GameConfig.ballInitialSpeed)
            let outwardDir = contactVector.normalized
            body.velocity = CGVector(dx: outwardDir.dx * speed, dy: outwardDir.dy * speed)
            return
        }

        let baseAngle = orientationBaseAngle()
        let canonicalImpact = contactVector.rotated(by: -baseAngle)
        let axisSign: CGFloat = -1
        let maxOffset = GameConfig.paddleSize.width / 2
        let normalized = (canonicalImpact.dx * axisSign / maxOffset).clamped(to: CGFloat(-1)...CGFloat(1))
        let speed = max(body.velocity.magnitude, GameConfig.ballInitialSpeed)
        let angleOffset = normalized * (.pi / 4)
        let newAngle = baseAngle + (.pi / 2) + angleOffset
        body.velocity = CGVector(dx: cos(newAngle) * speed, dy: sin(newAngle) * speed)

        // Light shake on paddle hit (rate-limited to avoid buzz).
        if paddleHitShakeCooldown == 0 {
            let shake = SKAction.sequence([
                .moveBy(x: 0, y: 2, duration: 0.04),
                .moveBy(x: 0, y: -2, duration: 0.04)
            ])
            shake.timingMode = .easeInEaseOut
            paddle.run(shake, withKey: "paddleShake")
            paddleHitShakeCooldown = 0.12
        }

        if paddleHapticCooldown == 0 {
            Haptic.play(.paddleHit)
            paddleHapticCooldown = 0.18
        }
    }

    private func levelCleared() {
        guard !isLevelTransitionActive else { return }
        isLevelTransitionActive = true

        rotationInterval = max(6, rotationInterval * 0.9)
        beginLevelTransition(
            completedLevel: currentLevelNumber,
            nextLevel: currentLevelNumber + 1
        )
    }

    private func addScore(for brick: BrickNode) {
        let bonus = brick.isExplosive ? GameConfig.scorePerChainBonus : 0
        let delta = (brick.scoreValue + bonus) * multiplier
        score += delta
        hud.update(score: score, multiplier: multiplier, lives: lives)
        hud.animateScoreBoost(delta: delta)
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
            let dropDescriptor = target.descriptor.drop
            let dropPosition = dropDescriptor.map { _ in
                brickLayer.convert(target.position, to: dropLayer)
            }
            target.removeFromParent()

            if let descriptor = dropDescriptor, let position = dropPosition {
                spawnDrop(for: descriptor, at: position)
            }
        }

        if brickLayer.children.compactMap({ $0 as? BrickNode }).allSatisfy({ $0.isUnbreakable }) {
            levelCleared()
        }
    }

    private func beginLevelTransition(completedLevel: Int, nextLevel: Int) {
        rotationTimer = 0
        isBallRespawning = false
        physicsWorld.speed = 0
        isGameActive = false
        isCountdownActive = false

        removeAction(forKey: ballLaunchActionKey)
        removeAction(forKey: countdownActionKey)
        playfieldNode.removeAllActions()

        for ballNode in activeBalls {
            ballNode.physicsBody?.velocity = .zero
            ballNode.removeAllActions()
            ballNode.isHidden = true
        }
        clearAdditionalBalls()
        dropLayer.removeAllChildren()
        storedBallVelocities.removeAll()

        paddle.run(.fadeAlpha(to: 0.5, duration: 0.18))
        hud.run(.fadeAlpha(to: 0.5, duration: 0.18))

        transitionLayer.removeAllChildren()
        transitionLayer.removeAllActions()
        transitionLayer.isHidden = false

        let flash = SKSpriteNode(color: .white, size: size)
        flash.alpha = 0
        flash.zPosition = 0
        transitionLayer.addChild(flash)

        let completeLabel = makeTransitionLabel(text: "Level Complete")
        completeLabel.setScale(0.82)
        transitionLayer.addChild(completeLabel)

        let nextLabel = makeTransitionLabel(text: "Level \(nextLevel)")
        nextLabel.setScale(0.72)
        transitionLayer.addChild(nextLabel)

        let flashSequence = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: 0.12),
            SKAction.wait(forDuration: 0.32),
            SKAction.fadeOut(withDuration: 0.35),
            SKAction.removeFromParent()
        ])
        flash.run(flashSequence)

        let completeSequence = SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.18),
                SKAction.scale(to: 1.0, duration: 0.22)
            ]),
            SKAction.wait(forDuration: 0.45),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.18),
                SKAction.scale(to: 0.94, duration: 0.18)
            ]),
            SKAction.removeFromParent()
        ])
        completeLabel.run(completeSequence)

        let nextSequence = SKAction.sequence([
            SKAction.wait(forDuration: 0.62),
            SKAction.run { [weak self, weak nextLabel] in
                guard let self, let nextLabel else { return }
                self.prepareNextLevelPresentation(level: nextLevel)
                nextLabel.alpha = 0
                nextLabel.setScale(0.78)
            },
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.22),
                SKAction.scale(to: 1.04, duration: 0.22)
            ]),
            SKAction.wait(forDuration: 0.55),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 0.96, duration: 0.2)
            ]),
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                self?.completeLevelTransition()
            }
        ])
        nextLabel.run(nextSequence)
    }

    private func prepareNextLevelPresentation(level: Int) {
        loadNextLevel()
        ball.position = paddle.position
        ball.isHidden = true
        hud.update(score: score, multiplier: multiplier, lives: lives)
    }

    private func completeLevelTransition() {
        transitionLayer.run(.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in
                self?.transitionLayer.removeAllChildren()
                self?.transitionLayer.isHidden = true
            }
        ]))

        paddle.run(.fadeAlpha(to: 1, duration: 0.2))
        hud.run(.fadeAlpha(to: 1, duration: 0.2))

        rotationTimer = 0
        physicsWorld.speed = 0
        isGameActive = false
        isLevelTransitionActive = false
        currentBallSpeedMultiplier *= 1.12
        anchorBallForServe()
        startCountdown()
    }

    private func makeTransitionLabel(text: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = text.uppercased()
        label.fontSize = 26
        label.fontColor = SKColor.white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.alpha = 0
        label.zPosition = 1
        return label
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

    private func clampBallsWithinPlayfield() {
        let bounds = currentPlayfieldBounds.insetBy(dx: GameConfig.ballRadius, dy: GameConfig.ballRadius)
        guard bounds.width > 0, bounds.height > 0 else { return }
        for ballNode in activeBalls {
            let clampedX = ballNode.position.x.clamped(to: bounds.minX...bounds.maxX)
            let clampedY = ballNode.position.y.clamped(to: bounds.minY...bounds.maxY)
            ballNode.position = CGPoint(x: clampedX, y: clampedY)
        }
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
        additionalBalls.forEach { $0.isHidden = hidden }
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

    private func startCountdown() {
        removeAction(forKey: countdownActionKey)
        rotationTimer = 0
        lastUpdateTime = 0
        physicsWorld.speed = 0
        isCountdownActive = true
        isGameActive = true
        isBallRespawning = true

        let steps: [(String, TimeInterval, CGFloat)] = [
            ("Get READY", 0.9, 19),
            ("3", 0.65, 30),
            ("2", 0.65, 30),
            ("1", 0.65, 30)
        ]

        var actions: [SKAction] = []
        for (text, duration, size) in steps {
            actions.append(.run { [weak self] in
                guard let self else { return }
                self.animateCountdown(text: text, fontSize: size, duration: duration)
            })
            actions.append(.wait(forDuration: duration))
        }

        actions.append(.run { [weak self] in
            self?.animateCountdown(text: "Go!", fontSize: 24, duration: 0.55)
        })
        actions.append(.wait(forDuration: 0.45))
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.isCountdownActive = false
            self.rotationTimer = 0
            self.lastUpdateTime = 0
            self.physicsWorld.speed = 1
            self.isGameActive = true
            self.isBallRespawning = false
            self.resetBall(launchAfter: GameConfig.ballLaunchDelay, reanchor: false)
        })

        run(.sequence(actions), withKey: countdownActionKey)
    }

    private func animateCountdown(text: String, fontSize: CGFloat, duration: TimeInterval) {
        hud.showCountdown(text, fontSize: fontSize, duration: duration)
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

    var normalized: CGVector {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return CGVector(dx: dx / mag, dy: dy / mag)
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
