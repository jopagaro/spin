//
//  Sheets.swift
//  RoyalSpin
//
//  Settings and paytable. The settings sheet deliberately exposes the volatility
//  and near-miss switches rather than hiding them — this is a toy, and letting the
//  player see the machine's guts is more interesting than pretending it's a sealed box.
//

import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Difficulty", selection: $game.volatility) {
                        ForEach(Volatility.allCases, id: \.self) { v in
                            Text(v.displayName).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(game.volatility.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent("Measured RTP", value: rtp)
                    LabeledContent("Wins on", value: hitRate)
                } header: {
                    Text("Volatility")
                } footer: {
                    Text("Return-to-player and hit frequency are separate settings. "
                         + "Royal Ruin returns the same percentage as Classic but pays "
                         + "less than half as often — the same money arrives in rarer, "
                         + "much larger wins.")
                }

                Section {
                    Toggle("Near misses", isOn: $game.teaseEnabled)
                } header: {
                    Text("Presentation")
                } footer: {
                    Text("Dresses up results so a symbol lands one row off the payline. "
                         + "This cannot change what you win: a nudged spin is only used "
                         + "if it pays exactly what the original did. Verified to zero "
                         + "difference in RTP by the test suite.")
                }

                Section {
                    Toggle("Sound", isOn: Binding(get: { !game.isMuted },
                                                  set: { game.isMuted = !$0 }))
                }

                Section {
                    Button("Reset credits to \(GameViewModel.startingCredits.formatted())") {
                        game.resetCredits()
                    }
                } footer: {
                    Text("Credits have no monetary value. There is nothing to buy and "
                         + "nothing to cash out — reset as often as you like.")
                }

                if SymbolArt.anyPlaceholders {
                    Section {
                        Label("Some symbols are placeholders", systemImage: "photo.badge.plus")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Drop artwork into Assets.xcassets to replace them. See ASSETS.md.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Figures from design/math.md, measured over 5M simulated spins per profile.
    private var rtp: String {
        switch game.volatility {
        case .gentle:  return "94.85%"
        case .classic: return "89.86%"
        case .brutal:  return "89.86%"
        }
    }

    private var hitRate: String {
        switch game.volatility {
        case .gentle:  return "1 spin in 2.8"
        case .classic: return "1 spin in 4.7"
        case .brutal:  return "1 spin in 11.4"
        }
    }
}

struct PaytableSheet: View {
    let volatility: Volatility
    let mode: ReelMode
    @Environment(\.dismiss) private var dismiss

    /// Which match lengths this machine can produce. Three reels can only ever
    /// match three, so showing a 4× and 5× column would be showing pays that are
    /// unreachable.
    private var matchCounts: [Int] { mode == .three ? [3] : [3, 4, 5] }

    /// High to low, so the sheet reads like a real paytable.
    private var ordered: [Symbol] {
        [.crown, .king, .queen, .prince, .princess, .knight,
         .joker, .sceptre, .chalice, .shield]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordered, id: \.self) { symbol in
                        HStack(spacing: 12) {
                            Image(uiImage: SymbolArt.image(for: symbol))
                                .resizable()
                                .frame(width: 42, height: 42)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(symbol.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                if symbol.isWild {
                                    Text("WILD — substitutes for all but the Seal")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                            }

                            Spacer()

                            HStack(spacing: 10) {
                                ForEach(matchCounts, id: \.self) { n in
                                    let pay = Paytable.linePay(symbol, count: n, volatility: volatility, mode: mode)
                                    VStack(spacing: 0) {
                                        Text("\(n)×")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                        Text(pay == 0 ? "—" : "\(pay)")
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundStyle(pay == 0 ? .secondary : .primary)
                                            .monospacedDigit()
                                    }
                                    .frame(minWidth: 34)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Line pays — \(volatility.displayName)")
                } footer: {
                    Text("Multiples of the per-line bet, for matches starting on reel 1 "
                         + "going left to right. A dash means that count doesn't pay on "
                         + "this difficulty — that's the main reason Royal Ruin hits so rarely.")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(uiImage: SymbolArt.image(for: .royalSeal))
                            .resizable().frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Royal Seal").font(.system(size: 15, weight: .semibold))
                            Text("SCATTER — pays from anywhere").font(.caption2).foregroundStyle(.orange)
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(matchCounts, id: \.self) { n in
                                VStack(spacing: 0) {
                                    Text("\(n)×").font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    let p = Paytable.scatterPay(count: n, volatility: volatility, mode: mode)
                                    Text(p == 0 ? "—" : "\(p)")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                }
                                .frame(minWidth: 34)
                            }
                        }
                    }
                    LabeledContent("3 Seals", value: "8 free spins")
                    LabeledContent("4 Seals", value: "12 free spins")
                    LabeledContent("5 Seals", value: "20 free spins")
                } header: {
                    Text("Scatter")
                } footer: {
                    Text("Scatter pays multiply your total bet, not the line bet, and "
                         + "ignore paylines entirely.")
                }

                Section {
                    LabeledContent("Paylines", value: "\(mode.lineCount)")
                    LabeledContent("Grid", value: "\(mode.reels) × \(Paylines.rows)")
                    LabeledContent("Reel strip length", value: "\(ReelStrips.strips[0].count) stops")
                } header: {
                    Text("Machine")
                } footer: {
                    Text("Stops are drawn independently per reel from a weighted virtual "
                         + "strip — the same technique as every commercial slot since the "
                         + "Telnaes patent in 1984.")
                }
            }
            .navigationTitle("Paytable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
