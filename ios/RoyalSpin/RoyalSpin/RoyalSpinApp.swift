//
//  RoyalSpinApp.swift
//  RoyalSpin
//

import SwiftUI

@main
struct RoyalSpinApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The reels are the whole screen; a status bar over them looks wrong
                // and portrait-only keeps the 5×3 grid at a readable size.
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
