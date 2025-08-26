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

struct MyView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF76000), Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00), Color(hex: 0x800100)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button {} label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .black, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.horizontal, 1)
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0xC03700))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal, 30)
                Spacer()
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("B")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("L")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("I")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("N")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("D")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                }
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("S")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("Q")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("U")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("N")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("C")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                }
                Spacer()
                HStack(spacing: 3) {
                    Button {} label: {
                        Image(systemName: "trophy.fill")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    
                    Button {} label: {
                        Image(systemName: "gearshape.fill")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    
                    Button {} label: {
                        Spacer()
                        Text("Challenge")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity)
                        Spacer()
                        VStack(spacing: -5) {
                            Text("SCORE")
                                .font(.custom("Nunito-Black", size: 10))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("51")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding(.trailing, 10)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal)
                
                HStack(spacing: 3) {
                    Button {} label: {
                        HStack {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Themes")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 5)
                        }
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    
                    Button {} label: {
                        Spacer()
                        Text("Classic")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity)
                        Spacer()
                        VStack(spacing: -5) {
                            Text("LEVEL")
                                .font(.custom("Nunito-Black", size: 10))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("13")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding(.trailing, 10)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal)
                Spacer()
                Spacer()
                Spacer()
            }
        }
    }
}

struct MyView2: View {
    @State private var score: Int = 140
    @State private var time: Int = 337291
    @State private var boxes: CGFloat = 13

    // customize: count → array of "boxes per row" (i.e., columns in that row)
    var layoutForCount: [Int: [Int]] = [
        1: [1],
        2: [2],
        3: [3],
        4: [4],
        5: [2, 3],
        6: [3, 3],
        7: [3, 4],
        8: [4, 4],
        9: [4, 5],
        10: [5, 5],
        11: [3, 4, 4],
        12: [4, 4, 4],
        13: [4, 5, 4],
        14: [4, 5, 5],
        15: [5, 5, 5],
        16: [4, 4, 4, 4],
        17: [4, 4, 4, 5],
        18: [4, 4, 5, 5],
        19: [4, 5, 5, 5],
        20: [5, 5, 5, 5],
        21: [4, 4, 4, 4, 5],
        22: [4, 4, 4, 5, 5],
        23: [4, 4, 5, 5, 5],
        24: [4, 5, 5, 5, 5],
        25: [5, 5, 5, 5, 5]
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF76000),
                    Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00),
                    Color(hex: 0x800100)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundColor(Color(hex: 0xFFFFFF))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: 0x650E02))
                        )

                Spacer()
                
                VStack(spacing: 20) {
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Text("L")
                                .font(.custom("Nunito-Black", size: 90))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    
                    ZStack {
                        HStack {
                            Spacer()
                            Text("\(time)s")
                                .font(.custom("Nunito-Black", size: 15))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: 0x650E02))
                                    )
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: 0xAD0303))
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: 0xAD0303))
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: 0xAD0303))
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: 0x696969))
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: 0x696969))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: 0x650E02))
                                )
                            Spacer()
                        }
                    }
                    
                    // 🔽🔽🔽 replaced grid logic starts here
                    let count = max(0, Int(boxes))
                    let pattern = layoutForCount[count] ?? defaultPattern(for: count)
                    
                    VStack(spacing: 10) {
                        ForEach(0..<pattern.count, id: \.self) { row in
                            let rowCount = pattern[row]
                            let gridItems = Array(
                                repeating: GridItem(.flexible(), spacing: 10),
                                count: rowCount
                            )
                            
                            LazyVGrid(columns: gridItems, alignment: .center, spacing: 10) {
                                let start = pattern.prefix(row).reduce(0, +)
                                let end = min(start + rowCount, count)
                                ForEach(start..<end, id: \.self) { idx in
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: 0x8E0F00))
                                        .frame(minWidth: 65, minHeight: 65)
                                        .overlay(
                                            Text("D")
                                                .font(.custom("Nunito-Black", size: 38))
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                        )
                                        .accessibilityLabel("box \(idx + 1)")
                                }
                            }
                        }
                    }
                    // 🔼🔼🔼 replaced grid logic ends here
                }

                Spacer()
                Spacer()
                Spacer()

                HStack {
                    Spacer()
                    Button {} label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .black, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.glass)

                    Spacer()
                    Button {} label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 24, weight: .black, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)

                    Spacer()
                    Button {} label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18, weight: .regular, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                .padding(.vertical, -10)
                .padding(.horizontal, 10)
            }
            .padding()
        }
    }

    // fallback layout if not customized above
    // tweak this to your taste (e.g., prefer rows of 4, then remainder)
    private func defaultPattern(for n: Int) -> [Int] {
        guard n > 0 else { return [] }
        if n <= 4 { return [n] }
        if n == 5 { return [2, 3] }
        if n == 6 { return [3, 3] }

        // generic: fill rows of 5 until done (change 5 to whatever you like)
        let perRow = 5
        var res: [Int] = []
        var remaining = n
        while remaining > 0 {
            let take = min(perRow, remaining)
            res.append(take)
            remaining -= take
        }
        return res
    }
}

#Preview {
    MyView()
}

// MARK: - HomeView

struct HomeView: View {
    // MARK: - Variables
    @StateObject private var user_data = UserInformation.shared
    @State private var showPicker: Bool = false
    @State private var profileImage: UIImage?
    @State private var listViewID = UUID()
    @State private var isLoadingLists = true
    @State private var trayViewOpen = false
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastID = UUID()
    @State private var toastDismissWorkItem: DispatchWorkItem?
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView(.vertical) {
                    VStack {
                        HStack {
                            Text("Home")
                                .font(.custom("Nunito-Black", size: 36))
                                .foregroundStyle(Color(hex: 0x514343))
                            Spacer()
                            ProfileIconView(diameter: CGFloat(50))
                        }
                        .padding(.horizontal, 35)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Self.popularCategories, id: \.self) { category in
                                    Circle()
                                        .foregroundColor(categoryChipIconColors[category]?.opacity(0.6))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: FilterChip.icon(named: category, in: defaultFilterChips) ?? "circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: 30, maxHeight: 30)
                                                .fontWeight(.black)
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        if isLoadingLists {
                            // Show 4 skeleton cards
                            VStack(spacing: 16) {
                                ForEach(0..<4, id: \.self) { _ in
                                    HomeListSkeletonViewRow()
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 60)
                            .padding(.leading)
                        } else {
                            HomeListsDisplay(
                                presentFakeRankos: false,
                                showToast: $showToast,
                                toastMessage: $toastMessage,
                                showToastHelper: showComingSoonToast
                            )
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
                isLoadingLists = false
                print("ℹ️ Simulator detected — skipping Firebase calls.")
            } else {
                isLoadingLists = true
                
                syncUserDataFromFirebase()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoadingLists = false
                }

                Task {
                    await updateGlobalSubscriptionStatus(groupID: "4205BB53", productIDs: ["pro_weekly", "pro_monthly", "pro_yearly"])
                }

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
            TrayView()
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
        
        userDetails.observeSingleEvent(of: .value) { snapshot in
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
            
        }
        
        userProfilePicture.observeSingleEvent(of: .value) { snapshot in
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
                downloadAndCacheProfileImage(from: user_data.userProfilePicturePath)
            } else {
                print("✅ Using Cached Profile Image From Disk.")
                profileImage = loadImageFromDisk()
            }
        }
        
        userStats.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed To Fetch User Data From Firebase.")
                return
            }
            
            user_data.userStatsFollowers = value["UserFollowerCount"] as? Int ?? 0
            user_data.userStatsFollowing = value["UserFollowingCount"] as? Int ?? 0
            user_data.userStatsRankos = value["UserRankoCount"] as? Int ?? 0
            
            print("✅ Successfully Loaded Statistics Details.")
            print("✅ Successfully Loaded All User Data.")
        }
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
        VStack {
            Rectangle()
                .fill(Color(hex: 0x707070))
                .opacity(0.15)
                .frame(maxWidth: .infinity)
                .frame(height: 2)
                .padding(.bottom, 10)
                .padding(.horizontal, 10)
            HStack(alignment: .top) {
                Group {
                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                    } else {
                        SkeletonView(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 42, height: 42)
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
                    HomeCategoryBadge1(text: listData.category)
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
            ProfileSpectateView(userID: (listData.userCreator))
        }
        .sheet(isPresented: $openShareView) {
            ProfileSpectateView(userID: (listData.userCreator))
        }
    }
    
    
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill")
                    .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
                    .font(.system(size: 15, weight: .black, design: .default))
                    .padding(2)
            } else if rank == 2 {
                Image(systemName: "2.circle.fill")
                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
                    .font(.system(size: 15, weight: .black, design: .default))
                    .padding(2)
            } else if rank == 3 {
                Image(systemName: "3.circle.fill")
                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
                    .font(.system(size: 15, weight: .black, design: .default))
                    .padding(2)
            } else {
                Image(systemName: "\(rank).circle.fill")
                    .foregroundColor(Color(hex: 0x000000))
                    .font(.system(size: 15, weight: .black, design: .default))
                    .padding(2)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
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
                            badgeView(for: item10.rank)
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
                badgeView(for: item.rank)
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
        likeRef.observeSingleEvent(of: .value) { snapshot in
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
        } withCancel: { error in
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
        let userProfilePicture = Database.database().reference().child("UserData").child(listData.userCreator).child("UserProfilePicture")

        userDetails.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Could Not Load User Data for HomeView Rankos with UserID: \(listData.userCreator)")
                return
            }

            self.creatorName = value["UserName"] as? String ?? ""
        }
        
        userProfilePicture.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Could Not Load Profile Photo Data for HomeView Rankos with UserID: \(listData.userCreator)")
                return
            }

            let profilePath = value["UserProfilePicturePath"] as? String ?? ""

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
        category: "Songs",
        isPrivate: "Public",
        userCreator: "user_abc123",
        dateTime: "20250815123045", // yyyyMMddHHmmss
        items: mockItems
    )

    static var previews: some View {
        // Wrap in a layout you like (card-ish)
        ScrollView {
            VStack(spacing: 0) {
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
        category: "Songs",
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
        category: "Ice Cream",
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
            category: listData.category,
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
        VStack {
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
                            VStack(alignment: .leading, spacing: 12) {
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
                            VStack(alignment: .leading, spacing: 12) {
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

