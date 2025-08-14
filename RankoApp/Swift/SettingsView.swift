//
//  SettingsView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import InstantSearchCore
import StoreKit
import FirebaseAnalytics

struct SettingItem: Identifiable {
    let id = UUID()
    let variable: String
    let title: String
    let icon: String
    let keywords: [String]
}

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview
    
    @StateObject private var user_data = UserInformation.shared
    // Store the tint as a String value (note the dot prefix to match our mapping below)
    @State private var rankoProView: Bool
    @State private var accountView: Bool = false
    @State private var notificationsView: Bool = false
    @State private var preferencesView: Bool = false
    @State private var privacySecurityView: Bool = false
    @State private var suggestionsIdeasView: Bool = false
    @State private var dataStorageView: Bool = false
    @State private var aboutView: Bool = false
    @State private var legalView: Bool = false
    
    @State private var searchText: String = ""
    @State private var activeSheet: SettingItem? = nil
    
    init(rankoProView: Bool = false) {
        self._rankoProView = State(initialValue: rankoProView)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xDBC252), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864)]),
                               startPoint: .top,
                               endPoint: .bottom
                )
                .ignoresSafeArea()
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            // MARK: - Header
                            HStack {
                                Text("Settings")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                Spacer()
                                // Profile Picture
                                ProfileIconView(diameter: CGFloat(50))
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 30)
                            VStack(spacing: 0) {
                                // Search Bar
                                
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                                        .padding(6)
                                    TextField("Search Settings", text: $searchText)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                                    Spacer()
                                    if !searchText.isEmpty {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                                            .onTapGesture {searchText = ""}
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            ))
                                        .shadow(color: Color(hex: 0xDBC252).opacity(0.8), radius: 5, x: 0, y: 3)
                                        .padding(8)
                                )
                                .cornerRadius(12)
                                .padding(.horizontal, 10)
                                .padding(.top, 5)
                                .padding(.bottom, 10)
                                
                                // Animated settings list wrapped in animation for searchText changes
                                VStack(spacing: 0) {
                                    if matchingSettings.isEmpty {
                                        VStack(spacing: 18) {
                                            Image(systemName: "questionmark.circle.fill")
                                                .font(.system(size: 120, weight: .heavy))
                                                .foregroundColor(Color(hex: 0x7E5F46).opacity(0.3))
                                                .padding(.top, 40)
                                            Text("No Settings Found")
                                                .font(.system(size: 20, weight: .heavy))
                                                .foregroundColor(Color(hex: 0x7E5F46))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 30)
                                        .transition(.opacity)
                                    } else {
                                        ForEach(matchingSettings) { setting in
                                            Button {
                                                switch setting.title {
                                                case "Account":
                                                    accountView = true
                                                case "Ranko Pro":
                                                    rankoProView = true
                                                case "Notifications":
                                                    notificationsView = true
                                                case "Preferences":
                                                    preferencesView = true
                                                case "Privacy & Security":
                                                    privacySecurityView = true
                                                case "Please Leave Us A Review":
                                                    requestReview()
                                                case "Suggestions & Ideas":
                                                    suggestionsIdeasView = true
                                                case "Data & Storage":
                                                    dataStorageView = true
                                                case "About":
                                                    aboutView = true
                                                case "Privacy Policy & Terms Of Use":
                                                    legalView = true
                                                default:
                                                    break
                                                }
                                            } label: {
                                                HStack(spacing: 14) {
                                                    Image(systemName: setting.icon)
                                                        .font(.system(size: 20, weight: .black))
                                                        .foregroundColor(Color(hex: 0x7E5F46))
                                                        .frame(width: 32)
                                                    Text(setting.title)
                                                        .font(.system(size: 14, weight: .black))
                                                        .foregroundColor(Color(hex: 0x7E5F46))
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 16, weight: .black))
                                                        .foregroundColor(Color(hex: 0x7E5F46))
                                                }
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 16)
                                            }
                                            .foregroundColor(Color(hex: 0xFF9864))
                                            .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                                 startPoint: .top,
                                                                 endPoint: .bottom
                                                                ))
                                            .buttonStyle(.glassProminent)
                                            .id(setting.id)
                                            .background(Color.clear)
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.35), value: matchingSettings.count)
                                        }
                                        .padding(.horizontal, 15)
                                        .padding(.top, 6)
                                    }
                                    // Non-matching settings fade out and collapse
                                    ForEach(nonMatchingSettings) { setting in
                                        Button {
                                            // Do nothing on tap for non-matching, invisible items
                                        } label: {
                                            HStack(spacing: 14) {
                                                Image(systemName: setting.icon)
                                                    .font(.system(size: 20, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                    .frame(width: 32)
                                                Text(setting.title)
                                                    .font(.system(size: 14, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 16, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                            }
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 8)
                                        }
                                        .id(setting.id)
                                        .background(Color.clear)
                                        .opacity(0)
                                        .frame(height: 0)
                                        .animation(.easeInOut(duration: 0.35), value: searchText)
                                    }
                                }
                                .padding(.vertical, 5)
                                .animation(.easeInOut(duration: 0.35), value: searchText)
                                .cornerRadius(16)
                                .sheet(item: $activeSheet) { setting in
                                    VStack {
                                        Text(setting.title)
                                            .font(.title)
                                            .padding()
                                        Spacer()
                                        Text("This is a placeholder for \(setting.title) settings.")
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                }
                                Spacer()
                            }
                            .padding(.bottom, 80)
                            .frame(minHeight: geo.size.height)
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
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "Settings",
                AnalyticsParameterScreenClass: "SettingsView"
            ])
        }
        .sheet(isPresented: $accountView) {
            AccountView()
        }
        .sheet(isPresented: $rankoProView) {
            ProSubscriptionView()
        }
        .sheet(isPresented: $notificationsView) {
            NotificationsView()
        }
        .sheet(isPresented: $preferencesView) {
            PreferencesView()
        }
        .sheet(isPresented: $privacySecurityView) {
            PrivacySecurityView()
        }
        .sheet(isPresented: $suggestionsIdeasView) {
            SuggestionsIdeasView()
        }
        .sheet(isPresented: $dataStorageView) {
            DataStorageView()
        }
        .sheet(isPresented: $aboutView) {
            AboutView()
        }
        .sheet(isPresented: $legalView) {
            LegalView()
        }
        
    }
    
    // Example settings with keywords
    private var settings: [SettingItem] {
        [
            SettingItem(variable: "account", title: "Account", icon: "person.crop.circle", keywords: ["account", "profile", "sign in", "sign out", "user", "login", "logout"]),
            SettingItem(variable: "rankoPro", title: "Ranko Pro", icon: "medal.star", keywords: ["ranko", "pro", "premium"]),
            SettingItem(variable: "notifications", title: "Notifications", icon: "bell.badge", keywords: ["notification", "alerts", "reminders", "push", "messages"]),
            SettingItem(variable: "preferences", title: "Preferences", icon: "wrench.and.screwdriver", keywords: ["preferences", "alerts", "reminders", "push", "messages"]),
            SettingItem(variable: "privacy", title: "Privacy & Security", icon: "lock.shield", keywords: ["privacy", "security", "password", "passcode", "auth", "protection"]),
            SettingItem(variable: "review", title: "Please Leave Us A Review", icon: "star.fill", keywords: ["Review"]),
            SettingItem(variable: "suggestions", title: "Suggestions & Ideas", icon: "brain.head.profile.fill", keywords: ["suggestions", "ideas", "help", "contact", "feedback"]),
            SettingItem(variable: "dataStorage", title: "Data & Storage", icon: "externaldrive", keywords: ["data", "storage", "cache", "clear", "reset"]),
            SettingItem(variable: "about", title: "About", icon: "info.circle", keywords: ["about", "info", "version", "app", "credits"]),
            SettingItem(variable: "legal", title: "Privacy Policy & Terms Of Use", icon: "scroll", keywords: ["privacy policy", "terms of use", "legal"])
        ]
    }
    
    // Filtering logic to get matching settings
    private var matchingSettings: [SettingItem] {
        if searchText.isEmpty { return settings }
        let lowercased = searchText.lowercased()
        return settings.filter { setting in
            setting.title.lowercased().contains(lowercased) ||
            setting.keywords.contains(where: { $0.contains(lowercased) })
        }
    }
    
    // Filtering logic to get non-matching settings
    private var nonMatchingSettings: [SettingItem] {
        let lowercased = searchText.lowercased()
        if lowercased.isEmpty { return [] }
        return settings.filter { setting in
            !(setting.title.lowercased().contains(lowercased) ||
            setting.keywords.contains(where: { $0.contains(lowercased) })) }
    }
    
    private func clearAllCache() {
        // 1. Remove URLCache entries
        let urlCache = URLCache.shared
        urlCache.removeAllCachedResponses()
        
        // 2. Reset its capacities
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        
        // 3. Clear out everything in Caches directory
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: cachesURL,
                                                                           includingPropertiesForKeys: nil)
                for file in contents {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                print("⚠️ Failed to clear Caches directory:", error)
            }
        }
        
        // 4. Clear out the tmp directory
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        do {
            let tmpContents = try FileManager.default.contentsOfDirectory(at: tmpURL,
                                                                          includingPropertiesForKeys: nil)
            for file in tmpContents {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            print("⚠️ Failed to clear tmp directory:", error)
        }
        
        print("✅ All caches cleared")
    }
}



/// IAP View Images
enum IAPImage: String, CaseIterable {
    /// Raw value represents the asset image
    case one = "IAP1"
    case two = "IAP2"
    case three = "IAP3"
    case four = "IAP4"
}


struct ProSubscriptionView: View {
    @State private var loadingStatus: (Bool, Bool) = (false, false)
    var body: some View {
        GeometryReader {
            let size = $0.size
            let isSmalleriPhone = size.height < 700
            
            VStack(spacing: 0) {
                Group {
                    if isSmalleriPhone {
                        SubscriptionStoreView(productIDs: Self.productIDs, marketingContent: {
                            CustomMarketingView()
                        })
                        .subscriptionStoreControlStyle(.compactPicker, placement: .bottomBar)
                    } else {
                        SubscriptionStoreView(productIDs: Self.productIDs, marketingContent: {
                            CustomMarketingView()
                        })
                        .subscriptionStoreControlStyle(.pagedProminentPicker, placement: .bottomBar)
                    }
                }
                .subscriptionStorePickerItemBackground(.ultraThinMaterial)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(.hidden, for: .policies)
                .onInAppPurchaseStart { product in
                    print("Show Loading Screen")
                    print("Purchasing \(product.displayName)")
                }
                .onInAppPurchaseCompletion { product, result in
                    switch result {
                    case .success(let result):
                        switch result {
                        case .success(_): print("Success and verify purchase using verification result")
                        case .pending: print("Pending Action")
                        case .userCancelled: print("User Cancelled")
                        @unknown default:
                            fatalError()
                        }
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                    
                    print("Hide Loading Screen")
                }
                .subscriptionStatusTask(for: "4205BB53") {
                    if let result = $0.value {
                        let premiumUser = !result.filter({ $0.state == .subscribed }).isEmpty
                        print("User Subscribed = \(premiumUser)")
                        
                    }
                    
                    print("[subscriptionStatusTask] Subscription status checked")
                    loadingStatus.1 = true
                }
                
                /// Privacy Policy & Terms of Service
                HStack(spacing: 3) {
                    Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                    
                    Text("And")
                    
                    Link("Privacy Policy", destination: URL(string: "https://apple.com")!)
                }
                .font(.caption)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isLoadingCompleted ? 1 : 0)
            .background(BackdropView())
            .overlay {
                if !isLoadingCompleted {
                    ProgressView()
                        .font(.largeTitle)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isLoadingCompleted)
            .storeProductsTask(for: Self.productIDs) { @MainActor collection in
                if let products = collection.products, products.count == Self.productIDs.count {
                    try? await Task.sleep(for: .seconds(0.1))
                    print("[storeProductsTask] Products loaded successfully")
                    loadingStatus.0 = true
                }
            }
        }
        .accentColor(.white)
        .environment(\.colorScheme, .dark)
        .tint(.white)
        .statusBarHidden()
        
    }
    
    var isLoadingCompleted: Bool {
        loadingStatus.0 && loadingStatus.1
    }
    
    static var productIDs: [String] {
        return ["pro_weekly", "pro_monthly", "pro_yearly"]
    }
    
    /// Backdrop View
    @ViewBuilder
    func BackdropView() -> some View {
        GeometryReader {
            let size = $0.size
            
            /// This is a Dark image, but you can use your own image as per your needs!
            Image("IAP4")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.5)
                .blur(radius: 70, opaque: true)
                .overlay {
                    Rectangle()
                        .fill(.black.opacity(0.2))
                }
                .ignoresSafeArea()
        }
    }
    
    /// Custom Marketing View (Header View)
    @ViewBuilder
    func CustomMarketingView() -> some View {
        VStack(spacing: 15) {
            /// App Screenshots View
            HStack(spacing: 25) {
                ScreenshotsView([.one, .two, .three], offset: -200)
                ScreenshotsView([.four, .one, .two], offset: -350)
                ScreenshotsView([.two, .three, .one], offset: -250)
                    .overlay(alignment: .trailing) {
                        ScreenshotsView([.four, .two, .one], offset: -150)
                            .visualEffect { content, proxy in
                                content
                                    .offset(x: proxy.size.width + 25)
                            }
                    }
            }
            .frame(maxHeight: .infinity)
            .offset(x: 20)
            /// Progress Blur Mask
            .mask {
                LinearGradient(colors: [
                    .white,
                    .white.opacity(0.9),
                    .white.opacity(0.7),
                    .white.opacity(0.4),
                    .clear
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .padding(.bottom, -40)
            }
            
            /// Replace with your App Information
            VStack(spacing: 6) {
                Text("Ranko")
                    .font(.title3)
                    .fontWeight(.black)
                
                Text("Supporter")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 10)
                
                Text("Please support us by purchasing the Pro version. We need your help to keep the databases running and to keep adding new features.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                
                Text("Features")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding(.bottom, 10)
                
                Text("• Unlock All App Icons")
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Text("• Create Blank Custom List Items")
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Text("• Experience Dark Mode")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.top, 15)
            .padding(.bottom, 18)
            .padding(.horizontal, 15)
        }
    }
    
    @ViewBuilder
    func ScreenshotsView(_ content: [IAPImage], offset: CGFloat) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                ForEach(content.indices, id: \.self) { index in
                    Image(content[index].rawValue)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .offset(y: offset)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .rotationEffect(.init(degrees: -30), anchor: .bottom)
        .scrollClipDisabled()
    }
}


// used in HomeView
struct SubscriptionStatusManager {
    static func fetchSubscriptionStatus(
        for groupID: String,
        productIDs: [String]
    ) async -> (isSubscribed: Bool, productID: String?) {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: groupID)

            if let subscribedStatus = statuses.first(where: { $0.state == .subscribed }) {
                // Get the verified renewal info
                let verifiedRenewal = subscribedStatus.renewalInfo

                switch verifiedRenewal {
                case .verified(let renewalInfo):
                    return (true, renewalInfo.currentProductID)
                case .unverified(_, let error):
                    print("❌ Renewal info unverified:", error.localizedDescription)
                    return (true, nil)
                }
            }
        } catch {
            print("❌ Error fetching subscription info:", error.localizedDescription)
        }

        return (false, nil)
    }
}

@MainActor
func updateGlobalSubscriptionStatus(groupID: String, productIDs: [String]) async {
    let result = await SubscriptionStatusManager.fetchSubscriptionStatus(for: groupID, productIDs: productIDs)
    UserDefaults.standard.set(result.isSubscribed ? 1 : 0, forKey: "isProUser")
    UserDefaults.standard.set(result.productID, forKey: "activeProductID")
}

#Preview {
    SettingsView()
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(rankoProView: true)
    }
}

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Account")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                
                // ✅ Credentials Section
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Credentials")
                            .foregroundColor(Color(hex: 0x857467))
                            .font(.title2)
                            .bold()
                        
                        Divider()
                        
                        Button {} label: {
                            if user_data.userLoginService == "Apple" {
                                HStack(spacing: 10) {
                                    Spacer()
                                    Image("apple_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .foregroundColor(Color(hex: 0x857467))
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    Text("Signed in with Apple")
                                        .font(.system(size: 17, weight: .heavy, design: .default))
                                        .foregroundColor(Color(hex: 0x857467))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            } else if user_data.userLoginService == "Google" {
                                HStack(spacing: 10) {
                                    Spacer()
                                    Image("google_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .foregroundColor(Color(hex: 0x857467))
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    Text("Signed in with Google")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: 0x857467))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            } else {
                                HStack(spacing: 10) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: 0x857467))
                                    Text("Can't Find Login Service")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: 0x857467))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                             startPoint: .top,
                                             endPoint: .bottom
                                            ))
                        .buttonStyle(.glassProminent)
                    }
                    .padding(.horizontal, 25)
                    
                    // ✅ Log Out & Delete Account Buttons
                    HStack(spacing: 10) {
                        Button(role: .destructive) { showLogoutAlert = true } label: {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                    .font(.system(size: 14, weight: .heavy, design: .default))
                                    .foregroundColor(Color(hex: 0x857467))
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .foregroundColor(Color(hex: 0xFF9864))
                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                             startPoint: .top,
                                             endPoint: .bottom
                                            ))
                        .buttonStyle(.glassProminent)
                        .alert(isPresented: $showLogoutAlert) {
                            CustomDialog(
                                title: "Sign Out?",
                                content: "Are you sure you want to sign out?",
                                image: .init(
                                    content: "figure.walk.departure",
                                    background: .red,
                                    foreground: .white
                                ),
                                button1: .init(
                                    content: "Sign Out",
                                    background: .red,
                                    foreground: .white,
                                    action: { _ in
                                        showLogoutAlert = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                                logOutUser()
                                            }
                                        }
                                    }
                                ),
                                button2: .init(
                                    content: "Cancel",
                                    background: .orange,
                                    foreground: .white,
                                    action: { _ in
                                        showLogoutAlert = false
                                    }
                                )
                            )
                            .transition(.blurReplace.combined(with: .push(from: .bottom)))
                        } background: {
                            Rectangle()
                                .fill(.primary.opacity(0.35))
                        }
                        
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            HStack {
                                Spacer()
                                Text("Delete Account")
                                    .font(.system(size: 14, weight: .heavy, design: .default))
                                    .foregroundColor(Color(hex: 0x857467))
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .foregroundColor(Color(hex: 0xFF9864))
                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                             startPoint: .top,
                                             endPoint: .bottom
                                            ))
                        .buttonStyle(.glassProminent)
                        .alert(isPresented: $showDeleteAlert) {
                            CustomDialog(
                                title: "Delete Account?",
                                content: "Are you sure you want to delete your account? Once deleted, this action cannot be undone.",
                                image: .init(
                                    content: "trash.fill",
                                    background: .red,
                                    foreground: .white
                                ),
                                button1: .init(
                                    content: "Delete Permanently",
                                    background: .red,
                                    foreground: .white,
                                    action: { _ in
                                        showDeleteAlert = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                                deleteAccount()
                                            }
                                        }
                                    }
                                ),
                                button2: .init(
                                    content: "Cancel",
                                    background: .orange,
                                    foreground: .white,
                                    action: { _ in
                                        showDeleteAlert = false
                                    }
                                )
                            )
                            .transition(.blurReplace.combined(with: .push(from: .bottom)))
                        } background: {
                            Rectangle()
                                .fill(.primary.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 25)
                }
                
                Spacer()
                
            }
        }
    }
    
    // ✅ Dummy Logout Function
    private func logOutUser() {
        user_data.logStatus = false
        print("User logged out.")
        
        try? Auth.auth().signOut()
        // User Details
        user_data.userID = ""
        user_data.username = ""
        user_data.userDescription = ""
        user_data.userPrivacy = ""
        user_data.userInterests = ""
        user_data.userJoined = ""
        user_data.userYear = 0
        user_data.userFoundUs = ""
        user_data.userLoginService = ""
        // User Profile Picture
        user_data.userProfilePictureFile = ""
        user_data.userProfilePicturePath = "default-profilePicture.jpg"
        user_data.userProfilePictureModified = ""
        // User Stats
        user_data.userStatsFollowers = 0
        user_data.userStatsFollowing = 0
        user_data.userStatsRankos = 0
        // Notifications
        user_data.notificationRankoLikes = true
        user_data.notificationRankoClones = true
        user_data.notificationPersonalizedRecommendations = true
        user_data.notificationWeeklyProgress = true
        user_data.notificationAppUpdateAvailable = true
        user_data.notificationFriendRequests = true
        user_data.notificationSharedRankos = true
        user_data.notificationFriendsNewRankos = true
        user_data.notificationTrendingRankos = true
        user_data.notificationMiniGameEvents = true
        // Other
        user_data.preferencesAutocorrectDisabled = true
        user_data.ProfilePicture = nil
        user_data.userRankoCategories = ""
        user_data.logStatus = false
    }
    
    // ✅ Dummy Delete Account Function
    private func deleteAccount() {
        
        let user = Auth.auth().currentUser

        user?.delete { error in
          if let error = error {
            print("Error Deleting Account: \(error.localizedDescription)")
          } else {
              print("Account deleted.")
              // User Details
              user_data.userID = ""
              user_data.username = ""
              user_data.userDescription = ""
              user_data.userPrivacy = ""
              user_data.userInterests = ""
              user_data.userJoined = ""
              user_data.userYear = 0
              user_data.userFoundUs = ""
              user_data.userLoginService = ""
              // User Profile Picture
              user_data.userProfilePictureFile = ""
              user_data.userProfilePicturePath = "default-profilePicture.jpg"
              user_data.userProfilePictureModified = ""
              // User Stats
              user_data.userStatsFollowers = 0
              user_data.userStatsFollowing = 0
              user_data.userStatsRankos = 0
              // Notifications
              user_data.notificationRankoLikes = true
              user_data.notificationRankoClones = true
              user_data.notificationPersonalizedRecommendations = true
              user_data.notificationWeeklyProgress = true
              user_data.notificationAppUpdateAvailable = true
              user_data.notificationFriendRequests = true
              user_data.notificationSharedRankos = true
              user_data.notificationFriendsNewRankos = true
              user_data.notificationTrendingRankos = true
              user_data.notificationMiniGameEvents = true
              // Other
              user_data.preferencesAutocorrectDisabled = true
              user_data.ProfilePicture = nil
              user_data.userRankoCategories = ""
              user_data.logStatus = false
          }
        }
    }
}

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Title Bar
                HStack {
                    Text("Notifications")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)

                Divider()
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack {
                            HStack {
                                Text("Personal")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Ranko Likes")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationRankoLikes)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Receive a notification whenever someone likes one of your rankos.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "square.fill.on.square.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Ranko Clones")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationRankoClones)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Get alerted when another user clones one of your rankos.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Personalized Recommendations")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationPersonalizedRecommendations)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("See suggested rankos tailored to your interests.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Weekly Progress Summary")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationWeeklyProgress)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("View a weekly summary of your activity progress.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "app.badge")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("App Update Available")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationAppUpdateAvailable)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Be notified when a new app version is available.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xFFFCF2))
                                    .stroke(Color(hex: 0xFFFFFF), lineWidth: 2)
                            )
                            .padding(.horizontal, 25)
                        }
                        
                        VStack {
                            HStack {
                                Text("Friends")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "figure.2.arms.open")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Friend Requests")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationFriendRequests)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Get notified when someone sends you a friend request.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "hands.clap.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Shared Rankos")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationSharedRankos)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("See when a friend shares a ranko with you.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "plus.diamond.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Friends' New Rankos")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationFriendsNewRankos)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Be alerted when friends create new rankos.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xFFFCF2))
                                    .stroke(Color(hex: 0xFFFFFF), lineWidth: 2)
                            )
                            .padding(.horizontal, 25)
                        }
                        
                        VStack {
                            HStack {
                                Text("Community")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Trending Rankos")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationTrendingRankos)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Stay updated on rankos that are trending community-wide.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "party.popper.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Text("Mini Game Events")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: 0x857467))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationMiniGameEvents)
                                            .tint(Color(hex: 0x857467))
                                            .labelsHidden()
                                    }
                                    Text("Receive alerts for upcoming in-app mini game events.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xFFFCF2))
                                    .stroke(Color(hex: 0xFFFFFF), lineWidth: 2)
                            )
                            .padding(.horizontal, 25)
                        }
                        
                    }
                }
            }
        }
    }
}

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Preferences")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                
                VStack {
                    HStack {
                        Text("Text Preferences")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.leading, 40)
                            .padding(.bottom, 5)
                        Spacer()
                    }
                    VStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "text.magnifyingglass")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x857467))
                                Text("Auto-Correction Disabled")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: 0x857467))
                                Spacer()
                                Toggle("", isOn: $user_data.preferencesAutocorrectDisabled)
                                    .tint(Color(hex: 0x857467))
                                    .labelsHidden()
                            }
                            Text("Disable Autocorrect for all text fields in Ranko.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                .padding(.top, 6)
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 30)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "party.popper.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x857467))
                                Text("Mini Game Events")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: 0x857467))
                                Spacer()
                                Toggle("", isOn: $user_data.notificationMiniGameEvents)
                                    .tint(Color(hex: 0x857467))
                                    .labelsHidden()
                            }
                            Text("Receive alerts for upcoming in-app mini game events.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: 0x857467).opacity(0.7))
                                .padding(.top, 6)
                        }
                        .padding(20)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: 0xFFFCF2))
                            .stroke(Color(hex: 0xFFFFFF), lineWidth: 2)
                    )
                    .padding(.horizontal, 25)
                }
                Spacer()
            }
        }
    }
}

struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Privacy & Security")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                Spacer()
            }
        }
    }
}

struct SuggestionsIdeasView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Suggestions")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                Spacer()
            }
        }
    }
}

struct DataStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Data & Storage")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                Spacer()
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("About")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                Spacer()
            }
        }
    }
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Legal")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Color(hex: 0x857467))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 30, height: 30)
                    }
                    .foregroundColor(Color(hex: 0x857467))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                Divider()
                
                // MARK: - 📜 LINKS TO TERMS AND CONDITIONS - PRIVACY POLICY
                VStack(spacing: 10) {
                    Button { print("Viewing Terms & Conditions") } label: {
                        HStack {
                            Spacer()
                            Text("Terms & Conditions")
                                .font(.system(size: 18, weight: .heavy, design: .default))
                                .foregroundColor(Color(hex: 0x857467))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFF9864))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                    
                    Button { print("Viewing Privacy Policy") } label: {
                        HStack {
                            Spacer()
                            Text("Privacy Policy")
                                .font(.system(size: 18, weight: .heavy, design: .default))
                                .foregroundColor(Color(hex: 0x857467))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFF9864))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 25)
                Spacer()
            }
        }
    }
}


//            ZStack {
//                Color(lightMode ? .gray.opacity(0.15) : .black.opacity(0.85))
//                    .ignoresSafeArea()
//                    .animation(.easeInOut(duration: 0.35), value: lightMode)
//                ScrollView {
//                    VStack(alignment: .leading) {
//                        // MARK: - Settings and Personal Details
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Settings")
//                                .font(.title)
//                                .fontWeight(.black)
//                                .padding(10)
//                                .foregroundColor(lightMode ? .black : .white)
//                                .animation(.easeInOut(duration: 0.35), value: lightMode)
//                            Text("Personal Details")
//                                .font(.caption)
//                                .foregroundColor(lightMode ?  .secondary : .white.opacity(0.9))
//                                .fontWeight(.bold)
//                                .padding([.top, .leading, .bottom], 6)
//                                .animation(.easeInOut(duration: 0.35), value: lightMode)
//                            HStack {
//                                Image(systemName: "person.fill")
//                                    .foregroundColor(.gray)
//                                    .padding(.trailing, 4)
//                                TextField("\(user_data.username)", text: $user_data.username)
//                                    .onChange(of: user_data.username) { oldValue, newValue in
//                                        if newValue.count > 50 {
//                                            user_data.username = String(newValue.prefix(30))
//                                        }
//                                    }
//                                    .autocorrectionDisabled(true)
//                                    .padding(.vertical, 10)
//                                    // Use the current tint for the text color.
//                                    .foregroundColor(currentTint)
//                                    .fontWeight(.bold)
//                            }
//                            .padding(.vertical, 8)
//                            .padding(.horizontal, 16)
//                            .background(lightMode ? Color.white : Color.white.opacity(0.15))
//                            .cornerRadius(10)
//                            .animation(.easeInOut(duration: 0.35), value: lightMode)
//
//                            // MARK: - Buttons
//                            HStack {
//                                GeometryReader { geometry in
//                                    let totalWidth = geometry.size.width
//                                    HStack(spacing: 12) {
//                                        Button {
//                                            // Your show-information action
//                                            let user = Auth.auth().currentUser
//                                            if user != nil {
//                                                print("User's Information")
//                                                print("_________________________________________")
//                                                print("User ID: \(user_data.userID)")
//                                                print("User Name: \(user_data.username)")
//                                                print("User Description: \(user_data.username)")
//                                                print("User Year of Birth: \(user_data.userYear)")
//                                                print("User Interests: \(user_data.userInterests)")
//                                                print("User Profile Picture: \(user_data.userProfilePicture)")
//                                                print("User Found Us: \(user_data.userFoundUs)")
//                                                print("User Joined: \(user_data.userJoined)")
//                                                print("User Log Status: \(user_data.logStatus)")
//                                                print("_________________________________________")
//                                                if let user = Auth.auth().currentUser {
//                                                    print("More Information")
//                                                    print("_________________________________________")
//                                                    print("UID: \(user.uid)")
//                                                    print("Email: \(user.email ?? "No email")")
//                                                    print("Display Name: \(user.displayName ?? "No name")")
//                                                    print("Photo URL: \(user.photoURL?.absoluteString ?? "No photo")")
//                                                    print("Anonymous: \(user.isAnonymous)")
//                                                    print("Email Verified: \(String(describing: user.emailVerified))")
//                                                    print("Created: \(String(describing: user.metadata.creationDate))")
//                                                    print("Last Signed In: \(String(describing: user.metadata.lastSignInDate))")
//                                                    print("_________________________________________")
//                                                }
//
//                                            }
//                                        } label: {
//                                            Text("Show Information")
//                                                .frame(maxWidth: .infinity)
//                                                .padding(.vertical, 10)
//                                                .foregroundColor(.white)
//                                                .fontWeight(.bold)
//                                                .font(.body)
//                                        }
//                                        // Use the currentTint for the button background.
//                                        .background(currentTint.gradient, in: RoundedRectangle(cornerRadius: 8))
//                                        .frame(width: totalWidth * 0.5)
//
//                                        Button {
//                                            try? Auth.auth().signOut()
//                                            user_data.userID = ""
//                                            user_data.username = ""
//                                            user_data.userDescription = ""
//                                            user_data.userYear = 0
//                                            user_data.userInterests = ""
//                                            user_data.userProfilePicture = "default-profilePicture.jpg"
//                                            user_data.userFoundUs = ""
//                                            user_data.userJoined = ""
//                                            user_data.logStatus = false
//                                        } label: {
//                                            Text("Log Out")
//                                                .frame(maxWidth: .infinity)
//                                                .padding(.vertical, 10)
//                                                .foregroundColor(.white)
//                                                .fontWeight(.bold)
//                                        }
//                                        .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
//                                        .frame(width: totalWidth * 0.43)
//
//                                        Spacer()
//                                    }
//                                    .frame(width: totalWidth)
//                                }
//                                .frame(height: 50)
//                            }
//                            .padding(.top, 15)
//
//                            // MARK: - Clear Cache Button
//                            Button {
//                                clearAllCache()
//                            } label: {
//                                Text("Clear Search Cache")
//                                    .frame(maxWidth: .infinity)
//                                    .padding(.vertical, 10)
//                                    .foregroundColor(.white)
//                                    .fontWeight(.bold)
//                            }
//                            .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//
//                            // MARK: - Tint Selection Tray
//                            Text("App Tint")
//                                .font(.caption)
//                                .foregroundColor(lightMode ?  .secondary : .white.opacity(0.9))
//                                .fontWeight(.bold)
//                                .padding([.top, .leading, .bottom], 6)
//                                .animation(.easeInOut(duration: 0.35), value: lightMode)
//                            RoundedRectangle(cornerRadius: 16)
//                                .fill(lightMode ? Color.white : Color.white.opacity(0.15))
//                                .frame(height: 60)
//                                .overlay(
//                                    ScrollView(.horizontal, showsIndicators: false) {
//                                        HStack(spacing: 16) {
//                                            ForEach(availableColours, id: \.name) { item in
//                                                Circle()
//                                                    .fill(item.color)
//                                                    .frame(width: 30, height: 30)
//                                                    .overlay(
//                                                        // Draw a border on the currently selected colour.
//                                                        Circle()
//                                                            .stroke(item.name == appColourString ? currentTint : Color.clear, lineWidth: 2)
//                                                            .frame(width: 35, height: 35)
//                                                    )
//                                                    .onTapGesture {
//                                                        // Update the stored colour string.
//                                                        appColourString = item.name
//                                                    }
//                                            }
//                                        }
//                                        .padding(.vertical, 4)
//                                        .padding(.horizontal, 16)
//                                    }
//                                )
//                                .padding(.horizontal, 10)
//                                .padding(.bottom, 20)
//                            // MARK: - App Icon Button
//                            Button {
//                                appIconCustomiserView.toggle()
//                            } label: {
//                                HStack {
//                                    Image(systemName: "square.filled.on.square")
//                                    Text("Customise App Icon")
//                                }
//                                .padding(.vertical, 10)
//                                .foregroundColor(.white)
//                                .fontWeight(.bold)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//
//                            // MARK: - Pro Membership Sheet Button
//                            Button {
//                                rankoProView.toggle()
//                            } label: {
//                                HStack {
//                                    Image(systemName: "crown.fill")
//                                    Text("Pro Membership")
//                                }
//                                .padding(.vertical, 10)
//                                .foregroundColor(.white)
//                                .fontWeight(.bold)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .background(Color.yellow.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//
//                            // MARK: - Rate on App Store Button
//                            Button {
//                                requestReview()
//                            } label: {
//                                HStack {
//                                    Image(systemName: "star.fill")
//                                    Text("Leave a Review")
//                                }
//                                .padding(.vertical, 10)
//                                .foregroundColor(.white)
//                                .fontWeight(.bold)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//
//                            // MARK: - Help Us Improve Sheet Button
//                            Button {
//                                requestReview()
//                            } label: {
//                                HStack {
//                                    Image(systemName: "hand.thumbsup.fill")
//                                    Text("Any Ideas or Suggestions?")
//                                }
//                                .padding(.vertical, 10)
//                                .foregroundColor(.white)
//                                .fontWeight(.bold)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//
//                            // MARK: - Sample Profile Button for Simulator Only
//                            #if targetEnvironment(simulator)
//                            Button {
//                                user_data.userID = "user_abc123"
//                                user_data.username = "AvaRanker"
//                                user_data.userDescription = "Obsessed with ranking everything from 90s cartoons to underground indie albums. Let's debate!"
//                                user_data.userYear = 2023
//                                user_data.userInterests = "Music, Travel, History"
//                                user_data.userFoundUs = "People"
//                                user_data.userJoined = "2025-06-12-12-34-56"
//                                user_data.userProfilePicture = "https://thumbs.dreamstime.com/b/space-rocket-vector-illustration-blasting-off-sky-32237994.jpg"
//                                user_data.logStatus = true
//                            } label: {
//                                HStack {
//                                    Image(systemName: "person.crop.circle.fill")
//                                    Text("Sample Profile")
//                                }
//                                .padding(.vertical, 10)
//                                .foregroundColor(.white)
//                                .fontWeight(.bold)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .background(Color.pink.gradient, in: RoundedRectangle(cornerRadius: 8))
//                            .frame(maxWidth: .infinity)
//                            .padding(.bottom, 10)
//                            #endif
//
//                        }
//                        Spacer()
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.bottom, 70)
//                }
//            }
//        }

