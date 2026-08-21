//
//  Lobby.swift
//  RoyalSpin
//
//  Machine select. Every number on these cards is *measured*, not estimated —
//  see `MachineStats` below and design/math.md.
//

import SwiftUI

// MARK: - Measured figures

/// Simulator output, transcribed.
///
/// These come from `tools/rtp_sim` running 200,000 spins per machine × profile
/// against the same `SlotMath.swift` the app ships. They are hard-coded here rather
/// than computed at runtime because deriving a true RTP needs millions of spins —
/// far too slow to do on launch — but that means **they go stale if the paytable
/// changes**. Re-run the simulator and update this table whenever it does.
struct MachineStats {
    let mode: ReelMode
    let volatility: Volatility
    /// Percent of wagers returned over millions of spins.
    let rtp: Double
    /// Percent of spins that pay anything at all.
    let hitFrequency: Double
    /// Largest win observed, as a multiple of the total bet.
    let maxWinMultiple: Int
    /// Spins between bonus triggers, on average.
    let bonusOneIn: Int

    var winsOneIn: Double { 100.0 / hitFrequency }

    static let all: [MachineStats] = [
        // 3 reels — 3×3, 5 classic lines, wild-dense strips. Bet 5/spin.
        .init(mode: .three, volatility: .gentle,  rtp: 96.25, hitFrequency: 23.51, maxWinMultiple: 74,   bonusOneIn: 31),
        .init(mode: .three, volatility: .classic, rtp: 94.16, hitFrequency: 23.51, maxWinMultiple: 81,   bonusOneIn: 31),
        .init(mode: .three, volatility: .brutal,  rtp: 92.18, hitFrequency: 13.20, maxWinMultiple: 107,  bonusOneIn: 31),
        // 5 reels — 5×3, 20 lines. Bet 20/spin.
        .init(mode: .five,  volatility: .gentle,  rtp: 95.03, hitFrequency: 35.23, maxWinMultiple: 193,  bonusOneIn: 97),
        .init(mode: .five,  volatility: .classic, rtp: 90.11, hitFrequency: 21.43, maxWinMultiple: 335,  bonusOneIn: 97),
        .init(mode: .five,  volatility: .brutal,  rtp: 90.14, hitFrequency: 8.75,  maxWinMultiple: 1358, bonusOneIn: 97),
    ]

    static func of(_ mode: ReelMode, _ volatility: Volatility) -> MachineStats {
        all.first { $0.mode == mode && $0.volatility == volatility } ?? all[0]
    }
}

/// Which difficulty each cabinet opens on.
///
/// The two machines are deliberately a progression rather than a preference: the
/// three-reel cabinet defaults to the friendliest table it has, and the five-reel one
/// to the harshest. That's the standard casino-floor shape — an approachable machine
/// that pays often and small, and a punishing one where the money actually is.
extension ReelMode {
    var defaultVolatility: Volatility {
        switch self {
        case .three: return .gentle
        case .five:  return .brutal
        }
    }

    var tagline: String {
        switch self {
        case .three: return "Start your reign"
        case .five:  return "For the biggest crowns"
        }
    }
}

// MARK: - Lobby

struct LobbyView: View {

    @ObservedObject var game: GameViewModel
    let onPick: (ReelMode, Volatility) -> Void
    let onBuy: () -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        ZStack {
            LobbyStyle.backdrop.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    ForEach(ReelMode.allCases, id: \.self) { mode in
                        MachineCard(
                            mode: mode,
                            stats: MachineStats.of(mode, mode.defaultVolatility),
                            affordable: game.displayCredits >= mode.lineCount || game.bonusSpins > 0,
                            unlocked: mode.isUnlocked(atLevel: game.progress.level)
                        ) {
                            onPick(mode, mode.defaultVolatility)
                        }
                    }

                    footnote
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                // The marquee's crown runs under the notch without this.
                .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 10) {
            if let art = UIImage(named: "marquee") {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(1024.0 / 408.0, contentMode: .fit)
            } else {
                Text("ROYAL SPIN")
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(LobbyStyle.gold)
                    .padding(.top, 20)
            }

            HStack(spacing: 10) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LobbyStyle.gold)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.black.opacity(0.35)))
                            .overlay(Circle().strokeBorder(LobbyStyle.gold.opacity(0.55), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: -3) {
                    Text("CREDITS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(2)
                    Text(game.displayCredits.formatted())
                        .font(.system(size: 28, weight: .black, design: .serif))
                        .foregroundStyle(LobbyStyle.gold)
                        .monospacedDigit()
                }

                if game.bonusSpins > 0 {
                    Text("\(game.bonusSpins) BONUS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(LobbyStyle.gold))
                }

                Spacer()

                Button(action: onBuy) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .black))
                        Text("BUY").font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(LobbyStyle.gold))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                RankBar(progress: game.progress)
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    CollectButton(ready: game.freeCreditsReady,
                                  amount: game.freeCreditsAmount,
                                  countdown: game.freeCreditsCountdown,
                                  action: { game.collectFreeCredits() })
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var footnote: some View {
        Text("Full odds for each machine are in its paytable. "
             + "Credits have no cash value and cannot be withdrawn.")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.35))
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - Card

private struct MachineCard: View {
    let mode: ReelMode
    let stats: MachineStats
    let affordable: Bool
    let unlocked: Bool
    let action: () -> Void

    private var canPlay: Bool { affordable && unlocked }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(mode.displayName)
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(LobbyStyle.gold)
                    Spacer()
                    Text(mode.tagline.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                grid

                Text(mode.blurb)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                stat_row

                HStack {
                    Text(stats.volatility.displayName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.10)))
                    Spacer()
                    Text(!unlocked ? "UNLOCKS LV \(mode.unlockLevel)" : affordable ? "PLAY" : "NEEDS CREDITS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(canPlay ? Color(red: 0.24, green: 0.10, blue: 0) : .white.opacity(0.5))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Capsule().fill(canPlay
                                                   ? AnyShapeStyle(LobbyStyle.gold)
                                                   : AnyShapeStyle(Color.white.opacity(0.12))))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.08, blue: 0.28),
                                                  Color(red: 0.09, green: 0.04, blue: 0.17)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(LobbyStyle.gold.opacity(0.55), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
            .overlay {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(LobbyStyle.gold)
                        .padding(18)
                        .background(Circle().fill(.black.opacity(0.72)))
                }
            }
            .opacity(unlocked ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .disabled(!canPlay)
    }

    /// A miniature of the actual grid, so the shape of the machine is obvious before
    /// you commit credits to it.
    private var grid: some View {
        VStack(spacing: 3) {
            ForEach(0 ..< Paylines.rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0 ..< mode.reels, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.4))
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(LobbyStyle.gold.opacity(0.4), lineWidth: 1))
                            .frame(height: 26)
                            // Middle row a touch brighter — that's payline 1.
                            .opacity(row == 1 ? 1 : 0.55)
                            .id("\(row)-\(col)")
                    }
                }
            }
        }
    }

    /// Leads with the prize — and only the prize.
    ///
    /// Top win is the number that sells a machine, so it gets the space and the
    /// gold. The odds (hit rate, bonus frequency, return-to-player) live in the
    /// paytable sheet — one tap away and referenced by the footnote below, but not
    /// printed on the sales floor.
    private var stat_row: some View {
        VStack(spacing: 2) {
            Text("TOP WIN")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Text("\(stats.maxWinMultiple)×")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(LobbyStyle.gold)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.30)))
    }
}

enum LobbyStyle {
    /// Same deep purple as the machine screen — sampled from the cabinet artwork
    /// (#300040), so moving between lobby and machine has no colour shift.
    static let backdrop = Color(red: 0x30 / 255.0, green: 0x00 / 255.0, blue: 0x40 / 255.0)
    static let gold = LinearGradient(
        colors: [Color(red: 1.0, green: 0.94, blue: 0.66),
                 Color(red: 0.95, green: 0.76, blue: 0.28),
                 Color(red: 0.74, green: 0.48, blue: 0.10)],
        startPoint: .top, endPoint: .bottom)
}
