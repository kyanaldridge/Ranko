//
//  Navigation.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import UIKit
import FirebaseAnalytics

// MARK: - Main Tab-based Navigation Layout
struct MainTabView: View {
    
    @State private var activeTab: TabModel = .explore
    @State private var navigationBar: Int = 1
    
    var body: some View {
        if navigationBar == 0 {
            ZStack(alignment: .bottom) {
                Group {
                    switch activeTab {
                    case .home:
                        HomeView()
                    case .explore:
                        ExploreView()
                    case .profile:
                        ProfileView()
                    case .settings:
                        SettingsView()
                    }
                }
                CustomTabBar(activeTab: $activeTab)
            }
            .ignoresSafeArea()
        } else if navigationBar == 1 {
            ZStack(alignment: .bottom) {
                Group {
                    switch activeTab {
                    case .home:
                        HomeView()
                    case .explore:
                        ExploreView()
                    case .profile:
                        ProfileView()
                    case .settings:
                        SettingsView()
                    }
                }
                .ignoresSafeArea(.all)
                CurvedTabBarView(activeTab: $activeTab)
            }
        } else if navigationBar == 2 {
            
        }
        
    }
}


struct CurvedTabBarShape: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        let height: CGFloat = 37.0
        let depth: CGFloat = height * 1.2  // Increase depth here
        let path = UIBezierPath()
        let centerWidth = rect.width / 2
        
        path.move(to: CGPoint(x: 0, y: 0)) // start top left
        path.addLine(to: CGPoint(x: (centerWidth - height * 2), y: 0)) // start of curve
        
        // First half of the dip
        path.addCurve(
            to: CGPoint(x: centerWidth, y: depth), // deeper dip
            controlPoint1: CGPoint(x: (centerWidth - 30), y: 0),
            controlPoint2: CGPoint(x: centerWidth - 35, y: depth)
        )
        
        // Second half of the dip
        path.addCurve(
            to: CGPoint(x: (centerWidth + height * 2), y: 0),
            controlPoint1: CGPoint(x: centerWidth + 40, y: depth),
            controlPoint2: CGPoint(x: (centerWidth + 25), y: 0)
        )
        
        path.addLine(to: CGPoint(x: rect.width, y: 0)) // finish top edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height)) // down right
        path.addLine(to: CGPoint(x: 0, y: rect.height)) // down left
        path.close()

        return Path(path.cgPath)
    }
}

struct CurvedTabBarView: View {
    let activeTab: Binding<TabModel>
    @State private var currentView: AnyView? = nil
    @State private var showCreateSheet = false
    @State private var showOverlay = false

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                ZStack {
                    CurvedTabBarShape()
                        .fill(.white)
                        .frame(height: 80)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                        )
                        .shadow(color: Color(hex: 0xE7DBCB), radius: 10)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .blur(radius: 14, opaque: false)
                                .offset(y: -26)
                        }

                    HStack {
                        ForEach(TabModel.allCases, id: \.rawValue) { tab in
                            tabButton(icon: tab.rawValue, tab: tab)
                            if tab != TabModel.allCases.last {
                                if tab == TabModel.allCases[1] {
                                    Spacer().frame(width: 80)
                                } else {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    
                    Button {
                        withAnimation {
                            showOverlay = true
                        }
                        showCreateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .heavy))
                        }
                        .frame(width: 30, height: 30)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 3)
                    }
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF9864), Color(hex: 0xFCB34D)]),
                                               startPoint: .top,
                                               endPoint: .bottom
                                )
                            )
                    )
                    .tint(Color(hex: 0xFF9864))
                    .buttonStyle(.glassProminent)
                    .offset(y: -32)

                    Button {
                        withAnimation {
                            showCreateSheet = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .heavy))
                        }
                        .frame(width: 30, height: 30)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 3)
                    }
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF9864), Color(hex: 0xFCB34D)]),
                                               startPoint: .top,
                                               endPoint: .bottom
                                )
                            )
                    )
                    .tint(Color(hex: 0xFF9864))
                    .buttonStyle(.glassProminent)
                    .offset(y: -32)
                }
            }
            if showCreateSheet {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showCreateSheet, onDismiss: {
            withAnimation {
                showCreateSheet = false
            }
        }) {
            AnyView(
                ZStack(alignment: .bottom) {
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
            .presentationBackgroundInteraction(.enabled)
        }
        .ignoresSafeArea(.keyboard)
        .edgesIgnoringSafeArea(.all)
    }

    private func tabButton(icon: String, tab: TabModel) -> some View {
        Button(action: {
            activeTab.wrappedValue = tab
        }) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(activeTab.wrappedValue == tab ? Color(hex: 0xCD612C) : Color(hex: 0x857467))
                .frame(maxWidth: .infinity)
        }
    }
}

/// The custom tab bar with a matched geometry effect.
struct CustomTabBar: View {
    @State private var trayViewOpen: Bool
    // Use the same stored string for the tint.
    @AppStorage("app_colour") private var appColourString: String = ".orange"
    @StateObject private var user_data = UserInformation.shared
    var activeForeground: Color = .white

    @Binding var activeTab: TabModel
    @Namespace private var animation
    @State private var tabLocation: CGRect = .zero
    
    init(trayViewOpen: Bool = false, activeTab: Binding<TabModel>) {
        self._trayViewOpen = State(initialValue: trayViewOpen)
        self._activeTab   = activeTab
    }
    

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(TabModel.allCases, id: \.rawValue) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.rawValue)
                                .font(.title3)
                                .frame(width: 30, height: 30)
                            
                            if activeTab == tab {
                                Text(tab.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(activeTab == tab ? activeForeground : Color(hex: 0xFF9864))
                        .padding(.vertical, 2)
                        .padding(.leading, 10)
                        .padding(.trailing, 15)
                        .contentShape(Rectangle())
                        .background {
                            if activeTab == tab {
                                Capsule()
                                    .fill(Color.clear)
                                    .onGeometryChange(for: CGRect.self, of: {
                                        $0.frame(in: .named("TABBARVIEW"))
                                    }, action: { newValue in
                                        tabLocation = newValue
                                    })
                                    .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: 0xFF9864).gradient)
                    .frame(width: tabLocation.width, height: tabLocation.height)
                    .offset(x: tabLocation.minX)
            }
            .coordinateSpace(name: "TABBARVIEW")
            .padding(.horizontal, 5)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 5, y: 5)
                    .shadow(color: Color.black.opacity(0.06), radius: 5, x: -5, y: -5)
            )
            .zIndex(10)
            
            Button {
                trayViewOpen.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
                    .accentColor(.white)
                    .background(Color(hex: 0xFF9864).gradient)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 5)
            }
            .padding(.leading, 0)
        }
        .systemTrayView($trayViewOpen) {
            CreateNewRanko()
        }
        .padding(.bottom, 10)
        .animation(.smooth(duration: 0.3, extraBounce: 0), value: activeTab)
        .frame(maxWidth: .infinity)
    }
}


struct CreateRankoView: View {
    @State private var listCreatorSheet: Bool = false
    
    var body: some View {
        HomeView()
            .sheet(isPresented: $listCreatorSheet) {
                CreateNewRanko()
                    .presentationDetents([.medium, .large]) // ✅ Detents must be attached here
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                listCreatorSheet = true
            }
    }
}

/// Tab identifiers and titles.
enum TabModel: String, CaseIterable {
    case home = "house.fill"
    case explore = "safari.fill"
    case profile = "person.fill"
    case settings = "gearshape.fill"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }
}

#Preview {
    MainTabView()
}

// MARK: - Supporting Views & Models

/// A helper view to hide the tab bar on iOS 17 devices.
struct HideTabBar: UIViewRepresentable {
    init(result: @escaping () -> Void) {
        UITabBar.appearance().isHidden = true
        self.result = result
    }
    
    var result: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let tabController = view.tabController {
                UITabBar.appearance().isHidden = false
                tabController.tabBar.isHidden = true
                result()
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
}

extension UIView {
    var tabController: UITabBarController? {
        sequence(first: self, next: { $0.next })
            .first(where: { $0 is UITabBarController }) as? UITabBarController
    }
}



/// A custom view that morphs between symbols (requires KeyframeAnimator and CubicKeyframe implementations).
struct MorphingSymbolView: View {
    var symbol: String
    var config: Config
    
    @State private var trigger: Bool = false
    @State private var displayingSymbol: String = ""
    @State private var nextSymbol: String = ""
    
    var body: some View {
        Canvas { ctx, size in
            ctx.addFilter(.alphaThreshold(min: 0.4, color: config.foregroundColor))
            if let renderedImage = ctx.resolveSymbol(id: 0) {
                ctx.draw(renderedImage, at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            ImageView()
                .tag(0)
        }
        .frame(width: config.frame.width, height: config.frame.height)
        .onChange(of: symbol) { _, newValue in
            trigger.toggle()
            nextSymbol = newValue
        }
        .task {
            if displayingSymbol.isEmpty {
                displayingSymbol = symbol
            }
        }
    }
    
    @ViewBuilder
    func ImageView() -> some View {
        KeyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { radius in
            Image(systemName: displayingSymbol.isEmpty ? symbol : displayingSymbol)
                .font(config.font)
                .blur(radius: radius)
                .frame(width: config.frame.width, height: config.frame.height)
                .onChange(of: radius) { _, newValue in
                    if newValue.rounded() == config.radius {
                        withAnimation(config.symbolAnimation) {
                            displayingSymbol = nextSymbol
                        }
                    }
                }
        } keyframes: { _ in
            CubicKeyframe(config.radius, duration: config.keyFrameDuration)
            CubicKeyframe(0, duration: config.keyFrameDuration)
        }
    }
    
    struct Config {
        var font: Font
        var frame: CGSize
        var radius: CGFloat
        var foregroundColor: Color
        var keyFrameDuration: CGFloat = 0.4
        var symbolAnimation: Animation = .smooth(duration: 0.5, extraBounce: 0)
    }
}

