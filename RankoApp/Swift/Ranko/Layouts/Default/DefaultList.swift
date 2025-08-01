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
    
    @State private var activeTab: AppTab = .addItems
    
    // Item states
    @State private var selectedRankoItems: [AlgoliaRankoItem]
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var itemToEdit: AlgoliaRankoItem? = nil
    @State private var onSave: (AlgoliaRankoItem) -> Void

    // Active tab
    @State private var selectedTab: TabType? = nil

    enum TabType {
        case edit, add, reorder
    }
    
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: CategoryChip?,
        selectedRankoItems: [AlgoliaRankoItem] = [],
        onSave: @escaping (AlgoliaRankoItem) -> Void
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
                                        onSave(updatedItem)
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
                    dismiss()   // dismiss DefaultListView after saving
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

        let itemRecords: [RankoItemRecord] = []

        // 1) Build Group List Codable Struct
        let listRecord = RankoListRecord(
            objectID:         listUUID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
            RankoItems: Dictionary(uniqueKeysWithValues: itemRecords.map { item in
                return (item.objectID, ["Rank": item.ItemRank, "Votes": item.ItemVotes])
            })
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

        group.enter()
        itemsIndex.saveObjects(itemRecords) { result in
            switch result {
            case .success:
                print("✅ Items uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading items: \(error)")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            print("🎉 Upload to Algolia completed")
        }
        
        let nullFields: [String: Any?] = [
            "RankoID": listUUID,
            "RankoLikes": nil,
            "RankoComments": nil,
            "RankoVoters": nil
        ]

        let finalData = nullFields.mapValues { $0 ?? NSNull() }
        
        let db = Database.database().reference()
        db.child("RankoLists").child(listUUID).setValue(finalData)
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
        aedtFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let rankoDateTime = aedtFormatter.string(from: now)

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.timeZone = .current
        localFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoLocalDateTime = localFormatter.string(from: now)

        // 4) Top-level list payload with both fields
        let listDataForFirebase: [String: Any] = [
            "RankoID":              listUUID,
            "RankoName":            rankoName,
            "RankoDescription":     description,
            "RankoType":            "default",
            "RankoPrivacy":         isPrivate,
            "RankoCategory":        category.name,
            "RankoUserID":          safeUID,
            "RankoItems":           rankoItemsDict,
            "RankoDateTime":        rankoDateTime,        // AEDT
            "RankoLocalDateTime":   rankoLocalDateTime   // device’s local
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
          .child(safeUID)
          .child("RankoData")
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




//struct DefaultListViewTabBar: View {
//    @State private var activeTab: DefaultListTab = .devices
//    @State private var currentDetent: PresentationDetent = .height(80)
//    @State private var allDetents: Set<PresentationDetent> = [.height(80), .fraction(0.3), .fraction(0.5), .fraction(0.7), .fraction(0.9), .large]
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            TabView(selection: $activeTab) {
//                Tab.init(value: .people) {
//                    IndividualTabView(.people)
//                }
//                
//                Tab.init(value: .devices) {
//                    IndividualTabView(.devices)
//                }
//                
//                Tab.init(value: .items) {
//                    IndividualTabView(.items)
//                }
//                
//                Tab.init(value: .me) {
//                    IndividualTabView(.me)
//                }
//            }
//            .tabViewStyle(.tabBarOnly)
//            .background {
//                TabViewHelper()
//            }
//            .compositingGroup()
//            
//            CustomTabBar()
//        }
//        .ignoresSafeArea(.all)
//        .interactiveDismissDisabled()
//        .presentationDetents(allDetents, selection: $currentDetent)
//        .presentationBackgroundInteraction(.enabled)
//        .onChange(of: activeTab) { oldValue, newValue in
//            switch newValue {
//            case .people: currentDetent = .fraction(0.3)
//            case .devices: currentDetent = .fraction(0.5)
//            case .items: currentDetent = .fraction(0.7)
//            case .me: currentDetent = .fraction(0.9)
//            case .empty: currentDetent = .height(80)
//            }
//        }
//    }
//    
//    /// Individual Tab View
//    @ViewBuilder
//    func IndividualTabView(_ tab: DefaultListTab) -> some View {
//        ScrollView(.vertical) {
//            VStack {
//                HStack {
//                    Text(tab.rawValue)
//                        .font(.title)
//                        .fontWeight(.bold)
//                    
//                    Spacer(minLength: 0)
//                    
//                    Group {
//                        if #available(iOS 26, *) {
//                            Button {
//                                
//                            } label: {
//                                Image(systemName: "plus")
//                                    .font(.title3)
//                                    .fontWeight(.semibold)
//                                    .frame(width: 30, height: 30)
//                            }
//                            .buttonStyle(.glass)
//                        } else {
//                            Button {
//                                
//                            } label: {
//                                Image(systemName: "plus")
//                                    .font(.title3)
//                                    .fontWeight(.semibold)
//                                    .frame(width: 30, height: 30)
//                            }
//                        }
//                    }
//                    .buttonBorderShape(.circle)
//                }
//                .padding(.top, 10)
//            }
//            .padding(15)
//            
//            /// Your Tab Contents Here...
//        }
//        .toolbarVisibility(.hidden, for: .tabBar)
//        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
//    }
//    
//    /// Custom Tab Bar
//    @ViewBuilder
//    func CustomTabBar() -> some View {
//        HStack(spacing: 0) {
//            ForEach(DefaultListTab.visibleCases, id: \.rawValue) { tab in
//                VStack(spacing: 6) {
//                    Image(systemName: tab.symbolImage)
//                        .font(.title3)
//                        .symbolVariant(.fill)
//                    
//                    Text(tab.rawValue)
//                        .font(.caption2)
//                        .fontWeight(.semibold)
//                }
//                .foregroundStyle(activeTab == tab ? .blue : .gray)
//                .frame(maxWidth: .infinity)
//                .contentShape(.rect)
//                .onTapGesture {
//                    activeTab = tab
//                }
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.top, 10)
//        .padding(.bottom, 15)
//    }
//}













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









struct DefaultListView2: View {
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var user_data = UserInformation.shared

    // THESE FOUR need to be initialized via our custom init:
    @State private var listUUID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    
    @State private var originalRankoName: String
    @State private var originalDescription: String
    @State private var originalIsPrivate: Bool
    @State private var originalCategory: CategoryChip?

    // State to track sheets
//    @State private var activeAction: DefaultListAction? = nil
    @State private var selectedRankoItems: [AlgoliaRankoItem]
    @State private var selectedItem: AlgoliaRankoItem? = nil
    @State private var itemToEdit: AlgoliaRankoItem? = nil

    // Add activeTab state here:
    @State private var activeTab: AppTab = .addItems

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: – Press-and-Hold / Ring State for “Publish”
    @State private var publishForward: Double = 0.0    // 0→1 while filling
    @State private var publishReverse: Double = 0.0    // 1→0 while reversing
    @State private var isPublishReversing: Bool = false

    // MARK: – Press-and-Hold / Ring State for “Delete”
    @State private var deleteForward: Double = 0.0
    @State private var deleteReverse: Double = 0.0
    @State private var isDeleteReversing: Bool = false

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
    
    @State private var showBottomBar: Bool = true
    @State private var trayDetent: PresentationDetent = .fraction(0.4)
    @State private var previousDetent: PresentationDetent = .fraction(0.4)

    // ──────────────────────────────────────────────────────────────────────────
    // Custom initializer to seed the four @State vars
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: CategoryChip?,
        selectedRankoItems: [AlgoliaRankoItem] = [],
        onSave: @escaping (AlgoliaRankoItem) -> Void
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
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Gradient section that stretches into the top safe area
                    VStack(spacing: 12) {
                        header
                            .padding(.top, 80)
                        descriptionView
                        categoryPrivacyView
                            .padding(.bottom, 20)
                    }
                    .padding(.bottom)
                    .padding(.horizontal, 15)
                    .background(
                        RoundedCorner(radius: 20, corners: [.bottomLeft, .bottomRight])
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .ignoresSafeArea(edges: .top) // This line makes it stretch into the top safe area
                    )

                    // Divider below the rounded section

                    selectedItemsSection
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            

            // MARK: — Bottom Bar Overlay
//            bottomBar
//                .edgesIgnoringSafeArea(.bottom)

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
        .onChange(of: trayDetent) {
            let seconds = 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                previousDetent = trayDetent
            }
        }
//        .sheet(item: $activeAction, content: sheetContent)
        .sheet(item: $itemToEdit) { tappedItem in
            EditItemView(item: tappedItem, listID: listUUID) { newName, newDesc in
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
                listID: listUUID
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
//        .sheet(isPresented: $showBlankItemSliderSheet) {
//            VStack(spacing: 16) {
//                Text("Add Blank Items")
//                    .font(.headline)
//
//                Text("Select how many blank items to add")
//                    .font(.caption)
//
//                Slider(value: $blankItemCount, in: 1...Double(max(1, 50 - selectedRankoItems.count)), step: 1)
//
//                Text("\(Int(blankItemCount)) blank item(s)")
//                    .font(.title2)
//
//                Button("Add Items") {
//                    let count = Int(blankItemCount)
//                    let startRank = selectedRankoItems.count + 1
//                    for i in 0..<count {
//                        let id = UUID().uuidString
//                        let item = AlgoliaRankoItem(
//                            id: id,
//                            rank: startRank + i,
//                            votes: 0,
//                            record: AlgoliaItemRecord(
//                                objectID: id,
//                                ItemName: "Blank Item",
//                                ItemDescription: "Hold here • and click edit",
//                                ItemCategory: "",
//                                ItemImage: ""
//                            )
//                        )
//                        selectedRankoItems.append(item)
//                    }
//                    showBlankItemSliderSheet = false
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.orange)
//            }
//            .padding()
//            .presentationDetents([.fraction(0.3), .medium])
//        }
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showBottomBar) {
            if #available(iOS 26.0, *) {
                BottomBarView(
                    rankoName: $rankoName,
                    description: $description,
                    isPrivate: $isPrivate,
                    selectedCategoryChip: $category,
                    selectedRankoItems: $selectedRankoItems,
                    currentDetent: $trayDetent,
                    activeTab: $activeTab,
                    onSaveEditDetails: { newName, newDescription, newPrivate, newCategory in
                        if activeTab == .editDetails {
                            // Update original values to reflect confirmed save
                            originalRankoName = newName
                            originalDescription = newDescription
                            originalIsPrivate = newPrivate
                            originalCategory = newCategory
                            
                            rankoName = newName
                            description = newDescription
                            isPrivate = newPrivate
                            category = newCategory
                        }
                        activeTab = .empty
                    },
                    onCancelEditDetails: { _, _, _, _ in
                        if activeTab == .editDetails {
                            // Revert to original values
                            rankoName = originalRankoName
                            description = originalDescription
                            isPrivate = originalIsPrivate
                            category = originalCategory
                        }
                        activeTab = .empty
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .presentationDetents([previousDetent, trayDetent], selection: $trayDetent)
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(80)))
                .presentationBackground(.gray.opacity(0.1))
                .interactiveDismissDisabled(true)
            } else {
                // Fallback on earlier versions
            }
        }
        
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Header
    private var header: some View {
        HStack {
            Text(rankoName)
                .font(.title)
                .fontWeight(.black)
                .fontDesign(.rounded)
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: — Description View
    private var descriptionView: some View {
        HStack {
            if description.isEmpty {
                Text("No description yet…")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .foregroundColor(.white)
            } else {
                Text(description)
                    .lineLimit(3)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .foregroundColor(.white)
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
            .contextMenu {
                Button(action: {
                    
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .foregroundColor(.orange)
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
                        .sheet(isPresented: $showEditSheet) {
                            // Determine which item is centered
                            EditItemView(
                                item: item,
                                listID: listUUID
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
                                onSave(updatedItem)
                            }
                        }
                }
                .padding(.vertical, 5)
            }
            Spacer()
        }
    }

//    // MARK: — Bottom Bar Overlay
//    private var bottomBar: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 6) {
//                HStack(spacing: 0) {
//                    ForEach(DefaultListAction.allCases) { action in
//                        if action == .publish {
//                            pressAndHoldButton(
//                                action: action,
//                                symbolName: buttonSymbols[action.rawValue] ?? "",
//                                onPerform: {
//                                    let generator = UINotificationFeedbackGenerator()
//                                    generator.notificationOccurred(.success)
//
//                                    // Save list
//                                    saveRankedListToAlgolia()
//                                    
//                                    dismiss()
//                                },
//                                onTapToast: {
//                                    // Error haptic when they only tap
//                                    let generator = UINotificationFeedbackGenerator()
//                                    generator.notificationOccurred(.error)
//                                    showTemporaryToast("Hold down button to Publish")
//                                }
//                            )
//                        }
//                        else if action == .delete {
//                            pressAndHoldButton(
//                                action: action,
//                                symbolName: buttonSymbols[action.rawValue] ?? "",
//                                onPerform: {
//                                    // Success haptic right before performing the action
//                                    let generator = UINotificationFeedbackGenerator()
//                                    generator.notificationOccurred(.success)
//                                    dismiss()
//                                },
//                                onTapToast: {
//                                    // Error haptic when they only tap
//                                    let generator = UINotificationFeedbackGenerator()
//                                    generator.notificationOccurred(.error)
//                                    showTemporaryToast("Hold down button to Delete")
//                                }
//                            )
//                        }
//                        else {
//                            // Other actions (addItems, reRank, editDetails)
//                            Button {
//                                switch action {
//                                case .addItems, .reRank, .editDetails:
//                                    withAnimation {
//                                        activeAction = action
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

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Press-and-Hold Button with Separate Forward/Reverse Rings
//    @ViewBuilder
//    private func pressAndHoldButton(
//        action: DefaultListAction,
//        symbolName: String,
//        onPerform: @escaping () -> Void,
//        onTapToast: @escaping () -> Void
//    ) -> some View {
//        ZStack {
//            // ─────────
//            // 1) Button Content
//            VStack(spacing: 0) {
//                Image(systemName: symbolName)
//                    .font(.system(size: 13, weight: .black, design: .default))
//                    .frame(height: 20)
//                    .padding(.bottom, 6)
//
//                Text(action.rawValue)
//                    .font(.system(size: 9, weight: .black, design: .rounded))
//            }
//            .foregroundColor(.black)
//            .frame(minWidth: 20)
//            .padding(.vertical, 8)
//            .padding(.horizontal, 12)
//            .background(Color.white)
//            .cornerRadius(12)
//            // Short tap = show toast + error haptic
//            .onTapGesture {
//                onTapToast()
//            }
//            // Long press (≥1s) = success haptic + perform action
//            .onLongPressGesture(
//                minimumDuration: 1.0,
//                perform: {
//                    onPerform()
//                }
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//    }

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
            selectedRankoItems[index].rank = index + 1
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
//    // MARK: – Sheet Content Builder
//    @ViewBuilder
//    private func sheetContent(for action: DefaultListAction) -> some View {
//        switch action {
//        case .publish:
//            EmptyView()
//        case .addItems:
//            VStack(spacing: 20) {
//                Text("How would you like to add items?")
//                    .font(.headline)
//                Button("➕ Add Blank Items") {
//                    activeAction = nil
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                        showBlankItemSliderSheet = true
//                    }
//                }
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.orange.opacity(0.15))
//                .cornerRadius(12)
//
//                Button("🔍 Search Items") {
//                    activeAction = nil
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                        showItemSearch = true
//                    }
//                    showAddItemPopup = false
//                }
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.blue.opacity(0.15))
//                .cornerRadius(12)
//            }
//            .padding()
//            .presentationDetents([.fraction(0.3)])
//            .onAppear {
//                showAddItemPopup = true
//            }
//        case .reRank:
//            DefaultListReRank(
//                items: selectedRankoItems,
//                onSave: { newOrder in
//                    selectedRankoItems = newOrder
//                }
//            )
//        case .editDetails:
//            DefaultListEditDetails(
//                rankoName: rankoName,
//                description: description,
//                isPrivate: isPrivate,
//                category: category,
//                onSave: { currentDetent = .height(80) }
//            ) { newName, newDescription, newPrivate, newCategory in
//                rankoName    = newName
//                description  = newDescription
//                isPrivate    = newPrivate
//                category     = newCategory
//            }
//        case .delete:
//            EmptyView()
//        }
//    }

    private func removeItem(_ item: AlgoliaRankoItem) {
        selectedRankoItems.removeAll { $0.id == item.id }
    }

//    enum DefaultListAction: String, Identifiable, CaseIterable {
//        var id: String { self.rawValue }
//        case publish     = "Publish"
//        case addItems    = "Add Items"
//        case reRank      = "Re-Rank"
//        case editDetails = "Edit Details"
//        case delete      = "Delete"
//    }
//
//    var buttonSymbols: [String: String] {
//        [
//            "Publish":      "paperplane",
//            "Add Items":    "plus",
//            "Re-Rank":      "rectangle.stack",
//            "Edit Details": "pencil",
//            "Delete":       "trash"
//        ]
//    }
    
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

        let itemRecords: [RankoItemRecord] = []

        // 1) Build Group List Codable Struct
        let listRecord = RankoListRecord(
            objectID:         listUUID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
            RankoItems: Dictionary(uniqueKeysWithValues: itemRecords.map { item in
                return (item.objectID, ["Rank": item.ItemRank, "Votes": item.ItemVotes])
            })
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

        group.enter()
        itemsIndex.saveObjects(itemRecords) { result in
            switch result {
            case .success:
                print("✅ Items uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading items: \(error)")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            print("🎉 Upload to Algolia completed")
        }
        
        let nullFields: [String: Any?] = [
            "RankoID": listUUID,
            "RankoLikes": nil,
            "RankoComments": nil,
            "RankoVoters": nil
        ]

        let finalData = nullFields.mapValues { $0 ?? NSNull() }
        
        let db = Database.database().reference()
        db.child("RankoLists").child(listUUID).setValue(finalData)
    }

    func saveRankedList() {
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
        aedtFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let rankoDateTime = aedtFormatter.string(from: now)

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.timeZone = .current
        localFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoLocalDateTime = localFormatter.string(from: now)

        // 4) Top-level list payload with both fields
        let listDataForFirebase: [String: Any] = [
            "RankoID":              listUUID,
            "RankoName":            rankoName,
            "RankoDescription":     description,
            "RankoType":            "default",
            "RankoPrivacy":         isPrivate,
            "RankoCategory":        category.name,
            "RankoUserID":          safeUID,
            "RankoItems":           rankoItemsDict,
            "RankoDateTime":        rankoDateTime,        // AEDT
            "RankoLocalDateTime":   rankoLocalDateTime   // device’s local
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
          .child(safeUID)
          .child("RankoData")
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
enum AppTab: String, CaseIterable {
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
    
    static var visibleCases: [AppTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}

@available(iOS 26.0, *)
struct BottomBarView: View {
    @Binding var rankoName: String
    @Binding var description: String
    @Binding var isPrivate: Bool
    @Binding var selectedCategoryChip: CategoryChip?
    @Binding var selectedRankoItems: [AlgoliaRankoItem]
    
    @State private var activeTabInternal: AppTab = .addItems
    @Binding var currentDetent: PresentationDetent
    @Binding var activeTab: AppTab
    
    // 👇 Changed these:
    var onSaveEditDetails: (String, String, Bool, CategoryChip?) -> Void
    var onCancelEditDetails: (String, String, Bool, CategoryChip?) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                CustomTabBar()
                
                TabView(selection: $activeTab) {
                    Tab.init(value: .addItems) {
                        ScrollView(.vertical) {
                            VStack {
                                HStack {
                                    Text("Add Items")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    
                                    Spacer(minLength: 0)
                                    
                                    Group {
                                        Button {
                                            currentDetent = .height(80)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                                .fontWeight(.black)
                                                .frame(width: 30, height: 30)
                                        }
                                        .buttonStyle(.glass)
                                    }
                                    .buttonBorderShape(.circle)
                                }
                                .padding(.top, 15)
                                .padding(.leading, 10)
                            }
                            .padding(15)
                            
                            /// Your Tab Contents Here...
                        }
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
                    }
                    
                    Tab.init(value: .editDetails) {
//                        DefaultListEditDetails(
//                            rankoName: $rankoName,
//                            description: $description,
//                            isPrivate: $isPrivate,
//                            selectedCategoryChip: $selectedCategoryChip,
//                            onSave: {
//                                activeTab = .empty
//                            },
//                            onCancel: {
//                                activeTab = .empty
//                            }
//                        )
                    }
                    
                    Tab.init(value: .reRank) {
                        DefaultListReRank(
                            items: selectedRankoItems,
                            onSave: { newOrder in
                                selectedRankoItems = newOrder
                                activeTab = .empty
                            }
                        )
                    }
                    
                    Tab.init(value: .exit) {
                        IndividualTabView(.exit)
                    }
                    
                    Tab.init(value: .empty) {
                        EmptyView()
                    }
                }
                .tabViewStyle(.tabBarOnly)
                .background {
                    if #available(iOS 26, *) {
                        TabViewHelper()
                    }
                }
                .compositingGroup()
                
                
            }
            .ignoresSafeArea(.all, edges: isiOS26 ? .bottom : [])
            
            
        }
        .onChange(of: activeTab) { oldValue, newValue in
            switch newValue {
            case .addItems: currentDetent = .fraction(0.4)
            case .editDetails: currentDetent = .fraction(0.5)
            case .reRank: currentDetent = .large
            case .exit: currentDetent = .fraction(0.4)
            case .empty: currentDetent = .height(80)
            }
        }
        .interactiveDismissDisabled()
    }
    
    /// Individual Tab View
    @ViewBuilder
    func IndividualTabView(_ tab: AppTab) -> some View {
        ScrollView(.vertical) {
            VStack {
                HStack {
                    Text(tab.rawValue)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer(minLength: 0)
                    
                    Group {
                        Button {
                            
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.glass)
                    }
                    .buttonBorderShape(.circle)
                }
                .padding(.top, isiOS26 ? 15 : 10)
                .padding(.leading, isiOS26 ? 10 : 0)
            }
            .padding(15)
            
            /// Your Tab Contents Here...
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
    }
    
    /// Custom Tab Bar
    @ViewBuilder
    func CustomTabBar() -> some View {
        HStack(spacing: activeTab == .empty ? 0 : 8) {
            if activeTab != .empty {
                // CANCEL
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    onCancelEditDetails(rankoName, description, isPrivate, selectedCategoryChip) // 👈 call lifted cancel logic with params
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.red.gradient))
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.leading, 5)
            }

            Spacer()

            ForEach(AppTab.visibleCases, id: \.rawValue) { tab in
                Group {
                    if activeTab == .empty {
                        VStack(spacing: 4) {
                            Image(systemName: tab.symbolImage)
                                .symbolVariant(.fill)
                                .font(.system(size: 28))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.orange)
                                .frame(height: 40)

                            Text(tab.rawValue)
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .transition(.opacity)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                activeTab = tab
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: tab.symbolImage)
                                .symbolVariant(.fill)
                                .font(.title3)
                                .foregroundStyle(activeTab == tab ? .orange : .orange.opacity(0.3))

                            if activeTab == tab {
                                Text(tab.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                        .padding(.horizontal, activeTab == tab ? 12 : 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                activeTab = tab
                            }
                        }
                    }
                }
            }

            Spacer()

            if activeTab != .empty {
                // SAVE
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onSaveEditDetails(rankoName, description, isPrivate, selectedCategoryChip) // 👈 call lifted save logic with params
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.green.gradient))
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.trailing, 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
    
    struct BlurGlassBackground: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(.ultraThinMaterial)
                .blur(radius: 0.5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.horizontal)
        }
    }
}

@available(iOS 26, *)
fileprivate struct TabViewHelper: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            guard let compostingGroup = view.superview?.superview else { return }
            guard let swiftUIWrapperUITabView = compostingGroup.subviews.last else { return }
            
            if let tabBarController = swiftUIWrapperUITabView.subviews.first?.next as? UITabBarController {
                /// Clearing Backgrounds
                tabBarController.view.backgroundColor = .clear
                tabBarController.viewControllers?.forEach {
                    $0.view.backgroundColor = .clear
                }
                
                tabBarController.delegate = context.coordinator
                
                /// Temporary Solution!
                tabBarController.tabBar.removeFromSuperview()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {  }
    
    class Coordinator: NSObject, UITabBarControllerDelegate, UIViewControllerAnimatedTransitioning {
        func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            return self
        }
        
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            return .zero
        }
        
        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let destinationView = transitionContext.view(forKey: .to) else { return }
            let containerView = transitionContext.containerView
            
            containerView.addSubview(destinationView)
            transitionContext.completeTransition(true)
        }
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
    
    private let originalRankoName: String = ""
    private let originalDescription: String = ""
    private let originalIsPrivate: Bool = false
    private let originalCategory: CategoryChip? = nil
    
    private let onSave: (String, String, Bool, CategoryChip?) -> Void
    
    // Custom initializer to seed @State and capture originals + onSave and onRequestClose
    
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
        VStack(spacing: 16) {
            // MARK: – Ranko Name Field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Ranko Name").foregroundColor(.secondary)
                    Text("*").foregroundColor(.red)
                }
                .font(.caption2).bold()
                HStack {
                    Image(systemName: "trophy.fill").foregroundColor(.gray)
                    TextField("", text: $rankoName)
                        .placeholder("Top 15 Countries", when: rankoName.isEmpty)
                        .onChange(of: rankoName) {
                            if rankoName.count > 50 {
                                rankoName = String(rankoName.prefix(50))
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(rankoName.count)/50")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white))
            }
            .modifier(ShakeEffect(animatableData: rankoNameShake))
            
            // MARK: – Description Field (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Description, if any")
                    .font(.caption2).foregroundColor(.secondary).bold()
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundColor(.gray)
                    TextField("", text: $description)
                        .placeholder("Description", when: description.isEmpty)
                        .onChange(of: description) {
                            if description.count > 100 {
                                description = String(description.prefix(100))
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(description.count)/100")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white))
            }
            
            // MARK: – Category & Privacy Toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Category").foregroundColor(.secondary)
                        Text("*").foregroundColor(.red)
                    }
                    .font(.caption2).bold()
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            if let categoryChip = selectedCategoryChip {
                                Image(systemName: categoryChip.icon)
                                Text(categoryChip.name).bold()
                            } else {
                                Image(systemName: "square.grid.2x2.fill")
                                Text("Select Category").bold()
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(8)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill((categoryChipIconColors[selectedCategoryChip?.name ?? ""] ?? .gray)))
                    }
                    .modifier(ShakeEffect(animatableData: categoryShake))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)

                VStack(alignment: .center, spacing: 4) {
                    Text("Private")
                        .foregroundColor(.secondary)
                        .font(.caption2).bold()
                    Toggle(isOn: $isPrivate) {}
                        .tint(.orange)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
            
            HStack(spacing: 12) {
                
                Button {
                    print("Cancel tapped")
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                
                Button {
                    if isValid {
                        onSave(rankoName, description, isPrivate, selectedCategoryChip)
                        dismiss()
                    }
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                .opacity(isValid ? 1 : 0.6)
            }
        }
        .ignoresSafeArea()
        .padding(16)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                categoryChipsByCategory: categoryChipsByCategory,
                selectedCategoryChip: $selectedCategoryChip,
                isPresented: $showCategoryPicker
            )
        }
        .presentationDetents([.fraction(0.4), .medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
    
    private func revertEdits() {
        rankoName = originalRankoName
        description = originalDescription
        isPrivate = originalIsPrivate
        selectedCategoryChip = originalCategory
    }
}


struct DefaultListView_Previews: PreviewProvider {
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








struct DefaultListReRank: View {
    @Environment(\.dismiss) private var dismiss

    /// The original items, injected at init
    private let originalItems: [AlgoliaRankoItem]
    /// Called when the user taps “Save”
    private let onSave: ([AlgoliaRankoItem]) -> Void

    /// A mutable copy we reorder in the UI
    @State private var draftItems: [AlgoliaRankoItem]

    init(
        items: [AlgoliaRankoItem],
        onSave: @escaping ([AlgoliaRankoItem]) -> Void
    ) {
        self.originalItems = items
        self.onSave = onSave
        // seed the draft with the passed-in order
        _draftItems = State(initialValue: items)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The re-orderable list
            List {
                // Enumerate draftItems so we can display the current index + 1
                ForEach(Array(draftItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 2) {
                        // Badge 1: current index in the list
                        Group {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundColor(.gray)
                                .font(.body)
                                .padding(3)
                        }
                        .font(.title2)

                        // Badge 2: the item.rank value
                        Group {
                            switch item.rank {
                            default:
                                let badgeColor: Color = {
                                    if item.rank < (index + 1) {
                                        return .red
                                    } else if item.rank > (index + 1) {
                                        return .green
                                    } else {
                                        return Color(red: 1, green: 0.65, blue: 0)
                                    }
                                }()
                                Image(systemName: "\(item.rank).circle.fill")
                                    .foregroundColor(badgeColor)
                                    .font(.body)
                                    .padding(3)
                            }
                        }
                        .font(.title2)

                        // Item info
                        HStack {
                            HStack {
                                Text(item.itemName).fontWeight(.bold)
                                Text("-").foregroundColor(.gray)
                                Text(item.itemDescription).foregroundColor(.gray)
                            }
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    draftItems.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            // Put the list into “edit” mode so drag handles appear
            .environment(\.editMode, .constant(.active))

            Divider()

            // Cancel / Save buttons
            HStack(spacing: 12) {
                
                Button {
                    print("Cancel tapped")
                    onSave(originalItems)
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                
                Button {
                    for idx in draftItems.indices {
                        draftItems[idx].rank = idx + 1
                    }
                    onSave(draftItems)
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .interactiveDismissDisabled(true)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
