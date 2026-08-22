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

    public static let household: [RealmUpgrade] = [
        .init(level: 11, name: "Courier Post",
              detail: "Messages finally travel farther than shouting distance.",
              assetName: "realm_11_courier_post", centerX: 0.44, centerY: 0.18, width: 0.16,
              replacesLevel: nil),
        .init(level: 12, name: "Torchlit Path",
              detail: "Two bright torches make the muddy road feel almost respectable.",
              assetName: "realm_12_torchlit_path", centerX: 0.49, centerY: 0.51, width: 0.22,
              replacesLevel: nil),
        .init(level: 13, name: "Cupbearer Fountain",
              detail: "Clean water arrives in a fountain shaped for a royal toast.",
              assetName: "realm_13_cupbearer_fountain", centerX: 0.49, centerY: 0.40, width: 0.16,
              replacesLevel: nil),
        .init(level: 14, name: "Page Noticeboard",
              detail: "Orders, errands, and suspiciously official notices gather here.",
              assetName: "realm_14_page_noticeboard", centerX: 0.14, centerY: 0.55, width: 0.16,
              replacesLevel: nil),
        .init(level: 15, name: "Footman Gate",
              detail: "A proper gate gives the growing settlement a proper entrance.",
              assetName: "realm_15_footman_gate", centerX: 0.50, centerY: 0.82, width: 0.25,
              replacesLevel: nil),
        .init(level: 16, name: "Castle Cookhouse",
              detail: "Warm bread and copper pots turn the camp into a household.",
              assetName: "realm_16_cookhouse", centerX: 0.14, centerY: 0.25, width: 0.23,
              replacesLevel: nil),
        .init(level: 17, name: "Village Brewery",
              detail: "Barrels, hops, and a reliable reason for everyone to visit.",
              assetName: "realm_17_brewery", centerX: 0.84, centerY: 0.39, width: 0.23,
              replacesLevel: nil),
        .init(level: 18, name: "Working Smithy",
              detail: "A glowing forge equips the realm with tools worthy of its ambition.",
              assetName: "realm_18_smithy", centerX: 0.65, centerY: 0.79, width: 0.23,
              replacesLevel: nil),
        .init(level: 19, name: "Falcon Mews",
              detail: "High perches welcome the realm's sharpest-eyed residents.",
              assetName: "realm_19_falcon_mews", centerX: 0.84, centerY: 0.18, width: 0.19,
              replacesLevel: nil),
        .init(level: 20, name: "Hunting Lodge",
              detail: "The apprentice cottage becomes a handsome lodge fit for the household.",
              assetName: "realm_20_hunting_lodge", centerX: 0.31, centerY: 0.62, width: 0.38,
              replacesLevel: 10),
    ]

    public static var all: [RealmUpgrade] { peasantry + household }
    public static func at(level: Int) -> RealmUpgrade? { all.first { $0.level == level } }
}
