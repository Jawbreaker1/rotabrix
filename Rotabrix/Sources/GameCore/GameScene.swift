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

    weak var gameDelegate: GameSceneDelegate?

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
        loadNextLevel()
        resetBall()
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
        levelIndex = layout.levelNumber + 1

        let bounds = currentPlayfieldBounds

        for descriptor in layout.bricks {
            let brick = BrickNode(descriptor: descriptor)
            brick.position = positionForBrick(descriptor: descriptor, layout: layout, in: bounds)
            brickLayer.addChild(brick)
        }
    }

    private func resetBall() {
        guard let body = ball.physicsBody else { return }
        body.velocity = .zero

        let offsetDistance = GameConfig.paddleSize.height + GameConfig.ballRadius * 2
        let interiorDirection = orientationInteriorDirection()
        let offset = CGVector(
            dx: interiorDirection.dx * offsetDistance,
            dy: interiorDirection.dy * offsetDistance
        )

        ball.position = CGPoint(
            x: paddle.position.x + offset.dx,
            y: paddle.position.y + offset.dy
        )

        clampBallWithinPlayfield()

        run(.wait(forDuration: 0.45)) { [weak self] in
            guard let self else { return }
            let angle = CGFloat.random(in: (.pi / 4)...(.pi * 3 / 4))
            body.velocity = CGVector(
                dx: cos(angle) * GameConfig.ballInitialSpeed,
                dy: sin(angle) * GameConfig.ballInitialSpeed
            ).rotated(by: self.orientationBaseAngle())
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
        let position = ball.position
        let limit: CGFloat = 48

        let bounds = currentPlayfieldBounds

        switch orientation {
        case .bottom:
            if position.y < bounds.minY - limit { loseLife() }
        case .top:
            if position.y > bounds.maxY + limit { loseLife() }
        case .right:
            if position.x > bounds.maxX + limit { loseLife() }
        case .left:
            if position.x < bounds.minX - limit { loseLife() }
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

        let layers: [(parallax: CGFloat, speed: CGFloat, alpha: CGFloat, color: SKColor)] = [
            (0.25, 6, 0.4, SKColor(red: 0.30, green: 0.80, blue: 1.0, alpha: 1)),
            (0.55, 10, 0.55, SKColor(red: 0.74, green: 0.35, blue: 1.0, alpha: 1)),
            (1.0, 16, 0.7, SKColor(red: 1.0, green: 0.64, blue: 0.2, alpha: 1))
        ]

        for (parallax, speed, alpha, color) in layers {
            let layer = makeStarLayer(parallax: parallax, speed: speed, alpha: alpha, color: color, rect: rect)
            parallaxNode.addChild(layer)
            starLayers.append(layer)
        }
    }

    private func makeStarLayer(parallax: CGFloat, speed: CGFloat, alpha: CGFloat, color: SKColor, rect: CGRect) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.starTexture
        emitter.particleBirthRate = 12 * parallax * 2
        emitter.particleLifetime = 8 / max(parallax, 0.1)
        emitter.particleAlpha = alpha
        emitter.particleAlphaRange = 0.25
        emitter.particleAlphaSpeed = -0.02
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleSpeed = -speed
        emitter.particleSpeedRange = speed * 0.4
        emitter.emissionAngleRange = .pi
        emitter.particleScale = 0.15 + 0.1 * parallax
        emitter.particleScaleRange = 0.08
        emitter.particlePositionRange = CGVector(dx: rect.width, dy: rect.height)
        emitter.position = .zero
        emitter.advanceSimulationTime(1.5)
        emitter.particleBlendMode = .add

        let drift = SKAction.move(by: CGVector(dx: 0, dy: 10 * parallax), duration: 2)
        emitter.run(.repeatForever(.sequence([drift, drift.reversed()])))

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
        hud.showMessage(lives > 0 ? "Miss" : "Game Over")

        if lives <= 0 {
            gameOver()
        } else {
            resetBall()
        }
    }

    private func gameOver() {
        isGameActive = false
        physicsWorld.speed = 0
        rotationTimer = 0
        isRotationInProgress = false
        playfieldNode.removeAllActions()
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
        let impact = ball.position - paddle.position
        let maxOffset = GameConfig.paddleSize.width / 2

        let axisValue: CGFloat
        switch orientation {
        case .bottom:
            axisValue = impact.x
        case .top:
            axisValue = -impact.x
        case .right:
            axisValue = -impact.y
        case .left:
            axisValue = impact.y
        }

        let normalized = max(-1, min(1, axisValue / maxOffset))
        let speed = max(body.velocity.magnitude, GameConfig.ballInitialSpeed)
        let angleOffset = normalized * (.pi / 4)
        let baseAngle = orientationBaseAngle()
        let newAngle = baseAngle + (.pi / 2) + angleOffset
        body.velocity = CGVector(dx: cos(newAngle) * speed, dy: sin(newAngle) * speed)
    }

    private func levelCleared() {
        hud.showMessage("Level \(levelIndex - 1) Clear")
        rotationInterval = max(6, rotationInterval * 0.9)
        run(.wait(forDuration: 1)) { [weak self] in
            self?.loadNextLevel()
            self?.resetBall()
        }
    }

    private func addScore(for brick: BrickNode) {
        let bonus = brick.isExplosive ? GameConfig.scorePerChainBonus : 0
        score += (brick.scoreValue + bonus) * multiplier
        hud.update(score: score, multiplier: multiplier, lives: lives)
        gameDelegate?.gameScene(self, didUpdateScore: score)
    }

    private func runExplosion(at point: CGPoint, explosive: Bool) {
        let radius: CGFloat = explosive ? 48 : 24
        let pulse = SKShapeNode(circleOfRadius: radius)
        pulse.position = point
        pulse.strokeColor = SKColor(red: 0.35, green: 0.95, blue: 1.0, alpha: 1)
        pulse.lineWidth = 2
        pulse.alpha = 0.6
        pulse.zPosition = 15
        playfieldNode.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: explosive ? 2.2 : 1.4, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ]),
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
