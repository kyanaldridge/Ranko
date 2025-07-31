//
//  ExploreView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import FirebaseAnalytics

struct MiniGameEntry: Identifiable {
    let id = UUID()
    let name: String
    let image: String
}

struct MenuItemButtons: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct ExploreView: View {
    // MARK: – Data
    let menuItems: [MenuItemButtons] = [
        .init(title: "Search Rankos", icon: "magnifyingglass"),
        .init(title: "Blind Ranko",     icon: "sunglasses.fill"),
        .init(title: "Store",           icon: "storefront.fill"),
        .init(title: "Random Picker",   icon: "dice.fill")
    ]

    let miniGames: [MiniGameEntry] = [
        .init(name: "Blind Sequence", image: "BlindSequence"),
        .init(name: "Guessr", image: "Guessr"),
        .init(name: "Outlier", image: "Outlier"),
        .init(name: "More Coming Soon", image: "ComingSoon")
    ]

    // MARK: – State
    @State private var selectedGame: MiniGameEntry? = nil
    @State private var showComingSoonBanner = false
    @State private var profileImage: UIImage?

    // MARK: – Body
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xDBC252), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864)]),
                               startPoint: .top,
                               endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Header
                        HStack {
                            Text("Explore")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                            Spacer()
                            ProfileIconView(size: CGFloat(50))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 30)
                        VStack {
                            topMenu
                            miniGamesSection
                            Spacer(minLength: 400)
                        }
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                                                   startPoint: .top,
                                                   endPoint: .bottom
                                                  )
                                )
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedGame) { game in
                destinationGameView(for: game.name)
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "Explore",
                AnalyticsParameterScreenClass: "ExploreView"
            ])
        }
    }

    // MARK: – Subviews

    private var topMenu: some View {
        FlowLayout(spacing: 8) {
            ForEach(menuItems) { item in
                Button(action: {showComingSoon()}) {
                    HStack {
                        Image(systemName: item.icon)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: 0xCD612C))
                        Text(item.title)
                            .font(.caption).fontWeight(.heavy)
                            .foregroundColor(Color(hex: 0x857467))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                }
                .foregroundColor(Color(hex: 0xFF9864))
                .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                     startPoint: .top,
                                     endPoint: .bottom
                                    ))
                .buttonStyle(.glassProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var miniGamesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mini Games")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(Color(hex: 0x857467))
                .padding([.top, .bottom])
                .padding(.leading, 25)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]) {
                ForEach(miniGames) { game in
                    Button(action: { selectedGame = game }) {
                        VStack(spacing: 12) {
                            Image(game.image)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .padding(.horizontal, 40)
                                .padding(.vertical, -20)
                            Text(game.name)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(Color(hex: 0x857467))
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.vertical)
                    }
                    .foregroundColor(Color(hex: 0xFF9864))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func destinationGameView(for item: String) -> some View {
        switch item {
        case "Blind Sequence":
            return AnyView(BlindSequence())
        case "Guessr":
            return AnyView(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    GuessrPlaceholderView()
                        .shadow(radius: 10)
                }
                )
        case "Outlier":
            return AnyView(
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        CreateNewRanko()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white)
                            )
                            .padding(.horizontal, 15)
                            .padding(.bottom, 2)
                    }
                }
            )
        default:
            return AnyView(Text("Game Not Found"))
        }
    }

    // MARK: – Helper
    private func showComingSoon() {
        showComingSoonBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showComingSoonBanner = false
        }
    }
    
    struct GuessrPlaceholderView: View {
        @Environment(\.dismiss) var dismiss

        var body: some View {
            VStack(alignment: .center) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                        print("Editing Profile...")
                    } label: {
                        Image(systemName: "person.crop.badge.magnifyingglass.fill")
                            .fontWeight(.semibold)
                            .padding(.vertical, 2)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .buttonStyle(.glassProminent)
                }
                Spacer()
                HStack {
                    Spacer()
                    Text("Guessr Coming Soon")
                    Spacer()
                }
                Spacer()
            }
            .background(RoundedRectangle(cornerRadius: 7).fill(.white))
            .padding()
        }
    }
}
