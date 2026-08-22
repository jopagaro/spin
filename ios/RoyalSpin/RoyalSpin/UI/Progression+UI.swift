//
//  Progression+UI.swift
//  RoyalSpin
//
//  The rank badge, XP bar, level-up banner and timed-collect button.
//

import SwiftUI

// MARK: - Band colour

extension Rank.Band {
    /// Each band gets its own metal, so a glance at the badge tells you roughly how
    /// far someone has come without reading the title.
    var tint: LinearGradient {
        switch self {
        case .peasantry:  // rough iron
            return grad(Color(red: 0.62, green: 0.60, blue: 0.58),
                        Color(red: 0.34, green: 0.32, blue: 0.31))
        case .household:  // bronze
            return grad(Color(red: 0.84, green: 0.60, blue: 0.36),
                        Color(red: 0.47, green: 0.30, blue: 0.15))
        case .court:      // motley purple
            return grad(Color(red: 0.78, green: 0.52, blue: 0.94),
                        Color(red: 0.40, green: 0.16, blue: 0.55))
        case .arms:       // steel
            return grad(Color(red: 0.74, green: 0.82, blue: 0.94),
                        Color(red: 0.32, green: 0.42, blue: 0.60))
        case .gentry:     // silver
            return grad(Color(red: 0.94, green: 0.94, blue: 0.97),
                        Color(red: 0.55, green: 0.57, blue: 0.64))
        case .crown:      // gold
            return grad(Color(red: 1.00, green: 0.94, blue: 0.66),
                        Color(red: 0.74, green: 0.48, blue: 0.10))
        }
    }

    private func grad(_ a: Color, _ b: Color) -> LinearGradient {
        LinearGradient(colors: [a, b], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Rank badge + XP bar

/// The generated portrait when one exists, with the numbered metal chip as the
/// fallback while later sections of the rank ladder are still being illustrated.
struct RankMedallion: View {
    let level: Int
    let band: Rank.Band
    var size: CGFloat

    var body: some View {
        Group {
            if let assetName = Rank.illustratedAssetName(for: level) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(band.tint, lineWidth: max(1, size * 0.035)))
                    .shadow(color: .black.opacity(0.55), radius: size * 0.08, y: size * 0.04)
            } else {
                Text("\(level)")
                    .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: size, height: size)
                    .background(Circle().fill(band.tint))
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Level \(level), \(Rank.title(for: level))")
    }
}

/// Compact rank readout: level chip, title, and the bar to the next rung.
struct RankBar: View {
    let progress: RankProgress
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            RankMedallion(level: progress.level,
                          band: progress.band,
                          size: compact ? 38 : 46)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(progress.title.uppercased())
                        .font(.system(size: compact ? 10 : 11, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(progress.band.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if !compact {
                        Spacer(minLength: 0)
                        Text(progress.isMaxLevel
                             ? "MAX"
                             : "\(progress.xpIntoLevel.formatted())/\(progress.xpForNextLevel.formatted())")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .monospacedDigit()
                    }
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.45))
                        Capsule()
                            .fill(progress.band.tint)
                            .frame(width: max(3, g.size.width * progress.fraction))
                    }
                }
                .frame(height: compact ? 4 : 5)
            }
        }
    }
}

// MARK: - Level-up banner

/// Promotion celebration. Taps through to dismiss.
struct LevelUpBanner: View {
    let event: GameViewModel.LevelUp
    let onDismiss: () -> Void
    var onRealm: (() -> Void)? = nil

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                Text("PROMOTED")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.55))

                RankMedallion(level: event.level,
                              band: Rank.band(for: event.level),
                              size: 132)

                Text(event.title)
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .foregroundStyle(Rank.band(for: event.level).tint)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("LEVEL \(event.level)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))

                VStack(spacing: 6) {
                    reward("+\(event.credits.formatted()) credits")
                    if event.bonusSpins > 0 {
                        reward("+\(event.bonusSpins) guaranteed wins")
                    }
                    if let unlocked = event.unlocked {
                        reward("\(unlocked.displayName) unlocked")
                    }
                    if event.realmUpgrades.count == 1, let upgrade = event.realmUpgrades.first {
                        reward("Realm: \(upgrade.name) unlocked")
                    } else if event.realmUpgrades.count > 1 {
                        reward("\(event.realmUpgrades.count) Realm upgrades unlocked")
                    }
                }
                .padding(.top, 2)

                if !event.realmUpgrades.isEmpty, let onRealm {
                    Button {
                        onDismiss()
                        onRealm()
                    } label: {
                        Text(event.realmUpgrades.count == 1
                             ? "VIEW REALM UPGRADE"
                             : "VIEW \(event.realmUpgrades.count) REALM UPGRADES")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Rank.band(for: event.level).tint))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Text("TAP TO CONTINUE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.09, blue: 0.32),
                                                  Color(red: 0.10, green: 0.04, blue: 0.18)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Rank.band(for: event.level).tint, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.7), radius: 24, y: 10)
            .padding(.horizontal, 34)
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { shown = true }
        }
    }

    private func reward(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.10)))
    }
}

// MARK: - Timed collect

/// The return loop, as a button. Shows the payout when ready and a countdown when not.
struct CollectButton: View {
    let ready: Bool
    let amount: Int
    let countdown: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: ready ? "gift.fill" : "clock.fill")
                    .font(.system(size: 12, weight: .black))
                Text(ready ? "+\(amount.formatted())" : countdown)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(ready ? Color(red: 0.20, green: 0.06, blue: 0.28) : .white.opacity(0.5))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                Capsule().fill(ready
                               ? AnyShapeStyle(LobbyStyle.gold)
                               : AnyShapeStyle(Color.black.opacity(0.40)))
            )
            .overlay(
                Capsule().strokeBorder(ready ? .clear : .white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }
}
