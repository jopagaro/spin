//
//  ContentView.swift
//  RoyalSpin
//
//  Layout notes — why this is built from pieces rather than one image.
//
//  The source artwork (assets/marketing/royal_spin_cover_cabinet.png) is a *poster*:
//  a portrait rendering of a whole machine, with a tall crown, lions and thick
//  decorative side columns. Rendering it as a single image is what made the game
//  tiny. The arithmetic is unforgiving:
//
//    · the reel window is 68.55% of the poster's width and 37% of its height,
//      so the playfield is only ~25% of the artwork's area;
//    · the poster is 2:3 while a phone is nearer 1:2, so fitting it by width
//      leaves it covering ~69% of the screen height.
//
//  Multiply those and the reels land on **17.5% of the screen**. No amount of
//  scaling fixes that, because the side columns consume width the grid needs.
//
//  So the poster is cut into three full-width bands instead — marquee, reels,
//  control bar — each stretched to the screen's full width. The columns simply stop
//  being drawn, the grid becomes the hero, and symbols go from 55pt to ~76pt with
//  nothing cropped and the lions fully intact.
//

import SceneKit
import SwiftUI

// MARK: - Artwork geometry

/// Normalised positions measured off the source artwork. Replace a piece of art and
/// update the constants here; nothing else in the file moves.
private enum Art {

    /// `marquee.png` — crown, lions and nameplate. Cropped from the poster's top 408
    /// rows of 1024×1536, which stops just above the reel window's gem rail; cutting
    /// any lower leaves a row of half-gems that reads as a mistake.
    enum Marquee {
        static let w = 1024.0, h = 408.0
        static var aspect: Double { w / h }
    }

    /// `control_bar.png` — the quilted control panel with its four inset frames.
    /// Cropped from rows 1090…1400 of the poster.
    enum Bar {
        static let w = 1024.0, h = 310.0
        static var aspect: Double { w / h }

        /// Slot centres and interior sizes, normalised to this crop. The x values are
        /// unchanged from the poster; the y values are re-based by the 1090px offset.
        struct Slot { let cx, cy, sw, sh: Double }

        static let betDown = Slot(cx: 189 / w, cy: (1197 - 1090) / h, sw: 118 / w, sh: 132 / h)
        static let readout = Slot(cx: 379 / w, cy: (1199 - 1090) / h, sw: 120 / w, sh: 76 / h)
        static let betUp   = Slot(cx: 556 / w, cy: (1197 - 1090) / h, sw: 118 / w, sh: 132 / h)
        static let spin    = Slot(cx: 815 / w, cy: (1200 - 1090) / h, sw: 152 / w, sh: 152 / h)
    }

    /// Exact border colour of the artwork — used for the app background so the
    /// pieces have no visible seam against the screen.
    static let backdrop = Color(red: 0x00 / 255.0, green: 0x00 / 255.0, blue: 0x1D / 255.0)
    /// Inside the machine, behind the reels.
    static let reelVoid = Color(red: 0x15 / 255.0, green: 0x0A / 255.0, blue: 0x2E / 255.0)

    /// Rows of symbols the reel viewport shows: three full plus a sliver above and
    /// below. See the derivation in `ReelScene` — panels foreshorten toward the edge
    /// of the cylinder, so this is not simply 3 + 2×sliver.
    static let visibleRows = 3.25

    /// Side inset for the reel block, in points.
    static let reelInset: CGFloat = 10
    /// Thickness of the gold bezel drawn around the reels.
    static let bezel: CGFloat = 8
    /// Dark housing between the bezel and the reels. This is what gives the grid the
    /// presence of a machine body rather than a bare rectangle, and it usefully
    /// absorbs vertical slack that would otherwise read as dead space.
    static let housing: CGFloat = 22

    /// Draw the control bar wider than the screen and clip the overhang. It is a
    /// horizontal strip, so its far left and right are plain wooden moulding — losing
    /// a little makes the bar taller and gives the controls more presence, which is a
    /// much better trade than it was for the full cabinet.
    static let barOverscale: CGFloat = 1.26
}

// MARK: - View

struct ContentView: View {

    @StateObject private var game = GameViewModel()
    @State private var scene = ReelScene()
    @State private var showSettings = false
    @State private var showPaytable = false
    @State private var showStore = false
    @State private var winFlash = false
    @State private var spinPressed = false

    var body: some View {
        GeometryReader { geo in
            let inner = geo.size.width - Art.reelInset * 2 - (Art.bezel + Art.housing) * 2
            let symbol = inner / CGFloat(Paylines.reels)

            ZStack {
                background

                VStack(spacing: 0) {
                    hud
                    marquee
                    Spacer(minLength: 0)
                    reels(symbol: symbol)
                    Spacer(minLength: 0)
                    controlBar(width: geo.size.width)
                }
                // The control bar is the machine's base; it should meet the bottom of
                // the screen rather than float above the home indicator.
                .ignoresSafeArea(edges: .bottom)

                overlays
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: wireScene)
        .sheet(isPresented: $showSettings) { SettingsSheet(game: game) }
        .sheet(isPresented: $showPaytable) { PaytableSheet(volatility: game.volatility) }
        .sheet(isPresented: $showStore) { StoreSheet() }
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

    // MARK: Bands

    /// Credits, store and menu. Sits above the marquee so the number has room to
    /// grow to six digits without fighting the artwork.
    private var hud: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: -3) {
                Text("CREDITS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(2.0)
                Text(game.displayCredits.formatted())
                    .font(.system(size: 27, weight: .black, design: .serif))
                    .foregroundStyle(goldGradient)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 2)
            }

            // Buying credits is the planned business model, so the affordance is
            // reserved here now rather than retrofitted into a finished layout.
            Button { showStore = true } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .black))
                    Text("BUY")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0))
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Capsule().fill(goldGradient))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 2)

            if game.freeSpinsRemaining > 0 {
                VStack(spacing: -2) {
                    Text("\(game.freeSpinsRemaining)")
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundStyle(.black)
                    Text("FREE")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.7))
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(goldGradient))
                .transition(.scale.combined(with: .opacity))
            }

            chromeButton("rectangle.grid.3x2.fill") { showPaytable = true }
            chromeButton("gearshape.fill") { showSettings = true }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.freeSpinsRemaining)
    }

    /// Crown, lions and nameplate, full width.
    @ViewBuilder
    private var marquee: some View {
        if let art = UIImage(named: "marquee") {
            Image(uiImage: art)
                .resizable()
                .aspectRatio(Art.Marquee.aspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            Text("ROYAL SPIN")
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(goldGradient)
                .padding(.vertical, 18)
        }
    }

    /// The playfield. Full width, which is the whole point of this layout.
    private func reels(symbol: CGFloat) -> some View {
        let viewportW = symbol * CGFloat(Paylines.reels)
        let viewportH = symbol * CGFloat(Art.visibleRows)

        return ZStack {
            SceneView(
                scene: scene.scene,
                options: [.rendersContinuously],
                preferredFramesPerSecond: 60,
                antialiasingMode: .multisampling2X,
                delegate: scene
            )
            .frame(width: viewportW, height: viewportH)
            .background(Art.reelVoid)
        }
        .padding(Art.housing)
        .background(
            // Machine body: a slightly warmer dark than the reel void so the housing
            // reads as a surface the grid is inset into.
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color(red: 0.17, green: 0.08, blue: 0.28),
                             Color(red: 0.10, green: 0.05, blue: 0.19)],
                    startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            // Gold bezel, lit from the top-left to match the artwork.
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [Color(red: 1.0, green: 0.94, blue: 0.66),
                                            Color(red: 0.86, green: 0.63, blue: 0.18),
                                            Color(red: 0.55, green: 0.34, blue: 0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: Art.bezel)
        )
        .shadow(color: .black.opacity(0.75), radius: 18, y: 8)
    }

    /// The four controls, seated in the artwork's own inset frames.
    private func controlBar(width: CGFloat) -> some View {
        let h = width / Art.Bar.aspect

        return ZStack {
            if let art = UIImage(named: "control_bar") {
                Image(uiImage: art)
                    .resizable()
                    .frame(width: width, height: h)
                    .allowsHitTesting(false)
            }

            seat(Art.Bar.betDown, width, h) {
                betGlyph(minus: true, enabled: !game.isSpinning && canAdjustBet(up: false)) {
                    game.adjustBet(by: -1)
                }
            }

            seat(Art.Bar.readout, width, h) {
                VStack(spacing: -1) {
                    Text("BET")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1.5)
                    Text(game.totalBet.formatted())
                        .font(.system(size: 25, weight: .heavy, design: .serif))
                        .foregroundStyle(goldGradient)
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
            }

            seat(Art.Bar.betUp, width, h) {
                betGlyph(minus: false, enabled: !game.isSpinning && canAdjustBet(up: true)) {
                    game.adjustBet(by: 1)
                }
            }

            seat(Art.Bar.spin, width, h) { spinButton }
        }
        .frame(width: width, height: h)
    }

    /// Place a control at a slot's normalised centre within the control bar.
    private func seat<V: View>(_ slot: Art.Bar.Slot, _ w: CGFloat, _ h: CGFloat,
                               @ViewBuilder content: () -> V) -> some View {
        content()
            .frame(width: w * slot.sw, height: h * slot.sh)
            .position(x: w * slot.cx, y: h * slot.cy)
    }

    // MARK: Controls

    private func canAdjustBet(up: Bool) -> Bool {
        guard let i = GameViewModel.betLevels.firstIndex(of: game.betPerLine) else { return true }
        return up ? i < GameViewModel.betLevels.count - 1 : i > 0
    }

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

    private var spinButton: some View {
        Button(action: spin) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: game.canSpin
                            ? [Color(red: 1.00, green: 0.88, blue: 0.48),
                               Color(red: 0.90, green: 0.56, blue: 0.10),
                               Color(red: 0.48, green: 0.19, blue: 0.02)]
                            : [Color(white: 0.34), Color(white: 0.16)],
                        center: .init(x: 0.32, y: 0.26), startRadius: 1, endRadius: 90))
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.6), .clear, .black.opacity(0.35)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2.5)
                Text(game.isFreeSpin ? "FREE" : "SPIN")
                    .font(.system(size: 21, weight: .black, design: .serif))
                    .foregroundStyle(game.canSpin
                                     ? Color(red: 0.26, green: 0.10, blue: 0)
                                     : Color.white.opacity(0.35))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
            .scaleEffect(spinPressed ? 0.92 : 1)
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
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().strokeBorder(goldGradient.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Chrome

    private var background: some View {
        ZStack {
            if let bg = UIImage(named: "bg_throne_room") {
                Image(uiImage: bg).resizable().scaledToFill().ignoresSafeArea()
                    .overlay(Color.black.opacity(0.32).ignoresSafeArea())
            } else {
                // Until there's a throne-room backdrop, a centred radial lift keeps
                // the empty area reading as depth rather than as a flat void.
                ZStack {
                    Art.backdrop
                    RadialGradient(
                        colors: [Color(red: 0.16, green: 0.06, blue: 0.30).opacity(0.85),
                                 Color.clear],
                        center: .center, startRadius: 40, endRadius: 520)
                }
                .ignoresSafeArea()
            }
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
                    Spacer().frame(height: 190)
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
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    Spacer().frame(height: 190)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Not wired up yet", systemImage: "hammer.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("This is where credit packs will go. Wiring it up means "
                         + "StoreKit 2 products, a purchase flow, and restoring "
                         + "purchases — plus an age rating and a review of the "
                         + "App Store's rules for apps that sell virtual currency "
                         + "alongside slot mechanics (guidelines 3.1.1 and 4.7), and "
                         + "the equivalent Google Play gambling policy.")
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
