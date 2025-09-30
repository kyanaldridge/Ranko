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
    
    // ✅ NEW: app storage for timestamp + ID queue
    @AppStorage("homeLastRefreshTimestamp") private var homeLastRefreshTimestamp: String = ""   // "yyyyMMddHHmmss"
    @AppStorage("storedRankoIDsJSON") private var storedRankoIDsJSON: String = "[]"            // JSON array of strings

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
                                       from: Data(storedRankoIDsJSON.utf8))) ?? []
        }
        nonmutating set { // ← key change
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                storedRankoIDsJSON = json
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
                    self.homeLastRefreshTimestamp = self.nowString()
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

        ref.observeSingleEvent(of: .value, with: { snap in
            guard let dict = snap.value as? [String: Any] else {
                completion(nil); return
            }

            // Core fields
            guard
                let name = dict["RankoName"] as? String,
                let description = dict["RankoDescription"] as? String,
                let type = dict["RankoType"] as? String,
                let isPrivate = dict["RankoPrivacy"] as? Bool,
                let userID = dict["RankoUserID"] as? String,
                let dateTimeStr = dict["RankoDateTime"] as? String
            else {
                completion(nil); return
            }

            // Category (nested)
            let cat = dict["RankoCategory"] as? [String: Any] ?? [:]
            let catName  = (cat["name"] as? String) ?? ""
            let catIcon  = (cat["icon"] as? String) ?? ""
            let catColour = UInt(cat["colour"] as! String) ?? UInt(0xFFFFFF)  // store as Int; convert to your Color later

            // Items
            let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
            let items: [RankoItem] = itemsDict.compactMap { itemID, item in
                guard
                    let itemName = item["ItemName"] as? String,
                    let itemDesc = item["ItemDescription"] as? String,
                    let itemImage = item["ItemImage"] as? String
                else { return nil }

                let rank  = intFromAny(item["ItemRank"])  ?? 0
                let votes = intFromAny(item["ItemVotes"]) ?? 0

                let record = RankoRecord(
                    objectID: itemID,
                    ItemName: itemName,
                    ItemDescription: itemDesc,
                    ItemCategory: "category",  // replace if you store real per-item category
                    ItemImage: itemImage
                )
                return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
            }

            let list = RankoList(
                id: objectID,
                listName: name,
                listDescription: description,
                type: type,
                categoryName: catName,
                categoryIcon: catIcon,
                categoryColour: catColour,
                isPrivate: isPrivate ? "Private" : "Public",
                userCreator: userID,
                dateTime: dateTimeStr,
                items: items
            )

            // If UI code expects main thread:
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
                self.feedLists.append(contentsOf: newLists.sorted { $0.dateTime > $1.dateTime })
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
            guard let last = parseTS(homeLastRefreshTimestamp) else { return true }
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
                                ForEach(feedLists, id: \.id) { list in
                                    if list.type == "group" {
                                        GroupListHomeView(listData: list) { msg in showComingSoonToast(msg) }
                                            .onTapGesture { /* open spectate if you want */ }
                                    } else {
                                        DefaultListHomeView(listData: list) { msg in showComingSoonToast(msg) }
                                            .onTapGesture { /* open vote if you want */ }
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
        
        // MARK: – reset "listViewID" whenever HomeView comes back on screen
        .onAppear {
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
                
                Task {
                    await updateGlobalSubscriptionStatus(groupID: "4205BB53", productIDs: ["pro_weekly","pro_monthly","pro_yearly"])
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
                
                LazyVStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(creatorName)
                            .font(.custom("Nunito-Black", size: 13))
                            .foregroundColor(Color(hex: 0x000000))
                        Text("•")
                            .font(.custom("Nunito-Black", size: 11))
                            .foregroundColor(Color(hex: 0x818181))
                        Text(timeAgo(from: String(listData.dateTime)))
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
                    HomeCategoryBadge1(text: listData.categoryName)
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


struct DefaultListHomeView_Previews: PreviewProvider {

    // Mock items 1…10
    static let mockItems: [RankoItem] = [
        .init(id: "1hewhlehwlhcx", rank: 1, votes: 103, record: RankoRecord(objectID: "1hewhlehwlhcx", ItemName: "Love Sick", ItemDescription: "Don Toliver", ItemCategory: "", ItemImage: "https://store.warnermusic.com.au/cdn/shop/files/20221202_DON-T_LP.jpg?v=1683766183&width=800")),
        .init(id: "h1ewhlehwlhcx", rank: 2, votes: 97, record: RankoRecord(objectID: "h1ewhlehwlhcx", ItemName: "Man On The Moon III: The Chosen", ItemDescription: "Kid Cudi", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/e/e2/Man_on_the_Moon_III.png")),
        .init(id: "he1whlehwlhcx", rank: 3, votes: 72, record: RankoRecord(objectID: "he1whlehwlhcx", ItemName: "HEROES & VILLAINS", ItemDescription: "Metro Boomin", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/5/5f/Metro_Boomin_-_Heroes_%26_Villains.png")),
        .init(id: "hew1hlehwlhcx", rank: 4, votes: 56, record: RankoRecord(objectID: "hew1hlehwlhcx", ItemName: "Death Race For Love", ItemDescription: "Juice WRLD", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/0/04/Juice_Wrld_-_Death_Race_for_Love.png")),
        .init(id: "hewh1lehwlhcx", rank: 5, votes: 53, record: RankoRecord(objectID: "hewh1lehwlhcx", ItemName: "TIMELESS", ItemDescription: "KAYTRANADA", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/1/17/Album_cover_for_Timeless_by_Kaytranada.webp")),
        .init(id: "hewhl1ehwlhcx", rank: 6, votes: 49, record: RankoRecord(objectID: "hewhl1ehwlhcx", ItemName: "Hurry Up Tomorrow", ItemDescription: "The Weeknd", ItemCategory: "", ItemImage: "https://preview.redd.it/hut-full-album-theory-v0-wxtp9tt4ayie1.jpeg?auto=webp&s=476e8ed57a870940a855525e09bb1f87a5779a81")),
        .init(id: "hewhle1hwlhcx", rank: 7, votes: 32, record: RankoRecord(objectID: "hewhle1hwlhcx", ItemName: "The Life Of Pablo", ItemDescription: "Kanye West", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/4/4d/The_life_of_pablo_alternate.jpg")),
        .init(id: "hewhleh1wlhcx", rank: 8, votes: 29, record: RankoRecord(objectID: "hewhleh1wlhcx", ItemName: "beerbongs & bentleys", ItemDescription: "Post Malone", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/634175-Product-0-I_1024x1024.jpg")),
        .init(id: "hewhlehw1lhcx", rank: 9, votes: 28, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "Manic", ItemDescription: "Halsey", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/c/ce/Halsey_-_Manic.png")),
        .init(id: "hewhlehwl1hcx", rank: 10, votes: 21, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "channel ORANGE", ItemDescription: "Frank Ocean", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/295143-Product-0-I_16643d3b-c81d-42c5-a016-4e65927e00f2_grande.jpg")),
        .init(id: "hewhlehwl1hcx", rank: 11, votes: 21, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "channel ORANGE", ItemDescription: "Frank Ocean", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/295143-Product-0-I_16643d3b-c81d-42c5-a016-4e65927e00f2_grande.jpg"))
    ]
    // Mock list that matches your model usage inside the view
    static let mockList = RankoList(
        id: "list_123",
        listName: "Top 10 Albums This Decade",
        listDescription: "My current fave bangers — argue with your mum 😌",
        type: "default",
        categoryName: "Songs",
        categoryIcon: "music.note",
        categoryColour: 0xFFFFFF,
        isPrivate: "Public",
        userCreator: "2FOqyZfO5TNOdoJ0B3KrX99za1SLJ3",
        dateTime: "20250815123045", // yyyyMMddHHmmss
        items: mockItems
    )

    static var previews: some View {
        // Wrap in a layout you like (card-ish)
        ScrollView {
            LazyVStack(spacing: 0) {
                DefaultListHomeView(
                    listData: mockList,
                    onCommentTap: { msg in
                        print("Comment tapped with message: \(msg)")
                    }
                )
            }
        }
        .background(Color.white)
        .environmentObject(UserInformation.shared) // if your view expects it
        .previewDisplayName("DefaultListHomeView – Mock")
    }
}

struct HomeListsDisplay: View {
    @Namespace private var transition
    @State private var lists: [RankoList] = []
    @State private var allItems: [RankoItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedList: RankoList? = nil
    @State var presentFakeRankos: Bool
    @Binding var showToast: Bool
    @Binding var toastMessage: String
    
    var showToastHelper: (String) -> Void
    
    static let mockItems1: [RankoItem] = [
        .init(id: "1hewhlehwlhcx", rank: 1, votes: 103, record: RankoRecord(objectID: "1hewhlehwlhcx", ItemName: "Love Sick", ItemDescription: "Don Toliver", ItemCategory: "", ItemImage: "https://store.warnermusic.com.au/cdn/shop/files/20221202_DON-T_LP.jpg?v=1683766183&width=800")),
        .init(id: "h1ewhlehwlhcx", rank: 2, votes: 97, record: RankoRecord(objectID: "h1ewhlehwlhcx", ItemName: "Man On The Moon III: The Chosen", ItemDescription: "Kid Cudi", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/e/e2/Man_on_the_Moon_III.png")),
        .init(id: "he1whlehwlhcx", rank: 3, votes: 72, record: RankoRecord(objectID: "he1whlehwlhcx", ItemName: "HEROES & VILLAINS", ItemDescription: "Metro Boomin", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/5/5f/Metro_Boomin_-_Heroes_%26_Villains.png")),
        .init(id: "hew1hlehwlhcx", rank: 4, votes: 56, record: RankoRecord(objectID: "hew1hlehwlhcx", ItemName: "Death Race For Love", ItemDescription: "Juice WRLD", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/0/04/Juice_Wrld_-_Death_Race_for_Love.png")),
        .init(id: "hewh1lehwlhcx", rank: 5, votes: 53, record: RankoRecord(objectID: "hewh1lehwlhcx", ItemName: "TIMELESS", ItemDescription: "KAYTRANADA", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/1/17/Album_cover_for_Timeless_by_Kaytranada.webp")),
        .init(id: "hewhl1ehwlhcx", rank: 6, votes: 49, record: RankoRecord(objectID: "hewhl1ehwlhcx", ItemName: "Hurry Up Tomorrow", ItemDescription: "The Weeknd", ItemCategory: "", ItemImage: "https://preview.redd.it/hut-full-album-theory-v0-wxtp9tt4ayie1.jpeg?auto=webp&s=476e8ed57a870940a855525e09bb1f87a5779a81")),
        .init(id: "hewhle1hwlhcx", rank: 7, votes: 32, record: RankoRecord(objectID: "hewhle1hwlhcx", ItemName: "The Life Of Pablo", ItemDescription: "Kanye West", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/4/4d/The_life_of_pablo_alternate.jpg")),
        .init(id: "hewhleh1wlhcx", rank: 8, votes: 29, record: RankoRecord(objectID: "hewhleh1wlhcx", ItemName: "beerbongs & bentleys", ItemDescription: "Post Malone", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/634175-Product-0-I_1024x1024.jpg")),
        .init(id: "hewhlehw1lhcx", rank: 9, votes: 28, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "Manic", ItemDescription: "Halsey", ItemCategory: "", ItemImage: "https://upload.wikimedia.org/wikipedia/en/c/ce/Halsey_-_Manic.png")),
        .init(id: "hewhlehwl1hcx", rank: 10, votes: 21, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "channel ORANGE", ItemDescription: "Frank Ocean", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/295143-Product-0-I_16643d3b-c81d-42c5-a016-4e65927e00f2_grande.jpg")),
        .init(id: "hewhlehwl1hcx", rank: 11, votes: 21, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "channel ORANGE", ItemDescription: "Frank Ocean", ItemCategory: "", ItemImage: "https://www.jbhifi.com.au/cdn/shop/products/295143-Product-0-I_16643d3b-c81d-42c5-a016-4e65927e00f2_grande.jpg"))
    ]
    // Mock list that matches your model usage inside the view
    static let mockList1 = RankoList(
        id: "list_123",
        listName: "Top 10 Albums This Decade",
        listDescription: "My current fave bangers — argue with your mum 😌",
        type: "default",
        categoryName: "Songs",
        categoryIcon: "music.note",
        categoryColour: 0xFFFFFF,
        isPrivate: "Public",
        userCreator: "user_abc123",
        dateTime: "20250815123045", // yyyyMMddHHmmss
        items: mockItems1
    )
    
    static let mockItems2: [RankoItem] = [
        .init(id: "1hewhlehwlhcx", rank: 1, votes: 103, record: RankoRecord(objectID: "1hewhlehwlhcx", ItemName: "Cookies & Cream", ItemDescription: "", ItemCategory: "", ItemImage: "https://image.shutterstock.com/image-photo/isolated-scoop-cream-ice-white-250nw-2498180691.jpg")),
        .init(id: "h1ewhlehwlhcx", rank: 2, votes: 97, record: RankoRecord(objectID: "h1ewhlehwlhcx", ItemName: "Chocolate", ItemDescription: "", ItemCategory: "", ItemImage: "https://t3.ftcdn.net/jpg/15/54/40/82/360_F_1554408215_prUzouZME3FBK1G4tzGDMkAyiqbc3PZk.jpg")),
        .init(id: "he1whlehwlhcx", rank: 3, votes: 72, record: RankoRecord(objectID: "he1whlehwlhcx", ItemName: "Strawberry", ItemDescription: "", ItemCategory: "", ItemImage: "https://media.istockphoto.com/id/138087063/photo/strawberry-ice-cream.jpg?s=612x612&w=0&k=20&c=KRwUn679tUQnW7n76ZvDWfI9glRfITaeuqqj5xTasT0=")),
        .init(id: "hew1hlehwlhcx", rank: 4, votes: 56, record: RankoRecord(objectID: "hew1hlehwlhcx", ItemName: "Mint Choc Chip", ItemDescription: "", ItemCategory: "", ItemImage: "https://thumbs.dreamstime.com/b/flavorful-mint-chocolate-chip-classic-dessert-rich-flavor-perfect-refreshing-your-taste-buds-isolated-white-367177761.jpg")),
        .init(id: "hewh1lehwlhcx", rank: 5, votes: 53, record: RankoRecord(objectID: "hewh1lehwlhcx", ItemName: "Chocolate Chip", ItemDescription: "", ItemCategory: "", ItemImage: "https://www.shutterstock.com/image-photo/scoop-vanilla-ice-cream-chocolate-600nw-2569287049.jpg")),
        .init(id: "hewhl1ehwlhcx", rank: 6, votes: 49, record: RankoRecord(objectID: "hewhl1ehwlhcx", ItemName: "Rocky Road", ItemDescription: "", ItemCategory: "", ItemImage: "https://images.getbento.com/accounts/7be06ab46c91545d057b03e4bc16a220/media/images/66456Rocky-Road_4286.png?w=1800&fit=max&auto=compress,format&cs=origin&h=1800")),
        .init(id: "hewhle1hwlhcx", rank: 7, votes: 32, record: RankoRecord(objectID: "hewhle1hwlhcx", ItemName: "Vanilla", ItemDescription: "", ItemCategory: "", ItemImage: "https://static.vecteezy.com/system/resources/previews/054/709/028/non_2x/close-up-ice-cream-scoop-delicious-vanilla-flavor-ice-cream-isolated-on-white-background-photo.jpg")),
        .init(id: "hewhleh1wlhcx", rank: 8, votes: 29, record: RankoRecord(objectID: "hewhleh1wlhcx", ItemName: "Coffee", ItemDescription: "", ItemCategory: "", ItemImage: "https://www.shutterstock.com/image-photo/coffee-ice-cream-scoop-isolated-600nw-2636609039.jpg")),
        .init(id: "hewhlehw1lhcx", rank: 9, votes: 28, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "Peanut Butter Cup", ItemDescription: "", ItemCategory: "", ItemImage: "https://www.benjerry.ie/files/live/sites/systemsite/files/EU%20Specific%20Assets/Flavors/Product%20Assets/Peanut%20Butter%20Cup%20Ice%20Cream/web_EU_Tower_PeanutButterCup_RGB_HR2_60M.png")),
        .init(id: "hewhlehwl1hcx", rank: 10, votes: 21, record: RankoRecord(objectID: "hewhlehw1lhcx", ItemName: "Brownie Batter", ItemDescription: "", ItemCategory: "", ItemImage: "https://www.benjerry.com/files/live/sites/systemsite/files/US%20and%20Global%20Assets/Flavors/Product%20Assets/US/Chocolate%20Fudge%20Brownie%20Ice%20Cream/web_Tower_ChocolateFudgeBrownie_RGB_HR2_60M.png")),
    ]
    // Mock list that matches your model usage inside the view
    static let mockList2 = RankoList(
        id: "list_123",
        listName: "My Favourite Ice Cream Flavours",
        listDescription: "My current fave flavours — argue with your mum 😌",
        type: "default",
        categoryName: "Ice Cream",
        categoryIcon: "snowflake",
        categoryColour: 0xFFFFFF,
        isPrivate: "Public",
        userCreator: "user_abc123",
        dateTime: "20250822165913", // yyyyMMddHHmmss
        items: mockItems2
    )
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if presentFakeRankos {
                DefaultListHomeView(
                    listData: HomeListsDisplay.mockList1,
                    onCommentTap: { msg in
                        print("Comment tapped with message: \(msg)")
                    }
                )
                DefaultListHomeView(
                    listData: HomeListsDisplay.mockList2,
                    onCommentTap: { msg in
                        print("Comment tapped with message: \(msg)")
                    }
                )
            }
            if isLoading {
                ForEach(0..<4, id: \.self) { _ in
                    HomeListSkeletonViewRow()
                }
            } else if let errorMessage = errorMessage {
                Text("❌ Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ForEach(lists, id: \.id) { list in
                    if list.type == "group" {
                        GroupListHomeView(listData: list, showToastHelper: { msg in
                            showToastHelper(msg)
                        })
                        .onTapGesture {
                            selectedList = list
                        }
                    } else {
                        DefaultListHomeView(listData: list, onCommentTap: { msg in
                            showToastHelper(msg)
                        }
                        )
                        .onTapGesture {
                            selectedList = list
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 60)
        .fullScreenCover(item: $selectedList) { list in
            if list.type == "default" {
                DefaultListVote(listID: list.id, creatorID: list.userCreator)
            } else if list.type == "group" {
                GroupListSpectate(listID: list.id, creatorID: list.userCreator)
            }
        }
        .padding(.leading)
        .onAppear {
            loadAllData()
        }
    }
    
    private func loadAllData(attempt: Int = 1) {
        isLoading = true
        errorMessage = nil
        
        let rankoDataRef = Database.database().reference().child("RankoData")
        
        rankoDataRef.observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                self.errorMessage = "❌ No data found."
                self.isLoading = false
                return
            }
            
            var fetchedLists: [RankoList] = []
            
            for (objectID, listData) in value {
                guard let listDict = listData as? [String: Any],
                      let name = listDict["RankoName"] as? String,
                      let description = listDict["RankoDescription"] as? String,
                      let category = listDict["RankoCategory"] as? String,
                      let type = listDict["RankoType"] as? String,
                      let isPrivate = listDict["RankoPrivacy"] as? Bool,
                      let userID = listDict["RankoUserID"] as? String,
                      let dateTimeStr = listDict["RankoDateTime"] as? String,
                      let itemsDict = listDict["RankoItems"] as? [String: [String: Any]] else {
                    continue
                }
                
                let items: [RankoItem] = itemsDict.compactMap { itemID, item in
                    guard let itemName = item["ItemName"] as? String,
                          let itemDesc = item["ItemDescription"] as? String,
                          let itemImage = item["ItemImage"] as? String else {
                        return nil
                    }
                    
                    let rank = item["ItemRank"] as? Int ?? 0
                    let votes = item["ItemVotes"] as? Int ?? 0
                    
                    let record = RankoRecord(
                        objectID: itemID,
                        ItemName: itemName,
                        ItemDescription: itemDesc,
                        ItemCategory: category,
                        ItemImage: itemImage
                    )
                    
                    return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
                }
                
                let rankoList = RankoList(
                    id: objectID,
                    listName: name,
                    listDescription: description,
                    type: type,
                    categoryName: "Albums",
                    categoryIcon: "circle.circle",
                    categoryColour: 0xFFFFFF,
                    isPrivate: isPrivate ? "Private" : "Public",
                    userCreator: userID,
                    dateTime: dateTimeStr,
                    items: items
                )
                
                fetchedLists.append(rankoList)
            }
            
            DispatchQueue.main.async {
                self.lists = fetchedLists
                self.isLoading = false
            }
        })
    }
}

struct GroupListHomeView: View {
    let listData: RankoList
    var showToastHelper: (String) -> Void
    
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
        DefaultListHomeView(listData: RankoList(
            id: listData.id,
            listName: listData.listName,
            listDescription: listData.listDescription,
            type: listData.type,
            categoryName: "Albums",
            categoryIcon: "circle.circle",
            categoryColour: 0xFFFFFF,
            isPrivate: listData.isPrivate,
            userCreator: listData.userCreator,
            dateTime: listData.dateTime,
            items: adjustedItems
        ), onCommentTap: { msg in
            showToastHelper(msg)
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

