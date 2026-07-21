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

    var orbData: [OrbData] = [] { didSet { rebuildOrbs() } }
    var onOrbSelected: ((String) -> Void)?

    private var orbNodes: [String: SKNode] = [:]
    private var selectedOrbID: String?
    private let centerCategory: UInt32 = 0x1
    private let orbCategory: UInt32 = 0x2
    private let satelliteCategory: UInt32 = 0x4

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

        rebuildOrbs()

        // Track mouse for hover effects
        view.window?.acceptsMouseMovedEvents = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Reposition center and gravity when window resizes
        if let center = childNode(withName: "center") {
            center.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        for child in children where child is SKFieldNode {
            child.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    // MARK: - Build Orbs

    private func rebuildOrbs() {
        // Remove old orbs
        for (_, node) in orbNodes { node.removeFromParent() }
        orbNodes.removeAll()

        guard !orbData.isEmpty else { return }

        let cx = size.width / 2
        let cy = size.height / 2
        let baseRadius = min(size.width, size.height) * 0.3

        for (index, data) in orbData.enumerated() {
            let orb = createOrbNode(data: data)

            // Place orbs in a circle around center, with some randomness
            let angle = (CGFloat(index) / CGFloat(orbData.count)) * .pi * 2
            let riskOffset = CGFloat(3 - data.risk.rawValue) * 30 // riskier = closer
            let radius = baseRadius + riskOffset + CGFloat.random(in: -20...20)
            orb.position = CGPoint(
                x: cx + cos(angle) * radius,
                y: cy + sin(angle) * radius
            )

            addChild(orb)
            orbNodes[data.id] = orb

            // Add satellites (MCP servers)
            for (satIndex, satellite) in data.satellites.enumerated() {
                let satNode = createSatelliteNode(satellite: satellite, parentColor: data.risk.color)
                let satAngle = (CGFloat(satIndex) / max(CGFloat(data.satellites.count), 1)) * .pi * 2
                let satRadius: CGFloat = 40 + CGFloat(satIndex) * 8
                satNode.position = CGPoint(
                    x: orb.position.x + cos(satAngle) * satRadius,
                    y: orb.position.y + sin(satAngle) * satRadius
                )
                addChild(satNode)
                orbNodes[satellite.id] = satNode

                // Spring joint tethering satellite to parent orb
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

        // Pulse animation on glow
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

        // Small glow
        let glow = SKShapeNode(circleOfRadius: radius + 4)
        glow.fillColor = color.withAlphaComponent(0.2)
        glow.strokeColor = .clear
        container.addChild(glow)

        // Satellite dot
        let dot = SKShapeNode(circleOfRadius: radius)
        dot.fillColor = color.withAlphaComponent(0.7)
        dot.strokeColor = color
        dot.lineWidth = 1
        container.addChild(dot)

        // Tiny label
        let label = SKLabelNode(text: satellite.label)
        label.fontName = ".AppleSystemUIFont"
        label.fontSize = 8
        label.fontColor = .white.withAlphaComponent(0.8)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        // Physics
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
        // Draw connection lines between orbs and their satellites
        removeChildren(in: children.filter { $0.name == "connection" })

        for data in orbData {
            guard let orbNode = orbNodes[data.id] else { continue }
            for satellite in data.satellites {
                guard let satNode = orbNodes[satellite.id] else { continue }
                drawConnection(from: orbNode.position, to: satNode.position,
                              color: data.risk.color, hasRisk: satellite.hasRisk)
            }
        }
    }

    private func drawConnection(from start: CGPoint, to end: CGPoint, color: NSColor, hasRisk: Bool) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let line = SKShapeNode(path: path)
        line.strokeColor = (hasRisk ? NSColor.systemOrange : color).withAlphaComponent(0.25)
        line.lineWidth = hasRisk ? 1.5 : 1.0
        line.name = "connection"
        line.zPosition = -1
        addChild(line)
    }

    // MARK: - Mouse Interaction

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let tappedNode = atPoint(location)

        // Walk up to find the named container node
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
        // Dim all orbs, brighten the selected one
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
