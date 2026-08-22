//
//  ContentView.swift
//  RoyalSpin
//
//  The whole cabinet, drawn as one piece of artwork, with the live 3D reels showing
//  through its chroma-keyed window and the controls seated in its own inset frames.
//
//  An earlier revision cut the poster into three full-width bands (marquee / reels /
//  control bar) to make the symbols bigger. It worked arithmetically — symbols went
//  from 55pt to 76pt — but it read as three separate objects rather than a machine,
//  so it's been reverted. The size is instead recovered by the three-reel cabinet,
//  where the same window is divided by three rather than five.
//
//  Only the credits readout and the store button live outside the cabinet, at the
//  top of the screen, where a six-digit number has room to grow.
//

import SceneKit
import SwiftUI

// MARK: - Cabinet geometry

/// Per-machine cabinet artwork and its measured geometry. Each machine gets its own
/// cabinet so the reel window's aspect can match that machine's reel bank — one
/// window cannot fit both a 3×3 bank (1.09:1) and a 5×3 bank (1.81:1) without
/// letterboxing one of them into dark voids.
///
/// Internal, not private: `ReelScene` reads the window aspect to pick the camera's
/// binding axis, so the window is measured in exactly one place.
enum Cab {
    /// The artwork's own deep purple, sampled from the cabinet: it is the single
    /// most common purple in the image at #300040.
    ///
    /// Used flat across the entire screen. Previously this was a near-black navy with
    /// a radial gradient lifting the middle, which is why the strip above the cabinet
    /// read as a different purple from the area around it — the gradient was simply
    /// brighter near the centre of the screen than at the edges.
    static let backdrop = Color(red: 0x30 / 255.0, green: 0x00 / 255.0, blue: 0x40 / 255.0)
    /// Inside the machine, behind the reels. `ReelScene` paints its scene background
    /// this exact colour so the letterbox bands and the scene interior read as one
    /// surface.
    static let reelVoid = Color(red: 0x15 / 255.0, green: 0x0A / 255.0, blue: 0x2E / 255.0)

    /// Apparent vertical extent of exactly three rows, in front-plane units.
    ///
    /// Not 3.0. The reels are a cylinder, so the rows above and below centre sit
    /// *deeper* than the middle one (z = R·cos Δ rather than R), and perspective
    /// shrinks them toward the centre. Three rows therefore project into 2.76 units,
    /// not 3.0 — sizing the viewport to 3.0 leaves 0.24 units of slack, which is
    /// precisely the gap the next row peeked through.
    ///
    /// Derived: the outer edge of row ±1 is at world y = R·sin Δ + ½·cos Δ = 1.470,
    /// at depth z = 2.117. Solving apparent(E) = E/2 for that point gives E = 2.7616.
    static let visibleRows = 2.7616

    /// A control slot: centre plus usable interior size, both normalised.
    struct Slot { let cx, cy, w, h: Double }

    /// One cabinet artwork: asset name, canvas size, chroma-keyed window rect, and
    /// the measured interior openings of the four control wells. All positions are
    /// pixel measurements off the master PNG, normalised here.
    struct Spec {
        let imageName: String
        let imageW, imageH: Double
        /// Window rect in master pixels.
        let winPx: (x0: Double, x1: Double, y0: Double, y1: Double)
        let betDown, readout, betUp, spin: Slot

        var aspect: Double { imageW / imageH }
        var winX0: Double { winPx.x0 / imageW }
        var winX1: Double { winPx.x1 / imageW }
        var winY0: Double { winPx.y0 / imageH }
        var winY1: Double { winPx.y1 / imageH }
        var winMidX: Double { (winX0 + winX1) / 2 }
        var winMidY: Double { (winY0 + winY1) / 2 }
        var winW: Double { winX1 - winX0 }
        var winH: Double { winY1 - winY0 }
        /// Width:height of the window opening itself, in pixels.
        var windowAspect: Double { (winPx.x1 - winPx.x0) / (winPx.y1 - winPx.y0) }
    }

    static func spec(for mode: ReelMode) -> Spec { mode == .three ? three : five }

    /// Orientation-aware variant. Only Empire has landscape artwork; Kingdom in
    /// landscape keeps its portrait cabinet, aspect-fit and pillarboxed.
    static func spec(for mode: ReelMode, landscape: Bool) -> Spec {
        landscape && mode == .five ? fiveLandscape : spec(for: mode)
    }

    /// How far apart to place reel centres (panel widths) for a given window.
    ///
    /// When the window is slightly wider than a snug bank, the reels are spread —
    /// never squeezed — so the bank fills it exactly: thin dark seams between reels
    /// read as the machine's reel dividers, where flanking void bands read as a
    /// mistake. Capped at 10% so artwork that is badly off shows honest bands
    /// rather than gap-toothed reels.
    static func reelSpacing(for mode: ReelMode, windowAspect: Double) -> Double {
        guard mode.reels > 1 else { return 1 }
        let targetWidth = windowAspect * visibleRows
        let spacing = (targetWidth - 1) / Double(mode.reels - 1)
        return min(max(spacing, 1), 1.10)
    }

    /// Width:height of the reel bank at that spacing — the aspect the camera
    /// actually frames. Panels are one unit square, so the bank is (n−1)·s + 1 wide.
    static func bankAspect(for mode: ReelMode, windowAspect: Double) -> Double {
        let spacing = reelSpacing(for: mode, windowAspect: windowAspect)
        return (Double(mode.reels - 1) * spacing + 1) / visibleRows
    }

    /// `cabinet_three.png` — measured off the master. Window opening 520 × 507
    /// (x 252–771, y 514–1020), aspect 1.026 against the 3×3 bank's ideal 1.086:
    /// the residual is a ~14px band top and bottom, filled with `reelVoid`.
    ///
    ///   betDown  opening  78 x  69 centred (255.5, 1138.0)
    ///   readout  opening 154 x  56 centred (423.5, 1137.5)
    ///   betUp    opening  78 x  69 centred (590.5, 1138.0)
    ///   spin     opening 126 x 106 centred (753.5, 1142.5)
    static let three = Spec(
        imageName: "cabinet_three",
        imageW: 1024, imageH: 1536,
        winPx: (x0: 252, x1: 771, y0: 514, y1: 1020),
        betDown: Slot(cx: 255.5 / 1024, cy: 1138.0 / 1536, w:  72 / 1024, h:  63 / 1536),
        readout: Slot(cx: 423.5 / 1024, cy: 1137.5 / 1536, w: 146 / 1024, h:  50 / 1536),
        betUp:   Slot(cx: 590.5 / 1024, cy: 1138.0 / 1536, w:  72 / 1024, h:  63 / 1536),
        spin:    Slot(cx: 753.5 / 1024, cy: 1142.5 / 1536, w: 116 / 1024, h:  96 / 1536)
    )

    /// `cabinet_five.png` — the letterbox cabinet. Window opening 665 × 355
    /// (x 177–841, y 709–1063), aspect 1.873 against the 5×3 bank's ideal 1.811:
    /// the residual is a ~11px band each side, filled with `reelVoid`.
    ///
    ///   betDown  opening  78 x  58 centred (249.5, 1272.5)
    ///   readout  opening 156 x  51 centred (419.5, 1274.0)
    ///   betUp    opening  78 x  58 centred (587.5, 1273.5)
    ///   spin     opening 124 x  83 centred (748.5, 1276.0)
    static let five = Spec(
        imageName: "cabinet_five",
        imageW: 1024, imageH: 1536,
        winPx: (x0: 177, x1: 841, y0: 709, y1: 1063),
        betDown: Slot(cx: 249.5 / 1024, cy: 1272.5 / 1536, w:  72 / 1024, h:  52 / 1536),
        readout: Slot(cx: 419.5 / 1024, cy: 1274.0 / 1536, w: 148 / 1024, h:  46 / 1536),
        betUp:   Slot(cx: 587.5 / 1024, cy: 1273.5 / 1536, w:  72 / 1024, h:  52 / 1536),
        spin:    Slot(cx: 748.5 / 1024, cy: 1276.0 / 1536, w: 114 / 1024, h:  76 / 1536)
    )

    /// `cabinet_five_land.png` — the landscape cabinet: shallow marquee, window
    /// on the left, control deck stacked down the right. Window opening 1066 × 555
    /// (x 69–1134, y 196–750), aspect 1.921 — the ~6% beyond the bank's 1.811 is
    /// absorbed by `reelSpacing` stretching the reels into it.
    ///
    ///   betDown  opening  98 x  96 centred (1331.5,  257.5)
    ///   readout  opening 203 x  70 centred (1331.0,  375.5)
    ///   betUp    opening  96 x  91 centred (1331.5,  487.0)
    ///   spin     opening 176 x 171 centred (1331.5,  648.0)
    static let fiveLandscape = Spec(
        imageName: "cabinet_five_land",
        imageW: 1536, imageH: 864,
        winPx: (x0: 69, x1: 1134, y0: 196, y1: 750),
        betDown: Slot(cx: 1331.5 / 1536, cy: 257.5 / 864, w:  90 / 1536, h:  88 / 864),
        readout: Slot(cx: 1331.0 / 1536, cy: 375.5 / 864, w: 194 / 1536, h:  64 / 864),
        betUp:   Slot(cx: 1331.5 / 1536, cy: 487.0 / 864, w:  88 / 1536, h:  84 / 864),
        spin:    Slot(cx: 1331.5 / 1536, cy: 648.0 / 864, w: 164 / 1536, h: 160 / 864)
    )
}

// MARK: - Root

/// Owns the session and swaps between the lobby and a machine.
struct ContentView: View {

    @StateObject private var game = GameViewModel()
    @State private var screen: Screen
    @State private var showStore = false

    private enum Screen { case welcome, lobby, machine, realm }

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let initialScreen: Screen
        if arguments.contains("-ui-realm") {
            initialScreen = .realm
        } else if arguments.contains("-ui-lobby") {
            initialScreen = .lobby
        } else {
            initialScreen = .welcome
        }
#else
        let initialScreen: Screen = .welcome
#endif
        _screen = State(initialValue: initialScreen)
    }

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeView(
                    // Straight into the starter machine. No decision required first.
                    onPlay: {
                        game.selectMachine(mode: .three,
                                           volatility: ReelMode.three.defaultVolatility)
                        screen = .machine
                    },
                    onChooseMachine: { screen = .lobby }
                )

            case .lobby:
                LobbyView(
                    game: game,
                    onPick: { mode, volatility in
                        if game.selectMachine(mode: mode, volatility: volatility) {
                            screen = .machine
                        }
                    },
                    onBuy: { showStore = true },
                    onRealm: { screen = .realm },
                    onBack: { screen = .welcome }
                )

            case .machine:
                MachineView(game: game,
                            onExit: { screen = .lobby },
                            onRealm: { screen = .realm })

            case .realm:
                RealmView(game: game,
                          onBack: { screen = .lobby },
                          onSpin: { screen = .machine })
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .sheet(isPresented: $showStore) { StoreSheet(onReset: game.resetCredits) }
    }
}

// MARK: - Machine

struct MachineView: View {

    @ObservedObject var game: GameViewModel
    var onExit: () -> Void
    var onRealm: () -> Void

    @State private var scene = ReelScene()
    @State private var showSettings = false
    @State private var showPaytable = false
    @State private var showStore = false
    @State private var winFlash = false
    @State private var spinPressed = false
    /// Tracked off the cabinet container's geometry; picks the cabinet artwork.
    @State private var isLandscape = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                cabinet
            }
            .ignoresSafeArea(edges: .bottom)

            overlays

            if let levelUp = game.levelUp {
                LevelUpBanner(event: levelUp,
                              onDismiss: game.dismissLevelUp,
                              onRealm: onRealm)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { wireScene() }
        .onChange(of: game.mode) { _, newMode in
            scene.frame(mode: newMode,
                        windowAspect: Cab.spec(for: newMode, landscape: isLandscape).windowAspect)
        }
        .sheet(isPresented: $showSettings) { SettingsSheet(game: game) }
        .sheet(isPresented: $showPaytable) {
            PaytableSheet(volatility: game.volatility, mode: game.mode)
        }
        .sheet(isPresented: $showStore) { StoreSheet(onReset: game.resetCredits) }
    }

    // MARK: Wiring

    private func wireScene() {
        scene.onReelStopped = { game.reelDidStop(index: $0) }
        scene.onSpinComplete = {
            game.spinDidFinish()
            guard let r = game.lastResult else { return }
            if r.totalWin > 0 {
                scene.highlight(r)
                withAnimation(.easeOut(duration: 0.18)) { winFlash = true }
                withAnimation(.easeIn(duration: 0.5).delay(0.18)) { winFlash = false }
            } else if let nm = r.nearMiss {
                scene.showNearMiss(nm)
            }
        }
    }

    private func spin() {
        guard let result = game.beginSpin() else { return }
        scene.spin(to: result)
    }

    // MARK: Top bar

    /// Credits, progression and utility actions above the cabinet.
    private var topBar: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(goldGradient)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.black.opacity(0.45)))
                    .overlay(Circle().strokeBorder(goldGradient.opacity(0.6), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(game.isSpinning)
            .opacity(game.isSpinning ? 0.35 : 1)

            Button { showStore = true } label: {
                HStack(spacing: 7) {
                    VStack(alignment: .leading, spacing: -3) {
                        Text("CREDITS")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(1.5)
                        Text(game.displayCredits.formatted())
                            .font(.system(size: 23, weight: .black, design: .serif))
                            .foregroundStyle(goldGradient)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: 78, alignment: .leading)
                            .shadow(color: .black.opacity(0.8), radius: 3, y: 2)
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(goldGradient))
                }
                .padding(.leading, 9)
                .padding(.trailing, 6)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.35)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 2)

            if game.bonusSpins > 0 {
                badge(count: game.bonusSpins, label: "BONUS")
            } else if game.freeSpinsRemaining > 0 {
                badge(count: game.freeSpinsRemaining, label: "FREE")
            }

            chromeButton("rectangle.grid.3x2.fill") { showPaytable = true }
            chromeButton("building.columns.fill") { onRealm() }
            chromeButton("gearshape.fill") { showSettings = true }
            }

            HStack(spacing: 10) {
                RankBar(progress: game.progress, compact: true)
                    .frame(maxWidth: .infinity)

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    CollectButton(ready: game.freeCreditsReady,
                                  amount: game.freeCreditsAmount,
                                  countdown: game.freeCreditsCountdown,
                                  action: { game.collectFreeCredits() })
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.bonusSpins)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.freeSpinsRemaining)
    }

    private func badge(count: Int, label: String) -> some View {
        VStack(spacing: -2) {
            Text("\(count)")
                .font(.system(size: 15, weight: .black, design: .serif))
                .foregroundStyle(.black)
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.7))
        }
        .frame(width: 34, height: 34)
        .background(Circle().fill(goldGradient))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Cabinet

    /// Geometry of whichever cabinet artwork is on screen.
    private var spec: Cab.Spec { Cab.spec(for: game.mode, landscape: isLandscape) }

    /// Keep the artwork choice and the scene's camera in step with the container's
    /// orientation. Runs on the cabinet's geometry, not the device orientation —
    /// what matters is the shape of the space the cabinet actually has.
    private func syncOrientation(_ size: CGSize) {
        let landscape = size.width > size.height
        if landscape != isLandscape { isLandscape = landscape }
        scene.frame(mode: game.mode,
                    windowAspect: Cab.spec(for: game.mode, landscape: landscape).windowAspect)
    }

    private var cabinet: some View {
        GeometryReader { geo in
            let fit = cabinetSize(in: geo.size)
            let ox = (geo.size.width - fit.width) / 2
            let oy = (geo.size.height - fit.height) / 2

            ZStack {
                // Dark interior filling the whole window. The 3D viewport can be
                // shorter than this, so these bands show above and below the reels.
                Rectangle()
                    .fill(Cab.reelVoid)
                    .frame(width: fit.width * spec.winW, height: fit.height * spec.winH)
                    .position(x: ox + fit.width * spec.winMidX,
                              y: oy + fit.height * spec.winMidY)

                SceneView(
                    scene: scene.scene,
                    options: [.rendersContinuously],
                    preferredFramesPerSecond: 60,
                    antialiasingMode: .multisampling2X,
                    delegate: scene
                )
                .frame(width: fit.width * spec.winW,
                       height: viewportHeight(fit: fit))
                .position(x: ox + fit.width * spec.winMidX,
                          y: oy + fit.height * spec.winMidY)

                if let art = UIImage(named: spec.imageName) {
                    // Framed to exactly the rect the slot overlays are computed
                    // against. Letting this default to `scaledToFit` inside the
                    // container draws it at a different scale and every control
                    // drifts off its frame.
                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fit.width, height: fit.height)
                        .position(x: ox + fit.width / 2, y: oy + fit.height / 2)
                        .allowsHitTesting(false)
                }

                seat(spec.betDown, fit, ox, oy) {
                    betGlyph(minus: true,
                             enabled: !game.isSpinning && game.canAdjustBet(up: false)) {
                        game.adjustBet(by: -1)
                    }
                }

                seat(spec.readout, fit, ox, oy) { betReadout(fit: fit) }

                seat(spec.betUp, fit, ox, oy) {
                    betGlyph(minus: false,
                             enabled: !game.isSpinning && game.canAdjustBet(up: true)) {
                        game.adjustBet(by: 1)
                    }
                }

                seat(spec.spin, fit, ox, oy) { spinButton(fit: fit) }
            }
            .onAppear { syncOrientation(geo.size) }
            .onChange(of: geo.size) { _, newSize in syncOrientation(newSize) }
        }
        .clipped()
    }

    /// The 3D viewport is never taller than the window; when the window is taller
    /// than the bank needs, the leftover band is `reelVoid`, reading as the dark
    /// interior of the machine.
    private func viewportHeight(fit: CGSize) -> CGFloat {
        let w = fit.width * spec.winW
        // Same stretched bank the scene frames — when the spacing stretch absorbs
        // the whole difference this is exactly the window's own aspect.
        let aspect = Cab.bankAspect(for: game.mode, windowAspect: spec.windowAspect)
        return min(w / aspect, fit.height * spec.winH)
    }

    /// Wants the full artwork visible, so this is a plain aspect fit. Drawing it
    /// wider than the screen would enlarge the symbols, but it slices the lions —
    /// they begin only 45px in from the artwork's edge.
    private func cabinetSize(in container: CGSize) -> CGSize {
        let width = min(container.width, container.height * spec.aspect)
        return CGSize(width: width, height: width / spec.aspect)
    }

    /// Seat a control at a slot's normalised centre within the fitted artwork.
    private func seat<V: View>(_ slot: Cab.Slot, _ fit: CGSize,
                               _ ox: CGFloat, _ oy: CGFloat,
                               @ViewBuilder content: () -> V) -> some View {
        content()
            .frame(width: fit.width * slot.w, height: fit.height * slot.h)
            .position(x: ox + fit.width * slot.cx, y: oy + fit.height * slot.cy)
    }

    // MARK: Controls

    /// Bet +/− as solid gold bars rather than SF Symbols, which read as system UI
    /// pasted onto a hand-painted cabinet.
    private func betGlyph(minus: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GeometryReader { g in
                let s = min(g.size.width, g.size.height)
                ZStack {
                    Color.white.opacity(0.001)          // full-slot hit target
                    Group {
                        Capsule().frame(width: s * 0.46, height: s * 0.115)
                        if !minus { Capsule().frame(width: s * 0.115, height: s * 0.46) }
                    }
                    .foregroundStyle(goldGradient)
                    .shadow(color: .black.opacity(0.85), radius: 2, y: 1.5)
                }
                .frame(width: g.size.width, height: g.size.height)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        // Still clearly visible when disabled — too faint reads as a missing button
        // rather than a bet already at its limit.
        .opacity(enabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: enabled)
    }

    /// The bet readout, sized to the well the current artwork provides. The wells
    /// differ per cabinet (the three-reel readout is a short 50px letterbox, the
    /// five-reel a tall 118px frame), so the type scales from the seat, not from
    /// constants.
    private func betReadout(fit: CGSize) -> some View {
        let slotH = fit.height * spec.readout.h
        return VStack(spacing: -1) {
            // In a short well the label steals height the number needs.
            if slotH >= 30 {
                Text("BET")
                    .font(.system(size: max(7, slotH * 0.19), weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1.5)
            }
            Text(game.totalBet.formatted())
                .font(.system(size: slotH * (slotH >= 30 ? 0.54 : 0.68),
                              weight: .heavy, design: .serif))
                .foregroundStyle(goldGradient)
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
    }

    private func spinButton(fit: CGSize) -> some View {
        // Width binds: SPIN in black serif measures ~2.7× its point size, and it
        // should sit clear of the gold ring — 0.26 × the well width reproduces the
        // hand-tuned 21pt on the original 82pt well and scales to smaller ones.
        let slotW = fit.width * spec.spin.w
        let slotH = fit.height * spec.spin.h
        let fontSize = min(slotH * 0.45, slotW * 0.26)
        return Button(action: spin) {
            // Just the word. The cabinet artwork already draws the round button well
            // — purple face, gold ring, the lot — so drawing another circle on top
            // only ever put a second button inside the first one. The text sits in
            // the well the artwork provides; the transparent circle behind it is the
            // tap target, nothing more.
            ZStack {
                Color.white.opacity(0.001)

                Text(game.spinButtonLabel)
                    .font(.system(size: fontSize, weight: .black, design: .serif))
                    .tracking(0.5)
                    .foregroundStyle(game.canSpin
                                     ? AnyShapeStyle(goldGradient)
                                     : AnyShapeStyle(Color.white.opacity(0.28)))
                    .shadow(color: .black.opacity(0.85), radius: 3, y: 2)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .contentShape(Circle())
            .scaleEffect(spinPressed ? 0.90 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!game.canSpin)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !spinPressed else { return }
                    withAnimation(.easeOut(duration: 0.08)) { spinPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { spinPressed = false }
                }
        )
    }

    private func chromeButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(goldGradient)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().strokeBorder(goldGradient.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Chrome

    private var background: some View {
        ZStack {
            // Flat and uniform. No gradient: any falloff makes the area above the
            // cabinet a visibly different purple from the area beside it.
            Cab.backdrop.ignoresSafeArea()
            Color.white.opacity(winFlash ? 0.26 : 0)
                .ignoresSafeArea().allowsHitTesting(false)
        }
    }

    private var overlays: some View {
        ZStack {
            if let nm = game.nearMissBanner {
                VStack {
                    Spacer()
                    Text("SO CLOSE — \(nm.symbol.displayName.uppercased()) MISSED BY ONE")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                    Spacer().frame(height: 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let r = game.lastResult, r.totalWin > 0, !game.isSpinning,
               r.tier.rawValue >= WinTier.big.rawValue {
                VStack(spacing: 2) {
                    Text(r.tier == .jackpot ? "JACKPOT" : r.tier == .mega ? "MEGA WIN" : "BIG WIN")
                        .font(.system(size: 40, weight: .black, design: .serif))
                        .foregroundStyle(goldGradient)
                    Text("+\(r.totalWin.formatted())")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.85), radius: 10, y: 4)
                .transition(.scale.combined(with: .opacity))
            }

            if let message = game.message {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(goldGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                    Spacer().frame(height: 40)
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: game.nearMissBanner?.symbol)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: game.isSpinning)
        .animation(.easeInOut(duration: 0.2), value: game.message)
    }

    private var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 1.0, green: 0.94, blue: 0.66),
                                Color(red: 0.95, green: 0.76, blue: 0.28),
                                Color(red: 0.74, green: 0.48, blue: 0.10)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Placeholder for the credit store. The layout reserves the entry point now so the
/// real thing drops in without another redesign.
struct StoreSheet: View {
    var onReset: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Add \(GameViewModel.startingCredits.formatted()) credits") {
                        onReset()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                } header: {
                    Text("For now")
                } footer: {
                    Text("Free, unlimited, and instant — there is no purchase here yet, "
                         + "so this stands in for the store and keeps the game playable.")
                }

                Section {
                    Label("Real store not wired up yet", systemImage: "hammer.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("Credit packs go here. Wiring it up means StoreKit 2 products, "
                         + "a purchase flow and restore, plus an age rating and a review "
                         + "of the App Store rules for apps that sell virtual currency "
                         + "alongside slot mechanics (guidelines 3.1.1 and 4.7), and the "
                         + "equivalent Google Play gambling policy.")
                }
            }
            .navigationTitle("Get Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

#Preview {
    ContentView()
}
