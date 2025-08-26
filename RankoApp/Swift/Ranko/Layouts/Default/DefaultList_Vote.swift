//
//  DefaultList_Vote.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import Foundation
import AlgoliaSearchClient

struct DefaultListVote: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared

    // Required property
    let listID: String

    // Optional editable properties with defaults
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    @State private var creatorID: String
    @State private var creatorName: String
    @State private var creatorImage: UIImage?

    // Sheets & states
    @State private var spectateProfile: Bool = false
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var userVoted = false
    @State var showSaveRankoSheet = false
    @State var showVoteSheet = false
    @State var showCloneSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var toastID = UUID()

    @State private var activeTab: DefaultListVoteTab = .clone
    @State private var triggerHaptic: Bool = false
    @State private var selectedRankoItems: [RankoItem] = []
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: ((RankoItem) -> Void)? = nil

    // MARK: - Init now only requires listID
    init(
        listID: String,
        creatorID: String = "",
        creatorName: String = "",
        creatorImage: UIImage? = nil,
        rankoName: String = "",
        description: String = "",
        isPrivate: Bool = false,
        category: CategoryChip? = CategoryChip(name: "Unknown", icon: "questionmark.circle.fill", category: "Unknown", synonym: ""),
        selectedRankoItems: [RankoItem] = []
    ) {
        self.listID = listID
        self.creatorID = creatorID
        _creatorName = State(initialValue: creatorName)
        _creatorImage = State(initialValue: creatorImage)
        _rankoName = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate = State(initialValue: isPrivate)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xFFF5E1).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 7) {
                    HStack {
                        Text(rankoName)
                            .font(.system(size: 28, weight: .black, design: .default))
                            .foregroundColor(Color(hex: 0x6D400F))
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    
                    HStack {
                        Text(description.isEmpty ? "No description yet…" : description)
                            .lineLimit(3)
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0x925611))
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.leading, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: isPrivate ? "lock.fill" : "globe.americas.fill")
                                    .font(.system(size: 12, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                    .padding(.leading, 10)
                                Text(isPrivate ? "Private" : "Public")
                                    .font(.system(size: 12, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                    .padding(.trailing, 10)
                                    .padding(.vertical, 8)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: 0xF2AB69))
                            )
                            
                            if let cat = category {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.leading, 10)
                                    Text(cat.name)
                                        .font(.system(size: 12, weight: .bold, design: .default))
                                        .foregroundColor(.white)
                                        .padding(.trailing, 10)
                                        .padding(.vertical, 8)
                                    
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(categoryChipIconColors[cat.name] ?? .gray)
                                        .opacity(0.6)
                                )
                            }
                            
                            HStack(spacing: 7) {
                                Group {
                                    if let img = creatorImage {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.white)
                                                .frame(width: 18, height: 18)
                                            Image(uiImage: img)
                                                .resizable()
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.white.opacity(0.8))
                                                .frame(width: 18, height: 18)
                                            HStack {
                                                Spacer()
                                                ThreeRectanglesAnimation(rectangleWidth: 4, rectangleMaxHeight: 12, rectangleSpacing: 1, rectangleCornerRadius: 1, animationDuration: 0.4)
                                                    .frame(height: 18)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .frame(width: 18, height: 18)
                                .padding(.leading, 10)
                                Text(creatorName)
                                    .font(.system(size: 12, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                    .padding(.trailing, 10)
                                    .padding(.vertical, 8)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: 0xF2AB69))
                            )
                            .onTapGesture {
                                spectateProfile = true
                            }
                        }
                        .padding(.top, 5)
                        .padding(.leading, 20)
                    }
                }
                .padding(.bottom, 5)
            
                VStack {
                    ScrollView {
                        let sortedItems = selectedRankoItems.sorted(by: sortByVotesThenRank)
                        
                        ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                            DefaultListVoteItemRow(item: item, votePosition: index + 1)
                                .onTapGesture {
                                    selectedItem = item
                                }
                                .sheet(isPresented: $showEditItemSheet) {
                                    // Determine which item is centered
                                    EditItemView(
                                        item: item,
                                        listID: listID
                                    ) { newName, newDesc in
                                        // build updated record & item
                                        let rec = item.record
                                        let updatedRecord = RankoRecord(
                                            objectID: rec.objectID,
                                            ItemName: newName,
                                            ItemDescription: newDesc,
                                            ItemCategory: "",
                                            ItemImage: rec.ItemImage
                                        )
                                        let updatedItem = RankoItem(
                                            id: item.id,
                                            rank: item.rank,
                                            votes: item.votes,
                                            record: updatedRecord
                                        )
                                        // callback to parent
                                        onSave!(updatedItem)
                                    }
                                }
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 70)
                    }
                    Spacer()
                }
            }
            
            if showToast {
                ComingSoonToast(
                    isShown: $showToast,
                    title: "🚧 Saving Rankos Feature Coming Soon",
                    message: toastMessage,
                    icon: Image(systemName: "hourglass"),
                    alignment: .bottom
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toastID)
                .padding(.bottom, 12)
                .zIndex(1)
            }
            
            VStack {
                Spacer()
                Rectangle()
                    .frame(height: 90)
                    .foregroundColor(tabBarPresent ? Color(hex: 0xFFEBC2) : .white)
                    .blur(radius: 23)
                    .opacity(tabBarPresent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: tabBarPresent) // ✅ Fast fade animation
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()
            
        }
        .fullScreenCover(isPresented: $showVoteSheet) {
            VoteNowView(
                hasVoted: userVoted,
                listID:      listID,
                items:       selectedRankoItems,
                onComplete:  {
                    showTabBar = false
                    tabBarPresent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showTabBar = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            tabBarPresent = true
                        }
                    }
                },
                onCancel:  {
                    showTabBar = false
                    tabBarPresent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showTabBar = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            tabBarPresent = true
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCloneSheet) {
            DefaultListView(
                rankoName: rankoName,
                description: description,
                isPrivate: isPrivate,
                category: category,
                selectedRankoItems: selectedRankoItems
            ) { updatedItem in
                // no-op in preview
            }
        }
        .onChange(of: showCloneSheet) { _, isPresented in
            // when it flips from true → false…
            if !isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastID)
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(DefaultListVoteTab.visibleCases, id: \.rawValue) { tab in
                        VStack(spacing: 6) {
                            Image(systemName: tab.symbolImage)
                                .font(.title3)
                                .symbolVariant(.fill)
                                .frame(height: 28)
                            
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color(hex: 0x925610))
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                        .onTapGesture {
                            activeTab = tab
                            switch tab {
                            case .vote:
                                if !userVoted {
                                    showVoteSheet = true
                                }
                            case .save:
                                if showToast {
                                    withAnimation {
                                        showToast = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showComingSoonToast(for: "Save Rankos")
                                    }
                                } else {
                                    showComingSoonToast(for: "Save Rankos")
                                }
                            case .clone:
                                showCloneSheet = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabBarPresent = false
                                }
                            case .exit:
                                let haptic = UIImpactFeedbackGenerator(style: .medium)
                                haptic.prepare()
                                haptic.impactOccurred()
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .interactiveDismissDisabled(true)
            .presentationDetents([.height(80)])
            .presentationBackground((Color(hex: 0xfff9ee)))
            .presentationBackgroundInteraction(.enabled)
            .onAppear {
                tabBarPresent = false      // Start from invisible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tabBarPresent = true
                    }
                }
            }
            .onDisappear {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tabBarPresent = false
                }
            }
        }
        .onAppear {
            fetchCreatorName()
            loadListFromFirebase()
            checkUserVoted()
            
            print("Page Loaded: DefaultListVote")
            print("ListID: \(listID)")
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailViewSpectate(
                items: selectedRankoItems,
                initialItem: item,
                listID: listID
            )
        }
        .sheet(isPresented: $spectateProfile) {
            ProfileSpectateView(userID: creatorID)
        }
    }
    
    private func sortByVotesThenRank(_ a: RankoItem, _ b: RankoItem) -> Bool {
        if a.votes != b.votes {
            return a.votes > b.votes  // More votes first
        } else {
            return a.rank < b.rank    // Lower rank wins tie
        }
    }
    
    private func checkUserVoted() {
        let db = Database.database().reference()
        let voterRef = db
            .child("RankoData")
            .child(listID)
            .child("RankoVoters")
            .child(user_data.userID)
        
        voterRef.observeSingleEvent(of: .value) { snap in
            if snap.exists() {
                userVoted = true
            }
        }
    }

    private func showComingSoonToast(for feature: String) {
        switch feature {
        case "Save Rankos":
                toastMessage = "Save Community or Friends Rankos Straight To Your Profile - Coming Soon!"
                toastID = UUID()
                showToast = true
                
            default:
                toastMessage = "New Feature Coming Soon!"
                toastID = UUID()
                showToast = true
            }
        
        // Cancel any previous dismiss
        toastDismissWorkItem?.cancel()
        
        // Schedule dismiss after 4 seconds
        let newDismissWorkItem = DispatchWorkItem {
            withAnimation { showToast = false }
        }
        toastDismissWorkItem = newDismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: newDismissWorkItem)
    }
    
    // MARK: — Fetchers
    private func loadProfileImage() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("UserProfilePicture")
            .child("UserProfilePicturePath")
        ref.getData { _, snap in
            if let path = snap?.value as? String {
                Storage.storage().reference().child("profilePictures").child(path)
                    .getData(maxSize: 2*1024*1024) { data, _ in
                        if let data = data, let ui = UIImage(data: data) {
                            creatorImage = ui
                        }
                }
            }
        }
    }
    
    private func fetchCreatorName() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("UserDetails")
            .child("UserName")
        ref.observeSingleEvent(of: .value) { snap in
            creatorName = snap.value as? String ?? "Unknown"
        }
        loadProfileImage()
    }
    
    private func loadListFromFirebase() {
        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(listID)

        listRef.observeSingleEvent(of: .value,
                                   with: { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("⚠️ No data at RankoData/\(listID)")
                return
            }

            DispatchQueue.main.async {
                // — map your top-level fields…
                self.rankoName   = data["RankoName"]        as? String ?? ""
                self.description = data["RankoDescription"] as? String ?? ""
                self.isPrivate   = data["RankoPrivacy"]     as? Bool   ?? false
                self.creatorID   = data["RankoUserID"]      as? String ?? ""

                if let catName = data["RankoCategory"] as? String {
                    let allChips = categoryChipsByCategory.values.flatMap { $0 }
                    self.category = allChips.first {
                        $0.name.caseInsensitiveCompare(catName) == .orderedSame
                    }
                }

                // — map your items…
                if let itemsDict = data["RankoItems"] as? [String: [String: Any]] {
                    var loaded: [RankoItem] = []
                    for (_, itemData) in itemsDict {
                        guard
                            let id    = itemData["ItemID"]          as? String,
                            let name  = itemData["ItemName"]        as? String,
                            let desc  = itemData["ItemDescription"] as? String,
                            let image = itemData["ItemImage"]       as? String,
                            let rank  = itemData["ItemRank"]        as? Int,
                            let votes = itemData["ItemVotes"]       as? Int
                        else { continue }
                        
                        let record = RankoRecord(
                            objectID: id,
                            ItemName: name,
                            ItemDescription: desc,
                            ItemCategory: "",      // adjust if you store item categories
                            ItemImage: image
                        )

                        let item = RankoItem(
                            id: id,
                            rank: rank,
                            votes: votes,
                            record: record
                        )
                        loaded.append(item)
                    }
                    self.selectedRankoItems = loaded.sorted { $0.rank < $1.rank }
                }
            }
        },
        withCancel: { error in
            print("❌ Firebase load error:", error.localizedDescription)
        })
    }
    // Item Helpers
    private func delete(_ item: RankoItem) {
        selectedRankoItems.removeAll { $0.id == item.id }
        normalizeRanks()
    }

    private func moveToTop(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.insert(moved, at: 0)
        normalizeRanks()
    }

    private func moveToBottom(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.append(moved)
        normalizeRanks()
    }

    private func normalizeRanks() {
        for index in selectedRankoItems.indices {
            selectedRankoItems[index].rank = index + 1
        }
    }
}

enum DefaultListVoteTab: String, CaseIterable {
    case vote = "Vote"
    case save = "Save Ranko"
    case clone = "Clone"
    case exit = "Exit"
    
    var symbolImage: String {
        switch self {
        case .vote:
            return "checkmark.seal.fill"
        case .save:
            return "bookmark.fill"
        case .clone:
            return "square.fill.on.square.fill"
        case .exit:
            return "door.left.hand.closed"
        }
    }
    
    static var visibleCases: [DefaultListVoteTab] {
        return [.vote, .save, .clone, .exit]
    }
}


struct VoteNowView: View {
    @StateObject private var user_data = UserInformation.shared
    // MARK: - Inputs
    let totalVotesAllowed: Int = 15
    let hasVoted: Bool
    let listID: String
    let items: [RankoItem]                 // full item data
    var onComplete: () -> Void            // callback after submit
    var onCancel: () -> Void

    // MARK: - Internal State
    @Environment(\.dismiss) private var dismiss
    @State private var voteAllocations: [String:Int]
    @State private var showSubmitWarning = false
    @State private var isSubmitting = false

    // Total votes allocated
    private var totalAllocated: Int {
        voteAllocations.values.reduce(0, +)
    }

    // MARK: - Initializer
    init(hasVoted: Bool, listID: String, items: [RankoItem], onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.hasVoted = hasVoted
        self.listID = listID
        self.items = items
        self.onComplete = onComplete
        self.onCancel = onCancel
        // start all allocations at zero
        _voteAllocations = State(initialValue:
            Dictionary(uniqueKeysWithValues: items.map { ($0.id, 0) })
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF2651E), Color(hex: 0xF08124), Color(hex: 0xF2651E)], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
            Group {
                if hasVoted {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("You have already voted!")
                            .font(.headline)
                    }
                } else {
                    votingList
                }
            }
            if isSubmitting {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Submitting votes…")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .shadow(radius: 10)
                )
            }
        }
    }

    // MARK: - Voting List
    private var votingList: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            // Item image
                            AsyncImage(url: URL(string: item.itemImage)) { phase in
                                switch phase {
                                case .empty:
                                    Color.gray.frame(width: 50, height: 50)
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    Color.gray.frame(width: 50, height: 50)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.4))
                            )
                            
                            // Text info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.itemName)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(item.itemDescription)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                // current allocation / original votes
                                VStack {
                                    Text("\(voteAllocations[item.id]!)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("\(item.votes)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .fixedSize()    // shrink to fit
                                
                                // the little “–” and “+”
                                Stepper("", value: Binding(
                                    get: { voteAllocations[item.id]! },
                                    set: { new in
                                        if totalAllocated - voteAllocations[item.id]! + new <= totalVotesAllowed {
                                            voteAllocations[item.id] = new
                                        }
                                    }
                                ), in: 0...totalVotesAllowed)
                                .labelsHidden() // hide the empty label
                                .fixedSize()    // minimal intrinsic size
                                .padding(.leading, 10)
                                .foregroundColor(.white)
                            }
                            
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color(hex: 0xFB8C24), Color(hex: 0xFC7C20)], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: Color(hex: 0xF38024), radius: 3, x: 0, y: 0)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        showSubmitWarning = true
                    }
                    .disabled(totalAllocated == 0 || isSubmitting)
                }
                ToolbarItemGroup(placement: .principal) {
                    VStack(alignment: .center) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("\(totalAllocated)")
                                .font(.system(size: 25, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.trailing, 3)
                            Text("/ \(totalVotesAllowed)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.trailing, 10)
                        }
                        Text("VOTES USED")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 15)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .alert("Confirm Submission", isPresented: $showSubmitWarning) {
                Button("Submit", role: .destructive) {
                    submitVotes()
                }
                Button("Go Back", role: .cancel) { }
            } message: {
                Text("Once you submit, you cannot vote again. Proceed?")
            }
        }
    }

    // MARK: - Submit Votes
    private func submitVotes() {
        isSubmitting = true
        let db = Database.database().reference()
        let group = DispatchGroup()
        
        for (itemID, voteCount) in voteAllocations where voteCount > 0 {
            let itemVotesRef = db
                .child("RankoData")
                .child(listID)
                .child("RankoItems")
                .child(itemID)
                .child("ItemVotes")

            // Make sure we wrap the whole increment in one transaction.
            group.enter()
            itemVotesRef.runTransactionBlock({ currentData in
                // Read current value (or 0 if none)
                var currentVotes = currentData.value as? Int ?? 0
                // Add the newly allocated votes
                currentVotes += voteCount
                // Set the new total
                currentData.value = currentVotes
                return TransactionResult.success(withValue: currentData)
            }) { error, committed, snapshot in
                if let error = error {
                    print("⚠️ Vote‐increment transaction failed:", error.localizedDescription)
                }
                group.leave()
            }
        }
        
        // 3. Mark user as voter in Firebase
        group.enter()
        db.child("RankoData")
            .child(listID)
            .child("RankoVoters")
            .child(user_data.userID)
            .setValue(true) { _, _ in
                group.leave()
            }
    }
}

// MARK: – Row Subview for a Selected Item
struct VotedItemRow: View {
    let item: RankoItem
    let position: Int   // 1-based vote ranking

    private var badge: some View {
        Group {
            switch position {
            case 1: Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.body).padding(3)
            case 2: Image(systemName: "2.circle.fill").foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.body).padding(3)
            case 3: Image(systemName: "3.circle.fill").foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.body).padding(3)
            default: Text("\(position)").font(.caption).padding(5).fontWeight(.heavy)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Color.gray.frame(width: 50, height: 50)
                    @unknown default:
                        EmptyView()
                    }
                }
                badge
            }

            

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(item.itemDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
            
            Text("\(item.votes) votes")          // ← show vote count
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding(.horizontal)
    }
}

