//
//  HomeView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import Firebase
import FirebaseAuth
import AlgoliaSearchClient

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

var isiOS26: Bool {
    if #available(iOS 26, *) {
        return true
    } else {
        return false
    }
}

/// Checks if a simulator is running the app or if it's a real device
let isSimulator: Bool = {
    var isSim = false
    #if targetEnvironment(simulator)
    isSim = true
    #endif
    return isSim
}()

final class AlgoliaRankoView {
    static let shared = AlgoliaRankoView()

    private let client = SearchClient(
        appID: ApplicationID(rawValue: Secrets.algoliaAppID),
        apiKey: APIKey(rawValue: Secrets.algoliaAPIKey)
    )
    private let index: Index

    private init() {
        self.index = client.index(withName: "RankoLists")
    }

    /// Top public Ranko objectIDs from Algolia (respects default ranking)
    func fetchTopPublicRankoIDs(limit: Int = 100, completion: @escaping (Result<[String], Error>) -> Void) {
        var query = Query("")
        query.hitsPerPage = limit
        query.filters = "RankoPrivacy:false AND RankoStatus:active" // public + active

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let ids: [String] = response.hits.compactMap { $0.objectID.rawValue }
                completion(.success(ids))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    // MARK: - Variables
    @EnvironmentObject private var imageService: ProfileImageService
    @StateObject private var user_data = UserInformation.shared
    @Namespace private var transition
    @State private var showPicker: Bool = false
    @State private var profileImage: UIImage?
    @State private var listViewID = UUID()
    @State private var feedSessionID = UUID()
    @State private var isLoadingLists = true
    @State private var trayViewOpen = false
    @State private var showCategorySheet = false
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastID = UUID()
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var selectedList: RankoList?
    @State private var clonedList: RankoList?

    // ✅ NEW: in-memory feed state
    @State private var feedLists: [RankoList] = []
    @State private var isFetchingBatch = false
    
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
    private func fetchRankoList(_ objectID: String, completion: @escaping (RankoList?) -> Void) {
        let ref = Database.database().reference()
            .child("RankoData")
            .child(objectID)

        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let s = any as? String    { return Int(s) }
            if let d = any as? Double    { return Int(d) }
            return nil
        }

        func parseColourUInt(_ any: Any?) -> UInt {
            // accepts "0xFFCF00", "#FFCF00", "FFCF00", 16763904, NSNumber, etc.
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

        ref.observeSingleEvent(of: .value, with: { snap in
            guard let root = snap.value as? [String: Any] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // ======== NEW SCHEMA PREFERRED ========
            if let details = root["RankoDetails"] as? [String: Any] {
                let privacy = root["RankoPrivacy"] as? [String: Any]
                let cat     = root["RankoCategory"] as? [String: Any]
                let items   = root["RankoItems"] as? [String: Any] ?? [:]
                let dt      = root["RankoDateTime"] as? [String: Any]

                let name        = (details["name"] as? String) ?? ""
                let description = (details["description"] as? String) ?? ""
                let type        = (details["type"] as? String) ?? "default"
                let userID      = (details["user_id"] as? String) ?? ""

                let isPrivBool  = (privacy?["private"] as? Bool) ?? false

                let catName     = (cat?["name"] as? String) ?? ""
                let catIcon     = (cat?["icon"] as? String) ?? "circle"
                let catColour   = parseColourUInt(cat?["colour"])

                let createdStr  = (dt?["created"] as? String) ?? ""
                let updatedStr  = (dt?["updated"] as? String) ?? createdStr

                let parsedItems: [RankoItem] = items.compactMap { (k, v) in
                    guard let it = v as? [String: Any] else { return nil }
                    guard
                        let itemName  = it["ItemName"] as? String,
                        let itemDesc  = it["ItemDescription"] as? String,
                        let itemImage = it["ItemImage"] as? String,
                        let itemGIF    = it["ItemGIF"] as? String,
                        let itemVideo    = it["ItemVideo"] as? String,
                        let itemAudio    = it["ItemAudio"] as? String
                    else { return nil }
                    let rank  = intFromAny(it["ItemRank"])  ?? 0
                    let votes = intFromAny(it["ItemVotes"]) ?? 0
                    let rec = RankoRecord(objectID: k, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                    let plays = intFromAny(it["PlayCount"]) ?? 0
                    return RankoItem(id: k, rank: rank, votes: votes, record: rec, playCount: plays)
                }

                let list = RankoList(
                    id: objectID,
                    listName: name,
                    listDescription: description,
                    type: type,
                    categoryName: catName,
                    categoryIcon: catIcon,
                    categoryColour: catColour,
                    isPrivate: isPrivBool ? "Private" : "Public",
                    userCreator: userID,
                    timeCreated: createdStr,
                    timeUpdated: updatedStr,
                    items: parsedItems.sorted { $0.rank < $1.rank }
                )
                DispatchQueue.main.async { completion(list) }
                return
            }

            // ======== LEGACY SCHEMA FALLBACK ========
            guard
                let name        = root["RankoName"] as? String,
                let description = root["RankoDescription"] as? String,
                let type        = root["RankoType"] as? String,
                let isPrivBool  = root["RankoPrivacy"] as? Bool,
                let userID      = root["RankoUserID"] as? String
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var createdStr = ""
            var updatedStr = ""
            if let dt = root["RankoDateTime"] as? [String: Any] {
                // older keys
                createdStr = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? ""
                updatedStr = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? createdStr
            } else if let s = root["RankoDateTime"] as? String {
                createdStr = s
                updatedStr = s
            }

            var catName = "Unknown"
            var catIcon = "circle"
            var catColourUInt: UInt = 0x446D7A
            if let catObj = root["RankoCategory"] as? [String: Any] {
                catName = (catObj["name"] as? String) ?? catName
                catIcon = (catObj["icon"] as? String) ?? catIcon
                catColourUInt = parseColourUInt(catObj["colour"])
            } else if let catStr = root["RankoCategory"] as? String {
                catName = catStr
            }

            let itemsDict = root["RankoItems"] as? [String: [String: Any]] ?? [:]
            let items: [RankoItem] = itemsDict.compactMap { itemID, it in
                guard
                    let itemName  = it["ItemName"] as? String,
                    let itemDesc  = it["ItemDescription"] as? String,
                    let itemImage = it["ItemImage"] as? String,
                    let itemGIF    = it["ItemGIF"] as? String,
                    let itemVideo    = it["ItemVideo"] as? String,
                    let itemAudio    = it["ItemAudio"] as? String
                else { return nil }
                let rank  = intFromAny(it["ItemRank"])  ?? 0
                let votes = intFromAny(it["ItemVotes"]) ?? 0
                let rec = RankoRecord(objectID: itemID, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                let plays = intFromAny(it["PlayCount"]) ?? 0
                return RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            }

            let list = RankoList(
                id: objectID,
                listName: name,
                listDescription: description,
                type: type,
                categoryName: catName,
                categoryIcon: catIcon,
                categoryColour: catColourUInt,
                isPrivate: isPrivBool ? "Private" : "Public",
                userCreator: userID,
                timeCreated: createdStr,
                timeUpdated: updatedStr,
                items: items.sorted { $0.rank < $1.rank }
            )

            DispatchQueue.main.async { completion(list) }
        })
    }

    // Helper to safely coerce Firebase numbers/strings into Int
    private func intFromAny(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
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
                    LazyVStack {
                        HStack {
                            Text("Home")
                                .font(.custom("Nunito-Black", size: 36))
                                .foregroundStyle(Color(hex: 0x514343))
                            Spacer()
                            ProfileIconView(diameter: CGFloat(50))
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.popularCategories, id: \.self) { category in
                                    Button {
                                        showCategorySheet = true
                                    } label: {
                                        HStack {
                                            Image(systemName: FilterChip.icon(named: category, in: defaultFilterChips) ?? "circle.fill")
                                                .font(.system(size: 14, weight: .black, design: .default))
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                            Text(category)
                                                .font(.custom("Nunito-Black", size: 15))
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                        }
                                    }
                                    .tint(categoryChipIconColors[category]?.opacity(0.6))
                                    .buttonStyle(.glassProminent)
                                    .matchedTransitionSource(
                                        id: "categoryButton", in: transition
                                    )
                                    .mask(RoundedRectangle(cornerRadius: 15))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // ✅ NEW: skeleton vs feed
                        if isLoadingLists || (feedLists.isEmpty && isFetchingBatch) {
                            LazyVStack(spacing: 16) {
                                ForEach(0..<4, id: \.self) { _ in HomeListSkeletonViewRow() }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 60)
                            .padding(.leading)
                        } else {
                            // ✅ FEED
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(feedLists.indices, id: \.self) { idx in
                                    let list = feedLists[idx]
                                    if list.type == "group" {
                                        GroupListHomeView(
                                            listData: list,
                                            onCommentTap: { msg in
                                                showComingSoonToast(msg)
                                            },
                                            onRankoTap: { _ in
                                                
                                            },
                                            onProfileTap: { _ in
                                                
                                            }
                                        )
                                    } else {
                                        DefaultListHomeView(
                                            listData: list,
                                            onCommentTap: { msg in
                                                showComingSoonToast(msg)
                                            },
                                            onRankoTap: { _ in
                                                selectedList = list
                                            },
                                            onProfileTap: { _ in
                                                
                                            }
                                        )
                                    }
                                }
                                
                                // ✅ Load more
                                Button {
                                    loadNextBatch()
                                } label: {
                                    HStack(spacing: 8) {
                                        if isFetchingBatch { ProgressView() }
                                        Text(isFetchingBatch ? "Loading…" : "Load More")
                                            .font(.custom("Nunito-Black", size: 16))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(isFetchingBatch)
                                .buttonStyle(.glassProminent)
                                .tint(Color(hex: 0xFF9864).gradient)
                                .padding(.trailing, 20)
                            }
                            .id(feedSessionID)
                            .padding(.top, 10)
                            .padding(.bottom, 80)
                            .padding(.leading)
                        }
                    }
                }
                if showToast {
                    ComingSoonToast(
                        isShown: $showToast,
                        title: "💬 Comments Coming Soon",
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
            .animation(.easeInOut(duration: 0.25), value: toastID)
            .navigationBarHidden(true)
        }
        .onChange(of: user_data.userID) {
            if user_data.userID == "0" {
                print("ERROR: User ID not set!")
            } else if user_data.userID == "" {
                print("ERROR: User ID is empty!")
            }
        }
        
        .fullScreenCover(item: $selectedList) { list in
            DefaultListSpectate(listID: list.id, onClone: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    clonedList = list
                }
            })
        }
        
        .fullScreenCover(item: $clonedList) { list in
            DefaultListView(rankoName: list.listName, description: list.listDescription, isPrivate: false, category: SampleCategoryChip(id: "", name: list.categoryName, icon: list.categoryIcon, colour: String(list.categoryColour)), selectedRankoItems: list.items, onSave: { _ in})
        }
        
        // MARK: – reset "listViewID" whenever HomeView comes back on screen
        .onAppear {
            clearAllCache()
            
            user_data.userID = Auth.auth().currentUser?.uid ?? "0"
            listViewID = UUID()
            
            if isSimulator {
                // show mocked feed if you want
                isLoadingLists = false
                print("ℹ️ Simulator detected — skipping Firebase calls.")
            } else {
                isLoadingLists = true
                syncUserDataFromFirebase()
                
                // ✅ ensure queue + initial batch of 6
                ensureQueueAndInitialBatch()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoadingLists = false
                }
                
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                    AnalyticsParameterScreenName: "Home",
                    AnalyticsParameterScreenClass: "HomeView"
                ])
            }
        }
        .refreshable {
            // 1) blank UI immediately
            feedSessionID = UUID()   // drop the subtree
            feedLists.removeAll()
            isFetchingBatch = false
            isLoadingLists = true
            
            ensureQueueAndInitialBatch()
            
            if !isSimulator {
                // pull another 6 on pull-to-refresh
                loadNextBatch()
            }
        }
        .sheet(isPresented: $trayViewOpen) {
            TrayView()
        }
        .fullScreenCover(isPresented: $showCategorySheet) {
            BlindSequence()
                .navigationTransition(
                    .zoom(sourceID: "categoryButton", in: transition)
                )
                .interactiveDismissDisabled()
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

    private func loadProfileImage(from path: String) {
        Storage.storage().reference().child("profilePictures").child(path)
            .getData(maxSize: Int64(2 * 1024 * 1024)) { data, _ in
                if let data = data, let ui = UIImage(data: data) {
                    profileImage = ui
                }
            }
    }
    
    private func syncUserDataFromFirebase() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user logged in. Aborting sync.")
            return
        }
        
        let userDetails = Database.database().reference().child("UserData").child(uid).child("UserDetails")
        let userProfilePicture = Database.database().reference().child("UserData").child(uid).child("UserProfilePicture")
        let userStats = Database.database().reference().child("UserData").child(uid).child("UserStats")
        
        print("UserID: \(uid)")
        print("🤔 Checking If Introduction Survey Should Open...")
        
        userDetails.observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed To Fetch User Data From Firebase.")
                checkIfTrayShouldOpen()
                return
            }
            
            user_data.userID = value["UserID"] as? String ?? ""
            user_data.username = value["UserName"] as? String ?? ""
            user_data.userDescription = value["UserDescription"] as? String ?? ""
            user_data.userPrivacy = value["UserPrivacy"] as? String ?? ""
            user_data.userInterests = value["UserInterests"] as? String ?? ""
            user_data.userJoined = value["UserJoined"] as? String ?? ""
            user_data.userYear = value["UserYear"] as? Int ?? 0
            user_data.userFoundUs = value["UserFoundUs"] as? String ?? ""
            user_data.userLoginService = value["UserSignInMethod"] as? String ?? ""
            
            print("✅ Successfully Loaded User Details.")
            
        })
        
        userProfilePicture.observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed To Fetch User Data From Firebase.")
                return
            }
            
            user_data.userProfilePictureFile = value["UserProfilePictureFile"] as? String ?? ""
            let modifiedTimestamp = value["UserProfilePictureModified"] as? String ?? ""
            user_data.userProfilePicturePath = value["UserProfilePicturePath"] as? String ?? ""
            
            print("✅ Successfully Loaded Profile Picture Details.")
            print("🤔 Checking For New Image...")
            
            // Only load profile image if the modified string has changed
            if modifiedTimestamp != user_data.userProfilePictureModified {
                print("🔁 Profile Picture Modified Date Changed, Reloading Image...")
                user_data.userProfilePictureModified = modifiedTimestamp
                imageService.refreshFromRemote(path: user_data.userProfilePicturePath)
            } else {
                print("✅ Using Cached Profile Image From Disk.")
                imageService.reloadFromDisk()
            }
        })
        
        userStats.observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed To Fetch User Data From Firebase.")
                return
            }
            
            user_data.userStatsFollowers = value["UserFollowerCount"] as? Int ?? 0
            user_data.userStatsFollowing = value["UserFollowingCount"] as? Int ?? 0
            user_data.userStatsRankos = value["UserRankoCount"] as? Int ?? 0
            
            print("✅ Successfully Loaded Statistics Details.")
            print("✅ Successfully Loaded All User Data.")
        })
    }
    
    private func checkIfTrayShouldOpen() {
        if user_data.username == "" || user_data.userInterests == "" {
            trayViewOpen = true
            print("📖 Opening Introduction Survey")
        } else {
            print("✅ Introduction Survey Already Completed")
        }
    }
    
    private func downloadAndCacheProfileImage(from path: String) {
        let storageRef = Storage.storage().reference().child("profilePictures").child(path)
        storageRef.getData(maxSize: Int64(2 * 1024 * 1024)) { data, error in
            guard let data = data, let uiImage = UIImage(data: data) else {
                print("❌ Failed to download profile image.")
                return
            }

            profileImage = uiImage
            user_data.ProfilePicture = uiImage
            saveImageToDisk(image: uiImage)
            
            let url = getProfileImagePath()
            do {
                try data.write(to: url)
                print("✅ Cached to disk at", url)
            } catch {
                print("❌ Could not cache:", error)
            }
        }
    }

    private func getProfileImagePath() -> URL {
        let filename = "cached_profile_image.jpg"
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }

    private func saveImageToDisk(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.95) {
            do {
                try data.write(to: getProfileImagePath(), options: .atomic)
                print("💾 Profile image saved to disk.")
            } catch {
                print("❌ Failed to save profile image: \(error)")
            }
        }
    }

    private func loadImageFromDisk() -> UIImage? {
        let path = getProfileImagePath()
        if FileManager.default.fileExists(atPath: path.path) {
            if let data = try? Data(contentsOf: path),
               let image = UIImage(data: data) {
                print("📂 Loaded profile image from disk.")
                return image
            }
        }
        return nil
    }
}

struct DefaultListHomeView: View {
    let listData: RankoList
    @StateObject private var user_data = UserInformation.shared
    
    // Profile & creator info
    @State private var profileImage: UIImage?
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
    
    private var sortedItems: [RankoItem] {
        listData.items.sorted { $0.rank < $1.rank }
    }
    private var firstBlock: [RankoItem] {
        Array(sortedItems.prefix(5))
    }
    private var remainder: [RankoItem] {
        Array(sortedItems.dropFirst(5))
    }
    private var secondBlock: [RankoItem] {
        Array(remainder.prefix(4))
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
        LazyVStack {
            Rectangle()
                .fill(Color(hex: 0x707070))
                .opacity(0.15)
                .frame(maxWidth: .infinity)
                .frame(height: 2)
                .padding(.bottom, 10)
                .padding(.horizontal, 10)
            HStack(alignment: .top) {
                Group {
                    AsyncImage(url: URL(string: "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/profilePictures%2F\(listData.userCreator).jpg?alt=media&token=\(user_data.userID)")) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            SkeletonView(RoundedRectangle(cornerRadius: 10))
                                .frame(width: 42, height: 42)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .onTapGesture {
                    onProfileTap(listData.userCreator)
                }
                
                LazyVStack(alignment: .leading) {
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
                    Text(listData.listName)
                        .font(.custom("Nunito-Black", size: 18))
                        .foregroundColor(Color(hex: 0x666666))
                        .padding(.bottom, -15)
                }
                .padding(.leading, 8)
                .onTapGesture {
                    onRankoTap(listData.id)
                }
                Spacer()
            }
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 42)
                    itemsSection
                }
                .onTapGesture {
                    onRankoTap(listData.id)
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
                    .onTapGesture {
                        onRankoTap(listData.id)
                    }
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
        if let idx = sortedItems.firstIndex(where: { $0.id == item.id }) {
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
        GeometryReader { geometry in
            let halfWidth = geometry.size.width * 0.4
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    // pass halfWidth as the minimum
                    leftColumn(minWidth: halfWidth)
                    rightColumn()
                }
                .padding(.vertical, 4)
                // force the entire HStack to stick to the left
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 300)
    }
    
    private func leftColumn(minWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(firstBlock) { item in
                itemRow(item)
            }
        }
        // use minWidth instead of fixed width, and align its content leading
        .frame(minWidth: minWidth, alignment: .leading)
    }
    
    private func rightColumn() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(secondBlock) { item in
                itemRow(item)
            }
            // 10th slot logic…
            if remainder.count >= 5 {
                if remainder.count == 5 {
                    // exactly 10 items → show the 10th
                    let item10 = remainder[4]
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
                            .font(.custom("Nunito-Black", size: 14))
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
                            Text("+\(listData.items.count - 9)")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(Color(hex: 0x666666))
                        )
                }
            }
        }
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
                .font(.custom("Nunito-Black", size: 14))
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
        let dbRef = Database.database().reference()
        let likePath = "RankoData/\(listData.id)/RankoLikes/\(safeUID)"
        let likeRef = dbRef.child(likePath)

        // 1) Optimistically update local state
        let currentlyLiked = hasLiked
        if currentlyLiked {
            likes.removeValue(forKey: safeUID)
        } else {
            likes[safeUID] = ts
        }

        // 2) Read once to confirm server state
        likeRef.observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists() {
                // 👎 Unlike on server
                likeRef.removeValue { error, _ in
                    if let error = error {
                        // 3a) Roll back if failure
                        likes[safeUID] = ts
                        print("Error removing like:", error)
                        showInlineToast("Couldn’t remove like.")
                    }
                    isLikeDisabled = false
                }
            } else {
                // 👍 Like on server
                likeRef.setValue(ts) { error, _ in
                    if let error = error {
                        // 3b) Roll back if failure
                        likes.removeValue(forKey: safeUID)
                        print("Error adding like:", error)
                        showInlineToast("Couldn’t add like.")
                    }
                    isLikeDisabled = false
                }
            }
        }) { error in
            // Handle read error
            print("Read error:", error)
            // Roll back optimistic change
            if currentlyLiked {
                likes[safeUID] = ts
            } else {
                likes.removeValue(forKey: safeUID)
            }
            isLikeDisabled = false
            showInlineToast("Network error.")
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
        let userDetails = Database.database().reference().child("UserData").child(listData.userCreator).child("UserDetails")

        userDetails.observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Could Not Load User Data for HomeView Rankos with UserID: \(listData.userCreator)")
                return
            }

            self.creatorName = value["UserName"] as? String ?? ""
        })
    }
    
    // MARK: — Fetch likes
    private func fetchLikes() {
        let ref = Database.database()
            .reference()
            .child("RankoData")
            .child(listData.id)
            .child("RankoLikes")
        
        ref.observe(.value, with: { snap in
            if let dict = snap.value as? [String: String] {
                likes = dict
            } else {
                likes = [:]
            }
        })
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoLikes", value: AlgoliaSearchClient.JSON(likes.count)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(_):
                print("✅ Algolia RankoLikes updated")
            case .failure(let error):
                print("❌ Algolia update failed:", error)
            }
        }
    }
    
    private func fetchComments() {
        let ref = Database.database().reference()
            .child("RankoData")
            .child(listData.id)
            .child("RankoComments")

        ref.observe(.value, with: { snap in
            if let dict = snap.value as? [String: Any] {
                commentsCount = dict.count
            } else {
                commentsCount = 0
            }
        })
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoComments", value: AlgoliaSearchClient.JSON(commentsCount)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(_):
                print("✅ Algolia RankoComments updated")
            case .failure(let error):
                print("❌ Algolia update failed:", error)
            }
        }
    }
    
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

struct GroupListHomeView: View {
    let listData: RankoList
    var onCommentTap: (String) -> Void
    var onRankoTap: (RankoList) -> Void
    var onProfileTap: (String) -> Void
    
    private var adjustedItems: [RankoItem] {
        listData.items.map { item in
            let adjustedRank = item.rank / 1000
            return RankoItem(id: item.id, rank: adjustedRank, votes: item.votes, record: item.record, playCount: item.playCount)
        }
    }
    
    var body: some View {
        DefaultListHomeView(listData: RankoList(
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
        ), onCommentTap: { msg in
            onCommentTap(msg)
        }, onRankoTap: { _ in
            onRankoTap(listData)
        }, onProfileTap: { _ in
            onProfileTap(listData.userCreator)
        })
    }
}











    
struct HomeListSkeletonViewRow: View {
    var body: some View {
        LazyVStack {
            SkeletonView(Rectangle())
                .frame(maxWidth: .infinity)
                .frame(height: 2)
                .padding(.bottom, 10)
                .padding(.horizontal, 10)
            HStack(alignment: .top) {
                // avatar
                SkeletonView(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 42, height: 42)
                
                // name / time / badge
                LazyVStack(alignment: .leading, spacing: 6) {
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
                        .padding(.trailing, CGFloat.random(in: 50...100))
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
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<5) { _ in
                                    HStack(spacing: 8) {
                                        SkeletonView(RoundedRectangle(cornerRadius: 8))
                                            .frame(width: 47, height: 47)
                                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                                            .frame(width: CGFloat.random(in: 60...110), height: 14)
                                    }
                                }
                            }
                            // Right column (next 4 + “+N more”)
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<5) { _ in
                                    HStack(spacing: 8) {
                                        SkeletonView(RoundedRectangle(cornerRadius: 8))
                                            .frame(width: 47, height: 47)
                                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                                            .frame(width: CGFloat.random(in: 60...110), height: 14)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 300)
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
    }
}

#Preview {
    HomeView()
        .environmentObject(ProfileImageService())
}

#Preview {
    HomeListSkeletonViewRow()
        .environmentObject(ProfileImageService())
}

