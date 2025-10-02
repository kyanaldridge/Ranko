//
//  SettingsView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseAnalytics
import FirebaseStorage
import FirebaseDatabase
import InstantSearchCore
import StoreKit
import SpotifyWebAPI

struct SettingItem: Identifiable {
    let id = UUID()
    let variable: String
    let title: String
    let icon: String
    let keywords: [String]
}

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview
    @Namespace private var transition
    
//    @StateObject private var auth = MusicAuthManager()
//    @StateObject var spotify = Spotify()
//    @StateObject private var player = PlayerManager()
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
        SpotifyAPILogHandler.bootstrap()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView(.vertical) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Settings")
                                .font(.custom("Nunito-Black", size: 36))
                                .foregroundStyle(Color(hex: 0x514343))
                            Spacer()
                            ProfileIconView(diameter: CGFloat(50))
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
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
                                        case "Ranko Platinum":
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
                                                .foregroundColor(Color(hex: 0x514343))
                                                .frame(width: 32)
                                            Text(setting.title)
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(Color(hex: 0x514343))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(Color(hex: 0x514343))
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 16)
                                        .matchedTransitionSource(id: setting.title, in: transition)
                                    }
                                    .tint(Color(hex: 0xFFFFFF))
                                    .buttonStyle(.glassProminent)
                                    .id(setting.id)
                                    .background(Color.clear)
                                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 8, x: 0, y: 0)
                                }
                                .padding(.horizontal, 15)
                                .padding(.top, 6)
                            }
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 70)
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
                }
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "Settings",
                AnalyticsParameterScreenClass: "SettingsView"
            ])
        }
        .sheet(isPresented: $accountView) {
            AccountView()
                .navigationTransition(
                    .zoom(sourceID: "Account", in: transition)
                )
        }
        .fullScreenCover(isPresented: $rankoProView) {
            RankoPlatinumView()
                .navigationTransition(
                    .zoom(sourceID: "Ranko Platinum", in: transition)
                )
        }
        .fullScreenCover(isPresented: $notificationsView) {
            //NotificationsView()
            NotificationsView()
//                .environmentObject(spotify)
                .navigationTransition(
                    .zoom(sourceID: "Notifications", in: transition)
                )
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $preferencesView) {
            PreferencesView()
                .navigationTransition(
                    .zoom(sourceID: "Preferences", in: transition)
                )
        }
        .sheet(isPresented: $privacySecurityView) {
            PrivacySecurityView()
                .navigationTransition(
                    .zoom(sourceID: "Privacy & Security", in: transition)
                )
        }
        .fullScreenCover(isPresented: $suggestionsIdeasView) {
            SuggestionsIdeasView()
                .navigationTransition(
                    .zoom(sourceID: "Suggestions & Ideas", in: transition)
                )
        }
        .sheet(isPresented: $dataStorageView) {
            DataStorageView()
                .navigationTransition(
                    .zoom(sourceID: "Data & Storage", in: transition)
                )
        }
        .sheet(isPresented: $aboutView) {
            AboutView()
                .navigationTransition(
                    .zoom(sourceID: "About", in: transition)
                )
        }
        .sheet(isPresented: $legalView) {
            LegalView()
                .navigationTransition(
                    .zoom(sourceID: "Privacy Policy & Terms Of Use", in: transition)
                )
        }
        
    }
    
    // Example settings with keywords
    private var settings: [SettingItem] {
        [
            SettingItem(variable: "account", title: "Account", icon: "person.crop.circle", keywords: ["account", "profile", "sign in", "sign out", "user", "login", "logout"]),
            SettingItem(variable: "rankoPlatinum", title: "Ranko Platinum", icon: "medal.star", keywords: ["ranko", "pro", "premium"]),
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
}

func clearAllCache() {
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

struct SettingsView1: View {
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
            clearAllCache()
        }
        .sheet(isPresented: $accountView) {
            AccountView()
        }
        .fullScreenCover(isPresented: $rankoProView) {
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
            SettingItem(variable: "rankoPlatinum", title: "Ranko Pro", icon: "medal.star", keywords: ["ranko", "pro", "premium"]),
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
    @State private var snappedItem = 0.0
    @State private var draggingItem = 0.0
    @State var activeIndex: Int = 0
    
    let subscriptionFeatures: [SubscriptionFeatures] = [
        .init(id: 14, title: "Unlimited Items & Rankos", icon: "infinity", description: "Create as many Rankos and items in Rankos as you want!"),
        .init(id: 13, title: "Create New Blank Items", icon: "rectangle.dashed", description: "Add blank items to your Rankos!"),
        .init(id: 12, title: "Add Custom Images to Items", icon: "photo.fill", description: "Add custom photos from your camera roll to your items!"),
        .init(id: 11, title: "Download & Export Rankos", icon: "arrow.down.circle.fill", description: "Download your Rankos for Offline Use and also export via csv and soon other formats!"),
        .init(id: 10, title: "New Folders & Tags", icon: "square.grid.3x1.folder.fill.badge.plus", description: "Organise all your Rankos into folders and tags, seperate a series of Rankos by categories or anything practically!"),
        .init(id: 9, title: "Unlock Pro App Icons", icon: "apps.iphone", description: "Unlock all pro app icons in the Customise App section!"),
        .init(id: 8, title: "Pin 20 Rankos", icon: "pin.fill", description: "Pin 20 Rankos to your Feature View for quick access and to show friends and the community!"),
        .init(id: 7, title: "Clone Rankos", icon: "square.fill.on.square.fill", description: "Copy other users Rankos and create your very own version of their creation!"),
        .init(id: 6, title: "Collaborate on Rankos", icon: "person.3.fill", description: "Collaborate with friends and family on Rankos!"),
        .init(id: 5, title: "Integrate with Spotify", icon: "music.note", description: "Add your favourite artists, albums, songs, playlists and more to your Rankos. More integrations to come soon!"),
        .init(id: 4, title: "Search Community Rankos", icon: "rectangle.and.text.magnifyingglass", description: "Search All Public Community Rankos"),
        .init(id: 3, title: "Personal Homepage", icon: "star.bubble.fill", description: "Get community Rankos on your homepage that fit your interests and Rankos you've created"),
        .init(id: 2, title: "Save Rankos", icon: "star.fill", description: "Save communities and friends Rankos to your library to look at again later!"),
        .init(id: 1, title: "Archive Rankos", icon: "archivebox.fill", description: "Archive your Rankos that you don't want showing up in your library anymore without deleting them!")
    ]
    
    var body: some View {
        
        VStack(spacing: 0) {
            SubscriptionStoreView(productIDs: Self.productIDs, marketingContent: {
                CustomMarketingView()
            })
            .subscriptionStoreControlStyle(.pagedProminentPicker, placement: .bottomBar)
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
            HStack(alignment: .center, spacing: 3) {
                Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                
                Text("&")
                
                Link("Privacy Policy", destination: URL(string: "https://apple.com")!)
            }
            .font(.caption)
            .padding(.bottom, 30)
            .padding(.top, 15)
        }
        .padding(.top, 50)
        .ignoresSafeArea()
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
        .accentColor(.white)
        .environment(\.colorScheme, .dark)
        .tint(.white)
        .statusBarHidden()
        .ignoresSafeArea()
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
            /// Replace with your App Information
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    ThreeRectanglesAnimation(rectangleWidth: 14, rectangleMaxHeight: 40, rectangleSpacing: 3, rectangleCornerRadius: 2, animationDuration: 0.8)
                        .frame(height: 60)
                    
                    Text("Ranko Pro")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .padding(.top, 25)
                        .padding(.trailing, 20)
                }
                .frame(height: 60)
            }
            .foregroundStyle(.white)
            ZStack {
                ForEach(subscriptionFeatures) { item in
                    
                    // article view
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x041913), Color(hex: 0x0D3632), Color(hex: 0x175158), Color(hex: 0x1E565F)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        VStack {
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: .heavy, design: .default))
                                Text(item.title)
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                            }
                            Text(item.description)
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(width: 350, height: 150)
                    .scaleEffect(1.0 - abs(distance(item.id)) * 0.2 )
                    .opacity(1.0 - abs(distance(item.id)) * 0.3 )
                    .offset(x: myXOffset(item.id), y: 0)
                    .zIndex(1.0 - abs(distance(item.id)) * 0.1)
                    .onTapGesture {
                        withAnimation {
                            draggingItem = Double(item.id)
                        }
                    }
                }
            }
            .gesture(getDragGesture())
            .padding(.top, 50)
        }
        .padding(.top, -60)
    }
    
    private func getDragGesture() -> some Gesture {
        
        DragGesture()
            .onChanged { value in
                draggingItem = snappedItem + value.translation.width / 400
            }
            .onEnded { value in
                withAnimation {
                    draggingItem = snappedItem + value.predictedEndTranslation.width / 400
                    draggingItem = round(draggingItem).remainder(dividingBy: Double(subscriptionFeatures.count))
                    snappedItem = draggingItem
                    
                    //Get the active Item index
                    self.activeIndex = subscriptionFeatures.count + Int(draggingItem)
                    if self.activeIndex > subscriptionFeatures.count || Int(draggingItem) >= 0 {
                        self.activeIndex = Int(draggingItem)
                    }
                }
            }
    }
    
    func distance(_ item: Int) -> Double {
        return (draggingItem - Double(item)).remainder(dividingBy: Double(subscriptionFeatures.count))
    }
    
    func myXOffset(_ item: Int) -> Double {
        let angle = Double.pi * 2 / Double(subscriptionFeatures.count) * distance(item)
        return sin(angle) * 200
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

// MARK: - Feature Model (reuse your existing one if already in project)
struct SubscriptionFeatures: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let description: String
}

// MARK: - RankoPlatinumView
struct RankoPlatinumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var user_data = UserInformation.shared

    // tabs
    enum PlatinumTab: String, CaseIterable { case features = "Features", plans = "Plans" }
    @State private var currentTab: PlatinumTab = .features

    // storekit
    private let productIDs = ["pro_weekly", "pro_monthly", "pro_yearly"]
    @State private var products: [Product] = []
    @State private var isSyncing = false
    @State private var purchaseInFlight: String? = nil

    // content
    private let features: [SubscriptionFeatures] = [
        .init(id: 14, title: "Unlimited Items & Rankos", icon: "infinity", description: "Create as many Rankos and items as you want."),
        .init(id: 13, title: "Create New Blank Items", icon: "rectangle.dashed", description: "Add blank items to your Rankos."),
        .init(id: 12, title: "Add Custom Images", icon: "photo.fill", description: "Attach camera-roll images to items."),
        .init(id: 11, title: "Download & Export", icon: "arrow.down.circle.fill", description: "Offline Rankos + CSV export (more soon)."),
        .init(id: 10, title: "Folders & Tags", icon: "square.grid.3x1.folder.fill.badge.plus", description: "Organise Rankos by folders and tags."),
        .init(id: 9,  title: "Pro App Icons", icon: "apps.iphone", description: "Unlock premium app icons."),
        .init(id: 8,  title: "Pin 20 Rankos", icon: "pin.fill", description: "Quick-access your favourites."),
        .init(id: 7,  title: "Clone Rankos", icon: "square.fill.on.square.fill", description: "Copy community Rankos and remix."),
        .init(id: 6,  title: "Collaborate", icon: "person.3.fill", description: "Build Rankos together in real time."),
        .init(id: 5,  title: "Spotify Integration", icon: "music.note", description: "Add artists, albums, tracks, playlists."),
        .init(id: 4,  title: "Search Community", icon: "rectangle.and.text.magnifyingglass", description: "Find public Rankos fast."),
        .init(id: 3,  title: "Personal Homepage", icon: "star.bubble.fill", description: "See Rankos tailored to you."),
        .init(id: 2,  title: "Save Rankos", icon: "star.fill", description: "Bookmark to your library."),
        .init(id: 1,  title: "Archive Rankos", icon: "archivebox.fill", description: "Hide without deleting.")
    ]

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .black))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .foregroundColor(.black.opacity(0.75))
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }

                // Header
                VStack(spacing: 14) {
                    Image("Platinum_AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .shadow(radius: 8, y: 4)

                    Text("BECOME A PLATINUM MEMBER")
                        .font(.custom("Nunito-Black", size: 22))
                        .kerning(1.1)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 6)

                // Tabs
                Picker("", selection: $currentTab) {
                    ForEach(PlatinumTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 18)

                // Content
                Group {
                    switch currentTab {
                    case .features: featuresTab(proxy: proxy)
                    case .plans:    plansTab()
                    }
                }
                .padding(.top, 10)
            }
            .background(Color.white.ignoresSafeArea())
            .task {
                await loadProducts()
            }
        }
    }

    // MARK: - Features Tab
    @ViewBuilder
    private func featuresTab(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: []) {
                ForEach(features) { f in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: f.icon)
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            Text(f.description)
                                .font(.system(size: 14))
                                .foregroundColor(.black.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 1))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }

                // Look At Plans button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        currentTab = .plans
                    }
                } label: {
                    Text("LOOK AT PLANS")
                        .font(.custom("Nunito-Black", size: 16))
                        .kerning(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Plans Tab
    @ViewBuilder
    private func plansTab() -> some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(sortedProducts(products), id: \.id) { product in
                        PlanCard(
                            product: product,
                            activeProductID: purchaseController.activeProductID,
                            isLoading: purchaseInFlight == product.id
                        ) {
                            Task {
                                purchaseInFlight = product.id
                                defer { purchaseInFlight = nil }
                                do {
                                    _ = try await product.purchase()
                                    // listener will pick it up, but refresh for snappier UI
                                    await purchaseController.refreshEntitlements()
                                } catch {
                                    print("purchase error:", error.localizedDescription)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }

            HStack(spacing: 14) {
                Button {
                    Task {
                        isSyncing = true
                        defer { isSyncing = false }
                        do { try await AppStore.sync() } catch { print("sync error:", error.localizedDescription) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSyncing { ProgressView().scaleEffect(0.8) }
                        Text("Restore Purchases")
                    }
                }

                Spacer()

                Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                Text("•").foregroundColor(.black.opacity(0.4))
                Link("Privacy", destination: URL(string: "https://apple.com")!)
            }
            .font(.footnote)
            .foregroundColor(.black.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers
    private func sortedProducts(_ products: [Product]) -> [Product] {
        // keep the horizontal order: weekly, monthly, yearly (matches your IDs)
        let order = ["pro_weekly", "pro_monthly", "pro_yearly"]
        return products.sorted { a, b in
            order.firstIndex(of: a.id) ?? 99 < order.firstIndex(of: b.id) ?? 99
        }
    }

    @MainActor
    private func loadProducts() async {
        do {
            let result = try await Product.products(for: Set(productIDs))
            self.products = sortedProducts(result)
        } catch {
            print("products load error:", error.localizedDescription)
        }
    }
}

// MARK: - PlanCard
private struct PlanCard: View {
    let product: Product
    let activeProductID: String?
    let isLoading: Bool
    let onPurchase: () -> Void

    var isActive: Bool { activeProductID == product.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // badge / name
            Text(planName(for: product.id).uppercased())
                .font(.custom("Nunito-Black", size: 13))
                .foregroundColor(.black.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.06), in: Capsule())

            // price
            Text(product.displayPrice)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.black)

            // period
            if let period = product.subscription?.subscriptionPeriod {
                Text("per \(period.unit.localizedUnit)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
            }

            // blurb
            Text(planBlurb(for: product.id))
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onPurchase) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isActive ? "Subscribed" : (isLoading ? "Processing…" : "Choose Plan"))
                        .font(.custom("Nunito-Black", size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isActive ? Color.black.opacity(0.15) : Color.black,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(isActive ? .black : .white)
            }
            .disabled(isActive || isLoading)
        }
        .padding(16)
        .frame(width: 260, height: 220)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    private func planName(for id: String) -> String {
        switch id {
        case "pro_weekly":  return "Weekly"
        case "pro_monthly": return "Monthly"
        case "pro_yearly":  return "Yearly"
        default:            return product.displayName
        }
    }

    private func planBlurb(for id: String) -> String {
        switch id {
        case "pro_weekly":  return "Low-Commitment"
        case "pro_monthly": return "Most Popular"
        case "pro_yearly":  return "Best Value"
        default:            return product.description
        }
    }
    
    private func freePeriod(for id: String) -> String {
        switch id {
        case "pro_weekly":  return "one week free"
        case "pro_monthly": return "one month free"
        case "pro_yearly":  return "one month free"
        default:            return product.description
        }
    }
}

// MARK: - Period helper
private extension Product.SubscriptionPeriod.Unit {
    var localizedUnit: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("Account")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                // ✅ Credentials Section
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Credentials")
                            .foregroundColor(Color(hex: 0x514343))
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
                                        .foregroundColor(Color(hex: 0x514343))
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    Text("Signed in with Apple")
                                        .font(.custom("Nunito-Black", size: 20))
                                        .foregroundColor(Color(hex: 0x514343))
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
                                        .foregroundColor(Color(hex: 0x514343))
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    Text("Signed in with Google")
                                        .font(.custom("Nunito-Black", size: 20))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            } else {
                                HStack(spacing: 10) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Can't Find Login Service")
                                        .font(.custom("Nunito-Black", size: 20))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .foregroundColor(Color(hex: 0x514343))
                        .tint(Color(hex: 0xFFFFFF))
                        .buttonStyle(.glassProminent)
                        .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                    }
                    .padding(.horizontal, 25)
                    
                    // ✅ Log Out & Delete Account Buttons
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Button(role: .destructive) { showLogoutAlert = true } label: {
                            HStack {
                                Text("Sign Out")
                                    .font(.custom("Nunito-Black", size: 17))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .padding(.horizontal, 10)
                            }
                            .padding(.vertical, 10)
                        }
                        .foregroundColor(Color(hex: 0x514343))
                        .tint(Color(hex: 0xFFFFFF))
                        .buttonStyle(.glassProminent)
                        .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
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
                                Text("Delete Account")
                                    .font(.custom("Nunito-Black", size: 17))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .padding(.horizontal, 10)
                            }
                            .padding(.vertical, 10)
                        }
                        .foregroundColor(Color(hex: 0x514343))
                        .tint(Color(hex: 0xFFFFFF))
                        .buttonStyle(.glassProminent)
                        .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
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
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 25)
                }
                .padding(.top, 20)
                
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
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Title Bar
                HStack {
                    Text("Notifications")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 25) {
                        VStack {
                            HStack {
                                Text("Personal")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Ranko Likes")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationRankoLikes)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationRankoLikes ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationRankoLikes ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .foregroundColor(.white)
                                            .labelsHidden()
                                    }
                                    Text("Receive a notification whenever someone likes one of your rankos.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "square.fill.on.square.fill")
                                            .font(.custom("Nunito-Black", size: 13))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Ranko Clones")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationRankoClones)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationRankoClones ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationRankoClones ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("Get alerted when another user clones one of your rankos.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Personalized Recommendations")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationPersonalizedRecommendations)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationPersonalizedRecommendations ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationPersonalizedRecommendations ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("See suggested rankos tailored to your interests.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Weekly Progress Summary")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationWeeklyProgress)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationWeeklyProgress ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationWeeklyProgress ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("View a weekly summary of your activity progress.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "app.badge")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("App Update Available")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationAppUpdateAvailable)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationAppUpdateAvailable ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationAppUpdateAvailable ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("Be notified when a new app version is available.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xF8F8F8))
                            )
                            .padding(.horizontal, 25)
                        }
                        .padding(.top, 20)
                        
                        VStack {
                            HStack {
                                Text("Friends")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "figure.2.arms.open")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Friend Requests")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationFriendRequests)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationFriendRequests ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationFriendRequests ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("Get notified when someone sends you a friend request.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "hands.clap.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Shared Rankos")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationSharedRankos)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationSharedRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationSharedRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("See when a friend shares a ranko with you.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "plus.diamond.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Friends' New Rankos")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationFriendsNewRankos)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationFriendsNewRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationFriendsNewRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("Be alerted when friends create new rankos.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xF8F8F8))
                            )
                            .padding(.horizontal, 25)
                        }
                        
                        VStack {
                            HStack {
                                Text("Community")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .padding(.leading, 40)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            VStack(spacing: 0) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Trending Rankos")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationTrendingRankos)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationTrendingRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationTrendingRankos ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .transition(.opacity)
                                            .labelsHidden()
                                    }
                                    Text("Stay updated on rankos that are trending community-wide.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                                
                                Divider()
                                    .padding(.horizontal, 30)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "party.popper.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Mini Game Events")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Spacer()
                                        Toggle("", isOn: $user_data.notificationMiniGameEvents)
                                            .tint(Color(hex:0x78C2B3))
                                            .padding(.trailing, 2)
                                            .background(RoundedRectangle(cornerRadius: 20)
                                                .fill(user_data.notificationMiniGameEvents ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                                .stroke(user_data.notificationMiniGameEvents ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                            )
                                            .labelsHidden()
                                    }
                                    Text("Receive alerts for upcoming in-app mini game events.")
                                        .font(.custom("Nunito-Black", size: 12))
                                        .foregroundColor(Color(hex: 0xA2A2A1))
                                        .padding(.top, 6)
                                }
                                .padding(20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: 0xF8F8F8))
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
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("Preferences")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                VStack {
                    HStack {
                        Text("Text Preferences")
                            .font(.custom("Nunito-Black", size: 14))
                            .foregroundColor(Color(hex: 0x514343))
                            .padding(.leading, 40)
                            .padding(.bottom, 5)
                        Spacer()
                    }
                    VStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "text.magnifyingglass")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x514343))
                                Text("Auto-Correction Disabled")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                Spacer()
                                Toggle("", isOn: $user_data.preferencesAutocorrectDisabled)
                                    .tint(Color(hex:0x78C2B3))
                                    .padding(.trailing, 2)
                                    .background(RoundedRectangle(cornerRadius: 20)
                                        .fill(user_data.preferencesAutocorrectDisabled ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                        .stroke(user_data.preferencesAutocorrectDisabled ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                    )
                                    .labelsHidden()
                            }
                            Text("Disable Autocorrect for all text fields in Ranko.")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                                .padding(.top, 6)
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 30)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "capslock.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x514343))
                                Text("Autocapitalise Ranko Titles")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                Spacer()
                                Toggle("", isOn: $user_data.notificationMiniGameEvents)
                                    .tint(Color(hex:0x78C2B3))
                                    .padding(.trailing, 2)
                                    .background(RoundedRectangle(cornerRadius: 20)
                                        .fill(user_data.notificationMiniGameEvents ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                        .stroke(user_data.notificationMiniGameEvents ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                    )
                                    .labelsHidden()
                            }
                            Text("Enable Ranko Titles to have automatic proper casing.")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                                .padding(.top, 6)
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 30)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x514343))
                                Text("Haptics")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                Spacer()
                                Toggle("", isOn: $user_data.preferencesHaptics)
                                    .tint(Color(hex:0x78C2B3))
                                    .padding(.trailing, 2)
                                    .background(RoundedRectangle(cornerRadius: 20)
                                        .fill(user_data.preferencesHaptics ? Color(hex:0x78C2B3) : Color(hex: 0xD67063))
                                        .stroke(user_data.preferencesHaptics ? Color(hex:0x78C2B3) : Color(hex: 0xD67063), lineWidth: 2)
                                    )
                                    .labelsHidden()
                            }
                            Text("Receive haptic feedback.")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                                .padding(.top, 6)
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 30)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: 0x514343))
                                Text("Haptic Intensity")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                                Spacer()
                                Text(user_data.preferencesHapticIntensity == 1 ? "Low" : (user_data.preferencesHapticIntensity == 2 ? "Normal" : (user_data.preferencesHapticIntensity == 3 ? "High" : "Very High")))
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundColor(Color(hex: 0x514343))
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(user_data.preferencesHapticIntensity) },
                                    set: { newValue in
                                        let newIndex = Int(newValue.rounded())
                                        user_data.preferencesHapticIntensity = newIndex
                                    }
                                ),
                                in: 1...4,
                                step: 1
                            )
                            .sensoryFeedback(.impact(intensity: Double(user_data.preferencesHapticIntensity / 4)), trigger: user_data.preferencesHapticIntensity)
                            .accentColor(Color(hex:0x78C2B3))
                            .padding(.top, 6)
                            
                            Text("Customise the intensity of haptic feedback.")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                                .padding(.top, 6)
                        }
                        .padding(20)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: 0xF8F8F8))
                    )
                    .padding(.horizontal, 25)
                }
                .padding(.top, 20)
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
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("Privacy & Security")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack {
                        VStack(spacing: 0) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Private Account")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyPrivateAccount)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                }
                                Text("Make your account fully private.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "figure.2.arms.open")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Allow Friend Requests")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyAllowFriendRequests)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Allow friend requests from other users.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Show Featured Lists Publicly")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyDisplayFeaturedLists)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Show all your featured lists to people who visit your profile.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Display Username Publicly")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyDisplayUsername)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Display your username on leaderboards and to people who visit your profile.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "text.word.spacing")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Display Description Publicly")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyDisplayBio)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Display your bio to people who visit your profile.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "person.crop.square")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Display Profile Picture Publicly")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyDisplayProfilePicture)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Display your profile picture on leaderboards and to people who visit your profile.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "square.fill.on.square.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Text("Allow Users to Clone Your Rankos")
                                        .font(.custom("Nunito-Black", size: 14))
                                        .foregroundColor(Color(hex: 0x514343))
                                    Spacer()
                                    Toggle("", isOn: $user_data.privacyAllowClones)
                                        .tint(Color(hex: 0x857467))
                                        .labelsHidden()
                                        .disabled(user_data.privacyPrivateAccount)
                                }
                                Text("Allow users when they visit your profile to clone your rankos to create their own versions.")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                                    .padding(.top, 6)
                            }
                            .padding(20)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(hex: 0xF8F8F8))
                        )
                        .padding(.horizontal, 25)
                    }
                    .padding(.top, 20)
                    Spacer()
                }
            }
            .onChange(of: user_data.privacyPrivateAccount) {
                if user_data.privacyPrivateAccount {
                    user_data.privacyAllowFriendRequests = true
                    user_data.privacyDisplayFeaturedLists = true
                    user_data.privacyDisplayUsername = true
                    user_data.privacyDisplayBio = true
                    user_data.privacyDisplayProfilePicture = true
                    user_data.privacyAllowClones = true
                } else {
                    user_data.privacyAllowFriendRequests = false
                    user_data.privacyDisplayFeaturedLists = false
                    user_data.privacyDisplayUsername = false
                    user_data.privacyDisplayBio = false
                    user_data.privacyDisplayProfilePicture = false
                    user_data.privacyAllowClones = false
                }
            }
        }
    }
}



struct SuggestionsIdeasView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    // MARK: - Types & Data
    enum SuggestionType: String, CaseIterable {
        case problems = "Problems"
        case ideas = "Ideas"
        case other = "Other"
    }

    private let problemCats: [(icon: String, name: String)] = [
        ("ladybug.fill", "Bugs"),
        ("exclamationmark.shield.fill", "App Crashes"),
        ("tortoise.fill", "Slow Performance"),
        ("externaldrive.fill.badge.exclamationmark", "Saving Data"),
        ("questionmark.folder.fill", "Unexpected Issues"),
        ("ellipsis", "Other")
    ]
    private let ideaCats: [(icon: String, name: String)] = [
        ("square.grid.3x3.fill", "Ranko Layouts"),
        ("paintbrush.pointed.fill", "App UI Design"),
        ("sparkles", "New Sample Items"),
        ("slider.horizontal.3", "New Customisation"),
        ("arrow.triangle.2.circlepath", "Update Data"),
        ("ellipsis", "Other")
    ]

    // MARK: - Form State
    @State private var suggestionID: String = UUID().uuidString
    @State private var selectedType: SuggestionType = .problems
    @State private var selectedCategory: String? = nil

    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var contact: String = ""

    // image attach (re-using your DraftCard flow vibe)
    @State private var attachedImage: UIImage? = nil
    @State private var showAttachSheet = false
    @State private var showPhotoPicker = false
    @State private var showImageCropper = false
    @State private var imageForCropping: UIImage? = nil

    // progress / errors
    @State private var isUploadingImage = false
    @State private var uploadError: String? = nil
    @State private var uploadedImageURL: String? = nil

    @State private var isSubmitting = false
    @State private var submitError: String? = nil

    var body: some View {
        ZStack {
            Color(hex: 0xFFFFFF).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Title Bar
                HStack {
                    Text("Suggestions")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black)
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: Type Picker
                        Picker("Type", selection: $selectedType) {
                            ForEach(SuggestionType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 25)
                        .onChange(of: selectedType) { _, newVal in
                            selectedCategory = nil
                        }

                        // MARK: Category Chips (Problems/Ideas only)
                        if selectedType == .problems || selectedType == .ideas {
                            let cats = selectedType == .problems ? problemCats : ideaCats
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Category")
                                    .font(.custom("Nunito-Black", size: 14))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 25)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(cats, id: \.name) { c in
                                            CategoryCircle(icon: c.icon, name: c.name, isSelected: selectedCategory == c.name)
                                                .onTapGesture {
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                                                        selectedCategory = c.name
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // MARK: Subject
                        VStack(spacing: 6) {
                            HStack {
                                Text("SUBJECT").font(.custom("Nunito-Black", size: 12)).foregroundStyle(.secondary)
                                Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
                                Spacer()
                            }
                            .padding(.horizontal, 6)

                            HStack(spacing: 8) {
                                Image(systemName: "textformat.size.larger").foregroundColor(.gray)
                                TextField("Short subject…", text: $subject)
                                    .font(.custom("Nunito-Black", size: 18))
                                    .autocorrectionDisabled(true)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
                            )
                        }
                        .padding(.horizontal, 25)

                        // MARK: Message
                        VStack(spacing: 6) {
                            HStack {
                                Text("MESSAGE").font(.custom("Nunito-Black", size: 12)).foregroundStyle(.secondary)
                                Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
                                Spacer()
                            }
                            .padding(.horizontal, 6)

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "text.justify").foregroundColor(.gray).padding(.top, 6)
                                TextField("Describe the problem/idea…", text: $message, axis: .vertical)
                                    .font(.custom("Nunito-Black", size: 18))
                                    .lineLimit(5...10)
                                    .autocorrectionDisabled(true)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
                            )
                        }
                        .padding(.horizontal, 25)

                        // MARK: Contact
                        VStack(spacing: 6) {
                            HStack {
                                Text("CONTACT (OPTIONAL)").font(.custom("Nunito-Black", size: 12)).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 6)

                            HStack(spacing: 8) {
                                Image(systemName: "at").foregroundColor(.gray)
                                TextField("Email or phone number for follow-up", text: $contact)
                                    .font(.custom("Nunito-Black", size: 16))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
                            )
                        }
                        .padding(.horizontal, 25)

                        // MARK: Attach Image
                        VStack(spacing: 10) {
                            Button {
                                showAttachSheet = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(attachedImage == nil ? "ATTACH IMAGE" : "REPLACE IMAGE")
                                        .font(.custom("Nunito-Black", size: 14))
                                    if isUploadingImage { ProgressView().controlSize(.mini) }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(isUploadingImage)
                            .padding(.horizontal, 25)

                            if let img = attachedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 25)
                                    .overlay {
                                        if isUploadingImage {
                                            ZStack {
                                                Color.black.opacity(0.2)
                                                ProgressView("Uploading…")
                                                    .padding(8)
                                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                            }

                            if let err = uploadError {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 25)
                            }
                        }

                        // MARK: Submit
                        VStack(spacing: 12) {
                            if let e = submitError {
                                Label(e, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                            }

                            Button {
                                Task { await handleSubmit() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "paperplane.fill")
                                    Text(isSubmitting ? "SUBMITTING…" : "SUBMIT")
                                        .font(.custom("Nunito-Black", size: 16))
                                    if isSubmitting { ProgressView().controlSize(.mini) }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(isSubmitting || isUploadingImage)
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 18)
                }
            }
        }
        // MARK: Sheets (same flow you use for DraftCard)
        .sheet(isPresented: $showAttachSheet) {
            AttachImageSheet(pickFromLibrary: {
                showAttachSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showPhotoPicker = true }
            })
            .presentationDetents([.fraction(0.35)])
            .presentationBackground(Color.white)
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
        }
        .fullScreenCover(isPresented: $showImageCropper) {
            if let img = imageForCropping {
                SwiftyCropView(
                    imageToCrop: img,
                    maskShape: .square,
                    configuration: SwiftyCropConfiguration(
                        maxMagnificationScale: 8.0,
                        maskRadius: 190.0,
                        cropImageCircular: false,
                        rotateImage: false,
                        rotateImageWithButtons: true,
                        usesLiquidGlassDesign: true,
                        zoomSensitivity: 3.0
                    ),
                    onCancel: {
                        imageForCropping = nil
                        showImageCropper = false
                    },
                    onComplete: { cropped in
                        imageForCropping = nil
                        showImageCropper = false
                        if let out = cropped { Task { await uploadSuggestionImage(out) } }
                    }
                )
            }
        }
        .onChange(of: imageForCropping) { _, val in
            if val != nil { showImageCropper = true }
        }
        .alert("Couldn't submit", isPresented: .init(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(submitError ?? "")
        }
    }

    // MARK: - UI Bits
    private struct CategoryCircle: View {
        let icon: String
        let name: String
        let isSelected: Bool

        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x514343) : Color.gray.opacity(0.12))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.08), lineWidth: isSelected ? 0 : 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.75))
                }
                Text(name)
                    .font(.custom("Nunito-Black", size: 11))
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }

    private struct AttachImageSheet: View {
        var pickFromLibrary: () -> Void
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Attach Image").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button(action: pickFromLibrary) {
                            Text("Photo Library")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x0288FE))
                        }
                    }
                    .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24)

                    Button(action: pickFromLibrary) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                            Text("Choose from Library")
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }

                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                            Text("Files (optional hook)")
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 18)
            }
        }
    }

    // MARK: - Helpers
    private func aedtTimestamp() -> String {
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        fmt.dateFormat = "yyyyMMddHHmmss"
        return fmt.string(from: now)
    }

    private func safeUID(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: ".#$[]")
        return raw.components(separatedBy: invalid).joined()
    }

    // MARK: - Image Upload
    private func uploadSuggestionImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        isUploadingImage = true
        uploadError = nil

        let path = "rankoSuggestions/\(suggestionID).jpg"
        let ref  = Storage.storage().reference().child(path)

        // metadata (like your profile uploads)
        let md = StorageMetadata()
        md.contentType = "image/jpeg"
        md.customMetadata = [
            "suggestionID": suggestionID,
            "userID": user_data.userID,
            "uploadedAt": aedtTimestamp()
        ]

        do {
            try await withTimeout(seconds: 12) {
                _ = try await ref.putDataAsync(data, metadata: md)
            }
            // deterministic public URL style you use elsewhere
            let url = "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoSuggestions%2F\(suggestionID).jpg?alt=media&token="
            attachedImage = image
            uploadedImageURL = url
            isUploadingImage = false
        } catch {
            isUploadingImage = false
            uploadError = (error as NSError).localizedDescription
        }
    }

    private enum TimeoutErr: Error { case timedOut }
    private func withTimeout<T>(seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutErr.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Submit
    @MainActor
    private func handleSubmit() async {
        submitError = nil

        // basic validation
        if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submitError = "please add a subject."
            return
        }
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submitError = "please add a message."
            return
        }
        if (selectedType == .problems || selectedType == .ideas), selectedCategory == nil {
            submitError = "please choose a category."
            return
        }
        if isUploadingImage {
            submitError = "please wait for the image to finish uploading."
            return
        }

        isSubmitting = true
        let db = Database.database().reference()

        // user id
        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let uid = safeUID(rawUID)

        // payload
        let ts = aedtTimestamp()
        let typeStr = selectedType.rawValue
        let catStr = (selectedType == .other) ? "Other" : (selectedCategory ?? "Other")

        let payload: [String: Any] = [
            "SuggestionID": suggestionID,
            "UserID": uid,
            "Type": typeStr,
            "Category": catStr,
            "Subject": subject,
            "Message": message,
            "Contact": contact,
            "ImageURL": uploadedImageURL ?? "",
            "DateTime": ts,
            "Status": "open",
            "Platform": "iOS",
            "AppVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "Build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        ]

        do {
            try await setValueAsync(
                db.child("SuggestionData").child(suggestionID),
                value: payload
            )
            isSubmitting = false
            // reset & close
            suggestionID = UUID().string
            dismiss()
        } catch {
            isSubmitting = false
            submitError = error.localizedDescription
        }
    }

    private func setValueAsync(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { err, _ in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
    }
}

// tiny UUID helper
private extension UUID {
    var string: String { uuidString }
}

struct DataStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("Data & Storage")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                Button {
                    clearAllCache()
                } label: {
                    HStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "")
                            .font(.system(size: 19, weight: .heavy, design: .default))
                            .foregroundColor(Color(hex: 0x514343))
                        Text("Clear Cache")
                            .font(.custom("Nunito-Black", size: 17))
                            .foregroundColor(Color(hex: 0x514343))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .tint(Color(hex: 0xFFFFFF))
                .buttonStyle(.glassProminent)
                .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                .padding(.horizontal, 25)
                .padding(.top, 20)
                
                Spacer()
            }
        }
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

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        ZStack {
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("About")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
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
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack {
                    Text("Legal")
                        .font(.custom("Nunito-Black", size: 32))
                        .foregroundColor(Color(hex: 0x514343))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .black))
                            .padding(.vertical, 5)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 40)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: 0x000000))
                    .frame(height: 3)
                    .opacity(0.08)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                
                // MARK: - 📜 LINKS TO TERMS AND CONDITIONS - PRIVACY POLICY
                VStack(spacing: 10) {
                    Button { print("Viewing Terms & Conditions") } label: {
                        HStack {
                            Spacer()
                            Text("Terms & Conditions")
                                .font(.custom("Nunito-Black", size: 18))
                                .foregroundColor(Color(hex: 0x514343))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                    
                    Button { print("Viewing Privacy Policy") } label: {
                        HStack {
                            Spacer()
                            Text("Privacy Policy")
                                .font(.custom("Nunito-Black", size: 18))
                                .foregroundColor(Color(hex: 0x514343))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0x514343))
                    .tint(Color(hex: 0xFFFFFF))
                    .buttonStyle(.glassProminent)
                    .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
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

