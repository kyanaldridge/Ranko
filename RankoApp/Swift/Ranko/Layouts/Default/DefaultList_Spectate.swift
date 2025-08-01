//
//  DefaultList_Spectate.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import InstantSearchCore
import Firebase
import FirebaseAuth
import FirebaseStorage
import Foundation
import AlgoliaSearchClient


struct DefaultListSpectate: View {
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
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false

    @State private var activeTab: AppTab = .addItems
    @State private var selectedRankoItems: [AlgoliaRankoItem] = []
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var itemToEdit: AlgoliaRankoItem? = nil
    @State private var onSave: ((AlgoliaRankoItem) -> Void)? = nil

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
        selectedRankoItems: [AlgoliaRankoItem] = []
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
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text(rankoName)
                            .font(.title)
                            .fontWeight(.black)
                            .fontDesign(.rounded)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    
                    HStack {
                        Text(description.isEmpty ? "No description yet…" : description)
                            .lineLimit(3)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.leading, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: isPrivate ? "lock.fill" : "globe.americas.fill")
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
                            
                            if let cat = category {
                                HStack {
                                    Image(systemName: cat.icon)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 5)
                                        .padding(.leading, 7)
                                    Text(cat.name)
                                        .foregroundColor(.white)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.trailing, 7)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(categoryChipIconColors[cat.name] ?? .gray)
                                )
                            }
                            
                            HStack(spacing: 7) {
                                Group {
                                    if let img = creatorImage {
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
                        .padding(.top, 5)
                        .padding(.leading, 20)
                    }
                }
                .padding(.bottom, 5)
                
                Divider()
                
                VStack {
                    ScrollView {
                        ForEach(selectedRankoItems.sorted { $0.rank < $1.rank }) { item in
                            DefaultListItemRow(item: item)
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
                                        let updatedRecord = AlgoliaItemRecord(
                                            objectID: rec.objectID,
                                            ItemName: newName,
                                            ItemDescription: newDesc,
                                            ItemCategory: "",
                                            ItemImage: rec.ItemImage
                                        )
                                        let updatedItem = AlgoliaRankoItem(
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
                        .padding(.vertical, 5)
                    }
                    Spacer()
                }
            }
            
            VStack {
                Spacer()
                Rectangle()
                    .frame(height: 90)
                    .foregroundColor(.gray.opacity(0.8))
                    .blur(radius: 23)
            }
            .ignoresSafeArea()
            
        }
        .onAppear {
            loadListFromFirebase()
        }
        .sheet(isPresented: $showAddItemsSheet) {
            FilterChipPickerView(
                selectedRankoItems: $selectedRankoItems
            )
        }
        .sheet(isPresented: $showEditDetailsSheet) {
            DefaultListEditDetails(
                rankoName: rankoName,
                description: description,
                isPrivate: isPrivate,
                category: category
            ) { newName, newDescription, newPrivate, newCategory in
                rankoName    = newName
                description  = newDescription
                isPrivate    = newPrivate
                category     = newCategory
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            DefaultListReRank(
                items: selectedRankoItems,
                onSave: { newOrder in
                    selectedRankoItems = newOrder
                }
            )
        }
        .sheet(isPresented: $showExitSheet) {
            DefaultListPersonalExit(
                onSave: {
                    updateListInAlgolia(
                        listID: listID,
                        newName: rankoName,
                        newDescription: description,
                        newCategory: category!.name,
                        isPrivate: isPrivate
                    ) { success in
                        if success {
                            print("🎉 Fields updated in Algolia")
                        } else {
                            print("⚠️ Failed to update fields")
                        }
                    }
                    updateListInFirebase()
                    dismiss()
                },
                onLeave: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()   // dismiss DefaultListView without saving
                    }
                }
            )
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(AppTab.visibleCases, id: \.rawValue) { tab in
                        VStack(spacing: 6) {
                            Image(systemName: tab.symbolImage)
                                .font(.title3)
                                .symbolVariant(.fill)
                                .frame(height: 28)
                            
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                        .onTapGesture {
                            activeTab = tab
                            switch tab {
                            case .addItems:
                                showAddItemsSheet = true
                            case .editDetails:
                                showEditDetailsSheet = true
                            case .reRank:
                                showReorderSheet = true
                            case .exit:
                                showExitSheet = true
                            case .empty:
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .interactiveDismissDisabled(true)
            .presentationDetents([.height(80)])
            .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            fetchCreatorName()
            loadListFromFirebase()
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
    
    // MARK: — Fetchers
    private func loadProfileImage() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("ProfilePicture")
        ref.getData { _, snap in
            if let path = snap?.value as? String {
                Storage.storage().reference().child(path)
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
                    var loaded: [AlgoliaRankoItem] = []
                    for (_, itemData) in itemsDict {
                        guard
                            let id    = itemData["ItemID"]          as? String,
                            let name  = itemData["ItemName"]        as? String,
                            let desc  = itemData["ItemDescription"] as? String,
                            let image = itemData["ItemImage"]       as? String,
                            let rank  = itemData["ItemRank"]        as? Int,
                            let votes = itemData["ItemVotes"]       as? Int
                        else { continue }
                        
                        let record = AlgoliaItemRecord(
                            objectID: id,
                            ItemName: name,
                            ItemDescription: desc,
                            ItemCategory: "",      // adjust if you store item categories
                            ItemImage: image
                        )

                        let item = AlgoliaRankoItem(
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
    private func delete(_ item: AlgoliaRankoItem) {
        selectedRankoItems.removeAll { $0.id == item.id }
        normalizeRanks()
    }

    private func moveToTop(_ item: AlgoliaRankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.insert(moved, at: 0)
        normalizeRanks()
    }

    private func moveToBottom(_ item: AlgoliaRankoItem) {
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
    
    
    
    // MARK: - Firebase Update
    private func updateListInFirebase() {
        guard let category = category else { return }
        
        let db = Database.database().reference()
        let safeUID = (Auth.auth().currentUser?.uid ?? user_data.userID)
            .components(separatedBy: CharacterSet(charactersIn: ".#$[]")).joined()
        
        // ✅ Prepare the top-level fields to update
        let listUpdates: [String: Any] = [
            "RankoName": rankoName,
            "RankoDescription": description,
            "RankoPrivacy": isPrivate,
            "RankoCategory": category.name
        ]
        
        let listRef = db.child("RankoData").child(listID)
        
        // ✅ Update list fields
        listRef.updateChildValues(listUpdates) { error, _ in
            if let err = error {
                print("❌ Failed to update list fields: \(err.localizedDescription)")
            } else {
                print("✅ List fields updated successfully")
            }
        }
        
        // ✅ Prepare all RankoItems
        var itemsUpdate: [String: Any] = [:]
        for item in selectedRankoItems {
            itemsUpdate[item.id] = [
                "ItemID": item.id,
                "ItemName": item.record.ItemName,
                "ItemDescription": item.record.ItemDescription,
                "ItemImage": item.record.ItemImage,
                "ItemRank": item.rank,
                "ItemVotes": item.votes
            ]
        }
        
        // ✅ Update RankoItems node with the new data
        listRef.child("RankoItems").setValue(itemsUpdate) { error, _ in
            if let err = error {
                print("❌ Failed to update RankoItems: \(err.localizedDescription)")
            } else {
                print("✅ RankoItems updated successfully")
            }
        }
        
        // ✅ Update the user's reference to this list
        db.child("UserData").child(safeUID).child("RankoData").child(listID)
            .setValue(category.name) { error, _ in
                if let err = error {
                    print("❌ Failed to update user's list reference: \(err.localizedDescription)")
                } else {
                    print("✅ User's list reference updated")
                }
            }
    }

        // MARK: - Algolia Update
    private func updateListInAlgolia(
        listID: String,
        newName: String,
        newDescription: String,
        newCategory: String,
        isPrivate: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let client = SearchClient(
            appID: ApplicationID(rawValue: Secrets.algoliaAppID),
            apiKey: APIKey(rawValue: Secrets.algoliaAPIKey)
        )
        let index = client.index(withName: "RankoLists")

        // ✅ Prepare partial updates
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listID), .update(attribute: "RankoName", value: .string(newName))),
            (ObjectID(rawValue: listID), .update(attribute: "RankoDescription", value: .string(newDescription))),
            (ObjectID(rawValue: listID), .update(attribute: "RankoCategory", value: .string(newCategory))),
            (ObjectID(rawValue: listID), .update(attribute: "RankoPrivacy", value: .bool(isPrivate)))
        ]

        // ✅ Perform batch update in Algolia
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(let response):
                print("✅ Ranko list fields updated successfully:", response)
                completion(true)
            case .failure(let error):
                print("❌ Failed to update Ranko list fields:", error.localizedDescription)
                completion(false)
            }
        }
    }
}

struct DefaultListSpectate2: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject private var user_data = UserInformation.shared
    
    /// The existing list’s ID in your RTDB
    let listID: String
    
    // MARK: - Editable state
    @State private var rankoName: String
    @State private var rankoDescription: String
    @State private var isPrivate: Bool
    @State private var creatorID: String
    @State private var creatorName: String
    @State private var rankoType: String = ""
    @State private var category: CategoryChip?
    @State private var selectedRankoItems: [AlgoliaRankoItem] = []
    @State private var profileImage: UIImage?
    
    // MARK: - UI state
    //@State private var activeAction: DefaultListAction? = nil
    @State private var showCancelAlert = false
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var spectateProfile: Bool = false
    
    // MARK: - Flag to detect SwiftUI previews
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    init(
        listID: String,
        creatorID: String = "",
        creatorName: String = "",
        creatorImage: UIImage? = nil,
        rankoName: String = "",
        description: String = "",
        isPrivate: Bool = false,
        category: CategoryChip? = CategoryChip(name: "Unknown", icon: "questionmark.circle.fill", category: "Unknown", synonym: ""),
        selectedRankoItems: [AlgoliaRankoItem] = []
    ) {
        self.listID = listID
        self.creatorID = creatorID
        _creatorName = State(initialValue: creatorName)
        _profileImage = State(initialValue: creatorImage)
        _rankoName = State(initialValue: rankoName)
        _rankoDescription = State(initialValue: description)
        _isPrivate = State(initialValue: isPrivate)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
    }
    
    var buttonSymbols: [String: String] {
        [
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
//            bottomBar
//                .edgesIgnoringSafeArea(.bottom)
        }
        //.sheet(item: $activeAction, content: sheetContent)
        .alert("Unsaved Changes", isPresented: $showCancelAlert) {
            Button("Yes", role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text("Any changes made will not be saved. Do you want to cancel?")
        }
        .onAppear {
            fetchCreatorName()
            loadList(listID: listID)
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
    }
    
    // MARK: — Fetchers
    private func loadProfileImage() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("ProfilePicture")
        ref.getData { _, snap in
            if let path = snap?.value as? String {
                Storage.storage().reference().child(path)
                    .getData(maxSize: 2*1024*1024) { data, _ in
                        if let data = data, let ui = UIImage(data: data) {
                            profileImage = ui
                        }
                }
            }
        }
    }
    
    private func fetchCreatorName() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("UserName")
        ref.observeSingleEvent(of: .value) { snap in
            creatorName = snap.value as? String ?? "Unknown"
        }
        loadProfileImage()
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
                
                HStack {
                    Image(systemName: category!.icon)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.leading, 7)
                    Text(category!.name)
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.trailing, 7)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryChipIconColors[category!.name] ?? .gray)
                )
                
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
                ForEach(selectedRankoItems.sorted { $0.rank < $1.rank }) { item in
                    DefaultListItemRow(item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
                        
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: — Bottom Bar Overlay
//    private var bottomBar: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 6) {
//                HStack(spacing: 0) {
//                    ForEach(DefaultListAction.allCases) { action in
//                        if action == .exit {
//                            Button {
//                                let generator = UINotificationFeedbackGenerator()
//                                generator.notificationOccurred(.success)
//                                dismiss()
//                            } label: {
//                                VStack(spacing: 0) {
//                                    Image(systemName: "door.left.hand.open")
//                                        .font(.system(size: 13, weight: .black, design: .default))
//                                        .frame(height: 20)
//                                        .padding(.bottom, 6)
//                                    Text("Exit")
//                                        .font(.system(size: 9, weight: .black, design: .rounded))
//                                }
//                                .foregroundColor(.black)
//                                .frame(minWidth: 20)
//                                .padding(.vertical, 8)
//                                .padding(.horizontal, 12)
//                                .background(Color.white)
//                                .cornerRadius(12)
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        } else {
//                            Button {
//                                switch action {
//                                case .copy, .share:
//                                    withAnimation {
//                                        //activeAction = action
//                                    }
//                                default:
//                                    break
//                                }
//                            } label: {
//                                VStack(spacing: 0) {
//                                    if let symbol = buttonSymbols[action.rawValue] {
//                                        Image(systemName: symbol)
//                                            .font(.system(size: 13, weight: .black, design: .default))
//                                            .frame(height: 20)
//                                            .padding(.bottom, 6)
//                                    }
//                                    Text(action.rawValue)
//                                        .font(.system(size: 9, weight: .black, design: .rounded))
//                                }
//                                .foregroundColor(.black)
//                                .frame(minWidth: 20)
//                                .padding(.vertical, 8)
//                                .padding(.horizontal, 12)
//                                .background(Color.white)
//                                .cornerRadius(12)
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        }
//                    }
//                }
//            }
//            .padding(.vertical, 2)
//            .padding(.horizontal, 12)
//            .background(
//                RoundedRectangle(cornerRadius: 17)
//                    .fill(Color.white)
//                    .shadow(color: Color.black.opacity(0.25), radius: 8)
//            )
//        }
//    }
    
    
    // MARK: – Sheet Content Builder
//    @ViewBuilder
//    private func sheetContent(for action: DefaultListAction) -> some View {
//        switch action {
//        case .copy:
//            DefaultListView(
//                rankoName: rankoName,
//                description: rankoDescription,
//                isPrivate: isPrivate,
//                category: category,
//                selectedRankoItems: selectedRankoItems
//            ) { updatedItem in
//                // no-op in preview
//            }
//        case .share:
//            DefaultListShareImage(rankoName: rankoName, items: selectedRankoItems)
//        case .exit:
//            EmptyView()
//        }
//    }
}

// Re-use DefaultListView’s helpers and enum:
//extension DefaultListSpectate {
//    enum DefaultListAction: String, Identifiable, CaseIterable {
//        var id: String { rawValue }
//        case copy   = "Copy"
//        case share  = "Share"
//        case exit   = "Exit"
//    }
//}



struct DefaultListSpectate_Previews: PreviewProvider {
    // Create 10 sample AlgoliaRankoItem instances representing top destinations
    static var sampleItems: [AlgoliaRankoItem] = [
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 1,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "1",
                ItemName: "Paris",
                ItemDescription: "The City of Light",
                ItemCategory: "",
                ItemImage: "https://res.klook.com/image/upload/c_fill,w_750,h_750/q_80/w_80,x_15,y_15,g_south_west,l_Klook_water_br_trans_yhcmh3/activities/wrgwlkhnjekv8h5tjbn4.jpg"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 2,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "2",
                ItemName: "New York",
                ItemDescription: "The Big Apple",
                ItemCategory: "",
                ItemImage: "https://hips.hearstapps.com/hmg-prod/images/manhattan-skyline-with-empire-state-building-royalty-free-image-960609922-1557777571.jpg?crop=0.66635xw:1xh;center,top&resize=640:*"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 3,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "3",
                ItemName: "Tokyo",
                ItemDescription: "Land of the Rising Sun",
                ItemCategory: "",
                ItemImage: "https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/04/10/13/tokyo-main.jpg?width=1200&height=1200&fit=crop"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 4,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "4",
                ItemName: "Rome",
                ItemDescription: "a city steeped in history, culture, and artistic treasures, often referred to as the Eternal City",
                ItemCategory: "",
                ItemImage: "https://i.guim.co.uk/img/media/03303b5f042b72c03541fcd7f3777180f61a01a5/0_2310_4912_2947/master/4912.jpg?width=1200&height=1200&quality=85&auto=format&fit=crop&s=19cf880f7508ea310bdb136057d78240"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 5,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "5",
                ItemName: "Sydney",
                ItemDescription: "Harbour City",
                ItemCategory: "",
                ItemImage: "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/93/a7/be/sydney-opera-house.jpg?w=500&h=500&s=1"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 6,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "6",
                ItemName: "Barcelona",
                ItemDescription: "Gaudí’s Masterpiece City",
                ItemCategory: "",
                ItemImage: "https://lp-cms-production.imgix.net/2023-08/iStock-1297827939.jpg?fit=crop&ar=1%3A1&w=1200&auto=format&q=75"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 7,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "7",
                ItemName: "Cape Town",
                ItemDescription: "Mother City of South Africa",
                ItemCategory: "",
                ItemImage: "https://imageresizer.static9.net.au/0sx9mhfU8tYDs_T-ftiFBrWR_as=/0x0:1307x735/1200x1200/https%3A%2F%2Fprod.static9.net.au%2Ffs%2F15af5183-fb21-49d9-a22c-d9f4813ccbea"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 8,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "8",
                ItemName: "Rio de Janeiro",
                ItemDescription: "Marvelous City",
                ItemCategory: "",
                ItemImage: "https://whc.unesco.org/uploads/thumbs/site_1100_0004-750-750-20120625114004.jpg"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 9,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "9",
                ItemName: "Reykjavik",
                ItemDescription: "Land of Fire and Ice",
                ItemCategory: "",
                ItemImage: "https://media.gq-magazine.co.uk/photos/5d138e07d7a7017355bb9bf3/1:1/w_1280,h_1280,c_limit/reykjavik-gq-22jun18_istock_b.jpg"
            )
        ),
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 10,
            votes: 0,
            record: AlgoliaItemRecord(
                objectID: "10",
                ItemName: "Istanbul",
                ItemDescription: "Where East Meets West",
                ItemCategory: "",
                ItemImage: "https://images.contentstack.io/v3/assets/blt06f605a34f1194ff/blt289d3aab2da77bc9/6777f31f93a84b03b5a37ef2/BCC-2023-EXPLORER-Istanbul-Fun-things-to-do-in-Istanbul-HEADER_MOBILE.jpg?format=webp&auto=avif&quality=60&crop=1%3A1&width=425"
            )
        )
    ]

    static var previews: some View {
        DefaultListSpectate(
            listID: UUID().uuidString,
            creatorID: "user123",
            creatorName: "Jane Doe",
            creatorImage: UIImage(systemName: "person.crop.circle.fill"),
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: CategoryChip(name: "Countries", icon: "globe.europe.africa.fill", category: "Geography", synonym: ""),
            selectedRankoItems: sampleItems
        )
        .previewLayout(.sizeThatFits)
    }
}
