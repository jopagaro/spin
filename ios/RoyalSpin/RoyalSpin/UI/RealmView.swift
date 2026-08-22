//
//  RealmView.swift
//  RoyalSpin
//
//  A fixed-composition 2.5D world. The background never contains construction;
//  each rank contributes one transparent layer at a known anchor.
//

import SwiftUI

struct RealmView: View {
    @ObservedObject var game: GameViewModel
    let onBack: () -> Void
    let onSpin: () -> Void

    @State private var selected: RealmUpgrade?
    @State private var lastBuiltLevel: Int?
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var liveZoom: CGFloat = 1
    @GestureState private var liveDrag: CGSize = .zero

    private var next: RealmUpgrade? { game.nextRealmUpgrade }

    var body: some View {
        ZStack {
            LobbyStyle.backdrop.ignoresSafeArea()

            VStack(spacing: 8) {
                header
                realmCanvas
                    .frame(maxHeight: .infinity)
                upgradeCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear { selected = next ?? RealmUpgrade.all.last }
        .onChange(of: game.nextRealmUpgrade?.level) { _, _ in
            selected = next ?? selected
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LobbyStyle.gold)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: -2) {
                    Text("MY REALM")
                        .font(.system(size: 25, weight: .black, design: .serif))
                        .foregroundStyle(LobbyStyle.gold)
                    Text("PEASANTRY · \(game.completedRealmCount)/10 BUILT")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: -2) {
                    Text(game.displayCredits.formatted())
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundStyle(LobbyStyle.gold)
                        .monospacedDigit()
                    Text("CREDITS")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            HStack(spacing: 10) {
                RankBar(progress: game.progress, compact: true)
                ProgressView(value: Double(game.completedRealmCount), total: 10)
                    .tint(Color(red: 0.95, green: 0.76, blue: 0.28))
                    .frame(maxWidth: 100)
            }
        }
    }

    private var realmCanvas: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Image("realm_base_mud")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: side, height: side)

                ForEach(visibleCompleted) { upgrade in
                    realmSprite(upgrade, side: side)
                        .transition(.scale(scale: 0.65).combined(with: .opacity))
                }

                if let next {
                    Button { selected = next } label: {
                        realmSprite(next, side: side)
                            .saturation(0)
                            .brightness(-0.72)
                            .contrast(1.25)
                            .opacity(game.progress.level >= next.level ? 0.72 : 0.42)
                            .overlay(alignment: .center) {
                                Image(systemName: game.progress.level >= next.level
                                      ? "hammer.fill" : "lock.fill")
                                    .font(.system(size: max(15, side * 0.035), weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(.black.opacity(0.70)))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(next.name), unlocks at rank \(next.level)")
                }

                if let built = lastBuiltLevel, let upgrade = RealmUpgrade.at(level: built) {
                    Circle()
                        .fill(Color.yellow.opacity(0.45))
                        .blur(radius: 18)
                        .frame(width: side * upgrade.width * 1.2)
                        .position(x: side * upgrade.centerX, y: side * upgrade.centerY)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .scaleEffect(min(2.4, max(0.9, zoom * liveZoom)))
            .offset(x: offset.width + liveDrag.width, y: offset.height + liveDrag.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($liveDrag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($liveZoom) { value, state, _ in state = value }
                    .onEnded { value in zoom = min(2.4, max(0.9, zoom * value)) }
            )
            .clipped()
            .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(LobbyStyle.gold.opacity(0.35), lineWidth: 1.5))
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: game.realmState)
        }
    }

    private var visibleCompleted: [RealmUpgrade] {
        RealmUpgrade.all.filter { upgrade in
            guard game.realmState.isCompleted(upgrade.level) else { return false }
            if upgrade.level == 1, game.realmState.isCompleted(10) { return false }
            return true
        }
    }

    private func realmSprite(_ upgrade: RealmUpgrade, side: CGFloat) -> some View {
        Image(upgrade.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: side * upgrade.width)
            .position(x: side * upgrade.centerX, y: side * upgrade.centerY)
    }

    @ViewBuilder
    private var upgradeCard: some View {
        if let upgrade = selected ?? next {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RANK \(upgrade.level) · \(upgrade.rankTitle.uppercased())")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.48))
                        Text(upgrade.name)
                            .font(.system(size: 21, weight: .black, design: .serif))
                            .foregroundStyle(LobbyStyle.gold)
                    }
                    Spacer()
                    Text(upgrade.cost == 0 ? "FREE" : "\(upgrade.cost.formatted())")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(upgrade.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button(action: onSpin) {
                        Label("SPIN TO EARN", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RealmSecondaryButtonStyle())

                    Button { build(upgrade) } label: {
                        Text(actionLabel(for: upgrade))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RealmPrimaryButtonStyle())
                    .disabled(!canBuild(upgrade))
                    .opacity(canBuild(upgrade) ? 1 : 0.48)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.42)))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(LobbyStyle.gold.opacity(0.35), lineWidth: 1))
        }
    }

    private func canBuild(_ upgrade: RealmUpgrade) -> Bool {
        !game.realmState.isCompleted(upgrade.level)
            && game.progress.level >= upgrade.level
            && (upgrade.level == 1 || game.realmState.isCompleted(upgrade.level - 1))
            && game.credits >= upgrade.cost
    }

    private func actionLabel(for upgrade: RealmUpgrade) -> String {
        if game.realmState.isCompleted(upgrade.level) { return "BUILT" }
        if game.progress.level < upgrade.level { return "REACH RANK \(upgrade.level)" }
        if upgrade.level > 1, !game.realmState.isCompleted(upgrade.level - 1) {
            return "BUILD RANK \(upgrade.level - 1) FIRST"
        }
        if game.credits < upgrade.cost {
            return "NEED \((upgrade.cost - game.credits).formatted())"
        }
        return "UPGRADE · \(upgrade.cost.formatted())"
    }

    private func build(_ upgrade: RealmUpgrade) {
        guard case .built = game.purchaseRealmUpgrade(upgrade) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            lastBuiltLevel = upgrade.level
        }
        Task {
            try? await Task.sleep(nanoseconds: 850_000_000)
            withAnimation(.easeOut(duration: 0.35)) { lastBuiltLevel = nil }
        }
    }
}

private struct RealmPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0))
            .padding(.vertical, 11)
            .background(Capsule().fill(LobbyStyle.gold))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct RealmSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.vertical, 11)
            .background(Capsule().fill(.white.opacity(0.10)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
