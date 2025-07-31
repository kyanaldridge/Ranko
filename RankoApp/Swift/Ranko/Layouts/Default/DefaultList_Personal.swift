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

    enum TabType { case edit, add, reorder }

    // MARK: - Init now only requires listID
    init(
        listID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        category: CategoryChip? = nil,
        selectedRankoItems: [AlgoliaRankoItem] = [],
        onSave: ((AlgoliaRankoItem) -> Void)? = nil
    ) {
        self.listID = listID
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
                    
                    HStack(spacing: 10) {
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
                        
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.leading, 20)
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
            ExitSheetView(
                onSave: {
                    updateListInAlgolia()
                    updateListInFirebase()
                    dismiss()
                },
                onDelete: { dismiss() }
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
        
        let listUpdates: [String: Any] = [
            "RankoName": rankoName,
            "RankoDescription": description,
            "RankoPrivacy": isPrivate,
            "RankoCategory": category.name
        ]
        
        // ✅ Update only changed fields
        db.child("RankoData").child(listID).updateChildValues(listUpdates)
        
        // ✅ Update user's reference
        db.child("UserData").child(safeUID).child("RankoData").child(listID).setValue(category.name)
    }

        // MARK: - Algolia Update
    private func updateListInAlgolia() {
        let response = try await client.partialUpdateObject(
            indexName: "ALGOLIA_INDEX_NAME",
            objectID: "uniqueID",
            attributesToUpdate: ["attributeId": "new value"]
        )
    }
    
    
}


struct DefaultListPersonal2: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var user_data = UserInformation.shared

    /// The existing list’s ID in your RTDB
    let listID: String

    // MARK: – Editable state
    @State private var rankoName: String        = ""
    @State private var rankoDescription: String      = ""
    @State private var isPrivate: Bool          = false
    @State private var category: CategoryChip?  = nil
    @State private var rankoType: String        = ""
    @State private var selectedRankoItems: [AlgoliaRankoItem] = []
    @State private var itemToEdit: AlgoliaRankoItem? = nil

    // MARK: – UI state
    @State private var activeAction: DefaultListAction? = nil
    @State private var showCancelAlert = false
    
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var changeMade: Bool = false
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: – Toast
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    @State private var showEditSheet: Bool = false
    @State private var onSave: (AlgoliaRankoItem) -> Void
    
    @State private var showAddItemPopup = false
    @State private var showBlankItemSliderSheet = false
    @State private var showItemSearch = false
    @State private var blankItemCount: Double = 1

    init(
        listID: String,
        rankoName: String = "Not Found",
        description: String = "",
        isPrivate: Bool = false,
        category: CategoryChip? = CategoryChip(name: "Unknown", icon: "questionmark.circle.fill", category: "Unknown", synonym: ""),
        selectedRankoItems: [AlgoliaRankoItem] = [],
        onSave: @escaping (AlgoliaRankoItem) -> Void
    ) {
        self.listID = listID
        _rankoName = State(initialValue: rankoName)
        _rankoDescription = State(initialValue: description)
        _isPrivate = State(initialValue: isPrivate)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)
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

            // MARK: — Toast Overlay
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                        )
                        .transition(
                            .move(edge: .bottom)
                            .combined(with: .opacity)
                        )
                        .padding(.bottom, 80)
                }
                .animation(.easeInOut(duration: 0.25), value: showToast)
            }
        }
        .sheet(item: $activeAction, content: sheetContent)
        .sheet(item: $itemToEdit) { tappedItem in
            EditItemView(item: tappedItem, listID: listID) { newName, newDesc in
                let rec = tappedItem.record
                let updatedRecord = AlgoliaItemRecord(
                    objectID: rec.objectID,
                    ItemName: newName,
                    ItemDescription: newDesc,
                    ItemCategory: "",
                    ItemImage: rec.ItemImage
                )
                let updatedItem = AlgoliaRankoItem(
                    id: tappedItem.id,
                    rank: tappedItem.rank,
                    votes: tappedItem.votes,
                    record: updatedRecord
                )
                if let idx = selectedRankoItems.firstIndex(where: { $0.id == tappedItem.id }) {
                    selectedRankoItems[idx] = updatedItem
                }
            }
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
        .sheet(isPresented: $showItemSearch) {
            FilterChipPickerView(
                selectedRankoItems: $selectedRankoItems
            )
        }
        .sheet(isPresented: $showBlankItemSliderSheet) {
            VStack(spacing: 16) {
                Text("Add Blank Items")
                    .font(.headline)

                Text("Select how many blank items to add")
                    .font(.caption)

                Slider(value: $blankItemCount, in: 1...Double(max(1, 50 - selectedRankoItems.count)), step: 1)

                Text("\(Int(blankItemCount)) blank item(s)")
                    .font(.title2)

                Button("Add Items") {
                    let count = Int(blankItemCount)
                    let startRank = selectedRankoItems.count + 1
                    for i in 0..<count {
                        let id = UUID().uuidString
                        let item = AlgoliaRankoItem(
                            id: id,
                            rank: startRank + i,
                            votes: 0,
                            record: AlgoliaItemRecord(
                                objectID: id,
                                ItemName: "Blank Item",
                                ItemDescription: "Hold here • and click edit",
                                ItemCategory: "",
                                ItemImage: ""
                            )
                        )
                        selectedRankoItems.append(item)
                    }
                    showBlankItemSliderSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .presentationDetents([.fraction(0.3), .medium])
        }

        .interactiveDismissDisabled(changeMade)
        .alert("Unsaved Changes", isPresented: $showCancelAlert) {
            Button("Yes", role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text("Any changes made will not be saved. Do you want to cancel?")
        }
        .onAppear {
            loadList(listID: listID)
        }
    }

    // MARK: – Load existing list
    private func loadList(listID: String) {
        
    }

    // MARK: – Update existing list
    private func updateRankedList() {
        guard let category = category else {
            print("❌ Cannot save: no category selected")
            return
        }

        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else {
            print("❌ Invalid user ID")
            return
        }

        let now = Date()
        let aedtFmt = DateFormatter()
        aedtFmt.locale   = Locale(identifier: "en_US_POSIX")
        aedtFmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFmt.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFmt.string(from: now)

        // 2) Build Grouped Items with Rank encoding
        let itemRecords: [RankoItemRecord] = []

        // 1) Build Group List Codable Struct
        let listRecord = RankoListRecord(
            objectID:         listID,
            RankoName:        rankoName,
            RankoDescription: rankoDescription,
            RankoType:        "group",
            RankoPrivacy:     isPrivate,
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
            RankoItems: Dictionary(uniqueKeysWithValues: itemRecords.map { item in
                return (item.objectID, ["Rank": item.ItemRank, "Votes": item.ItemVotes])
            })
        )

        listsIndex.saveObject(listRecord) { result in
            switch result {
            case .success: print("✅ List updated in Algolia")
            case .failure(let error): print("❌ Algolia list update failed: \(error)")
            }
        }

        itemsIndex.saveObjects(itemRecords) { result in
            switch result {
            case .success: print("✅ Items updated in Algolia")
            case .failure(let error): print("❌ Algolia item update failed: \(error)")
            }
        }

        changeMade = true
    }

    
    private func deleteRankedList() {
//
//        // sanitize user key
//        let rawUID = Auth.auth().currentUser?.uid ?? userID
//        let invalidSet = CharacterSet(charactersIn: ".#$[]")
//        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
//        guard !safeUID.isEmpty else {
//            print("❌ Cannot save: invalid user ID")
//            return
//        }
//
//        let rankedListRef = Database.database().reference().child("UserData").child(safeUID).child("RankoListData").child(listID)
//
//        rankedListRef.removeValue()
//
//        Database.database().reference().child("UserData").child(safeUID).child("DeletedRankoListData").child(listID).setValue(category?.name)
//
        dismiss()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Header
    private var header: some View {
        HStack {
            Text(rankoName)
                .font(.title2)
                .fontWeight(.black)
                .fontDesign(.rounded)
            Spacer()
        }
    }

    // MARK: — Description View
    private var descriptionView: some View {
        HStack {
            if rankoDescription.isEmpty {
                Text("No description yet…")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            } else {
                Text(rankoDescription)
                    .lineLimit(3)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }

    // MARK: — Category & Privacy View
    private var categoryPrivacyView: some View {
        HStack(spacing: 10) {
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

            Spacer()
        }
    }

    // MARK: — Selected Items Section
    private var selectedItemsSection: some View {
        VStack {
            ScrollView {
                ForEach(selectedRankoItems.sorted { $0.rank < $1.rank }) { item in
                    DefaultListItemRow(item: item)
                        .onTapGesture {
                            selectedItem = item
                            changeMade = true
                        }
                        .contextMenu {
                            Button(action: {
                                selectedItem = item
                                changeMade = true
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
                }
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: — Bottom Bar Overlay
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(DefaultListAction.allCases) { action in
                        if action == .save {
                            pressAndHoldButton(
                                action: action,
                                symbolName: buttonSymbols[action.rawValue] ?? "",
                                onPerform: {
                                    // Success haptic right before performing the action
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    updateRankedList()
                                    dismiss()
                                },
                                onTapToast: {
                                    // Error haptic when they only tap
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    showTemporaryToast("Hold down button to Save")
                                }
                            )
                        }
                        else if action == .delete {
                            pressAndHoldButton(
                                action: action,
                                symbolName: buttonSymbols[action.rawValue] ?? "",
                                onPerform: {
                                    // Success haptic right before performing the action
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    deleteRankedList()
                                },
                                onTapToast: {
                                    // Error haptic when they only tap
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    showTemporaryToast("Hold down button to Delete")
                                }
                            )
                        }
                        else {
                            // Other actions (addItems, reRank, editDetails)
                            Button {
                                switch action {
                                case .addItems, .reRank, .editDetails:
                                    withAnimation {
                                        activeAction = action
                                        changeMade = true
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

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Press-and-Hold Button with Separate Forward/Reverse Rings
    @ViewBuilder
    private func pressAndHoldButton(
        action: DefaultListAction,
        symbolName: String,
        onPerform: @escaping () -> Void,
        onTapToast: @escaping () -> Void
    ) -> some View {
        ZStack {
            // ─────────
            // 1) Button Content
            VStack(spacing: 0) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .black, design: .default))
                    .frame(height: 20)
                    .padding(.bottom, 6)

                Text(action.rawValue)
                    .font(.system(size: 9, weight: .black, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(minWidth: 20)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white)
            .cornerRadius(12)
            // Short tap = show toast + error haptic
            .onTapGesture {
                onTapToast()
            }
            // Long press (≥1s) = success haptic + perform action
            .onLongPressGesture(
                minimumDuration: 1.0,
                perform: {
                    onPerform()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Toast Helper
    private func showTemporaryToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showToast = false
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Existing Helpers
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
            // assign 1-based ranks in list order
            selectedRankoItems[index].rank = index + 1
        }
    }
    
    
    // MARK: – Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for action: DefaultListAction) -> some View {
        switch action {
        case .save:
            EmptyView() // never present a sheet for Save
        case .addItems:
            FilterChipPickerView(selectedRankoItems: $selectedRankoItems)
        case .reRank:
            DefaultListReRank(
                items: selectedRankoItems,
                onSave: { newOrder in
                    selectedRankoItems = newOrder
                }
            )
        case .editDetails:
            EmptyView()
//            DefaultListEditDetails(
//                rankoName: rankoName,
//                description: rankoDescription,
//                isPrivate: isPrivate,
//                selectedCategoryChip: category
//            ) { newName, newDescription, newPrivate, newCategory in
//                rankoName    = newName
//                rankoDescription  = newDescription
//                isPrivate    = newPrivate
//                category     = newCategory
//            }
        case .delete:
            EmptyView() // never present a sheet for Delete
        }
    }

    private func removeItem(_ item: AlgoliaRankoItem) {
        selectedRankoItems.removeAll { $0.id == item.id }
    }

    enum DefaultListAction: String, Identifiable, CaseIterable {
        var id: String { self.rawValue }
        case save        = "Save"
        case addItems    = "Add Items"
        case reRank      = "Re-Rank"
        case editDetails = "Edit Details"
        case delete      = "Delete"
    }

    var buttonSymbols: [String: String] {
        [
            "Save":         "square.and.arrow.down",
            "Add Items":    "plus",
            "Re-Rank":      "rectangle.stack",
            "Edit Details": "pencil",
            "Delete":       "trash"
        ]
    }
}

struct DefaultListPersonal_Previews: PreviewProvider {
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
                ItemImage:"https://res.klook.com/image/upload/c_fill,w_750,h_750/q_80/w_80,x_15,y_15,g_south_west,l_Klook_water_br_trans_yhcmh3/activities/wrgwlkhnjekv8h5tjbn4.jpg"
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
                ItemImage:"https://hips.hearstapps.com/hmg-prod/images/manhattan-skyline-with-empire-state-building-royalty-free-image-960609922-1557777571.jpg?crop=0.66635xw:1xh;center,top&resize=640:*"
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
                ItemImage:"https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/04/10/13/tokyo-main.jpg?width=1200&height=1200&fit=crop"
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
                ItemImage:"https://i.guim.co.uk/img/media/03303b5f042b72c03541fcd7f3777180f61a01a5/0_2310_4912_2947/master/4912.jpg?width=1200&height=1200&quality=85&auto=format&fit=crop&s=19cf880f7508ea310bdb136057d78240"
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
                ItemImage:"https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/93/a7/be/sydney-opera-house.jpg?w=500&h=500&s=1"
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
                ItemImage:"https://lp-cms-production.imgix.net/2023-08/iStock-1297827939.jpg?fit=crop&ar=1%3A1&w=1200&auto=format&q=75"
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
                ItemImage:"https://imageresizer.static9.net.au/0sx9mhfU8tYDs_T-ftiFBrWR_as=/0x0:1307x735/1200x1200/https%3A%2F%2Fprod.static9.net.au%2Ffs%2F15af5183-fb21-49d9-a22c-d9f4813ccbea"
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
                ItemImage:"https://whc.unesco.org/uploads/thumbs/site_1100_0004-750-750-20120625114004.jpg"
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
                ItemImage:"https://media.gq-magazine.co.uk/photos/5d138e07d7a7017355bb9bf3/1:1/w_1280,h_1280,c_limit/reykjavik-gq-22jun18_istock_b.jpg"
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

