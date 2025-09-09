//
//  Spotify.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 9/9/2025.
//

//  Spotify SwiftUI Starter (PKCE + Search + Previews)
//  Works with: Spotify Web API using Authorization Code + PKCE
//  Features: Artist/Album/Track search, Artist detail, Album detail, User Playlists,
//            30s preview playback with AVPlayer when available, deep link fallback
//
//  ⛳ Setup
//  1) In the Spotify Developer Dashboard, create an app and copy your CLIENT ID.
//  2) Add a redirect URI that matches the one below (edit to your scheme):
//     ranko-spotify://callback
//  3) In Xcode > Info.plist:
//     - LSApplicationQueriesSchemes: [ "spotify" ]
//     - CFBundleURLTypes -> CFBundleURLSchemes: [ "ranko-spotify" ]
//  4) Replace SpotifyConfig.clientID and SpotifyConfig.redirectURI with yours.
//  5) Run. Tap “Log in with Spotify”, approve scopes, and explore.
//
//  Notes
//  • Some tracks no longer expose preview_url. The UI below gracefully falls back
//    to an “Open in Spotify” deep link when preview is unavailable.
//  • Scopes requested: user-read-email, playlist-read-private, playlist-read-collaborative
//  • Market is set to "AU" for top tracks; change if needed.

import SwiftUI
import Combine
import AVFoundation
import AuthenticationServices

// MARK: - Config
struct SpotifyConfig {
    static let clientID: String = Secrets.spotifyClientID // <- replace
    static let redirectURI: URL = URL(string: "ranko-spotify://callback")! // <- replace
    static let authURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    static let apiBase = URL(string: "https://api.spotify.com/v1")!
    static let defaultMarket = "AU"
}

// MARK: - Auth State
@MainActor
final class SpotifyAuth: NSObject, ObservableObject {
    @Published private(set) var accessToken: String? = nil
    @Published private(set) var refreshToken: String? = nil
    @Published private(set) var expirationDate: Date? = nil
    @Published var isAuthorized: Bool = false

    private var codeVerifier: String = ""
    private var authSession: ASWebAuthenticationSession? = nil

    override init() {
        super.init()
        // Restore from UserDefaults for demo convenience
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token"),
           let refresh = UserDefaults.standard.string(forKey: "spotify_refresh_token"),
           let exp = UserDefaults.standard.object(forKey: "spotify_expiration") as? Date {
            self.accessToken = token
            self.refreshToken = refresh
            self.expirationDate = exp
            self.isAuthorized = Date() < exp
        }
    }

    // MARK: Public API
    func signIn(scopes: [String]) {
        codeVerifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: codeVerifier)

        var comps = URLComponents(url: SpotifyConfig.authURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI.absoluteString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
        ]

        guard let url = comps.url else { return }

        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: SpotifyConfig.redirectURI.scheme) { [weak self] callBackURL, error in
            guard let self else { return }
            if let callBackURL {
                self.handleCallback(url: callBackURL)
            } else {
                print("Auth canceled or failed: \(String(describing: error))")
            }
        }
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }

    func handleCallback(url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else { return }
        Task { await exchangeCodeForToken(code: code) }
    }

    func ensureValidToken() async throws -> String {
        if let exp = expirationDate, Date() >= exp.addingTimeInterval(-60) {
            try await refreshAccessToken()
        }
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        return token
    }

    // MARK: Token Exchange
    private func exchangeCodeForToken(code: String) async {
        var req = URLRequest(url: SpotifyConfig.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": SpotifyConfig.clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI.absoluteString,
            "code_verifier": codeVerifier
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
        .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            self.accessToken = token.access_token
            self.refreshToken = token.refresh_token
            self.expirationDate = Date().addingTimeInterval(TimeInterval(token.expires_in))
            self.isAuthorized = true
            persist()
        } catch {
            print("Token exchange failed: \(error)")
        }
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken else { throw URLError(.userAuthenticationRequired) }

        var req = URLRequest(url: SpotifyConfig.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": SpotifyConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
        .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        self.accessToken = token.access_token
        if let newRefresh = token.refresh_token { self.refreshToken = newRefresh }
        self.expirationDate = Date().addingTimeInterval(TimeInterval(token.expires_in))
        self.isAuthorized = true
        persist()
    }

    private func persist() {
        UserDefaults.standard.setValue(accessToken, forKey: "spotify_access_token")
        UserDefaults.standard.setValue(refreshToken, forKey: "spotify_refresh_token")
        UserDefaults.standard.setValue(expirationDate, forKey: "spotify_expiration")
    }

    // MARK: PKCE Helpers
    private static func generateCodeVerifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = verifier.data(using: .ascii)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        let hashed = Data(hash)
        return hashed.base64EncodedString(options: [.endLineWithLineFeed])
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Crypto import (CommonCrypto shim)
import CommonCrypto

// MARK: - Token DTO
struct TokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
}

// MARK: - API Client
@MainActor
final class SpotifyAPI: ObservableObject {
    private let auth: SpotifyAuth

    init(auth: SpotifyAuth) { self.auth = auth }

    private func request<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var comps = URLComponents(url: SpotifyConfig.apiBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        let token = try await auth.ensureValidToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: Search
    func searchArtists(_ q: String, limit: Int = 25) async throws -> Paging<Artist> {
        let res: SearchArtistsResponse = try await request("search", query: ["q": q, "type": "artist", "limit": String(limit)])
        return res.artists
    }
    func searchAlbums(_ q: String, limit: Int = 25) async throws -> Paging<Album> {
        let res: SearchAlbumsResponse = try await request("search", query: ["q": q, "type": "album", "limit": String(limit)])
        return res.albums
    }
    func searchTracks(_ q: String, limit: Int = 25) async throws -> Paging<Track> {
        let res: SearchTracksResponse = try await request("search", query: ["q": q, "type": "track", "limit": String(limit)])
        return res.tracks
    }

    // MARK: Entities
    func getArtist(_ id: String) async throws -> Artist { try await request("artists/\(id)") }
    func getArtistAlbums(_ id: String, includeGroups: String = "album,single,appears_on,compilation", limit: Int = 25) async throws -> Paging<Album> {
        try await request("artists/\(id)/albums", query: ["include_groups": includeGroups, "market": SpotifyConfig.defaultMarket, "limit": String(limit)])
    }
    func getArtistTopTracks(_ id: String) async throws -> TopTracksResponse {
        try await request("artists/\(id)/top-tracks", query: ["market": SpotifyConfig.defaultMarket])
    }
    func getAlbum(_ id: String) async throws -> Album { try await request("albums/\(id)") }
    func getAlbumTracks(_ id: String, limit: Int = 50) async throws -> Paging<Track> {
        try await request("albums/\(id)/tracks", query: ["limit": String(limit), "market": SpotifyConfig.defaultMarket])
    }

    // MARK: Me / Playlists
    func getMyPlaylists(limit: Int = 25) async throws -> Paging<Playlist> {
        try await request("me/playlists", query: ["limit": String(limit)])
    }
    func getPlaylistItems(_ id: String, limit: Int = 50) async throws -> PlaylistTracksResponse {
        try await request("playlists/\(id)/tracks", query: ["limit": String(limit)])
    }
    func getTrack(_ id: String) async throws -> Track { try await request("tracks/\(id)") }
}

// MARK: - Models (trimmed to fields we use)
struct Paging<T: Decodable>: Decodable { let items: [T] }

struct ExternalURL: Decodable { let spotify: String? }
struct SpotifyImage: Decodable { let url: String; let width: Int?; let height: Int? }

struct Artist: Decodable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]? // artist images
    let genres: [String]?
    let followers: Followers?
    let externalUrls: ExternalURL?
}
struct Followers: Decodable { let total: Int }

struct Album: Decodable, Identifiable {
    let id: String
    let name: String
    let releaseDate: String?
    let images: [SpotifyImage]?
    let artists: [ArtistSimplified]?
}
struct ArtistSimplified: Decodable, Identifiable { let id: String; let name: String }

struct Track: Decodable, Identifiable {
    let id: String
    let name: String
    let previewUrl: String? // may be null in many cases
    let uri: String
    let durationMs: Int?
    let album: AlbumSimplified?
    let artists: [ArtistSimplified]?
}
struct AlbumSimplified: Decodable, Identifiable { let id: String; let name: String; let images: [SpotifyImage]? }

struct Playlist: Decodable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let owner: PlaylistOwner?
}
struct PlaylistOwner: Decodable { let displayName: String? }

struct PlaylistTracksResponse: Decodable { let items: [PlaylistTrackItem] }
struct PlaylistTrackItem: Decodable, Identifiable {
    let track: Track
    var id: String { track.id }
}

struct TopTracksResponse: Decodable { let tracks: [Track] }

struct SearchArtistsResponse: Decodable { let artists: Paging<Artist> }
struct SearchAlbumsResponse: Decodable { let albums: Paging<Album> }
struct SearchTracksResponse: Decodable { let tracks: Paging<Track> }

// MARK: - Player (30s previews when available)
@MainActor
final class PreviewPlayer: ObservableObject {
    static let shared = PreviewPlayer()
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var nowPlayingTitle: String? = nil

    private var player: AVPlayer? = nil
    private var observer: AnyCancellable? = nil

    func play(track: Track) {
        guard let urlStr = track.previewUrl, let url = URL(string: urlStr) else { return }
        let item = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: item)
        self.player?.play()
        self.isPlaying = true
        self.nowPlayingTitle = track.name

        // Stop at end
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        nowPlayingTitle = nil
    }
}

// MARK: - UI Helpers
extension View {
    func spotifyCover(_ images: [SpotifyImage]?, size: CGFloat) -> some View {
        let url = images?.first?.url.flatMap(URL.init(string:))
        return AsyncImage(url: url) { phase in
            switch phase {
            case .empty: Color.gray.opacity(0.15)
            case .success(let img): img.resizable().scaledToFill()
            case .failure: Color.gray.opacity(0.15)
            @unknown default: Color.gray.opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Root App
@main
struct SpotifyDemoApp: App {
    @StateObject private var auth = SpotifyAuth()
    @StateObject private var apiHolder = APIHolder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(apiHolder.provide(with: auth))
                .onOpenURL { url in auth.handleCallback(url: url) }
        }
    }
}

// Simple DI helper so `SpotifyAPI` can be created after auth exists
@MainActor
final class APIHolder: ObservableObject {
    private(set) var api: SpotifyAPI? = nil
    func provide(with auth: SpotifyAuth) -> SpotifyAPI {
        if let api { return api }
        let new = SpotifyAPI(auth: auth)
        self.api = new
        return new
    }
}

// MARK: - RootView with Tabs
struct RootView: View {
    @EnvironmentObject var auth: SpotifyAuth

    var body: some View {
        Group {
            if auth.isAuthorized {
                AuthedTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var auth: SpotifyAuth
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 56, weight: .bold))
            Text("connect your spotify")
                .font(.title).bold()
            Text("search artists, albums & songs, preview tracks, and browse your playlists")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button {
                auth.signIn(scopes: ["user-read-email", "playlist-read-private", "playlist-read-collaborative"]) // add more scopes if you extend features
            } label: {
                Label("log in with spotify", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
}

struct AuthedTabView: View {
    var body: some View {
        TabView {
            ArtistsTab().tabItem { Label("Artists", systemImage: "person.2.fill") }
            AlbumsTab().tabItem { Label("Albums", systemImage: "square.stack.fill") }
            TracksTab().tabItem { Label("Songs", systemImage: "music.note.list") }
            PlaylistsTab().tabItem { Label("Playlists", systemImage: "text.badge.plus") }
        }
    }
}

// MARK: - Artists
struct ArtistsTab: View {
    @EnvironmentObject var api: SpotifyAPI
    @State private var q = ""
    @State private var results: [Artist] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search artists", text: $q)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await search() } }
                        .buttonStyle(.borderedProminent)
                }.padding()

                if isSearching { ProgressView().padding(.top) }

                List(results) { artist in
                    NavigationLink(value: artist) {
                        HStack(spacing: 12) {
                            spotifyCover(artist.images, size: 54)
                            VStack(alignment: .leading) {
                                Text(artist.name).bold()
                                if let followers = artist.followers?.total {
                                    Text("\(followers) followers").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
                .navigationTitle("Artists")
            }
        }
    }

    private func search() async {
        guard !q.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do { results = try await api.searchArtists(q).items } catch { print(error) }
    }
}

struct ArtistDetailView: View {
    @EnvironmentObject var api: SpotifyAPI
    let artist: Artist
    @State private var albums: [Album] = []
    @State private var top: [Track] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    spotifyCover(artist.images, size: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(artist.name).font(.title).bold()
                        if let g = artist.genres, !g.isEmpty { Text(g.prefix(3).joined(separator: ", ")).foregroundStyle(.secondary) }
                        if let f = artist.followers?.total { Text("Followers: \(f.formatted())").foregroundStyle(.secondary) }
                    }
                }.padding(.horizontal)

                if !top.isEmpty {
                    Text("Top Tracks").font(.headline).padding(.horizontal)
                    ForEach(top) { track in TrackRow(track: track) }
                }

                if !albums.isEmpty {
                    Text("Albums & Singles").font(.headline).padding([.horizontal, .top])
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)]) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                VStack(alignment: .leading, spacing: 8) {
                                    spotifyCover(album.images, size: 140)
                                    Text(album.name).font(.subheadline).lineLimit(2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Artist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(for: Album.self) { AlbumDetailView(albumID: $0.id) }
    }

    private func load() async {
        do {
            albums = try await api.getArtistAlbums(artist.id).items
            top = try await api.getArtistTopTracks(artist.id).tracks
        } catch { print(error) }
    }
}

// MARK: - Albums
struct AlbumsTab: View {
    @EnvironmentObject var api: SpotifyAPI
    @State private var q = ""
    @State private var results: [Album] = []

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search albums", text: $q).textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await search() } }.buttonStyle(.borderedProminent)
                }.padding()
                List(results) { album in
                    NavigationLink(value: album) {
                        HStack(spacing: 12) {
                            spotifyCover(album.images, size: 54)
                            VStack(alignment: .leading) {
                                Text(album.name).bold()
                                if let artist = album.artists?.first?.name { Text(artist).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                .navigationDestination(for: Album.self) { AlbumDetailView(albumID: $0.id) }
                .navigationTitle("Albums")
            }
        }
    }

    private func search() async {
        guard !q.isEmpty else { return }
        do { results = try await api.searchAlbums(q).items } catch { print(error) }
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject var api: SpotifyAPI
    let albumID: String
    @State private var album: Album? = nil
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            if let album {
                Section {
                    HStack(spacing: 16) {
                        spotifyCover(album.images, size: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(album.name).font(.title3).bold()
                            if let a = album.artists?.first?.name { Text(a).foregroundStyle(.secondary) }
                            if let d = album.releaseDate { Text("Released: \(d)").foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Section("Tracks") {
                ForEach(tracks) { TrackRow(track: $0) }
            }
        }
        .task { await load() }
        .navigationTitle("Album")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        do {
            async let a: Album = api.getAlbum(albumID)
            async let t: Paging<Track> = api.getAlbumTracks(albumID)
            let (aa, tt) = try await (a, t)
            album = aa
            tracks = tt.items
        } catch { print(error) }
    }
}

// MARK: - Tracks (search + preview)
struct TracksTab: View {
    @EnvironmentObject var api: SpotifyAPI
    @State private var q = ""
    @State private var results: [Track] = []

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search songs", text: $q).textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await search() } }.buttonStyle(.borderedProminent)
                }.padding()
                List(results) { TrackRow(track: $0) }
                .navigationTitle("Songs")
            }
        }
    }

    private func search() async {
        guard !q.isEmpty else { return }
        do { results = try await api.searchTracks(q).items } catch { print(error) }
    }
}

struct TrackRow: View {
    @EnvironmentObject var api: SpotifyAPI
    @StateObject private var player = PreviewPlayer.shared
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            spotifyCover(track.album?.images, size: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).bold()
                if let artist = track.artists?.first?.name { Text(artist).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if track.previewUrl != nil {
                Button {
                    if player.isPlaying { player.stop() } else { player.play(track: track) }
                } label: {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                }.buttonStyle(.bordered)
            } else {
                // Fallback deep-link if no preview
                if let url = URL(string: "spotify:track:\(track.id)") {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square").accessibilityLabel("Open in Spotify")
                    }
                }
            }
        }
    }
}

// MARK: - Playlists (requires scopes)
struct PlaylistsTab: View {
    @EnvironmentObject var api: SpotifyAPI
    @State private var playlists: [Playlist] = []

    var body: some View {
        NavigationStack {
            List(playlists) { pl in
                NavigationLink(value: pl) {
                    HStack(spacing: 12) {
                        spotifyCover(pl.images, size: 54)
                        VStack(alignment: .leading) {
                            Text(pl.name).bold()
                            if let owner = pl.owner?.displayName { Text(owner).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
            .navigationTitle("Your Playlists")
            .task { await load() }
        }
    }

    private func load() async {
        do { playlists = try await api.getMyPlaylists().items } catch { print(error) }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject var api: SpotifyAPI
    let playlist: Playlist
    @State private var items: [PlaylistTrackItem] = []

    var body: some View {
        List(items) { item in
            TrackRow(track: item.track)
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do { items = try await api.getPlaylistItems(playlist.id).items } catch { print(error) }
    }
}
