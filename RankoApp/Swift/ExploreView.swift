//
//  ExploreView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseAnalytics
import AlgoliaSearchClient

struct MiniGameEntry: Identifiable {
    let id = UUID()
    let name: String
    let image: String
}

struct MiniGame: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let color: Color
    let unlocked: String
    let message: String
}

struct MenuItemButtons: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let size: Int
    let message: String
    let color: Color
}

struct MenuItemButtons1: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct ExploreView: View {
    @StateObject private var user_data = UserInformation.shared
    @Namespace private var transition
    @State private var listViewID = UUID()
    @State private var isLoadingLists = true
    @State private var initialOffset = 0.0
    @State private var miniGameScrollID: MiniGame.ID?
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastID = UUID()
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var selectedList: RankoList?
    @State private var clonedList: RankoList?
    
    @State private var showBlindSequence = false
    
    let buttons: [MenuItemButtons] = [
        .init(title: "Search", icon: "magnifyingglass", size: 16, message: "Search and filter through all public Rankos from the community – Coming Soon!", color: Color(hex: 0x6D400F)),
        .init(title: "Picker", icon: "dice.fill", size: 18, message: "Pick a category, set filters, and let Ranko choose random items for you – Coming Soon!", color: Color(hex: 0x6D400F)),
        .init(title: "Store", icon: "cart.fill", size: 15, message: "A future Store may let you trade in-game currency for items, themes, and app icons – Stay tuned!", color: Color(hex: 0x6D400F))
    ]
    
    let miniGames: [MiniGame] = [
        .init(name: "Blind Sequence", image: "BlindSequenceImage", color: Color(hex: 0xBB3300), unlocked: "yes", message: "Maintenance works, please be patient"),
        .init(name: "Coming Soon", image: "ComingSoonImage", color: Color(hex: 0x979797), unlocked: "no", message: "More features and exciting mini-games are on the way – stay tuned!")
    ]

    // ✅ NEW: in-memory feed state
    @State private var feedLists: [RankoList] = []
    @State private var isFetchingBatch = false
    @State private var feedSessionID = UUID()
    
    private let isSimulator: Bool = {
        var isSim = false
        #if targetEnvironment(simulator)
        isSim = true
        #endif
        return isSim
    }()
    
    static var popularCategories: [String] {
        return ["Songs", "Science", "Basketball", "Countries", "Movies", "Food", "Mammals"]
    }
    
    // ✅ NEW: storage helpers
    private var melbourneTZ: TimeZone { TimeZone(identifier: "Australia/Melbourne") ?? .current }

    private func nowString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = melbourneTZ
        fmt.dateFormat = "yyyyMMddHHmmss"
        return fmt.string(from: Date())
    }

    private func parseTS(_ ts: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = melbourneTZ
        fmt.dateFormat = "yyyyMMddHHmmss"
        return fmt.date(from: ts)
    }

    private var storedIDs: [String] {
        get {
            (try? JSONDecoder().decode([String].self,
                                       from: Data(user_data.lastRefreshRankoIds.utf8))) ?? []
        }
        nonmutating set { // ← key change
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                user_data.lastRefreshRankoIds = json
            }
        }
    }

    // ✅ NEW: fetch (re)fill queue from Algolia and update timestamp
    private func refillIDsFromAlgoliaAndResetTimestamp(completion: (() -> Void)? = nil) {
        AlgoliaRankoView.shared.fetchTopPublicRankoIDs(limit: 100) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ids):
                    self.storedIDs = ids
                    self.user_data.lastRefreshTimestamp = self.nowString()
                case .failure(let error):
                    print("❌ Algolia fetch failed:", error)
                    self.storedIDs = [] // keep consistent
                }
                completion?()
            }
        }
    }

    // ✅ NEW: pop next N ids, save remainder
    private func popNextIDs(_ count: Int) -> [String] {
        var ids = storedIDs
        guard !ids.isEmpty else { return [] }
        let n = min(count, ids.count)
        let batch = Array(ids.prefix(n))
        ids.removeFirst(n)
        storedIDs = ids
        return batch
    }

    // ✅ NEW: fetch a single Ranko list from Firebase by objectID
    func intFromAny(_ any: Any?) -> Int? {
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String    { return Int(s) }
        if let d = any as? Double    { return Int(d) }
        return nil
    }

    func parseColourUInt(_ any: Any?) -> UInt {
        if let n = any as? NSNumber { return UInt(truncating: n) & 0x00FF_FFFF }
        if let i = any as? Int      { return UInt(i & 0x00FF_FFFF) }
        if let s = any as? String {
            var hex = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let dec = Int(hex) { return UInt(dec & 0x00FF_FFFF) }
            if hex.hasPrefix("#")  { hex.removeFirst() }
            if hex.hasPrefix("0x") { hex.removeFirst(2) }
            if let v = Int(hex, radix: 16) { return UInt(v & 0x00FF_FFFF) }
        }
        return 0x446D7A
    }
    
    private func fetchRankoList(_ objectID: String, completion: @escaping (RankoList?) -> Void) {
        let doc = FirestoreProvider.dbFilters.collection("ranko").document(objectID)

        doc.getDocument { snap, error in
            guard error == nil, let data = snap?.data() else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let name        = data["name"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            let type        = data["type"] as? String ?? "default"
            let userID      = data["user_id"] as? String ?? ""
            let status      = data["status"] as? String ?? "active"
            let privacy     = data["privacy"] as? Bool ?? false

            guard status == "active" else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let cat       = data["category_meta"] as? [String: Any]
            let catName   = data["category"] as? String ?? "Unknown"
            let catIcon   = cat?["icon"] as? String ?? "circle"
            let catColour = parseColourUInt(cat?["colour"])

            let time      = data["time"] as? [String: Any]
            let createdStr  = (time?["created"] as? String) ?? (time?["created"] as? Int).map(String.init) ?? "19700101000000"
            let updatedStr  = (time?["updated"] as? String) ?? (time?["updated"] as? Int).map(String.init) ?? createdStr

            var parsedItems: [RankoItem] = []
            var itemsNumber: Int? = nil
            if let num = data["items"] as? Int {
                itemsNumber = num
            }
            if let preview = data["preview"] as? [[String: Any]] {
                parsedItems = preview.enumerated().compactMap { idx, dict in
                    let id        = dict["id"] as? String ?? UUID().uuidString
                    let itemName  = dict["name"] as? String ?? ""
                    let itemImage = dict["image"] as? String ?? ""
                    let rank      = intFromAny(dict["rank"]) ?? (idx + 1)

                    let record = RankoRecord(
                        objectID: id,
                        ItemName: itemName,
                        ItemDescription: "",
                        ItemCategory: "",
                        ItemImage: itemImage,
                        ItemGIF: nil,
                        ItemVideo: nil,
                        ItemAudio: nil
                    )
                    return RankoItem(id: id, rank: rank, votes: 0, record: record, playCount: 0)
                }
            } else if let arr = data["items"] as? [[String: Any]] {
                parsedItems = arr.compactMap { dict in
                    let id        = dict["id"] as? String ?? UUID().uuidString
                    let itemName  = dict["name"] as? String ?? ""
                    let itemDesc  = dict["description"] as? String ?? ""
                    let itemImage = dict["image"] as? String ?? ""
                    let itemGIF   = dict["gif"] as? String
                    let itemVideo = dict["video"] as? String
                    let itemAudio = dict["audio"] as? String

                    let rank      = intFromAny(dict["rank"]) ?? 0
                    let votes     = intFromAny(dict["votes"]) ?? 0
                    let playCount = intFromAny(dict["playCount"]) ?? 0

                    let record = RankoRecord(
                        objectID: id,
                        ItemName: itemName,
                        ItemDescription: itemDesc,
                        ItemCategory: "",
                        ItemImage: itemImage,
                        ItemGIF: itemGIF,
                        ItemVideo: itemVideo,
                        ItemAudio: itemAudio
                    )

                    return RankoItem(
                        id: id,
                        rank: rank,
                        votes: votes,
                        record: record,
                        playCount: playCount
                    )
                }
            }

            let list = RankoList(
                id: objectID,
                listName: name,
                listDescription: description,
                type: type,
                categoryName: catName,
                categoryIcon: catIcon,
                categoryColour: catColour,
                isPrivate: privacy ? "Private" : "Public",
                userCreator: userID,
                timeCreated: createdStr,
                timeUpdated: updatedStr,
                itemsNumber: itemsNumber ?? parsedItems.count,
                items: parsedItems.sorted { $0.rank < $1.rank }
            )

            DispatchQueue.main.async { completion(list) }
        }
    }

    // ✅ NEW: load next batch of 6 (refill queue if needed)
    private func loadNextBatch() {
        guard !isFetchingBatch else { return }
        isFetchingBatch = true

        func loadFromQueue() {
            var ids = popNextIDs(6)

            // If queue is empty AFTER popping, we still proceed with what we got;
            // if we got none, refill then try again.
            if ids.isEmpty {
                refillIDsFromAlgoliaAndResetTimestamp {
                    ids = self.popNextIDs(6)
                    loadIDs(ids)
                }
            } else {
                loadIDs(ids)
            }
        }

        func loadIDs(_ ids: [String]) {
            if ids.isEmpty {
                self.isFetchingBatch = false
                return
            }
            let group = DispatchGroup()
            var newLists: [RankoList] = []

            ids.forEach { id in
                group.enter()
                fetchRankoList(id) { list in
                    if let list = list, list.isPrivate == "Public" { newLists.append(list) }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                // simple order: newest first by RankoDateTime
                self.feedLists.append(contentsOf: newLists.sorted { $0.timeUpdated > $1.timeUpdated })
                self.isFetchingBatch = false
                self.isLoadingLists = false
            }
        }

        loadFromQueue()
    }

    // ✅ NEW: check 3-hour window and prep initial 6
    private func ensureQueueAndInitialBatch() {
        // update the timestamp (if needed) every time HomeView opens
        let needsRefresh: Bool = {
            guard let last = parseTS(user_data.lastRefreshTimestamp) else { return true }
            let delta = Date().timeIntervalSince(last)
            return delta >= (3 * 3600) // 3 hours
        }()

        if needsRefresh || storedIDs.isEmpty {
            refillIDsFromAlgoliaAndResetTimestamp {
                self.feedLists.removeAll()
                self.loadNextBatch()
            }
        } else {
            // under 3h → just pull next 6 from the queue
            self.feedLists.removeAll()
            self.loadNextBatch()
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView(.vertical) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Explore")
                                .font(.custom("Nunito-Black", size: 36))
                                .foregroundStyle(Color(hex: 0x514343))
                            Spacer()
                            ProfileIconView(diameter: CGFloat(50))
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)

                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white)
                                .shadow(color: Color(hex: 0x000000).opacity(0.12), radius: 10, x: 0, y: 6)
                            VStack(spacing: 10) {
                                Button {
                                    showComingSoonToast("Search and filter through all public Rankos from the community – Coming Soon!")
                                } label: {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 16, weight: .black))
                                        Text("Search Rankos")
                                            .font(.custom("Nunito-Black", size: 17))
                                        Spacer()
                                        Button {
                                            showComingSoonToast("Search and filter through all public Rankos from the community – Coming Soon!")
                                        } label: {
                                            HStack {
                                                Image(systemName: "line.3.horizontal.decrease")
                                                    .font(.system(size: 15, weight: .black))
                                                Text("Filter")
                                                    .font(.custom("Nunito-Black", size: 14))
                                            }
                                        }
                                        .buttonStyle(.glassProminent)
                                        .tint(Color(hex: 0xFFFFFF))
                                        .foregroundStyle(Color(hex: 0x595959))
                                        .padding(4)
                                    }
                                }
                                .buttonStyle(.glassProminent)
                                .tint(Color(hex: 0xE8E8E8))
                                .foregroundStyle(Color(hex: 0x595959))
                                HStack(spacing: 15) {
                                    Button {
                                        showComingSoonToast("Pick a category, set filters, and let Ranko choose random items for you – Coming Soon!")
                                    } label: {
                                        HStack {
                                            Image(systemName: "dice.fill")
                                                .font(.system(size: 14, weight: .black))
                                            Text("Random Picker")
                                                .font(.custom("Nunito-Black", size: 15))
                                        }
                                        .padding(4)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .tint(Color(hex: 0xE8E8E8))
                                    .foregroundStyle(Color(hex: 0x595959))
                                    .colorScheme(.light)
                                    
                                    Button {
                                        showComingSoonToast("A future Store may let you trade in-game currency for items, themes, and app icons – Stay tuned!")
                                    } label: {
                                        HStack {
                                            Image(systemName: "basket.fill")
                                                .font(.system(size: 14, weight: .black))
                                            Text("Ranko Store")
                                                .font(.custom("Nunito-Black", size: 15))
                                        }
                                        .padding(4)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .tint(Color(hex: 0xE8E8E8))
                                    .foregroundStyle(Color(hex: 0x595959))
                                    .colorScheme(.dark)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 13)
                        
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Mini Games")
                                    .font(.custom("Nunito-Black", size: 23))
                                    .foregroundStyle(Color(hex: 0x080808))
                                Spacer(minLength: 0)
                            }
                            .padding(.top, 10)
                            .padding(.leading, 25)
                            
                            HStack {
                                Text("Enjoy some of these mini games, made for fun")
                                    .font(.custom("Nunito-Black", size: 15))
                                    .foregroundStyle(Color(hex: 0x929292))
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 25)

                            GeometryReader { geo in
                                let cardWidth = geo.size.width * 0.55
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(miniGames) { game in
                                            Button {
                                                if game.unlocked != "yes" {
                                                    showComingSoonToast(game.message)
                                                } else {
                                                    switch game.name {
                                                    case "Blind Sequence":
                                                        showBlindSequence = true
                                                    default:
                                                        showComingSoonToast("New Feature Coming Soon!")
                                                    }
                                                }
                                            } label: {
                                                VStack {
                                                    VStack {
                                                        Image(game.image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .frame(width: cardWidth, height: 139)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .fill(game.color)
                                                    )
                                                    VStack(spacing: 4) {
                                                        HStack {
                                                            Text(game.name)
                                                                .font(.custom("Nunito-Black", size: 20))
                                                                .foregroundStyle(Color(hex: 0x080808))
                                                            Spacer(minLength: 0)
                                                        }
                                                        .padding(.top, 10)
                                                        
                                                        if game.unlocked == "yes" {
                                                            HStack(alignment: .center) {
                                                                Text("4.2")
                                                                    .font(.custom("Nunito-Black", size: 15))
                                                                    .foregroundStyle(Color(hex: 0x080808))
                                                                Image(systemName: "star.fill")
                                                                    .font(.custom("Nunito-Black", size: 14))
                                                                    .foregroundStyle(Color(hex: 0x080808))
                                                                    .padding(.bottom, 2)
                                                                Text("2+ Playing Right Now")
                                                                    .font(.custom("Nunito-Black", size: 15))
                                                                    .foregroundStyle(Color(hex: 0x929292))
                                                                Spacer(minLength: 0)
                                                            }
                                                        } else {
                                                            HStack {
                                                                Image(systemName: "timer")
                                                                    .font(.custom("Nunito-Black", size: 15))
                                                                    .foregroundStyle(Color(hex: 0x929292))
                                                                Text("April 2026")
                                                                    .font(.custom("Nunito-Black", size: 15))
                                                                    .foregroundStyle(Color(hex: 0x929292))
                                                                Spacer(minLength: 0)
                                                            }
                                                        }
                                                    }
                                                }
                                                .frame(width: cardWidth)
                                            }
                                            .id(game.id)
                                        }
                                    }
                                    .scrollTargetLayout()
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 5)
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .scrollPosition(id: $miniGameScrollID)
                            }
                            .frame(height: 235)
                        }
                        .padding(.top, 7)
                        
                        
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("Trending Today")
                                    .font(.custom("Nunito-Black", size: 23))
                                    .foregroundStyle(Color(hex: 0x080808))
                                Spacer(minLength: 0)
                            }
                            .padding(.top, 10)
                            .padding(.leading, 25)
                            
                            HStack {
                                Text("Check out today's top 100")
                                    .font(.custom("Nunito-Black", size: 15))
                                    .foregroundStyle(Color(hex: 0x929292))
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 25)

                            ScrollView(.horizontal, showsIndicators: false) {
                                if isLoadingLists || (feedLists.isEmpty && isFetchingBatch) {
                                    // 🔁 SKELETONS (HORIZONTAL)
                                    LazyHStack(spacing: 14) {
                                        ForEach(0..<6, id: \.self) { _ in
                                            ExploreListSkeletonViewRow()
                                                .frame(width: 260, height: 220)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .id(feedSessionID) // <- drop subtree on refresh
                                } else {
                                    // ✅ FEED (HORIZONTAL)
                                    LazyHStack(spacing: 14) {
                                        ForEach(feedLists, id: \.id) { list in
                                            if list.type == "default" {
                                                DefaultListExploreView(
                                                    listData: list,
                                                    onCommentTap: { msg in
                                                        showComingSoonToast(msg)
                                                    },
                                                    onRankoTap: { _ in
                                                        selectedList = list
                                                    },
                                                    onProfileTap: { _ in }
                                                )
                                            } else if list.type == "tier" {
                                                TierListExploreView(
                                                    listData: list,
                                                    onCommentTap: { msg in
                                                        showComingSoonToast(msg)
                                                    },
                                                    onRankoTap: { _ in
                                                        selectedList = list
                                                    },
                                                    onProfileTap: { _ in }
                                                )
                                            }
                                        }
                                    }
                                    .scrollTargetLayout()
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .id(feedSessionID) // <- drop subtree on refresh
                                }
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .safeAreaPadding(.trailing, 15)
                        }
                    }
                    .padding(.bottom, 100)
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
        }
        .animation(.easeInOut(duration: 0.25), value: toastID)
        .fullScreenCover(isPresented: $showBlindSequence) {
            BlindSequence()
                .navigationTransition(
                    .zoom(sourceID: "Blind Sequence Button", in: transition)
                )
                .interactiveDismissDisabled()
        }
        
        .fullScreenCover(item: $selectedList) { list in
            if list.type == "default" {
                DefaultListSpectate(rankoID: list.id, onClone: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        clonedList = list
                    }
                })
            } else if list.type == "tier" {
                TierListSpectate(rankoID: list.id, onClone: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        clonedList = list
                    }
                })
            }
        }
        
        .fullScreenCover(item: $clonedList) { list in
            DefaultListView(rankoName: list.listName, description: list.listDescription, isPrivate: false, categoryName: list.categoryName, categoryIcon: list.categoryIcon, categoryColour: list.categoryColour, selectedRankoItems: list.items, onSave: { _ in})
        }
        
        .onAppear {
            user_data.userID = Auth.auth().currentUser?.uid ?? "0"
            listViewID = UUID()
            if miniGameScrollID == nil {
                miniGameScrollID = miniGames.first?.id
            }
            
            if isSimulator {
                // show mocked feed if you want
                isLoadingLists = false
                print("ℹ️ Simulator detected — skipping Firebase calls.")
            } else {
                isLoadingLists = true
                
                // ✅ ensure queue + initial batch of 6
                ensureQueueAndInitialBatch()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoadingLists = false
                }
                
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                    AnalyticsParameterScreenName: "Explore",
                    AnalyticsParameterScreenClass: "ExploreView"
                ])
            }
        }
        .refreshable {
            // 1) blank UI immediately
            feedSessionID = UUID()   // drop the subtree
            feedLists.removeAll()
            isFetchingBatch = false
            isLoadingLists = true

            // 2) (optional) force a brand-new 100 from Algolia by clearing the queue:
            // storedIDs = []
            // user_data.lastRefreshTimestamp = ""

            // 3) rebuild from scratch (this will load the first 6)
            ensureQueueAndInitialBatch()
        }
    }
    
    private func showComingSoonToast(_ msg: String) {
        toastMessage = msg
        toastID = UUID()
        showToast = true
        
        toastDismissWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation { showToast = false }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}

struct DefaultListExploreView: View {
    let listData: RankoList
    @StateObject private var user_data = UserInformation.shared
    
    // Profile & creator info
    @State private var creatorName: String = ""
    
    // Likes & comments
    @State private var likes: [String: String] = [:]
    @State private var commentsCount: Int = 0
    @State private var isLikeDisabled = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var animateHeart = false
    @State private var spectateProfile: Bool = false
    @State private var openShareView: Bool = false
    var onCommentTap: (String) -> Void
    var onRankoTap: (String) -> Void
    var onProfileTap: (String) -> Void
    
    private var previewItems: [RankoItem] {
        // Use provided preview items (already mapped into listData.items) and limit to top 5 for defaults
        let items = listData.items
        if listData.type.lowercased() == "tier" { return items }
        return Array(items.prefix(5))
    }
    private var firstBlock: [RankoItem] { Array(previewItems.prefix(3)) }
    private var remainder: [RankoItem] { Array(previewItems.dropFirst(3)) }
    
    private var creatorImageURL: URL? {
        URL(string: "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/profilePictures%2F\(listData.userCreator).jpg?alt=media&token=\(user_data.userID)")
    }
    
    // MARK: — Helpers to compute “safe” UID & whether we’ve liked
    private var safeUID: String {
        let raw = Auth.auth().currentUser?.uid ?? user_data.userID
        return raw.components(separatedBy: CharacterSet(charactersIn: ".#$[]")).joined()
    }
    private var hasLiked: Bool {
        likes.keys.contains(safeUID)
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                AsyncImage(url: creatorImageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                    case .empty:
                        SkeletonView(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.gray.opacity(0.4))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(creatorName)
                            .font(.custom("Nunito-Black", size: 13))
                            .foregroundColor(Color(hex: 0x000000))
                        Text("•")
                            .font(.custom("Nunito-Black", size: 11))
                            .foregroundColor(Color(hex: 0x818181))
                        Text(timeAgo(from: String(listData.timeUpdated)))
                            .font(.custom("Nunito-Black", size: 11))
                            .foregroundColor(Color(hex: 0x818181))
                        Spacer()
                    }
                    Text(listData.listName.count > 30 ? "\(listData.listName.prefix(28))..." : listData.listName)
                        .font(.custom("Nunito-Black", size: 17))
                        .foregroundColor(Color(hex: 0x666666))
                        .padding(.bottom, -15)
                }
                .padding(.leading, 8)
                Spacer()
            }
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                    itemsSection
                }
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                        .overlay(
                            Rectangle()
                                .fill(Color(hex: 0x707070))
                                .frame(width: 2)
                                .opacity(0.3)
                        )
                    Spacer()
                }
            }
            HStack {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                    HomeCategoryBadge1(
                        name: listData.categoryName,
                        colour: listData.categoryColour,   // UInt from Firebase
                        icon: listData.categoryIcon        // SF Symbol name from Firebase
                    )
                }
                
                HStack(spacing: 4) {
                    LikeButton(isLiked: hasLiked, onTap: handleLikeTap)
                    Text("\(likes.count)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Color(hex: 0x666666))
                }
                .padding(.horizontal, 8)
                
                Button {
                    // pass a custom message or a static one:
                    onCommentTap("Interacting on Friends & Community Rankos Are Coming Soon!")
                } label: {
                    Image(systemName: "bubble.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Color(hex: 0x666666))
                    Text("\(commentsCount)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Color(hex: 0x666666))
                }
                .padding(.trailing, 8)
                
                Button {
                    openShareView = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Color(hex: 0x666666))
                }
                Spacer()
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(color: Color(hex: 0x000000).opacity(0.22), radius: 6, x: 0, y: 0)
        )
        .overlay(
            Group {
                if showToast {
                    Text(toastMessage)
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                }
            }, alignment: .bottom
        )
        .onAppear {
            fetchCreatorName()
            fetchLikes()
            fetchComments()
        }
        .sheet(isPresented: $spectateProfile) {
            //ProfileSpectateView(userID: (listData.userCreator))
        }
        .sheet(isPresented: $openShareView) {
            //ProfileSpectateView(userID: (listData.userCreator))
        }
    }
    
    private func positionForItem(_ item: RankoItem) -> Int? {
        // prefer matching by id; if your RankoItem doesn't have `id`,
        // swap to another unique key (e.g. itemName + image url).
        if let idx = previewItems.firstIndex(where: { $0.id == item.id }) {
            return idx + 1
        }
        return nil
    }
    
    @ViewBuilder
    private func badgeView(forPosition position: Int) -> some View {
        // colors for 1/2/3 stay special; others default to black
        let color: Color = {
            switch position {
            case 1: return Color(red: 1, green: 0.65, blue: 0)            // gold-ish
            case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)      // silver-ish
            case 3: return Color(red: 0.56, green: 0.33, blue: 0)          // bronze-ish
            default: return Color(hex: 0x000000)
            }
        }()

        // SF Symbols provide numbered circles up to 50; fallback to text if bigger
        if (1...50).contains(position) {
            Image(systemName: "\(position).circle.fill")
                .foregroundColor(color)
                .font(.system(size: 15, weight: .black, design: .default))
                .padding(2)
                .background(Circle().fill(Color.white))
                .offset(x: 7, y: 7)
        } else {
            ZStack {
                Circle().fill(Color.white)
                Text("\(position)")
                    .font(.system(size: 11, weight: .black, design: .default))
                    .foregroundColor(color)
            }
            .frame(width: 19, height: 19)
            .offset(x: 7, y: 7)
        }
    }
    
    private var itemsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // pass halfWidth as the minimum
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(firstBlock) { item in
                        itemRow(item)
                    }
                }
                // use minWidth instead of fixed width, and align its content leading
                .frame(minWidth: 270, alignment: .leading)
                
                if remainder.count >= 4 {
                    if remainder.count == 4 {
                        // exactly 10 items → show the 10th
                        let item10 = remainder[3]
                        HStack(spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                AsyncImage(url: URL(string: item10.itemImage)) { phase in
                                    if let img = phase.image {
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Color.gray.opacity(0.2)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                if let pos = positionForItem(item10) {
                                    badgeView(forPosition: pos)
                                }
                            }
                            Text(item10.itemName)
                                .font(.custom("Nunito-Black", size: 17))
                                .foregroundColor(Color(hex: 0x666666))
                                .lineLimit(1)
                                .padding(.leading, 6)
                        }
                    } else {
                        // >10 items → show “+N” where N = total-9
                        Color.gray.opacity(0.2)
                            .frame(width: 47, height: 47)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Text("+\(listData.items.count - 3)")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(Color(hex: 0x666666))
                            )
                    }
                }
            }
            .padding(.vertical, 4)
            // force the entire HStack to stick to the left
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 240)
    }
    
    private func itemRow(_ item: RankoItem) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    if let img = phase.image {
                        img.resizable()
                            .scaledToFill()
                            .frame(width: 47, height: 47)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(width: 47, height: 47)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                if let pos = positionForItem(item) {
                    badgeView(forPosition: pos)
                }
            }
            Text(item.itemName.count > 25 ? "\(item.itemName.prefix(23))..." : item.itemName)
                .font(.custom("Nunito-Black", size: 17))
                .foregroundColor(Color(hex: 0x666666))
                .lineLimit(1)
                .padding(.leading, 6)
        }
    }
    
    // MARK: — Like handling (unchanged)
    private func handleLikeTap() {
        guard !isLikeDisabled else {
            showInlineToast("Calm down! Wait a few seconds.")
            return
        }
        isLikeDisabled = true

        let ts = currentAEDTString()
        let likeDoc = FirestoreProvider.dbFilters
            .collection("ranko")
            .document(listData.id)
            .collection("likes")
            .document(safeUID)

        // 1) Optimistically update local state
        let currentlyLiked = hasLiked
        if currentlyLiked {
            likes.removeValue(forKey: safeUID)
        } else {
            likes[safeUID] = ts
        }

        // 2) Read once to confirm server state
        likeDoc.getDocument { snap, error in
            if let error = error {
                print("Read error:", error)
                // Roll back optimistic change
                if currentlyLiked {
                    likes[safeUID] = ts
                } else {
                    likes.removeValue(forKey: safeUID)
                }
                isLikeDisabled = false
                showInlineToast("Network error.")
                return
            }

            if let snap = snap, snap.exists {
                // 👎 Unlike on server
                likeDoc.delete { error in
                    if let error = error {
                        likes[safeUID] = ts
                        print("Error removing like:", error)
                        showInlineToast("Couldn’t remove like.")
                    }
                    isLikeDisabled = false
                }
            } else {
                // 👍 Like on server
                likeDoc.setData(["time": ts]) { error in
                    if let error = error {
                        likes.removeValue(forKey: safeUID)
                        print("Error adding like:", error)
                        showInlineToast("Couldn’t add like.")
                    }
                    isLikeDisabled = false
                }
            }
        }
    }
    
    private func showInlineToast(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
        }
    }
    
    // MARK: — Data fetches
    private func fetchCreatorName() {
        let userDoc = FirestoreProvider.dbFilters.collection("users").document(listData.userCreator)

        Task {
            do {
                let snap = try await userDoc.getDocument()
                guard let value = snap.data() else {
                    print("❌ Could Not Load User Data for HomeView Rankos with UserID: \(listData.userCreator)")
                    return
                }

                self.creatorName = value["name"] as? String ?? ""
                
            } catch {
                print("❌ Could Not Load User Data for HomeView Rankos with UserID: \(listData.userCreator)")
            }
        }
    }
    
    // MARK: — Fetch likes
    private func fetchLikes() {
        Task {
            do {
                let snap = try await FirestoreProvider.dbFilters
                    .collection("ranko")
                    .document(listData.id)
                    .collection("likes")
                    .getDocuments()
                var dict: [String: String] = [:]
                for d in snap.documents {
                    let t = d.data()["time"] as? String ?? ""
                    dict[d.documentID] = t
                }
                await MainActor.run { likes = dict }
            } catch {
                print("❌ Failed to fetch likes from Firestore:", error.localizedDescription)
            }
        }
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoLikes", value: AJSON(likes.count)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                print("❌ Algolia update failed:", error)
            }
        }
    }
    
    private func fetchComments() {
        Task {
            do {
                let snap = try await FirestoreProvider.dbFilters
                    .collection("ranko")
                    .document(listData.id)
                    .collection("comments")
                    .getDocuments()
                await MainActor.run { commentsCount = snap.documents.count }
            } catch {
                print("❌ Failed to fetch comments from Firestore:", error.localizedDescription)
            }
        }
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoComments", value: AJSON(commentsCount)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                print("❌ Algolia update failed:", error)
            }
        }
    }
    
    // MARK: — Helpers
    private func timeAgo(from dt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"

        guard let date = formatter.date(from: dt) else {
            print("Failed to parse date from string: \(dt)")
            return ""
        }

        let now = Date()
        let secondsAgo = Int(now.timeIntervalSince(date))

        switch secondsAgo {
        case 0..<60:
            return "\(secondsAgo)s ago"
        case 60..<3600:
            return "\(secondsAgo / 60)m ago"
        case 3600..<86400:
            return "\(secondsAgo / 3600)h ago"
        case 86400..<604800:
            return "\(secondsAgo / 86400)d ago"
        case 604800..<31536000:
            return "\(secondsAgo / 604800)w ago"
        default:
            return "\(secondsAgo / 31536000)y ago"
        }
    }

    
    private func currentAEDTString() -> String {
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        fmt.dateFormat = "yyyyMMddHHmmss"
        return fmt.string(from: now)
    }
    
    
    
    struct LikeButton: View {
        let isLiked: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button {
                onTap()
            } label: {
                ZStack {
                    image(Image(systemName: "heart.fill"), show: isLiked)
                    image(Image(systemName: "heart.fill"),      show: !isLiked)
                }
            }
            
        }
        
        private func image(_ image: Image, show: Bool) -> some View {
            image
                .tint(isLiked ? Color(hex: 0xDA0D0D) : Color(hex: 0x666666))
                .font(.system(size: 16, weight: .black))
                .scaleEffect(show ? 1 : 0)
                .opacity(show ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: show)
        }
    }
}

struct TierListExploreView: View {
    let listData: RankoList
    var onCommentTap: (String) -> Void
    var onRankoTap: (String) -> Void
    var onProfileTap: (String) -> Void

    private var adjustedItems: [RankoItem] {
        listData.items.map { item in
            var newItem = item
            // Adjust rank: e.g., 1003 → 1, 4005 → 4
            let rawRank = item.rank
            let adjustedRank = rawRank / 1000
            newItem.rank = adjustedRank
            return newItem
        }
    }

    var body: some View {
        DefaultListExploreView(listData: RankoList(
            id: listData.id,
            listName: listData.listName,
            listDescription: listData.listDescription,
            type: listData.type,
            categoryName: listData.categoryName,
            categoryIcon: listData.categoryIcon,
            categoryColour: listData.categoryColour,
            isPrivate: listData.isPrivate,
            userCreator: listData.userCreator,
            timeCreated: listData.timeUpdated,
            timeUpdated: listData.timeUpdated,
            items: adjustedItems
        ), onCommentTap: onCommentTap, onRankoTap: onRankoTap, onProfileTap: onProfileTap)
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


struct ExploreListSkeletonViewRow: View {
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                // avatar
                SkeletonView(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 42, height: 42)
                
                // name / time / badge
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                            .frame(width: CGFloat.random(in: 50...100), height: 11)
                        SkeletonView(Circle())
                            .frame(width: 4, height: 4)
                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                            .frame(width: 40, height: 11)
                    }
                    // MARK: Title skeleton
                    SkeletonView(RoundedRectangle(cornerRadius: 4))
                        .frame(height: 14)
                        .padding(.trailing, CGFloat.random(in: 5...40))
                }
                .padding(.leading, 8)
                Spacer()
            }
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 24) {
                            // Left column (first 5)
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<3) { _ in
                                    HStack(spacing: 8) {
                                        SkeletonView(RoundedRectangle(cornerRadius: 8))
                                            .frame(width: 47, height: 47)
                                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                                            .frame(width: CGFloat.random(in: 60...110), height: 14)
                                    }
                                }
                                SkeletonView(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 47, height: 47)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 240, height: 240)
                }
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                        .overlay(
                            SkeletonView(Rectangle())
                                .frame(width: 2)
                        )
                    Spacer()
                }
            }
            
            HStack {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                    SkeletonView(Circle())
                        .frame(width: 32, height: 32)
                }
                HStack(spacing: 4) {
                    SkeletonView(Circle())
                        .frame(width: 24, height: 24)
                    SkeletonView(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 20, height: 14)
                }
                .padding(.horizontal, 8)
                
                HStack(spacing: 4) {
                    SkeletonView(Circle())
                        .frame(width: 24, height: 24)
                    SkeletonView(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 20, height: 14)
                }
                .padding(.trailing, 8)
                
                SkeletonView(Circle())
                    .frame(width: 24, height: 24)
                
                Spacer()
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(color: Color(hex: 0x000000).opacity(0.22), radius: 6, x: 0, y: 0)
        )
    }
}
