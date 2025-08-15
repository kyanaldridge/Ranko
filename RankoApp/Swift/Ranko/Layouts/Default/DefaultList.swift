//
//  DefaultList.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import Foundation
import InstantSearch
import UIKit
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseAnalytics
import PhotosUI
import AlgoliaSearchClient

let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID), apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
let listsIndex = client.index(withName: "RankoLists")
let itemsIndex = client.index(withName: "RankoItems")

// MARK: - Helpers
func randomString(length: Int) -> String {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).compactMap{ _ in chars.randomElement() })
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}






struct DefaultListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared

    // Init properties
    @State private var listUUID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    
    // to revert to old values
    @State private var originalRankoName: String
    @State private var originalDescription: String
    @State private var originalIsPrivate: Bool
    @State private var originalCategory: CategoryChip?

    // Sheet states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    
    @State private var activeTab: DefaultListTab = .addItems
    
    // Item states
    @State private var selectedRankoItems: [RankoItem]
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: (RankoItem) -> Void

    // Active tab
    @State private var selectedTab: TabType? = nil
    
    @State private var imageReloadToken = UUID()

    enum TabType {
        case edit, add, reorder
    }
    
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: CategoryChip?,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName)
        _originalDescription = State(initialValue: description)
        _originalIsPrivate = State(initialValue: isPrivate)
        _originalCategory = State(initialValue: category)
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
                        Group {
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
                                            listID: listUUID
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
                                            onSave(updatedItem)
                                        }
                                    }
                            }
                        }
                        .id(imageReloadToken)
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
        .refreshable {
            refreshItemImages()
        }
        .onAppear {
            refreshItemImages()
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
            DefaultListExit(
                onSave: {
                    saveRankedListToAlgolia()
                    saveRankedListToFirebase()
                    showTabBar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()
                    }
                },
                onDelete: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()   // dismiss DefaultListView without saving
                    }
                }
            )
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(DefaultListTab.visibleCases, id: \.rawValue) { tab in
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
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
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
    
    func saveRankedListToAlgolia() {
        guard let category = category else {
            print("❌ Cannot save: no category selected")
            return
        }

        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else {
            print("❌ Cannot save: invalid user ID")
            return
        }

        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)

        // 1) Build Group List Codable Struct
        let listRecord = RankoListAlgolia(
            objectID:         listUUID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoStatus:      "active",
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
            RankoLikes:       0,
            RankoComments:    0,
            RankoVotes:       0
        )

        // 3) Upload to Algolia
        let group = DispatchGroup()

        group.enter()
        listsIndex.saveObject(listRecord) { result in
            switch result {
            case .success:
                print("✅ List uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading list: \(error)")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            print("🎉 Upload to Algolia completed")
        }
    }

    func saveRankedListToFirebase() {
        // 1) Make sure we actually have a category
        guard let category = category else {
            print("❌ Cannot save: no category selected")
            return
        }
        
        let db = Database.database().reference()
        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else {
            print("❌ Cannot save: invalid user ID")
            return
        }
        
        // 2) Build your items payload
        var rankoItemsDict: [String: Any] = [:]
        for item in selectedRankoItems {
            let itemID = UUID().uuidString
            rankoItemsDict[itemID] = [
                "ItemID":          itemID,
                "ItemRank":        item.rank,
                "ItemName":        item.itemName,
                "ItemDescription": item.itemDescription,
                "ItemImage":       item.itemImage,
                "ItemVotes":       0
            ]
        }
        
        // 3) Prepare both AEDT and local timestamps
        let now = Date()
        
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)
        
        // 4) Top-level list payload with both fields
        let listDataForFirebase: [String: Any] = [
            "RankoID":              listUUID,
            "RankoName":            rankoName,
            "RankoDescription":     description,
            "RankoType":            "default",
            "RankoPrivacy":         isPrivate,
            "RankoStatus":          "active",
            "RankoCategory":        category.name,
            "RankoUserID":          safeUID,
            "RankoItems":           rankoItemsDict,
            "RankoDateTime":        rankoDateTime,
        ]
        
        // 5) Write the main list node
        db.child("RankoData")
            .child(listUUID)
            .setValue(listDataForFirebase) { error, _ in
                if let err = error {
                    print("❌ Error saving list: \(err.localizedDescription)")
                } else {
                    print("✅ List saved successfully")
                }
            }
        
        // 6) Write the user’s index of lists
        db.child("UserData")
            .child(user_data.userID)
            .child("UserRankos")
            .child("UserActiveRankos")
            .child(listUUID)
            .setValue(category.name) { error, _ in
                if let err = error {
                    print("❌ Error saving list to user: \(err.localizedDescription)")
                } else {
                    print("✅ List saved successfully to user")
                }
            }
    }
}


/// Tab Enum
enum DefaultListTab: String, CaseIterable {
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
    
    static var visibleCases: [DefaultListTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}

struct DefaultListEditDetails: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: – Editable state
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var selectedCategoryChip: CategoryChip?
    @State private var showCategoryPicker: Bool = false
    
    // MARK: – Validation & shake effects
    @State private var rankoNameShake: CGFloat = 0
    @State private var categoryShake: CGFloat = 0
    private var isValid: Bool {
        !rankoName.isEmpty && selectedCategoryChip != nil
    }
    
    private let onSave: (String, String, Bool, CategoryChip?) -> Void
    
    init(
        rankoName: String,
        description: String = "",
        isPrivate: Bool,
        category: CategoryChip?,
        onSave: @escaping (String, String, Bool, CategoryChip?) -> Void
    ) {
        self.onSave              = onSave
        
        _rankoName    = State(initialValue: rankoName)
        _description  = State(initialValue: description)
        _isPrivate    = State(initialValue: isPrivate)
        _selectedCategoryChip = State(initialValue: category)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Ranko Name Field
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        Text("Ranko Name")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.leading, 6)
                        Text("*")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: 0x4C2C33))
                    }
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.trailing, 1)
                        TextField("Enter name", text: $rankoName, axis: .vertical)
                            .lineLimit(1...2)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .onChange(of: rankoName) { _, newValue in
                                if newValue.count > 30 {
                                    rankoName = String(newValue.prefix(30))
                                }
                            }
                        Spacer()
                        Text("\(rankoName.count)/30")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.top, 30)
                .modifier(ShakeEffect(animatableData: rankoNameShake))
                
                // Description Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Color(hex: 0x857467))
                        .padding(.leading, 6)
                    HStack(alignment: .top) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.trailing, 1)
                        TextField("Enter Description", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .onChange(of: description) { _, newValue in
                                if newValue.count > 250 {
                                    description = String(newValue.prefix(250))
                                }
                            }
                        Spacer()
                        Text("\(description.count)/250")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.top, 10)
                
                // Category & Privacy Toggle
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            Text("Category")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(Color(hex: 0x857467))
                            Text("*")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: 0x4C2C33))
                        }
                        .padding(.leading, 6)
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                if let chip = selectedCategoryChip {
                                    Image(systemName: chip.icon)
                                    Text(chip.name).bold()
                                } else {
                                    Image(systemName: "square.grid.2x2.fill")
                                    Text("Select Category")
                                        .bold()
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .padding(8)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        (categoryChipIconColors[selectedCategoryChip?.name ?? ""] ?? .gray)
                                    )
                            )
                        }
                        .modifier(ShakeEffect(animatableData: categoryShake))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.leading, 6)
                        Button {
                            withAnimation {
                                isPrivate.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPrivate ? "lock.fill" : "globe")
                                Text(isPrivate ? "Private" : "Public").bold()
                            }
                            .padding(8)
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isPrivate ? Color(hex: 0xFE8C34) : Color(hex: 0x42ADFF))
                            )
                        }
                        .contentTransition(.symbolEffect(.replace))
                    }
                }
                .padding(.bottom, 10)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(Color(hex: 0xA26A2A), in: RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        if isValid {
                            onSave(rankoName, description, isPrivate, selectedCategoryChip)
                            dismiss()
                        } else {
                            if rankoName.isEmpty {
                                withAnimation { rankoNameShake += 1 }
                            }
                            if selectedCategoryChip == nil {
                                withAnimation { categoryShake += 1 }
                            }
                        }
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x6D400F), in: RoundedRectangle(cornerRadius: 8))
                    .opacity(isValid ? 1 : 0.6)
                }
                
                Spacer(minLength: 0)
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Text("Edit Ranko Details")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: 0x857467))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .padding(.horizontal, 22)
        // Category picker sheet
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                categoryChipsByCategory: categoryChipsByCategory,
                selectedCategoryChip: $selectedCategoryChip,
                isPresented: $showCategoryPicker
            )
        }
        // Use exact height (clamped to a minimum) for our sheet
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(hex: 0xFFF5E1))
        .interactiveDismissDisabled(true)
    }
}

struct TextView: UIViewRepresentable {
    
    typealias UIViewType = UITextView
    var configuration = { (view: UIViewType) in }
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIViewType {
        UIViewType()
    }
    
    func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<Self>) {
        configuration(uiView)
    }
}

struct DefaultListReRank: View {
    @Environment(\.dismiss) private var dismiss

    // Immutable source passed in
    private let originalItems: [RankoItem]
    private let onSave: ([RankoItem]) -> Void

    // Mutable working copy that the List will reorder
    @State private var draftItems: [RankoItem]
    // Used only to trigger/propagate animation when order changes
    @State private var reorderTick: Int = 0

    init(items: [RankoItem], onSave: @escaping ([RankoItem]) -> Void) {
        self.originalItems = items
        self.onSave = onSave
        _draftItems = State(initialValue: items)
    }

    var body: some View {
        NavigationStack {
            // iOS 17+: List with a *binding* to your array
            List($draftItems, editActions: .move) { $item in
                // Find the current index for badges/logic
                let index = draftItems.firstIndex(where: { $0.id == item.id }) ?? 0
                row(item: $item, index: index)
            }
            .listRowSeparator(.hidden)
            .listRowSpacing(5)
            .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listSectionMargins(.horizontal, 0)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        for i in draftItems.indices { draftItems[i].rank = i + 1 }
                        onSave(draftItems)
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .principal) {
                    Text("Edit Order")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: 0x857467))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        onSave(originalItems) // discard changes
                        dismiss()
                    }
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, -10)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea()
        }
        .presentationBackground(Color(hex: 0xFFF5E1))
        .interactiveDismissDisabled(true)
    }

    // MARK: - Row
    private func row(item: Binding<RankoItem>, index: Int) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                // Badge 1: current index (SFSymbols numbered circles exist up to ~50)
                if index == 0 {
                    Image(systemName: "1.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.65, blue: 0))
                } else if index == 1 {
                    Image(systemName: "2.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.635, green: 0.7, blue: 0.698))
                } else if index == 2 {
                    Image(systemName: "3.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.56, green: 0.33, blue: 0))
                } else {
                    Image(systemName: "\(min(index + 1, 50)).circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF9864))
                }

                // Badge 2: compare original rank to current position (animated)
                let currentRank = item.wrappedValue.rank
                let delta = currentRank - (index + 1)

                Group {
                    if delta != 0 {
                        let goingUp = delta > 0
                        HStack(spacing: 2) {
                            Image(systemName: goingUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(goingUp ? .green : .red)
                            Text(goingUp ? "\(delta)" : "\(delta * -1)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(goingUp ? .green : .red)
                        }
                    }
                }
            }

            // Item info
            HStack(spacing: 4) {
                AsyncImage(url: URL(string: item.wrappedValue.itemImage)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 35, height: 35)
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 35, height: 35)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 35, height: 35)
                            Image(systemName: "xmark.octagon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.trailing, 8)

                Text("\(item.wrappedValue.itemName)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: 0x6D400F))
            }
            .lineLimit(1)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF9EE))
        )
        .padding(.vertical, -8)
    }
}

struct DefaultListExit: View {
    @Environment(\.dismiss) var dismiss
    
    var onSave: () -> Void
    var onDelete: () -> Void   // NEW closure for delete

    var body: some View {
        VStack(spacing: 12) {
            Button {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onSave()        // run save in parent
                dismiss()       // dismiss ExitSheetView
            } label: {
                Text("Publish Ranko")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 12) {
                Button {
                    print("Cancel tapped")
                    dismiss() // just dismiss ExitSheetView
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                
                Button {
                    print("Delete tapped")
                    onDelete()      // trigger delete logic in parent
                    dismiss()       // close ExitSheetView
                } label: {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 30)
        .presentationBackground(Color.white)
        .presentationDetents([.height(160)])
        .interactiveDismissDisabled(true)
    }
}

struct DefaultListView_Previews: PreviewProvider {
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




// Helper to show placeholder in a TextField
extension View {
    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow {
                Text(text).foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            self
        }
    }
}

/// Renders any SwiftUI view into a UIImage
extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view!
        let targetSize = controller.view.intrinsicContentSize

        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}








