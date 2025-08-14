//
//  DefaultList_Personal.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import InstantSearchCore
import Firebase
import FirebaseAuth
import Foundation
import AlgoliaSearchClient


struct DefaultListPersonal: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared

    // Required property
    let listID: String

    // Optional editable properties with defaults
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var category: CategoryChip? = nil

    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategory: CategoryChip? = nil

    // Sheets & states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var possiblyEdited = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    @State var showDeleteAlert = false
    @State var showLeaveAlert = false

    @State private var activeTab: DefaultListPersonalTab = .addItems
    @State private var selectedRankoItems: [RankoItem] = []
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: ((RankoItem) -> Void)? = nil
    private let onDelete: (() -> Void)?

    enum TabType { case edit, add, reorder }

    // MARK: - Init now only requires listID
    init(
        listID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        category: CategoryChip? = nil,
        selectedRankoItems: [RankoItem] = [],
        onSave: ((RankoItem) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.listID = listID
        self.onDelete = onDelete
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName ?? "")
        _originalDescription = State(initialValue: description ?? "")
        _originalIsPrivate = State(initialValue: isPrivate ?? false)
        _originalCategory = State(initialValue: category)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xFFF5E1).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 7) {
                    HStack {
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
                        }
                        Spacer(minLength: 0)
                        Button {
                            if possiblyEdited {
                                showLeaveAlert = true
                            } else {
                                showTabBar = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    dismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .heavy, design: .default))
                                .padding(.vertical, 6)
                        }
                        .foregroundColor(Color(hex: 0x6D400F))
                        .tint(Color(hex: 0xFFF9EE))
                        .buttonStyle(.glassProminent)
                        .padding(.trailing, 30)
                    }
                    .alert(isPresented: $showLeaveAlert) {
                        CustomDialog(
                            title: "Leave Without Saving?",
                            content: "Are you sure you want to leave your Ranko without saving? All your changes will be lost.",
                            image: .init(
                                content: "figure.walk.departure",
                                background: .orange,
                                foreground: .white
                            ),
                            button1: .init(
                                content: "Leave",
                                background: .orange,
                                foreground: .white,
                                action: { _ in
                                    showLeaveAlert = false
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        dismiss()
                                    }
                                }
                            ),
                            button2: .init(
                                content: "Cancel",
                                background: .red,
                                foreground: .white,
                                action: { _ in
                                    showLeaveAlert = false
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        showTabBar = true
                                    }
                                }
                            )
                        )
                        .transition(.blurReplace.combined(with: .push(from: .bottom)))
                    } background: {
                        Rectangle()
                            .fill(.primary.opacity(0.35))
                    }
                    
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
                        
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.leading, 20)
                }
                .padding(.bottom, 5)
                
                VStack {
                    ScrollView {
                        ForEach(selectedRankoItems.sorted { $0.rank < $1.rank }) { item in
                            DefaultListItemRow(item: item)
                                .onTapGesture {
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        selectedItem = item
                                    }
                                }
                                .contextMenu {
                                    Button(action: {
                                        itemToEdit = item
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .foregroundColor(.orange)
                                    
                                    Divider()
                                    
                                    Button(action: { moveToTop(item) }) {
                                        Label("Move to Top", systemImage: "arrow.up.to.line.compact")
                                    }
                                    
                                    Button(action: { moveToBottom(item) }) {
                                        Label("Move to Bottom", systemImage: "arrow.down.to.line.compact")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
                possiblyEdited = true
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
                    possiblyEdited = true
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
                },
                onDelete: {
                    showTabBar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        showDeleteAlert = true
                    }
                }
            )
        }
        .alert(isPresented: $showDeleteAlert) {
            CustomDialog(
                title: "Delete Ranko?",
                content: "Are you sure you want to delete your Ranko.",
                image: .init(
                    content: "trash.fill",
                    background: .red,
                    foreground: .white
                ),
                button1: .init(
                    content: "Delete",
                    background: .red,
                    foreground: .white,
                    action: { _ in
                        showDeleteAlert = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            removeFeaturedRanko(listID: listID) { success in}
                            deleteRanko() { success in
                                if success {
                                    print("🎉 Fields updated in Algolia")
                                } else {
                                    print("⚠️ Failed to update fields")
                                }
                            }
                            onDelete!()
                            dismiss()
                        }
                    }
                ),
                button2: .init(
                    content: "Cancel",
                    background: .orange,
                    foreground: .white,
                    action: { _ in
                        showDeleteAlert = false
                        showTabBar = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            showTabBar = true
                        }
                    }
                )
            )
            .transition(.blurReplace.combined(with: .push(from: .bottom)))
        } background: {
            Rectangle()
                .fill(.primary.opacity(0.35))
        }
        .sheet(item: $selectedItem) { tapped in
            ItemDetailView(
                items: selectedRankoItems,
                initialItem: tapped,
                listID: listID
            ) { updated in
                // replace the old item with the updated one
                if let idx = selectedRankoItems.firstIndex(where: { $0.id == updated.id }) {
                    selectedRankoItems[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(DefaultListPersonalTab.visibleCases, id: \.rawValue) { tab in
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
                            case .addItems:
                                showAddItemsSheet = true
                                possiblyEdited = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabBarPresent = false
                                }
                            case .editDetails:
                                showEditDetailsSheet = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabBarPresent = false
                                }
                            case .reRank:
                                showReorderSheet = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabBarPresent = false
                                }
                            case .exit:
                                showExitSheet = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabBarPresent = false
                                }
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
    }
    
    private func loadListFromFirebase() {
        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(listID)

        listRef.observeSingleEvent(of: .value, with: { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("⚠️ No data at RankoData/\(listID)")
                return
            }

            DispatchQueue.main.async {
                // — map your top-level fields…
                self.rankoName   = data["RankoName"]        as? String ?? ""
                self.description = data["RankoDescription"] as? String ?? ""
                self.isPrivate   = data["RankoPrivacy"]     as? Bool   ?? false

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
        possiblyEdited = true
    }

    private func moveToTop(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.insert(moved, at: 0)
        normalizeRanks()
        possiblyEdited = true
    }

    private func moveToBottom(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.append(moved)
        normalizeRanks()
        possiblyEdited = true
    }

    private func normalizeRanks() {
        for index in selectedRankoItems.indices {
            selectedRankoItems[index].rank = index + 1
        }
    }
    
    private func deleteRanko(completion: @escaping (Bool) -> Void
    ) {
        let db = Database.database().reference()
        
        let statusUpdate: [String: Any] = [
            "RankoStatus": "deleted"
        ]
        
        let listRef = db.child("RankoData").child(listID)
        
        // ✅ Update list fields
        listRef.updateChildValues(statusUpdate) { error, _ in
            if let err = error {
                print("❌ Failed to update list fields: \(err.localizedDescription)")
            } else {
                print("✅ List fields updated successfully")
            }
        }
        
        let client = SearchClient(
            appID: ApplicationID(rawValue: Secrets.algoliaAppID),
            apiKey: APIKey(rawValue: Secrets.algoliaAPIKey)
        )
        let index = client.index(withName: "RankoLists")

        // ✅ Prepare partial updates
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: listID), .update(attribute: "RankoStatus", value: "deleted"))
        ]

        // ✅ Perform batch update in Algolia
        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success(let response):
                print("✅ Ranko list status updated successfully:", response)
                completion(true)
            case .failure(let error):
                print("❌ Failed to update Ranko list status:", error.localizedDescription)
                completion(false)
            }
        }
    }
    
    func removeFeaturedRanko(listID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            // No user; nothing to delete
            completion(.success(()))
            return
        }

        let featuredRef = Database.database()
            .reference()
            .child("UserData")
            .child(user_data.userID)
            .child("UserRankos")
            .child("UserFeaturedRankos")

        // 1) Load all featured slots
        featuredRef.getData { error, snapshot in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let snap = snapshot, snap.exists() else {
                // No featured entries at all
                completion(.success(()))
                return
            }

            // 2) Find the slot whose value == listID
            var didRemove = false
            for case let child as DataSnapshot in snap.children {
                if let value = child.value as? String, value == listID {
                    didRemove = true
                    // 3) Remove that child entirely
                    featuredRef.child(child.key).removeValue { removeError, _ in
                        if let removeError = removeError {
                            completion(.failure(removeError))
                        } else {
                            // Optionally reload your local state here:
                            // self.tryLoadFeaturedRankos()
                            completion(.success(()))
                        }
                    }
                    break
                }
            }

            // 4) If no match was found, still report success
            if !didRemove {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Firebase Update
    private func updateListInFirebase() {
        guard let category = category else { return }
        
        let db = Database.database().reference()
        
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

enum DefaultListPersonalTab: String, CaseIterable {
    case addItems = "Add Items"
    case editDetails = "Edit Details"
    case reRank = "Re-Rank"
    case exit = "Exit"
    case empty = "Empty"
    
    var symbolImage: String {
        switch self {
        case .addItems:
            return "circle.grid.2x2"
        case .editDetails:
            return "square.text.square"
        case .reRank:
            return "rectangle.stack"
        case .exit:
            return "door.left.hand.closed"
        case .empty:
            return ""
        }
    }
    
    static var visibleCases: [DefaultListPersonalTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}

struct DefaultListPersonalExit: View {
    @Environment(\.dismiss) var dismiss
    
    var onSave: () -> Void
    var onLeave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                HStack {
                    Button {
                        print("Save Tapped")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        onSave()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Save")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0x42ADFF))
                    .buttonStyle(.glassProminent)
                    Button {
                        print("Don't Save Tapped")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        onLeave()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Don't Save")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0xFE8C34))
                    .buttonStyle(.glassProminent)
                }
                Button {
                    print("Delete Tapped")
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    onDelete()
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                        Text("Delete")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .foregroundColor(Color(hex: 0xFFFFFF))
                .tint(Color(hex: 0xE93B3D))
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 40)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                        print("Cancel Exit Tapped")
                    }
                }
            }
        }
        .presentationBackground(Color.white)
        .presentationDetents([.height(300)])
        .ignoresSafeArea()
    }
}

struct DefaultListPersonal_Previews: PreviewProvider {
    // Create 10 sample RankoItem instances representing top destinations
    static var sampleItems: [RankoItem] = [
        RankoItem(
            id: UUID().uuidString,
            rank: 1,
            votes: 0,
            record: RankoRecord(
                objectID: "1",
                ItemName: "Paris",
                ItemDescription: "The City of Light",
                ItemCategory: "",
                ItemImage:"https://res.klook.com/image/upload/c_fill,w_750,h_750/q_80/w_80,x_15,y_15,g_south_west,l_Klook_water_br_trans_yhcmh3/activities/wrgwlkhnjekv8h5tjbn4.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 2,
            votes: 0,
            record: RankoRecord(
                objectID: "2",
                ItemName: "New York",
                ItemDescription: "The Big Apple",
                ItemCategory: "",
                ItemImage:"https://hips.hearstapps.com/hmg-prod/images/manhattan-skyline-with-empire-state-building-royalty-free-image-960609922-1557777571.jpg?crop=0.66635xw:1xh;center,top&resize=640:*"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3,
            votes: 0,
            record: RankoRecord(
                objectID: "3",
                ItemName: "Tokyo",
                ItemDescription: "Land of the Rising Sun",
                ItemCategory: "",
                ItemImage:"https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/04/10/13/tokyo-main.jpg?width=1200&height=1200&fit=crop"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 4,
            votes: 0,
            record: RankoRecord(
                objectID: "4",
                ItemName: "Rome",
                ItemDescription: "a city steeped in history, culture, and artistic treasures, often referred to as the Eternal City",
                ItemCategory: "",
                ItemImage:"https://i.guim.co.uk/img/media/03303b5f042b72c03541fcd7f3777180f61a01a5/0_2310_4912_2947/master/4912.jpg?width=1200&height=1200&quality=85&auto=format&fit=crop&s=19cf880f7508ea310bdb136057d78240"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 5,
            votes: 0,
            record: RankoRecord(
                objectID: "5",
                ItemName: "Sydney",
                ItemDescription: "Harbour City",
                ItemCategory: "",
                ItemImage:"https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/93/a7/be/sydney-opera-house.jpg?w=500&h=500&s=1"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 6,
            votes: 0,
            record: RankoRecord(
                objectID: "6",
                ItemName: "Barcelona",
                ItemDescription: "Gaudí’s Masterpiece City",
                ItemCategory: "",
                ItemImage:"https://lp-cms-production.imgix.net/2023-08/iStock-1297827939.jpg?fit=crop&ar=1%3A1&w=1200&auto=format&q=75"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 7,
            votes: 0,
            record: RankoRecord(
                objectID: "7",
                ItemName: "Cape Town",
                ItemDescription: "Mother City of South Africa",
                ItemCategory: "",
                ItemImage:"https://imageresizer.static9.net.au/0sx9mhfU8tYDs_T-ftiFBrWR_as=/0x0:1307x735/1200x1200/https%3A%2F%2Fprod.static9.net.au%2Ffs%2F15af5183-fb21-49d9-a22c-d9f4813ccbea"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 8,
            votes: 0,
            record: RankoRecord(
                objectID: "8",
                ItemName: "Rio de Janeiro",
                ItemDescription: "Marvelous City",
                ItemCategory: "",
                ItemImage:"https://whc.unesco.org/uploads/thumbs/site_1100_0004-750-750-20120625114004.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 9,
            votes: 0,
            record: RankoRecord(
                objectID: "9",
                ItemName: "Reykjavik",
                ItemDescription: "Land of Fire and Ice",
                ItemCategory: "",
                ItemImage:"https://media.gq-magazine.co.uk/photos/5d138e07d7a7017355bb9bf3/1:1/w_1280,h_1280,c_limit/reykjavik-gq-22jun18_istock_b.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 10,
            votes: 0,
            record: RankoRecord(
                objectID: "10",
                ItemName: "Istanbul",
                ItemDescription: "Where East Meets West",
                ItemCategory: "",
                ItemImage:"https://images.contentstack.io/v3/assets/blt06f605a34f1194ff/blt289d3aab2da77bc9/6777f31f93a84b03b5a37ef2/BCC-2023-EXPLORER-Istanbul-Fun-things-to-do-in-Istanbul-HEADER_MOBILE.jpg?format=webp&auto=avif&quality=60&crop=1%3A1&width=425"
            )
        )
    ]

    static var previews: some View {
        DefaultListView(
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: CategoryChip(name: "Countries", icon: "globe.europe.africa.fill", category: "Geography", synonym: ""),
            selectedRankoItems: sampleItems
        ) { updatedItem in
            // no-op in preview
        }
         // Optional: wrap in a NavigationView or set a fixed frame for better preview layout
        .previewLayout(.sizeThatFits)
    }
}

