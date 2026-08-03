//
//  Welcome.swift
//  RoyalSpin
//
//  First screen. One job: get the player spinning.
//
//  The design follows what the genre's best onboarding actually does rather than
//  what a settings-shaped mind would build. Clash Royale drops you into a match
//  almost immediately; Candy Crush spends its first levels teaching through play.
//  The common thread is *do, don't choose* — so PLAY goes straight into the starter
//  machine with bonus spins already banked, and picking a machine is a secondary
//  link for players who want it. Asking someone to compare two cabinets before
//  they've ever spun is asking for a decision they have no basis to make.
//

import SwiftUI

struct WelcomeView: View {

    let onPlay: () -> Void
    let onChooseMachine: () -> Void

    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LobbyStyle.backdrop.ignoresSafeArea()

                // Full-bleed key art when it exists, so the screen is the artwork
                // rather than a small image floating in empty colour.
                if let art = UIImage(named: "bg_welcome") {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    LinearGradient(colors: [.clear, LobbyStyle.backdrop.opacity(0.95)],
                                   startPoint: .center, endPoint: .bottom)
                        .ignoresSafeArea()
                }

                // One centred block. Everything used to be pinned apart by large
                // spacers, which left gaps in the middle and read as a half-loaded
                // screen.
                VStack(spacing: 0) {
                    Spacer()

                    if UIImage(named: "bg_welcome") == nil {
                        hero(width: geo.size.width)
                        Spacer().frame(height: 34)
                    }

                    playButton
                        .padding(.horizontal, 30)

                    Button(action: onChooseMachine) {
                        Text("Choose a machine")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 16)
                    }
                    .buttonStyle(.plain)

                    Text("Free to play · credits have no cash value")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.30))
                        .padding(.top, 10)

                    Spacer()
                }
                .padding(.bottom, geo.size.height * 0.04)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    // MARK: Hero

    /// Fallback wordmark, used until `bg_welcome.png` is dropped into
    /// art/masters/scene/ and tools/install_art.py is re-run.
    @ViewBuilder
    private func hero(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            if let m = UIImage(named: "marquee") {
                Image(uiImage: m)
                    .resizable()
                    .aspectRatio(1024.0 / 408.0, contentMode: .fit)
                    .frame(maxWidth: width * 0.96)
            } else {
                Text("ROYAL SPIN")
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .foregroundStyle(LobbyStyle.gold)
            }

            Text("Take the throne.")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    // MARK: Pieces

    private var playButton: some View {
        Button(action: onPlay) {
            Text("PLAY")
                .font(.system(size: 27, weight: .black, design: .serif))
                .tracking(2)
                .foregroundStyle(Color(red: 0.20, green: 0.06, blue: 0.28))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(Capsule().fill(LobbyStyle.gold))
                .overlay(
                    Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                .scaleEffect(shimmer ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
