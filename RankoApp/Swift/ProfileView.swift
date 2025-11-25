//
//  ProfileView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import FirebaseAnalytics
import FirebaseStorage
import AlgoliaSearchClient
import InstantSearchSwiftUI
import Foundation
import FirebaseAuth
import FirebaseDatabase
import PhotosUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject private var imageService: ProfileImageService
    @StateObject private var cache = FeaturedRankoCacheService.shared
    @StateObject private var user_data = UserInformation.shared
    @Namespace private var transition

    @State private var showEditProfile = false
    @State private var loadingProfileImage = false
    @State private var profileImage: UIImage?
    @State private var usedOfflineFeatured: Bool = false
    
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
    
    @State private var rowWidth: CGFloat = 0
    
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
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView {
                    VStack {
                        HStack {
                            ZStack(alignment: .bottomTrailing) {
                                ProfileIconView(diameter: CGFloat(90))
                                    .matchedTransitionSource(
                                        id: "editProfileButton", in: transition
                                    )
                                Button {
                                    showEditProfile = true
                                    print("Editing Profile...")
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .black, design: .default))
                                        .padding(.vertical, -2)
                                        .padding(.horizontal, -7)
                                }
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                .background(Circle().stroke(Color.white, lineWidth: 8))
                                .offset(x: 2, y: 2)
                                
                            }
                            .padding(.trailing, 25)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(user_data.username)
                                    .font(.custom("Nunito-Black", size: 20))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                HStack(spacing: 20) {
                                    VStack {
                                        Text("\(user_data.userStatsRankos)")
                                            .font(.custom("Nunito-SemiBold", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Rankos")
                                            .font(.custom("Nunito-SemiBold", size: 13))
                                            .foregroundColor(Color(hex: 0x514343))
                                    }
                                    .onTapGesture {
                                        showSearchRankos = true
                                    }
                                    VStack {
                                        Text("\(user_data.userStatsFollowers)")
                                            .font(.custom("Nunito-SemiBold", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Followers")
                                            .font(.custom("Nunito-SemiBold", size: 13))
                                            .foregroundColor(Color(hex: 0x514343))
                                    }
                                    .onTapGesture {
                                        showUserFollowers = true
                                    }
                                    VStack {
                                        Text("\(user_data.userStatsFollowing)")
                                            .font(.custom("Nunito-SemiBold", size: 14))
                                            .foregroundColor(Color(hex: 0x514343))
                                        Text("Following")
                                            .font(.custom("Nunito-SemiBold", size: 13))
                                            .foregroundColor(Color(hex: 0x514343))
                                    }
                                    .onTapGesture {
                                        showUserFollowing = true
                                    }
                                }
                            }
                            
                        }
                        .padding(.vertical)
                        
                        HStack {
                            if !user_data.userDescription.isEmpty {
                                Text(user_data.userDescription)
                                    .font(.custom("Nunito-Black", size: 11))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .multilineTextAlignment(.leading)
                            } else {
                                Text("✏️ Add a bio to display more personality to your profile...")
                                    .font(.custom("Nunito-SemiBold", size: 13))
                                    .foregroundColor(Color(hex: 0x514343))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.bottom, -20)
                        
                        // 2) your view snippet
                        if !user_data.userInterests.isEmpty {
                            let tags = user_data.userInterests
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                            
                            GeometryReader { geo in
                                // account for your outer horizontal padding (change if you tweak padding below)
                                let outerHorizontalPadding: CGFloat = 16
                                let available = geo.size.width - (outerHorizontalPadding * 2)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(tags, id: \.self) { tag in
                                            let icon = ProfileView.interestIconMapping[tag] ?? "tag.fill"
                                            
                                            Button(action: { print("\(tag) Category Clicked") }) {
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
                                            }
                                            .foregroundColor(Color(hex: 0xFFFFFF))
                                            .tint(Color(hex: 0xFFB654))
                                            .buttonStyle(.glassProminent)
                                            .mask(RoundedRectangle(cornerRadius: 30))
                                        }
                                    }
                                    // measure the natural width of the HStack (with paddings)
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear.preference(key: RowWidthKey.self, value: proxy.size.width)
                                        }
                                    )
                                    // if content < available, expand to available and center; else use content width and lead align
                                    .frame(
                                        width: max(available, rowWidth),
                                        alignment: rowWidth < available ? .center : .leading
                                    )
                                    .padding(.vertical, 30)
                                    .padding(.horizontal, outerHorizontalPadding)
                                }
                                .onPreferenceChange(RowWidthKey.self) { rowWidth = $0 }
                            }
                            .frame(height: 72) // or whatever fits your buttons’ height
                            .padding(.horizontal) // keeps parity with your original outer padding
                        }
                        
                        ZStack {
                            
                            HStack {
                                Button {
                                    showSearchRankos = true
                                    print("Searching Rankos...")
                                } label: {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 17, weight: .heavy))
                                        Text("Search Rankos")
                                            .font(.system(size: 14, weight: .heavy))
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                }
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFFFFFF)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                .matchedTransitionSource(
                                    id: "searchRankos", in: transition
                                )
                                .mask(RoundedRectangle(cornerRadius: 30))
                                Button {
                                    appIconCustomiserView = true
                                    print("Customising App...")
                                } label: {
                                    HStack {
                                        Image(systemName: "paintbrush.fill")
                                            .font(.system(size: 17, weight: .heavy))
                                        Text("Customise App")
                                            .font(.system(size: 14, weight: .heavy))
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                }
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                .matchedTransitionSource(
                                    id: "customiseApp", in: transition
                                )
                                .mask(RoundedRectangle(cornerRadius: 30))
                            }
                            
                            
                            
                            HStack {
                                Button {
                                    showSearchRankos = true
                                    print("Searching Rankos...")
                                } label: {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 17, weight: .heavy))
                                        Text("Search Rankos")
                                            .font(.system(size: 14, weight: .heavy))
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                }
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFFFFFF)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                Button {
                                    appIconCustomiserView = true
                                    print("Customising App...")
                                } label: {
                                    HStack {
                                        Image(systemName: "paintbrush.fill")
                                            .font(.system(size: 17, weight: .heavy))
                                        Text("Customise App")
                                            .font(.system(size: 14, weight: .heavy))
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                }
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                            }
                        }
                        .padding(.bottom, 12)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: 0x707070))
                            .frame(height: 2)
                            .padding(.horizontal, 25)
                            .opacity(0.20)
                        
                        HStack {
                            Text("⭐️ Featured Rankos")
                                .font(.custom("Nunito-Black", size: 22))
                                .foregroundStyle(Color(hex: 0x514343))
                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.leading, 25)
                        .padding(.bottom, 10)
                        
                        VStack(spacing: 13) {
                            let filledSlots = featuredLists.keys.sorted()
                            let emptySlots = (1...10).filter { !featuredLists.keys.contains($0) }
                            
                            // ✅ If loading or failed, show placeholders
                            if featuredLoading {
                                HStack {
                                    ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                                }
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: 0xFFFFFF))
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
                                                    .foregroundStyle(Color(hex: 0x514343))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(Color(hex: 0xFFFFFF))
                                        .buttonStyle(.glassProminent)
                                        .disabled(false)
                                        .shadow(color: Color(hex:0x000000).opacity(0.1), radius: 8, x: 0, y: -2)
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
                                                    DefaultListIndividualGallery(
                                                        listData: list,
                                                        type: "featured",
                                                        onUnpin: {
                                                            slotToUnpin = slot
                                                            showUnpinAlert = true
                                                        },
                                                        userID: user_data.userID
                                                    )
                                                    .contextMenu {
                                                        Button(action: {
                                                            slotToUnpin = slot
                                                            showUnpinAlert = true
                                                        }) {
                                                            Label("Unpin", systemImage: "pin.slash")
                                                        }
                                                        .foregroundColor(Color(hex: 0xFF9864))
                                                    }
                                                    .simultaneousGesture(
                                                        LongPressGesture(minimumDuration: 1.2).onEnded(({ _ in
                                                                slotToUnpin = slot
                                                                showUnpinAlert = true
                                                        }))
                                                    )
                                                } else {
                                                    TierListIndividualGallery(listData: list, type: "featured", onUnpin: {
                                                        slotToUnpin = slot
                                                        showUnpinAlert = true
                                                    })
                                                }
                                            }
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(Color(hex: 0xFFFFFF))
                                        .buttonStyle(.glassProminent)
                                        .shadow(color: Color(hex:0x000000).opacity(0.1), radius: 8, x: 0, y: -2)
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
                                                    .foregroundStyle(Color(hex: 0x514343))
                                                Spacer()
                                            }
                                            .frame(height: 52)
                                        }
                                        .foregroundColor(Color(hex: 0xFF9864))
                                        .tint(Color(hex: 0xFFFFFF))
                                        .buttonStyle(.glassProminent)
                                        .shadow(color: Color(hex:0x000000).opacity(0.1), radius: 8, x: 0, y: -2)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 70)
                        Spacer()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showUserFollowers) {
            SearchFollowersView()
        }
        .fullScreenCover(isPresented: $showUserFollowing) {
            SearchFollowingView()
        }
        .fullScreenCover(isPresented: $showSearchRankos) {
            SearchRankosView()
                .navigationTransition(
                    .zoom(sourceID: "searchRankos", in: transition)
                )
        }
        .fullScreenCover(isPresented: $showUserFinder) {
            SearchUsersView()
                .navigationTransition(
                    .zoom(sourceID: "userFinder", in: transition)
                )
        }
        .sheet(isPresented: $appIconCustomiserView) {
            AppPersonalisationView()
                .navigationTransition(
                    .zoom(sourceID: "customiseApp", in: transition)
                )
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
                    
                    cache.rebuildFromRemote(uid: user_data.userID) { fresh in
                        self.featuredLists = fresh
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedFeaturedList) { list in
            if list.type == "default" {
                DefaultListPersonal(
                  rankoID: list.id,
                  categoryName: list.categoryName,
                  categoryIcon: list.categoryIcon,
                  categoryColour: list.categoryColour,
                  onSave: { _ in
                      listViewID     = UUID()
                      isLoadingLists = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                          isLoadingLists = false
                          retryFeaturedLoading()
                          loadFollowStats()
                      }
                  },
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
            } else if list.type == "tier" {
                TierListPersonal(
                  rankoID: list.id,
                  onSave: { _ in
                      listViewID     = UUID()
                      isLoadingLists = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                          isLoadingLists = false
                          retryFeaturedLoading()
                          loadFollowStats()
                      }
                  },
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
        .fullScreenCover(isPresented: $showEditProfile) {
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
                        showEditProfile = false
                        return
                    }
                    loadingProfileImage = true
                    profileImage        = nil
                    showEditProfile     = false
                    uploadImageToFirebase(img)
                },
                onCancel: {
                    showEditProfile = false
                }
            )
            .navigationTransition(
                .zoom(sourceID: "editProfileButton", in: transition)
            )
            .interactiveDismissDisabled(true)
        }
        .refreshable {
            guard !user_data.userID.isEmpty else { return }
            featuredLoading = featuredLists.isEmpty
            cache.refreshIfChanged(uid: user_data.userID) { fresh in
                DispatchQueue.main.async {
                    if !fresh.isEmpty { self.featuredLists = fresh }
                    self.featuredLoading = false
                    self.featuredLoadFailed = fresh.isEmpty && self.featuredLists.isEmpty
                }
            }
            // you can still update follow stats, etc., below if you want
            loadFollowStats()
        }
        .onAppear {
            listViewID = UUID()

            // 1) serve from cache instantly (if any)
            if !user_data.userID.isEmpty {
                let cached = cache.loadCachedLists(uid: user_data.userID)
                if !cached.isEmpty {
                    featuredLists = cached
                    featuredLoading = false
                    usedOfflineFeatured = true
                }
            }

            // 2) do your normal stuff that doesn’t depend on featured
            if !isSimulator {
                loadNumberOfRankos()
                syncUserDataFromFirebase()
                isLoadingLists = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isLoadingLists = false }
                loadFollowStats()
            }

            // 3) now verify & refresh if changed (network aware)
            guard !user_data.userID.isEmpty else { return }
            featuredLoading = featuredLists.isEmpty // show skeletons only if nothing cached
            cache.refreshIfChanged(uid: user_data.userID) { fresh in
                // if changed, this will have rebuilt + returned fresh lists
                if !fresh.isEmpty {
                    featuredLists = fresh
                    featuredLoading = false
                    featuredLoadFailed = false
                } else {
                    // nothing changed and we already had cache
                    featuredLoading = false
                }
            }

            // rest of your tag animation + analytics...
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let tags = user_data.userInterests
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                Task {
                    for (index, tag) in tags.enumerated() {
                        try? await Task.sleep(for: .milliseconds(200 * index))
                        _ = withAnimation(.easeOut(duration: 0.4)) { animatedTags.insert(tag) }
                    }
                }
            }

            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "Profile",
                AnalyticsParameterScreenClass: "ProfileView"
            ])
        }
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
    
    private func retryFeaturedLoading() {
        featuredLoadFailed = false
        featuredLoading = true
        retryCount = 0

        guard !user_data.userID.isEmpty else {
            featuredLoading = false
            return
        }
        cache.rebuildFromRemote(uid: user_data.userID) { fresh in
            DispatchQueue.main.async {
                self.featuredLists = fresh
                self.featuredLoading = false
                self.featuredLoadFailed = fresh.isEmpty
            }
        }
    }
    
    private struct RowWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
    
    private let isSimulator: Bool = {
        var isSim = false
        #if targetEnvironment(simulator)
        isSim = true
        #endif
        return isSim
    }()
    
    
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
        
        userProfilePicture.observe(.value) { snapshot in
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
                if let slot = Int(child.key), let rankoID = child.value as? String {
                    group.enter()
                    fetchFeaturedList(slot: slot, rankoID: rankoID) {
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
    private func fetchFeaturedList(slot: Int, rankoID: String, completion: @escaping (RankoList?) -> Void) {
        let listRef = Database.database()
            .reference()
            .child("RankoData")
            .child(rankoID)

        listRef.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any],
                  let rl = parseListData(dict: dict, id: rankoID) else {
                completion(nil)
                return
            }
            completion(rl)
        }
    }
    
    func parseColour(_ any: Any?) -> Int {
        // numbers coming from Firebase (Int/Double)
        if let n = any as? NSNumber {
            return n.intValue
        }
        // strings: "16776960", "#FFCC00", "0xFFCC00", "FFCC00"
        if let s = any as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            // try decimal first
            if let dec = Int(trimmed) { return dec }
            // strip prefixes for hex
            var hex = trimmed.lowercased()
            if hex.hasPrefix("#") { hex.removeFirst() }
            if hex.hasPrefix("0x") { hex.removeFirst(2) }
            if let hx = Int(hex, radix: 16) { return hx }
        }
        // fallback
        return 0xFFFFFF
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        // tolerant int parser
        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let d = any as? Double   { return Int(d) }
            if let s = any as? String   { return Int(s) }
            return nil
        }

        // parse "0xRRGGBB", "#RRGGBB", "RRGGBB", decimal, NSNumber → UInt (24-bit)
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

        // ======== NEW SCHEMA PREFERRED ========
        if let details = dict["RankoDetails"] as? [String: Any] {
            let privacy = dict["RankoPrivacy"]   as? [String: Any]
            let cat     = dict["RankoCategory"]  as? [String: Any]
            let items   = dict["RankoItems"]     as? [String: Any] ?? [:]
            let dt      = dict["RankoDateTime"]  as? [String: Any]

            let listName    = (details["name"] as? String) ?? ""
            let description = (details["description"] as? String) ?? ""
            let type        = (details["type"] as? String) ?? "default"
            let userCreator = (details["user_id"] as? String) ?? ""

            let isPrivate   = (privacy?["private"] as? Bool) ?? false

            let catName     = (cat?["name"] as? String) ?? "Unknown"
            let catIcon     = (cat?["icon"] as? String) ?? "circle"
            let catColour   = parseColourUInt(cat?["colour"])

            let timeCreated = (dt?["created"] as? String) ?? ""
            let timeUpdated = (dt?["updated"] as? String) ?? timeCreated

            // items can be [String: Any] with inner dicts
            let rankoItems: [RankoItem] = items.compactMap { (keyID, raw) in
                guard let itemDict = raw as? [String: Any] else { return nil }
                let itemID   = (itemDict["ItemID"] as? String) ?? keyID
                guard
                    let itemName  = itemDict["ItemName"] as? String,
                    let itemDesc  = itemDict["ItemDescription"] as? String,
                    let itemImage = itemDict["ItemImage"] as? String,
                    let itemGIF    = itemDict["ItemGIF"] as? String,
                    let itemVideo    = itemDict["ItemVideo"] as? String,
                    let itemAudio    = itemDict["ItemAudio"] as? String
                else { return nil }
                let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
                let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
                let rec = RankoRecord(objectID: itemID, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                let plays = intFromAny(itemDict["PlayCount"]) ?? 0
                return RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            }.sorted { $0.rank < $1.rank }

            return RankoList(
                id:              id,
                listName:        listName,
                listDescription: description,
                type:            type,
                categoryName:    catName,
                categoryIcon:    catIcon,
                categoryColour:  catColour,
                isPrivate:       isPrivate ? "Private" : "Public",
                userCreator:     userCreator,
                timeCreated:     timeCreated,
                timeUpdated:     timeUpdated,
                items:           rankoItems
            )
        }

        // ======== LEGACY SCHEMA FALLBACK ========
        guard
            let listName    = dict["RankoName"]        as? String,
            let description = dict["RankoDescription"] as? String,
            let type        = dict["RankoType"]        as? String,
            let privacy     = dict["RankoPrivacy"]     as? Bool,
            let userCreator = dict["RankoUserID"]      as? String
        else { return nil }

        var timeCreated = ""
        var timeUpdated = ""
        if let dt = dict["RankoDateTime"] as? [String: Any] {
            timeCreated = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? ""
            timeUpdated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? timeCreated
        } else if let s = dict["RankoDateTime"] as? String {
            timeCreated = s
            timeUpdated = s
        }

        // Items
        let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
        var rankoItems: [RankoItem] = []

        for (keyID, itemDict) in itemsDict {
            let itemID = (itemDict["ItemID"] as? String) ?? keyID

            // If these media fields aren’t guaranteed in legacy data, default them to ""
            let itemGIF   = (itemDict["ItemGIF"]   as? String) ?? ""
            let itemVideo = (itemDict["ItemVideo"] as? String) ?? ""
            let itemAudio = (itemDict["ItemAudio"] as? String) ?? ""

            guard
                let itemName  = itemDict["ItemName"] as? String,
                let itemDesc  = itemDict["ItemDescription"] as? String,
                let itemImage = itemDict["ItemImage"] as? String
            else { continue } // <- don’t return; just skip this item
                                
            let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
            let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
            let plays = intFromAny(itemDict["PlayCount"]) ?? 0

            let rec = RankoRecord(
                objectID: itemID,
                ItemName: itemName,
                ItemDescription: itemDesc,
                ItemCategory: "",
                ItemImage: itemImage,
                ItemGIF: itemGIF,
                ItemVideo: itemVideo,
                ItemAudio: itemAudio
            )

            rankoItems.append(
                RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            )
        }

        rankoItems.sort { $0.rank < $1.rank }

        // Category (object or legacy string)
        var catName = "Unknown"
        var catIcon = "circle"
        var catColour = 0x446D7A
        if let cat = dict["RankoCategory"] as? [String: Any] {
            catName   = (cat["name"] as? String) ?? catName
            catIcon   = (cat["icon"] as? String) ?? catIcon
            catColour = {
                if let n = cat["colour"] as? NSNumber { return n.intValue }
                if let s = cat["colour"] as? String {
                    var hex = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let dec = Int(hex) { return dec }
                    if hex.hasPrefix("#")  { hex.removeFirst() }
                    if hex.hasPrefix("0x") { hex.removeFirst(2) }
                    return Int(hex, radix: 16) ?? 0x446D7A
                }
                return 0x446D7A
            }()
        } else if let catStr = dict["RankoCategory"] as? String {
            catName = catStr
        }

        return RankoList(
            id:              id,
            listName:        listName,
            listDescription: description,
            type:            type,
            categoryName:    catName,
            categoryIcon:    catIcon,
            categoryColour:  UInt(catColour & 0x00FF_FFFF),
            isPrivate:       privacy ? "Private" : "Public",
            userCreator:     userCreator,
            timeCreated:     timeCreated,
            timeUpdated:     timeUpdated,
            items:           rankoItems
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
        
        cache.rebuildFromRemote(uid: user_data.userID) { fresh in
            self.featuredLists = fresh
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
}

func cachedImageURL(uid: String, rankoID: String, idx: Int) -> URL {
    FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FeaturedCache")
        .appendingPathComponent(uid)
        .appendingPathComponent("\(rankoID)_img\(idx).jpg")
}

final class FeaturedRankoCacheService: ObservableObject {
    static let shared = FeaturedRankoCacheService()

    struct Index: Codable {
        var featuredHash: String
        var rankoHashes: [String:String]   // rankoID -> content hash (e.g., updated timestamp or sha)
        var lastBuiltAt: String            // yyyyMMddHHmmss
        var orderSlots: [Int:String]       // slot -> rankoID
    }
    
    private func rankoContentSignature(_ dict: [String: Any]) -> String {
        // Prefer an explicit updated timestamp if it exists (cheap check)
        let updated = ((dict["RankoDateTime"] as? [String:Any])?["updated"] as? String)
                    ?? ((dict["RankoDetails"]  as? [String:Any])?["time_updated"] as? String)
                    ?? ""

        // Build a deterministic digest of item order + images
        let itemsAny = dict["RankoItems"] as? [String: Any] ?? [:]

        // Convert to tuples (rank, image, id) and sort by rank asc
        var triples: [(Int, String, String)] = []
        for (key, raw) in itemsAny {
            guard let it = raw as? [String: Any] else { continue }
            let rank  = (it["ItemRank"] as? NSNumber)?.intValue
                     ?? (it["ItemRank"] as? Int)
                     ?? Int((it["ItemRank"] as? String) ?? "") ?? 0
            let img   = (it["ItemImage"] as? String) ?? ""
            let id    = (it["ItemID"] as? String) ?? key
            triples.append((rank, img, id))
        }
        triples.sort { $0.0 < $1.0 }

        // Keep whole list (or limit if you want): join into a stable string
        let core = triples.map { "\($0.0)|\($0.1)|\($0.2)" }.joined(separator: "||")

        // Combine with updated (so if server bumps a timestamp, we still change)
        let payload = updated.isEmpty ? core : (updated + "##" + core)
        return sha1(of: Data(payload.utf8))
    }

    private let fm = FileManager.default

    private func baseDir(for uid: String) -> URL {
        let d = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return d.appendingPathComponent("FeaturedCache").appendingPathComponent(uid)
    }

    private func write(_ data: Data, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func readData(_ url: URL) -> Data? {
        guard fm.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func sha1(of data: Data) -> String {
        // lightweight hash; you can swap to CryptoKit if you prefer
        var hash = 5381
        for b in data { hash = ((hash << 5) &+ hash) &+ Int(b) }
        return String(hash)
    }

    // MARK: Public API

    /// Load cached RankoLists (if present) without touching the network.
    func loadCachedLists(uid: String) -> [Int: RankoList] {
        let dir = baseDir(for: uid)
        let indexURL = dir.appendingPathComponent("index.json")
        guard let data = readData(indexURL),
              let idx = try? JSONDecoder().decode(Index.self, from: data) else {
            return [:]
        }

        var out: [Int: RankoList] = [:]
        for (slot, rankoID) in idx.orderSlots {
            let file = dir.appendingPathComponent("\(rankoID).json")
            guard let j = readData(file),
                  let dict = (try? JSONSerialization.jsonObject(with: j)) as? [String:Any],
                  let rl = parseListData(dict: dict, id: rankoID) else { continue }
            out[slot] = rl
        }
        return out
    }

    /// Build (or rebuild) the entire cache from Firebase. Deletes stale cache first.
    func rebuildFromRemote(uid: String, completion: @escaping ([Int: RankoList]) -> Void) {
        let userRef = Database.database().reference()
            .child("UserData").child(uid)
            .child("UserRankos").child("UserFeaturedRankos")

        userRef.observeSingleEvent(of: .value) { snap in
            guard snap.exists(), let children = snap.children.allObjects as? [DataSnapshot] else {
                // nothing pinned
                self.deleteAll(uid: uid)
                completion([:]); return
            }

            // slot -> rankoID
            var orderSlots: [Int:String] = [:]
            for c in children {
                if let slot = Int(c.key), let rankoID = c.value as? String { orderSlots[slot] = rankoID }
            }

            // serialize featured map to hash
            let featuredRawStringKeys: [String:String] = Dictionary(
                uniqueKeysWithValues: orderSlots.map { (String($0.key), $0.value) }
            )
            let featuredData = try? JSONSerialization.data(withJSONObject: featuredRawStringKeys, options: [.sortedKeys])
            let featuredHash = featuredData.map(self.sha1) ?? "0"

            // pull each ranko JSON
            let group = DispatchGroup()
            var slotLists: [Int: RankoList] = [:]
            var rankoHashes: [String:String] = [:]
            var rankoJSONForDisk: [String: Data] = [:]

            for (slot, rid) in orderSlots {
                group.enter()
                let ref = Database.database().reference().child("RankoData").child(rid)
                ref.observeSingleEvent(of: .value) { rsnap in
                    defer { group.leave() }
                    guard let dict = rsnap.value as? [String:Any] else { return }
                    // hash pref: use updated time if present; else full-JSON hash
                    let json = (try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])) ?? Data()
                    rankoJSONForDisk[rid] = json

                    let contentHash = self.rankoContentSignature(dict)   // ⬅️ key change
                    rankoHashes[rid] = contentHash

                    if let rl = self.parseListData(dict: dict, id: rid) { slotLists[slot] = rl }
                }
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                // purge + write
                self.deleteAll(uid: uid)
                let dir = self.baseDir(for: uid)
                do {
                    // featured_map.json
                    if let fd = featuredData {
                        try self.write(fd, to: dir.appendingPathComponent("featured_map.json"))
                    }

                    // per-ranko json
                    for (rid, data) in rankoJSONForDisk {
                        try self.write(data, to: dir.appendingPathComponent("\(rid).json"))
                    }
                    
                    let dir = self.baseDir(for: uid)
                    try? self.fm.createDirectory(at: dir, withIntermediateDirectories: true)

                    // download top-3 images for each ranko
                    let dlGroup = DispatchGroup()
                    for (_, rl) in slotLists {
                        let top3 = Array(rl.items.sorted { $0.rank < $1.rank }.prefix(3))
                        for (idx, item) in top3.enumerated() {
                            guard !item.record.ItemImage.isEmpty else { continue }
                            dlGroup.enter()
                            self.downloadImageIfNeeded(pathOrURL: item.record.ItemImage) { data in
                                defer { dlGroup.leave() }
                                guard let data else { return }
                                try? self.write(data, to: dir.appendingPathComponent("\(rl.id)_img\(idx+1).jpg"))
                            }
                        }
                    }

                    dlGroup.notify(queue: .global(qos: .userInitiated)) {
                        // write index.json
                        let idx = Index(
                            featuredHash: featuredHash,
                            rankoHashes: rankoHashes,
                            lastBuiltAt: Self.timestamp(),
                            orderSlots: orderSlots
                        )
                        if let idxData = try? JSONEncoder().encode(idx) {
                            try? self.write(idxData, to: dir.appendingPathComponent("index.json"))
                        }
                        DispatchQueue.main.async { completion(slotLists) }
                    }
                } catch {
                    print("❌ cache write error:", error.localizedDescription)
                    DispatchQueue.main.async { completion(slotLists) } // still return what we have
                }
            }
        }
    }

    /// Compare remote vs local hashes; if any mismatch → rebuild.
    func refreshIfChanged(uid: String, completion: @escaping ([Int: RankoList]) -> Void) {
        // read local index first
        let dir = baseDir(for: uid)
        let indexURL = dir.appendingPathComponent("index.json")
        let localIndex: Index? = {
            guard let d = readData(indexURL) else { return nil }
            return try? JSONDecoder().decode(Index.self, from: d)
        }()

        let userRef = Database.database().reference()
            .child("UserData").child(uid)
            .child("UserRankos").child("UserFeaturedRankos")

        userRef.observeSingleEvent(of: .value) { snap in
            // compute featuredHash remote
            var orderSlots: [Int:String] = [:]
            if let children = snap.children.allObjects as? [DataSnapshot] {
                for c in children {
                    if let slot = Int(c.key), let rankoID = c.value as? String { orderSlots[slot] = rankoID }
                }
            }
            let featuredRawStringKeys: [String:String] = Dictionary(
                uniqueKeysWithValues: orderSlots.map { (String($0.key), $0.value) }
            )
            let featuredData = try? JSONSerialization.data(withJSONObject: featuredRawStringKeys, options: [.sortedKeys])
            let remoteFeaturedHash = featuredData.map(self.sha1) ?? "0"
            
            let localFeaturedHash = localIndex?.featuredHash ?? "_none"

            // quick diff: if featured set changed → rebuild
            if remoteFeaturedHash != localFeaturedHash {
                self.rebuildFromRemote(uid: uid, completion: completion)
                return
            }

            // same set: check each ranko's "updated" or content hash
            let group = DispatchGroup()
            var mismatch = false

            for (_, rid) in orderSlots {
                group.enter()
                let ref = Database.database().reference().child("RankoData").child(rid)
                ref.observeSingleEvent(of: .value) { rsnap in
                    defer { group.leave() }
                    guard let dict = rsnap.value as? [String:Any] else { mismatch = true; return }
                    let remoteHash = self.rankoContentSignature(dict)  // ⬅️ key change
                    let localHash  = localIndex?.rankoHashes[rid] ?? "_none"
                    if remoteHash != localHash { mismatch = true }
                }
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                if mismatch {
                    self.rebuildFromRemote(uid: uid, completion: completion)
                } else {
                    // no change → just serve cache
                    let lists = self.loadCachedLists(uid: uid)
                    DispatchQueue.main.async { completion(lists) }
                }
            }
        }
    }

    func deleteAll(uid: String) {
        let dir = baseDir(for: uid)
        if fm.fileExists(atPath: dir.path) {
            try? fm.removeItem(at: dir)
        }
    }

    private func downloadImageIfNeeded(pathOrURL: String, completion: @escaping (Data?) -> Void) {
        if pathOrURL.hasPrefix("http") {
            guard let url = URL(string: pathOrURL) else { completion(nil); return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                completion(data)
            }.resume()
        } else {
            let ref = Storage.storage().reference(withPath: pathOrURL)
            ref.getData(maxSize: Int64(4 * 1024 * 1024)) { data, _ in
                completion(data)
            }
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMddHHmmss"
        return f.string(from: Date())
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        // tolerant int parser
        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let d = any as? Double   { return Int(d) }
            if let s = any as? String   { return Int(s) }
            return nil
        }

        // parse "0xRRGGBB", "#RRGGBB", "RRGGBB", decimal, NSNumber → UInt (24-bit)
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

        // ======== NEW SCHEMA PREFERRED ========
        if let details = dict["RankoDetails"] as? [String: Any] {
            let privacy = dict["RankoPrivacy"]   as? [String: Any]
            let cat     = dict["RankoCategory"]  as? [String: Any]
            let items   = dict["RankoItems"]     as? [String: Any] ?? [:]
            let dt      = dict["RankoDateTime"]  as? [String: Any]

            let listName    = (details["name"] as? String) ?? ""
            let description = (details["description"] as? String) ?? ""
            let type        = (details["type"] as? String) ?? "default"
            let userCreator = (details["user_id"] as? String) ?? ""

            let isPrivate   = (privacy?["private"] as? Bool) ?? false

            let catName     = (cat?["name"] as? String) ?? "Unknown"
            let catIcon     = (cat?["icon"] as? String) ?? "circle"
            let catColour   = parseColourUInt(cat?["colour"])

            let timeCreated = (dt?["created"] as? String) ?? ""
            let timeUpdated = (dt?["updated"] as? String) ?? timeCreated

            // items can be [String: Any] with inner dicts
            let rankoItems: [RankoItem] = items.compactMap { (keyID, raw) in
                guard let itemDict = raw as? [String: Any] else { return nil }
                let itemID   = (itemDict["ItemID"] as? String) ?? keyID
                guard
                    let itemName  = itemDict["ItemName"] as? String,
                    let itemDesc  = itemDict["ItemDescription"] as? String,
                    let itemImage = itemDict["ItemImage"] as? String,
                    let itemGIF    = itemDict["ItemGIF"] as? String,
                    let itemVideo    = itemDict["ItemVideo"] as? String,
                    let itemAudio    = itemDict["ItemAudio"] as? String
                else { return nil }
                let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
                let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
                let rec = RankoRecord(objectID: itemID, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                let plays = intFromAny(itemDict["PlayCount"]) ?? 0
                return RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            }.sorted { $0.rank < $1.rank }

            return RankoList(
                id:              id,
                listName:        listName,
                listDescription: description,
                type:            type,
                categoryName:    catName,
                categoryIcon:    catIcon,
                categoryColour:  catColour,
                isPrivate:       isPrivate ? "Private" : "Public",
                userCreator:     userCreator,
                timeCreated:     timeCreated,
                timeUpdated:     timeUpdated,
                items:           rankoItems
            )
        }

        // ======== LEGACY SCHEMA FALLBACK ========
        guard
            let listName    = dict["RankoName"]        as? String,
            let description = dict["RankoDescription"] as? String,
            let type        = dict["RankoType"]        as? String,
            let privacy     = dict["RankoPrivacy"]     as? Bool,
            let userCreator = dict["RankoUserID"]      as? String
        else { return nil }

        var timeCreated = ""
        var timeUpdated = ""
        if let dt = dict["RankoDateTime"] as? [String: Any] {
            timeCreated = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? ""
            timeUpdated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? timeCreated
        } else if let s = dict["RankoDateTime"] as? String {
            timeCreated = s
            timeUpdated = s
        }

        // Items
        let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
        var rankoItems: [RankoItem] = []

        for (keyID, itemDict) in itemsDict {
            let itemID = (itemDict["ItemID"] as? String) ?? keyID

            // If these media fields aren’t guaranteed in legacy data, default them to ""
            let itemGIF   = (itemDict["ItemGIF"]   as? String) ?? ""
            let itemVideo = (itemDict["ItemVideo"] as? String) ?? ""
            let itemAudio = (itemDict["ItemAudio"] as? String) ?? ""

            guard
                let itemName  = itemDict["ItemName"] as? String,
                let itemDesc  = itemDict["ItemDescription"] as? String,
                let itemImage = itemDict["ItemImage"] as? String
            else { continue } // <- don’t return; just skip this item
                                
            let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
            let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
            let plays = intFromAny(itemDict["PlayCount"]) ?? 0

            let rec = RankoRecord(
                objectID: itemID,
                ItemName: itemName,
                ItemDescription: itemDesc,
                ItemCategory: "",
                ItemImage: itemImage,
                ItemGIF: itemGIF,
                ItemVideo: itemVideo,
                ItemAudio: itemAudio
            )

            rankoItems.append(
                RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            )
        }

        rankoItems.sort { $0.rank < $1.rank }

        // Category (object or legacy string)
        var catName = "Unknown"
        var catIcon = "circle"
        var catColour = 0x446D7A
        if let cat = dict["RankoCategory"] as? [String: Any] {
            catName   = (cat["name"] as? String) ?? catName
            catIcon   = (cat["icon"] as? String) ?? catIcon
            catColour = {
                if let n = cat["colour"] as? NSNumber { return n.intValue }
                if let s = cat["colour"] as? String {
                    var hex = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let dec = Int(hex) { return dec }
                    if hex.hasPrefix("#")  { hex.removeFirst() }
                    if hex.hasPrefix("0x") { hex.removeFirst(2) }
                    return Int(hex, radix: 16) ?? 0x446D7A
                }
                return 0x446D7A
            }()
        } else if let catStr = dict["RankoCategory"] as? String {
            catName = catStr
        }

        return RankoList(
            id:              id,
            listName:        listName,
            listDescription: description,
            type:            type,
            categoryName:    catName,
            categoryIcon:    catIcon,
            categoryColour:  UInt(catColour & 0x00FF_FFFF),
            isPrivate:       privacy ? "Private" : "Public",
            userCreator:     userCreator,
            timeCreated:     timeCreated,
            timeUpdated:     timeUpdated,
            items:           rankoItems
        )
    }
}

struct OfflineRankoImage: View {
    let uid: String
    let rankoID: String
    /// 1-based position by rank (1 = top item, 2 = second, 3 = third)
    let topIndex: Int
    /// The original remote string (URL or storage path) to fall back to when online
    let remote: String

    var body: some View {
        if let local = localURL(),
           FileManager.default.fileExists(atPath: local.path),
           let img = UIImage(contentsOfFile: local.path) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            // Fallback to your existing remote loader. Examples:
            // AsyncImage(url: URL(string: remote)) { phase in ... }
            // or Kingfisher/SDWebImage component you already use:
            AsyncImage(url: URL(string: remote)) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.15)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.gray.opacity(0.25)
                @unknown default:
                    Color.gray.opacity(0.25)
                }
            }
        }
    }

    private func localURL() -> URL? {
        guard topIndex >= 1 && topIndex <= 3 else { return nil }
        return cachedImageURL(uid: uid, rankoID: rankoID, idx: topIndex)
    }
}

struct SearchRankosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    @FocusState private var searchFocused: Bool

    // Data
    @State private var allLists: [RankoList] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Query
    @State private var searchField: String = ""
    @State private var rankoQuery: String = ""

    // Filters / Sort / Group
    @State private var showFilters = false
    @State private var sortMode: SortMode = .dateUpdated
    @State private var groupMode: GroupMode = .none
    @State private var selectedTypes = Set<String>()        // e.g. ["default", "group"/"tier"]
    @State private var selectedCategories = Set<String>()   // category names

    // External selections
    @State private var selectedList: RankoList?

    // UserSort model
    @State private var userSort = UserSortModel()

    // MARK: - Derived

    private var allTypes: [String] {
        let set = Set(allLists.map { $0.type.lowercased() })
        return Array(set).sorted()
    }

    private var allCategories: [CategoryMeta] {
        // Use live RankoList for completeness; fall back to categoryOrder when needed
        let metas = Dictionary(grouping: allLists, by: { $0.categoryName })
            .map { (name, lists) -> CategoryMeta in
                // pick first as source of icon/colour
                let first = lists.first!
                return CategoryMeta(
                    name: name,
                    icon: first.categoryIcon,
                    colour: first.categoryColour
                )
            }
        // Merge known order from userSort.categoryOrder (optional nicety)
        let orderNames = userSort.categoryOrder.map { $0.name }
        return metas.sorted {
            let i0 = orderNames.firstIndex(of: $0.name) ?? .max
            let i1 = orderNames.firstIndex(of: $1.name) ?? .max
            return (i0, $0.name) < (i1, $1.name)
        }
    }

    private var filteredBase: [RankoList] {
        allLists.filter { list in
            // text query
            (rankoQuery.isEmpty || list.listName.range(of: rankoQuery, options: .caseInsensitive) != nil)
            // type filter
            && (selectedTypes.isEmpty || selectedTypes.contains(list.type.lowercased()))
            // category filter
            && (selectedCategories.isEmpty || selectedCategories.contains(list.categoryName))
        }
    }

    private var displayed: [SectionModel] {
        // 1) sort
        let sorted: [RankoList]
        switch sortMode {
        case .custom:
            sorted = sortByCustom(filteredBase)
        case .alphabetical:
            sorted = filteredBase.sorted { $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending }
        case .category:
            // stable: category name, then name
            sorted = filteredBase.sorted {
                if $0.categoryName != $1.categoryName { return $0.categoryName < $1.categoryName }
                return $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending
            }
        case .dateCreated:
            sorted = filteredBase.sorted { (Int($0.timeCreated) ?? 0) > (Int($1.timeCreated) ?? 0) }
        case .dateUpdated:
            sorted = filteredBase.sorted { (Int($0.timeUpdated) ?? 0) > (Int($1.timeUpdated) ?? 0) }
        }

        // 2) group
        switch groupMode {
        case .none:
            return [SectionModel(
                title: "\(sorted.count) results",
                titleIcon: nil,
                titleColor: Color(hex: 0x514343),
                rows: sorted
            )]
        case .type:
            let buckets = Dictionary(grouping: sorted, by: { $0.type.lowercased() })
            let order = ["default", "tier"] // nice order; "group" == tier lists in your data
            return buckets
                .sorted { (l, r) in
                    let i0 = order.firstIndex(of: l.key) ?? .max
                    let i1 = order.firstIndex(of: r.key) ?? .max
                    return (i0, l.key) < (i1, r.key)
                }
                .map { (key, rows) in
                    SectionModel(
                        title: key.capitalized.replacingOccurrences(of: "Group", with: "Tier"),
                        titleIcon: "square.stack.3d.down.right", // neutral icon
                        titleColor: Color(hex: 0x514343),
                        rows: rows
                    )
                }
        case .category:
            let buckets = Dictionary(grouping: sorted, by: { $0.categoryName })
            // prefer your stored order if available
            let orderNames = userSort.categoryOrder.map { $0.name }
            return buckets
                .map { (name, rows) -> (CategoryMeta, [RankoList]) in
                    // pick meta: from userSort if present else from a row
                    if let meta = userSort.categoryOrder.first(where: { $0.name == name }) {
                        return (meta, rows)
                    } else {
                        let any = rows.first!
                        return (CategoryMeta(name: name, icon: any.categoryIcon, colour: any.categoryColour), rows)
                    }
                }
                .sorted { lhs, rhs in
                    let i0 = orderNames.firstIndex(of: lhs.0.name) ?? .max
                    let i1 = orderNames.firstIndex(of: rhs.0.name) ?? .max
                    return (i0, lhs.0.name) < (i1, rhs.0.name)
                }
                .map { (meta, rows) in
                    SectionModel(
                        title: meta.name,
                        titleIcon: meta.icon,
                        titleColor: Color(hex: meta.colour),
                        rows: rows
                    )
                }
        }
    }

    var body: some View {
        TabView {
            // Playlists tab
            Tab("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                NavigationStack {
                    FilterSortGroupSheet(
                        sortMode: $sortMode,
                        groupMode: $groupMode,
                        allTypes: allTypes,
                        allCategories: allCategories,
                        selectedTypes: $selectedTypes,
                        selectedCategories: $selectedCategories
                    )
                    .navigationTitle("Filter")
                }
            }

            // Search tab
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    ZStack {
                        VStack {
                            ScrollView {
                                VStack(spacing: 0) {
                                    VStack(spacing: 0) {
                                        
                                        if let error = errorMessage {
                                            Text(error)
                                                .foregroundColor(.red)
                                                .padding()
                                        }
                                        
                                        // Sections
                                        LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                                            ForEach(displayed) { section in
                                                Section {
                                                    VStack(spacing: 8) {
                                                        ForEach(section.rows) { list in
                                                            Button {
                                                                selectedList = list
                                                            } label: {
                                                                RankoMiniView(listData: list, type: "", onUnpin: {})
                                                            }
                                                            .buttonStyle(.glass)
                                                            .padding(.horizontal, 15)
                                                        }
                                                    }
                                                    .padding(.bottom, 6)
                                                } header: {
                                                    HStack(spacing: 8) {
                                                        if let icon = section.titleIcon {
                                                            Image(systemName: icon)
                                                        }
                                                        Text(section.title)
                                                            .font(.custom("Nunito-Black", size: 16))
                                                    }
                                                    .foregroundColor(section.titleColor)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 15)
                                                    .padding(.vertical, 8)
                                                    .background(Color(.systemBackground).opacity(0.95))
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }

                        if isLoading {
                            VStack(spacing: 10) {
                                ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                                Text("Loading Rankos…")
                                    .font(.custom("Nunito-Black", size: 16))
                                    .foregroundColor(Color(hex: 0xA2A2A1))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                            .background(Color(.systemBackground).opacity(0.6).ignoresSafeArea())
                        }
                    }
                    .searchable(text: $searchField, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Rankos")
                    .searchFocused($searchFocused)
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: searchField) { _, newVal in
                        rankoQuery = newVal
                    }
                    .navigationTitle("Search Rankos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarRole(.navigationStack)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .black))
                            }
                            .tint(Color(hex: 0x514343))
                        }
                        ToolbarItem(placement: .principal) {
                            Text("Search Rankos")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0x514343))
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    .sheet(isPresented: $showFilters) {
                        FilterSortGroupSheet(
                            sortMode: $sortMode,
                            groupMode: $groupMode,
                            allTypes: allTypes,
                            allCategories: allCategories,
                            selectedTypes: $selectedTypes,
                            selectedCategories: $selectedCategories
                        )
                        .presentationDetents([.large])
                    }
                    .fullScreenCover(item: $selectedList) { list in
                        if list.type == "default" {
                            DefaultListPersonal(
                                rankoID: list.id,
                                categoryName: list.categoryName,
                                categoryIcon: list.categoryIcon,
                                categoryColour: list.categoryColour,
                                onSave: { _ in dismiss() },
                                onDelete: { dismiss() }
                            )
                        } else {
                            TierListPersonal(
                                rankoID: list.id,
                                onSave: { _ in dismiss() },
                                onDelete: { dismiss() }
                            )
                        }
                    }
                    .onAppear {
                        if !isSimulator {
                            loadOptimizedData()
                            loadUserSortModel() // ← pulls Custom/Category/Date/Type order
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            searchFocused = true
                        }
                    }
                }
            }
        }
    }
    
    private var headerBar: some View {
        VStack(spacing: 8) {
            // Active filters summary chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        print("Found \(filteredBase.count) Results")
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(filteredBase.count) Results")
                        }
                        .font(.custom("Nunito-Black", size: 12))
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0x514343))
                    
                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                        }
                        .font(.custom("Nunito-Black", size: 12))
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0x514343))
                    
                    if !selectedTypes.isEmpty || !selectedCategories.isEmpty || !rankoQuery.isEmpty {
                        Button {
                            rankoQuery = ""; searchField = ""
                            selectedTypes.removeAll()
                            selectedCategories.removeAll()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear Filters")
                            }
                            .font(.custom("Nunito-Black", size: 12))
                        }
                        .buttonStyle(.glass)
                        .tint(Color(hex: 0x514343))
                        if !rankoQuery.isEmpty {
                            chip(text: "“\(rankoQuery)”") { rankoQuery = ""; searchField = "" }
                        }
                        ForEach(Array(selectedTypes), id: \.self) { t in
                            chip(text: "Type: \(t.capitalized)") { selectedTypes.remove(t) }
                        }
                        ForEach(Array(selectedCategories), id: \.self) { c in
                            chip(text: "Category: \(c)") { selectedCategories.remove(c) }
                        }
                    }
                }
                .padding(15)
            }
        }
    }

    private func chip(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.custom("Nunito-Black", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F5F5)))
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(hex: 0x514343))
    }

    // MARK: - Sorting helpers

    private func sortByCustom(_ input: [RankoList]) -> [RankoList] {
        // build lookup for fast ID -> RankoList
        let dict = Dictionary(uniqueKeysWithValues: input.map { ($0.id, $0) })

        var result: [RankoList] = []
        for node in userSort.customTree {
            switch node {
            case .item(let id):
                if let r = dict[id] { result.append(r) }
            case .folder(_, let ids):
                for id in ids {
                    if let r = dict[id] { result.append(r) }
                }
            }
        }
        // append any missing ones (not in custom tree) at the end (stable by name)
        let seen = Set(result.map { $0.id })
        let missing = input.filter { !seen.contains($0.id) }
            .sorted { $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending }
        return result + missing
    }

    // MARK: - Data loads (existing)

    private func loadOptimizedData() {
        isLoading = true
        errorMessage = nil

        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")

        var query = Query("").set(\.hitsPerPage, to: 1000)
        query.filters = "RankoUserID:\(user_data.userID) AND RankoStatus:active"

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let objectIDs = response.hits.map { $0.objectID.rawValue }
                fetchMinimalDataFromFirebase(using: objectIDs)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ Failed to fetch from Algolia: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchMinimalDataFromFirebase(using objectIDs: [String]) {
        let rankoDataRef = Database.database().reference().child("RankoData")
        let dispatchGroup = DispatchGroup()
        var fetchedLists: [RankoList] = []

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

        for objectID in objectIDs {
            dispatchGroup.enter()
            rankoDataRef.child(objectID).observeSingleEvent(of: .value) { snap in
                defer { dispatchGroup.leave() }
                guard let root = snap.value as? [String: Any] else { return }

                if let details = root["RankoDetails"] as? [String: Any] {
                    let privacy = root["RankoPrivacy"]  as? [String: Any]
                    let cat     = root["RankoCategory"] as? [String: Any]
                    let dt      = root["RankoDateTime"] as? [String: Any]

                    let name        = (details["name"] as? String) ?? "(untitled)"
                    let description = (details["description"] as? String) ?? ""
                    let type        = (details["type"] as? String) ?? "default"
                    let userID      = (details["user_id"] as? String) ?? ""
                    let isPrivate   = (privacy?["private"] as? Bool) ?? false

                    let catName   = (cat?["name"] as? String) ?? "Unknown"
                    let catIcon   = (cat?["icon"] as? String) ?? "circle"
                    let catColour = parseColourUInt(cat?["colour"])

                    let created = (dt?["created"] as? String) ?? "19700101000000"
                    let updated = (dt?["updated"] as? String) ?? created

                    let rankoList = RankoList(
                        id: objectID,
                        listName: name,
                        listDescription: description,
                        type: type,
                        categoryName: catName,
                        categoryIcon: catIcon,
                        categoryColour: catColour,
                        isPrivate: isPrivate ? "Private" : "Public",
                        userCreator: userID,
                        timeCreated: created,
                        timeUpdated: updated,
                        items: []
                    )
                    DispatchQueue.main.async { fetchedLists.append(rankoList) }
                    return
                }

                // legacy fallback
                let name        = root["RankoName"] as? String ?? "(untitled)"
                let description = root["RankoDescription"] as? String ?? ""
                let type        = root["RankoType"] as? String ?? "default"
                let isPriv: Bool = {
                    if let b = root["RankoPrivacy"] as? Bool { return b }
                    if let s = root["RankoPrivacy"] as? String { return s.lowercased() == "private" }
                    return false
                }()
                let userID = root["RankoUserID"] as? String ?? ""

                var created = "19700101000000"
                var updated = "19700101000000"
                if let dt = root["RankoDateTime"] as? [String: Any] {
                    created = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? created
                    updated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? created
                } else if let s = root["RankoDateTime"] as? String {
                    created = s; updated = s
                }

                var catName = "Unknown"
                var catIcon = "circle"
                var catColour: UInt = 0x446D7A
                if let cat = root["RankoCategory"] as? [String: Any] {
                    catName   = (cat["name"] as? String) ?? catName
                    catIcon   = (cat["icon"] as? String) ?? catIcon
                    catColour = parseColourUInt(cat["colour"])
                } else if let catStr = root["RankoCategory"] as? String {
                    catName = catStr
                }

                let rankoList = RankoList(
                    id: objectID,
                    listName: name,
                    listDescription: description,
                    type: type,
                    categoryName: catName,
                    categoryIcon: catIcon,
                    categoryColour: catColour,
                    isPrivate: isPriv ? "Private" : "Public",
                    userCreator: userID,
                    timeCreated: created,
                    timeUpdated: updated,
                    items: []
                )
                DispatchQueue.main.async { fetchedLists.append(rankoList) }
            }
        }

        dispatchGroup.notify(queue: .main) {
            // default load order: most recently updated
            self.allLists = fetchedLists.sorted { (Int($0.timeUpdated) ?? 0) > (Int($1.timeUpdated) ?? 0) }
            self.isLoading = false
        }
    }

    // MARK: - Load UserSortRankos

    private func loadUserSortModel() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(user_data.userID)
            .child("UserSortRankos")

        ref.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any] else { return }
            var model = UserSortModel()

            // Custom
            if let custom = dict["Custom"] as? [String: Any] {
                let keys = custom.keys.sorted() // 000001..., preserves intended order
                for k in keys {
                    if let itemID = custom[k] as? String {
                        model.customTree.append(.item(id: itemID))
                    } else if let folder = custom[k] as? [String: Any] {
                        let name = (folder["name"] as? String) ?? "Folder"
                        let ids  = (folder["rankos"] as? [String]) ?? []
                        model.customTree.append(.folder(name: name, ids: ids))
                    }
                }
            }

            // Alphabetical
            if let alpha = dict["Alphabetical"] as? [String: String] {
                model.alphabetical = alpha
            }

            // Category
            if let category = dict["Category"] as? [String: Any] {
                if let buckets = category["CategoryData"] as? [String: [String]] {
                    model.categoryBuckets = buckets
                }
                if let order = category["CategorySort"] as? [[String: Any]] {
                    model.categoryOrder = order.map {
                        CategoryMeta(
                            name: ($0["name"] as? String) ?? "Unknown",
                            icon: ($0["icon"] as? String) ?? "circle",
                            colour: parseUInt(($0["colour"]))
                        )
                    }
                }
            }

            // Dates
            if let created = dict["DateTimeCreated"] as? [String: Any] {
                model.createdKeys = created.keys.sorted() // "timestamp - id"
            }
            if let updated = dict["DateTimeUpdated"] as? [String: Any] {
                model.updatedKeys = updated.keys.sorted()
            }

            // Types
            if let types = dict["Type"] as? [String: [String]] {
                model.typeBuckets = types
            }

            self.userSort = model
        }
    }

    private func parseUInt(_ any: Any?) -> UInt {
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
}

struct FacetCategory: Identifiable {
    let id = UUID()
    let facetName: String
    let facetCount: Int
}

private enum SortMode: String, CaseIterable, Identifiable {
    case custom = "Custom"
    case alphabetical = "Alphabetical"
    case category = "Category"
    case dateCreated = "DateTimeCreated"
    case dateUpdated = "DateTimeUpdated"
    var id: String { rawValue }
}

private enum GroupMode: String, CaseIterable, Identifiable {
    case none = "None"
    case type = "Type"
    case category = "Category"
    var id: String { rawValue }
}

// MARK: - User sort model parsed from /UserData/{uid}/UserSortRankos

private struct CategoryMeta: Hashable {
    let name: String
    let icon: String
    let colour: UInt
}

private enum CustomNode: Hashable {
    case folder(name: String, ids: [String])
    case item(id: String)
}

private struct UserSortModel {
    // Custom
    var customTree: [CustomNode] = []
    // Alphabetical: map "LABEL - UUID" -> uuid
    var alphabetical: [String: String] = [:]
    // Category buckets + display order
    var categoryBuckets: [String: [String]] = [:]              // name -> [rankoIDs]
    var categoryOrder: [CategoryMeta] = []                     // sorted order for headers
    // Created/Updated keys "timestamp - UUID"
    var createdKeys: [String] = []
    var updatedKeys: [String] = []
    // Type buckets
    var typeBuckets: [String: [String]] = [:]                  // e.g. "default", "tier"
}

// MARK: - Section model for grouped display

private struct SectionModel: Identifiable {
    let id = UUID()
    let title: String
    let titleIcon: String?
    let titleColor: Color
    let rows: [RankoList]
}

// MARK: - View

struct SearchRankosView2: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    @FocusState private var searchFocused: Bool

    // Data
    @State private var allLists: [RankoList] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Query
    @State private var searchField: String = ""
    @State private var rankoQuery: String = ""

    // Filters / Sort / Group
    @State private var showFilters = false
    @State private var sortMode: SortMode = .dateUpdated
    @State private var groupMode: GroupMode = .none
    @State private var selectedTypes = Set<String>()        // e.g. ["default", "group"/"tier"]
    @State private var selectedCategories = Set<String>()   // category names

    // External selections
    @State private var selectedList: RankoList?

    // UserSort model
    @State private var userSort = UserSortModel()

    // MARK: - Derived

    private var allTypes: [String] {
        let set = Set(allLists.map { $0.type.lowercased() })
        return Array(set).sorted()
    }

    private var allCategories: [CategoryMeta] {
        // Use live RankoList for completeness; fall back to categoryOrder when needed
        let metas = Dictionary(grouping: allLists, by: { $0.categoryName })
            .map { (name, lists) -> CategoryMeta in
                // pick first as source of icon/colour
                let first = lists.first!
                return CategoryMeta(
                    name: name,
                    icon: first.categoryIcon,
                    colour: first.categoryColour
                )
            }
        // Merge known order from userSort.categoryOrder (optional nicety)
        let orderNames = userSort.categoryOrder.map { $0.name }
        return metas.sorted {
            let i0 = orderNames.firstIndex(of: $0.name) ?? .max
            let i1 = orderNames.firstIndex(of: $1.name) ?? .max
            return (i0, $0.name) < (i1, $1.name)
        }
    }

    private var filteredBase: [RankoList] {
        allLists.filter { list in
            // text query
            (rankoQuery.isEmpty || list.listName.range(of: rankoQuery, options: .caseInsensitive) != nil)
            // type filter
            && (selectedTypes.isEmpty || selectedTypes.contains(list.type.lowercased()))
            // category filter
            && (selectedCategories.isEmpty || selectedCategories.contains(list.categoryName))
        }
    }

    private var displayed: [SectionModel] {
        // 1) sort
        let sorted: [RankoList]
        switch sortMode {
        case .custom:
            sorted = sortByCustom(filteredBase)
        case .alphabetical:
            sorted = filteredBase.sorted { $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending }
        case .category:
            // stable: category name, then name
            sorted = filteredBase.sorted {
                if $0.categoryName != $1.categoryName { return $0.categoryName < $1.categoryName }
                return $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending
            }
        case .dateCreated:
            sorted = filteredBase.sorted { (Int($0.timeCreated) ?? 0) > (Int($1.timeCreated) ?? 0) }
        case .dateUpdated:
            sorted = filteredBase.sorted { (Int($0.timeUpdated) ?? 0) > (Int($1.timeUpdated) ?? 0) }
        }

        // 2) group
        switch groupMode {
        case .none:
            return [SectionModel(
                title: "\(sorted.count) results",
                titleIcon: nil,
                titleColor: Color(hex: 0x514343),
                rows: sorted
            )]
        case .type:
            let buckets = Dictionary(grouping: sorted, by: { $0.type.lowercased() })
            let order = ["default", "tier"] // nice order; "group" == tier lists in your data
            return buckets
                .sorted { (l, r) in
                    let i0 = order.firstIndex(of: l.key) ?? .max
                    let i1 = order.firstIndex(of: r.key) ?? .max
                    return (i0, l.key) < (i1, r.key)
                }
                .map { (key, rows) in
                    SectionModel(
                        title: key.capitalized.replacingOccurrences(of: "Group", with: "Tier"),
                        titleIcon: "square.stack.3d.down.right", // neutral icon
                        titleColor: Color(hex: 0x514343),
                        rows: rows
                    )
                }
        case .category:
            let buckets = Dictionary(grouping: sorted, by: { $0.categoryName })
            // prefer your stored order if available
            let orderNames = userSort.categoryOrder.map { $0.name }
            return buckets
                .map { (name, rows) -> (CategoryMeta, [RankoList]) in
                    // pick meta: from userSort if present else from a row
                    if let meta = userSort.categoryOrder.first(where: { $0.name == name }) {
                        return (meta, rows)
                    } else {
                        let any = rows.first!
                        return (CategoryMeta(name: name, icon: any.categoryIcon, colour: any.categoryColour), rows)
                    }
                }
                .sorted { lhs, rhs in
                    let i0 = orderNames.firstIndex(of: lhs.0.name) ?? .max
                    let i1 = orderNames.firstIndex(of: rhs.0.name) ?? .max
                    return (i0, lhs.0.name) < (i1, rhs.0.name)
                }
                .map { (meta, rows) in
                    SectionModel(
                        title: meta.name,
                        titleIcon: meta.icon,
                        titleColor: Color(hex: meta.colour),
                        rows: rows
                    )
                }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 0) {
                                
                                if let error = errorMessage {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                                
                                // Sections
                                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                                    ForEach(displayed) { section in
                                        Section {
                                            VStack(spacing: 8) {
                                                ForEach(section.rows) { list in
                                                    Button {
                                                        selectedList = list
                                                    } label: {
                                                        RankoMiniView(listData: list, type: "", onUnpin: {})
                                                    }
                                                    .buttonStyle(.glass)
                                                    .padding(.horizontal, 15)
                                                }
                                            }
                                            .padding(.bottom, 6)
                                        } header: {
                                            HStack(spacing: 8) {
                                                if let icon = section.titleIcon {
                                                    Image(systemName: icon)
                                                }
                                                Text(section.title)
                                                    .font(.custom("Nunito-Black", size: 16))
                                            }
                                            .foregroundColor(section.titleColor)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemBackground).opacity(0.95))
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                if isLoading {
                    VStack(spacing: 10) {
                        ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                        Text("Loading Rankos…")
                            .font(.custom("Nunito-Black", size: 16))
                            .foregroundColor(Color(hex: 0xA2A2A1))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                    .background(Color(.systemBackground).opacity(0.6).ignoresSafeArea())
                }
            }
            .searchable(text: $searchField, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Rankos")
            .searchFocused($searchFocused)
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: searchField) { _, newVal in
                rankoQuery = newVal
            }
            .navigationTitle("Search Rankos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.navigationStack)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .black))
                    }
                    .tint(Color(hex: 0x514343))
                }
                ToolbarItem(placement: .principal) {
                    Text("Search Rankos")
                        .font(.custom("Nunito-Black", size: 24))
                        .foregroundColor(Color(hex: 0x514343))
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSortGroupSheet(
                    sortMode: $sortMode,
                    groupMode: $groupMode,
                    allTypes: allTypes,
                    allCategories: allCategories,
                    selectedTypes: $selectedTypes,
                    selectedCategories: $selectedCategories
                )
                .presentationDetents([.large])
            }
            .fullScreenCover(item: $selectedList) { list in
                if list.type == "default" {
                    DefaultListPersonal(
                        rankoID: list.id,
                        categoryName: list.categoryName,
                        categoryIcon: list.categoryIcon,
                        categoryColour: list.categoryColour,
                        onSave: { _ in dismiss() },
                        onDelete: { dismiss() }
                    )
                } else {
                    TierListPersonal(
                        rankoID: list.id,
                        onSave: { _ in dismiss() },
                        onDelete: { dismiss() }
                    )
                }
            }
            .onAppear {
                if !isSimulator {
                    loadOptimizedData()
                    loadUserSortModel() // ← pulls Custom/Category/Date/Type order
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    searchFocused = true
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Header + chips

    private var headerBar: some View {
        VStack(spacing: 8) {
            // Active filters summary chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        print("Found \(filteredBase.count) Results")
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(filteredBase.count) Results")
                        }
                        .font(.custom("Nunito-Black", size: 12))
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0x514343))
                    
                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                        }
                        .font(.custom("Nunito-Black", size: 12))
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0x514343))
                    
                    if !selectedTypes.isEmpty || !selectedCategories.isEmpty || !rankoQuery.isEmpty {
                        Button {
                            rankoQuery = ""; searchField = ""
                            selectedTypes.removeAll()
                            selectedCategories.removeAll()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear Filters")
                            }
                            .font(.custom("Nunito-Black", size: 12))
                        }
                        .buttonStyle(.glass)
                        .tint(Color(hex: 0x514343))
                        if !rankoQuery.isEmpty {
                            chip(text: "“\(rankoQuery)”") { rankoQuery = ""; searchField = "" }
                        }
                        ForEach(Array(selectedTypes), id: \.self) { t in
                            chip(text: "Type: \(t.capitalized)") { selectedTypes.remove(t) }
                        }
                        ForEach(Array(selectedCategories), id: \.self) { c in
                            chip(text: "Category: \(c)") { selectedCategories.remove(c) }
                        }
                    }
                }
                .padding(15)
            }
        }
    }

    private func chip(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.custom("Nunito-Black", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F5F5)))
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(hex: 0x514343))
    }

    // MARK: - Sorting helpers

    private func sortByCustom(_ input: [RankoList]) -> [RankoList] {
        // build lookup for fast ID -> RankoList
        let dict = Dictionary(uniqueKeysWithValues: input.map { ($0.id, $0) })

        var result: [RankoList] = []
        for node in userSort.customTree {
            switch node {
            case .item(let id):
                if let r = dict[id] { result.append(r) }
            case .folder(_, let ids):
                for id in ids {
                    if let r = dict[id] { result.append(r) }
                }
            }
        }
        // append any missing ones (not in custom tree) at the end (stable by name)
        let seen = Set(result.map { $0.id })
        let missing = input.filter { !seen.contains($0.id) }
            .sorted { $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending }
        return result + missing
    }

    // MARK: - Data loads (existing)

    private func loadOptimizedData() {
        isLoading = true
        errorMessage = nil

        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")

        var query = Query("").set(\.hitsPerPage, to: 1000)
        query.filters = "RankoUserID:\(user_data.userID) AND RankoStatus:active"

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                let objectIDs = response.hits.map { $0.objectID.rawValue }
                fetchMinimalDataFromFirebase(using: objectIDs)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "❌ Failed to fetch from Algolia: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchMinimalDataFromFirebase(using objectIDs: [String]) {
        let rankoDataRef = Database.database().reference().child("RankoData")
        let dispatchGroup = DispatchGroup()
        var fetchedLists: [RankoList] = []

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

        for objectID in objectIDs {
            dispatchGroup.enter()
            rankoDataRef.child(objectID).observeSingleEvent(of: .value) { snap in
                defer { dispatchGroup.leave() }
                guard let root = snap.value as? [String: Any] else { return }

                if let details = root["RankoDetails"] as? [String: Any] {
                    let privacy = root["RankoPrivacy"]  as? [String: Any]
                    let cat     = root["RankoCategory"] as? [String: Any]
                    let dt      = root["RankoDateTime"] as? [String: Any]

                    let name        = (details["name"] as? String) ?? "(untitled)"
                    let description = (details["description"] as? String) ?? ""
                    let type        = (details["type"] as? String) ?? "default"
                    let userID      = (details["user_id"] as? String) ?? ""
                    let isPrivate   = (privacy?["private"] as? Bool) ?? false

                    let catName   = (cat?["name"] as? String) ?? "Unknown"
                    let catIcon   = (cat?["icon"] as? String) ?? "circle"
                    let catColour = parseColourUInt(cat?["colour"])

                    let created = (dt?["created"] as? String) ?? "19700101000000"
                    let updated = (dt?["updated"] as? String) ?? created

                    let rankoList = RankoList(
                        id: objectID,
                        listName: name,
                        listDescription: description,
                        type: type,
                        categoryName: catName,
                        categoryIcon: catIcon,
                        categoryColour: catColour,
                        isPrivate: isPrivate ? "Private" : "Public",
                        userCreator: userID,
                        timeCreated: created,
                        timeUpdated: updated,
                        items: []
                    )
                    DispatchQueue.main.async { fetchedLists.append(rankoList) }
                    return
                }

                // legacy fallback
                let name        = root["RankoName"] as? String ?? "(untitled)"
                let description = root["RankoDescription"] as? String ?? ""
                let type        = root["RankoType"] as? String ?? "default"
                let isPriv: Bool = {
                    if let b = root["RankoPrivacy"] as? Bool { return b }
                    if let s = root["RankoPrivacy"] as? String { return s.lowercased() == "private" }
                    return false
                }()
                let userID = root["RankoUserID"] as? String ?? ""

                var created = "19700101000000"
                var updated = "19700101000000"
                if let dt = root["RankoDateTime"] as? [String: Any] {
                    created = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? created
                    updated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? created
                } else if let s = root["RankoDateTime"] as? String {
                    created = s; updated = s
                }

                var catName = "Unknown"
                var catIcon = "circle"
                var catColour: UInt = 0x446D7A
                if let cat = root["RankoCategory"] as? [String: Any] {
                    catName   = (cat["name"] as? String) ?? catName
                    catIcon   = (cat["icon"] as? String) ?? catIcon
                    catColour = parseColourUInt(cat["colour"])
                } else if let catStr = root["RankoCategory"] as? String {
                    catName = catStr
                }

                let rankoList = RankoList(
                    id: objectID,
                    listName: name,
                    listDescription: description,
                    type: type,
                    categoryName: catName,
                    categoryIcon: catIcon,
                    categoryColour: catColour,
                    isPrivate: isPriv ? "Private" : "Public",
                    userCreator: userID,
                    timeCreated: created,
                    timeUpdated: updated,
                    items: []
                )
                DispatchQueue.main.async { fetchedLists.append(rankoList) }
            }
        }

        dispatchGroup.notify(queue: .main) {
            // default load order: most recently updated
            self.allLists = fetchedLists.sorted { (Int($0.timeUpdated) ?? 0) > (Int($1.timeUpdated) ?? 0) }
            self.isLoading = false
        }
    }

    // MARK: - Load UserSortRankos

    private func loadUserSortModel() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(user_data.userID)
            .child("UserSortRankos")

        ref.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any] else { return }
            var model = UserSortModel()

            // Custom
            if let custom = dict["Custom"] as? [String: Any] {
                let keys = custom.keys.sorted() // 000001..., preserves intended order
                for k in keys {
                    if let itemID = custom[k] as? String {
                        model.customTree.append(.item(id: itemID))
                    } else if let folder = custom[k] as? [String: Any] {
                        let name = (folder["name"] as? String) ?? "Folder"
                        let ids  = (folder["rankos"] as? [String]) ?? []
                        model.customTree.append(.folder(name: name, ids: ids))
                    }
                }
            }

            // Alphabetical
            if let alpha = dict["Alphabetical"] as? [String: String] {
                model.alphabetical = alpha
            }

            // Category
            if let category = dict["Category"] as? [String: Any] {
                if let buckets = category["CategoryData"] as? [String: [String]] {
                    model.categoryBuckets = buckets
                }
                if let order = category["CategorySort"] as? [[String: Any]] {
                    model.categoryOrder = order.map {
                        CategoryMeta(
                            name: ($0["name"] as? String) ?? "Unknown",
                            icon: ($0["icon"] as? String) ?? "circle",
                            colour: parseUInt(($0["colour"]))
                        )
                    }
                }
            }

            // Dates
            if let created = dict["DateTimeCreated"] as? [String: Any] {
                model.createdKeys = created.keys.sorted() // "timestamp - id"
            }
            if let updated = dict["DateTimeUpdated"] as? [String: Any] {
                model.updatedKeys = updated.keys.sorted()
            }

            // Types
            if let types = dict["Type"] as? [String: [String]] {
                model.typeBuckets = types
            }

            self.userSort = model
        }
    }

    private func parseUInt(_ any: Any?) -> UInt {
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
}

// MARK: - Filter / Sort / Group Sheet

private struct FilterSortGroupSheet: View {
    @Binding var sortMode: SortMode
    @Binding var groupMode: GroupMode

    let allTypes: [String]
    let allCategories: [CategoryMeta]
    @Binding var selectedTypes: Set<String>
    @Binding var selectedCategories: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Sort
                Section("Sort By") {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // Group
                Section("Group By") {
                    Picker("Group", selection: $groupMode) {
                        ForEach(GroupMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Filter
                Section("Filter By") {
                    DisclosureGroup("Type") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(allTypes, id: \.self) { t in
                                SelectChip(
                                    title: t.capitalized.replacingOccurrences(of: "Group", with: "Tier"),
                                    isOn: selectedTypes.contains(t),
                                    action: {
                                        if selectedTypes.contains(t) { selectedTypes.remove(t) }
                                        else { selectedTypes.insert(t) }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    DisclosureGroup("Category") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                            ForEach(allCategories, id: \.self) { cat in
                                SelectChipWithIcon(
                                    title: cat.name,
                                    icon: cat.icon,
                                    color: Color(hex: cat.colour),
                                    isOn: selectedCategories.contains(cat.name),
                                    action: {
                                        if selectedCategories.contains(cat.name) { selectedCategories.remove(cat.name) }
                                        else { selectedCategories.insert(cat.name) }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Filter, Sort & Group")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        selectedTypes.removeAll()
                        selectedCategories.removeAll()
                        sortMode = .dateUpdated
                        groupMode = .none
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.custom("Nunito-Black", size: 16))
                }
            }
        }
    }
}

// MARK: - Small UI helpers

private struct SelectChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Nunito-Black", size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? Color.accentColor : Color(.secondarySystemBackground)))
                .foregroundColor(isOn ? .white : Color(hex: 0x514343))
        }
        .buttonStyle(.plain)
    }
}

private struct SelectChipWithIcon: View {
    let title: String
    let icon: String
    let color: Color
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.custom("Nunito-Black", size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? color : color.opacity(0.15)))
            .foregroundColor(isOn ? .white : color)
        }
        .buttonStyle(.plain)
    }
}

struct RankoMiniView: View {
    let listData: RankoList
    let type: String
    let onUnpin: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(listData.listName)
                    .font(.custom("Nunito-Black", size: 16))
                    .foregroundColor(Color(hex: 0x514343))
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 6) {
                    FeaturedCategoryBadge(name: listData.categoryName, icon: listData.categoryIcon, colour: listData.categoryColour)
                    Text("• \(timeAgo(from: String(listData.timeUpdated)))")
                        .font(.custom("Nunito-Black", size: 9))
                        .foregroundColor(Color(hex: 0x514343))
                }
            }
            Spacer()
            
            if type == "featured" {
                Button {
                    onUnpin?()
                } label: {
                    Image(systemName: "pin.fill")
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundColor(Color(hex: 0x514343))
                        .padding(.trailing, 6)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .background(.clear)
        .padding(.vertical, 1)
    }
    
    private func timeAgo(from dt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"
        
        guard let date = formatter.date(from: dt)
        else { return "" }
        
        let now = Date()
        let secondsAgo = Int(now.timeIntervalSince(date))
        
        switch secondsAgo {
        case 0..<60: return "\(secondsAgo)s ago"
        case 60..<3600: return "\(secondsAgo / 60)m ago"
        case 3600..<86400: return "\(secondsAgo / 3600)h ago"
        case 86400..<604800: return "\(secondsAgo / 86400)d ago"
        case 604800..<31536000: return "\(secondsAgo / 604800)w ago"
        default: return "\(secondsAgo / 31536000)y ago"
        }
    }
}

struct SelectFeaturedRankosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var user_data = UserInformation.shared
    @FocusState private var searchFocused: Bool
    
    @State private var lists: [RankoList] = []
    @State private var selectedFacet: String? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var rankoQuery: String = ""
    @State private var searchField: String = ""
    @State private var selectedList: RankoList?
    
    var onSelect: (RankoList) -> Void
    
    // Dynamic filtering + facets that react to the remaining lists
    private var filteredLists: [RankoList] {
        lists.filter { list in
            (selectedFacet == nil || list.categoryName == selectedFacet) &&
            (rankoQuery.isEmpty || list.listName.lowercased().contains(rankoQuery.lowercased()))
        }
    }

    private var dynamicFacets: [FacetCategory] {
        // facet counts based on what's left after the search query (but before facet selection)
        let base = lists.filter { list in
            rankoQuery.isEmpty || list.listName.lowercased().contains(rankoQuery.lowercased())
        }
        
        let grouped = Dictionary(grouping: base, by: { $0.categoryName })
        return grouped
            .map { FacetCategory(facetName: $0.key, facetCount: $0.value.count) }
            .sorted { $0.facetCount > $1.facetCount }
    }
    
    // Fallback color helper so we never force-unwrap
    private func chipColor(for name: String) -> Color {
        categoryChipIconColors[name] ?? Color.gray
    }


    var body: some View {
        TabView {
            NavigationStack {
                // MAIN CONTENT
                ScrollView {
                    // loading / error
                    if isLoading {
                        VStack(spacing: 10) {
                            ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                            Text("Loading Rankos...")
                                .font(.custom("Nunito-Black", size: 16))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    }
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).padding()
                    }
                    // filtered results
                    VStack(spacing: 8) {
                        ForEach(filteredLists) { list in
                            HStack {
                                Button {
                                    print("Tapped: \(list.listName)")
                                    onSelect(list)
                                } label: {
                                    if list.type == "default" {
                                        DefaultListIndividualGallery(listData: list, type: "", onUnpin: {}, userID: user_data.userID)
                                    } else {
                                        TierListIndividualGallery(listData: list, type: "", onUnpin: {})
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
                    .padding(.vertical, 20)
                    .padding(.horizontal, 15)
                }
                // SEARCH IN NAV BAR
                .searchable(text: $searchField, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Rankos")
                .searchFocused($searchFocused)
                .scrollDismissesKeyboard(.immediately)
                .onAppear {
                    // give NavigationStack a tick to mount before focusing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
                .onChange(of: searchField) { _, newVal in
                    withAnimation(.easeInOut(duration: 0.3)) { rankoQuery = newVal }
                }
                // NAV BAR CONFIG (attach INSIDE the NavigationStack!)
                .navigationTitle("Search Rankos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.navigationStack)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                        }
                        .tint(Color(hex: 0x514343))
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Search Rankos")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0x514343))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                
                // CHIPS UNDER TOOLBAR
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !dynamicFacets.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dynamicFacets) { facet in
                                    let isSelected = selectedFacet == facet.facetName
                                    if selectedFacet == nil || isSelected {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                selectedFacet = isSelected ? nil : facet.facetName
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: FilterChip.icon(named: facet.facetName, in: defaultFilterChips) ?? "circle.fill")
                                                Text(facet.facetName).bold()
                                                Text("\(facet.facetCount)")
                                                    .font(.caption2.weight(.black))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.ultraThinMaterial, in: Capsule())
                                                if isSelected { Image(systemName: "xmark.circle.fill") }
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .foregroundStyle(isSelected ? .white : chipColor(for: facet.facetName))
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(isSelected ? chipColor(for: facet.facetName)
                                                          : chipColor(for: facet.facetName).opacity(0.18))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .background(Color(.systemBackground))
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
                .onAppear {
                    if !isSimulator {
                        fetchFacetData()
                        loadAllData()
                    }
                }
            }
            .tabItem { Label("", systemImage: "magnifyingglass") }
        }
        .interactiveDismissDisabled(true)
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

        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let d = any as? Double   { return Int(d) }
            if let s = any as? String   { return Int(s) }
            return nil
        }
        func parseColourUInt(_ any: Any?) -> UInt {
            if let n = any as? NSNumber { return UInt(truncating: n) & 0x00FF_FFFF }
            if let i = any as? Int      { return UInt(i & 0x00FF_FFFF) }
            if let s = any as? String {
                var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let dec = Int(t) { return UInt(dec & 0x00FF_FFFF) }
                if t.hasPrefix("#")  { t.removeFirst() }
                if t.hasPrefix("0x") { t.removeFirst(2) }
                if let v = Int(t, radix: 16) { return UInt(v & 0x00FF_FFFF) }
            }
            return 0x446D7A
        }

        // ✅ one-parameter closure variant
        rankoDataRef.observeSingleEvent(of: .value) { snapshot in
            guard let all = snapshot.value as? [String: Any] else {
                self.errorMessage = "❌ No data found in Firebase."
                self.isLoading = false
                return
            }

            var fetched: [RankoList] = []

            for objectID in objectIDs {
                guard let dict = all[objectID] as? [String: Any] else { continue }

                // ---------- NEW SCHEMA ----------
                if let details = dict["RankoDetails"] as? [String: Any] {
                    let privacy = dict["RankoPrivacy"]  as? [String: Any]
                    let cat     = dict["RankoCategory"] as? [String: Any]
                    let dt      = dict["RankoDateTime"] as? [String: Any]

                    let name        = (details["name"] as? String) ?? "(untitled)"
                    let description = (details["description"] as? String) ?? ""
                    let type        = (details["type"] as? String) ?? "default"
                    let userID      = (details["user_id"] as? String) ?? ""

                    let isPriv     = (privacy?["private"] as? Bool) ?? false
                    let catName    = (cat?["name"] as? String) ?? "Unknown"
                    let catIcon    = (cat?["icon"] as? String) ?? "circle"
                    let catColour  = parseColourUInt(cat?["colour"])

                    let created    = (dt?["created"] as? String) ?? "19700101000000"
                    let updated    = (dt?["updated"] as? String) ?? created

                    // Items may be [String: Any] under new schema
                    let itemsRaw   = dict["RankoItems"] as? [String: Any] ?? [:]
                    let items: [RankoItem] = itemsRaw.compactMap { (k, v) in
                        guard let it = v as? [String: Any],
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
                    }.sorted { $0.rank < $1.rank }

                    fetched.append(
                        RankoList(
                            id: objectID,
                            listName: name,
                            listDescription: description,
                            type: type,
                            categoryName: catName,
                            categoryIcon: catIcon,
                            categoryColour: catColour,
                            isPrivate: isPriv ? "Private" : "Public",
                            userCreator: userID,
                            timeCreated: created,
                            timeUpdated: updated,
                            items: items
                        )
                    )
                    continue
                }

                // ---------- LEGACY SCHEMA FALLBACK ----------
                guard
                    let name        = dict["RankoName"]        as? String,
                    let description = dict["RankoDescription"] as? String,
                    let type        = dict["RankoType"]        as? String,
                    let isPrivBool  = dict["RankoPrivacy"]     as? Bool,
                    let userID      = dict["RankoUserID"]      as? String
                else { continue }

                var created = "19700101000000"
                var updated = "19700101000000"
                if let dt = dict["RankoDateTime"] as? [String: Any] {
                    created = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? created
                    updated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? created
                } else if let s = dict["RankoDateTime"] as? String {
                    created = s; updated = s
                }

                var catName = "Unknown"
                var catIcon = "circle"
                var catColour: UInt = 0x446D7A
                if let cat = dict["RankoCategory"] as? [String: Any] {
                    catName   = (cat["name"] as? String) ?? catName
                    catIcon   = (cat["icon"] as? String) ?? catIcon
                    catColour = parseColourUInt(cat["colour"])
                } else if let catStr = dict["RankoCategory"] as? String {
                    catName = catStr
                }

                let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
                let items: [RankoItem] = itemsDict.compactMap { itemID, it in
                    guard let itemName  = it["ItemName"] as? String,
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
                }.sorted { $0.rank < $1.rank }

                fetched.append(
                    RankoList(
                        id: objectID,
                        listName: name,
                        listDescription: description,
                        type: type,
                        categoryName: catName,
                        categoryIcon: catIcon,
                        categoryColour: catColour,
                        isPrivate: isPrivBool ? "Private" : "Public",
                        userCreator: userID,
                        timeCreated: created,
                        timeUpdated: updated,
                        items: items
                    )
                )
            }

            DispatchQueue.main.async {
                self.lists = fetched
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
    @FocusState private var searchFocused: Bool
    
    @State private var users: [RankoUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var userQuery: String = ""
    @State private var searchField: String = ""
    @State private var selectedUser: RankoUser?
    @State private var filteredUsers: [RankoUser] = []
    @State private var followerIDs: [String] = []

    var body: some View {
        TabView {
            NavigationStack {
                // MAIN CONTENT
                ScrollView {
                    // loading / error
                    if isLoading {
                        VStack(spacing: 10) {
                            ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                            Text("Loading Followers...")
                                .font(.custom("Nunito-Black", size: 16))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    }
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).padding()
                    }
                    // filtered results
                    VStack(spacing: 8) {
                        ForEach(filteredUsers) { user in
                            NavigationLink {
                                ProfileSpectateView(userID: user.id)
                            } label: {
                                UserGalleryView(user: user)
                            }
                            .foregroundColor(Color(hex: 0xFF9864))
                            .tint(Color(hex: 0xFFFFFF))
                            .buttonStyle(.glassProminent)
                            .shadow(color: Color(hex:0x000000).opacity(0.1), radius: 8, x: 0, y: -2)
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 15)
                }
                // SEARCH IN NAV BAR
                .searchable(text: $searchField, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Followers")
                .searchFocused($searchFocused)
                .scrollDismissesKeyboard(.immediately)
                .onAppear {
                    // give NavigationStack a tick to mount before focusing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
                // NAV BAR CONFIG (attach INSIDE the NavigationStack!)
                .navigationTitle("Search Followers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.navigationStack)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                        }
                        .tint(Color(hex: 0x514343))
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Search Followers")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0x514343))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .onAppear {
                    loadFollowers()
                }
                .onChange(of: searchField) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
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
            }
            .tabItem { Label("", systemImage: "magnifyingglass") }
        }
        .interactiveDismissDisabled(true)
    }

    private func loadFollowers() {
        isLoading = true
        errorMessage = nil

        let followersRef = Database.database()
            .reference()
            .child("UserData")
            .child(user_data.userID)
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

            if self.userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.filteredUsers = loaded
            } else {
                let lc = self.userQuery.lowercased()
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
    @FocusState private var searchFocused: Bool
    
    @State private var users: [RankoUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var userQuery: String = ""
    @State private var searchField: String = ""
    @State private var selectedUser: RankoUser?
    @State private var filteredUsers: [RankoUser] = []
    @State private var followingIDs: [String] = []

    var body: some View {
        TabView {
            NavigationStack {
                // MAIN CONTENT
                ScrollView {
                    // loading / error
                    if isLoading {
                        VStack(spacing: 10) {
                            ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                            Text("Loading Following...")
                                .font(.custom("Nunito-Black", size: 16))
                                .foregroundColor(Color(hex: 0xA2A2A1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    }
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).padding()
                    }
                    // filtered results
                    VStack(spacing: 8) {
                        ForEach(filteredUsers) { user in
                            NavigationLink {
                                ProfileSpectateView(userID: user.id)
                            } label: {
                                UserGalleryView(user: user)
                            }
                            .foregroundColor(Color(hex: 0xFF9864))
                            .tint(Color(hex: 0xFFFFFF))
                            .buttonStyle(.glassProminent)
                            .shadow(color: Color(hex:0x000000).opacity(0.1), radius: 8, x: 0, y: -2)
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 15)
                }
                // SEARCH IN NAV BAR
                .searchable(text: $searchField, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Following")
                .searchFocused($searchFocused)
                .scrollDismissesKeyboard(.immediately)
                .onAppear {
                    // give NavigationStack a tick to mount before focusing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
                // NAV BAR CONFIG (attach INSIDE the NavigationStack!)
                .navigationTitle("Search Following")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.navigationStack)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                        }
                        .tint(Color(hex: 0x514343))
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Search Following")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0x514343))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .onAppear {
                    loadFollowing()
                }
                .onChange(of: searchField) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
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
            }
            .tabItem { Label("", systemImage: "magnifyingglass") }
        }
        .interactiveDismissDisabled(true)
    }

    private func loadFollowing() {
        isLoading = true
        errorMessage = nil

        let followingRef = Database.database()
            .reference()
            .child("UserData")
            .child(user_data.userID)
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
    
    func fetchFollowingProfiles(ids: [String]) {
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

            if self.userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.filteredUsers = loaded
            } else {
                let lc = self.userQuery.lowercased()
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
    @State private var pendingClone: ClonedRankoList? = nil
    @State private var showClonedEditor = false
    
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
                                    ThreeRectanglesAnimation(rectangleWidth: 30, rectangleMaxHeight: 80, rectangleSpacing: 4, rectangleCornerRadius: 6, animationDuration: 0.7)
                                }
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: 0xFFFFFF))
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
                                                    }, userID: user_data.userID)
                                                } else {
                                                    TierListIndividualGallery(listData: list, type: "featured", onUnpin: {
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
                .onChange(of: selectedFeaturedList?.id, initial: false) { _, newID in
                    if newID == nil, pendingClone != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showClonedEditor = true
                        }
                    }
                }
//                .fullScreenCover(isPresented: $showClonedEditor, onDismiss: { pendingClone = nil }) {
//                    if let clone = pendingClone {
//                        DefaultListView(
//                            rankoName: clone.listName,
//                            description: clone.listDescription,
//                            isPrivate: clone.isPrivate == "Private",
//                            category: categoryChip(named: clone.category),
//                            selectedRankoItems: clone.items
//                        ) { _ in /* no-op */ }
//                    }
//                }
                .sheet(isPresented: $showUserFollowers) {
                    SearchFollowersView()
                }
                .sheet(isPresented: $showUserFollowing) {
                    SearchFollowingView()
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
    
//    private func categoryChip(named name: String) -> SampleCategoryChip? {
//        // Uses your existing global/category source if available
//        let all = categoryChipsByCategory.values.flatMap { $0 }
//        return all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
//    }
    
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

        storageRef.getData(maxSize: Int64(2 * 1024 * 1024)) { data, error in
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
                if let slot = Int(child.key), let rankoID = child.value as? String {
                    group.enter()
                    fetchFeaturedList(slot: slot, rankoID: rankoID) {
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
    private func fetchFeaturedList(slot: Int, rankoID: String, completion: @escaping (RankoList?) -> Void) {
        let listRef = Database.database().reference().child("RankoData").child(rankoID)

        listRef.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any],
                  let rl = parseListData(dict: dict, id: rankoID) else {
                completion(nil)
                return
            }
            completion(rl)
        }
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        // tolerant int parser
        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let d = any as? Double   { return Int(d) }
            if let s = any as? String   { return Int(s) }
            return nil
        }

        // parse "0xRRGGBB", "#RRGGBB", "RRGGBB", decimal, NSNumber → UInt (24-bit)
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

        // ======== NEW SCHEMA PREFERRED ========
        if let details = dict["RankoDetails"] as? [String: Any] {
            let privacy = dict["RankoPrivacy"]   as? [String: Any]
            let cat     = dict["RankoCategory"]  as? [String: Any]
            let items   = dict["RankoItems"]     as? [String: Any] ?? [:]
            let dt      = dict["RankoDateTime"]  as? [String: Any]

            let listName    = (details["name"] as? String) ?? ""
            let description = (details["description"] as? String) ?? ""
            let type        = (details["type"] as? String) ?? "default"
            let userCreator = (details["user_id"] as? String) ?? ""

            let isPrivate   = (privacy?["private"] as? Bool) ?? false

            let catName     = (cat?["name"] as? String) ?? "Unknown"
            let catIcon     = (cat?["icon"] as? String) ?? "circle"
            let catColour   = parseColourUInt(cat?["colour"])

            let timeCreated = (dt?["created"] as? String) ?? ""
            let timeUpdated = (dt?["updated"] as? String) ?? timeCreated

            // items can be [String: Any] with inner dicts
            let rankoItems: [RankoItem] = items.compactMap { (keyID, raw) in
                guard let itemDict = raw as? [String: Any] else { return nil }
                let itemID   = (itemDict["ItemID"] as? String) ?? keyID
                guard
                    let itemName  = itemDict["ItemName"] as? String,
                    let itemDesc  = itemDict["ItemDescription"] as? String,
                    let itemImage = itemDict["ItemImage"] as? String,
                    let itemGIF    = itemDict["ItemGIF"] as? String,
                    let itemVideo    = itemDict["ItemVideo"] as? String,
                    let itemAudio    = itemDict["ItemAudio"] as? String
                else { return nil }
                let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
                let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
                let rec = RankoRecord(objectID: itemID, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                let plays = intFromAny(itemDict["PlayCount"]) ?? 0
                return RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            }.sorted { $0.rank < $1.rank }

            return RankoList(
                id:              id,
                listName:        listName,
                listDescription: description,
                type:            type,
                categoryName:    catName,
                categoryIcon:    catIcon,
                categoryColour:  catColour,
                isPrivate:       isPrivate ? "Private" : "Public",
                userCreator:     userCreator,
                timeCreated:     timeCreated,
                timeUpdated:     timeUpdated,
                items:           rankoItems
            )
        }

        // ======== LEGACY SCHEMA FALLBACK ========
        guard
            let listName    = dict["RankoName"]        as? String,
            let description = dict["RankoDescription"] as? String,
            let type        = dict["RankoType"]        as? String,
            let privacy     = dict["RankoPrivacy"]     as? Bool,
            let userCreator = dict["RankoUserID"]      as? String
        else { return nil }

        var timeCreated = ""
        var timeUpdated = ""
        if let dt = dict["RankoDateTime"] as? [String: Any] {
            timeCreated = (dt["RankoCreated"] as? String) ?? (dt["created"] as? String) ?? ""
            timeUpdated = (dt["RankoUpdated"] as? String) ?? (dt["updated"] as? String) ?? timeCreated
        } else if let s = dict["RankoDateTime"] as? String {
            timeCreated = s
            timeUpdated = s
        }

        // Items
        let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
        var rankoItems: [RankoItem] = []

        for (keyID, itemDict) in itemsDict {
            let itemID = (itemDict["ItemID"] as? String) ?? keyID

            // If these media fields aren’t guaranteed in legacy data, default them to ""
            let itemGIF   = (itemDict["ItemGIF"]   as? String) ?? ""
            let itemVideo = (itemDict["ItemVideo"] as? String) ?? ""
            let itemAudio = (itemDict["ItemAudio"] as? String) ?? ""

            guard
                let itemName  = itemDict["ItemName"] as? String,
                let itemDesc  = itemDict["ItemDescription"] as? String,
                let itemImage = itemDict["ItemImage"] as? String
            else { continue } // <- don’t return; just skip this item
                                
            let rank  = intFromAny(itemDict["ItemRank"])  ?? 0
            let votes = intFromAny(itemDict["ItemVotes"]) ?? 0
            let plays = intFromAny(itemDict["PlayCount"]) ?? 0

            let rec = RankoRecord(
                objectID: itemID,
                ItemName: itemName,
                ItemDescription: itemDesc,
                ItemCategory: "",
                ItemImage: itemImage,
                ItemGIF: itemGIF,
                ItemVideo: itemVideo,
                ItemAudio: itemAudio
            )

            rankoItems.append(
                RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            )
        }

        rankoItems.sort { $0.rank < $1.rank }

        // Category (object or legacy string)
        var catName = "Unknown"
        var catIcon = "circle"
        var catColour = 0x446D7A
        if let cat = dict["RankoCategory"] as? [String: Any] {
            catName   = (cat["name"] as? String) ?? catName
            catIcon   = (cat["icon"] as? String) ?? catIcon
            catColour = {
                if let n = cat["colour"] as? NSNumber { return n.intValue }
                if let s = cat["colour"] as? String {
                    var hex = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let dec = Int(hex) { return dec }
                    if hex.hasPrefix("#")  { hex.removeFirst() }
                    if hex.hasPrefix("0x") { hex.removeFirst(2) }
                    return Int(hex, radix: 16) ?? 0x446D7A
                }
                return 0x446D7A
            }()
        } else if let catStr = dict["RankoCategory"] as? String {
            catName = catStr
        }

        return RankoList(
            id:              id,
            listName:        listName,
            listDescription: description,
            type:            type,
            categoryName:    catName,
            categoryIcon:    catIcon,
            categoryColour:  UInt(catColour & 0x00FF_FFFF),
            isPrivate:       privacy ? "Private" : "Public",
            userCreator:     userCreator,
            timeCreated:     timeCreated,
            timeUpdated:     timeUpdated,
            items:           rankoItems
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

// MARK: - Enhanced Models

struct AppTheme: Identifiable {
    let id = UUID()
    let name: String
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let textColor: Color
    let icon: String
    let isLocked: Bool
    let mission: Mission?
    
    static let `default` = AppTheme(
        name: "Classic",
        primaryColor: .blue,
        secondaryColor: .gray,
        accentColor: .orange,
        backgroundColor: Color(.systemBackground),
        textColor: Color(.label),
        icon: "paintbrush.fill",
        isLocked: false,
        mission: nil
    )
}

struct AppFont: Identifiable {
    let id = UUID()
    let name: String
    let fontName: String
    let previewText: String
    let isLocked: Bool
    let mission: Mission?
    
    func font(size: CGFloat) -> Font {
        if fontName == "System" {
            return .system(size: size, weight: .medium, design: .default)
        }
        return .custom(fontName, size: size)
    }
}

enum GameType: String, CaseIterable {
    case blindSequence = "Blind Sequence"
    case memoryChallenge = "Memory Challenge"
    case speedTap = "Speed Tap"
    case colorMatch = "Color Match"
    case patternTrace = "Pattern Trace"
}

enum RewardType: String, CaseIterable {
    case appIcon = "App Icons"
    case theme = "Themes"
    case font = "Fonts"
    case badge = "Badges"
    case effect = "Effects"
}

struct Mission: Identifiable {
    let id = UUID()
    let description: String
    let goal: Int
    let type: MissionType
    let game: GameType
    let rewardType: RewardType
    let difficulty: Difficulty
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"
        case legendary = "Legendary"
        
        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .yellow
            case .hard: return .orange
            case .expert: return .red
            case .legendary: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .easy: return "leaf.fill"
            case .medium: return "flame.fill"
            case .hard: return "bolt.fill"
            case .expert: return "crown.fill"
            case .legendary: return "star.fill"
            }
        }
    }
}

enum MissionType: String, CaseIterable {
    case gamesPlayed = "Games Played"
    case highScore = "High Score"
    case consecutiveWins = "Win Streak"
    case perfectRounds = "Perfect Rounds"
    case timeChallenge = "Time Challenge"
    case subscribed = "Premium"
    case dailyStreak = "Daily Streak"
}

struct AppIcon: Identifiable {
    let id = UUID()
    let iconName: String?
    let previewImage: String
    var isLocked: Bool
    let mission: Mission?
    let category: String
}

// MARK: - Enhanced Toast Component

struct MissionToast: View {
    @Binding var isShown: Bool
    var title: String? = "Mission"
    var message: String = "message"
    var icon: Image = Image(systemName: "exclamationmark.circle")
    var alignment: Alignment = .top
    var theme: AppTheme = .default
    
    var goal: Int? = nil
    var progress: Int? = nil
    var difficulty: Mission.Difficulty? = nil

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
                    .foregroundColor(theme.accentColor)
                    .font(.custom("Nunito-Black", size: 18))
                
                if let difficulty = difficulty {
                    Image(systemName: difficulty.icon)
                        .foregroundColor(difficulty.color)
                        .font(.caption)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.custom("Nunito-Black", size: 16))
                            .foregroundColor(theme.textColor)
                    }
                    Text(message)
                        .font(.custom("Nunito-Black", size: 14))
                        .foregroundColor(theme.textColor.opacity(0.8))
                }
            }

            if let goal, let progress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Float(progress), total: Float(goal))
                        .accentColor(theme.accentColor)
                    HStack {
                        Text("\(progress)/\(goal)")
                            .font(.custom("Nunito-Black", size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int((Float(progress) / Float(goal)) * 100))%")
                            .font(.custom("Nunito-Black", size: 12))
                            .foregroundColor(theme.accentColor)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.backgroundColor)
                .shadow(color: theme.accentColor.opacity(0.3), radius: 15, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
        )
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

// MARK: - Main View

struct AppPersonalisationView: View {
    @Environment(\.dismiss) var dismiss
    // Game Stats
    @State private var blindSequenceGames = 12
    @State private var blindSequenceScore = 25
    @State private var memoryGames = 15
    @State private var memoryScore = 28
    @State private var speedTapGames = 8
    @State private var speedTapScore = 42
    @State private var colorMatchGames = 23
    @State private var colorMatchScore = 35
    @State private var patternTraceGames = 12
    @State private var patternTraceScore = 18
    
    @State private var dailyStreak = 7
    @State private var consecutiveWins = 5
    @State private var perfectRounds = 12
    @State var subscribed: Int = 1
    
    // Unlock States
    @State private var selectedThemeName = "Classic"
    @State private var selectedFontName = "System"
    @State private var selectedIconName: String?
    
    // State Variables
    @State private var currentTheme: AppTheme = .default
    @State private var currentFont: AppFont = AppFont(name: "System", fontName: "System", previewText: "Abc", isLocked: false, mission: nil)
    
    @State private var unlockingItemIndex: Int? = nil
    @State private var isUnlocking: Bool = false
    @State private var selectedIcon: String?
    
    @State private var groupByType: GroupingType = .rewardType
    @State private var showFilterSheet = false
    @State private var selectedGame: GameType? = nil
    @State private var selectedRewardType: RewardType? = nil
    @State private var selectedDifficulty: Mission.Difficulty? = nil
    
    @State private var toastMessage: String = ""
    @State private var toastProgress: Int? = nil
    @State private var toastGoal: Int? = nil
    @State private var showToast: Bool = false
    @State private var toastDifficulty: Mission.Difficulty? = nil
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var toastID = UUID()
    
    enum GroupingType: String, CaseIterable {
        case rewardType = "Reward"
        case game = "Mini Game"
        case missionType = "Mission Type"
        case difficulty = "Difficulty"
        
        var icon: String {
            switch self {
            case .rewardType: return "square.grid.2x2"
            case .game: return "gamecontroller"
            case .missionType: return "target"
            case .difficulty: return "chart.bar"
            }
        }
    }
    
    let iconColumns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 4)
    let themeColumns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 12), count: 2)
    
    // MARK: - Data Generation
    
    private func generateMissions() -> [Mission] {
        var missions: [Mission] = []
        
        // Blind Sequence Missions
        missions += [
            Mission(description: "Score 20 points in Blind Sequence", goal: 20, type: .highScore, game: .blindSequence, rewardType: .appIcon, difficulty: .easy),
            Mission(description: "Score 30 points in Blind Sequence", goal: 30, type: .highScore, game: .blindSequence, rewardType: .appIcon, difficulty: .medium),
            Mission(description: "Play 10 Blind Sequence games", goal: 10, type: .gamesPlayed, game: .blindSequence, rewardType: .theme, difficulty: .easy),
            Mission(description: "Subscribe to Premium", goal: 1, type: .subscribed, game: .blindSequence, rewardType: .font, difficulty: .easy),
        ]
        
        // Memory Challenge Missions
        missions += [
            Mission(description: "Score 25 in Memory Challenge", goal: 25, type: .highScore, game: .memoryChallenge, rewardType: .theme, difficulty: .medium),
            Mission(description: "Play 50 Memory games", goal: 50, type: .gamesPlayed, game: .memoryChallenge, rewardType: .appIcon, difficulty: .medium),
            Mission(description: "Score 35 in Memory Challenge", goal: 35, type: .highScore, game: .memoryChallenge, rewardType: .font, difficulty: .medium),
        ]
        
        // Speed Tap Missions
        missions += [
            Mission(description: "Get 10 consecutive wins in Speed Tap", goal: 10, type: .consecutiveWins, game: .speedTap, rewardType: .appIcon, difficulty: .hard),
            Mission(description: "Score 45 in Speed Tap", goal: 45, type: .highScore, game: .speedTap, rewardType: .theme, difficulty: .expert),
        ]
        
        // Color Match Missions
        missions += [
            Mission(description: "Score 35 in Color Match", goal: 35, type: .highScore, game: .colorMatch, rewardType: .appIcon, difficulty: .hard),
            Mission(description: "Complete 100 Color Match games", goal: 100, type: .gamesPlayed, game: .colorMatch, rewardType: .theme, difficulty: .hard),
            Mission(description: "Maintain 14-day streak", goal: 14, type: .dailyStreak, game: .colorMatch, rewardType: .font, difficulty: .easy),
            Mission(description: "Maintain 30-day streak", goal: 30, type: .dailyStreak, game: .colorMatch, rewardType: .appIcon, difficulty: .legendary)
        ]
        
        // Pattern Trace Missions
        missions += [
            Mission(description: "Get 20 perfect rounds in Pattern Trace", goal: 20, type: .perfectRounds, game: .patternTrace, rewardType: .theme, difficulty: .hard),
            Mission(description: "Play 25 Pattern Trace games", goal: 25, type: .gamesPlayed, game: .patternTrace, rewardType: .font, difficulty: .medium),
        ]
        
        return missions
    }
    
    private func generateAppIcons() -> [AppIcon] {
        let missions = generateMissions().filter { $0.rewardType == .appIcon }
        
        return [
            AppIcon(iconName: nil, previewImage: "Default_AppIcon_Preview", isLocked: false, mission: nil, category: "Classic"),
            AppIcon(iconName: "Medal_AppIcon", previewImage: "Medal_AppIcon_Preview", isLocked: missions.count > 0 ? !checkMissionComplete(missions[0]) : true, mission: missions.count > 0 ? missions[0] : nil, category: "Achievement"),
            AppIcon(iconName: "Trophy_AppIcon", previewImage: "Trophy_AppIcon_Preview", isLocked: missions.count > 1 ? !checkMissionComplete(missions[1]) : true, mission: missions.count > 1 ? missions[1] : nil, category: "Achievement"),
            AppIcon(iconName: "Star_AppIcon", previewImage: "Star_AppIcon_Preview", isLocked: missions.count > 2 ? !checkMissionComplete(missions[2]) : true, mission: missions.count > 2 ? missions[2] : nil, category: "Achievement"),
            AppIcon(iconName: "Crown_AppIcon", previewImage: "Crown_AppIcon_Preview", isLocked: missions.count > 3 ? !checkMissionComplete(missions[3]) : true, mission: missions.count > 3 ? missions[3] : nil, category: "Royal"),
            AppIcon(iconName: "Diamond_AppIcon", previewImage: "Diamond_AppIcon_Preview", isLocked: missions.count > 4 ? !checkMissionComplete(missions[4]) : true, mission: missions.count > 4 ? missions[4] : nil, category: "Premium"),
            AppIcon(iconName: "Fire_AppIcon", previewImage: "Fire_AppIcon_Preview", isLocked: missions.count > 5 ? !checkMissionComplete(missions[5]) : true, mission: missions.count > 5 ? missions[5] : nil, category: "Elite"),
            AppIcon(iconName: "Galaxy_AppIcon", previewImage: "Galaxy_AppIcon_Preview", isLocked: missions.count > 6 ? !checkMissionComplete(missions[6]) : true, mission: missions.count > 6 ? missions[6] : nil, category: "Cosmic")
        ]
    }
    
    private func generateThemes() -> [AppTheme] {
        let missions = generateMissions().filter { $0.rewardType == .theme }
        
        return [
            AppTheme(name: "Classic", primaryColor: .blue, secondaryColor: .gray, accentColor: .orange, backgroundColor: Color(.systemBackground), textColor: Color(.label), icon: "DefaultTheme_Image", isLocked: false, mission: nil),
            AppTheme(name: "Ocean", primaryColor: .blue, secondaryColor: .cyan, accentColor: .teal, backgroundColor: Color.blue.opacity(0.1), textColor: .blue, icon: "OceanTheme_Image", isLocked: missions.count > 0 ? !checkMissionComplete(missions[0]) : true, mission: missions.count > 0 ? missions[0] : nil),
            AppTheme(name: "Sunset", primaryColor: .orange, secondaryColor: .pink, accentColor: .red, backgroundColor: Color.orange.opacity(0.1), textColor: .orange, icon: "SunsetTheme_Image", isLocked: missions.count > 1 ? !checkMissionComplete(missions[1]) : true, mission: missions.count > 1 ? missions[1] : nil),
            AppTheme(name: "Forest", primaryColor: .green, secondaryColor: .mint, accentColor: .green, backgroundColor: Color.green.opacity(0.1), textColor: .green, icon: "ForestTheme_Image", isLocked: missions.count > 2 ? !checkMissionComplete(missions[2]) : true, mission: missions.count > 2 ? missions[2] : nil),
            AppTheme(name: "Galaxy", primaryColor: .purple, secondaryColor: .indigo, accentColor: .purple, backgroundColor: Color.purple.opacity(0.1), textColor: .purple, icon: "GalaxyTheme_Image", isLocked: missions.count > 3 ? !checkMissionComplete(missions[3]) : true, mission: missions.count > 3 ? missions[3] : nil),
            AppTheme(name: "Crimson", primaryColor: .red, secondaryColor: .pink, accentColor: .red, backgroundColor: Color.red.opacity(0.1), textColor: .red, icon: "CrimsonTheme_Image", isLocked: missions.count > 4 ? !checkMissionComplete(missions[4]) : true, mission: missions.count > 4 ? missions[4] : nil)
        ]
    }
    
    private func generateFonts() -> [AppFont] {
        let missions = generateMissions().filter { $0.rewardType == .font }
        
        return [
            AppFont(name: "System", fontName: "System", previewText: "Abc 123", isLocked: false, mission: nil),
            AppFont(name: "Rounded", fontName: "SF Pro Rounded", previewText: "Abc 123", isLocked: missions.count > 0 ? !checkMissionComplete(missions[0]) : true, mission: missions.count > 0 ? missions[0] : nil),
            AppFont(name: "Mono", fontName: "SF Mono", previewText: "Abc 123", isLocked: missions.count > 1 ? !checkMissionComplete(missions[1]) : true, mission: missions.count > 1 ? missions[1] : nil),
            AppFont(name: "Serif", fontName: "Times New Roman", previewText: "Abc 123", isLocked: missions.count > 2 ? !checkMissionComplete(missions[2]) : true, mission: missions.count > 2 ? missions[2] : nil)
        ]
    }
    
    private func checkMissionComplete(_ mission: Mission) -> Bool {
        let progress = getProgress(for: mission)
        return progress >= mission.goal
    }
    
    private func getProgress(for mission: Mission) -> Int {
        switch (mission.type, mission.game) {
        case (.gamesPlayed, .blindSequence): return blindSequenceGames
        case (.gamesPlayed, .memoryChallenge): return memoryGames
        case (.gamesPlayed, .speedTap): return speedTapGames
        case (.gamesPlayed, .colorMatch): return colorMatchGames
        case (.gamesPlayed, .patternTrace): return patternTraceGames
        case (.highScore, .blindSequence): return blindSequenceScore
        case (.highScore, .memoryChallenge): return memoryScore
        case (.highScore, .speedTap): return speedTapScore
        case (.highScore, .colorMatch): return colorMatchScore
        case (.highScore, .patternTrace): return patternTraceScore
        case (.consecutiveWins, _): return consecutiveWins
        case (.perfectRounds, _): return perfectRounds
        case (.subscribed, _): return subscribed
        case (.dailyStreak, _): return dailyStreak
        default: return 0
        }
    }
    
    // MARK: - Grouped Data
    
    private var groupedData: [(String, [AppIcon], [AppTheme], [AppFont])] {
        let allIcons = generateAppIcons()
        let allThemes = generateThemes()
        let allFonts = generateFonts()
        
        switch groupByType {
        case .game:
            return GameType.allCases.map { game in
                let icons = allIcons.filter { icon in
                    guard let mission = icon.mission else { return game == .blindSequence && icon.iconName == nil }
                    return mission.game == game
                }
                let themes = allThemes.filter { theme in
                    guard let mission = theme.mission else { return game == .blindSequence && theme.name == "Classic" }
                    return mission.game == game
                }
                let fonts = allFonts.filter { font in
                    guard let mission = font.mission else { return game == .blindSequence && font.name == "System" }
                    return mission.game == game
                }
                return (game.rawValue, icons, themes, fonts)
            }.filter { !$0.1.isEmpty || !$0.2.isEmpty || !$0.3.isEmpty }
            
        case .missionType:
            return MissionType.allCases.map { missionType in
                let icons = allIcons.filter { $0.mission?.type == missionType }
                let themes = allThemes.filter { $0.mission?.type == missionType }
                let fonts = allFonts.filter { $0.mission?.type == missionType }
                return (missionType.rawValue, icons, themes, fonts)
            }.filter { !$0.1.isEmpty || !$0.2.isEmpty || !$0.3.isEmpty }
            
        case .difficulty:
            return Mission.Difficulty.allCases.map { difficulty in
                let icons = allIcons.filter { $0.mission?.difficulty == difficulty }
                let themes = allThemes.filter { $0.mission?.difficulty == difficulty }
                let fonts = allFonts.filter { $0.mission?.difficulty == difficulty }
                return (difficulty.rawValue, icons, themes, fonts)
            }.filter { !$0.1.isEmpty || !$0.2.isEmpty || !$0.3.isEmpty }
            
        case .rewardType:
            return [
                ("App Icons", allIcons, [], []),
                ("Themes", [], allThemes, []),
                ("Fonts", [], [], allFonts)
            ]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                currentTheme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(groupedData.enumerated()), id: \.offset) { index, group in
                                VStack(spacing: 0) {
                                    TierSectionView(
                                        title: group.0,
                                        icons: group.1,
                                        themes: group.2,
                                        fonts: group.3,
                                        theme: currentTheme,
                                        selectedIcon: selectedIcon,
                                        selectedTheme: currentTheme,
                                        selectedFont: currentFont,
                                        iconColumns: iconColumns,
                                        themeColumns: themeColumns,
                                        onIconTap: { icon in handleIconTap(icon: icon) },
                                        onThemeTap: { theme in handleThemeSelection(theme: theme) },
                                        onFontTap: { font in handleFontSelection(font: font) }
                                    )
                                    
                                    // Divider between groups
                                    if index < groupedData.count - 1 {
                                        Divider()
                                            .background(currentTheme.textColor.opacity(0.2))
                                            .padding(.vertical, 20)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Toast Overlay
                if showToast {
                    MissionToast(
                        isShown: $showToast,
                        title: "🔒 Mission Required",
                        message: toastMessage,
                        icon: Image(systemName: "target"),
                        alignment: .bottom,
                        theme: currentTheme,
                        goal: toastGoal,
                        progress: toastProgress,
                        difficulty: toastDifficulty
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toastID)
                    .zIndex(1)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showFilterSheet = true } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(currentTheme.textColor)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 2)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Customisation Center")
                        .font(.custom("Nunito-Black", size: 22))
                        .foregroundColor(currentTheme.textColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(currentTheme.textColor)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 3)
                    }
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                selectedGrouping: $groupByType,
                theme: currentTheme
            )
        }
        .onAppear {
            setupInitialStates()
        }
    }
    
    private var filterControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Group By Picker
                Menu {
                    ForEach(GroupingType.allCases, id: \.self) { type in
                        Button(action: { groupByType = type }) {
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                                    .font(.custom("Nunito-Black", size: 14))
                                if groupByType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: groupByType.icon)
                        Text("Group: \(groupByType.rawValue)")
                            .font(.custom("Nunito-Black", size: 14))
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(currentTheme.accentColor.opacity(0.15))
                    .foregroundColor(currentTheme.accentColor)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Filter Sheet
    
    struct FilterSheet: View {
        @Binding var selectedGrouping: GroupingType
        let theme: AppTheme
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            NavigationView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Group rewards by:")
                        .font(.custom("Nunito-Black", size: 18))
                        .foregroundColor(theme.textColor)
                        .padding(.top)
                    
                    VStack(spacing: 12) {
                        ForEach(GroupingType.allCases, id: \.self) { grouping in
                            Button(action: {
                                selectedGrouping = grouping
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: grouping.icon)
                                        .foregroundColor(theme.accentColor)
                                        .frame(width: 24)
                                    
                                    Text(grouping.rawValue)
                                        .font(.custom("Nunito-Black", size: 16))
                                        .foregroundColor(theme.textColor)
                                    
                                    Spacer()
                                    
                                    if selectedGrouping == grouping {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(theme.accentColor)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedGrouping == grouping ? theme.accentColor.opacity(0.1) : theme.backgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedGrouping == grouping ? theme.accentColor : theme.textColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(theme.backgroundColor)
                .navigationTitle("Group By")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.custom("Nunito-Black", size: 14))
                        .foregroundColor(theme.accentColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialStates() {
        if let savedTheme = generateThemes().first(where: { $0.name == selectedThemeName }) {
            currentTheme = savedTheme
        }
        
        if let savedFont = generateFonts().first(where: { $0.name == selectedFontName }) {
            currentFont = savedFont
        }
        
        selectedIcon = selectedIconName
    }
    
    private func handleIconTap(icon: AppIcon) {
        if !icon.isLocked {
            changeAppIcon(to: icon.iconName)
            selectedIcon = icon.iconName
            selectedIconName = icon.iconName
        } else if let mission = icon.mission {
            showMissionToast(mission: mission)
        }
    }
    
    private func handleThemeSelection(theme: AppTheme) {
        if !theme.isLocked {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTheme = theme
                selectedThemeName = theme.name
            }
        } else if let mission = theme.mission {
            showMissionToast(mission: mission)
        }
    }
    
    private func handleFontSelection(font: AppFont) {
        if !font.isLocked {
            currentFont = font
            selectedFontName = font.name
        } else if let mission = font.mission {
            showMissionToast(mission: mission)
        }
    }
    
    private func showMissionToast(mission: Mission) {
        let progress = getProgress(for: mission)
        
        if progress >= mission.goal {
            // Handle unlock animation here
            return
        }
        
        toastMessage = mission.description
        toastProgress = progress
        toastGoal = mission.goal
        toastDifficulty = mission.difficulty
        toastID = UUID()
        
        withAnimation {
            showToast = true
        }
        
        toastDismissWorkItem?.cancel()
        let newDismissWorkItem = DispatchWorkItem {
            withAnimation {
                showToast = false
            }
        }
        toastDismissWorkItem = newDismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: newDismissWorkItem)
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
}

// MARK: - Group Section View

struct TierSectionView: View {
    let title: String
    let icons: [AppIcon]
    let themes: [AppTheme]
    let fonts: [AppFont]
    let theme: AppTheme
    let selectedIcon: String?
    let selectedTheme: AppTheme
    let selectedFont: AppFont
    let iconColumns: [GridItem]
    let themeColumns: [GridItem]
    let onIconTap: (AppIcon) -> Void
    let onThemeTap: (AppTheme) -> Void
    let onFontTap: (AppFont) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group Title
            Text(title)
                .font(.custom("Nunito-Black", size: 24))
                .foregroundColor(theme.textColor)
                .padding(.leading, 4)
            
            // App Icons Section
            if !icons.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if icons.count > 1 {
                        Text("App Icons")
                            .font(.custom("Nunito-Black", size: 18))
                            .foregroundColor(theme.accentColor)
                            .padding(.leading, 4)
                    }
                    
                    LazyVGrid(columns: iconColumns, spacing: 16) {
                        ForEach(icons) { icon in
                            AppIconGridItem(
                                icon: icon,
                                theme: theme,
                                isSelected: selectedIcon == icon.iconName || (selectedIcon == nil && icon.iconName == nil)
                            ) {
                                onIconTap(icon)
                            }
                        }
                    }
                }
            }
            
            // Themes Section
            if !themes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if themes.count > 1 {
                        Text("Themes")
                            .font(.custom("Nunito-Black", size: 18))
                            .foregroundColor(theme.accentColor)
                            .padding(.leading, 4)
                    }
                    
                    LazyVGrid(columns: themeColumns, spacing: 16) {
                        ForEach(themes) { themeItem in
                            ThemeCard(
                                theme: themeItem,
                                currentTheme: theme,
                                isSelected: selectedTheme.name == themeItem.name
                            ) {
                                onThemeTap(themeItem)
                            }
                        }
                    }
                }
            }
            
            // Fonts Section
            if !fonts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if fonts.count > 1 {
                        Text("Fonts")
                            .font(.custom("Nunito-Black", size: 18))
                            .foregroundColor(theme.accentColor)
                            .padding(.leading, 4)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(fonts) { font in
                            FontCard(
                                font: font,
                                theme: theme,
                                isSelected: selectedFont.name == font.name
                            ) {
                                onFontTap(font)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AppIconGridItem: View {
    let icon: AppIcon
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [theme.backgroundColor, theme.primaryColor.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: theme.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Image(icon.previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                if icon.isLocked {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        
                        if let mission = icon.mission {
                            HStack(spacing: 2) {
                                Image(systemName: mission.difficulty.icon)
                                    .font(.caption2)
                                Text(mission.difficulty.rawValue)
                                    .font(.custom("Nunito-Black", size: 10))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(mission.difficulty.color)
                        }
                    }
                }
            }
            .frame(width: 80, height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                        LinearGradient(gradient: Gradient(colors: [theme.accentColor, theme.primaryColor]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(gradient: Gradient(colors: [Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 3 : 0
                    )
                    .shadow(color: isSelected ? theme.accentColor : Color.clear, radius: 8, x: 0, y: 0)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            Text(icon.iconName?.replacingOccurrences(of: "_AppIcon", with: "") ?? "Default")
                .font(.custom("Nunito-Black", size: 12))
                .fontWeight(.medium)
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct ThemeCard: View {
    let theme: AppTheme
    let currentTheme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.primaryColor.opacity(0.8),
                                theme.secondaryColor.opacity(0.6),
                                theme.accentColor.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                
                VStack {
                    Image(systemName: theme.icon)
                        .font(.title)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 2) {
                        Circle().fill(theme.primaryColor).frame(width: 8, height: 8)
                        Circle().fill(theme.secondaryColor).frame(width: 8, height: 8)
                        Circle().fill(theme.accentColor).frame(width: 8, height: 8)
                    }
                }
                
                if theme.isLocked {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.7))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        
                        if let mission = theme.mission {
                            HStack(spacing: 2) {
                                Image(systemName: mission.difficulty.icon)
                                    .font(.caption)
                                Text(mission.difficulty.rawValue)
                                    .font(.custom("Nunito-Black", size: 10))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(mission.difficulty.color)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(currentTheme.accentColor, lineWidth: isSelected ? 3 : 0)
                    .shadow(color: isSelected ? currentTheme.accentColor : Color.clear, radius: 8, x: 0, y: 0)
            )
            
            VStack(spacing: 4) {
                Text(theme.name)
                    .font(.custom("Nunito-Black", size: 16))
                    .foregroundColor(currentTheme.textColor)
                
                if let mission = theme.mission {
                    Text(mission.description)
                        .font(.custom("Nunito-Black", size: 11))
                        .foregroundColor(currentTheme.textColor.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

struct FontCard: View {
    let font: AppFont
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(font.name)
                    .font(.custom("Nunito-Black", size: 18))
                    .foregroundColor(theme.textColor)
                
                Text(font.previewText)
                    .font(font.font(size: 24))
                    .foregroundColor(theme.accentColor)
                
                if let mission = font.mission {
                    HStack(spacing: 4) {
                        Image(systemName: mission.difficulty.icon)
                            .font(.caption)
                            .foregroundColor(mission.difficulty.color)
                        Text(mission.description)
                            .font(.custom("Nunito-Black", size: 12))
                            .foregroundColor(theme.textColor.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(theme.backgroundColor)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(theme.accentColor, lineWidth: isSelected ? 3 : 1)
                    )
                
                if font.isLocked {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                } else {
                    Text("Aa")
                        .font(font.font(size: 20))
                        .foregroundColor(theme.accentColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? theme.accentColor : theme.textColor.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: theme.accentColor.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 8 : 4, x: 0, y: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}
