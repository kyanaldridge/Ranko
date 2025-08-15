//
//  ProfileView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import Firebase
import FirebaseAnalytics
import FirebaseStorage
import AlgoliaSearchClient
import InstantSearchSwiftUI
import Foundation
import FirebaseAuth
import PhotosUI
import SwiftData

struct ProfileView: View {
    @StateObject private var user_data = UserInformation.shared
    @Namespace private var transition

    @State private var showEditProfileImage = false
    @State private var showEditProfileButton = false
    @State private var loadingProfileImage = false
    @State private var profileImage: UIImage?
    
    private var profileImageService = ProfileImageService()
    
    @State private var showSearchRankos = false
    @State private var showUserFollowers = false
    @State private var showUserFollowing = false
    @State private var listViewID = UUID()
    @State private var isLoadingLists = true
    @State private var animatedTags: Set<String> = []
    
    @State private var featuredLists: [Int: RankoList] = [:]
    @State private var featuredLoading: Bool = true
    @State private var featuredLoadFailed: Bool = false
    @State private var retryCount: Int = 0
    @State private var slotToSelect: Int?
    @State private var slotToUnpin: Int?
    @State private var showUnpinAlert = false
    @State private var selectedFeaturedList: RankoList?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showUserFinder = false
    @State private var appIconCustomiserView: Bool = false
    @State private var lists: [RankoList] = []
    
    @State private var topCategories: [String] = []
    
    static let interestIconMapping: [String: String] = [
        "Sport": "figure.gymnastics",
        "Animals": "pawprint.fill",
        "Music": "music.note",
        "Food": "fork.knife",
        "Nature": "leaf.fill",
        "Geography": "globe.europe.africa.fill",
        "History": "building.columns.fill",
        "Science": "atom",
        "Gaming": "gamecontroller.fill",
        "Celebrities": "star.fill",
        "Art": "paintbrush.pointed.fill",
        "Cars": "car.side.roof.cargo.carrier.fill",
        "Football": "soccerball",
        "Fruit": "apple.logo",
        "Soda": "takeoutbag.and.cup.and.straw.fill",
        "Mammals": "hare.fill",
        "Flowers": "microbe.fill",
        "Movies": "movieclapper",
        "Instruments": "guitars.fill",
        "Politics": "person.bust.fill",
        "Basketball": "basketball.fill",
        "Vegetables": "carrot.fill",
        "Alcohol": "flame.fill",
        "Birds": "bird.fill",
        "Trees": "tree.fill",
        "Shows": "tv",
        "Festivals": "hifispeaker.2.fill",
        "Planets": "circles.hexagonpath.fill",
        "Tennis": "tennisball.fill",
        "Pizza": "triangle.lefthalf.filled",
        "Coffee": "cup.and.heat.waves.fill",
        "Dogs": "dog.fill",
        "Social Media": "message.fill",
        "Albums": "record.circle",
        "Actors": "theatermasks.fill",
        "Travel": "airplane",
        "Motorsport": "steeringwheel",
        "Eggs": "oval.portrait.fill",
        "Cats": "cat.fill",
        "Books": "books.vertical.fill",
        "Musicians": "music.microphone",
        "Australian Football": "australian.football.fill",
        "Fast Food": "takeoutbag.and.cup.and.straw.fill",
        "Fish": "fish.fill",
        "Board Games": "dice.fill",
        "Numbers": "1.square.fill",
        "Relationships": "heart.fill",
        "American Football": "american.football.fill",
        "Pasta": "water.waves",
        "Reptiles": "lizard.fill",
        "Card Games": "suit.club.fill",
        "Letters": "a.square.fill",
        "Baseball": "baseball.fill",
        "Ice Cream": "snowflake",
        "Bugs": "ladybug.fill",
        "Memes": "camera.fill",
        "Shapes": "triangle.fill",
        "Emotions": "face.smiling",
        "Ice Hockey": "figure.ice.hockey",
        "Statues": "figure.stand",
        "Gym": "figure.indoor.cycle",
        "Running": "figure.run"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xDBC252),  Color(hex: 0xFF9864)]),
                               startPoint: .top,
                               endPoint: .center)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack {
                            Button {
                                showUserFinder = true
                                print("Finding Users...")
                            } label: {
                                Image(systemName: "person.crop.badge.magnifyingglass.fill")
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 2)
                            }
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .tint(Color(hex: 0xFEF4E7))
                            .buttonStyle(.glassProminent)
                            .matchedTransitionSource(
                                id: "userFinder", in: transition
                            )
                            Spacer()
                            Button {
                                showEditProfileButton = true
                                print("Editing Profile...")
                            } label: {
                                Image(systemName: "pencil")
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 2)
                            }
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .tint(Color(hex: 0xFEF4E7))
                            .buttonStyle(.glassProminent)
                            .matchedTransitionSource(
                                id: "editProfileButton", in: transition
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, -70)
                        // Profile Picture
                        ProfileIconView(diameter: CGFloat(100))
                        .contextMenu {
                            Button(role: .confirm) {
                                showEditProfileImage = true
                            } label: {
                                Label("Change Profile Picture", systemImage: "person.crop.square")
                            }
                        }
                        .matchedTransitionSource(
                            id: "editProfileImage", in: transition
                        )
                        
                        // Name
                        Text(user_data.username)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: 0xFFFADB))
                        
                        // user_data.userDescription
                        if !user_data.userDescription.isEmpty {
                            Text(user_data.userDescription)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: 0xFFFADB))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // user_data.userInterests as buttons
                        if !user_data.userInterests.isEmpty {
                            let tags = user_data.userInterests
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }

                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    let icon = ProfileView.interestIconMapping[tag] ?? "tag.fill"

                                    Button(action: { print("\(tag) clicked") }) {
                                        HStack(spacing: 4) {
                                            ZStack {
                                                Image(systemName: icon)
                                                    .font(.system(size: 12, weight: .heavy))
                                                    .foregroundColor(.clear)
                                                if animatedTags.contains(tag) {
                                                    Image(systemName: icon)
                                                        .font(.system(size: 12, weight: .heavy))
                                                        .transition(.symbolEffect(.drawOn.individually))
                                                        .padding(1)
                                                }
                                            }
                                            Text(tag)
                                                .font(.system(size: 10, weight: .heavy))
                                        }
                                        .cornerRadius(8)
                                    }
                                    .foregroundColor(Color(hex: 0x7E5F46))
                                    .tint(Color(hex: 0xFEF4E7))
                                    .buttonStyle(.glassProminent)
                                    .geometryGroup()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Followers / Following / Rankos
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(user_data.userStatsRankos)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Rankos")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            
                            VStack {
                                Text("\(user_data.userStatsFollowers)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Followers")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            .onTapGesture {
                                showUserFollowers = true
                            }
                            
                            VStack {
                                Text("\(user_data.userStatsFollowing)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Following")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            .onTapGesture {
                                showUserFollowing = true
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom)
                    }
                    .padding(.top, 0)
                    
                    HStack {
                        Button(action: {showSearchRankos = true}) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 17, weight: .heavy))
                                Text("Search Rankos")
                                    .font(.system(size: 14, weight: .heavy))
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                        }
                        .foregroundColor(Color(hex: 0x7E5F46))
                        .tint(Color(hex: 0xFEF4E7))
                        .buttonStyle(.glassProminent)
                        .matchedTransitionSource(
                            id: "searchRankos", in: transition
                        )
                        Button(action: {appIconCustomiserView = true}) {
                            HStack {
                                Image(systemName: "swirl.circle.righthalf.filled.inverse")
                                    .font(.system(size: 17, weight: .heavy))
                                Text("Customise App")
                                    .font(.system(size: 14, weight: .heavy))
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                        }
                        .foregroundColor(Color(hex: 0x7E5F46))
                        .tint(Color(hex: 0xFEF4E7))
                        .buttonStyle(.glassProminent)
                        .matchedTransitionSource(
                            id: "customiseApp", in: transition
                        )
                    }
                    .padding(.bottom, 20)
                    VStack {
                        HStack {
                            Text("Featured")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(Color(hex: 0x7E5F46))
                            Spacer()
                        }
                        .padding(.bottom, 5)

                        VStack(spacing: 13) {
                            let filledSlots = featuredLists.keys.sorted()
                            let emptySlots = (1...10).filter { !featuredLists.keys.contains($0) }

                            // ✅ If loading or failed, show placeholders
                            if featuredLoading {
                                HStack {
                                    ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 60, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.3)
                                        .frame(height: 60)
                                        .padding(60)
                                }
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                         startPoint: .top,
                                                         endPoint: .bottom
                                                        )
                                          )
                                )
                                .padding(.top, 40)
                                .padding(.bottom, 120)
                                
                            } else if featuredLoadFailed {
                                // ❌ If failed after 3 attempts, show retry buttons
                                ForEach(1...10, id: \.self) { slot in
                                    HStack {
                                        Button {
                                            retryFeaturedLoading()
                                        } label: {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 24, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                        .disabled(false)
                                    }
                                }
                            } else {
                                // ✅ Normal loaded state
                                ForEach(filledSlots, id: \.self) { slot in
                                    HStack {
                                        Button {
                                            if let list = featuredLists[slot] {
                                                selectedFeaturedList = list
                                            }
                                        } label: {
                                            if let list = featuredLists[slot] {
                                                if list.type == "default" {
                                                    DefaultListIndividualGallery(listData: list, type: "featured", onUnpin: {
                                                        slotToUnpin = slot
                                                        showUnpinAlert = true
                                                    })
                                                    .contextMenu {
                                                        Button(action: {
                                                            slotToUnpin = slot
                                                            showUnpinAlert = true
                                                        }) {
                                                            Label("Unpin", systemImage: "pin.slash")
                                                        }
                                                        .foregroundColor(Color(hex: 0xFF9864))
                                                    }
                                                } else {
                                                    GroupListIndividualGallery(listData: list, type: "featured", onUnpin: {
                                                        slotToUnpin = slot
                                                        showUnpinAlert = true
                                                    })
                                                }
                                            }
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                    }
                                }

                                ForEach(emptySlots, id: \.self) { slot in
                                    HStack {
                                        Button {
                                            slotToSelect = slot
                                        } label: {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "plus")
                                                    .font(.system(size: 24, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            ))
                                        .buttonStyle(.glassProminent)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity)
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
                .fullScreenCover(isPresented: $showEditProfileImage) {
                    EditProfileView(
                        originalImage:       user_data.ProfilePicture,
                        username:            user_data.username,
                        userDescription:     user_data.userDescription,
                        // → make initialTags a [String], not a single String
                        initialTags:         user_data.userInterests
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespaces) },
                        onSave: { name, bioText, tags, newImg in
                            user_data.username        = name
                            user_data.userDescription = bioText
                            user_data.userInterests   = tags.joined(separator: ", ")
                            saveUserDataToFirebase(
                                name:        name,
                                description: bioText,
                                interests:   tags
                            )

                            // animate tags…
                            Task {
                                for (index, tag) in tags.enumerated() {
                                    try? await Task.sleep(for: .milliseconds(200 * index))
                                    _ = withAnimation(.easeOut(duration: 0.4)) {
                                        animatedTags.insert(tag)
                                    }
                                }
                            }

                            // handle image
                            guard let img = newImg else {
                                showEditProfileImage = false
                                return
                            }
                            loadingProfileImage = true
                            profileImage        = nil
                            showEditProfileImage          = false
                            uploadImageToFirebase(img)
                        },
                        onCancel: {
                            showEditProfileImage = false
                        }
                    )
                    .navigationTransition(
                        .zoom(sourceID: "editProfileImage", in: transition)
                    )
                    .interactiveDismissDisabled(true)
                }
                .sheet(isPresented: $showUserFollowers) {
                    SearchFollowersView(userID: user_data.userID)
                }
                .sheet(isPresented: $showUserFollowing) {
                    SearchFollowingView(userID: user_data.userID)
                }
                .sheet(isPresented: $showSearchRankos) {
                    SearchRankosView()
                        .navigationTransition(
                            .zoom(sourceID: "searchRankos", in: transition)
                        )
                }
                .sheet(isPresented: $showUserFinder) {
                    SearchUsersView()
                        .navigationTransition(
                            .zoom(sourceID: "userFinder", in: transition)
                        )
                }
                .sheet(isPresented: $appIconCustomiserView) {
                    CustomiseAppIconView()
                        .navigationTransition(
                            .zoom(sourceID: "customiseApp", in: transition)
                        )
                }
                .fullScreenCover(isPresented: $showEditProfileButton) {
                    EditProfileView(
                        originalImage:       user_data.ProfilePicture,
                        username:            user_data.username,
                        userDescription:     user_data.userDescription,
                        // → make initialTags a [String], not a single String
                        initialTags:         user_data.userInterests
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespaces) },
                        onSave: { name, bioText, tags, newImg in
                            user_data.username        = name
                            user_data.userDescription = bioText
                            user_data.userInterests   = tags.joined(separator: ", ")
                            saveUserDataToFirebase(
                                name:        name,
                                description: bioText,
                                interests:   tags
                            )

                            // animate tags…
                            Task {
                                for (index, tag) in tags.enumerated() {
                                    try? await Task.sleep(for: .milliseconds(200 * index))
                                    _ = withAnimation(.easeOut(duration: 0.4)) {
                                        animatedTags.insert(tag)
                                    }
                                }
                            }

                            // handle image
                            guard let img = newImg else {
                                showEditProfileButton = false
                                return
                            }
                            loadingProfileImage = true
                            profileImage        = nil
                            showEditProfileButton     = false
                            uploadImageToFirebase(img)
                        },
                        onCancel: {
                            showEditProfileButton = false
                        }
                    )
                    .navigationTransition(
                        .zoom(sourceID: "editProfileButton", in: transition)
                    )
                    .interactiveDismissDisabled(true)
                }
                .sheet(item: $slotToSelect) { slot in
                    SelectFeaturedRankosView { selected in
                        // Dismiss sheet first
                        DispatchQueue.main.async {
                            slotToSelect = nil
                        }

                        // Delay slightly to ensure dismissal is finished
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Save to Firebase
                            let ref = Database.database()
                                .reference()
                                .child("UserData")
                                .child(user_data.userID)
                                .child("UserRankos")
                                .child("UserFeaturedRankos")
                                .child("\(slot)")
                            ref.setValue(selected.id)

                            // Update local UI state
                            featuredLists[slot] = selected
                        }
                    }
                }
                .fullScreenCover(item: $selectedFeaturedList) { list in
                    if list.type == "default" {
                        DefaultListPersonal(
                          listID: list.id,
                          onDelete: {
                              listViewID     = UUID()
                              isLoadingLists = true
                              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                  isLoadingLists = false
                                  retryFeaturedLoading()
                                  loadFollowStats()
                              }
                          }
                        )
                    } else if list.type == "group" {
                        GroupListPersonal(
                          listID: list.id,
                          onDelete: {
                              listViewID     = UUID()
                              isLoadingLists = true
                              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                  isLoadingLists = false
                                  retryFeaturedLoading()
                                  loadFollowStats()
                              }
                          }
                        )
                    }
                    
                }
                .refreshable {
                    listViewID     = UUID()
                    isLoadingLists = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isLoadingLists = false
                    }
                    loadFollowStats()
                    tryLoadFeaturedRankos()
                }
                .onAppear {
                    listViewID     = UUID()
                    isLoadingLists = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoadingLists = false
                    }
                    loadFollowStats()
                    tryLoadFeaturedRankos()
                    loadNumberOfRankos()
                    
                    let tags = user_data.userInterests
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    Task {
                        for (index, tag) in tags.enumerated() {
                            try? await Task.sleep(for: .milliseconds(200 * index))
                            _ = withAnimation(.easeOut(duration: 0.4)) {
                                animatedTags.insert(tag)
                            }
                        }
                    }
                    
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                        AnalyticsParameterScreenName: "Profile",
                        AnalyticsParameterScreenClass: "ProfileView"
                    ])                }
                .alert(
                    "Unpin Ranko?",
                    isPresented: $showUnpinAlert,
                    presenting: slotToUnpin
                ) { slot in
                    Button("Yes, unpin", role: .destructive) {
                        unpin(slot)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { slot in
                    Text("Are you sure you want to remove this featured Ranko from slot \(slot)?")
                }
            }
            
        }
    }
    
    
    private func loadNumberOfRankos() {
        guard !user_data.userID.isEmpty else { print("Skipping loadNumberOfRankos: userID is empty"); return }
        
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        var query = Query("").set(\.hitsPerPage, to: 0) // 0 results, just want count
        query.filters = "RankoUserID:\(user_data.userID) AND RankoStatus:active"

        index.search(query: query) { (result: Result<SearchResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let totalResults = response.nbHits
                    user_data.userStatsRankos = totalResults!
                    print("✅ Total Algolia Results: \(String(describing: totalResults))")
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child(user_data.userID).child("UserStats").child("UserRankoCount")
                    dbRef.setValue(totalResults!)
                case .failure(let error):
                    print("❌ Error fetching Algolia results: \(error)")
                }
            }
        }
    }
    
    private func uploadImageToFirebase(_ image: UIImage) {
        loadingProfileImage = true
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            loadingProfileImage = false
            return
        }

        let filePath = "\(user_data.userID).jpg"
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let storageRef = Storage.storage()
            .reference()
            .child("profilePictures")
            .child(filePath)

        storageRef.putData(data, metadata: metadata) { _, error in
            if let e = error {
                print("Upload error:", e)
                DispatchQueue.main.async { loadingProfileImage = false }
                return
            }
            
            let dbRef = Database.database().reference()
                .child("UserData")
                .child(user_data.userID)
                .child("UserProfilePicture")
                .child("UserProfilePicturePath")
            dbRef.setValue(filePath) { _, _ in
                // 3️⃣ Now download it back and cache
                downloadAndCacheProfileImage(from: filePath)
            }
            
            let now = Date()
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
            fmt.dateFormat = "yyyyMMddHHmmss"
            let ts = fmt.string(from: now)
            Database.database().reference()
                .child("UserData")
                .child(user_data.userID)
                .child("UserProfilePicture")
                .child("UserProfilePictureModified")
                .setValue(ts)
        }
    }

    private func downloadAndCacheProfileImage(from filePath: String) {
        let storageRef = Storage.storage()
            .reference()
            .child("profilePictures")
            .child(filePath)

        storageRef.getData(maxSize: 2 * 1024 * 1024) { data, error in
            DispatchQueue.main.async {
                defer { loadingProfileImage = false }
                guard let d = data, let ui = UIImage(data: d) else {
                    print("Download failed:", error ?? "unknown")
                    return
                }

                // 1️⃣ Update the in-memory state
                profileImage = ui
                user_data.ProfilePicture = ui

                // 2️⃣ Write to disk so next launch can load from cache
                let url = getProfileImagePath()
                do {
                    try d.write(to: url)
                    print("✅ Cached to disk at", url)
                } catch {
                    print("❌ Could not cache:", error)
                }
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
        
        userDetails.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Failed To Fetch User Data From Firebase.")
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
    
    private func loadFollowStats() {
        guard !user_data.userID.isEmpty else { print("Skipping loadFollowStats: userID is empty"); return }
        
        let db = Database.database().reference()
        let group = DispatchGroup()

        group.enter()
        db.child("UserData").child(user_data.userID).child("UserSocial").child("UserFollowers")
            .observeSingleEvent(of: .value) { snapshot in
                DispatchQueue.main.async {
                    self.user_data.userStatsFollowers = Int(snapshot.childrenCount)
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child(user_data.userID).child("UserStats").child("UserFollowerCount")
                    dbRef.setValue(user_data.userStatsFollowers)
                }
                group.leave()
            }

        group.enter()
        db.child("UserData").child(user_data.userID).child("UserSocial").child("UserFollowing")
            .observeSingleEvent(of: .value) { snapshot in
                DispatchQueue.main.async {
                    self.user_data.userStatsFollowing = Int(snapshot.childrenCount)
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child(user_data.userID).child("UserStats").child("UserFollowingCount")
                    dbRef.setValue(user_data.userStatsFollowing)
                }
                group.leave()
            }

        group.notify(queue: .main) {
            print("✅ Finished loading follow stats")
        }
    }
    
    private func retryFeaturedLoading() {
        featuredLoadFailed = false
        featuredLoading = true
        retryCount = 0
        tryLoadFeaturedRankos()
    }

    private func tryLoadFeaturedRankos() {
        guard retryCount < 3 else {
            DispatchQueue.main.async {
                self.featuredLoading = false
                self.featuredLoadFailed = true
            }
            return
        }
        retryCount += 1

        // Attempt Firebase fetch
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            print("❌ No UID found, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tryLoadFeaturedRankos() }
            return
        }

        let baseRef = Database.database()
            .reference()
            .child("UserData")
            .child(uid)
            .child("UserRankos")
            .child("UserFeaturedRankos")

        baseRef.getData { error, snapshot in
            if let error = error {
                print("❌ Firebase error: \(error.localizedDescription), retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tryLoadFeaturedRankos() }
                return
            }

            guard let snap = snapshot, snap.exists() else {
                print("⚠️ No featured rankos found")
                DispatchQueue.main.async {
                    self.featuredLists = [:]
                    self.featuredLoading = false
                }
                return
            }

            // ✅ Successfully connected
            var tempLists: [Int: RankoList] = [:]
            let group = DispatchGroup()

            for child in snap.children.allObjects as? [DataSnapshot] ?? [] {
                if let slot = Int(child.key), let listID = child.value as? String {
                    group.enter()
                    fetchFeaturedList(slot: slot, listID: listID) {
                        if let list = $0 { tempLists[slot] = list }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.featuredLists = tempLists
                self.featuredLoading = false
                print("✅ Featured Rankos loaded successfully")
            }
        }
    }

    // ✅ Modified fetchFeaturedList to support completion
    private func fetchFeaturedList(slot: Int, listID: String, completion: @escaping (RankoList?) -> Void) {
        let listRef = Database.database()
            .reference()
            .child("RankoData")
            .child(listID)

        listRef.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any],
                  let rl = parseListData(dict: dict, id: listID) else {
                completion(nil)
                return
            }
            completion(rl)
        }
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        guard
            let listName      = dict["RankoName"]        as? String,
            let description   = dict["RankoDescription"] as? String,
            let category      = dict["RankoCategory"]    as? String,
            let type          = dict["RankoType"]        as? String,
            let privacy       = dict["RankoPrivacy"]     as? Bool,
            let dateTime      = dict["RankoDateTime"]    as? String,
            let userCreator   = dict["RankoUserID"]      as? String,
            let itemsDict     = dict["RankoItems"]       as? [String: Any]
        else { return nil }

        let isPrivateString = privacy ? "Private" : "Public"
        var rankoItems: [RankoItem] = []

        for (_, value) in itemsDict {
            guard
                let itemDict  = value as? [String: Any],
                let itemID    = itemDict["ItemID"]          as? String,
                let itemName  = itemDict["ItemName"]        as? String,
                let itemDesc  = itemDict["ItemDescription"] as? String,
                let itemImg   = itemDict["ItemImage"]       as? String,
                let itemVotes = itemDict["ItemVotes"]       as? Int,
                let itemRank  = itemDict["ItemRank"]        as? Int
            else { continue }

            let record = RankoRecord(
                objectID:        itemID,
                ItemName:        itemName,
                ItemDescription: itemDesc,
                ItemCategory: "",
                ItemImage:       itemImg
            )
            rankoItems.append(RankoItem(id: itemID,
                                        rank: itemRank,
                                        votes: itemVotes,
                                        record: record))
        }

        rankoItems.sort { $0.rank < $1.rank }

        return RankoList(
            id:               id,
            listName:         listName,
            listDescription:  description,
            type:             type,
            category:         category,
            isPrivate:        isPrivateString,
            userCreator:      userCreator,
            dateTime:         dateTime,
            items:            rankoItems
        )
    }
    
    private func unpin(_ slot: Int) {
        guard !user_data.userID.isEmpty else { print("Skipping unpin: userID is empty"); return }
        
        let ref = Database.database()
            .reference()
            .child("UserData")
            .child(user_data.userID)
            .child("UserRankos")
            .child("UserFeaturedRankos")
            .child("\(slot)")
        ref.removeValue { error, _ in
            guard error == nil else { return }
            DispatchQueue.main.async {
                featuredLists.removeValue(forKey: slot)
            }
        }
    }
    
    private func saveUserDataToFirebase(name: String, description: String, interests: [String]) {
        guard !user_data.userID.isEmpty else {
            print("❌ Cannot save: userID is empty")
            return
        }

        let ref = Database.database().reference().child("UserData").child(user_data.userID).child("UserDetails")

        let updates: [String: Any] = [
            "UserName": name,
            "UserDescription": description,
            "UserInterests": interests.joined(separator: ", ")
        ]

        ref.updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ Error updating user data: \(error.localizedDescription)")
            } else {
                print("✅ User data updated successfully")
            }
        }
    }

    private func loadImageFromDisk() -> UIImage? {
        let path = URL(string: user_data.userProfilePicturePath)!
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

// MARK: - AlgoliaRankoView
class AlgoliaRankoView {
    static let shared = AlgoliaRankoView()
    @StateObject private var user_data = UserInformation.shared

    private let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                      apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
    private let index: Index

    private init() {
        self.index = client.index(withName: "RankoLists")
    }

    /// Fetches only the objectIDs of public Ranko lists from Algolia
    func fetchRankoLists(limit: Int = 20, completion: @escaping (Result<[String], Error>) -> Void) {
        let userID = user_data.userID
        var query = Query("")
        query.hitsPerPage = limit
        query.filters = "RankoUserID:\(userID) AND RankoStatus:active" // Only public lists
        
        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let ids = response.hits.compactMap { $0.objectID.rawValue }
                completion(.success(ids))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct FacetCategory: Identifiable {
    let id = UUID()
    let facetName: String
    let facetCount: Int
}

struct SearchRankosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    @State private var lists: [RankoList] = []
    @State private var selectedFacet: String? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedList: RankoList?
    @State private var activeFacet: FacetCategory?

    var facets: [FacetCategory] {
        guard let start = user_data.userRankoCategories.range(of: "["),
              let end = user_data.userRankoCategories.range(of: "]") else {
            return []
        }

        let inner = user_data.userRankoCategories[start.upperBound..<end.lowerBound]
        let entries = inner.components(separatedBy: ", ")

        return entries.compactMap { entry in
            if let openParen = entry.lastIndex(of: "("),
               let closeParen = entry.lastIndex(of: ")") {
                let name = entry[..<openParen].trimmingCharacters(in: .whitespaces)
                let countString = entry[entry.index(after: openParen)..<closeParen]
                if let count = Int(countString) {
                    return FacetCategory(facetName: name, facetCount: count)
                }
            }
            return nil
        }
        .sorted { $0.facetCount > $1.facetCount }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                            .padding(6)
                        TextField("Search Rankos", text: $searchText)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                        Spacer()
                        if !searchText.isEmpty {
                            Image(systemName: "xmark")
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
                    .padding(.leading, 10)
                    .padding(.top, 15)
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                    .buttonStyle(.glassProminent)
                }
                
                // Facet Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(facets) { facet in
                            let isSelected = selectedFacet == facet.facetName
                            let shouldShow = selectedFacet == nil || isSelected

                            if shouldShow {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if isSelected {
                                            selectedFacet = nil
                                        } else {
                                            selectedFacet = facet.facetName
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: FilterChip.icon(named: facet.facetName, in: defaultFilterChips) ?? "circle.fill")
                                        Text(facet.facetName).bold()
                                        Image(systemName: "\(facet.facetCount).circle.fill")

                                        if isSelected {
                                            Image(systemName: "xmark.circle")
                                        }
                                    }
                                    .font(.caption)
                                    .padding(6)
                                    .foregroundColor(isSelected ? .white : categoryChipIconColors[facet.facetName])
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? categoryChipIconColors[facet.facetName]! : categoryChipIconColors[facet.facetName]!.opacity(0.2))
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
                
                ScrollView(.vertical, showsIndicators: false) {
                    
                    // Loading + Error
                    if isLoading {
                        ProgressView("Loading Rankos...").padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).padding()
                    }
                    
                    // Filtered Ranko Lists
                    VStack(spacing: 8) {
                        let filtered = lists.filter { list in
                            (selectedFacet == nil || list.category == selectedFacet) &&
                            (searchText.isEmpty || list.listName.lowercased().contains(searchText.lowercased()))
                        }
                        
                        ForEach(filtered) { list in
                            HStack {
                                Button {
                                    print("Tapped: \(list.listName)")
                                    selectedList = list
                                } label: {
                                    if list.type == "default" {
                                        DefaultListIndividualGallery(listData: list, type: "", onUnpin: {})
                                    } else {
                                        GroupListIndividualGallery(listData: list, type: "", onUnpin: {})
                                    }
                                }
                                .foregroundColor(Color(hex: 0xFF9864))
                                .tint(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                    Spacer()
                }
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
        .fullScreenCover(item: $selectedList) { list in
            if list.type == "default" {
                DefaultListPersonal(listID: list.id, onDelete: { dismiss() })
            } else if list.type == "group" {
                GroupListPersonal(listID: list.id, onDelete: { dismiss() })
            }
        }
        .onAppear {
            fetchFacetData()
            loadAllData()
        }
    }


    private func fetchFacetData() {
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")

        var facetQuery = Query("")
        facetQuery.facets = ["RankoCategory"]
        facetQuery.hitsPerPage = 0
        facetQuery.maxFacetHits = 50
        facetQuery.filters = "RankoUserID:\(user_data.userID) AND RankoStatus:active"

        index.search(query: facetQuery) { result in
            switch result {
            case .success(let response):
                if let facets = response.facets {
                    for (facetName, facetCounts) in facets {
                        DispatchQueue.main.async {
                            user_data.userRankoCategories = "— \(facetName): \(facetCounts)"
                        }
                    }
                }
            case .failure(let error):
                print("❌ Facet fetch failed: \(error)")
            }
        }
    }

    private func loadAllData() {
        isLoading = true
        errorMessage = nil

        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        var query = Query("").set(\.hitsPerPage, to: 20)
        query.filters = "RankoUserID:\(user_data.userID) AND RankoStatus:active"

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let objectIDs = response.hits.map { $0.objectID.rawValue }
                fetchFromFirebase(using: objectIDs)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ Failed to fetch from Algolia: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchFromFirebase(using objectIDs: [String]) {
        let rankoDataRef = Database.database().reference().child("RankoData")
        rankoDataRef.observeSingleEvent(of: .value) { snapshot, _ in
            guard let value = snapshot.value as? [String: Any] else {
                self.errorMessage = "❌ No data found in Firebase."
                self.isLoading = false
                return
            }

            var fetchedLists: [RankoList] = []

            for objectID in objectIDs {
                guard let listData = value[objectID] as? [String: Any],
                      let name = listData["RankoName"] as? String,
                      let description = listData["RankoDescription"] as? String,
                      let category = listData["RankoCategory"] as? String,
                      let type = listData["RankoType"] as? String,
                      let isPrivate = listData["RankoPrivacy"] as? Bool,
                      let userID = listData["RankoUserID"] as? String,
                      let dateTimeStr = listData["RankoDateTime"] as? String,
                      let itemsDict = listData["RankoItems"] as? [String: [String: Any]] else {
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

struct SelectFeaturedRankosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    @State private var lists: [RankoList] = []
    @State private var selectedFacet: String? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedList: RankoList?
    @State private var activeFacet: FacetCategory?
    
    var onSelect: (RankoList) -> Void

    var facets: [FacetCategory] {
        guard let start = user_data.userRankoCategories.range(of: "["),
              let end = user_data.userRankoCategories.range(of: "]") else {
            return []
        }

        let inner = user_data.userRankoCategories[start.upperBound..<end.lowerBound]
        let entries = inner.components(separatedBy: ", ")

        return entries.compactMap { entry in
            if let openParen = entry.lastIndex(of: "("),
               let closeParen = entry.lastIndex(of: ")") {
                let name = entry[..<openParen].trimmingCharacters(in: .whitespaces)
                let countString = entry[entry.index(after: openParen)..<closeParen]
                if let count = Int(countString) {
                    return FacetCategory(facetName: name, facetCount: count)
                }
            }
            return nil
        }
        .sorted { $0.facetCount > $1.facetCount }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                            .padding(6)
                        TextField("Search Rankos", text: $searchText)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                        Spacer()
                        if !searchText.isEmpty {
                            Image(systemName: "xmark")
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
                    .padding(.leading, 10)
                    .padding(.top, 15)
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                    .buttonStyle(.glassProminent)
                }
                
                // Facet Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(facets) { facet in
                            let isSelected = selectedFacet == facet.facetName
                            let shouldShow = selectedFacet == nil || isSelected

                            if shouldShow {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if isSelected {
                                            selectedFacet = nil
                                        } else {
                                            selectedFacet = facet.facetName
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: FilterChip.icon(named: facet.facetName, in: defaultFilterChips) ?? "circle.fill")
                                        Text(facet.facetName).bold()
                                        Image(systemName: "\(facet.facetCount).circle.fill")

                                        if isSelected {
                                            Image(systemName: "xmark.circle")
                                        }
                                    }
                                    .font(.caption)
                                    .padding(6)
                                    .foregroundColor(isSelected ? .white : categoryChipIconColors[facet.facetName])
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? categoryChipIconColors[facet.facetName]! : categoryChipIconColors[facet.facetName]!.opacity(0.2))
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
                
                ScrollView(.vertical, showsIndicators: false) {
                    
                    // Loading + Error
                    if isLoading {
                        ProgressView("Loading Rankos...").padding()
                    }
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).padding()
                    }
                    
                    // Filtered Ranko Lists
                    VStack(spacing: 8) {
                        let filtered = lists.filter { list in
                            (selectedFacet == nil || list.category == selectedFacet) &&
                            (searchText.isEmpty || list.listName.lowercased().contains(searchText.lowercased()))
                        }
                        
                        ForEach(filtered) { list in
                            HStack {
                                Button {
                                    print("Tapped: \(list.listName)")
                                    onSelect(list)
                                } label: {
                                    if list.type == "default" {
                                        DefaultListIndividualGallery(listData: list, type: "", onUnpin: {})
                                    } else {
                                        GroupListIndividualGallery(listData: list, type: "", onUnpin: {})
                                    }
                                }
                                .foregroundColor(Color(hex: 0xFF9864))
                                .tint(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                    Spacer()
                }
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
        .onAppear {
            fetchFacetData()
            loadAllData()
        }
    }


    private func fetchFacetData() {
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")

        var facetQuery = Query("")
        facetQuery.facets = ["RankoCategory"]
        facetQuery.hitsPerPage = 0
        facetQuery.maxFacetHits = 50
        facetQuery.filters = "RankoUserID:\(user_data.userID) AND RankoPrivacy:false AND RankoStatus:active"

        index.search(query: facetQuery) { result in
            switch result {
            case .success(let response):
                if let facets = response.facets {
                    for (facetName, facetCounts) in facets {
                        DispatchQueue.main.async {
                            user_data.userRankoCategories = "— \(facetName): \(facetCounts)"
                        }
                    }
                }
            case .failure(let error):
                print("❌ Facet fetch failed: \(error)")
            }
        }
    }

    private func loadAllData() {
        isLoading = true
        errorMessage = nil

        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        var query = Query("").set(\.hitsPerPage, to: 20)
        query.filters = "RankoUserID:\(user_data.userID) AND RankoPrivacy:false AND RankoStatus:active"

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let objectIDs = response.hits.map { $0.objectID.rawValue }
                fetchFromFirebase(using: objectIDs)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ Failed to fetch from Algolia: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchFromFirebase(using objectIDs: [String]) {
        let rankoDataRef = Database.database().reference().child("RankoData")
        rankoDataRef.observeSingleEvent(of: .value) { snapshot, _ in
            guard let value = snapshot.value as? [String: Any] else {
                self.errorMessage = "❌ No data found in Firebase."
                self.isLoading = false
                return
            }

            var fetchedLists: [RankoList] = []

            for objectID in objectIDs {
                guard let listData = value[objectID] as? [String: Any],
                      let name = listData["RankoName"] as? String,
                      let description = listData["RankoDescription"] as? String,
                      let category = listData["RankoCategory"] as? String,
                      let type = listData["RankoType"] as? String,
                      let isPrivate = listData["RankoPrivacy"] as? Bool,
                      let userID = listData["RankoUserID"] as? String,
                      let dateTimeStr = listData["RankoDateTime"] as? String,
                      let itemsDict = listData["RankoItems"] as? [String: [String: Any]] else {
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

struct SearchUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @State private var users: [RankoUser] = []
    @State private var selectedFacet: String? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedUser: RankoUser?
    @State private var showSpectate: Bool = false

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 10) {
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                            .padding(6)
                        TextField("Search Rankos", text: $searchText)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                        Spacer()
                        if !searchText.isEmpty {
                            Image(systemName: "xmark")
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
                    .padding(.leading, 10)
                    .padding(.top, 15)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                    .buttonStyle(.glassProminent)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    if isLoading {
                        ProgressView("Loading Users...").padding()
                            .frame(maxWidth: .infinity)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(users) { user in
                            HStack {
                                Button {
                                    selectedUser = user
                                } label: {
                                    UserGalleryView(user: user)
                                }
                                .foregroundColor(Color(hex: 0xFF9864))
                                .tint(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                    Spacer()
                }
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
        .sheet(item: $selectedUser) { user in
            ProfileSpectateView(userID: user.id)
        }
        .onAppear {
            performSearch()
        }
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
    }

    private func performSearch() {
        isLoading = true
        errorMessage = nil

        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoUsers")

        let query = Query(searchText)
            .set(\.hitsPerPage, to: 20)

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let objectIDs = response.hits.map { $0.objectID.rawValue }
                fetchFromFirebase(using: objectIDs)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ Algolia error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchFromFirebase(using objectIDs: [String]) {
        let group = DispatchGroup()
        var loaded: [RankoUser] = []
        let appendQueue = DispatchQueue(label: "followers.append.queue") // serialize appends
        
        for fid in objectIDs {
            group.enter()
            let userRef = Database.database().reference()
                .child("UserData")
                .child(fid)
            
            userRef.observeSingleEvent(of: .value) { snapshot in
                defer { group.leave() }
                
                guard let root = snapshot.value as? [String: Any] else { return }
                
                let details = root["UserDetails"] as? [String: Any]
                let pfp     = root["UserProfilePicture"] as? [String: Any]
                
                let name = (details?["UserName"] as? String) ?? "Unknown"
                let desc = (details?["UserDescription"] as? String) ?? ""
                let pic  = (pfp?["UserProfilePicturePath"] as? String) ?? ""
                
                let user = RankoUser(
                    id: fid,
                    userName: name,
                    userDescription: desc,
                    userProfilePicture: pic
                )
                
                appendQueue.sync {
                    loaded.append(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            // Replace `self.followers` with your actual target property
            self.users = loaded
            self.errorMessage = loaded.isEmpty ? "No users found." : nil
            self.isLoading = false
        }
    }
}

struct UserGalleryView: View {
    let user: RankoUser
    @State private var profileImage: UIImage?

    var body: some View {
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
                    Text(user.userName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: 0x7E5F46))
                    Spacer()
                }

                if !user.userDescription.isEmpty {
                    Text(user.userDescription)
                        .font(.system(size: 12 , weight: .medium))
                        .foregroundColor(Color(hex: 0x7E5F46).opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.leading, 15)
        .padding(.vertical, 10)
        .onAppear {
            loadProfileImage(from: user.userProfilePicture)
        }
    }

    private func loadProfileImage(from path: String) {
        Storage.storage().reference().child("profilePictures").child(path)
            .getData(maxSize: Int64(2 * 1024 * 1024)) { data, _ in
                if let data = data, let img = UIImage(data: data) {
                    self.profileImage = img
                }
            }
    }
}

struct SearchFollowersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @State private var users: [RankoUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedUser: RankoUser?
    @State private var filteredUsers: [RankoUser] = []
    @State private var followerIDs: [String] = []
    
    let userID: String
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 10) {
                // Search Bar (optional filtering)
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                            .padding(6)
                        TextField("Search Followers", text: $searchText)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                        Spacer()
                        if !searchText.isEmpty {
                            Image(systemName: "xmark")
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
                    .padding(.leading, 10)
                    .padding(.top, 15)
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                    .buttonStyle(.glassProminent)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    if isLoading {
                        ProgressView("Loading Followers…")
                            .frame(maxWidth: .infinity)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(filteredUsers) { user in
                            HStack {
                                Button {
                                    selectedUser = user
                                } label: {
                                    UserGalleryView(user: user)
                                }
                                .foregroundColor(Color(hex: 0xFF9864))
                                .tint(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                    Spacer()
                }
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
        .sheet(item: $selectedUser) { user in
            ProfileSpectateView(userID: user.id)
        }
        .onAppear {
            loadFollowers()
        }
        .onChange(of: searchText) { _, newValue in
            // if the search field is empty, show all; otherwise filter by username
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredUsers = users
            } else {
                let lc = newValue.lowercased()
                filteredUsers = users.filter {
                    $0.userName.lowercased().contains(lc)
                }
            }
        }
    }
    
    private func loadFollowers() {
        isLoading = true
        errorMessage = nil

        let followersRef = Database.database()
            .reference()
            .child("UserData")
            .child(userID)
            .child("UserSocial")
            .child("UserFollowers")

        followersRef.observeSingleEvent(of: .value) { snap in
            // Handle "no followers" represented as "" or null
            if snap.value is NSNull || (snap.value as? String) == "" {
                self.errorMessage = "No followers found."
                self.isLoading = false
                return
            }

            // Expected shape: followerID -> timestampString
            if let map = snap.value as? [String: Any], !map.isEmpty {
                // Build (timestampInt, followerID) pairs
                let sortedPairs: [(Int, String)] = map.compactMap { (fid, tsAny) in
                    if let s = tsAny as? String, let t = Int(s) { return (t, fid) }
                    if let t = tsAny as? Int { return (t, fid) }
                    return nil
                }
                .sorted(by: { $0.0 > $1.0 }) // newest first

                // Fallback: if timestamps were non-numeric for some reason, just use keys
                let ids: [String] = sortedPairs.isEmpty
                    ? Array(map.keys)
                    : sortedPairs.map { $0.1 }

                guard !ids.isEmpty else {
                    self.errorMessage = "No followers found."
                    self.isLoading = false
                    return
                }

                self.followerIDs = ids
                self.fetchFollowerProfiles(ids: ids) // will set isLoading=false when done
            } else {
                self.errorMessage = "No followers found."
                self.isLoading = false
            }
        }
    }
    
    func fetchFollowerProfiles(ids: [String]) {
        let group = DispatchGroup()
        var loaded: [RankoUser] = []
        let appendQueue = DispatchQueue(label: "followers.append.queue") // serialize appends
        
        for fid in ids {
            group.enter()
            let userRef = Database.database().reference()
                .child("UserData")
                .child(fid)
            
            userRef.observeSingleEvent(of: .value) { snapshot in
                defer { group.leave() }
                
                guard let root = snapshot.value as? [String: Any] else { return }
                
                let details = root["UserDetails"] as? [String: Any]
                let pfp     = root["UserProfilePicture"] as? [String: Any]
                
                let name = (details?["UserName"] as? String) ?? "Unknown"
                let desc = (details?["UserDescription"] as? String) ?? ""
                let pic  = (pfp?["UserProfilePicturePath"] as? String) ?? ""
                
                let user = RankoUser(
                    id: fid,
                    userName: name,
                    userDescription: desc,
                    userProfilePicture: pic
                )
                
                appendQueue.sync {
                    loaded.append(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.users = loaded

            if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.filteredUsers = loaded
            } else {
                let lc = self.searchText.lowercased()
                self.filteredUsers = loaded.filter { $0.userName.lowercased().contains(lc) }
            }

            self.errorMessage = loaded.isEmpty ? "No followers found." : nil
            self.isLoading = false
        }
    }
}


struct SearchFollowingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @State private var users: [RankoUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedUser: RankoUser?
    @State private var filteredUsers: [RankoUser] = []
    @State private var followingIDs: [String] = []
    
    let userID: String
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 10) {
                // Search Bar (optional filtering)
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(hex: 0x7E5F46).opacity(0.6))
                            .padding(6)
                        TextField("Search Following", text: $searchText)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.6) : Color(hex: 0x7E5F46).opacity(0.9))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accentColor((searchText.isEmpty) ? Color(hex: 0x7E5F46).opacity(0.3) : Color(hex: 0x7E5F46).opacity(0.7))
                        Spacer()
                        if !searchText.isEmpty {
                            Image(systemName: "xmark")
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
                    .padding(.leading, 10)
                    .padding(.top, 15)
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .tint(Color(hex: 0xFEF4E7))
                    .padding(.trailing, 20)
                    .padding(.top, 15)
                    .buttonStyle(.glassProminent)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    if isLoading {
                        ProgressView("Loading Following…")
                            .frame(maxWidth: .infinity)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(filteredUsers) { user in
                            HStack {
                                Button {
                                    selectedUser = user
                                } label: {
                                    UserGalleryView(user: user)
                                }
                                .foregroundColor(Color(hex: 0xFF9864))
                                .tint(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                    Spacer()
                }
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
        .sheet(item: $selectedUser) { user in
            ProfileSpectateView(userID: user.id)
        }
        .onAppear {
            loadFollowing()
        }
        .onChange(of: searchText) { _, newValue in
            // if the search field is empty, show all; otherwise filter by username
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredUsers = users
            } else {
                let lc = newValue.lowercased()
                filteredUsers = users.filter {
                    $0.userName.lowercased().contains(lc)
                }
            }
        }
    }
    
    private func loadFollowing() {
        isLoading = true
        errorMessage = nil
        
        let followingRef = Database.database()
            .reference()
            .child("UserData")
            .child(userID)
            .child("UserSocial")
            .child("UserFollowing")
        
        followingRef.observeSingleEvent(of: .value) { snap in
            // Handle "no following" represented as "" or null
            if snap.value is NSNull || (snap.value as? String) == "" {
                self.errorMessage = "No following found."
                self.isLoading = false
                return
            }

            // Expected shape: followingID -> timestampString
            if let map = snap.value as? [String: Any], !map.isEmpty {
                // Build (timestampInt, followingID) pairs
                let sortedPairs: [(Int, String)] = map.compactMap { (fid, tsAny) in
                    if let s = tsAny as? String, let t = Int(s) { return (t, fid) }
                    if let t = tsAny as? Int { return (t, fid) }
                    return nil
                }
                .sorted(by: { $0.0 > $1.0 }) // newest first

                // Fallback: if timestamps were non-numeric for some reason, just use keys
                let ids: [String] = sortedPairs.isEmpty
                    ? Array(map.keys)
                    : sortedPairs.map { $0.1 }

                guard !ids.isEmpty else {
                    self.errorMessage = "No following found."
                    self.isLoading = false
                    return
                }

                self.followingIDs = ids
                self.fetchFollowingProfiles(ids: ids) // will set isLoading=false when done
            } else {
                self.errorMessage = "No following found."
                self.isLoading = false
            }
        }
    }
    
    private func fetchFollowingProfiles(ids: [String]) {
        let group = DispatchGroup()
        var loaded: [RankoUser] = []
        let appendQueue = DispatchQueue(label: "following.append.queue") // serialize appends
        
        for fid in ids {
            group.enter()
            let userRef = Database.database().reference()
                .child("UserData")
                .child(fid)
            
            userRef.observeSingleEvent(of: .value) { snapshot in
                defer { group.leave() }
                
                guard let root = snapshot.value as? [String: Any] else { return }
                
                let details = root["UserDetails"] as? [String: Any]
                let pfp     = root["UserProfilePicture"] as? [String: Any]
                
                let name = (details?["UserName"] as? String) ?? "Unknown"
                let desc = (details?["UserDescription"] as? String) ?? ""
                let pic  = (pfp?["UserProfilePicturePath"] as? String) ?? ""
                
                let user = RankoUser(
                    id: fid,
                    userName: name,
                    userDescription: desc,
                    userProfilePicture: pic
                )
                
                appendQueue.sync {
                    loaded.append(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.users = loaded

            if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.filteredUsers = loaded
            } else {
                let lc = self.searchText.lowercased()
                self.filteredUsers = loaded.filter { $0.userName.lowercased().contains(lc) }
            }

            self.errorMessage = loaded.isEmpty ? "No following found." : nil
            self.isLoading = false
        }
    }
}


struct ProfileSpectateView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    let userID: String
        
    @State private var username: String = ""
    @State private var userDescription: String = ""
    @State private var userInterests: String = ""
    @State private var userProfileImagePath: String = ""
    @State private var profileImage: UIImage?
    @State private var rankoCount: Int = 0
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var isCheckingFollowStatus = true
    @State private var showUnfollowConfirmation = false
    @State private var showSearchRankos = false
    @State private var showUserFollowers = false
    @State private var showUserFollowing = false
    @State private var followUser = false
    @State private var listViewID = UUID()
    @State private var isLoadingLists = true
    @State private var animatedTags: Set<String> = []
    
    @State private var featuredLists: [Int: RankoList] = [:]
    @State private var featuredLoading: Bool = true
    @State private var featuredLoadFailed: Bool = false
    @State private var retryCount: Int = 0
    @State private var selectedFeaturedList: RankoList?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var lists: [RankoList] = []
    
    @State private var topCategories: [String] = []
    
    static let interestIconMapping: [String: String] = [
        "Sport": "figure.gymnastics",
        "Animals": "pawprint.fill",
        "Music": "music.note",
        "Food": "fork.knife",
        "Nature": "leaf.fill",
        "Geography": "globe.europe.africa.fill",
        "History": "building.columns.fill",
        "Science": "atom",
        "Gaming": "gamecontroller.fill",
        "Celebrities": "star.fill",
        "Art": "paintbrush.pointed.fill",
        "Cars": "car.side.roof.cargo.carrier.fill",
        "Football": "soccerball",
        "Fruit": "apple.logo",
        "Soda": "takeoutbag.and.cup.and.straw.fill",
        "Mammals": "hare.fill",
        "Flowers": "microbe.fill",
        "Movies": "movieclapper",
        "Instruments": "guitars.fill",
        "Politics": "person.bust.fill",
        "Basketball": "basketball.fill",
        "Vegetables": "carrot.fill",
        "Alcohol": "flame.fill",
        "Birds": "bird.fill",
        "Trees": "tree.fill",
        "Shows": "tv",
        "Festivals": "hifispeaker.2.fill",
        "Planets": "circles.hexagonpath.fill",
        "Tennis": "tennisball.fill",
        "Pizza": "triangle.lefthalf.filled",
        "Coffee": "cup.and.heat.waves.fill",
        "Dogs": "dog.fill",
        "Social Media": "message.fill",
        "Albums": "record.circle",
        "Actors": "theatermasks.fill",
        "Travel": "airplane",
        "Motorsport": "steeringwheel",
        "Eggs": "oval.portrait.fill",
        "Cats": "cat.fill",
        "Books": "books.vertical.fill",
        "Musicians": "music.microphone",
        "Australian Football": "australian.football.fill",
        "Fast Food": "takeoutbag.and.cup.and.straw.fill",
        "Fish": "fish.fill",
        "Board Games": "dice.fill",
        "Numbers": "1.square.fill",
        "Relationships": "heart.fill",
        "American Football": "american.football.fill",
        "Pasta": "water.waves",
        "Reptiles": "lizard.fill",
        "Card Games": "suit.club.fill",
        "Letters": "a.square.fill",
        "Baseball": "baseball.fill",
        "Ice Cream": "snowflake",
        "Bugs": "ladybug.fill",
        "Memes": "camera.fill",
        "Shapes": "triangle.fill",
        "Emotions": "face.smiling",
        "Ice Hockey": "figure.ice.hockey",
        "Statues": "figure.stand",
        "Gym": "figure.indoor.cycle",
        "Running": "figure.run"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xDBC252),  Color(hex: 0xFF9864)]),
                               startPoint: .top,
                               endPoint: .center)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                                print("Dismissing Spectate Profile...")
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .heavy, design: .default))
                                    .padding(.vertical, 2)
                            }
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .tint(Color(hex: 0xFEF4E7))
                            .buttonStyle(.glassProminent)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // MARK: – Profile Picture
                        Group {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                // Placeholder (Skeleton)
                                SkeletonView(Circle())
                            }
                        }
                        .frame(width: 100, height: 100)
                        .overlay(Circle()
                            .stroke(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFECC5), Color(hex: 0xFECF88)]),
                                                   startPoint: .top,
                                                   endPoint: .bottom), lineWidth: 3
                            )
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 2))
                        .shadow(radius: 3)
                        
                        // Name
                        Text(username)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: 0xFFFADB))
                        
                        // user_data.userDescription
                        if !userDescription.isEmpty {
                            Text(userDescription)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: 0xFFFADB))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // user_data.userInterests as buttons
                        if !userInterests.isEmpty {
                            let tags = userInterests
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }

                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    let icon = ProfileSpectateView.interestIconMapping[tag] ?? "tag.fill"

                                    Button(action: { print("\(tag) clicked") }) {
                                        HStack(spacing: 4) {
                                            ZStack {
                                                Image(systemName: icon)
                                                    .font(.system(size: 12, weight: .heavy))
                                                    .foregroundColor(.clear)
                                                if animatedTags.contains(tag) {
                                                    Image(systemName: icon)
                                                        .font(.system(size: 12, weight: .heavy))
                                                        .transition(.symbolEffect(.drawOn.individually))
                                                        .padding(1)
                                                }
                                            }
                                            Text(tag)
                                                .font(.system(size: 10, weight: .heavy))
                                        }
                                        .cornerRadius(8)
                                    }
                                    .foregroundColor(Color(hex: 0x7E5F46))
                                    .tint(Color(hex: 0xFEF4E7))
                                    .buttonStyle(.glassProminent)
                                    .geometryGroup()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Followers / Following / Rankos
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(rankoCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Rankos")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            
                            VStack {
                                Text("\(followersCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Followers")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            .onTapGesture {
                                showUserFollowers = true
                            }
                            
                            VStack {
                                Text("\(followingCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                                Text("s")
                                    .font(.system(size: 4, weight: .bold))
                                    .foregroundColor(.clear)
                                Text("Following")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xFFFADB))
                            }
                            .onTapGesture {
                                showUserFollowing = true
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom)
                    }
                    .padding(.top, 0)
                    
                    HStack {
                        Button(action: {showSearchRankos = true}) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 17, weight: .heavy))
                                Text("Search Rankos")
                                    .font(.system(size: 14, weight: .heavy))
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                        }
                        .foregroundColor(Color(hex: 0x7E5F46))
                        .tint(Color(hex: 0xFEF4E7))
                        .buttonStyle(.glassProminent)
                        if isCheckingFollowStatus {
                            ProgressView()
                                .frame(width: 100, height: 30)
                        } else {
                            Button {
                                if followUser {
                                    showUnfollowConfirmation = true
                                } else {
                                    followUserAction()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: followUser ? "checkmark" : "person.crop.circle")
                                        .font(.system(size: 17, weight: .heavy))
                                        .animation(.smooth(duration: 0.3, extraBounce: 0), value: followUser)
                                    Text(followUser ? "Following" : "Follow")
                                        .font(.system(size: 14, weight: .heavy))
                                        .animation(.smooth(duration: 0.3, extraBounce: 0), value: followUser)
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                            }
                            .foregroundColor(Color(hex: 0x7E5F46))
                            .tint(Color(hex: 0xFEF4E7))
                            .buttonStyle(.glassProminent)
                            .alert("Are you sure you want to unfollow this user?", isPresented: $showUnfollowConfirmation) {
                                Button("Unfollow", role: .destructive) {
                                    unfollowUserAction()
                                }
                                Button("Cancel", role: .cancel) { }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    VStack {
                        HStack {
                            Text("Featured")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(Color(hex: 0x7E5F46))
                            Spacer()
                        }
                        .padding(.bottom, 5)

                        VStack(spacing: 13) {
                            let filledSlots = featuredLists.keys.sorted()
                            let emptySlots = (1...10).filter { !featuredLists.keys.contains($0) }

                            // ✅ If loading or failed, show placeholders
                            if featuredLoading {
                                HStack {
                                    ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 60, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.3)
                                        .frame(height: 60)
                                        .padding(60)
                                }
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                         startPoint: .top,
                                                         endPoint: .bottom
                                                        )
                                          )
                                )
                                .padding(.top, 40)
                                .padding(.bottom, 120)
                                
                            } else if featuredLoadFailed {
                                // ❌ If failed after 3 attempts, show retry buttons
                                ForEach(1...10, id: \.self) { slot in
                                    HStack {
                                        Button {
                                            retryFeaturedLoading()
                                        } label: {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 24, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                        .disabled(false)
                                    }
                                }
                            } else {
                                // ✅ Normal loaded state
                                ForEach(filledSlots, id: \.self) { slot in
                                    HStack {
                                        Button {
                                            if let list = featuredLists[slot] {
                                                selectedFeaturedList = list
                                            }
                                        } label: {
                                            if let list = featuredLists[slot] {
                                                if list.type == "default" {
                                                    DefaultListIndividualGallery(listData: list, type: "featured", onUnpin: {
                                                    })
                                                } else {
                                                    GroupListIndividualGallery(listData: list, type: "featured", onUnpin: {
                                                    })
                                                }
                                            }
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                    }
                                }

                                ForEach(emptySlots, id: \.self) { slot in
                                    HStack {
                                        Button {
                                        } label: {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 24, weight: .black))
                                                    .foregroundColor(Color(hex: 0x7E5F46))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                                             startPoint: .top,
                                                             endPoint: .bottom
                                                            ))
                                        .buttonStyle(.glassProminent)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity)
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
                .ignoresSafeArea()
                .sheet(isPresented: $showSearchRankos) {
                    SearchRankosView()
                }
                .fullScreenCover(item: $selectedFeaturedList) { list in
                    if list.type == "default" {
                        DefaultListSpectate(listID: list.id, creatorID: list.userCreator)
                    } else if list.type == "group" {
                        GroupListSpectate(listID: list.id, creatorID: list.userCreator)
                    }
                    
                }
                .sheet(isPresented: $showUserFollowers) {
                    SearchFollowersView(userID: userID)
                }
                .sheet(isPresented: $showUserFollowing) {
                    SearchFollowingView(userID: userID)
                }
                .refreshable {
                    listViewID     = UUID()
                    isLoadingLists = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isLoadingLists = false
                    }
                    loadFollowStats()
                    tryLoadFeaturedRankos()
                }
                .onAppear {
                    listViewID     = UUID()
                    isLoadingLists = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoadingLists = false
                    }
                    loadFollowStats()
                    tryLoadFeaturedRankos()
                    loadNumberOfRankos()
                    loadProfileData()
                    
                    checkFollowStatus()
                    
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                        AnalyticsParameterScreenName: "ProfileSpectate",
                        AnalyticsParameterScreenClass: "ProfileSpectateView"
                    ])
                }
            }
            
        }
    }
    
    private func checkFollowStatus() {
            isCheckingFollowStatus = true
            let db = Database.database().reference()
            db.child("UserData")
              .child(userID)
              .child("UserSocial")
              .child("UserFollowers")
              .child(user_data.userID)
              .observeSingleEvent(of: .value) { snap in
                  DispatchQueue.main.async {
                      followUser = snap.exists()
                      isCheckingFollowStatus = false
                  }
              }
        }
        
        private func followUserAction() {
            let now = Date()
            let aedtFormatter = DateFormatter()
            aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
            aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
            aedtFormatter.dateFormat = "yyyyMMddHHmmss"
            let rankoDateTime = aedtFormatter.string(from: now)
            
            let db = Database.database().reference()
            let followerPath = db.child("UserData")
                                .child(userID)
                                .child("UserSocial")
                                .child("UserFollowers")
                                .child(user_data.userID)
            let followingPath = db.child("UserData")
                                .child(user_data.userID)
                                .child("UserSocial")
                                .child("UserFollowing")
                                .child(userID)
            
            // write both sides
            followerPath.setValue(rankoDateTime)
            followingPath.setValue(rankoDateTime)
            
            followUser = true
            // optionally refresh counts
            loadFollowStats()
        }
        
        private func unfollowUserAction() {
            let db = Database.database().reference()
            let followerPath = db.child("UserData")
                                .child(userID)
                                .child("UserSocial")
                                .child("UserFollowers")
                                .child(user_data.userID)
            let followingPath = db.child("UserData")
                                .child(user_data.userID)
                                .child("UserSocial")
                                .child("UserFollowing")
                                .child(userID)
            
            followerPath.removeValue()
            followingPath.removeValue()
            
            followUser = false
            loadFollowStats()
        }
    
    private func loadNumberOfRankos() {
        guard !userID.isEmpty else { print("Skipping loadNumberOfRankos: userID is empty"); return }
        
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")
        var query = Query("").set(\.hitsPerPage, to: 0) // 0 results, just want count
        query.filters = "RankoUserID:\(userID) AND RankoStatus:active"

        index.search(query: query) { (result: Result<SearchResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let totalResults = response.nbHits
                    rankoCount = totalResults!
                    print("✅ Total Algolia Results: \(String(describing: totalResults))")
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child("UserStats").child(userID).child("UserRankoCount")
                    dbRef.setValue(totalResults!)
                case .failure(let error):
                    print("❌ Error fetching Algolia results: \(error)")
                }
            }
        }
    }
    
    private func loadProfileData() {
        let userDetails = Database.database().reference().child("UserData").child(userID).child("UserDetails")
        let userProfilePicture = Database.database().reference().child("UserData").child(userID).child("UserProfilePicture")

        userDetails.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ loadProfileData: no user data at path")
                return
            }

            // Extract fields
            let name  = value["UserName"]            as? String ?? ""
            let desc  = value["UserDescription"]     as? String ?? ""
            let interestsArray = value["UserInterests"] as? [String]
            let interests = interestsArray?
                                .joined(separator: ",")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            ?? (value["UserInterests"] as? String ?? "")

            DispatchQueue.main.async {
                // Update all UI state
                self.username             = name
                self.userDescription      = desc
                self.userInterests        = interests

                // Animate tags
                let tags = interests
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                for (idx, tag) in tags.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(idx)) {
                        _ = withAnimation(.easeOut(duration: 0.4)) {
                            animatedTags.insert(String(tag))
                        }
                    }
                }
            }
        } withCancel: { error in
            print("❌ loadProfileData cancelled:", error.localizedDescription)
        }
        
        userProfilePicture.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ loadProfileData: no user data at path")
                return
            }
            
            let picPath = value["UserProfilePicturePath"] as? String ?? ""

            DispatchQueue.main.async {
                self.userProfileImagePath = picPath

                loadProfileImage(from: picPath)
            }
        } withCancel: { error in
            print("❌ loadProfileData cancelled:", error.localizedDescription)
        }
    }

    // MARK: – Download the picture from Storage
    private func loadProfileImage(from path: String) {
        guard !path.isEmpty else {
            print("⚠️ loadProfileImage: empty path, skipping")
            return
        }

        let storageRef = Storage.storage()
            .reference()
            .child("profilePictures")
            .child(path)

        storageRef.getData(maxSize: 2 * 1024 * 1024) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ loadProfileImage failed:", error.localizedDescription)
                    return
                }
                guard let data = data, let ui = UIImage(data: data) else {
                    print("⚠️ loadProfileImage: no data or decode failure")
                    return
                }
                self.profileImage = ui
            }
        }
    }
    
    private func loadFollowStats() {
        guard !userID.isEmpty else { print("Skipping loadFollowStats: userID is empty"); return }
        
        let db = Database.database().reference()
        let group = DispatchGroup()

        group.enter()
        db.child("UserData").child(userID).child("UserSocial").child("UserFollowers")
            .observeSingleEvent(of: .value) { snapshot in
                DispatchQueue.main.async {
                    self.followersCount = Int(snapshot.childrenCount)
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child(userID).child("UserStats").child("UserFollowerCount")
                    dbRef.setValue(followersCount)
                }
                group.leave()
            }

        group.enter()
        db.child("UserData").child(userID).child("UserSocial").child("UserFollowing")
            .observeSingleEvent(of: .value) { snapshot in
                DispatchQueue.main.async {
                    self.followingCount = Int(snapshot.childrenCount)
                    let db = Database.database().reference()
                    let dbRef = db.child("UserData").child(userID).child("UserStats").child("UserFollowingCount")
                    dbRef.setValue(followingCount)
                }
                group.leave()
            }

        group.notify(queue: .main) {
            print("✅ Finished loading follow stats")
        }
    }
    
    private func retryFeaturedLoading() {
        featuredLoadFailed = false
        featuredLoading = true
        retryCount = 0
        tryLoadFeaturedRankos()
    }

    private func tryLoadFeaturedRankos() {
        guard retryCount < 3 else {
            DispatchQueue.main.async {
                self.featuredLoading = false
                self.featuredLoadFailed = true
            }
            return
        }
        retryCount += 1

        // Attempt Firebase fetch
        guard !userID.isEmpty else {
            print("❌ No UID found, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tryLoadFeaturedRankos() }
            return
        }

        let baseRef = Database.database()
            .reference()
            .child("UserData")
            .child(userID)
            .child("UserRankos")
            .child("UserFeaturedRankos")

        baseRef.getData { error, snapshot in
            if let error = error {
                print("❌ Firebase error: \(error.localizedDescription), retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tryLoadFeaturedRankos() }
                return
            }

            guard let snap = snapshot, snap.exists() else {
                print("⚠️ No featured rankos found")
                DispatchQueue.main.async {
                    self.featuredLists = [:]
                    self.featuredLoading = false
                }
                return
            }

            // ✅ Successfully connected
            var tempLists: [Int: RankoList] = [:]
            let group = DispatchGroup()

            for child in snap.children.allObjects as? [DataSnapshot] ?? [] {
                if let slot = Int(child.key), let listID = child.value as? String {
                    group.enter()
                    fetchFeaturedList(slot: slot, listID: listID) {
                        if let list = $0 { tempLists[slot] = list }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.featuredLists = tempLists
                self.featuredLoading = false
                print("✅ Featured Rankos loaded successfully")
            }
        }
    }

    // ✅ Modified fetchFeaturedList to support completion
    private func fetchFeaturedList(slot: Int, listID: String, completion: @escaping (RankoList?) -> Void) {
        let listRef = Database.database()
            .reference()
            .child("RankoData")
            .child(listID)

        listRef.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any],
                  let rl = parseListData(dict: dict, id: listID) else {
                completion(nil)
                return
            }
            completion(rl)
        }
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        guard
            let listName      = dict["RankoName"]        as? String,
            let description   = dict["RankoDescription"] as? String,
            let category      = dict["RankoCategory"]    as? String,
            let type          = dict["RankoType"]        as? String,
            let privacy       = dict["RankoPrivacy"]     as? Bool,
            let dateTime      = dict["RankoDateTime"]    as? String,
            let userCreator   = dict["RankoUserID"]      as? String,
            let itemsDict     = dict["RankoItems"]       as? [String: Any]
        else { return nil }

        let isPrivateString = privacy ? "Private" : "Public"
        var rankoItems: [RankoItem] = []

        for (_, value) in itemsDict {
            guard
                let itemDict  = value as? [String: Any],
                let itemID    = itemDict["ItemID"]          as? String,
                let itemName  = itemDict["ItemName"]        as? String,
                let itemDesc  = itemDict["ItemDescription"] as? String,
                let itemImg   = itemDict["ItemImage"]       as? String,
                let itemVotes = itemDict["ItemVotes"]       as? Int,
                let itemRank  = itemDict["ItemRank"]        as? Int
            else { continue }

            let record = RankoRecord(
                objectID:        itemID,
                ItemName:        itemName,
                ItemDescription: itemDesc,
                ItemCategory: "",
                ItemImage:       itemImg
            )
            rankoItems.append(RankoItem(id: itemID,
                                        rank: itemRank,
                                        votes: itemVotes,
                                        record: record))
        }

        rankoItems.sort { $0.rank < $1.rank }

        return RankoList(
            id:               id,
            listName:         listName,
            listDescription:  description,
            type:             type,
            category:         category,
            isPrivate:        isPrivateString,
            userCreator:      userCreator,
            dateTime:         dateTime,
            items:            rankoItems
        )
    }
}

struct FlexibleView: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY),
                          proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension CGSize {
    /// This function will return a new size that fits the given size in an aspect ratio
    func aspectFit(_ to: CGSize) -> CGSize {
        let scaleX = to.width / self.width
        let scaleY = to.height / self.height
        
        let aspectRatio = min(scaleX, scaleY)
        return .init(width: aspectRatio * width, height: aspectRatio * height)
    }
}

@Model
class Cache {
    var cacheID: String
    var data: Data
    var expiration: Date
    var creation: Date = Date()
    
    init(cacheID: String, data: Data, expiration: Date) {
        self.cacheID = cacheID
        self.data = data
        self.expiration = expiration
    }
}

final class CacheManager {
    /// You can also update this to run entirely on a different thread
    @MainActor static let shared = CacheManager()
    /// Separate Context For Cache Operations
    let context: ModelContext? = {
        guard let container = try? ModelContainer(for: Cache.self) else { return nil }
        let context = ModelContext(container)
        return context
    }()
    /// You can use some values like 20 or 30, depending on your requirement
    let cacheLimit: Int = 30
    
    init() {
        removeExpiredItems()
    }
    
    private func removeExpiredItems() {
        guard let context else { return }
        
        let todayDate: Date = .now
        let predicate = #Predicate<Cache> { todayDate > $0.expiration }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            try context.enumerate(descriptor) {
                context.delete($0)
                print("Expired ID: \($0.cacheID)")
            }
            
            try context.save()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func verifyLimits() throws {
        guard let context else { return }
        let countDescriptor = FetchDescriptor<Cache>()
        let count = try context.fetchCount(countDescriptor)
        
        if count >= cacheLimit {
            /// By removing the first oldest item each time it’s inserted, you can ensure that the cache remains within the specified limit
            var fetchDescriptor = FetchDescriptor<Cache>(sortBy: [.init(\.creation, order: .forward)])
            fetchDescriptor.fetchLimit = 1
            
            if let oldCache = try context.fetch(fetchDescriptor).first {
                context.delete(oldCache)
            }
        }
    }
    
    /// CRUD Operations
    func insert(id: String, data: Data, expirationDays: Int) throws {
        guard let context else { return }
        /// Checking if it's already existed
        if let cache = try get(id: id) {
            /// You can update it's value, but I'm removing it instead
            context.delete(cache)
        }
        
        try verifyLimits()
        
        let expiration = calculateExpirationDate(expirationDays)
        let cache = Cache(cacheID: id, data: data, expiration: expiration)
        context.insert(cache)
        try context.save()
        print("Cache Added ID: \(id)")
    }
    
    func get(id: String) throws -> Cache? {
        guard let context else { return nil }
        
        let predicate = #Predicate<Cache> { $0.cacheID == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        /// Since, it's only one
        descriptor.fetchLimit = 1
        
        if let cache = try context.fetch(descriptor).first {
            return cache
        }
        
        return nil
    }
    
    func remove(id: String) throws {
        guard let context else { return }
        if let cache = try get(id: id) {
            context.delete(cache)
            try context.save()
            print("Cache Removed ID: \(id)")
        }
    }
    
    func removeAll() throws {
        guard let context else { return }
        /// Empty Fetch Descriptor will return all objects
        let descriptor = FetchDescriptor<Cache>()
        try context.enumerate(descriptor) {
            context.delete($0)
        }
        
        try context.save()
    }
    
    private func calculateExpirationDate(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: days, to: .now) ?? .now
    }
}

struct MissionToast: View {
    @Binding var isShown: Bool
    var title: String? = "Mission"
    var message: String = "message"
    var icon: Image = Image(systemName: "exclamationmark.circle")
    var alignment: Alignment = .top
    
    var goal: Int? = nil
    var progress: Int? = nil

    var body: some View {
        VStack {
            if isShown {
                content
                    .transition(.move(edge: alignmentToEdge(self.alignment)).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: isShown)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                icon
                    .foregroundColor(.orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Text(message)
                        .font(.subheadline)
                }
            }

            if let goal, let progress {
                ProgressView(value: Float(progress), total: Float(goal))
                    .accentColor(.orange)
                Text("\(progress)/\(goal)")
                    .font(.caption)
                    .foregroundColor(.gray)
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

struct Mission {
    let description: String
    let goal: Int
    let type: MissionType
}

enum MissionType {
    case gamesPlayed
    case highScore
    case subscribed
}

struct AppIcon: Identifiable {
    let id = UUID()
    let iconName: String?
    let previewImage: String
    var isLocked: Bool
    let mission: Mission?
}

struct CustomiseAppIconView: View {
    @AppStorage("totalBlindSequenceGamesPlayed") private var totalGamesPlayed = 0
    @AppStorage("BlindSequenceHighScore") private var highScore = 0
    @AppStorage("isProUser") var subscribed: Int = 0

    @AppStorage("unlocked_Medal_AppIcon") private var unlockedMedal: Bool = false
    @AppStorage("unlocked_Trophy_AppIcon") private var unlockedTrophy: Bool = false
    @AppStorage("unlocked_Crown_AppIcon") private var unlockedCrown: Bool = false
    @AppStorage("unlocked_Star_AppIcon") private var unlockedStar: Bool = false

    @State private var unlockingIconIndex: Int? = nil
    @State private var isUnlocking: Bool = false
    @State private var selectedIcon: String? = UIApplication.shared.alternateIconName
    @State private var appIcons: [AppIcon] = []
    
    @State private var toastMessage: String = ""
    @State private var toastProgress: Int? = nil
    @State private var toastGoal: Int? = nil
    @State private var showToast: Bool = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var toastID = UUID()

    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 4), count: 5)

    private func initializeAppIcons() {
        appIcons = [
            AppIcon(iconName: "Default_AppIcon", previewImage: "Default_AppIcon_Preview", isLocked: false, mission: nil),
            AppIcon(iconName: "Medal_AppIcon", previewImage: "Medal_AppIcon_Preview", isLocked: !unlockedMedal, mission: Mission(description: "Achieve 20 Points on Blind Sequence", goal: 20, type: .highScore)),
            AppIcon(iconName: "Trophy_AppIcon", previewImage: "Trophy_AppIcon_Preview", isLocked: !unlockedTrophy, mission: Mission(description: "Achieve 30 Points on Blind Sequence", goal: 30, type: .highScore)),
            AppIcon(iconName: "Star_AppIcon", previewImage: "Star_AppIcon_Preview", isLocked: !unlockedStar, mission: Mission(description: "Achieve 40 Points on Blind Sequence", goal: 40, type: .highScore)),
            AppIcon(iconName: "Crown_AppIcon", previewImage: "Crown_AppIcon_Preview", isLocked: !unlockedCrown, mission: Mission(description: "Achieve 50 Points on Blind Sequence", goal: 50, type: .highScore)),
            AppIcon(iconName: nil, previewImage: "ComingSoon_Preview", isLocked: true, mission: Mission(description: "More Icons & Missions Coming Soon!", goal: 100, type: .highScore)),
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Change App Icon")
                    .font(.title2.bold())

                Text("Click on a locked icon to see the mission to claim it.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(appIcons.indices, id: \.self) { index in
                        let icon = appIcons[index]
                        let isLast = index == appIcons.count - 1

                        AppIconGridItem(
                            icon: icon,
                            isComingSoon: isLast,
                            isUnlocking: unlockingIconIndex == index && isUnlocking,
                            isSelected: (selectedIcon == icon.iconName || (selectedIcon == nil && icon.iconName == nil))
                        ) {
                            if !icon.isLocked && !isLast {
                                changeAppIcon(to: icon.iconName)
                                selectedIcon = icon.iconName
                            } else if icon.isLocked, let mission = icon.mission {
                                let progress: Int
                                switch mission.type {
                                case .gamesPlayed: progress = totalGamesPlayed
                                case .highScore: progress = highScore
                                case .subscribed: progress = subscribed
                                }

                                if progress >= mission.goal {
                                    unlockingIconIndex = index
                                    isUnlocking = true

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        withAnimation {
                                            appIcons[index].isLocked = false
                                            isUnlocking = false
                                            unlockingIconIndex = nil

                                            switch icon.iconName {
                                            case "Medal_AppIcon": unlockedMedal = true
                                            case "Trophy_AppIcon": unlockedTrophy = true
                                            case "Crown_AppIcon": unlockedCrown = true
                                            case "Star_AppIcon": unlockedStar = true
                                            default: break
                                            }
                                        }
                                    }
                                } else {
                                    if showToast {
                                        withAnimation {
                                            showToast = false
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showToastWithMission(mission: mission, progress: progress)
                                        }
                                    } else {
                                        showToastWithMission(mission: mission, progress: progress)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.top, 15)
            .padding()
            .navigationTitle("Choose App Icon")

            // ✅ Actual Toast view (conditionally shown)
            if showToast {
                MissionToast(
                    isShown: $showToast,
                    title: "🔒 Mission to Unlock",
                    message: toastMessage,
                    icon: Image(systemName: "exclamationmark.circle"),
                    alignment: .bottom,
                    goal: toastGoal,
                    progress: toastProgress
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toastID)
                .padding(.bottom, 12)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastID) // Ensures all transitions animate
        .onAppear {
            initializeAppIcons()
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "CustomiseAppIcon",
                AnalyticsParameterScreenClass: "CustomiseAppIconView"
            ])
        }
    }

    private func changeAppIcon(to name: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
                print("Error setting alternate icon: \(error.localizedDescription)")
            } else {
                print("App icon changed to \(name ?? "primary")")
            }
        }
    }
    
    private func showToastWithMission(mission: Mission, progress: Int) {
        toastMessage = mission.description
        toastProgress = progress
        toastGoal = mission.goal
        toastID = UUID() // Forces transition in the toast view
        showToast = true

        // Cancel any previous dismiss
        toastDismissWorkItem?.cancel()

        // Schedule dismiss
        let newDismissWorkItem = DispatchWorkItem {
            withAnimation {
                showToast = false
            }
        }
        toastDismissWorkItem = newDismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: newDismissWorkItem)
    }
}

struct AppIconGridItem: View {
    let icon: AppIcon
    let isComingSoon: Bool
    let isUnlocking: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var animateUnlock: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(radius: 4)

                Image(icon.previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if isComingSoon {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image(systemName: "clock.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                } else if icon.isLocked {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if isUnlocking {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 28))
                            .scaleEffect(animateUnlock ? 1.4 : 1.0)
                            .opacity(animateUnlock ? 0.2 : 1)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1)) {
                                    animateUnlock.toggle()
                                }
                            }
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(isSelected ? 0.9 : 0), lineWidth: 3)
                    .shadow(color: isSelected ? Color.orange : Color.clear, radius: 6, x: 0, y: 0)
            )
            .onTapGesture {
                onTap()
            }
        }
    }
}
