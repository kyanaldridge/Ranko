//
//  ExploreView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
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
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastID = UUID()
    @State private var toastDismissWorkItem: DispatchWorkItem?
    
    @State private var showBlindSequence = false
    
    @State private var activeIndex: Int? = 12
    
    let buttons: [MenuItemButtons] = [
        .init(title: "Search Rankos", icon: "magnifyingglass", size: 13, message: "Search and filter through all public Rankos from the community – Coming Soon!", color: Color(hex:0xB085FA)),
        .init(title: "Random Picker", icon: "dice.fill", size: 14, message: "Pick a category, set filters, and let Ranko choose random items for you – Coming Soon!", color: Color(hex:0xFF999A)),
        .init(title: "Store", icon: "cart.fill", size: 12, message: "A future Store may let you trade in-game currency for items, themes, and app icons – Stay tuned!", color: Color(hex:0xF1CD41))
    ]
    
    let miniGames: [MiniGame] = [
        .init(name: "Blind Sequence", image: "BlindSequence", color: Color(hex: 0x791401), unlocked: "yes", message: "Maintenance works, please be patient"),
        .init(name: "Keep 'N' Ditch", image: "KeepNDitch", color: Color(hex: 0xFFFFFF), unlocked: "no", message: "Face 10 random items (albums, animals, soft drinks—anything) one at a time and choose to keep or ditch without knowing what’s next. Only 5 can stay and 5 must go, so choose carefully — Keep 'N' Ditch is coming soon!"),
        .init(name: "Outlier", image: "Outlier", color: Color(hex: 0xFFFFFF), unlocked: "no", message: "Find the least popular answers and aim for the lowest score – Outlier is coming soon!"),
        .init(name: "Guessr", image: "Guessr", color: Color(hex: 0xFFFFFF), unlocked: "no", message: "Uncover clues, guess early, and score big – the Guessr mini-game is coming soon!"),
        .init(name: "Coming Soon", image: "ComingSoon", color: Color(hex: 0xFFFFFF), unlocked: "no", message: "More features and exciting mini-games are on the way – stay tuned!")
    ]
    
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
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(buttons) { button in
                                    Button {
                                        showComingSoonToast(button.message)
                                    } label: {
                                        HStack {
                                            Image(systemName: button.icon)
                                                .font(.system(size: 14, weight: .black, design: .default))
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                            Text(button.title)
                                                .font(.custom("Nunito-Black", size: 15))
                                                .foregroundColor(Color(hex: 0xFFFFFF))
                                        }
                                    }
                                    .tint(button.color)
                                    .buttonStyle(.glassProminent)
                                    .matchedTransitionSource(
                                        id: "menuButtons", in: transition
                                    )
                                    .mask(RoundedRectangle(cornerRadius: 15))
                                }
                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                        }
                        
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("👾 Mini Games")
                                    .font(.custom("Nunito-Black", size: 25))
                                    .foregroundStyle(Color(hex: 0x514343))
                                Spacer()
                            }
                            .padding(.bottom, -10)
                            .padding(.top, 10)
                            .padding(.leading, 25)

                            // safe setup without 'guard' in ViewBuilder
                            let original = miniGames
                            let realCount = original.count
                            let duplicateMiniGames = miniGames + miniGames + miniGames + miniGames + miniGames
                            let duplicateCount = duplicateMiniGames.count

                            if realCount == 0 {
                                // fallback ui
                                Text("no mini games yet")
                                    .font(.custom("Nunito-Black", size: 16))
                                    .foregroundStyle(Color(hex: 0x9E9E9C))
                                    .padding(.vertical, 24)
                            } else {
                                // looped data = [last] + original + [first]
                                let looped = [duplicateMiniGames.last!] + duplicateMiniGames + [duplicateMiniGames.first!]

                                VStack(spacing: 16) {
                                    // CAROUSEL
                                    // --- PEEKING CAROUSEL ---
                                    GeometryReader { proxy in
                                        let spacing: CGFloat = 1
                                        let offsetSpace = (proxy.size.width - 230) / 2

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: spacing) {
                                                ForEach(looped.indices, id: \.self) { i in
                                                    GeometryReader { geo in
                                                        let frame = geo.frame(in: .named("carousel"))
                                                        let mid = proxy.size.width / 2
                                                        let distance = abs(frame.midX - mid)
                                                        let scale = max(0.9, 1.0 - (distance / 800))
                                                        let opacity = max(0.5, 1.0 - (distance / 600))

                                                        let game = looped[i]

                                                        VStack(spacing: 15) {
                                                            Image(game.image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 230, height: 230)
                                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                                                .matchedTransitionSource(id: game.name, in: transition)

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
                                                                Text(game.unlocked == "yes" ? "PLAY" : "SOON")
                                                                    .font(.custom("Nunito-Black", size: 22))
                                                                    .foregroundStyle(Color(hex: 0xFFFFFF))
                                                                    .padding(.vertical, 2)
                                                                    .padding(.horizontal, 40)
                                                            }
                                                            .tint(game.unlocked == "yes" ? game.color : Color(hex: 0x9E9E9C))
                                                            .buttonStyle(.glassProminent)
                                                            .mask(RoundedRectangle(cornerRadius: 20))
                                                            .padding(.bottom)
                                                        }
                                                        .scaleEffect(scale)
                                                        .opacity(opacity)
                                                    }
                                                    .frame(width: 230, height: 320)
                                                    .id(i)
                                                }
                                            }
                                            .scrollTargetLayout()
                                            .padding(.leading, offsetSpace)
                                            .onAppear {
                                                DispatchQueue.main.async { activeIndex = 11 }
                                            }
                                        }
                                        .coordinateSpace(name: "carousel")
                                        .scrollTargetBehavior(.viewAligned)
                                        .scrollPosition(id: $activeIndex)
                                    }
                                    .frame(height: 360)
                                    // --- end peeking carousel ---
                                    .onAppear {
                                        // set after layout so it lands dead center
                                        DispatchQueue.main.async { activeIndex = 11 }
                                    }
                                    .onChange(of: activeIndex) { _, new in
                                        guard let i = new else { return }
                                        if i == 0 { withAnimation(.none) { activeIndex = duplicateCount } }
                                        else if i == duplicateCount + 1 { withAnimation(.none) { activeIndex = 1 } }
                                    }

                                    // INDICATOR DOTS
                                    HStack(spacing: 8) {
                                        let current = ((activeIndex ?? 1) - 1 + realCount) % realCount
                                        ForEach(0..<realCount, id: \.self) { idx in
                                            Circle()
                                                .frame(width: idx == current ? 9 : 6, height: idx == current ? 9 : 6)
                                                .opacity(idx == current ? 1.0 : 0.35)
                                                .animation(.easeInOut(duration: 0.2), value: activeIndex)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)          // ✅ dots centered across full width
                                    .padding(.top, -35)
                                }
                            }
                        }
                        .padding(.top, 7)
                        
                        
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("🔥 Trending Today")
                                    .font(.custom("Nunito-Black", size: 25))
                                    .foregroundStyle(Color(hex: 0x514343))
                                Spacer()
                            }
                            .padding(.leading, 25)
                            .padding(.bottom, 0)
                            
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                if isLoadingLists {
                                    // Show 4 skeleton cards
                                    VStack(spacing: 16) {
                                        ForEach(0..<4, id: \.self) { _ in
                                            ExploreListSkeletonViewRow()
                                        }
                                    }
                                    .padding(.top, 10)
                                    .padding(.bottom, 10)
                                    .padding(.leading)
                                } else {
                                    ExploreListsDisplay(
                                        presentFakeRankos: false,
                                        showToast: $showToast,
                                        toastMessage: $toastMessage,
                                        showToastHelper: showComingSoonToast
                                    )
                                }
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .safeAreaPadding(.trailing, 15)
                        }
                        .padding(.top, 7)
                        
                        
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
                    .zoom(sourceID: "Blind Sequence", in: transition)
                )
        }
        .onAppear {
            user_data.userID = Auth.auth().currentUser?.uid ?? "0"
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


struct ExploreListsDisplay: View {
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
        LazyHStack(alignment: .top, spacing: 16) {
            if presentFakeRankos {
                DefaultListExploreView(
                    listData: HomeListsDisplay.mockList1,
                    onCommentTap: { msg in
                        print("Comment tapped with message: \(msg)")
                    }
                )
                DefaultListExploreView(
                    listData: HomeListsDisplay.mockList2,
                    onCommentTap: { msg in
                        print("Comment tapped with message: \(msg)")
                    }
                )
            }
            if isLoading {
                ForEach(0..<4, id: \.self) { _ in
                    ExploreListSkeletonViewRow()
                }
            } else if let errorMessage = errorMessage {
                Text("❌ Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ForEach(lists, id: \.id) { list in
                    if list.type == "group" {
                        GroupListExploreView(listData: list, showToastHelper: { msg in
                            showToastHelper(msg)
                        })
                            .onTapGesture {
                                selectedList = list
                            }
                    } else {
                        DefaultListExploreView(listData: list, onCommentTap: { msg in
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
        .scrollTargetLayout()
        .padding(.top, 10)
        .padding(.bottom, 10)
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

struct DefaultListExploreView: View {
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
        listData.items.sorted { ($1.votes, $0.rank) < ($0.votes, $1.rank) }
    }
    private var firstBlock: [RankoItem] {
        Array(sortedItems.prefix(3))
    }
    private var remainder: [RankoItem] {
        Array(sortedItems)
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
            ProfileSpectateView(userID: (listData.userCreator))
        }
        .sheet(isPresented: $openShareView) {
            ProfileSpectateView(userID: (listData.userCreator))
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
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoLikes", value: AJSON(likes.count)))
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
            (ObjectID(rawValue: listData.id), .update(attribute: "RankoComments", value: AJSON(commentsCount)))
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

struct GroupListExploreView: View {
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
        DefaultListExploreView(listData: RankoList(
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
