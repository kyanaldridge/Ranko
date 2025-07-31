//
//  DefaultList_Vote.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import AlgoliaSearchClient

struct DefaultListVote: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject private var user_data = UserInformation.shared
    
    /// The existing list’s ID in your RTDB
    let listID: String
    
    // MARK: – Editable state
    @State private var rankoName: String        = ""
    @State private var rankoDescription: String      = ""
    @State private var isPrivate: Bool          = false
    @State private var creatorID: String = ""
    @State private var creatorName: String = ""
    @State private var rankoType: String        = ""
    @State private var category: CategoryChip?  = nil
    @State private var selectedRankoItems: [AlgoliaRankoItem] = []
    @State private var profileImage: UIImage?
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var spectateProfile: Bool = false
    
    // MARK: – UI state
    @State private var activeAction: DefaultListAction? = nil
    @State private var showCancelAlert = false
    
    @State private var hasVoted = false
    @State private var showAlreadyVotedAlert = false
    @State private var showVoteSheet = false
    
    init(listID: String, creatorID: String) {
        self.listID = listID
    }
    
    var buttonSymbols: [String: String] {
        [
            "Vote":       "archivebox",
            "Copy":       "plus.square.on.square.fill",
            "Share":      "paperplane",
            "Exit":       "door.left.hand.open"
        ]
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: — Main scrollable content
            ScrollView {
                VStack(spacing: 12) {
                    header
                    descriptionView
                    categoryPrivacyView
                    Divider()
                    selectedItemsSection
                    Spacer(minLength: 60) // leave room for bottom bar
                }
                .padding(.top, 30)
                .padding(.horizontal, 15)
            }
            
            // MARK: — Bottom Bar Overlay
            bottomBar
                .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(item: $activeAction, content: sheetContent)
        .onAppear {
            fetchCreatorName()
            loadList(listID: listID)
            checkIfUserHasVoted()
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailViewSpectate(
                items: selectedRankoItems,
                initialItem: item,
                listID: listID
            )
        }
        .sheet(isPresented: $spectateProfile) {
            SpecProfileView(userID: creatorID)
        }
    }
    
    // MARK: – Load existing list
    private func loadList(listID: String) {
        let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                  apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        let index = client.index(withName: "RankoLists")

        index.getObject(withID: ObjectID(rawValue: listID)) { (result: Result<Hit<JSON>, Error>) in
            switch result {
            case .success(let hit):
                do {
                    // Try encoding the hit's object and decode as dictionary
                    let data = try JSONEncoder().encode(hit.object)
                    guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("❌ Could not cast JSON to dictionary")
                        return
                    }

                    let name = dict["RankoName"] as? String ?? ""
                    let description = dict["RankoDescription"] as? String ?? ""
                    let privacy = dict["RankoPrivacy"] as? Bool ?? false
                    let type = dict["RankoType"] as? String ?? ""
                    let creator = dict["RankoUserID"] as? String ?? ""
                    let categoryName = dict["RankoCategory"] as? String ?? ""
                    let itemsDict = dict["RankoItems"] as? [String: [String: Int]] ?? [:]

                    let itemIDs = Array(itemsDict.keys)

                    DispatchQueue.main.async {
                        self.rankoName = name
                        self.rankoDescription = description
                        self.isPrivate = privacy
                        self.rankoType = type
                        self.creatorID = creator

                        let allChips = categoryChipsByCategory.values.flatMap { $0 }
                        self.category = allChips.first {
                            $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
                        }

                        self.fetchItemsFromFirebase(itemIDs: itemIDs, listID: listID, itemMetadata: itemsDict)
                    }

                } catch {
                    print("❌ JSON decoding failed: \(error.localizedDescription)")
                }

            case .failure(let error):
                print("❌ Failed to fetch list from Algolia: \(error)")
            }
        }
    }
    
    private func fetchItemsFromFirebase(itemIDs: [String], listID: String, itemMetadata: [String: [String: Int]]) {
        let ref = Database.database().reference().child("ItemData")

        ref.observeSingleEvent(of: .value) { snapshot,snapShot  in
            var loadedItems: [AlgoliaRankoItem] = []

            for itemID in itemIDs {
                if let itemSnap = snapshot.childSnapshot(forPath: itemID).value as? [String: Any],
                   let name = itemSnap["ItemName"] as? String,
                   let desc = itemSnap["ItemDescription"] as? String,
                   let image = itemSnap["ItemImage"] as? String {

                    let meta = itemMetadata[itemID] ?? [:]
                    let rank = meta["Rank"] ?? 9999
                    let votes = meta["Votes"] ?? 0

                    let record = AlgoliaItemRecord(
                        objectID: itemID,
                        ItemName: name,
                        ItemDescription: desc,
                        ItemCategory: "",
                        ItemImage: image
                    )

                    let item = AlgoliaRankoItem(
                        id: itemID,
                        rank: rank,
                        votes: votes,
                        record: record
                    )

                    loadedItems.append(item)
                }
            }

            DispatchQueue.main.async {
                self.selectedRankoItems = loadedItems.sorted { $0.rank < $1.rank }
            }
        }
    }
    
    // MARK: — Fetchers
    private func loadProfileImage() {
//        let ref = Database.database().reference()
//            .child("UserData")
//            .child(creatorID)
//            .child("ProfilePicture")
//        ref.getData { _, snap in
//            if let path = snap?.value as? String {
//                Storage.storage().reference().child(path)
//                    .getData(maxSize: 2*1024*1024) { data, _ in
//                        if let data = data, let ui = UIImage(data: data) {
//                            profileImage = ui
//                        }
//                }
//            }
//        }
    }
    
    private func fetchCreatorName() {
//        let ref = Database.database().reference()
//            .child("UserData")
//            .child(creatorID)
//            .child("UserName")
//        ref.observeSingleEvent(of: .value) { snap in
//            creatorName = snap.value as? String ?? "Unknown"
//        }
//        loadProfileImage()
    }
    
    
    
    // MARK: – Main UI pieces (copied from DefaultListView)
    private var header: some View {
        HStack {
            Text(rankoName)
                .font(.title2)
                .fontWeight(.black)
            Spacer()
        }
    }
    
    private var descriptionView: some View {
        HStack {
            if rankoDescription.isEmpty {
                Text("No description yet…")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text(rankoDescription)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    
    private var categoryPrivacyView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                HStack {
                    Image(systemName: isPrivate ? "lock.fill" : "globe")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.leading, 7)
                    Text(isPrivate ? "Private" : "Public")
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.trailing, 7)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPrivate ? .orange : .blue)
                )
                if let category = category {
                    HStack {
                        
                        Image(systemName: category.icon)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 5)
                            .padding(.leading, 7)
                        Text(category.name)
                            .foregroundColor(.white)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.trailing, 7)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryChipIconColors[category.name] ?? .gray)
                    )
                }
               
                
                HStack(spacing: 7) {
                    Group {
                        if let img = profileImage {
                            Image(uiImage: img)
                                .resizable()
                        } else {
                            SkeletonView(Circle())
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    Text(creatorName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.9))
                }
                .onTapGesture {
                    spectateProfile = true
                }
                Spacer()
            }
        }
    }
    
    private var selectedItemsSection: some View {
        VStack {
            ScrollView {
                // Always iterate over the latest sorted order
                let sortedItems = selectedRankoItems.sorted(by: sortByVotesThenRank)
                
                ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                    DefaultListVoteItemRow(item: item, votePosition: index + 1)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    private func sortByVotesThenRank(_ a: AlgoliaRankoItem, _ b: AlgoliaRankoItem) -> Bool {
        if a.votes != b.votes {
            return a.votes > b.votes  // More votes first
        } else {
            return a.rank < b.rank    // Lower rank wins tie
        }
    }
    
    // MARK: — Bottom Bar Overlay
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(DefaultListAction.allCases) { action in
                        if action == .exit {
                            Button {
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                dismiss()
                            } label: {
                                VStack(spacing: 0) {
                                    Image(systemName: "door.left.hand.open")
                                        .font(.system(size: 13, weight: .black, design: .default))
                                        .frame(height: 20)
                                        .padding(.bottom, 6)
                                    Text("Exit")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .frame(minWidth: 20)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button {
                                switch action {
                                case .copy, .share, .vote:
                                    withAnimation {
                                        activeAction = action
                                    }
                                default:
                                    break
                                }
                            } label: {
                                VStack(spacing: 0) {
                                    if let symbol = buttonSymbols[action.rawValue] {
                                        Image(systemName: symbol)
                                            .font(.system(size: 13, weight: .black, design: .default))
                                            .frame(height: 20)
                                            .padding(.bottom, 6)
                                    }
                                    Text(action.rawValue)
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .frame(minWidth: 20)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 17)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 8)
            )
        }
    }
    
    // MARK: — Check voting status
    private func checkIfUserHasVoted() {
        let safeUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let voterRef = Database.database().reference()
            .child("RankoData")
            .child(listID)
            .child("RankoVoters")
            .child(safeUID)
        voterRef.observeSingleEvent(of: .value) { snap in
            hasVoted = snap.exists()
        }
    }
    
    // MARK: – Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for action: DefaultListAction) -> some View {
        switch action {
        case .vote:
            VoteNowView(
                  hasVoted: hasVoted,
                  listID: listID,
                  items: selectedRankoItems
            ) {
                // After successful submission, mark voted and reload
                hasVoted = true
                showVoteSheet = false
            }
        case .copy:
            DefaultListView(
                rankoName: rankoName,
                description: rankoDescription,
                isPrivate: isPrivate,
                category: category,
                selectedRankoItems: selectedRankoItems
            ) { updatedItem in
                // no-op in preview
            }
        case .share:
            DefaultListShareImage(rankoName: rankoName, items: selectedRankoItems)
        case .exit:
            EmptyView()
        }
    }
}

// Re-use DefaultListView’s helpers and enum:
extension DefaultListVote {
    enum DefaultListAction: String, Identifiable, CaseIterable {
        var id: String { rawValue }
        case vote   = "Vote"
        case copy   = "Copy"
        case share  = "Share"
        case exit   = "Exit"
    }
}

struct VoteNowView: View {
    // MARK: - Inputs
    let hasVoted: Bool
    let listID: String
    let items: [AlgoliaRankoItem]                 // full item data
    var onComplete: () -> Void            // callback after submit

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
    init(hasVoted: Bool, listID: String, items: [AlgoliaRankoItem], onComplete: @escaping () -> Void) {
        self.hasVoted = hasVoted
        self.listID = listID
        self.items = items
        self.onComplete = onComplete
        // start all allocations at zero
        _voteAllocations = State(initialValue:
            Dictionary(uniqueKeysWithValues: items.map { ($0.id, 0) })
        )
    }

    var body: some View {
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
                            
                            // Text info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.itemName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(item.itemDescription)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Vote Stepper
                            Stepper(
                                "\(voteAllocations[item.id]!)",               // <-- label shows current votes
                                value: Binding(
                                    get: { voteAllocations[item.id]! },
                                    set: { new in
                                        // enforce max 10 total
                                        if totalAllocated - voteAllocations[item.id]! + new <= 10 {
                                            voteAllocations[item.id] = new
                                        }
                                    }
                                ),
                                in: 0...10
                            )
                            .frame(width: 140)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 1)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Cast Your Votes (\(totalAllocated)/10)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        showSubmitWarning = true
                    }
                    .disabled(totalAllocated == 0 || isSubmitting)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        let safeUID = Auth.auth().currentUser?.uid ?? ""
        let group = DispatchGroup()
        
        var firebaseVoteCounts: [String: Int] = [:]  // [ItemID: totalVotes]
        
        for (itemID, voteCount) in voteAllocations where voteCount > 0 {
            let itemVotesRef = db
                .child("ItemData")
                .child(itemID)
                .child("ItemVotes")
            
            // 1. Write each vote to Firebase
            for i in 1...voteCount {
                group.enter()
                let voteKey = "\(safeUID)-\(i)"
                itemVotesRef.child(voteKey).setValue(1) { _, _ in
                    group.leave()
                }
            }
            
            // 2. After writing, count total votes
            group.enter()
            itemVotesRef.observeSingleEvent(of: .value) { snap in
                let totalVotes = Int(snap.childrenCount)
                firebaseVoteCounts[itemID] = totalVotes
                group.leave()
            }
        }
        
        // 3. Mark user as voter in Firebase
        group.enter()
        db.child("RankoData")
            .child(listID)
            .child("RankoVoters")
            .child(safeUID)
            .setValue(true) { _, _ in
                group.leave()
            }
        
        // 4. After Firebase, update Algolia
        group.notify(queue: .main) {
            let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                      apiKey:  APIKey(rawValue: Secrets.algoliaAPIKey))
            let index = client.index(withName: "RankoLists")

            // Step 1: Fetch the current object
            index.getObject(withID: ObjectID(rawValue: listID)) { (result: Result<Hit<JSON>, Error>) in
                switch result {
                case .success(let hit):
                    do {
                        // Convert JSON to dictionary
                        let data = try JSONEncoder().encode(hit.object)
                        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              var rankoItems = dict["RankoItems"] as? [String: [String: Any]] else {
                            print("❌ Failed to decode RankoItems from Algolia object")
                            return
                        }

                        // Step 2: Update vote counts in-place
                        for (itemID, voteCount) in firebaseVoteCounts {
                            if rankoItems[itemID] != nil {
                                rankoItems[itemID]?["Votes"] = voteCount
                            }
                        }

                        // Step 3: Push updated RankoItems back to Algolia
                        let update = PartialUpdate.update(
                            attribute: "RankoItems",
                            value: try JSON(jsonObject: rankoItems)
                        )

                        index.partialUpdateObject(
                            withID: ObjectID(rawValue: listID),
                            with: update,
                            completion: { result in
                                switch result {
                                case .success:
                                    print("✅ Votes updated in nested RankoItems")
                                case .failure(let error):
                                    print("❌ Error updating Algolia:", error.localizedDescription)
                                }

                                isSubmitting = false
                                onComplete()
                                dismiss()
                            }
                        )

                    } catch {
                        print("❌ JSON processing error:", error.localizedDescription)
                        isSubmitting = false
                    }

                case .failure(let error):
                    print("❌ Could not fetch list from Algolia:", error.localizedDescription)
                    isSubmitting = false
                }
            }
        }
    }
}


// MARK: – Row Subview for a Selected Item
struct VotedItemRow: View {
    let item: AlgoliaRankoItem
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
