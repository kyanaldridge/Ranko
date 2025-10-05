////
////  AppleMusic.swift
////  RankoApp
////
////  Created by Kyan Aldridge on 31/8/2025.
////
//
//import SwiftUI
//import StoreKit
//import MusicKit
//import MediaPlayer
//import Foundation
//import Combine
//import AVKit
//
///// A shorter alias for the ApplicationMusicPlayer
//@available(macOS 14.0, macCatalyst 17.0, *)
//@available(watchOS, unavailable)
//public typealias APlayer = ApplicationMusicPlayer
//
//@available(macOS 14.0, macCatalyst 17.0, *)
//@available(watchOS, unavailable)
//public extension APlayer {
//    
//    /// Plays the specified song in the player's queue.
//    ///
//    /// - Parameter song: The song to play.
//    func play(song: Song) async throws {
//        queue = [song]
//        try await play()
//    }
//    
//    /// Plays the specified collection of songs in the player's queue.
//    ///
//    /// - Parameter songs: The collection of songs to play.
//    func play(songs: Songs) async throws {
//        queue = APlayer.Queue(for: songs)
//        try await play()
//    }
//    
//    /// Plays the specified song at the specified position in the player's queue.
//    ///
//    /// - Parameters:
//    ///   - song: The song to play.
//    ///   - position: The position at which to insert the song in the player's queue.
//    ///
//    /// - Throws: An error if the song cannot be inserted in the queue or played.
//    func play(song: Song, at position: APlayer.Queue.EntryInsertionPosition) async throws {
//        try await queue.insert(song, position: position)
//        try await play()
//    }
//}
//
//@available(macOS 14.0, macCatalyst 17.0, *)
//@available(watchOS, unavailable)
//public extension APlayer {
//    
//    /// Plays the specified station in the player's queue.
//    ///
//    /// - Parameter station: The station to play.
//    func play(station: Station) async throws {
//        queue = [station]
//        try await play()
//    }
//}
//
//@available(macOS 14.0, macCatalyst 17.0, *)
//@available(watchOS, unavailable)
//public extension APlayer {
//    
//    /// Plays the specified playlist in the player's queue.
//    ///
//    /// - Parameter playlist: The playlist to play.
//    func play(playlist: Playlist) async throws {
//        queue = [playlist]
//        try await play()
//    }
//}
//
//@available(macOS 14.0, macCatalyst 17.0, *)
//@available(watchOS, unavailable)
//public extension APlayer {
//    
//    /// Plays the specified album in the player's queue.
//    ///
//    /// - Parameter album: The album to play.
//    func play(album: Album) async throws {
//        queue = [album]
//        try await play()
//    }
//    
//    @available(iOS 16.0, tvOS 16.0, visionOS 1.0, *)
//    func play(album: MusicLibrarySection<Album, Song>) async throws {
//        queue = ApplicationMusicPlayer.Queue(for: album.items)
//        try await play()
//    }
//}
//
//@available(iOS 16, *, tvOS 16, *, macOS 14.0, macCatalyst 17.0, visionOS 1.0, *)
//@available(watchOS, unavailable)
//public extension APlayer {
//    
//    /// Plays the specified personalized music recommendation item in the player's queue.
//    ///
//    /// - Parameter item: The personalized music recommendation item to play, which can be an album, playlist, or station.
//    func play(item: MusicPersonalRecommendation.Item) async throws {
//        switch item {
//        case .album(let album):
//            queue = [album]
//        case .playlist(let playlist):
//            queue = [playlist]
//        case .station(let station):
//            queue = [station]
//        @unknown default:
//            fatalError()
//        }
//        
//        try await play()
//    }
//}
//
//struct AppleMusicView: View {
//    @Environment(\.dismiss) var dismiss
//    @StateObject private var vm = MusicSearchViewModel()
//    @ObservedObject private var state = APlayer.shared.state
//    @Namespace private var animation
//    @EnvironmentObject private var player: PlayerManager
//    
//    @State private var searchText: String = ""
//    @State private var expandMiniPlayer: Bool = false
//    @State private var searchResults: [Song] = []
//    @State private var searchCategory: String = "Artists"
//    @State private var activeIndex: Int? = 1
//    
//    enum SearchCategory: String, CaseIterable {
//        case artists = "Artists"
//        case albums = "Albums"
//        case tracks = "Tracks"
//        case musicVideos = "Music Videos"
//        case playlists = "Playlists"
//    }
//
//    struct SearchFilterButton: Identifiable {
//        let id = UUID()
//        let title: String          // e.g. "Artists"
//        let icon: String           // e.g. "music.mic"
//        let iconSize: CGFloat      // lets you tweak per-chip if you want
//        let buttonWidth: CGFloat
//        let color: Color           // base tint (like your MenuItemButtons)
//        let category: SearchCategory
//    }
//
//    // edit colors/sizes/icons however you like
//    let searchFilters: [SearchFilterButton] = [
//        .init(title: "Artists", icon: "music.mic", iconSize: 14, buttonWidth: 99, color: Color(hex: 0xB085FA), category: .artists),
//        .init(title: "Albums", icon: "square.stack.fill", iconSize: 14, buttonWidth: 103, color: Color(hex: 0xFF999A), category: .albums),
//        .init(title: "Tracks", icon: "music.note", iconSize: 14, buttonWidth: 90, color: Color(hex: 0xF1CD41), category: .tracks),
//        .init(title: "Music Videos", icon: "play.rectangle.fill", iconSize: 14, buttonWidth: 146, color: Color(hex: 0x6AD7B3), category: .musicVideos),
//        .init(title: "Playlists", icon: "star.square.on.square.fill", iconSize: 14, buttonWidth: 113, color: Color(hex: 0x5AA3FF), category: .playlists)
//    ]
//
//    // helper to map your category -> vm.scope
//    private func applyScope(for category: SearchCategory) {
//        switch category {
//        case .artists:      vm.scope = .artist
//        case .albums:       vm.scope = .album
//        case .tracks:       vm.scope = .song
//        case .musicVideos:  vm.scope = .musicVideo
//        case .playlists:    vm.scope = .playlist
//        }
//    }
//    
//    let idSearchFilters: [Int: String] = [
//        0: "Artists",
//        1: "Albums",
//        2: "Tracks",
//        3: "Music Videos",
//        4: "Playlists"
//    ]
//    
//    let idSearchCategories: [Int: SearchCategory] = [
//        0: .artists,
//        1: .albums,
//        2: .tracks,
//        3: .musicVideos,
//        4: .playlists
//    ]
//
//    var body: some View {
//        ZStack {
//            if isSimulator {
//                NativeTabView()
//                    .accentColor(Color(hex: 0xEE34F2))
//                    .colorScheme(.dark)
//                    .tabViewBottomAccessory {
//                        MiniPlayerView()
//                            .matchedTransitionSource(id: "MINIPLAYER", in: animation)
//                            .frame(maxWidth: .infinity)
//                    }
//                    .fullScreenCover(isPresented: $expandMiniPlayer) {
//                        VStack(spacing: 10) {
//                            /// Drag Indicator Mimick
//                            Capsule()
//                                .fill(.primary.secondary)
//                                .frame(width: 35, height: 3)
//                            
//                            HStack(spacing: 0) {
//                                PlayerInfo(width: 80, height: 80, font: 18)
//                                
//                                Spacer(minLength: 0)
//                                
//                                /// Expanded Actions
//                                Group {
//                                    Button("", systemImage: "star.circle.fill") {
//                                        
//                                    }
//                                    
//                                    Button("", systemImage: "ellipsis.circle.fill") {
//                                        
//                                    }
//                                }
//                                .font(.title)
//                                .foregroundStyle(Color.primary, Color.primary.opacity(0.1))
//                            }
//                            .padding(.horizontal, 15)
//                        }
//                        .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
//                    }
//            } else {
//                NativeTabView()
//                    .welcomeSheet()
//                    .accentColor(Color(hex: 0xFF073B))
//                    .colorScheme(.dark)
//                    .tabViewBottomAccessory {
//                        MiniPlayerView()
//                            .matchedTransitionSource(id: "MINIPLAYER", in: animation)
//                            .frame(maxWidth: .infinity)
//                    }
//                    .fullScreenCover(isPresented: $expandMiniPlayer) {
//                        VStack(spacing: 10) {
//                            /// Drag Indicator Mimick
//                            Capsule()
//                                .fill(.primary.secondary)
//                                .frame(width: 35, height: 3)
//                            
//                            HStack(spacing: 0) {
//                                PlayerInfo(width: 80, height: 80, font: 18)
//                                
//                                Spacer(minLength: 0)
//                                
//                                /// Expanded Actions
//                                Group {
//                                    Button("", systemImage: "star.circle.fill") {
//                                        
//                                    }
//                                    
//                                    Button("", systemImage: "ellipsis.circle.fill") {
//                                        
//                                    }
//                                }
//                                .font(.title)
//                                .foregroundStyle(Color.primary, Color.primary.opacity(0.1))
//                            }
//                            .padding(.horizontal, 15)
//                        }
//                        .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
//                    }
//            }
//            VStack {
//                HStack {
//                    Spacer()
//                    Button {
//                        dismiss()
//                    } label: {
//                        Image(systemName: "xmark")
//                            .font(.system(size: 20, weight: .black))
//                            .foregroundColor(.white)
//                            .padding(.vertical, 5)
//                    }
//                    .buttonStyle(.glassProminent)
//                    .colorScheme(.dark)
//                }
//                Spacer()
//            }
//            .padding(.horizontal, 25)
//            .padding(.top, -10)
//        }
//    }
//    @ViewBuilder
//    func NativeTabView(_ safeAreaBottomPadding: CGFloat = 0) -> some View {
//        TabView {
//            Tab.init("Home", systemImage: "house.fill") {
//                NavigationStack {
//                    ZStack {
//                        LinearGradient(colors: [Color(hex: 0xAE2FDC), Color(hex: 0x54169B), Color(hex: 0x311691)], startPoint: .topLeading, endPoint: .bottomTrailing)
//                            .ignoresSafeArea()
//                    }
//                }
//            }
//            
//            Tab.init("Feed", systemImage: "ellipsis.bubble.fill") {
//                NavigationStack {
//                    ZStack {
//                        LinearGradient(colors: [Color(hex: 0xAE2FDC), Color(hex: 0x54169B), Color(hex: 0x311691)], startPoint: .topLeading, endPoint: .bottomTrailing)
//                            .ignoresSafeArea()
//                    }
//                }
//            }
//            
//            Tab.init("Playlists", systemImage: "music.note.list") {
//                NavigationStack {
//                    ZStack {
//                        LinearGradient(colors: [Color(hex: 0xAE2FDC), Color(hex: 0x54169B), Color(hex: 0x311691)], startPoint: .topLeading, endPoint: .bottomTrailing)
//                            .ignoresSafeArea()
//                    }
//                }
//            }
//            
//            Tab("Search", systemImage: "magnifyingglass", role: .search) {
//                
//                NavigationStack {
//                    ZStack {
//                        LinearGradient(colors: [Color(hex: 0xAE2FDC), Color(hex: 0x54169B), Color(hex: 0x311691)], startPoint: .topLeading, endPoint: .bottomTrailing)
//                            .ignoresSafeArea()
//                        VStack(spacing: 0) {
//                            VStack(spacing: 0) {
//                                let original = searchFilters
//                                let realCount = original.count
//
//                                if realCount == 0 {
//                                    Text("no search filters yet")
//                                        .font(.custom("Nunito-Black", size: 16))
//                                        .foregroundStyle(Color(hex: 0x9E9E9C))
//                                        .padding(.vertical, 24)
//                                } else {
//                                    VStack(spacing: 16) {
//                                        ZStack {
//                                            GeometryReader { proxy in
//                                                let spacing: CGFloat = 30
//                                                
//                                                ScrollView(.horizontal, showsIndicators: false) {
//                                                    
//                                                    LazyHStack(spacing: spacing) {
//                                                        ForEach(original.indices, id: \.self) { i in
//                                                            GeometryReader { geo in
//                                                                let frame = geo.frame(in: .named("carousel"))
//                                                                let mid = proxy.size.width / 2
//                                                                let distance = abs(frame.midX - mid)
//                                                                let scale = max(0.5, 1.0 - (distance / 800))
//                                                                let opacity = max(0.5, 1.0 - (distance / 600))
//                                                                
//                                                                let searchFilter = original[i]
//                                                                
//                                                                // ✅ center the button inside its 140pt-wide card
//                                                                ZStack {                                // keeps content centered in the item
//                                                                    Button {
//                                                                        
//                                                                    } label: {
//                                                                        HStack(spacing: 6) {
//                                                                            Image(systemName: searchFilter.icon)
//                                                                                .font(.system(size: searchFilter.iconSize, weight: .black))
//                                                                                .foregroundColor(.white)
//                                                                                .padding(.leading, 6)
//                                                                            Text(searchFilter.title)
//                                                                                .font(.custom("Nunito-Black", size: 15))
//                                                                                .foregroundColor(.white)
//                                                                                .padding(.vertical, 5)
//                                                                                .padding(.trailing, 6)
//                                                                        }
//                                                                        .frame(width: 140)
//                                                                    }
//                                                                    .tint(searchFilter.color)
//                                                                    .buttonStyle(.glassProminent)
//                                                                    .shadow(
//                                                                        color: Color(hex: 0xDB9BFF).opacity(
//                                                                            searchCategory == searchFilter.title ? 0.7 : 0.5
//                                                                        ),
//                                                                        radius: searchCategory == searchFilter.title ? 10 : 6, x: 0, y: 2
//                                                                    )
//                                                                }
//                                                                .scaleEffect(scale)
//                                                                .opacity(opacity)
//                                                            }
//                                                            .frame(width: 140, height: 40)
//                                                            .id(i)
//                                                        }
//                                                    }
//                                                    .scrollTargetLayout()
//                                                }
//                                                .contentMargins(.trailing, (proxy.size.width - 140) / 2)
//                                                .contentMargins(.leading, (proxy.size.width - 180) / 2)
//                                                .coordinateSpace(name: "carousel")
//                                                .scrollTargetBehavior(.viewAligned)
//                                                .scrollPosition(id: $activeIndex)
//                                            }
//                                            .onAppear {
//                                                activeIndex = 0
//                                            }
//                                            .onChange(of: activeIndex) { _, new in
//                                                withAnimation(.easeInOut(duration: 0.2)) {
//                                                    searchCategory = idSearchFilters[activeIndex ?? 0] ?? "Artists"
//                                                    applyScope(for: idSearchCategories[activeIndex ?? 0] ?? .artists)
//                                                }
//                                                Task { await vm.search() }
//                                            }
//                                            
//                                            // INDICATOR DOTS (unchanged)
//                                            HStack(spacing: 8) {
//                                                let current = ((activeIndex ?? 0) + realCount) % realCount
//                                                ForEach(0..<realCount, id: \.self) { idx in
//                                                    Circle()
//                                                        .frame(width: idx == current ? 9 : 6, height: idx == current ? 9 : 6)
//                                                        .opacity(idx == current ? 1.0 : 0.35)
//                                                        .animation(.easeInOut(duration: 0.2), value: activeIndex)
//                                                }
//                                            }
//                                            .frame(maxWidth: .infinity, alignment: .center)
//                                            .padding(.top, 140)
//                                            
//                                            HStack(alignment: .center) {
//                                                Button {
//                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
//                                                        if activeIndex! > 0 {
//                                                            activeIndex = activeIndex! - 1
//                                                        }
//                                                    }
//                                                } label: {
//                                                    Image(systemName: "chevron.backward")
//                                                        .font(.system(size: 16, weight: .black))
//                                                        .frame(width: 25, height: 30)
//                                                }
//                                                .foregroundColor(Color(hex: 0x514343))
//                                                .tint(Color(hex: 0xFFFCF7))
//                                                .buttonStyle(.glassProminent)
//                                                
//                                                Spacer()
//                                                
//                                                Button {
//                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
//                                                        if activeIndex! < 4 {
//                                                            activeIndex = activeIndex! + 1
//                                                        }
//                                                    }
//                                                } label: {
//                                                    Image(systemName: "chevron.forward")
//                                                        .font(.system(size: 16, weight: .black))
//                                                        .frame(width: 25, height: 30)
//                                                }
//                                                .foregroundColor(Color(hex: 0x514343))
//                                                .tint(Color(hex: 0xFFFCF7))
//                                                .buttonStyle(.glassProminent)
//                                            }
//                                            .padding(.horizontal, 8)
//                                            .zIndex(100)
//                                        }
//                                    }
//                                }
//                            }
//                            .frame(height: 130)
//                            
//                            List {
//                                if vm.isLoading { ProgressView("searching…") }
//                                if let err = vm.errorMessage, !err.isEmpty { Text(err).foregroundStyle(.red) }
//                                
//                                switch vm.scope {
//                                case .song:
//                                    ForEach(vm.songResults, id: \.id) { song in
//                                        Button {
//                                            Task { await player.play(song) }
//                                        } label: {
//                                            HStack(spacing: 12) {
//                                                ArtworkView(artwork: song.artwork, size: 56)
//
//                                                VStack(alignment: .leading, spacing: 2) {
//                                                    Text(song.title)
//                                                        .font(.headline)
//                                                        .lineLimit(1)
//
//                                                    Text(song.artistName)
//                                                        .font(.subheadline)
//                                                        .foregroundStyle(.secondary)
//                                                        .lineLimit(1)
//                                                }
//
//                                                Spacer()
//
//                                                Button { Task { await player.play(song) }} label: {
//                                                    Image(systemName: "play.fill")
//                                                        .font(.system(size: 16, weight: .bold))
//                                                        .foregroundStyle(.white)
//                                                        .padding(10)
//                                                        .background(.tint, in: Circle())
//                                                }
//                                                .buttonStyle(.plain)
//                                            }
//                                        }
//                                        .foregroundColor(Color(hex: 0x514343))
//                                        .tint(Color(hex: 0xFFFCF7))
//                                        .buttonStyle(.glassProminent)
//                                    }
//                                    
//                                case .album:
//                                    ForEach(vm.albumResults, id: \.id) { album in
//                                        AlbumRow(album: album) { Task { await player.play(album) } }
//                                    }
//                                    
//                                case .artist:
//                                    ForEach(vm.artistResults, id: \.id) { artist in
//                                        ArtistRow(artist: artist)
//                                    }
//                                    
//                                case .musicVideo:
//                                    ForEach(vm.videoResults, id: \.id) { video in
//                                        MusicVideoRow(video: video, onPlayPreview: {
//                                        })
//                                    }
//                                    
//                                case .playlist:
//                                    ForEach(vm.playlistResults, id: \.id) { playlist in
//                                        PlaylistRow(playlist: playlist) { Task { await player.play(playlist) } }
//                                    }
//                                }
//                            }
//                            .colorScheme(.light)
//                            .listRowSeparator(.hidden)
//                            .listRowSpacing(5)
//                            .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
//                            .listSectionMargins(.horizontal, 0)
//                            .scrollContentBackground(.hidden)
//                            .searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .always),
//                                        prompt: "Search \(searchCategory)")
//                            .onSubmit(of: .search) {
//                                print("Search Submitted")
//                                Task {
//                                    await vm.search()
//                                }
//                            }
//                        }
//                        .toolbarVisibility(.hidden)
//                    }
//                }
//                .ignoresSafeArea()
//            }
//        }
//    }
//    
//    @ViewBuilder
//    func PlayerInfo(width: CGFloat, height: CGFloat, font: CGFloat) -> some View {
//        // prefer the explicit nowPlaying; fall back to what's actually in the queue
//        let playingSong: Song? = {
//            if let s = player.nowPlaying { return s }
//            if let entryItem = player.player.queue.currentEntry?.item as? Song { return entryItem }
//            return nil
//        }()
//
//        HStack(spacing: 12) {
//            if let song = playingSong {
//                ArtworkView(artwork: song.artwork, size: height)
//                VStack(alignment: .leading, spacing: -1) {
//                    Text(song.title)
//                        .font(.custom("Nunito-Black", size: font))
//                        .foregroundColor(.primary)
//                        .lineLimit(1)
//                    Text(song.artistName)
//                        .font(.custom("Nunito-Black", size: font * 0.8))
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
//                }
//            } else {
//                // placeholder when nothing queued
//                RoundedRectangle(cornerRadius: height / 4)
//                    .fill(.quaternary)
//                    .frame(width: width, height: height)
//                    .overlay(
//                        Image(systemName: "music.note")
//                            .font(.system(size: 12, weight: .black))
//                            .foregroundStyle(Color(hex: 0xA2A2A1))
//                    )
//                VStack(alignment: .leading, spacing: -1) {
//                    Text("Nothing Playing")
//                        .font(.custom("Nunito-Black", size: font))
//                        .foregroundColor(.primary)
//                        .lineLimit(1)
//                    Text("—")
//                        .font(.custom("Nunito-Black", size: font * 0.8))
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
//                }
//            }
//            Spacer()
//        }
//    }
//    
//    /// MiniPlayer View
//    @ViewBuilder
//    func MiniPlayerView() -> some View {
//        ZStack {
//            // 1) full-width transparent tap target (includes whitespace)
//            Color.clear
//                .contentShape(Rectangle())
//                .onTapGesture { withAnimation { expandMiniPlayer.toggle() } }
//
//            // 2) your visible row (non-interactive so taps fall through to #1)
//            HStack {
//                PlayerInfo(width: 30, height: 30, font: 12)
//                Spacer(minLength: 1)
//            }
//            .padding(.leading, 15)
//            .allowsHitTesting(false)
//
//            // 3) interactive play/pause over the top (does NOT toggle expand)
//            HStack {
//                Spacer()
//                Button {
//                    Task { await player.togglePlayPause() }
//                } label: {
//                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
//                        .foregroundStyle(.primary)
//                        .padding(.horizontal, 14)
//                        .padding(.vertical, 10)
//                }
//                .padding(.trailing, 16)
//                .disabled(player.player.queue.entries.isEmpty)
//            }
//        }
//    }
//}
//
//struct WelcomeView: View {
//    @Binding var musicAuthorizationStatus: MusicAuthorization.Status
//    @Environment(\.openURL) private var openURL
//    
//    var body: some View {
//        ZStack {
//            gradient
//            
//            VStack(spacing: 0) {
//                Spacer()
//                
//                VStack {
//                    VStack(spacing: 5) {
//                        ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 75, rectangleSpacing: 5, rectangleCornerRadius: 7, animationDuration: 0.9)
//                        Text("Ranko")
//                            .font(.custom("Nunito-Black", size: 40))
//                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFD358), Color(hex: 0xFFB753), Color(hex: 0xFF9B4F)], startPoint: .leading, endPoint: .trailing))
//                    }
//                    Text("x")
//                        .font(.custom("Nunito-Regular", size: 25))
//                    HStack(spacing: 4) {
//                        Image(systemName: "applelogo")
//                            .font(.system(size: 34, weight: .black, design: .default))
//                            .padding(.bottom, 3)
//                        Text("Music")
//                            .font(.custom("Nunito-Regular", size: 40))
//                    }
//                }
//                .padding(.bottom, 40)
//                
//                Text("Add songs, albums, artists, playlists, genres ++ from your Apple Music Library and the Apple Music Catalog to your Rankos.")
//                    .font(.custom("Nunito-Medium", size: 17))
//                    .multilineTextAlignment(.center)
//                    .padding(.bottom)
//                    .padding(.horizontal)
//                Spacer()
//                
//                if let secondaryExplanatoryText = self.secondaryExplanatoryText {
//                    secondaryExplanatoryText
//                        .foregroundColor(.primary)
//                        .font(.headline)
//                        .multilineTextAlignment(.center)
//                        .padding([.horizontal, .bottom])
//                }
//                
//                if musicAuthorizationStatus == .notDetermined || musicAuthorizationStatus == .denied {
//                    Button(action: handleButtonPressed) {
//                        buttonText
//                            .font(.custom("Nunito-Black", size: 17))
//                            .padding(.horizontal, 40)
//                            .padding(.vertical, 8)
//                    }
//                    .tint(Color(hex: 0x0E0F2D))
//                    .buttonStyle(.glassProminent)
//                    .colorScheme(.dark)
//                    .padding(.bottom)
//                }
//            }
//            .colorScheme(.dark)
//        }
//    }
//    
//    private var gradient: some View {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                Color(red: (222 / 255.0), green: (57 / 255.0), blue: (254 / 255.0)),
//                Color(red: (90 / 255.0), green: (21 / 255.0), blue: (157 / 255.0)),
//                Color(red: (45 / 255.0), green: (21 / 255.0), blue: (144 / 255.0))
//            ]),
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
//        .flipsForRightToLeftLayoutDirection(false)
//        .ignoresSafeArea()
//    }
//    
//    private var secondaryExplanatoryText: Text? {
//        var secondaryExplanatoryText: Text?
//        switch musicAuthorizationStatus {
//        case .denied:
//            secondaryExplanatoryText = Text("Please grant Musadora access to ")
//            + Text(Image(systemName: "applelogo")) + Text(" Music in Settings.")
//        default:
//            break
//        }
//        return secondaryExplanatoryText
//    }
//    
//    private var buttonText: Text {
//        let buttonText: Text
//        switch musicAuthorizationStatus {
//        case .notDetermined:
//            buttonText = Text("Continue")
//        case .denied:
//            buttonText = Text("Open Settings")
//        default:
//            fatalError("No button should be displayed for current authorization status: \(musicAuthorizationStatus).")
//        }
//        return buttonText
//    }
//    
//    private func handleButtonPressed() {
//        switch musicAuthorizationStatus {
//        case .notDetermined:
//            Task {
//                let musicAuthorizationStatus = await MusicAuthorization.request()
//                await update(with: musicAuthorizationStatus)
//                print("CASE 1")
//            }
//        case .denied:
//            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
//                openURL(settingsURL)
//                print("CASE 2")
//            }
//        default:
//            print("CASE 3")
//            fatalError("No button should be displayed for current authorization status: \(musicAuthorizationStatus).")
//        }
//    }
//    
//    @MainActor
//    private func update(with musicAuthorizationStatus: MusicAuthorization.Status) {
//        withAnimation {
//            self.musicAuthorizationStatus = musicAuthorizationStatus
//        }
//    }
//    
//    class PresentationCoordinator: ObservableObject {
//        static let shared = PresentationCoordinator()
//        
//        private init() {
//            let authorizationStatus = MusicAuthorization.currentStatus
//            
//            debugPrint(MusicAuthorization.currentStatus.rawValue)
//            
//            musicAuthorizationStatus = authorizationStatus
//            isWelcomeViewPresented = (authorizationStatus != .authorized)
//        }
//        
//        @Published var musicAuthorizationStatus: MusicAuthorization.Status {
//            didSet {
//                isWelcomeViewPresented = (musicAuthorizationStatus != .authorized)
//            }
//        }
//        
//        @Published var isWelcomeViewPresented: Bool
//    }
//    
//    fileprivate struct SheetPresentationModifier: ViewModifier {
//        @StateObject private var presentationCoordinator = PresentationCoordinator.shared
//        
//        func body(content: Content) -> some View {
//            content
//                .fullScreenCover(isPresented: $presentationCoordinator.isWelcomeViewPresented) {
//                    WelcomeView(musicAuthorizationStatus: $presentationCoordinator.musicAuthorizationStatus)
//                }
//        }
//    }
//}
//
//extension View {
//    func welcomeSheet() -> some View {
//        modifier(WelcomeView.SheetPresentationModifier())
//    }
//}
//
//@MainActor
//final class MusicSearchViewModel: ObservableObject {
//    enum Scope: String, CaseIterable {
//        case song = "Song"
//        case album = "Album"
//        case artist = "Artist"
//        case musicVideo = "Music Video"
//        case playlist = "Playlist"
//    }
//
//    @Published var query: String = ""
//    @Published var scope: Scope = .artist
//
//    // keep separate result buckets (use the one you need in UI)
//    @Published var songResults: [Song] = []
//    @Published var albumResults: [Album] = []
//    @Published var artistResults: [Artist] = []
//    @Published var videoResults: [MusicVideo] = []
//    @Published var playlistResults: [Playlist] = []
//
//    @Published var isLoading: Bool = false
//    @Published var errorMessage: String?
//
//    func search() async {
//        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !term.isEmpty else { clear(); return }
//
//        isLoading = true
//        errorMessage = nil
//        defer { isLoading = false }
//
//        do {
//            // choose static types based on the enum (NOT strings)
//            let requestedTypes: [any MusicCatalogSearchable.Type]
//            switch scope {
//            case .song:       requestedTypes = [Song.self]
//            case .album:      requestedTypes = [Album.self]
//            case .artist:     requestedTypes = [Artist.self]
//            case .musicVideo: requestedTypes = [MusicVideo.self]
//            case .playlist:   requestedTypes = [Playlist.self]
//            }
//
//            var request = MusicCatalogSearchRequest(term: term, types: requestedTypes)
//            request.limit = 25
//            let response = try await request.response()
//
//            clear() // wipe old buckets before filling the selected one
//
//            switch scope {
//            case .song:
//                songResults = Array(response.songs)
//            case .album:
//                albumResults = Array(response.albums)
//            case .artist:
//                artistResults = Array(response.artists)
//            case .musicVideo:
//                videoResults = Array(response.musicVideos)
//            case .playlist:
//                playlistResults = Array(response.playlists)
//            }
//        } catch {
//            errorMessage = "search failed: \(error.localizedDescription)"
//            clear()
//        }
//    }
//
//    private func clear() {
//        songResults = []
//        albumResults = []
//        artistResults = []
//        videoResults = []
//        playlistResults = []
//    }
//}
//
//
//struct Chip: View {
//    let title: String
//    let icon: String
//    let selected: Bool
//    let action: () -> Void
//
//    init(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) {
//        self.title = title; self.icon = icon; self.selected = selected; self.action = action
//    }
//
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 6) {
//                Image(systemName: icon)
//                    .font(.system(size: 14, weight: .black))
//                Text(title)
//                    .font(.custom("Nunito-Black", size: 15))
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//            .background(selected ? Color.black : Color.white, in: Capsule())
//            .foregroundStyle(selected ? Color.white : Color.black)
//        }
//        .buttonStyle(.plain)
//        .animation(.easeInOut(duration: 0.2), value: selected)
//    }
//}
//
//@MainActor
//final class PlayerManager: ObservableObject {
//    let player = ApplicationMusicPlayer.shared
//    @Published var nowPlaying: Song?
//    @Published var isPlaying: Bool = false
//
//    func play(_ song: Song) async {
//        do {
//            player.queue = ApplicationMusicPlayer.Queue(for: [song])
//            nowPlaying = song
//            try await player.play()
//            isPlaying = true
//        } catch { print("Failed to play: \(error)") }
//    }
//
//    func play(_ album: Album) async {
//        do {
//            player.queue = ApplicationMusicPlayer.Queue(for: [album])
//            try await player.play()
//            isPlaying = true
//        } catch { print("Failed to play album: \(error)") }
//    }
//
//    func play(_ playlist: Playlist) async {
//        do {
//            player.queue = ApplicationMusicPlayer.Queue(for: [playlist])
//            try await player.play()
//            isPlaying = true
//        } catch { print("Failed to play playlist: \(error)") }
//    }
//
//    func play(_ video: MusicVideo) async {
//        do {
//            
//        } catch { print("Failed to play video: \(error)") }
//    }
//
//    func togglePlayPause() async {
//        do {
//            if isPlaying {
//                try await player.pause()
//                isPlaying = false
//            } else {
//                try await player.play()
//                isPlaying = true
//            }
//        } catch { print("Play/Pause failed: \(error)") }
//    }
//
//    func stop() {
//        player.stop()
//        isPlaying = false
//    }
//}
//
//@MainActor
//final class MusicAuthManager: ObservableObject {
//    @Published var status: MusicAuthorization.Status = .notDetermined
//    @Published var canPlayCatalog: Bool = false
//
//    func ensureAuthorized() async {
//        // If not determined, request.
//        let current = await MusicAuthorization.currentStatus
//        if current == .notDetermined {
//            status = await MusicAuthorization.request()
//        } else {
//            status = current
//        }
//
//        // Check subscription/capabilities (user must be an Apple Music subscriber to stream).
//        do {
//            let capabilities = try await MusicSubscription.current
//            canPlayCatalog = capabilities.canPlayCatalogContent
//        } catch {
//            // If this fails, default to false; user may still browse local library if you add that later.
//            canPlayCatalog = false
//        }
//    }
//
//    var isAuthorizedForCatalog: Bool {
//        status == .authorized && canPlayCatalog
//    }
//}
//
//struct ArtistRow: View {
//    let artist: Artist
//    var body: some View {
//        HStack(spacing: 12) {
//            ArtworkView(artwork: artist.artwork, size: 56)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(artist.name)
//                    .font(.headline).lineLimit(1)
//                if let genres = artist.genreNames, !genres.isEmpty {
//                    Text(genres.joined(separator: ", "))
//                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
//                }
//            }
//            Spacer()
//        }
//        .contentShape(Rectangle())
//    }
//}
//
//struct AlbumRow: View {
//    let album: Album
//    var onPlay: () -> Void
//    var body: some View {
//        HStack(spacing: 12) {
//            ArtworkView(artwork: album.artwork, size: 56)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(album.title).font(.headline).lineLimit(1)
//                Text(album.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
//            }
//            Spacer()
//            Button(action: onPlay) {
//                Image(systemName: "play.fill")
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundStyle(.white)
//                    .padding(10)
//                    .background(.tint, in: Circle())
//            }
//            .buttonStyle(.plain)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture(perform: onPlay)
//    }
//}
//
//struct PlaylistRow: View {
//    let playlist: Playlist
//    var onPlay: () -> Void
//    var body: some View {
//        HStack(spacing: 12) {
//            ArtworkView(artwork: playlist.artwork, size: 56)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(playlist.name).font(.headline).lineLimit(1)
//                Text(playlist.curatorName ?? "Playlist")
//                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
//            }
//            Spacer()
//            Button(action: onPlay) {
//                Image(systemName: "play.fill")
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundStyle(.white)
//                    .padding(10)
//                    .background(.tint, in: Circle())
//            }
//            .buttonStyle(.plain)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture(perform: onPlay)
//    }
//}
//
//struct MusicVideoRow: View {
//    let video: MusicVideo
//    var onPlayPreview: () -> Void
//
//    var body: some View {
//        HStack(spacing: 12) {
//            ArtworkView(artwork: video.artwork, size: 56)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(video.title).font(.headline).lineLimit(1)
//                Text(video.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
//            }
//            Spacer()
//            Button {
//                onPlayPreview()
//            } label: {
//                Image(systemName: "play.rectangle.fill")
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundStyle(.white)
//                    .padding(10)
//                    .background(.tint, in: Circle())
//            }
//            .buttonStyle(.plain)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture {
//            onPlayPreview()
//        }
//    }
//}
//
//struct ArtworkView: View {
//    let artwork: Artwork?
//    let size: CGFloat
//
//    var body: some View {
//        Group {
//            if let url = artwork?.url(width: Int(size * 2), height: Int(size * 2)) {
//                AsyncImage(url: url) { image in
//                    image
//                        .resizable()
//                        .scaledToFill()
//                } placeholder: {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 8)
//                            .fill(.quaternary)
//                        ProgressView()
//                    }
//                }
//            } else {
//                ZStack {
//                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
//                    Image(systemName: "music.note")
//                        .font(.title3)
//                        .foregroundStyle(.secondary)
//                }
//            }
//        }
//        .frame(width: size, height: size)
//        .clipShape(RoundedRectangle(cornerRadius: 8))
//    }
//}
//
//struct SongRow: View {
//    let song: Song
//    var onPlay: () -> Void
//
//    var body: some View {
//        Button {
//            onPlay()
//        } label: {
//            HStack(spacing: 12) {
//                ArtworkView(artwork: song.artwork, size: 56)
//
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(song.title)
//                        .font(.headline)
//                        .lineLimit(1)
//
//                    Text(song.artistName)
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                        .lineLimit(1)
//                }
//
//                Spacer()
//
//                Button(action: onPlay) {
//                    Image(systemName: "play.fill")
//                        .font(.system(size: 16, weight: .bold))
//                        .foregroundStyle(.white)
//                        .padding(10)
//                        .background(.tint, in: Circle())
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .foregroundColor(Color(hex: 0x514343))
//        .tint(Color(hex: 0xFFFCF7))
//        .buttonStyle(.glassProminent)
//        .listRowBackground(
//            RoundedRectangle(cornerRadius: 10)
//                .fill(Color(hex: 0xFFFCF7))
//        )
//    }
//}
//
//public typealias Songs = MusicItemCollection<Song>
//
//#Preview {
//    AppleMusicView()
//        .environmentObject(PlayerManager())
//}
