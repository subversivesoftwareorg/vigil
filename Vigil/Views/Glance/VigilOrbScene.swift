import SpriteKit
import AppKit

// MARK: - Data Model

struct OrbData {
    let id: String
    let label: String
    let risk: RiskLevel
    let activity: Double // 0.0–1.0
    let satellites: [SatelliteData]

    enum RiskLevel: Int, Comparable {
        case healthy = 0
        case info = 1
        case concern = 2
        case warning = 3

        static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: NSColor {
            switch self {
            case .healthy: .systemGreen
            case .info: .systemBlue
            case .concern: .systemOrange
            case .warning: .systemRed
            }
        }

        var glowColor: NSColor {
            switch self {
            case .healthy: NSColor.systemGreen.withAlphaComponent(0.3)
            case .info: NSColor.systemBlue.withAlphaComponent(0.3)
            case .concern: NSColor.systemOrange.withAlphaComponent(0.4)
            case .warning: NSColor.systemRed.withAlphaComponent(0.5)
            }
        }
    }
}

struct SatelliteData {
    let id: String
    let label: String
    let hasRisk: Bool
}

// MARK: - Scene

final class VigilOrbScene: SKScene {

    var onOrbSelected: ((String) -> Void)?

    private var orbs: [OrbData] = []
    private var orbNodes: [String: SKNode] = [:]
    private var connectionNodes: [String: SKShapeNode] = [:]
    private var radarNode: SKNode?
    private var selectedOrbID: String?
    private let centerCategory: UInt32 = 0x1
    private let orbCategory: UInt32 = 0x2
    private let satelliteCategory: UInt32 = 0x4

    /// Golden angle keeps incrementally added orbs well-distributed even
    /// though the final count is unknown while a scan is in flight.
    private static let goldenAngle: CGFloat = 2.399963

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero

        // Central anchor (invisible)
        let center = SKShapeNode(circleOfRadius: 2)
        center.fillColor = .clear
        center.strokeColor = .clear
        center.position = CGPoint(x: size.width / 2, y: size.height / 2)
        center.physicsBody = SKPhysicsBody(circleOfRadius: 2)
        center.physicsBody?.isDynamic = false
        center.physicsBody?.categoryBitMask = centerCategory
        center.name = "center"
        addChild(center)

        // Gentle radial gravity toward center
        let gravity = SKFieldNode.radialGravityField()
        gravity.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gravity.strength = 0.3
        gravity.falloff = 0.5
        gravity.categoryBitMask = orbCategory
        addChild(gravity)

        // If orbs were provided before presentation, spawn them now
        if !orbs.isEmpty {
            let data = orbs
            orbs = []
            setOrbs(data)
        }

        view.window?.acceptsMouseMovedEvents = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        childNode(withName: "center")?.position = center
        for child in children where child is SKFieldNode {
            child.position = center
        }
        radarNode?.position = center
    }

    // MARK: - Public API

    /// Replace all orbs at once (warm-cache load). Spawns with a small
    /// stagger so arrival still reads as intentional.
    func setOrbs(_ data: [OrbData]) {
        clearAllOrbs()
        orbs = data
        for (index, orbData) in data.enumerated() {
            let angle = data.count > 1
                ? (CGFloat(index) / CGFloat(data.count)) * .pi * 2
                : 0
            spawnOrb(orbData, angle: angle, delay: Double(index) * 0.08)
        }
    }

    /// Add a single orb while a scan is in flight.
    func addOrb(_ data: OrbData) {
        let index = orbs.count
        orbs.append(data)
        spawnOrb(data, angle: CGFloat(index) * Self.goldenAngle, delay: 0)
    }

    /// Recolor an orb in place once final risk levels are known.
    func updateRisk(id: String, risk: OrbData.RiskLevel) {
        guard let index = orbs.firstIndex(where: { $0.id == id }) else { return }
        let old = orbs[index]
        orbs[index] = OrbData(id: old.id, label: old.label, risk: risk,
                              activity: old.activity, satellites: old.satellites)

        guard let container = orbNodes[id] else { return }
        if let glow = container.childNode(withName: "glow") as? SKShapeNode {
            glow.fillColor = risk.glowColor
        }
        if let shape = container.childNode(withName: "orbShape") as? SKShapeNode {
            shape.fillColor = risk.color.withAlphaComponent(0.85)
            shape.strokeColor = risk.color
        }
        container.physicsBody?.charge = CGFloat(risk.rawValue + 1) * 0.5
    }

    // MARK: - Radar Scan Effect

    func beginScanEffect() {
        guard radarNode == nil else { return }
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2)
        container.zPosition = -2

        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 30)
            ring.strokeColor = NSColor.systemTeal.withAlphaComponent(0.5)
            ring.lineWidth = 1.5
            ring.fillColor = .clear
            let expand = SKAction.group([
                .scale(to: 9.0, duration: 2.4),
                .fadeOut(withDuration: 2.4),
            ])
            expand.timingMode = .easeOut
            let reset = SKAction.group([
                .scale(to: 1.0, duration: 0),
                .fadeIn(withDuration: 0),
            ])
            ring.run(.sequence([
                .wait(forDuration: Double(i) * 0.8),
                .repeatForever(.sequence([expand, reset])),
            ]))
            container.addChild(ring)
        }

        addChild(container)
        radarNode = container
    }

    func endScanEffect() {
        guard let radar = radarNode else { return }
        radarNode = nil
        radar.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    // MARK: - Spawning

    private func clearAllOrbs() {
        for (_, node) in orbNodes { node.removeFromParent() }
        orbNodes.removeAll()
        for (_, node) in connectionNodes { node.removeFromParent() }
        connectionNodes.removeAll()
        orbs.removeAll()
    }

    private func spawnOrb(_ data: OrbData, angle: CGFloat, delay: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height / 2
        let baseRadius = min(size.width, size.height) * 0.3

        let orb = createOrbNode(data: data)
        let riskOffset = CGFloat(3 - data.risk.rawValue) * 30 // riskier = closer
        let radius = baseRadius + riskOffset + CGFloat.random(in: -20...20)
        orb.position = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)

        popIn(orb, delay: delay)
        addChild(orb)
        orbNodes[data.id] = orb

        for (satIndex, satellite) in data.satellites.enumerated() {
            let satNode = createSatelliteNode(satellite: satellite, parentColor: data.risk.color)
            let satAngle = (CGFloat(satIndex) / max(CGFloat(data.satellites.count), 1)) * .pi * 2
            let satRadius: CGFloat = 40 + CGFloat(satIndex) * 8
            satNode.position = CGPoint(
                x: orb.position.x + cos(satAngle) * satRadius,
                y: orb.position.y + sin(satAngle) * satRadius
            )
            popIn(satNode, delay: delay + 0.1 + Double(satIndex) * 0.05)
            addChild(satNode)
            orbNodes[satellite.id] = satNode

            let joint = SKPhysicsJointSpring.joint(
                withBodyA: orb.physicsBody!,
                bodyB: satNode.physicsBody!,
                anchorA: orb.position,
                anchorB: satNode.position
            )
            joint.frequency = 0.8
            joint.damping = 0.3
            physicsWorld.add(joint)
        }
    }

    /// Spring pop-in: scale from nothing with a slight overshoot.
    private func popIn(_ node: SKNode, delay: TimeInterval) {
        node.setScale(0.01)
        node.alpha = 0
        let overshoot = SKAction.scale(to: 1.12, duration: 0.22)
        overshoot.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.14)
        settle.timingMode = .easeIn
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([.fadeIn(withDuration: 0.2), .sequence([overshoot, settle])]),
        ]))
    }

    private func createOrbNode(data: OrbData) -> SKNode {
        let container = SKNode()
        container.name = data.id

        // Glow layer
        let glowRadius = 20 + CGFloat(data.activity) * 15
        let glow = SKShapeNode(circleOfRadius: glowRadius + 12)
        glow.fillColor = data.risk.glowColor
        glow.strokeColor = .clear
        glow.alpha = 0.6
        glow.name = "glow"

        let pulseUp = SKAction.scale(to: 1.15, duration: 1.5 + Double.random(in: 0...0.5))
        let pulseDown = SKAction.scale(to: 0.9, duration: 1.5 + Double.random(in: 0...0.5))
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        glow.run(.repeatForever(.sequence([pulseUp, pulseDown])))

        container.addChild(glow)

        // Main orb
        let orbShape = SKShapeNode(circleOfRadius: glowRadius)
        orbShape.fillColor = data.risk.color.withAlphaComponent(0.85)
        orbShape.strokeColor = data.risk.color
        orbShape.lineWidth = 1.5
        orbShape.name = "orbShape"
        container.addChild(orbShape)

        // Label
        let label = SKLabelNode(text: data.label)
        label.fontName = ".AppleSystemUIFont"
        label.fontSize = 11
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        // Physics
        let body = SKPhysicsBody(circleOfRadius: glowRadius + 4)
        body.isDynamic = true
        body.mass = 1.0 + CGFloat(data.activity) * 2.0
        body.linearDamping = 2.0
        body.angularDamping = 1.0
        body.restitution = 0.2
        body.friction = 0.5
        body.categoryBitMask = orbCategory
        body.collisionBitMask = orbCategory | satelliteCategory
        body.fieldBitMask = orbCategory
        body.charge = CGFloat(data.risk.rawValue + 1) * 0.5
        container.physicsBody = body

        return container
    }

    private func createSatelliteNode(satellite: SatelliteData, parentColor: NSColor) -> SKNode {
        let container = SKNode()
        container.name = satellite.id

        let radius: CGFloat = 8
        let color = satellite.hasRisk ? NSColor.systemOrange : parentColor.withAlphaComponent(0.5)

        let glow = SKShapeNode(circleOfRadius: radius + 4)
        glow.fillColor = color.withAlphaComponent(0.2)
        glow.strokeColor = .clear
        container.addChild(glow)

        let dot = SKShapeNode(circleOfRadius: radius)
        dot.fillColor = color.withAlphaComponent(0.7)
        dot.strokeColor = color
        dot.lineWidth = 1
        container.addChild(dot)

        let label = SKLabelNode(text: satellite.label)
        label.fontName = ".AppleSystemUIFont"
        label.fontSize = 8
        label.fontColor = .white.withAlphaComponent(0.8)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        let body = SKPhysicsBody(circleOfRadius: radius + 2)
        body.isDynamic = true
        body.mass = 0.3
        body.linearDamping = 3.0
        body.restitution = 0.1
        body.categoryBitMask = satelliteCategory
        body.collisionBitMask = orbCategory | satelliteCategory
        body.fieldBitMask = 0
        container.physicsBody = body

        return container
    }

    // MARK: - Connection Lines

    override func update(_ currentTime: TimeInterval) {
        for data in orbs {
            guard let orbNode = orbNodes[data.id] else { continue }
            for satellite in data.satellites {
                guard let satNode = orbNodes[satellite.id] else { continue }
                updateConnection(
                    key: "\(data.id)|\(satellite.id)",
                    from: orbNode.position, to: satNode.position,
                    color: data.risk.color, hasRisk: satellite.hasRisk
                )
            }
        }
    }

    private func updateConnection(key: String, from start: CGPoint, to end: CGPoint,
                                  color: NSColor, hasRisk: Bool) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        if let existing = connectionNodes[key] {
            existing.path = path
        } else {
            let line = SKShapeNode(path: path)
            line.strokeColor = (hasRisk ? NSColor.systemOrange : color).withAlphaComponent(0.25)
            line.lineWidth = hasRisk ? 1.5 : 1.0
            line.zPosition = -1
            addChild(line)
            connectionNodes[key] = line
        }
    }

    // MARK: - Mouse Interaction

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let tappedNode = atPoint(location)

        var target = tappedNode
        while target.name == nil || target.name == "glow" || target.name == "orbShape" {
            guard let parent = target.parent, parent != self else { return }
            target = parent
        }

        guard let id = target.name, id != "center" else {
            deselectAll()
            return
        }

        selectedOrbID = id
        highlightOrb(id: id)
        onOrbSelected?(id)
    }

    private func highlightOrb(id: String) {
        for (orbID, node) in orbNodes {
            let alpha: CGFloat = orbID == id ? 1.0 : 0.4
            node.run(.fadeAlpha(to: alpha, duration: 0.3))
        }
    }

    private func deselectAll() {
        selectedOrbID = nil
        for (_, node) in orbNodes {
            node.run(.fadeAlpha(to: 1.0, duration: 0.3))
        }
        onOrbSelected?("")
    }
}
