//
//  ReelScene.swift
//  RoyalSpin
//
//  The 3D reels. Each reel is a real cylinder in SceneKit — a ring of textured
//  quads rotating about the X axis — so the symbols genuinely foreshorten and
//  catch the light as they come over the top. Nothing here is a flat scrolling
//  list with a fake gradient.
//
//  Reel geometry, for anyone editing the angles:
//
//    · Panel k sits at angle aₖ = −k·Δ around the X axis, where Δ = 2π / panelCount,
//      at position (0, R·sin aₖ, R·cos aₖ). Panel 0 therefore starts dead centre
//      front at (0, 0, R).
//    · Rotating the parent by ψ maps a panel at angle a to angle a − ψ, so
//      *increasing ψ scrolls symbols downward* — the direction a real reel spins.
//    · Because a full turn is 2π, landing on ψ ≡ 0 (mod 2π) always puts panel 0
//      back at front centre. That's why we can assign textures once before the
//      spin starts and never touch them again mid-flight.
//

import SceneKit
import UIKit

// MARK: - Tuning

enum ReelTuning {
    /// Faces on each cylinder. Enough that you never see the back of the ring
    /// through the gap between symbols; few enough to stay cheap. 5 reels × 14 = 70 nodes.
    static let panelCount = 14

    /// Panels are exactly one unit square and sit exactly one unit apart, so five
    /// reels span exactly 5.0 units. The camera is then framed to that width, which
    /// is what makes the bank fill the cabinet window edge to edge.
    static let panelSize: CGFloat = 1.0
    static let reelSpacing: CGFloat = 1.0

    /// Vertical spacing between adjacent panels at the front of the cylinder is
    /// R·sin(Δ). For rows not to overlap that has to be at least `panelSize`, so
    /// R ≥ 1 / sin(2π/14) = 2.304. A little above the minimum leaves a hairline gap.
    static let radius: CGFloat = 2.35

    /// Angular size of one symbol cell.
    static var cellAngle: Double { 2 * .pi / Double(panelCount) }

    /// Aspect of the cabinet's reel window (702 × 569 in the artwork). The camera
    /// needs it to decide which axis is the binding constraint.
    static let windowAspect: Double = 702.0 / 569.0

    /// Rows of symbols the viewport shows: three full, plus a sliver above and below.
    static let visibleRows: Double = 3.25

    // Shape follows the spec in assets/symbols/README.md — accelerate, cruise,
    // staggered left-to-right stop, ease into the predetermined index, overshoot and
    // settle — but the durations are stretched well past the spec's minimums. At the
    // spec timings the whole spin was over in well under a second, which reads as a
    // glitch rather than a machine. A real reel takes its time.

    /// Peak spin rate, radians/sec. ~31 symbols/sec — fast enough to blur, slow
    /// enough that you can still tell what's going past.
    static let maxSpeed: Double = 14
    /// Accelerate.
    static let spinUpTime: Double = 0.34
    /// Base cruise before reel 1 begins to stop.
    static let baseCruiseTime: Double = 0.90
    /// Each successive reel keeps going this much longer — the classic
    /// left-to-right staggered stop.
    static let reelStagger: Double = 0.30
    /// Extra cruise for a reel flagged `anticipation`. This is the "please, please"
    /// pause when a bonus is still live.
    static let anticipationHold: Double = 1.30
    /// Decelerate into the predetermined stop.
    static let decelTime: Double = 0.62
    /// Overshoot past the target before settling back. Spec: 4–8% of one cell.
    static var bounceAngle: Double { cellAngle * 0.07 }
    /// Settle back.
    static let bounceTime: Double = 0.16
}

// MARK: - Per-reel spin state

private enum ReelPhase {
    case idle
    case spinningUp(start: TimeInterval)
    case cruising(until: TimeInterval)
    case decelerating(start: TimeInterval, from: Double, to: Double)
    case bouncing(start: TimeInterval, from: Double, to: Double)
}

private final class Reel {
    let node = SCNNode()
    var panels: [SCNNode] = []
    var phase: ReelPhase = .idle
    /// Current rotation ψ in radians.
    var angle: Double = 0
    var speed: Double = 0
    /// Set when this reel finishes, so the scene can fire the stop sound once.
    var justStopped = false
}

// MARK: - Scene

/// Owns the SceneKit scene and drives all five reels from the render loop.
final class ReelScene: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    private var reels: [Reel] = []
    private let strips: [[Symbol]]

    /// Fired on the main thread as each reel lands, with the reel index.
    var onReelStopped: ((Int) -> Void)?
    /// Fired once every reel has settled.
    var onSpinComplete: (() -> Void)?

    private var isSpinning = false
    private var pendingResult: SpinResult?
    private var lastFrameTime: TimeInterval = 0

    // Cache so we're not rebuilding a symbol texture every spin.
    private var materialCache: [Symbol: SCNMaterial] = [:]

    /// Which machine is on screen. Changing it tears down and rebuilds the reel
    /// bank, because the number of cylinders and the camera framing both depend on
    /// it — see `rebuild(for:)`.
    private(set) var mode: ReelMode

    init(mode: ReelMode = .three, strips: [[Symbol]] = ReelStrips.strips) {
        self.mode = mode
        self.strips = strips
        super.init()
        buildScene()
    }

    /// Swap machines. Safe to call at any time; a spin in flight is abandoned.
    func rebuild(for newMode: ReelMode) {
        guard newMode != mode else { return }
        mode = newMode
        isSpinning = false
        pendingResult = nil
        for reel in reels { reel.node.removeFromParentNode() }
        reels.removeAll()
        cameraNode?.removeFromParentNode()
        cameraNode = nil
        buildScene()
    }

    private var cameraNode: SCNNode?

    // MARK: Scene construction

    private func buildScene() {
        scene.background.contents = UIColor(red: 0.05, green: 0.02, blue: 0.09, alpha: 1)

        let camera = SCNCamera()
        // Fit by whichever axis actually binds.
        //
        // Five reels are wider than they are tall (5.0 / 3.25 = 1.54 against the
        // window's 1.23), so width is the constraint. Three reels are not
        // (3.0 / 3.25 = 0.92), and fitting them by width would scale each symbol
        // past the height of the glass and crop the top and bottom rows. Picking the
        // binding axis makes both machines fill the window correctly with no
        // per-mode fudge factors.
        let bank = Double(mode.reels) * Double(ReelTuning.reelSpacing)
        let visibleRows = ReelTuning.visibleRows
        camera.projectionDirection =
            bank / visibleRows >= ReelTuning.windowAspect ? .horizontal : .vertical
        camera.fieldOfView = 42
        camera.zNear = 0.1
        camera.zFar = 100
        // A touch of bloom so gold symbols glow when the win flash fires.
        camera.bloomIntensity = 0.45
        camera.bloomThreshold = 0.72
        camera.bloomBlurRadius = 12
        camera.wantsHDR = true

        let cameraNode = SCNNode()
        self.cameraNode = cameraNode
        cameraNode.camera = camera
        // Distance is derived, not eyeballed: to frame an extent E across a FOV θ at
        // the plane of the front faces, the camera sits at E / (2·tan(θ/2)) beyond
        // that plane — which is itself `radius` in front of the reel axis.
        let halfFOV = (camera.fieldOfView * .pi / 180) / 2
        let extent = camera.projectionDirection == .horizontal ? bank : visibleRows
        let distance = extent / (2 * tan(halfFOV)) + Double(ReelTuning.radius)
        cameraNode.position = SCNVector3(0, 0, CGFloat(distance))
        scene.rootNode.addChildNode(cameraNode)

        // No lights: every material is `.constant`, so lights would be ignored
        // anyway. Dropping them also drops the shadow pass, which was the most
        // expensive thing in the scene and contributed nothing.

        // Reels.
        let totalWidth = CGFloat(mode.reels - 1) * ReelTuning.reelSpacing
        for i in 0 ..< mode.reels {
            let reel = buildReel(index: i)
            reel.node.position = SCNVector3(
                CGFloat(i) * ReelTuning.reelSpacing - totalWidth / 2, 0, 0
            )
            scene.rootNode.addChildNode(reel.node)
            reels.append(reel)
        }

        // Park each reel on a random stop so the machine looks alive before the
        // first pull rather than showing five identical columns.
        var seed = Xoshiro256()
        for i in 0 ..< reels.count {
            let stop = Int(seed.next(upperBound: UInt64(strips[i].count)))
            applyTextures(reelIndex: i, stop: stop)
            applyDepthShading(reels[i])
        }
    }

    /// Fade panels out as they rotate away from the front.
    ///
    /// With unlit materials nothing would otherwise distinguish a symbol at the
    /// front from one curving over the top, and the reel would read as a flat
    /// collage. Dimming toward the background colour gives the classic look of
    /// symbols sinking into the cabinet at the edges of the window.
    ///
    /// Panel k sits at angle −k·Δ − ψ, so `cos` of that is exactly how face-on it is.
    private func applyDepthShading(_ reel: Reel) {
        let delta = 2 * Double.pi / Double(ReelTuning.panelCount)
        for (k, panel) in reel.panels.enumerated() {
            let angle = -Double(k) * delta - reel.angle
            let facing = max(0, cos(angle))
            // Steep falloff: the three centre rows stay near full brightness, the
            // partial rows peeking above and below drop away sharply.
            panel.opacity = CGFloat(0.12 + 0.88 * pow(facing, 1.7))
        }
    }

    private func buildReel(index: Int) -> Reel {
        let reel = Reel()
        let delta = 2 * Double.pi / Double(ReelTuning.panelCount)

        for k in 0 ..< ReelTuning.panelCount {
            let a = -Double(k) * delta

            let plane = SCNPlane(width: ReelTuning.panelSize, height: ReelTuning.panelSize)
            // No corner rounding: the symbol art carries its own gold frame and
            // rounded navy border, so geometry rounding would slice through it.
            plane.cornerRadius = 0

            let panel = SCNNode(geometry: plane)
            panel.position = SCNVector3(0,
                                        ReelTuning.radius * CGFloat(sin(a)),
                                        ReelTuning.radius * CGFloat(cos(a)))
            // Face outward: rotating +Z by −a gives the outward normal at angle a.
            panel.eulerAngles = SCNVector3(Float(-a), 0, 0)
            reel.node.addChildNode(panel)
            reel.panels.append(panel)
        }
        return reel
    }

    // MARK: Textures

    private func material(for symbol: Symbol) -> SCNMaterial {
        if let cached = materialCache[symbol] { return cached }

        let m = SCNMaterial()
        // Unlit. The symbol art arrives fully rendered — it already has its own key
        // light, gold specular and shadows painted in. Running it through a PBR
        // shader lights it a second time, which is what was tinting the lower rows
        // blue from the rim light. Depth is conveyed by perspective and the
        // per-panel dimming in `applyDepthShading`, not by re-lighting the artwork.
        m.lightingModel = .constant
        m.diffuse.contents = SymbolArt.image(for: symbol)
        m.isDoubleSided = false
        // The art is opaque and already self-framed, so it composites as a solid
        // tile. Leaving alpha blending on would only cost fill rate and risk
        // depth-sort artefacts where panels overlap at the top of the cylinder.
        m.blendMode = .replace
        m.writesToDepthBuffer = true

        materialCache[symbol] = m
        return m
    }

    /// Assign panel textures for a given stop position.
    ///
    /// Panel 0 is at front centre, which is grid row 1 (the middle row), and the grid
    /// reads `strip[stop]`, `strip[stop+1]`, `strip[stop+2]` top to bottom — hence the
    /// `+ 1` offset here.
    private func applyTextures(reelIndex: Int, stop: Int) {
        let strip = strips[reelIndex]
        let reel = reels[reelIndex]
        for k in 0 ..< reel.panels.count {
            let symbol = strip[(stop + 1 + k) % strip.count]
            reel.panels[k].geometry?.firstMaterial = material(for: symbol)
        }
    }

    // MARK: Spin control

    var spinning: Bool { isSpinning }

    /// Kick off a spin that lands on `result`.
    func spin(to result: SpinResult) {
        guard !isSpinning else { return }
        isSpinning = true
        pendingResult = result

        let now = CACurrentMediaTime()
        for (i, reel) in reels.enumerated() {
            // Textures are set now, at the start. By the time the reel decelerates
            // it's already showing the right symbols — the player can't tell during
            // the blur, and it avoids a visible pop from a late swap.
            applyTextures(reelIndex: i, stop: result.stops[i])

            // Normalise so every reel starts from a clean ψ = 0.
            reel.angle = 0
            reel.node.eulerAngles = SCNVector3(0, 0, 0)
            reel.speed = 0
            reel.justStopped = false
            reel.phase = .spinningUp(start: now)
        }
        lastFrameTime = now
    }

    // MARK: Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isSpinning else { return }
        let dt = min(time - lastFrameTime, 1.0 / 20.0)  // clamp so a hitch can't fling a reel
        lastFrameTime = time
        guard dt > 0 else { return }

        guard let result = pendingResult else { return }
        var allIdle = true

        for (i, reel) in reels.enumerated() {
            switch reel.phase {

            case .idle:
                break

            case .spinningUp(let start):
                allIdle = false
                let t = min((time - start) / ReelTuning.spinUpTime, 1)
                // Ease-in so the reel lurches away from rest like it has mass.
                reel.speed = ReelTuning.maxSpeed * (t * t)
                reel.angle += reel.speed * dt
                if t >= 1 {
                    var cruise = ReelTuning.baseCruiseTime + Double(i) * ReelTuning.reelStagger
                    if result.anticipation.indices.contains(i), result.anticipation[i] {
                        cruise += ReelTuning.anticipationHold
                    }
                    reel.phase = .cruising(until: time + cruise)
                }

            case .cruising(let until):
                allIdle = false
                reel.speed = ReelTuning.maxSpeed
                reel.angle += reel.speed * dt
                if time >= until {
                    // Land on the next whole turn that leaves enough runway to
                    // decelerate smoothly — otherwise a reel that happens to be just
                    // past 2π would slam to a halt.
                    let minTravel = reel.speed * ReelTuning.decelTime * 0.5
                    var target = (reel.angle + minTravel)
                    target = (target / (2 * .pi)).rounded(.up) * (2 * .pi)
                    reel.phase = .decelerating(start: time, from: reel.angle, to: target)
                }

            case .decelerating(let start, let from, let to):
                allIdle = false
                let t = min((time - start) / ReelTuning.decelTime, 1)
                // Cubic ease-out: fast arrival, soft landing.
                let eased = 1 - pow(1 - t, 3)
                reel.angle = from + (to - from) * eased
                reel.speed = (to - from) * 3 * pow(1 - t, 2) / ReelTuning.decelTime
                if t >= 1 {
                    reel.angle = to
                    reel.phase = .bouncing(start: time, from: to, to: to + ReelTuning.bounceAngle)
                }

            case .bouncing(let start, let from, let to):
                allIdle = false
                let t = min((time - start) / ReelTuning.bounceTime, 1)
                // Out and back — the mechanical recoil of a reel hitting its detent.
                let swing = sin(t * .pi)
                reel.angle = from + (to - from) * swing
                if t >= 1 {
                    reel.angle = from
                    reel.speed = 0
                    reel.phase = .idle
                    reel.justStopped = true
                }
            }

            reel.node.eulerAngles = SCNVector3(Float(reel.angle), 0, 0)
            applyDepthShading(reel)

            if reel.justStopped {
                reel.justStopped = false
                DispatchQueue.main.async { [weak self] in self?.onReelStopped?(i) }
            }
        }

        if allIdle {
            isSpinning = false
            pendingResult = nil
            DispatchQueue.main.async { [weak self] in self?.onSpinComplete?() }
        }
    }

    // MARK: Win presentation

    /// Pulse the winning symbols. Called after the last reel lands.
    func highlight(_ result: SpinResult) {
        var lit = Set<Int>()
        for win in result.lineWins {
            for p in win.positions { lit.insert(p.reel * Paylines.rows + p.row) }
        }
        for key in lit {
            let reel = key / Paylines.rows
            let row = key % Paylines.rows
            guard let panel = frontPanel(reel: reel, row: row) else { continue }
            let up = SCNAction.scale(to: 1.18, duration: 0.22)
            up.timingMode = .easeOut
            let down = SCNAction.scale(to: 1.0, duration: 0.22)
            down.timingMode = .easeIn
            panel.runAction(.repeat(.sequence([up, down]), count: 3))
        }
    }

    /// Shake the reel where a near miss landed, and flash the symbol that got away.
    func showNearMiss(_ nm: NearMiss) {
        guard let panel = frontPanel(reel: nm.reel, row: nm.row) else { return }
        let left  = SCNAction.moveBy(x: -0.045, y: 0, z: 0, duration: 0.05)
        let right = SCNAction.moveBy(x: 0.09, y: 0, z: 0, duration: 0.10)
        let back  = SCNAction.moveBy(x: -0.045, y: 0, z: 0, duration: 0.05)
        panel.runAction(.repeat(.sequence([left, right, back]), count: 3))
    }

    /// Which panel node is currently showing a given grid row.
    ///
    /// At rest ψ ≡ 0, so panel 0 is front centre (row 1), panel `panelCount − 1`
    /// is one step up (row 0), and panel 1 is one step down (row 2).
    private func frontPanel(reel: Int, row: Int) -> SCNNode? {
        guard reels.indices.contains(reel) else { return nil }
        let panels = reels[reel].panels
        let k: Int
        switch row {
        case 0:  k = panels.count - 1
        case 1:  k = 0
        default: k = 1
        }
        return panels.indices.contains(k) ? panels[k] : nil
    }
}
