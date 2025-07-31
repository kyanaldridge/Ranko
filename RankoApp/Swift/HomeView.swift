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

// MARK: - HomeView
struct HomeView: View {
    // MARK: - Variables
    @StateObject private var user_data = UserInformation.shared
    @State private var trayViewOpen: Bool = false
    @State private var trayDetent: PresentationDetent = .medium
    @State private var showPicker: Bool = false
    @State private var profileImage: UIImage?
    @State private var listViewID = UUID()
    @State private var isLoadingLists = true
    
    private let isSimulator: Bool = {
        var isSim = false
        #if targetEnvironment(simulator)
        isSim = true
        #endif
        return isSim
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xDBC252), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864), Color(hex: 0xFF9864)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
                
                if isSimulator {
                    ScrollView {
                        VStack(spacing: 0) {
                            // MARK: - Header
                            HStack {
                                Text("Home")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                Spacer()
                                ProfileIconView(size: CGFloat(50))
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 30)
                            VStack(spacing: 16) {
                                ForEach(0..<2, id: \.self) { _ in
                                    HomeListSkeletonViewRow()
                                }
                            }
                            .padding(.top, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(
                                        LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                                                       startPoint: .top,
                                                       endPoint: .bottom
                                                      )
                                    )
                                )
                            
                        }
                    }
                    
                } else {
                    // Now a single ScrollView + our single-column MyListsView
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // MARK: - Header
                                HStack {
                                    Text("Home")
                                        .font(.system(size: 32, weight: .black))
                                        .foregroundColor(.white)
                                        .fontDesign(.rounded)
                                    Spacer()
                                    ProfileIconView(size: CGFloat(50))
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                                .padding(.horizontal, 30)
                                
                                if isLoadingLists {
                                    // Show 4 skeleton cards
                                    VStack(spacing: 16) {
                                        ForEach(0..<4, id: \.self) { _ in
                                            HomeListSkeletonViewRow()
                                        }
                                    }
                                    .padding(.top, 23)
                                    .padding(.horizontal)
                                    .padding(.bottom, 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .fill(
                                                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                                                               startPoint: .top,
                                                               endPoint: .bottom
                                                              )
                                            )
                                    )
                                } else {
                                    HomeListsDisplay()
                                        .padding(.top)
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
                }
            }
            .navigationBarHidden(true)
        }
        
        // MARK: – reset "listViewID" whenever HomeView comes back on screen
        .onAppear {
            listViewID = UUID()

            if isSimulator {
                isLoadingLists = false
                print("ℹ️ Simulator detected — skipping Firebase calls.")
            } else {
                isLoadingLists = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoadingLists = false
                }

                Task {
                    await updateGlobalSubscriptionStatus(groupID: "4205BB53", productIDs: ["pro_weekly", "pro_monthly", "pro_yearly"])
                }

                syncUserDataFromFirebase()

                Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                    AnalyticsParameterScreenName: "Home",
                    AnalyticsParameterScreenClass: "HomeView"
                ])
            }
        }
        .refreshable {
            listViewID = UUID()
            
            if !isSimulator {
                isLoadingLists = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isLoadingLists = false
                }
            }
        }
        .sheet(isPresented: $trayViewOpen) {
            TrayView(currentDetent: $trayDetent)
                .presentationDetents([.fraction(0.7), .large], selection: $trayDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
        }
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

        let dbRef = Database.database().reference().child("UserData").child(uid)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed to fetch user data from Firebase.")
                checkIfTrayShouldOpen()
                return
            }

            user_data.userID = uid
            user_data.username = value["UserName"] as? String ?? ""
            user_data.userDescription = value["UserDescription"] as? String ?? ""
            user_data.userYear = value["UserYear"] as? Int ?? 0
            user_data.userInterests = value["UserInterests"] as? String ?? ""
            user_data.userProfilePicture = value["UserProfilePicture"] as? String ?? ""
            let modifiedTimestamp = value["UserProfilePictureModified"] as? String ?? ""
            user_data.userFoundUs = value["UserFoundUs"] as? String ?? ""
            user_data.userJoined = value["UserJoined"] as? String ?? ""

            print("✅ Successfully loaded user data.")

            // Only load profile image if the modified string has changed
            if modifiedTimestamp != user_data.userProfilePictureModified {
                print("🔁 Profile picture modified date changed, reloading image.")
                user_data.userProfilePictureModified = modifiedTimestamp
                user_data.userProfilePicture = user_data.userProfilePicture
                downloadAndCacheProfileImage(from: user_data.userProfilePicture)
            } else {
                print("✅ Using cached profile image from disk.")
                profileImage = loadImageFromDisk()
            }

            checkIfTrayShouldOpen()
        }
    }
    
    private func checkIfTrayShouldOpen() {
        if user_data.username == "" || user_data.userInterests == "" {
            trayViewOpen = true
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
            saveImageToDisk(image: uiImage)
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
    
    private var sortedItems: [AlgoliaRankoItem] {
        listData.items.sorted { $0.rank < $1.rank }
    }
    private var firstBlock: [AlgoliaRankoItem] {
        Array(sortedItems.prefix(5))
    }
    private var remainder: [AlgoliaRankoItem] {
        Array(sortedItems.dropFirst(5))
    }
    private var secondBlock: [AlgoliaRankoItem] {
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
        VStack(alignment: .leading, spacing: 16) {
            creatorRow
            Text(listData.listName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(Color(hex: 0x7E5F46))
            Divider()
            itemsSection
            Divider()
            likeCommentShareSection
            descriptionSection
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFEF4E7), Color(hex: 0xFFFBF1)]),
                           startPoint: .top,
                           endPoint: .bottom
                          )
        )
        .cornerRadius(25)
        .shadow(color: Color(hex: 0xD0BD91).opacity(0.6), radius: 6, x: 0, y: -3)
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
            SpecProfileView(userID: (listData.userCreator))
        }
        .sheet(isPresented: $openShareView) {
            SpecProfileView(userID: (listData.userCreator))
        }
    }
    
    // Badge builder with white circle background and inset offset
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.body).padding(3)
            } else if rank == 2 {
                Image(systemName: "2.circle.fill").foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.body).padding(3)
            } else if rank == 3 {
                Image(systemName: "3.circle.fill").foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.body).padding(3)
            } else {
                Image(systemName: "\(rank).circle.fill").foregroundColor(Color(hex: 0xFF9864)).font(.body).padding(3)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }
    
    private var creatorRow: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                    } else {
                        SkeletonView(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 50, height: 50)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(creatorName)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .onTapGesture {
                                spectateProfile.toggle()
                            }
                        Text("•")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: 0xA3A3A3))
                            .padding(.top, 2)
                        Text(timeAgo(from: String(listData.dateTime)))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: 0xA3A3A3))
                            .padding(.top, 2)
                        Spacer()
                    }
                    HomeCategoryBadge(text: listData.category)
                }
                Spacer()
            }
        }
    }
    
    private var itemsSection: some View {
        GeometryReader { geometry in
            let halfWidth = geometry.size.width * 0.5
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
                            badgeView(for: item10.rank)
                        }
                        Text(item10.itemName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .lineLimit(1)
                            .padding(.leading, 6)
                    }
                } else {
                    // >10 items → show “+N” where N = total-9
                    Text("+\(listData.items.count - 9) more itemz")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x7E5F46))
                        .frame(maxWidth: .infinity, maxHeight: 50, alignment: .center)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6)).foregroundColor(.clear)
                }
            }
        }
    }
    
    private func itemRow(_ item: AlgoliaRankoItem) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
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
                badgeView(for: item.rank)
            }
            Text(item.itemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: 0x7E5F46))
                .lineLimit(1)
                .padding(.leading, 6)
        }
    }
    
    private var likeCommentShareSection: some View {
        HStack(spacing: 18) {
            HStack(spacing: 4) {
                LikeButton(isLiked: hasLiked, onTap: handleLikeTap)
                Text("\(likes.count)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Color(hex: 0x7E5F46))
            }
            
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: 0x7E5F46))
                Text("\(commentsCount)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Color(hex: 0x7E5F46))
            }
            Button {
                openShareView = true
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Color(hex: 0x7E5F46))
            }
            
            
            Spacer()
        }
    }
    
    private var descriptionSection: some View {
        Group {
            if !listData.listDescription.isEmpty {
                Text(listData.listDescription)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color(hex: 0x7E5F46))
            }
        }
    }
    
    
    // MARK: — Like handling (unchanged)
    private func handleLikeTap() {
        guard !isLikeDisabled else {
            showInlineToast("Calm down! Wait a few seconds.")
            return
        }
        isLikeDisabled = true

        let db = Database.database().reference()
        let likeRef = db.child("RankoData")
            .child(listData.id)
            .child("RankoLikes")
            .child(safeUID)

        likeRef.getData { error, snapshot in
            if snapshot?.exists() == true {
                // 👎 Unlike
                likeRef.removeValue { _, _ in
                    likes.removeValue(forKey: safeUID)
                }
            } else {
                // 👍 Like
                let ts = currentAEDTString()
                likeRef.setValue(ts) { _, _ in
                    likes[safeUID] = ts
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isLikeDisabled = false
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
        let dbRef = Database.database().reference()
            .child("UserData")
            .child(listData.userCreator)

        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Could not load user data for creator \(listData.userCreator)")
                return
            }

            self.creatorName = value["UserName"] as? String ?? ""
            let profilePath = value["UserProfilePicture"] as? String ?? ""

            print("✅ Creator info loaded from Firebase:")
            print("   Name: \(self.creatorName)")
            print("   Profile Picture Path: \(profilePath)")

            loadProfileImage(from: profilePath)
        }
    }
    
    // MARK: — Fetch likes
    private func fetchLikes() {
        let ref = Database.database()
            .reference()
            .child("RankoData")
            .child(listData.id)
            .child("RankoLikes")
        
        ref.observe(.value) { snap in
            if let dict = snap.value as? [String: String] {
                likes = dict
            } else {
                likes = [:]
            }
        }
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoLikes", value: JSON(likes.count)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(let response):
                print("✅ Algolia RankoLikes updated:", response)
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

        ref.observe(.value) { snap in
            if let dict = snap.value as? [String: Any] {
                commentsCount = dict.count
            } else {
                commentsCount = 0
            }
        }
        
        // ✅ Algolia update
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoComments", value: JSON(commentsCount)))
        ]
        
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(let response):
                print("✅ Algolia RankoComments updated:", response)
            case .failure(let error):
                print("❌ Algolia update failed:", error)
            }
        }
    }
    
    // MARK: — Helpers
    private func loadProfileImage(from path: String) {
        Storage.storage().reference().child("profilePictures").child(path)
            .getData(maxSize: Int64(2 * 1024 * 1024)) { data, _ in
                if let data = data, let ui = UIImage(data: data) {
                    profileImage = ui
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
        fmt.dateFormat = "yyyy-MM-dd-HH-mm-ss"
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
                    image(Image(systemName: "heart"),      show: !isLiked)
                }
            }
            
        }
        
        private func image(_ image: Image, show: Bool) -> some View {
            image
                .tint(isLiked ? .red : Color(hex: 0x7E5F46))
                .font(.system(size: 20, weight: .semibold))
                .scaleEffect(show ? 1 : 0)
                .opacity(show ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: show)
        }
    }
}

struct HomeListsDisplay: View {
    @State private var lists: [RankoList] = []
    @State private var allItems: [AlgoliaRankoItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedList: RankoList? = nil
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
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
                        GroupListHomeView(listData: list)
                    } else {
                        DefaultListHomeView(listData: list)
                            .onTapGesture {
                                selectedList = list
                            }
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 60)
        .sheet(item: $selectedList) { list in
            DefaultListVote(listID: list.id, creatorID: list.userCreator)
        }
        .padding(.horizontal)
        .onAppear {
            loadAllData()
        }
    }
    
    private func loadAllData(attempt: Int = 1) {
        isLoading = true
        errorMessage = nil

        let rankoDataRef = Database.database().reference().child("RankoData")
        
        rankoDataRef.observeSingleEvent(of: .value) { snapshot,anything  in
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

                let items: [AlgoliaRankoItem] = itemsDict.compactMap { itemID, item in
                    guard let itemName = item["ItemName"] as? String,
                          let itemDesc = item["ItemDescription"] as? String,
                          let itemImage = item["ItemImage"] as? String else {
                        return nil
                    }

                    let rank = item["ItemRank"] as? Int ?? 0
                    let votes = item["ItemVotes"] as? Int ?? 0

                    let record = AlgoliaItemRecord(
                        objectID: itemID,
                        ItemName: itemName,
                        ItemDescription: itemDesc,
                        ItemCategory: category,
                        ItemImage: itemImage
                    )

                    return AlgoliaRankoItem(id: itemID, rank: rank, votes: votes, record: record)
                }

                let rankoList = RankoList(
                    id: objectID,
                    listName: name,
                    listDescription: description,
                    type: type,
                    category: category,
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
        }
    }
}

struct GroupListHomeView: View {
    let listData: RankoList

    private var adjustedItems: [AlgoliaRankoItem] {
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
            category: listData.category,
            isPrivate: listData.isPrivate,
            userCreator: listData.userCreator,
            dateTime: listData.dateTime,
            items: adjustedItems
        ))
    }
}










    
struct HomeListSkeletonViewRow: View {
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            // MARK: Profile row skeleton
            HStack(alignment: .center, spacing: 12) {
                // avatar
                SkeletonView(Circle())
                    .frame(width: 45, height: 45)
                
                // name / time / badge
                VStack(alignment: .leading, spacing: 4) {
                    
                    HStack(spacing: 6) {
                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                            .frame(width: 120, height: 14)
                        SkeletonView(Circle())
                            .frame(width: 4, height: 4)
                        SkeletonView(RoundedRectangle(cornerRadius: 4))
                            .frame(width: 40, height: 14)
                    }
                    SkeletonView(RoundedRectangle(cornerRadius: 6))
                        .frame(width: 60, height: 20)
                }
                
                Spacer()
            }
            
            // MARK: Title skeleton
            SkeletonView(RoundedRectangle(cornerRadius: 4))
                .frame(height: 24)
                .padding(.trailing, 150)
            
            Divider()
            
            // MARK: Items grid skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    // Left column (first 5)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<5) { _ in
                            HStack(spacing: 8) {
                                SkeletonView(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 50, height: 50)
                                SkeletonView(RoundedRectangle(cornerRadius: 4))
                                    .frame(width: 100, height: 14)
                            }
                        }
                    }
                    // Right column (next 4 + “+N more”)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<5) { _ in
                            HStack(spacing: 8) {
                                SkeletonView(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 50, height: 50)
                                SkeletonView(RoundedRectangle(cornerRadius: 4))
                                    .frame(width: 100, height: 14)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 300)
            
            Divider()
            
            // MARK: Likes & comments skeleton
            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    SkeletonView(Circle())
                        .frame(width: 24, height: 24)
                    SkeletonView(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 20, height: 14)
                }
                HStack(spacing: 4) {
                    SkeletonView(Circle())
                        .frame(width: 24, height: 24)
                    SkeletonView(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 20, height: 14)
                }
                Spacer()
            }
            
            // MARK: Description skeleton
            SkeletonView(RoundedRectangle(cornerRadius: 4))
                .frame(height: 14)
                .padding(.trailing, 100)
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFEF4E7), Color(hex: 0xFFFBF1)]),
                           startPoint: .top,
                           endPoint: .bottom
                          )
        )
        .cornerRadius(25)
        .shadow(color: Color(hex: 0xD0BD91).opacity(0.6), radius: 6, x: 0, y: -3)
    }
}


#Preview {
    VStack {
        Spacer()
        DefaultListHomeView(
            listData: RankoList(
                id: "rrsrywey55eyhhf",
                listName: "Top 10 Albums of the 1970s to 2010s",
                listDescription: "my fav albums",
                type: "default",
                category: "Albums",
                isPrivate: "false",
                userCreator: "ey54y54y3y",
                dateTime: "20230718094500",
                items: [
                AlgoliaRankoItem(id: "", rank: 10, votes: 23, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "Madvillainy",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/5/5e/Madvillainy_cover.png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 9, votes: 19, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "Wish You Were Here",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://www.emp.co.uk/dw/image/v2/BBQV_PRD/on/demandware.static/-/Sites-master-emp/default/dw74154f22/images/4/0/6/0/406025.jpg?sw=1000&sh=800&sm=fit&sfrm=png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 8, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "In Rainbows",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://m.media-amazon.com/images/I/A1MwaIeBpwL._UF894,1000_QL80_.jpg"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 7, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "OK Computer",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/thumb/b/ba/Radioheadokcomputer.png/250px-Radioheadokcomputer.png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 6, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "To Pimp a Butterfly",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/f/f6/Kendrick_Lamar_-_To_Pimp_a_Butterfly.png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 5, votes: 23, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "Madvillainy",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/5/5e/Madvillainy_cover.png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 4, votes: 19, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "Wish You Were Here",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://www.emp.co.uk/dw/image/v2/BBQV_PRD/on/demandware.static/-/Sites-master-emp/default/dw74154f22/images/4/0/6/0/406025.jpg?sw=1000&sh=800&sm=fit&sfrm=png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 3, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "In Rainbows",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://m.media-amazon.com/images/I/A1MwaIeBpwL._UF894,1000_QL80_.jpg"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 2, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "OK Computer",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/thumb/b/ba/Radioheadokcomputer.png/250px-Radioheadokcomputer.png"
                                    )
                                ),
                AlgoliaRankoItem(id: "", rank: 1, votes: 26, record:
                                    AlgoliaItemRecord(
                                        objectID: "",
                                        ItemName: "To Pimp a Butterfly",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/f/f6/Kendrick_Lamar_-_To_Pimp_a_Butterfly.png"
                                    )
                                )
                ]
            )
        )
        Spacer()
    }
    .background(
        RoundedRectangle(cornerRadius: 25)
            .fill(
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                               startPoint: .top,
                               endPoint: .bottom
                              )
            )
    )
    .ignoresSafeArea()
}

#Preview {
    HomeView()
}

#Preview {
    HomeListSkeletonViewRow()
}

