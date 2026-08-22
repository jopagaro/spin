//
//  Realm.swift
//  RoyalSpin
//
//  The lightweight meta-game behind the reels. Rank earns permission to build;
//  credits pay for the construction. There are no production resources or timers.
//

import Foundation

public struct RealmState: Codable, Equatable, Sendable {
    public var completedLevels: Set<Int>

    public init(completedLevels: Set<Int> = [1]) {
        self.completedLevels = completedLevels.isEmpty ? [1] : completedLevels
    }

    public func isCompleted(_ level: Int) -> Bool { completedLevels.contains(level) }
}

public struct RealmUpgrade: Identifiable, Equatable, Sendable {
    public let level: Int
    public let name: String
    public let detail: String
    public let assetName: String
    /// Position and display width inside the square map, expressed from 0...1.
    public let centerX: Double
    public let centerY: Double
    public let width: Double
    /// An upgrade can replace an older sprite at the same plot.
    public let replacesLevel: Int?

    public var id: Int { level }
    public var rankTitle: String { Rank.title(for: level) }
    public var cost: Int { level == 1 ? 0 : XPCurve.levelReward(for: level) }

    public static let peasantry: [RealmUpgrade] = [
        .init(level: 1, name: "Peasant Hut",
              detail: "One crooked hut in a field of mud. Every empire starts somewhere.",
              assetName: "realm_01_peasant_hut", centerX: 0.31, centerY: 0.66, width: 0.25,
              replacesLevel: nil),
        .init(level: 2, name: "Grunt Camp",
              detail: "A proper fire, somewhere to sit, and just enough fence to feel official.",
              assetName: "realm_02_grunt_camp", centerX: 0.51, centerY: 0.69, width: 0.21,
              replacesLevel: nil),
        .init(level: 3, name: "Serf Garden",
              detail: "A tiny garden, a patched scarecrow, and the first signs of honest growth.",
              assetName: "realm_03_serf_garden", centerX: 0.20, centerY: 0.42, width: 0.24,
              replacesLevel: nil),
        .init(level: 4, name: "Mud Furrows",
              detail: "Drainage channels finally put all that mud to useful work.",
              assetName: "realm_04_mud_farmer_furrows", centerX: 0.54, centerY: 0.32, width: 0.27,
              replacesLevel: nil),
        .init(level: 5, name: "Washing Shelter",
              detail: "A humble shelter where the realm's pots can shine with pride.",
              assetName: "realm_05_pot_scrubber_wash", centerX: 0.39, centerY: 0.45, width: 0.19,
              replacesLevel: nil),
        .init(level: 6, name: "Shabby Stable",
              detail: "A warm roof for one scruffy pony and a pair of wandering chickens.",
              assetName: "realm_06_stable_hand_stable", centerX: 0.71, centerY: 0.28, width: 0.24,
              replacesLevel: nil),
        .init(level: 7, name: "Goose Pond",
              detail: "Four geese, a little bridge, and considerably more honking.",
              assetName: "realm_07_goose_herd_pond", centerX: 0.73, centerY: 0.53, width: 0.27,
              replacesLevel: nil),
        .init(level: 8, name: "Rookie Training Yard",
              detail: "Wooden weapons and battered shields for the realm's newest defenders.",
              assetName: "realm_08_rookie_training", centerX: 0.53, centerY: 0.59, width: 0.19,
              replacesLevel: nil),
        .init(level: 9, name: "Turnip Knight Post",
              detail: "A small guard post proudly watched over by one legendary turnip helmet.",
              assetName: "realm_09_turnip_knight_guard", centerX: 0.79, centerY: 0.69, width: 0.20,
              replacesLevel: nil),
        .init(level: 10, name: "Apprentice Cottage",
              detail: "The first hut becomes a sturdy cottage with a curious little workshop.",
              assetName: "realm_10_apprentice_cottage", centerX: 0.31, centerY: 0.64, width: 0.31,
              replacesLevel: 1),
    ]

    public static var all: [RealmUpgrade] { peasantry }
    public static func at(level: Int) -> RealmUpgrade? { all.first { $0.level == level } }
}
