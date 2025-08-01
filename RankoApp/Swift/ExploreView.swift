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
    
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var toastID = UUID()

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
                if showToast {
                    ComingSoonToast(
                        isShown: $showToast,
                        title: "🚧 Features & Mini Games Coming Soon",
                        message: toastMessage,
                        icon: Image(systemName: "hourglass"),
                        alignment: .bottom
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toastID)
                    .padding(.bottom, 12)
                    .zIndex(1)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedGame) { game in
                destinationGameView(for: game.name)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastID)
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
                Button {
                    if showToast {
                        withAnimation {
                            showToast = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showComingSoonToast(for: item.title)
                        }
                    } else {
                        showComingSoonToast(for: item.title)
                    }
                } label: {
                    HStack {
                        Image(systemName: item.icon)
                            .font(.body).fontWeight(.bold)
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
                    Button {
                        if game.name == "Guessr" || game.name == "Outlier" || game.name == "More Coming Soon" {
                            if showToast {
                                withAnimation {
                                    showToast = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showComingSoonToast(for: game.name)
                                }
                            } else {
                                showComingSoonToast(for: game.name)
                            }
                        } else {
                            selectedGame = game
                        }
                    } label: {
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
    
    private func showComingSoonToast(for feature: String) {
        switch feature {
        case "Search Rankos":
                toastMessage = "Search and filter through all public Rankos from the community – Coming Soon!"
                toastID = UUID()
                showToast = true
                
            case "Blind Ranko":
                toastMessage = "Choose a category and rank random items one at a time without knowing what's next – Coming Soon!"
                toastID = UUID()
                showToast = true
                
            case "Store":
                toastMessage = "A future Store may let you trade in-game currency for items, themes, and app icons – Stay tuned!"
                toastID = UUID()
                showToast = true
                
            case "Random Picker":
                toastMessage = "Pick a category, set filters, and let Ranko choose random items for you – Coming Soon!"
                toastID = UUID()
                showToast = true
                
            case "Guessr":
                toastMessage = "Uncover clues, guess early, and score big – the Guessr mini-game is coming soon!"
                toastID = UUID()
                showToast = true
                
            case "Outlier":
                toastMessage = "Find the least popular answers and aim for the lowest score – Outlier is coming soon!"
                toastID = UUID()
                showToast = true
                
            case "More Coming Soon":
                toastMessage = "More features and exciting mini-games are on the way – stay tuned!"
                toastID = UUID()
                showToast = true
                
            default:
                toastMessage = "New Feature Coming Soon!"
                toastID = UUID()
                showToast = true
            }
        
        // Cancel any previous dismiss
        toastDismissWorkItem?.cancel()
        
        // Schedule dismiss after 4 seconds
        let newDismissWorkItem = DispatchWorkItem {
            withAnimation { showToast = false }
        }
        toastDismissWorkItem = newDismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: newDismissWorkItem)
    }

    private func destinationGameView(for item: String) -> some View {
        switch item {
        case "Blind Sequence":
            return AnyView(BlindSequence())
        case "Guessr":
            return AnyView(BlindSequence())
        case "Outlier":
            return AnyView(BlindSequence())
        default:
            return AnyView(BlindSequence())
        }
    }

    // MARK: – Helper
    private func showComingSoon() {
        showComingSoonBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showComingSoonBanner = false
        }
    }
}

struct ComingSoonToast: View {
    @Binding var isShown: Bool
    var title: String? = "Coming Soon"
    var message: String = "New Feature Coming Soon!"
    var icon: Image = Image(systemName: "hourglass")
    var alignment: Alignment = .top

    var body: some View {
        VStack {
            if isShown {
                content
                    .transition(.move(edge: alignmentToEdge(self.alignment)).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: isShown)
                Rectangle()
                    .fill(.clear)
                    .frame(height: 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                icon
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(hex: 0x857467))
                VStack(alignment: .leading, spacing: 7) {
                    if let title {
                        Text(title)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                    }
                    Text(message.capitalized)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Color(hex: 0x857467))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }

    private func alignmentToEdge(_ alignment: Alignment) -> Edge {
        switch alignment {
        case .top, .topLeading, .topTrailing: return .top
        case .bottom, .bottomLeading, .bottomTrailing: return .bottom
        default: return .top
        }
    }
}
