//
//  AppleMusic.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 31/8/2025.
//

import SwiftUI
import StoreKit
import MusicKit
import MediaPlayer
import Foundation
import Combine
import AVKit

//struct AppleMusicView: View {
//    @State private var searchText: String = ""
//    @State private var expandMiniPlayer: Bool = false
//    @State private var searchResults: [Song] = []
//    @State private var searchCategory: String = "Artists"
//    @State private var screenWidth: CGFloat = 0
//    
//    @FocusState private var searchFocus: Bool
//    @StateObject private var vm = MusicSearchViewModel()
//    @EnvironmentObject private var auth: MusicAuthManager
//    @EnvironmentObject private var player: PlayerManager
//    @Namespace private var animation
//    var body: some View {
//        NativeTabView()
//            .task { await auth.ensureAuthorized() }
//            .tabViewBottomAccessory {
//                MiniPlayerView()
//                    .matchedTransitionSource(id: "MINIPLAYER", in: animation)
//                    .frame(maxWidth: .infinity)
//            }
//            .fullScreenCover(isPresented: $expandMiniPlayer) {
//                VStack(spacing: 10) {
//                    /// Drag Indicator Mimick
//                    Capsule()
//                        .fill(.primary.secondary)
//                        .frame(width: 35, height: 3)
//                    
//                    HStack(spacing: 0) {
//                        PlayerInfo(width: 80, height: 80, font: 18)
//                        
//                        Spacer(minLength: 0)
//                        
//                        /// Expanded Actions
//                        Group {
//                            Button("", systemImage: "star.circle.fill") {
//                                
//                            }
//                            
//                            Button("", systemImage: "ellipsis.circle.fill") {
//                                
//                            }
//                        }
//                        .font(.title)
//                        .foregroundStyle(Color.primary, Color.primary.opacity(0.1))
//                    }
//                    .padding(.horizontal, 15)
//                }
//                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
//            }
//            .ignoresSafeArea()
//    }
//    
//    /// Let's First Start with TabView
//    @ViewBuilder
//    func NativeTabView(_ safeAreaBottomPadding: CGFloat = 0) -> some View {
//        TabView {
//            Tab.init("Home", systemImage: "house.fill") {
//                NavigationStack {
//                    ZStack {
//                        Color(hex: 0xFFFFFF)
//                            .ignoresSafeArea()
//                        ScrollView(.vertical) {
//                            VStack(spacing: 10) {
//                                HStack {
//                                    Text("Explore")
//                                        .font(.custom("Nunito-Black", size: 36))
//                                        .foregroundStyle(Color(hex: 0x514343))
//                                    Spacer()
//                                }
//                                .padding(.horizontal, 30)
//                                .padding(.top, 10)
//                                
//                                ScrollView(.horizontal, showsIndicators: false) {
//                                }
//                            }
//                        }
//                    }
//                    .navigationBarHidden(true)
//                }
//            }
//            
//            Tab.init("New", systemImage: "star.fill") {
//                NavigationStack {
//                    ZStack {
//                        Color(hex: 0xFFFFFF)
//                            .ignoresSafeArea()
//                        ScrollView(.vertical) {
//                            VStack(spacing: 10) {
//                                HStack {
//                                    Text("Explore")
//                                        .font(.custom("Nunito-Black", size: 36))
//                                        .foregroundStyle(Color(hex: 0x514343))
//                                    Spacer()
//                                }
//                                .padding(.horizontal, 30)
//                                .padding(.top, 10)
//                                
//                                ScrollView(.horizontal, showsIndicators: false) {
//                                }
//                            }
//                        }
//                    }
//                    .navigationBarHidden(true)
//                }
//            }
//            
//            Tab.init("Playlists", systemImage: "music.note.list") {
//                NavigationStack {
//                    LibraryPlaylistsView()
//                        .navigationTitle("Playlists")
//                        .navigationBarTitleDisplayMode(.large)
//                        .background(Color(hex: 0xFFFFFF).ignoresSafeArea())
//                }
//            }
//            
//            Tab("Search", systemImage: "magnifyingglass", role: .search) {
//                NavigationStack {
//                    VStack(spacing: 0) {
//                        VStack(spacing: 0) {
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                HStack(spacing: 8) {
//                                    Chip("Artists", icon: "music.mic", selected: searchCategory == "Artists") {
//                                        withAnimation { searchCategory = "Artists"; vm.scope = .artist; searchFocus = true }
//                                        Task { await vm.search() }
//                                    }
//                                    Chip("Albums", icon: "smallcircle.circle.fill", selected: searchCategory == "Albums") {
//                                        withAnimation { searchCategory = "Albums"; vm.scope = .album; searchFocus = true }
//                                        Task { await vm.search() }
//                                    }
//                                    Chip("Tracks", icon: "music.note", selected: searchCategory == "Tracks") {
//                                        withAnimation { searchCategory = "Tracks"; vm.scope = .song; searchFocus = true }
//                                        Task { await vm.search() }
//                                    }
//                                    Chip("Music Videos", icon: "play.rectangle.fill", selected: searchCategory == "Music Videos") {
//                                        withAnimation { searchCategory = "Music Videos"; vm.scope = .musicVideo; searchFocus = true }
//                                        Task { await vm.search() }
//                                    }
//                                    Chip("Playlists", icon: "star.square.on.square.fill", selected: searchCategory == "Playlists") {
//                                        withAnimation { searchCategory = "Playlists"; vm.scope = .playlist; searchFocus = true }
//                                        Task { await vm.search() }
//                                    }
//                                }
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 6)
//                            }
//                        }
//                        .padding(.top, 10)
//                        List {
//                            if vm.isLoading { ProgressView("searching…") }
//                            if let err = vm.errorMessage, !err.isEmpty { Text(err).foregroundStyle(.red) }
//
//                            switch vm.scope {
//                            case .song:
//                                ForEach(vm.songResults, id: \.id) { song in
//                                    SongRow(song: song) { Task { await player.play(song) } }
//                                }
//
//                            case .album:
//                                ForEach(vm.albumResults, id: \.id) { album in
//                                    AlbumRow(album: album) { Task { await player.play(album) } }
//                                }
//
//                            case .artist:
//                                ForEach(vm.artistResults, id: \.id) { artist in
//                                    ArtistRow(artist: artist)
//                                }
//
//                            case .musicVideo:
//                                ForEach(vm.videoResults, id: \.id) { video in
//                                    MusicVideoRow(video: video, onPlayPreview: {
//                                    })
//                                }
//
//                            case .playlist:
//                                ForEach(vm.playlistResults, id: \.id) { playlist in
//                                    PlaylistRow(playlist: playlist) { Task { await player.play(playlist) } }
//                                }
//                            }
//                        }
//                        .listStyle(.plain)
//                        .searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .always),
//                                    prompt: "Search \(searchCategory)")
//                        .focused($searchFocus)
//                        .onSubmit(of: .search) {
//                            print("Search Submitted")
//                            Task {
//                                await vm.search()
//                            }
//                        }
//                    }
//                    .toolbarVisibility(.hidden)
//                }
//                .ignoresSafeArea()
//            }
//        }
//        .accentColor(Color(hex: 0xFF073B))
//        .ignoresSafeArea()
//    }
//    /// Resuable Player Info
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
//                        .foregroundColor(Color(hex: 0x000000))
//                        .lineLimit(1)
//                    Text(song.artistName)
//                        .font(.custom("Nunito-Black", size: font * 0.8))
//                        .foregroundColor(Color(hex: 0xA2A2A1))
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
//                        .foregroundColor(Color(hex: 0x000000))
//                        .lineLimit(1)
//                    Text("—")
//                        .font(.custom("Nunito-Black", size: font * 0.8))
//                        .foregroundColor(Color(hex: 0xA2A2A1))
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
//        HStack(spacing: 12) {
//            ArtworkView(artwork: song.artwork, size: 56)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(song.title)
//                    .font(.headline)
//                    .lineLimit(1)
//
//                Text(song.artistName)
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                    .lineLimit(1)
//            }
//
//            Spacer()
//
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
//
//// MARK: - Library Playlists (List)
//@MainActor
//final class LibraryPlaylistsViewModel: ObservableObject {
//    @Published var playlists: [Playlist] = []
//    @Published var isLoading = false
//    @Published var error: String?
//
//    func load() async {
//        isLoading = true; error = nil
//        defer { isLoading = false }
//        do {
//            var req = MusicLibraryRequest<Playlist>()
//            req.limit = 100
//            let resp = try await req.response()
//            playlists = Array(resp.items)
//        } catch {
//            self.error = "couldn't load playlists: \(error.localizedDescription)"
//            playlists = []
//        }
//    }
//}
//
//struct LibraryPlaylistsView: View {
//    @EnvironmentObject private var auth: MusicAuthManager
//    @EnvironmentObject private var player: PlayerManager
//    @StateObject private var vm = LibraryPlaylistsViewModel()
//
//    var body: some View {
//        Group {
//            if !auth.isAuthorizedForCatalog {
//                VStack(spacing: 12) {
//                    Text("sign in to apple music")
//                        .font(.title3).bold()
//                    Text("we need permission to show your playlists.")
//                        .foregroundStyle(.secondary)
//                    Button("Authorize") {
//                        Task {
//                            await auth.ensureAuthorized()
//                            if auth.isAuthorizedForCatalog { await vm.load() }
//                        }
//                    }
//                    .buttonStyle(.borderedProminent)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color(hex: 0xFFFFFF))
//            } else {
//                List {
//                    if vm.isLoading { ProgressView("loading playlists…") }
//                    if let err = vm.error { Text(err).foregroundStyle(.red) }
//
//                    ForEach(vm.playlists, id: \.id) { pl in
//                        NavigationLink {
//                            LibraryPlaylistDetailView(playlist: pl)
//                        } label: {
//                            LibraryPlaylistRow(playlist: pl) {
//                                Task { await player.play(pl) }
//                            }
//                        }
//                    }
//                }
//                .listStyle(.plain)
//            }
//        }
//        .task {
//            await auth.ensureAuthorized()
//            if auth.isAuthorizedForCatalog { await vm.load() }
//        }
//    }
//}
//
//struct LibraryPlaylistRow: View {
//    let playlist: Playlist
//    var onPlay: () -> Void
//    var body: some View {
//        HStack(spacing: 12) {
//            ArtworkView(artwork: playlist.artwork, size: 56)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(playlist.name).font(.headline).lineLimit(1)
//                if let curator = playlist.curatorName {
//                    Text(curator).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
//                } else {
//                    Text("Playlist").font(.subheadline).foregroundStyle(.secondary)
//                }
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
//    }
//}
//
//// MARK: - Library Playlist Detail (Tracks)
//@MainActor
//final class LibraryPlaylistsViewModel: ObservableObject {
//    @Published var songs: [Song] = []
//    @Published var isLoading = false
//    @Published var error: String?
//
//    func load() async {
//        isLoading = true; error = nil
//        defer { isLoading = false }
//        do {
//            var req = MusicLibraryRequest<Playlist>()
//            req.limit = 100
//            let resp = try await req.response()
//            playlists = Array(resp.items)
//        } catch {
//            self.error = "couldn't load playlists: \(error.localizedDescription)"
//            playlists = []
//        }
//    }
//}
//
//@MainActor
//final class PlaylistTracksViewModel: ObservableObject {
//    @Published var songs: [Song] = []
//    @Published var isLoading = false
//    @Published var error: String?
//
//    func loadTracks(for playlist: Playlist) async {
//        isLoading = true
//        error = nil
////        defer { isLoading = false }
////
////        do {
////            // hydrate the library playlist's tracks
////            let hydrated = try await playlist.with([.tracks])
////            songs = Array(hydrated.tracks ?? [])
////        } catch {
////            error = "couldn't load tracks: \(error.localizedDescription)"
////            songs = []
////        }
//        
//        func load(for playlist: Playlist) async {
//            isLoading = true; error = nil
//            defer { isLoading = false }
//            do {
//                var req = MusicItemCollection<Playlist.Entry>?
//                req.limit = 100
//                let resp = try await req.response()
//                songs = Array(resp.items)
//            } catch {
//                self.error = "couldn't load playlists: \(error.localizedDescription)"
//                songs = []
//            }
//        }
//    }
//}
//
//struct LibraryPlaylistDetailView: View {
//    let playlist: Playlist
//    @EnvironmentObject private var player: PlayerManager
//    @StateObject private var vm = PlaylistTracksViewModel()
//
//    var body: some View {
//        List {
//            Section {
//                HStack {
//                    ArtworkView(artwork: playlist.artwork, size: 64)
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(playlist.name).font(.title3).bold().lineLimit(2)
//                        Text("Apple Music • \(vm.songs.count) tracks")
//                            .foregroundStyle(.secondary).font(.subheadline)
//                    }
//                    Spacer()
//                    Button {
//                        Task { await player.play(playlist) }
//                    } label: {
//                        Label("Play", systemImage: "play.fill")
//                            .labelStyle(.iconOnly)
//                            .font(.system(size: 18, weight: .bold))
//                            .foregroundStyle(.white)
//                            .padding(12)
//                            .background(.tint, in: Circle())
//                    }
//                    .buttonStyle(.plain)
//                }
//                .padding(.vertical, 4)
//            }
//
//            if vm.isLoading { ProgressView("loading songs…") }
//            if let err = vm.error { Text(err).foregroundStyle(.red) }
//
//            ForEach(vm.songs, id: \.id) { song in
//                SongRow(song: song) {
//                    Task { await player.play(song) }
//                }
//            }
//        }
//        .listStyle(.plain)
//        .navigationTitle(playlist.name)
//        .navigationBarTitleDisplayMode(.inline)
//        .task { await vm.loadTracks(for: playlist) }
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
//            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 0)
//        }
//        .buttonStyle(.plain)
//        .animation(.easeInOut(duration: 0.2), value: selected)
//    }
//}
//
//
//#Preview {
//    AppleMusicView()
//        .environmentObject(MusicAuthManager())
//        .environmentObject(PlayerManager())
//}
