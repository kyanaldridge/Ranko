////
////  Spotify.swift
////  RankoApp
////
////  Created by Kyan Aldridge on 9/9/2025.
////
//
//
//import Foundation
//import Combine
//import UIKit
//import SwiftUI
//import KeychainAccess
//import SpotifyWebAPI
//import CryptoKit
//
//private var PKCE: String?
//
//private func generateCodeVerifier() -> String {
//    // 43–128 chars, URL-safe. You already have this helper:
//    String.randomURLSafe(length: 128)
//}
//
//private func codeChallenge(for verifier: String) -> String {
//    let data = Data(verifier.utf8)
//    let digest = SHA256.hash(data: data)
//    // base64url (no padding)
//    return Data(digest).base64EncodedString()
//        .replacingOccurrences(of: "+", with: "-")
//        .replacingOccurrences(of: "/", with: "_")
//        .replacingOccurrences(of: "=", with: "")
//}
//
///**
// A helper class that wraps around an instance of `SpotifyAPI` and provides
// convenience methods for authorizing your application.
//
// Its most important role is to handle changes to the authorization information
// and save them to persistent storage in the keychain.
// */
//final class Spotify: ObservableObject {
//    // MARK: public state
//    @Published var isAuthorized = false
//    @Published var isRetrievingTokens = false
//    @Published var currentUser: SpotifyUser? = nil
//
//    // MARK: config
//    private static let clientId: String = Secrets.spotifyClientID          // ← no secret
//    let authorizationManagerKey = "authorizationManager"
//    let loginCallbackURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!
//
//    // CSRF protection; must match across the flow
//    var authorizationState = String.randomURLSafe(length: 128)
//
//    // PKCE: regenerate for every authorization attempt
//    private(set) var pkce = PKCE
//
//    // Persist tokens in keychain
//    let keychain = Keychain(service: "com.Peter-Schorn.SpotifyAPIExampleApp")
//
//    // Use PKCE manager (no clientSecret)
//    let api = SpotifyAPI(
//        authorizationManager: AuthorizationCodeFlowPKCEManager(clientId: Spotify.clientId)
//    )
//
//    private var cancellables: Set<AnyCancellable> = []
//
//    init() {
//        // Optional: verbose wire logs while debugging
//        api.apiRequestLogger.logLevel = .trace
//        // api.logger.logLevel = .trace
//
//        // Observe auth manager changes BEFORE restoring from keychain.
//        api.authorizationManagerDidChange
//            .receive(on: RunLoop.main)
//            .sink(receiveValue: authorizationManagerDidChange)
//            .store(in: &cancellables)
//
//        api.authorizationManagerDidDeauthorize
//            .receive(on: RunLoop.main)
//            .sink(receiveValue: authorizationManagerDidDeauthorize)
//            .store(in: &cancellables)
//
//        // Restore tokens from keychain if present.
//        if let data = keychain[data: authorizationManagerKey] {
//            do {
//                let manager = try JSONDecoder().decode(AuthorizationCodeFlowPKCEManager.self, from: data)
//                api.authorizationManager = manager
//                print("Restored authorization from keychain")
//            } catch {
//                print("Failed to decode auth manager: \(error)")
//            }
//        } else {
//            print("No auth info in keychain")
//        }
//    }
//
//    // MARK: Kick off login (opens browser)
//    func authorize() {
//            // 1) Create verifier + challenge
//            let verifier = generateCodeVerifier()
//            self.pkce = verifier
//            let challenge = codeChallenge(for: verifier)
//
//            // 2) Build URL with codeChallenge (note: no showDialog:)
//            let url = api.authorizationManager.makeAuthorizationURL(
//                redirectURI: loginCallbackURL,
//                codeChallenge: challenge,
//                state: authorizationState,
//                scopes: [
//                    .userReadPlaybackState,
//                    .userModifyPlaybackState,
//                    .playlistModifyPrivate,
//                    .playlistModifyPublic,
//                    .userLibraryRead,
//                    .userLibraryModify,
//                    .userReadRecentlyPlayed,
//                    .userReadPrivate,
//                    .userReadEmail
//                ]
//            )!
//
//            UIApplication.shared.open(url)
//        }
//
//    // MARK: Handle redirect from Spotify (call from onOpenURL)
//    func handleRedirectURL(_ url: URL) {
//            guard url.scheme == loginCallbackURL.scheme else { return }
//            isRetrievingTokens = true
//
//            guard let verifier = pkce else {
//                print("Missing PKCE verifier; call authorize() again.")
//                isRetrievingTokens = false
//                return
//            }
//
//            // Depending on your SpotifyWebAPI version, you have one of these two APIs.
//            // Try A; if it doesn’t compile in your project, use B.
//
//            // A) Newer versions: pass the verifier into the method.
//            api.authorizationManager.requestAccessAndRefreshTokens(
//                redirectURIWithQuery: url,
//                codeVerifier: verifier, state: authorizationState
//            )
//            // B) Older versions: set the manager’s verifier, then call the 2-arg method.
//            // api.authorizationManager.codeVerifier = verifier
//            // api.authorizationManager.requestAccessAndRefreshTokens(
//            //     redirectURIWithQuery: url,
//            //     state: authorizationState
//            // )
//
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { [weak self] completion in
//                guard let self else { return }
//                self.isRetrievingTokens = false
//                if case .failure(let error) = completion {
//                    print("Token exchange failed: \(error)")
//                } else {
//                    // success — clear the one-time verifier
//                    self.pkce = nil
//                }
//            }, receiveValue: { _ in })
//            .store(in: &cancellables)
//
//            // Always rotate state after each attempt
//            authorizationState = String.randomURLSafe(length: 128)
//        }
//
//
//    // MARK: Observe/save auth changes
//    private func authorizationManagerDidChange() {
//        withAnimation(LoginView.animation) {
//            self.isAuthorized = api.authorizationManager.isAuthorized()
//        }
//        print("Auth changed; isAuthorized:", isAuthorized)
//        retrieveCurrentUser()
//
//        do {
//            let data = try JSONEncoder().encode(api.authorizationManager)
//            keychain[data: authorizationManagerKey] = data
//        } catch {
//            print("Could not encode auth manager: \(error)")
//        }
//    }
//
//    private func authorizationManagerDidDeauthorize() {
//        withAnimation(LoginView.animation) { self.isAuthorized = false }
//        currentUser = nil
//        do {
//            try keychain.remove(authorizationManagerKey)
//        } catch {
//            print("Failed removing auth from keychain: \(error)")
//        }
//    }
//
//    func retrieveCurrentUser(onlyIfNil: Bool = true) {
//        if onlyIfNil && currentUser != nil { return }
//        guard isAuthorized else { return }
//
//        api.currentUserProfile()
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                if case .failure(let error) = completion {
//                    print("Couldn't load current user:", error)
//                }
//            }, receiveValue: { [weak self] user in
//                self?.currentUser = user
//            })
//            .store(in: &cancellables)
//    }
//}
//
//import SpotifyWebAPI
//
//enum SpotifyErrorPresenter {
//    static func userMessage(for error: Error) -> String {
//        // 429 - typed error
//        if let rate = error as? RateLimitedError {
//            if let secs = rate.retryAfter {
//                return "Too many requests. Try again in \(Int(secs))s."
//            }
//            return "Too many requests. Please slow down and try again."
//        }
//
//        // User explicitly denied or auth issue
//        if let auth = error as? SpotifyAuthorizationError, auth.accessWasDenied {
//            return "You denied the authorization request."
//        }
//
//        // Heuristic for 401/403 when we don’t have typed HTTP errors
//        let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
//        let lower = msg.lowercased()
//
//        if lower.contains("403") || lower.contains("forbidden") {
//            return """
//            Forbidden: this Spotify account isn’t allowed for this app while it’s in Development mode. \
//            Add the account under Users & Access in the Spotify Developer Dashboard, or move the app to Production.
//            """
//        }
//        if lower.contains("401") || lower.contains("expired") || lower.contains("unauthorized") {
//            return "Session expired. Please try again."
//        }
//
//        // Network issues
//        if (error as NSError).domain == NSURLErrorDomain {
//            return "Network error. Check your connection and try again."
//        }
//
//        // Fallback
//        return msg
//    }
//}
//
//import Foundation
//import Combine
//import SwiftUI
//import SpotifyWebAPI
//
///// Encapsulates the logic for removing duplicates from a playlist.
//class PlaylistDeduplicator: ObservableObject {
//    
//    @Published var isDeduplicating = false
//    
//    /// The total number of tracks/episodes in the playlist.
//    @Published var totalItems: Int
//
//    let spotify: Spotify
//
//    let playlist: Playlist<PlaylistItemsReference>
//
//    let alertPublisher = PassthroughSubject<AlertItem, Never>()
//
//    private var seenPlaylists: Set<PlaylistItem> = []
//    
//    /// The uri of an item in the playlist, along with its position in the
//    /// playlist.
//    private var duplicates: [(uri: SpotifyURIConvertible, position: Int)] = []
//
//    private var cancellables: Set<AnyCancellable> = []
//
//    init(spotify: Spotify, playlist: Playlist<PlaylistItemsReference>) {
//        self.spotify = spotify
//        self.playlist = playlist
//        self._totalItems = Published(initialValue: playlist.items.total)
//    }
//
//    /// Find the duplicates in the playlist.
//    func findAndRemoveDuplicates() {
//        
//        self.isDeduplicating = true
//        
//        self.seenPlaylists = []
//        self.duplicates = []
//        
//        self.spotify.api.playlistItems(playlist.uri)
//            .extendPagesConcurrently(self.spotify.api)
//            .receive(on: DispatchQueue.main)
//            .sink(
//                receiveCompletion: { completion in
//                    print("received completion:", completion)
//                    switch completion {
//                        case .finished:
//                            // We've finished finding the duplicates; now we
//                            // need to remove them if there are any.
//                            if self.duplicates.isEmpty {
//                                self.isDeduplicating = false
//                                self.alertPublisher.send(.init(
//                                    title: "\(self.playlist.name) does not " +
//                                        "have any duplicates",
//                                    message: ""
//                                ))
//                                return
//                            }
//                        case .failure(let error):
//                            print("couldn't check for duplicates:\n\(error)")
//                            self.isDeduplicating = false
//                            self.alertPublisher.send(.init(
//                                title: "Couldn't check for duplicates for " +
//                                       "\(self.playlist.name)",
//                                message: error.localizedDescription
//                            ))
//                    }
//                },
//                receiveValue: self.receivePlaylistItemsPage(page:)
//            )
//            .store(in: &cancellables)
//                
//    }
//    
//    func receivePlaylistItemsPage(page: PlaylistItems) {
//        
//        print("received page at offset \(page.offset)")
//        
//        let playlistItems = page.items
//            .map(\.item)
//            .enumerated()
//        
//        for (index, playlistItem) in playlistItems {
//            
//            guard let playlistItem = playlistItem else {
//                continue
//            }
//            
//            // skip local tracks
//            if case .track(let track) = playlistItem {
//                if track.isLocal { continue }
//            }
//            
//            for seenPlaylist in self.seenPlaylists {
//                guard let uri = playlistItem.uri else {
//                    continue
//                }
//                
//                if playlistItem.isProbablyTheSameAs(seenPlaylist) {
//                    // To determine the actual index of the item in the
//                    // playlist, we must take into account the offset of the
//                    // current page.
//                    let playlistIndex = index + page.offset
//                    self.duplicates.append(
//                        (uri: uri, position: playlistIndex)
//                    )
//                }
//            }
//            self.seenPlaylists.insert(playlistItem)
//        }
//    }
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//
//struct SpotifyRootView: View {
//    @EnvironmentObject var spotify: Spotify
//    
//    @State private var kind: SearchKind = .artists
//    @State private var query: String = ""
//    @State private var isLoading = false
//    @State private var errorMessage: String?
//
//    @State private var artists: [Artist] = []
//    @State private var albums:  [Album]  = []
//    @State private var tracks:  [Track]  = []
//    
//    @State private var debounce: DispatchWorkItem?
//
//    @State private var alert: AlertItem? = nil
//    @State private var cancellables: Set<AnyCancellable> = []
//
//    var body: some View {
//        TabView {
//            // Playlists tab
//            Tab("Playlists", systemImage: "music.note.list") {
//                NavigationStack {
//                    PlaylistsTabView()
//                        .navigationTitle("Playlists")
//                        .toolbar {
//                            ToolbarItem(placement: .navigationBarTrailing) { logoutButton }
//                        }
//                }
//            }
//
//            // Search tab
//            Tab("Search", systemImage: "magnifyingglass", role: .search) {
//                NavigationStack {
//                    VStack(spacing: 8) {
//                        Picker("Type", selection: $kind) {
//                            ForEach(SearchKind.allCases) { k in Text(k.rawValue).tag(k) }
//                        }
//                        .pickerStyle(.segmented)
//                        .padding(.horizontal)
//
//                        contentList   // <- keep your List here (no .searchable on the List)
//                    }
//                    .navigationTitle("Search")
//                    .searchable(
//                        text: $query,
//                        placement: .navigationBarDrawer(displayMode: .always),
//                        prompt: kind.prompt
//                    )
//                    .onSubmit(of: .search, search)
//                    .onChange(of: kind) { _, _ in clearResults(); scheduleSearch() }
//                    .onChange(of: query) { _, _ in scheduleSearch() }
//                    .refreshable { if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { search() } }
//                    .toolbar {
//                        ToolbarItem(placement: .navigationBarTrailing) { logoutButton }
//                    }
//                }
//            }
//        }
//        .modifier(LoginView())
//        .alert(item: $alert) { alert in Alert(title: alert.title, message: alert.message) }
//        .onOpenURL { url in
//            guard url.scheme == spotify.loginCallbackURL.scheme else { return }
//            spotify.handleRedirectURL(url)   // ← this now passes the PKCE verifier internally
//        }
//        .onAppear {
//            if spotify.isAuthorized {
//                spotify.retrieveCurrentUser(onlyIfNil: false)
//            }
//        }
//        // ✅ And whenever authorization flips to true
//        .onChange(of: spotify.isAuthorized) { _, isAuthed in
//            if isAuthed {
//                spotify.retrieveCurrentUser(onlyIfNil: false)
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private var contentList: some View {
//        List {
//            if let errorMessage {
//                Text(errorMessage).foregroundStyle(.red)
//            }
//            if isLoading {
//                ProgressView("Searching…")
//            }
//
//            switch kind {
//            case .artists:
//                ForEach(artists, id: \.uri) { artist in
//                    HStack(spacing: 12) {
//                        AsyncSpotifyImageView(images: artist.images)
//                            .frame(width: 44, height: 44).clipShape(Circle())
//                        VStack(alignment: .leading, spacing: 2) {
//                            Text(artist.name).font(.headline)
//                            let followers = artist.followers?.total ?? 0
//                            Text("\(followers) followers")
//                                .font(.subheadline).foregroundStyle(.secondary)
//                        }
//                    }
//                }
//
//            case .albums:
//                ForEach(albums, id: \.uri) { album in
//                    HStack(spacing: 12) {
//                        AsyncSpotifyImageView(images: album.images)
//                            .frame(width: 52, height: 52).cornerRadius(6)
//                        VStack(alignment: .leading, spacing: 2) {
//                            Text(album.name).font(.headline)
//                            Text(album.artists?.map(\.name).joined(separator: ", ") ?? "")
//                                .font(.subheadline).foregroundStyle(.secondary)
//                        }
//                    }
//                }
//
//            case .songs:
//                ForEach(tracks, id: \.uri) { track in
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(track.name).font(.headline)
//                        Text(
//                            [
//                                track.artists?.map(\.name).joined(separator: ", "),
//                                track.album?.name
//                            ].compactMap { $0 }.joined(separator: " • ")
//                        )
//                        .font(.subheadline).foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .listStyle(.plain)
//        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: kind.prompt)
//        .onSubmit(of: .search, search)
//    }
//
//    private func scheduleSearch() {
//        debounce?.cancel()
//        let work = DispatchWorkItem { search() }
//        debounce = work
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
//    }
//
//    private func clearResults() {
//        artists.removeAll()
//        albums.removeAll()
//        tracks.removeAll()
//        errorMessage = nil
//    }
//
//    private func search() {
//        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !q.isEmpty else { clearResults(); return }
//        isLoading = true
//        errorMessage = nil
//
//        // choose the right category inline so Swift can infer the type
//        let searchPublisher: AnyPublisher<SearchResult, Error>
//        switch kind {
//        case .artists:
//            searchPublisher = spotify.api.search(query: q, categories: [.artist], limit: 25)
//        case .albums:
//            searchPublisher = spotify.api.search(query: q, categories: [.album],  limit: 25)
//        case .songs:
//            searchPublisher = spotify.api.search(query: q, categories: [.track],  limit: 25)
//        }
//
//        searchPublisher
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                self.isLoading = false
//                if case .failure(let error) = completion {
//                    self.errorMessage = SpotifyErrorPresenter.userMessage(for: error)
//                }
//            }, receiveValue: { results in
//                switch kind {
//                case .artists: self.artists = results.artists?.items ?? []
//                case .albums:  self.albums  = results.albums?.items  ?? []
//                case .songs:   self.tracks  = results.tracks?.items  ?? []
//                }
//            })
//            .store(in: &cancellables)
//    }
//
//    // MARK: auth redirect handling (same logic you had)
//    func handleURL(_ url: URL) {
//        guard url.scheme == spotify.loginCallbackURL.scheme else { return }
//        spotify.isRetrievingTokens = true
//        spotify.handleRedirectURL(url)   // <- delegate to the PKCE-aware function
//    }
//
//    var logoutButton: some View {
//        Button(action: spotify.api.authorizationManager.deauthorize) {
//            Text("Logout")
//                .foregroundColor(.white)
//                .padding(.horizontal, 10).padding(.vertical, 7)
//                .background(Color(red: 0.392, green: 0.720, blue: 0.197))
//                .cornerRadius(10)
//                .shadow(radius: 3)
//        }
//    }
//}
//
//// MARK: - Search (segmented: Artists / Albums / Songs)
//
//private enum SearchKind: String, CaseIterable, Identifiable {
//    case artists = "Artists"
//    case albums  = "Albums"
//    case songs   = "Songs"
//
//    var id: Self { self }
//
//    var prompt: String {
//        switch self {
//        case .artists: return "Search artists"
//        case .albums:  return "Search albums"
//        case .songs:   return "Search songs"
//        }
//    }
//}
//
//struct SearchTabView: View {
//    @EnvironmentObject var spotify: Spotify
//
//    @State private var kind: SearchKind = .artists
//    @State private var query: String = ""
//    @State private var isLoading = false
//    @State private var errorMessage: String?
//
//    @State private var artists: [Artist] = []
//    @State private var albums:  [Album]  = []
//    @State private var tracks:  [Track]  = []
//
//    @State private var cancellables: Set<AnyCancellable> = []
//    @State private var debounce: DispatchWorkItem?
//
//    var body: some View {
//        VStack(spacing: 8) {
//            Picker("Type", selection: $kind) {
//                ForEach(SearchKind.allCases) { k in Text(k.rawValue).tag(k) }
//            }
//            .pickerStyle(.segmented)
//            .padding(.horizontal)
//
//            contentList
//        }
//        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: kind.prompt)
//        .onSubmit(of: .search, search)
//        .onChange(of: kind) { _, _ in
//            clearResults()
//            scheduleSearch()
//        }
//        .onChange(of: query) { _, _ in
//            scheduleSearch()
//        }
//        .refreshable { if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { search() } }
//    }
//
//    @ViewBuilder
//    private var contentList: some View {
//        List {
//            if let errorMessage {
//                Text(errorMessage).foregroundStyle(.red)
//            }
//            if isLoading {
//                ProgressView("Searching…")
//            }
//
//            switch kind {
//            case .artists:
//                ForEach(artists, id: \.uri) { artist in
//                    HStack(spacing: 12) {
//                        AsyncSpotifyImageView(images: artist.images)
//                            .frame(width: 44, height: 44).clipShape(Circle())
//                        VStack(alignment: .leading, spacing: 2) {
//                            Text(artist.name).font(.headline)
//                            let followers = artist.followers?.total ?? 0
//                            Text("\(followers) followers")
//                                .font(.subheadline).foregroundStyle(.secondary)
//                        }
//                    }
//                }
//
//            case .albums:
//                ForEach(albums, id: \.uri) { album in
//                    HStack(spacing: 12) {
//                        AsyncSpotifyImageView(images: album.images)
//                            .frame(width: 52, height: 52).cornerRadius(6)
//                        VStack(alignment: .leading, spacing: 2) {
//                            Text(album.name).font(.headline)
//                            Text(album.artists?.map(\.name).joined(separator: ", ") ?? "")
//                                .font(.subheadline).foregroundStyle(.secondary)
//                        }
//                    }
//                }
//
//            case .songs:
//                ForEach(tracks, id: \.uri) { track in
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(track.name).font(.headline)
//                        Text(
//                            [
//                                track.artists?.map(\.name).joined(separator: ", "),
//                                track.album?.name
//                            ].compactMap { $0 }.joined(separator: " • ")
//                        )
//                        .font(.subheadline).foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .listStyle(.plain)
//    }
//
//    private func scheduleSearch() {
//        debounce?.cancel()
//        let work = DispatchWorkItem { search() }
//        debounce = work
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
//    }
//
//    private func clearResults() {
//        artists.removeAll()
//        albums.removeAll()
//        tracks.removeAll()
//        errorMessage = nil
//    }
//
//    private func search() {
//        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !q.isEmpty else { clearResults(); return }
//        isLoading = true
//        errorMessage = nil
//
//        // choose the right category inline so Swift can infer the type
//        let searchPublisher: AnyPublisher<SearchResult, Error>
//        switch kind {
//        case .artists:
//            searchPublisher = spotify.api.search(query: q, categories: [.artist], limit: 25)
//        case .albums:
//            searchPublisher = spotify.api.search(query: q, categories: [.album],  limit: 25)
//        case .songs:
//            searchPublisher = spotify.api.search(query: q, categories: [.track],  limit: 25)
//        }
//
//        searchPublisher
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                self.isLoading = false
//                if case .failure(let error) = completion {
//                    self.errorMessage = SpotifyErrorPresenter.userMessage(for: error)
//                }
//            }, receiveValue: { results in
//                switch kind {
//                case .artists: self.artists = results.artists?.items ?? []
//                case .albums:  self.albums  = results.albums?.items  ?? []
//                case .songs:   self.tracks  = results.tracks?.items  ?? []
//                }
//            })
//            .store(in: &cancellables)
//    }
//}
//
//// MARK: - Playlists
//
//struct PlaylistsTabView: View {
//    @EnvironmentObject var spotify: Spotify
//    @State private var playlists: [Playlist<PlaylistItemsReference>] = []
//    @State private var isLoading = false
//    @State private var errorMessage: String?
//    @State private var cancellables: Set<AnyCancellable> = []
//
//    var body: some View {
//        List {
//            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
//            if isLoading { ProgressView("Loading your playlists…") }
//
//            ForEach(playlists, id: \.uri) { pl in
//                HStack(spacing: 12) {
//                    AsyncSpotifyImageView(images: pl.images)
//                        .frame(width: 52, height: 52).cornerRadius(6)
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(pl.name).font(.headline)
//                        Text(pl.owner?.displayName ?? "Unknown owner")
//                            .font(.subheadline).foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .listStyle(.plain)
//        .task { loadPlaylists() }            // load on first appearance
//        .refreshable { loadPlaylists() }     // pull to refresh
//    }
//
//    @MainActor
//    private func loadPlaylists() {
//        isLoading = true
//        errorMessage = nil
//
//        spotify.api.currentUserPlaylists(limit: 50)
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                self.isLoading = false
//                if case .failure(let error) = completion {
//                    self.errorMessage = error.localizedDescription
//                }
//            }, receiveValue: { paging in
//                self.playlists = paging.items
//            })
//            .store(in: &cancellables)
//    }
//}
//
//// MARK: - Tiny helper for images (uses the first image url if available)
//
//struct AsyncSpotifyImageView: View {
//    let url: URL?
//
//    init(images: [SpotifyImage]?) {
//        self.url = images?.first?.url
//    }
//
//    var body: some View {
//        if let url {
//            AsyncImage(url: url) { phase in
//                switch phase {
//                case .empty: ProgressView()
//                case .success(let img): img.resizable().scaledToFill()
//                case .failure: placeholder
//                @unknown default: placeholder
//                }
//            }
//        } else {
//            placeholder
//        }
//    }
//
//    private var placeholder: some View {
//        ZStack {
//            Color.secondary.opacity(0.15)
//            Image(systemName: "photo").imageScale(.medium).foregroundStyle(.secondary)
//        }.clipped()
//    }
//}
//
//
//import SwiftUI
//import Combine
//
///**
// A view that presents a button to login with Spotify.
//
// It is presented when `isAuthorized` is `false`.
//
// When the user taps the button, the authorization URL is opened in the browser,
// which prompts them to login with their Spotify account and authorize this
// application.
//
// After Spotify redirects back to this app and the access and refresh tokens have
// been retrieved, dismiss this view by setting `isAuthorized` to `true`.
// */
//struct LoginView: ViewModifier {
//
//    /// Always show this view for debugging purposes. Most importantly, this is
//    /// useful for the preview provider.
//    fileprivate static var debugAlwaysShowing = false
//    
//    /// The animation that should be used for presenting and dismissing this
//    /// view.
//    static let animation = Animation.spring()
//    
//    @Environment(\.colorScheme) var colorScheme
//
//    @EnvironmentObject var spotify: Spotify
//
//    /// After the app first launches, add a short delay before showing this view
//    /// so that the animation can be seen.
//    @State private var finishedViewLoadDelay = false
//    
//    let backgroundGradient = LinearGradient(
//        gradient: Gradient(
//            colors: [
//                Color(red: 0.467, green: 0.765, blue: 0.267),
//                Color(red: 0.190, green: 0.832, blue: 0.437)
//            ]
//        ),
//        startPoint: .leading, endPoint: .trailing
//    )
//    
//    var spotifyLogo: ImageName {
//        colorScheme == .dark ? .spotifyLogoWhite
//                : .spotifyLogoBlack
//    }
//    
//    func body(content: Content) -> some View {
//        content
//            .blur(
//                radius: spotify.isAuthorized && !Self.debugAlwaysShowing ? 0 : 3
//            )
//            .overlay(
//                ZStack {
//                    if !spotify.isAuthorized || Self.debugAlwaysShowing {
//                        Color.black.opacity(0.25)
//                            .edgesIgnoringSafeArea(.all)
//                        if self.finishedViewLoadDelay || Self.debugAlwaysShowing {
//                            loginView
//                        }
//                    }
//                }
//            )
//            .onAppear {
//                // After the app first launches, add a short delay before
//                // showing this view so that the animation can be seen.
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
//                    withAnimation(LoginView.animation) {
//                        self.finishedViewLoadDelay = true
//                    }
//                })
//            }
//    }
//    
//    var loginView: some View {
//        spotifyButton
//            .padding()
//            .padding(.vertical, 50)
//            .background(Color(.secondarySystemBackground))
//            .cornerRadius(20)
//            .overlay(retrievingTokensView)
//            .shadow(radius: 5)
//            .transition(
//                AnyTransition.scale(scale: 1.2)
//                    .combined(with: .opacity)
//            )
//    }
//    
//    var spotifyButton: some View {
//
//        Button(action: spotify.authorize) {
//            HStack {
//                Image(spotifyLogo)
//                    .interpolation(.high)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(height: 40)
//                Text("Log in with Spotify")
//                    .font(.title)
//            }
//            .padding()
//            .background(backgroundGradient)
//            .clipShape(Capsule())
//            .shadow(radius: 5)
//        }
//        .accessibility(identifier: "Log in with Spotify Identifier")
//        .buttonStyle(PlainButtonStyle())
//        // Prevent the user from trying to login again
//        // if a request to retrieve the access and refresh
//        // tokens is currently in progress.
//        .allowsHitTesting(!spotify.isRetrievingTokens)
//        .padding(.bottom, 5)
//        
//    }
//    
//    var retrievingTokensView: some View {
//        VStack {
//            Spacer()
//            if spotify.isRetrievingTokens {
//                HStack {
//                    ProgressView()
//                        .padding()
//                    Text("Authenticating")
//                }
//                .padding(.bottom, 20)
//            }
//        }
//    }
//    
//}
//
//import SwiftUI
//
//struct ExamplesListView: View {
//    
//    var body: some View {
//        List {
//            
//            NavigationLink(
//                "Playlists", destination: PlaylistsListView()
//            )
//            NavigationLink(
//                "Saved Albums", destination: SavedAlbumsGridView()
//            )
//            NavigationLink(
//                "Search For Tracks", destination: SearchForTracksView()
//            )
//            NavigationLink(
//                "Recently Played Tracks", destination: RecentlyPlayedView()
//            )
//            NavigationLink(
//                "Debug Menu", destination: DebugMenuView()
//            )
//            
//            // This is the location where you can add your own views to test out
//            // your application. Each view receives an instance of `Spotify`
//            // from the environment.
//            
//        }
//        .listStyle(PlainListStyle())
//        
//    }
//}
//
//import SwiftUI
//import SpotifyWebAPI
//import Combine
//
//struct SearchForTracksView: View {
//
//    @EnvironmentObject var spotify: Spotify
//    
//    @State private var isSearching = false
//    
//    @State var tracks: [Track] = []
//
//    @State private var alert: AlertItem? = nil
//    
//    @State private var searchText = ""
//    @State private var searchCancellable: AnyCancellable? = nil
//    
//    /// Used by the preview provider to provide sample data.
//    fileprivate init(sampleTracks: [Track]) {
//        self._tracks = State(initialValue: sampleTracks)
//    }
//    
//    init() { }
//    
//    var body: some View {
//        VStack {
//            searchBar
//                .padding([.top, .horizontal])
//            Text("Tap on a track to play it.")
//                .font(.caption)
//                .foregroundColor(.secondary)
//            Spacer()
//            if tracks.isEmpty {
//                if isSearching {
//                    HStack {
//                        ProgressView()
//                            .padding()
//                        Text("Searching")
//                            .font(.title)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                }
//                else {
//                    Text("No Results")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//            }
//            else {
//                List {
//                    ForEach(tracks, id: \.self) { track in
//                        TrackView(track: track)
//                    }
//                }
//            }
//            Spacer()
//        }
//        .navigationTitle("Search For Tracks")
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//    }
//    
//    /// A search bar. Essentially a textfield with a magnifying glass and an "x"
//    /// button overlayed in front of it.
//    var searchBar: some View {
//        // `onCommit` is called when the user presses the return key.
//        TextField("Search", text: $searchText, onCommit: search)
//            .padding(.leading, 22)
//            .overlay(
//                HStack {
//                    Image(systemName: "magnifyingglass")
//                        .foregroundColor(.secondary)
//                    Spacer()
//                    if !searchText.isEmpty {
//                        // Clear the search text when the user taps the "x"
//                        // button.
//                        Button(action: {
//                            self.searchText = ""
//                            self.tracks = []
//                        }, label: {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundColor(.secondary)
//                        })
//                    }
//                }
//            )
//            .padding(.vertical, 7)
//            .padding(.horizontal, 7)
//            .background(Color(.secondarySystemBackground))
//            .cornerRadius(10)
//    }
//    
//    /// Performs a search for tracks based on `searchText`.
//    func search() {
//
//        self.tracks = []
//        
//        if self.searchText.isEmpty { return }
//
//        print("searching with query '\(self.searchText)'")
//        self.isSearching = true
//        
//        self.searchCancellable = spotify.api.search(
//            query: self.searchText, categories: [.track]
//        )
//        .receive(on: RunLoop.main)
//        .sink(
//            receiveCompletion: { completion in
//                self.isSearching = false
//                if case .failure(let error) = completion {
//                    self.alert = AlertItem(
//                        title: "Couldn't Perform Search",
//                        message: error.localizedDescription
//                    )
//                }
//            },
//            receiveValue: { searchResults in
//                self.tracks = searchResults.tracks?.items ?? []
//                print("received \(self.tracks.count) tracks")
//            }
//        )
//    }
//    
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//
//struct TrackView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//    
//    @State private var playRequestCancellable: AnyCancellable? = nil
//
//    @State private var alert: AlertItem? = nil
//    
//    let track: Track
//    
//    var body: some View {
//        Button(action: playTrack) {
//            HStack {
//                Text(trackDisplayName())
//                Spacer()
//            }
//            // Ensure the hit box extends across the entire width of the frame.
//            // See https://bit.ly/2HqNk4S
//            .contentShape(Rectangle())
//        }
//        .buttonStyle(PlainButtonStyle())
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//    }
//    
//    /// The display name for the track. E.g., "Eclipse - Pink Floyd".
//    func trackDisplayName() -> String {
//        var displayName = track.name
//        if let artistName = track.artists?.first?.name {
//            displayName += " - \(artistName)"
//        }
//        return displayName
//    }
//    
//    func playTrack() {
//        
//        let alertTitle = "Couldn't Play \(track.name)"
//
//        guard let trackURI = track.uri else {
//            self.alert = AlertItem(
//                title: alertTitle,
//                message: "missing URI"
//            )
//            return
//        }
//
//        let playbackRequest: PlaybackRequest
//
//        if let albumURI = track.album?.uri {
//            // Play the track in the context of its album. Always prefer
//            // providing a context; otherwise, the back and forwards buttons may
//            // not work.
//            playbackRequest = PlaybackRequest(
//                context: .contextURI(albumURI),
//                offset: .uri(trackURI)
//            )
//        }
//        else {
//            playbackRequest = PlaybackRequest(trackURI)
//        }
//        
//        // By using a single cancellable rather than a collection of
//        // cancellables, the previous request always gets cancelled when a new
//        // request to play a track is made.
//        self.playRequestCancellable =
//            self.spotify.api.getAvailableDeviceThenPlay(playbackRequest)
//                .receive(on: RunLoop.main)
//                .sink(receiveCompletion: { completion in
//                    if case .failure(let error) = completion {
//                        self.alert = AlertItem(
//                            title: alertTitle,
//                            message: error.localizedDescription
//                        )
//                    }
//                })
//        
//    }
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//import SpotifyExampleContent
//
//struct RecentlyPlayedView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//
//    @State private var recentlyPlayed: [Track]
//
//    @State private var alert: AlertItem? = nil
//
//    @State private var nextPageHref: URL? = nil
//    @State private var isLoadingPage = false
//    @State private var didRequestFirstPage = false
//    
//    @State private var loadRecentlyPlayedCancellable: AnyCancellable? = nil
//
//    init() {
//        self._recentlyPlayed = State(initialValue: [])
//    }
//    
//    fileprivate init(recentlyPlayed: [Track]) {
//        self._recentlyPlayed = State(initialValue: recentlyPlayed)
//    }
//
//    var body: some View {
//        Group {
//            if recentlyPlayed.isEmpty {
//                if isLoadingPage {
//                    HStack {
//                        ProgressView()
//                            .padding()
//                        Text("Loading Tracks")
//                            .font(.title)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                else {
//                    Text("No Recently Played Tracks")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//            }
//            else {
//                List {
//                    ForEach(
//                        Array(recentlyPlayed.enumerated()),
//                        id: \.offset
//                    ) { item in
//
//                        TrackView(track: item.element)
//                            // Each track in the list will be loaded lazily. We
//                            // take advantage of this feature in order to detect
//                            // when the user has scrolled to *near* the bottom
//                            // of the list based on the offset of this item.
//                            .onAppear {
//                                self.loadNextPageIfNeeded(offset: item.offset)
//                            }
//
//                    }
//                }
//            }
//        }
//        .navigationTitle("Recently Played")
//        .navigationBarItems(trailing: refreshButton)
//        .onAppear {
//            // don't try to load any tracks if we're previewing because sample
//            // tracks have already been provided
//            if ProcessInfo.processInfo.isPreviewing {
//                return
//            }
//
//            print("onAppear")
//            // the `onAppear` can be called multiple times, but we only want to
//            // load the first page once
//            if !self.didRequestFirstPage {
//                self.didRequestFirstPage = true
//                self.loadRecentlyPlayed()
//            }
//        }
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//        
//        
//    }
//    
//    var refreshButton: some View {
//        Button(action: self.loadRecentlyPlayed) {
//            Image(systemName: "arrow.clockwise")
//                .font(.title)
//                .scaleEffect(0.8)
//        }
//        .disabled(isLoadingPage)
//        
//    }
//
//}
//
//extension RecentlyPlayedView {
//    
//    // Normally, you would extract these methods into a separate model class.
//    
//    /// Determines whether or not to load the next page based on the offset of
//    /// the just-loaded item in the list.
//    func loadNextPageIfNeeded(offset: Int) {
//        
//        let threshold = self.recentlyPlayed.count - 5
//        
//        print(
//            """
//            loadNextPageIfNeeded threshold: \(threshold); offset: \(offset); \
//            total: \(self.recentlyPlayed.count)
//            """
//        )
//        
//        // load the next page if this track is the fifth from the bottom of the
//        // list
//        guard offset == threshold else {
//            return
//        }
//        
//        guard let nextPageHref = self.nextPageHref else {
//            print("no more paged to load: nextPageHref was nil")
//            return
//        }
//        
//        guard !self.isLoadingPage else {
//            return
//        }
//
//        self.loadNextPage(href: nextPageHref)
//
//    }
//    
//    /// Loads the next page of results from the provided URL.
//    func loadNextPage(href: URL) {
//    
//        print("loading next page")
//        self.isLoadingPage = true
//        
//        self.loadRecentlyPlayedCancellable = self.spotify.api
//            .getFromHref(
//                href,
//                responseType: CursorPagingObject<PlayHistory>.self
//            )
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: self.receiveRecentlyPlayedCompletion(_:),
//                receiveValue: { playHistory in
//                    let tracks = playHistory.items.map(\.track)
//                    print(
//                        "received next page with \(tracks.count) items"
//                    )
//                    self.nextPageHref = playHistory.next
//                    self.recentlyPlayed += tracks
//                }
//            )
//
//    }
//
//    /// Loads the first page. Called when this view appears.
//    func loadRecentlyPlayed() {
//        
//        print("loading first page")
//        self.isLoadingPage = true
//        self.recentlyPlayed = []
//        
//        self.loadRecentlyPlayedCancellable = self.spotify.api
//            .recentlyPlayed()
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: self.receiveRecentlyPlayedCompletion(_:),
//                receiveValue: { playHistory in
//                    let tracks = playHistory.items.map(\.track)
//                    print(
//                        "received first page with \(tracks.count) items"
//                    )
//                    self.nextPageHref = playHistory.next
//                    self.recentlyPlayed = tracks
//                }
//            )
//
//    }
//    
//    func receiveRecentlyPlayedCompletion(
//        _ completion: Subscribers.Completion<Error>
//    ) {
//        if case .failure(let error) = completion {
//            let title = "Couldn't retrieve recently played tracks"
//            print("\(title): \(error)")
//            self.alert = AlertItem(
//                title: title,
//                message: error.localizedDescription
//            )
//        }
//        self.isLoadingPage = false
//    }
//
//}
//
//import SwiftUI
//import Combine
//
//struct DebugMenuView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//    
//    @State private var cancellables: Set<AnyCancellable> = []
//
//    var body: some View {
//        List {
//            Button("Make Access Token Expired") {
//                self.spotify.api.authorizationManager.setExpirationDate(
//                    to: Date()
//                )
//            }
//            Button("Refresh Access Token") {
//                self.spotify.api.authorizationManager.refreshTokens(
//                    onlyIfExpired: false
//                )
//                .sink(receiveCompletion: { completion in
//                    print("refresh tokens completion: \(completion)")
//                    
//                })
//                .store(in: &self.cancellables)
//            }
//            Button("Print SpotifyAPI") {
//                print(
//                    """
//                    --- SpotifyAPI ---
//                    \(self.spotify.api)
//                    ------------------
//                    """
//                )
//            }
//            
//        }
//        .navigationBarTitle("Debug Menu")
//    }
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//
//struct SavedAlbumsGridView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//    
//    @State private var savedAlbums: [Album] = []
//
//    @State private var alert: AlertItem? = nil
//
//    @State private var didRequestAlbums = false
//    @State private var isLoadingAlbums = false
//    @State private var couldntLoadAlbums = false
//    
//    @State private var loadAlbumsCancellable: AnyCancellable? = nil
//    
//    let columns = [
//        GridItem(.adaptive(minimum: 100, maximum: 200))
//    ]
//
//    init() { }
//    
//    /// Used only by the preview provider to provide sample data.
//    fileprivate init(sampleAlbums: [Album]) {
//        self._savedAlbums = State(initialValue: sampleAlbums)
//    }
//    
//    var body: some View {
//        Group {
//            if savedAlbums.isEmpty {
//                if isLoadingAlbums {
//                    HStack {
//                        ProgressView()
//                            .padding()
//                        Text("Loading Albums")
//                            .font(.title)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                else if couldntLoadAlbums {
//                    Text("Couldn't Load Albums")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//                else {
//                    Text("No Albums")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//            }
//            else {
//                ScrollView {
//                    LazyVGrid(columns: columns) {
//                        // WARNING: do not use `\.self` for the id. This is
//                        // extremely expensive and causes lag when scrolling
//                        // because the hash of the entire album instance, which
//                        // is very large, must be calculated.
//                        ForEach(savedAlbums, id: \.id) { album in
//                            AlbumGridItemView(album: album)
//                        }
//                    }
//                    .padding()
//                    .accessibility(identifier: "Saved Albums Grid")
//                }
//            }
//            
//        }
//        .navigationTitle("Saved Albums")
//        .navigationBarItems(trailing: refreshButton)
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//        .onAppear {
//            if !self.didRequestAlbums {
//                self.retrieveSavedAlbums()
//            }
//        }
//    }
//    
//    var refreshButton: some View {
//        Button(action: retrieveSavedAlbums) {
//            Image(systemName: "arrow.clockwise")
//                .font(.title)
//                .scaleEffect(0.8)
//        }
//        .disabled(isLoadingAlbums)
//        
//    }
//    
//    func retrieveSavedAlbums() {
//
//        // Don't try to load any albums if we're in preview mode.
//        if ProcessInfo.processInfo.isPreviewing { return }
//        
//        self.didRequestAlbums = true
//        self.isLoadingAlbums = true
//        self.savedAlbums = []
//        
//        print("retrieveSavedAlbums")
//        
//        self.loadAlbumsCancellable = spotify.api
//            .currentUserSavedAlbums()
//            .extendPages(spotify.api)
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: { completion in
//                    self.isLoadingAlbums = false
//                    switch completion {
//                        case .finished:
//                            self.couldntLoadAlbums = false
//                        case .failure(let error):
//                            self.couldntLoadAlbums = true
//                            self.alert = AlertItem(
//                                title: "Couldn't Retrieve Albums",
//                                message: error.localizedDescription
//                            )
//                    }
//                },
//                receiveValue: { savedAlbums in
//                    let albums = savedAlbums.items
//                        .map(\.item)
//                        /*
//                         Remove albums that have a `nil` id so that this
//                         property can be used as the id for the ForEach above.
//                         (The id must be unique, otherwise the app will crash.)
//                         In theory, the id should never be `nil` when the albums
//                         are retrieved using the `currentUserSavedAlbums()`
//                         endpoint.
//
//                         Using \.self in the ForEach is extremely expensive as
//                         this involves calculating the hash of the entire
//                         `Album` instance, which is very large.
//                         */
//                        .filter { $0.id != nil }
//                    
//                    self.savedAlbums.append(contentsOf: albums)
//                    
//                }
//            )
//    }
//
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//import SpotifyExampleContent
//
//struct AlbumGridItemView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//    
//    /// The cover image for the album.
//    @State private var image = Image(ImageName.spotifyAlbumPlaceholder)
//    
//    @State private var loadImageCancellable: AnyCancellable? = nil
//    @State private var didRequestImage = false
//    
//    var album: Album
//    
//    var body: some View {
//        NavigationLink(
//            destination: AlbumTracksView(album: album, image: image)
//        ) {
//            VStack {
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .cornerRadius(5)
//                Text(album.name)
//                    .font(.callout)
//                    .lineLimit(3)
//                    // This is necessary to ensure that the text wraps to the
//                    // next line if it is too long.
//                    .fixedSize(horizontal: false, vertical: true)
//                Spacer()
//            }
//            .onAppear(perform: loadImage)
//        }
//        .buttonStyle(PlainButtonStyle())
//        .padding(5)
//    }
//    
//    func loadImage() {
//    
//        // Return early if the image has already been requested. We can't just
//        // check if `self.image == nil` because the image might have already
//        // been requested, but not loaded yet.
//        if self.didRequestImage { return }
//        self.didRequestImage = true
//    
//        guard let spotifyImage = album.images?.largest else {
//            return
//        }
//    
//        // print("loading image for '\(album.name)'")
//    
//        // Note that a `Set<AnyCancellable>` is NOT being used so that each time
//        // a request to load the image is made, the previous cancellable
//        // assigned to `loadImageCancellable` is deallocated, which cancels the
//        // publisher.
//        self.loadImageCancellable = spotifyImage.load()
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: { _ in },
//                receiveValue: { image in
//                    self.image = image
//                }
//            )
//    }
//
//
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//import SpotifyExampleContent
//
//struct AlbumTracksView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//
//    @State private var alert: AlertItem? = nil
//    
//    @State private var loadTracksCancellable: AnyCancellable? = nil
//    @State private var playAlbumCancellable: AnyCancellable? = nil
//    
//    @State private var isLoadingTracks = false
//    @State private var couldntLoadTracks = false
//    
//    @State var allTracks: [Track] = []
//
//    let album: Album
//    let image: Image
//    
//    init(album: Album, image: Image) {
//        self.album = album
//        self.image = image
//    }
//    
//    /// Used by the preview provider to provide sample data.
//    fileprivate init(album: Album, image: Image, tracks: [Track]) {
//        self.album = album
//        self.image = image
//        self._allTracks = State(initialValue: tracks)
//    }
//
//    /// The album and artist name; e.g., "Abbey Road - The Beatles".
//    var albumAndArtistName: String {
//        var title = album.name
//        if let artistName = album.artists?.first?.name {
//            title += " - \(artistName)"
//        }
//        return title
//    }
//    
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 0) {
//                albumImageWithPlayButton
//                    .padding(30)
//                Text(albumAndArtistName)
//                    .font(.title)
//                    .bold()
//                    .padding(.horizontal)
//                    .padding(.top, -10)
//                Text("\(album.tracks?.total ?? 0) Tracks")
//                    .foregroundColor(.secondary)
//                    .font(.title2)
//                    .padding(.vertical, 10)
//                if allTracks.isEmpty {
//                    Group {
//                        if isLoadingTracks {
//                            HStack {
//                                ProgressView()
//                                    .padding()
//                                Text("Loading Tracks")
//                                    .font(.title)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        else if couldntLoadTracks {
//                            Text("Couldn't Load Tracks")
//                                .font(.title)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                    .padding(.top, 20)
//                }
//                else {
//                    ForEach(
//                        Array(allTracks.enumerated()),
//                        id: \.offset
//                    ) { track in
//                        AlbumTrackCellView(
//                            index: track.offset,
//                            track: track.element,
//                            album: album,
//                            alert: $alert
//                        )
//                        Divider()
//                    }
//                }
//            }
//        }
//        .navigationBarTitle("", displayMode: .inline)
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//        .onAppear(perform: loadTracks)
//    }
//    
//    var albumImageWithPlayButton: some View {
//        ZStack {
//            image
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .cornerRadius(20)
//                .shadow(radius: 20)
//            Button(action: playAlbum, label: {
//                Image(systemName: "play.circle")
//                    .resizable()
//                    .background(Color.black.opacity(0.5))
//                    .clipShape(Circle())
//                    .frame(width: 100, height: 100)
//            })
//        }
//    }
//    
//    /// Loads the album tracks.
//    func loadTracks() {
//        
//        // Don't try to load any tracks if we're in preview mode
//        if ProcessInfo.processInfo.isPreviewing { return }
//
//        guard let tracks = self.album.tracks else {
//            return
//        }
//
//        // the `album` already contains the first page of tracks, but we need to
//        // load additional pages if they exist. the `extendPages` method
//        // immediately republishes the page that was passed in and then requests
//        // additional pages.
//        
//        self.isLoadingTracks = true
//        self.allTracks = []
//        self.loadTracksCancellable = self.spotify.api.extendPages(tracks)
//            .map(\.items)
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: { completion in
//                    self.isLoadingTracks = false
//                    switch completion {
//                        case .finished:
//                            self.couldntLoadTracks = false
//                        case .failure(let error):
//                            self.couldntLoadTracks = true
//                            self.alert = AlertItem(
//                                title: "Couldn't Load Tracks",
//                                message: error.localizedDescription
//                            )
//                    }
//                },
//                receiveValue: { tracks in
//                    self.allTracks.append(contentsOf: tracks)
//                }
//            )
//        
//    }
//    
//    func playAlbum() {
//        guard let albumURI = album.uri else {
//            print("missing album uri for '\(album.name)'")
//            return
//        }
//        let playbackRequest = PlaybackRequest(
//            context: .contextURI(albumURI), offset: nil
//        )
//        print("playing album '\(album.name)'")
//        self.playAlbumCancellable = spotify.api
//            .getAvailableDeviceThenPlay(playbackRequest)
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                print("Received play album completion: \(completion)")
//                if case .failure(let error) = completion {
//                    self.alert = AlertItem(
//                        title: "Couldn't Play Album",
//                        message: error.localizedDescription
//                    )
//                }
//            })
//    }
//    
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//import SpotifyExampleContent
//
//struct AlbumTrackCellView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//
//    @State private var playTrackCancellable: AnyCancellable? = nil
//
//    let index: Int
//    let track: Track
//    let album: Album
//    
//    @Binding var alert: AlertItem?
//
//    var body: some View {
//        Button(action: playTrack, label: {
//            Text("\(index + 1). \(track.name)")
//                .lineLimit(1)
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding()
//                .contentShape(Rectangle())
//        })
//        .buttonStyle(PlainButtonStyle())
//    }
//    
//    func playTrack() {
//        
//        let alertTitle = "Couldn't play \(track.name)"
//
//        guard let trackURI = track.uri else {
//            self.alert = AlertItem(
//                title: alertTitle,
//                message: "Missing data"
//            )
//            return
//        }
//        
//        let playbackRequest: PlaybackRequest
//        
//        if let albumURI = self.album.uri {
//            // Play the track in the context of its album. Always prefer
//            // providing a context; otherwise, the back and forwards buttons may
//            // not work.
//            playbackRequest = PlaybackRequest(
//                context: .contextURI(albumURI),
//                offset: .uri(trackURI)
//            )
//        }
//        else {
//            playbackRequest = PlaybackRequest(trackURI)
//        }
//
//        self.playTrackCancellable = self.spotify.api
//            .getAvailableDeviceThenPlay(playbackRequest)
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                if case .failure(let error) = completion {
//                    self.alert = AlertItem(
//                        title: alertTitle,
//                        message: error.localizedDescription
//                    )
//                    print("\(alertTitle): \(error)")
//                }
//            })
//        
//    }
//
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//
//struct PlaylistsListView: View {
//    
//    @EnvironmentObject var spotify: Spotify
//
//    @State private var playlists: [Playlist<PlaylistItemsReference>] = []
//    
//    @State private var cancellables: Set<AnyCancellable> = []
//    
//    @State private var isLoadingPlaylists = false
//    @State private var couldntLoadPlaylists = false
//    
//    @State private var alert: AlertItem? = nil
//
//    init() { }
//    
//    /// Used only by the preview provider to provide sample data.
//    fileprivate init(samplePlaylists: [Playlist<PlaylistItemsReference>]) {
//        self._playlists = State(initialValue: samplePlaylists)
//    }
//    
//    var body: some View {
//        VStack {
//            if playlists.isEmpty {
//                if isLoadingPlaylists {
//                    HStack {
//                        ProgressView()
//                            .padding()
//                        Text("Loading Playlists")
//                            .font(.title)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                else if couldntLoadPlaylists {
//                    Text("Couldn't Load Playlists")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//                else {
//                    Text("No Playlists Found")
//                        .font(.title)
//                        .foregroundColor(.secondary)
//                }
//            }
//            else {
//                Text(
//                    """
//                    Tap on a playlist to play it. Tap and hold on a Playlist \
//                    to remove duplicates.
//                    """
//                )
//                .font(.caption)
//                .foregroundColor(.secondary)
//                List {
//                    ForEach(playlists, id: \.uri) { playlist in
//                        PlaylistCellView(spotify: spotify, playlist: playlist)
//                    }
//                }
//                .listStyle(PlainListStyle())
//                .accessibility(identifier: "Playlists List View")
//            }
//        }
//        .navigationTitle("Playlists")
//        .navigationBarItems(trailing: refreshButton)
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//        .onAppear(perform: retrievePlaylists)
//        
//    }
//    
//    var refreshButton: some View {
//        Button(action: retrievePlaylists) {
//            Image(systemName: "arrow.clockwise")
//                .font(.title)
//                .scaleEffect(0.8)
//        }
//        .disabled(isLoadingPlaylists)
//        
//    }
//    
//    func retrievePlaylists() {
//        
//        // Don't try to load any playlists if we're in preview mode.
//        if ProcessInfo.processInfo.isPreviewing { return }
//        
//        self.isLoadingPlaylists = true
//        self.playlists = []
//        spotify.api.currentUserPlaylists(limit: 50)
//            // Gets all pages of playlists.
//            .extendPages(spotify.api)
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: { completion in
//                    self.isLoadingPlaylists = false
//                    switch completion {
//                        case .finished:
//                            self.couldntLoadPlaylists = false
//                        case .failure(let error):
//                            self.couldntLoadPlaylists = true
//                            self.alert = AlertItem(
//                                title: "Couldn't Retrieve Playlists",
//                                message: error.localizedDescription
//                            )
//                    }
//                },
//                // We will receive a value for each page of playlists. You could
//                // use Combine's `collect()` operator to wait until all of the
//                // pages have been retrieved.
//                receiveValue: { playlistsPage in
//                    let playlists = playlistsPage.items
//                    self.playlists.append(contentsOf: playlists)
//                }
//            )
//            .store(in: &cancellables)
//
//    }
//    
//    
//}
//
//import SwiftUI
//import Combine
//import SpotifyWebAPI
//
//struct PlaylistCellView: View {
//    
//    @ObservedObject var spotify: Spotify
//
//    @ObservedObject var playlistDeduplicator: PlaylistDeduplicator
//
//    let playlist: Playlist<PlaylistItemsReference>
//
//    /// The cover image for the playlist.
//    @State private var image = Image(ImageName.spotifyAlbumPlaceholder)
//
//    @State private var didRequestImage = false
//    
//    @State private var alert: AlertItem? = nil
//    
//    // MARK: Cancellables
//    @State private var loadImageCancellable: AnyCancellable? = nil
//    @State private var playPlaylistCancellable: AnyCancellable? = nil
//    
//    init(spotify: Spotify, playlist: Playlist<PlaylistItemsReference>) {
//        self.spotify = spotify
//        self.playlist = playlist
//        self.playlistDeduplicator = PlaylistDeduplicator(
//            spotify: spotify, playlist: playlist
//        )
//    }
//    
//    var body: some View {
//        Button(action: playPlaylist, label: {
//            HStack {
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 70, height: 70)
//                    .padding(.trailing, 5)
//                Text("\(playlist.name) - \(playlistDeduplicator.totalItems) items")
//                if playlistDeduplicator.isDeduplicating {
//                    ProgressView()
//                        .padding(.leading, 5)
//                }
//                Spacer()
//            }
//            // Ensure the hit box extends across the entire width of the frame.
//            // See https://bit.ly/2HqNk4S
//            .contentShape(Rectangle())
//            .contextMenu {
//                // you can only remove duplicates from a playlist you own
//                if let currentUserId = spotify.currentUser?.id,
//                        playlist.owner?.id == currentUserId {
//                    
//                    Button("Remove Duplicates") {
//                        playlistDeduplicator.findAndRemoveDuplicates()
//                    }
//                    .disabled(playlistDeduplicator.isDeduplicating)
//                }
//            }
//        })
//        .buttonStyle(PlainButtonStyle())
//        .alert(item: $alert) { alert in
//            Alert(title: alert.title, message: alert.message)
//        }
//        .onAppear(perform: loadImage)
//        .onReceive(playlistDeduplicator.alertPublisher) { alert in
//            self.alert = alert
//        }
//    }
//    
//    /// Loads the image for the playlist.
//    func loadImage() {
//        
//        // Return early if the image has already been requested. We can't just
//        // check if `self.image == nil` because the image might have already
//        // been requested, but not loaded yet.
//        if self.didRequestImage {
//            // print("already requested image for '\(playlist.name)'")
//            return
//        }
//        self.didRequestImage = true
//        
//        guard let spotifyImage = playlist.images.largest else {
//            // print("no image found for '\(playlist.name)'")
//            return
//        }
//
//        // print("loading image for '\(playlist.name)'")
//        
//        // Note that a `Set<AnyCancellable>` is NOT being used so that each time
//        // a request to load the image is made, the previous cancellable
//        // assigned to `loadImageCancellable` is deallocated, which cancels the
//        // publisher.
//        self.loadImageCancellable = spotifyImage.load()
//            .receive(on: RunLoop.main)
//            .sink(
//                receiveCompletion: { _ in },
//                receiveValue: { image in
//                    // print("received image for '\(playlist.name)'")
//                    self.image = image
//                }
//            )
//    }
//    
//    func playPlaylist() {
//        
//        let playbackRequest = PlaybackRequest(
//            context: .contextURI(playlist), offset: nil
//        )
//        self.playPlaylistCancellable = self.spotify.api
//            .getAvailableDeviceThenPlay(playbackRequest)
//            .receive(on: RunLoop.main)
//            .sink(receiveCompletion: { completion in
//                if case .failure(let error) = completion {
//                    self.alert = AlertItem(
//                        title: "Couldn't Play Playlist \(playlist.name)",
//                        message: error.localizedDescription
//                    )
//                }
//            })
//        
//    }
//    
//}
//
//import Foundation
//import SwiftUI
//
///// The names of the image assets.
//enum ImageName: String {
//    
//    case spotifyLogoGreen = "spotify logo green"
//    case spotifyLogoWhite = "spotify logo white"
//    case spotifyLogoBlack = "spotify logo black"
//    case spotifyAlbumPlaceholder = "spotify album placeholder"
//}
//
//extension Image {
//    
//    /// Creates an image using `ImageName`, an enum which contains the names of
//    /// all the image assets.
//    init(_ name: ImageName) {
//        self.init(name.rawValue)
//    }
//    
//}
//
//extension UIImage {
//    
//    /// Creates an image using `ImageName`, an enum which contains the names of
//    /// all the image assets.
//    convenience init?(_ name: ImageName) {
//        self.init(named: name.rawValue)
//    }
//    
//}
//
//import Foundation
//import SwiftUI
//
//struct AlertItem: Identifiable {
//    
//    let id = UUID()
//    let title: Text
//    let message: Text
//    
//    init(title: String, message: String) {
//        self.title = Text(title)
//        self.message = Text(message)
//    }
//    
//    init(title: Text, message: Text) {
//        self.title = title
//        self.message = message
//    }
//
//}
//
//import Foundation
//import SwiftUI
//import SpotifyWebAPI
//
//extension View {
//    
//    /// Type erases self to `AnyView`. Equivalent to `AnyView(self)`.
//    func eraseToAnyView() -> AnyView {
//        return AnyView(self)
//    }
//
//}
//
//extension ProcessInfo {
//    
//    /// Whether or not this process is running within the context of a SwiftUI
//    /// preview.
//    var isPreviewing: Bool {
//        return self.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
//    }
//
//}
//
//import Foundation
//import Combine
//import SpotifyWebAPI
//
//extension SpotifyAPI where AuthorizationManager: SpotifyScopeAuthorizationManager {
//
//    /**
//     Makes a call to `availableDevices()` and plays the content on the active
//     device if one exists. Else, plays content on the first available device.
//     
//     See [Using the Player Endpoints][1].
//
//     - Parameter playbackRequest: A request to play content.
//
//     [1]: https://peter-schorn.github.io/SpotifyAPI/documentation/spotifywebapi/using-the-player-endpoints
//     */
//    func getAvailableDeviceThenPlay(
//        _ playbackRequest: PlaybackRequest
//    ) -> AnyPublisher<Void, Error> {
//        
//        return self.availableDevices().flatMap {
//            devices -> AnyPublisher<Void, Error> in
//    
//            // A device must have an id and must not be restricted in order to
//            // accept web API commands.
//            let usableDevices = devices.filter { device in
//                !device.isRestricted && device.id != nil
//            }
//
//            // If there is an active device, then it's usually a good idea to
//            // use that one. For example, if content is already playing, then it
//            // will be playing on the active device. If not, then just use the
//            // first available device.
//            let device = usableDevices.first(where: \.isActive)
//                    ?? usableDevices.first
//            
//            if let deviceId = device?.id {
//                return self.play(playbackRequest, deviceId: deviceId)
//            }
//            else {
//                return SpotifyGeneralError.other(
//                    "no active or available devices",
//                    localizedDescription:
//                    "There are no devices available to play content on. " +
//                    "Try opening the Spotify app on one of your devices."
//                )
//                .anyFailingPublisher()
//            }
//            
//        }
//        .eraseToAnyPublisher()
//        
//    }
//
//}
//
//extension PlaylistItem {
//    
//    /// Returns `true` if this playlist item is probably the same as `other` by
//    /// comparing the name, artist/show name, and duration.
//    func isProbablyTheSameAs(_ other: Self) -> Bool {
//        
//        // don't return true if both URIs are `nil`.
//        if let uri = self.uri, uri == other.uri {
//            return true
//        }
//        
//        switch (self, other) {
//            case (.track(let track), .track(let otherTrack)):
//                return track.isProbablyTheSameAs(otherTrack)
//        case (.episode(_), .episode(_)):
//                return false
//            default:
//                return false
//        }
//        
//    }
//    
//}
//
//extension Track {
//    
//    
//    /// Returns `true` if this track is probably the same as `other` by
//    /// comparing the name, artist name, and duration.
//    func isProbablyTheSameAs(_ other: Self) -> Bool {
//        
//        if self.name != other.name ||
//                self.artists?.first?.name != other.artists?.first?.name {
//            return false
//        }
//        
//        switch (self.durationMS, other.durationMS) {
//            case (.some(let durationMS), .some(let otherDurationMS)):
//                // use a relative tolerance of 10% and an absolute tolerance of
//                // ten seconds
//                return durationMS.isApproximatelyEqual(
//                    to: otherDurationMS,
//                    absoluteTolerance: 10_000,  // 10 seconds
//                    relativeTolerance: 0.1,
//                    norm: { Double($0) }
//                )
//            case (nil, nil):
//                return true
//            default:
//                return false
//        }
//        
//    }
//
//}
//
//// MARK: - Helper for deduplication
//struct URIsWithPositionsContainer {
//    let urisWithPosition: [(uri: SpotifyURIConvertible, position: Int)]
//    // Spotify API batch limits are typically 100
//    static func chunked(urisWithSinglePosition: [(uri: SpotifyURIConvertible, position: Int)], chunkSize: Int = 100) -> [URIsWithPositionsContainer] {
//        stride(from: 0, to: urisWithSinglePosition.count, by: chunkSize).map {
//            let chunk = Array(urisWithSinglePosition[$0..<min($0 + chunkSize, urisWithSinglePosition.count)])
//            return URIsWithPositionsContainer(urisWithPosition: chunk)
//        }
//    }
//}
//
