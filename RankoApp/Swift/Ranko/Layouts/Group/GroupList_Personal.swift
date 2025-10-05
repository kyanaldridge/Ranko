//
//  GroupList_Personal.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import FirebaseAuth
import Firebase
import AlgoliaSearchClient

// MARK: - GROUP LIST VIEW
//struct GroupListPersonal: View {
//    
//    @Environment(\.dismiss) var dismiss
//    @StateObject private var user_data = UserInformation.shared
//    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList
//    
//    // MARK: - RANKO LIST DATA
//    let listID: String
//    @State private var rankoName: String
//    @State private var description: String
//    @State private var isPrivate: Bool
//    @State private var category: SampleCategoryChip?
//    @State private var categoryID: String = ""
//    @State private var categoryName: String = ""
//    @State private var categoryIcon: String? = nil
//    
//    // Sheet states
//    @State private var showTabBar = true
//    @State private var tabBarPresent = false
//    @State private var showEmbeddedStickyPoolSheet = false
//    @State var showEditDetailsSheet = false
//    @State var showAddItemsSheet = false
//    @State var showReorderSheet = false
//    @State var showEditItemSheet = false
//    @State var showExitSheet = false
//    @State var showDeleteAlert = false
//    
//    // MARK: - ITEM VARIABLES
//    @State private var unGroupedItems: [RankoItem] = []
//    @State private var groupedItems: [[RankoItem]]
//    @State private var selectedDetailItem: RankoItem? = nil
//    
//    // MARK: - OTHER VARIABLES (INC. TOAST)
//    @State private var hoveredRow: Int? = nil
//    
//    @State private var activeTab: GroupListPersonalTab = .addItems
//    
//    @State private var onSave: ((RankoItem) -> Void)? = nil
//    private let onDelete: (() -> Void)?
//    
//    private enum GroupViewMode: String, CaseIterable {
//        case biggerList, defaultList, largeGrid
//    }
//    
//    enum TabType {
//        case edit, add, reorder
//    }
//    // MARK: - INITIALISER
//    
//    init(
//        listID: String,
//        rankoName: String = "Not Found",
//        description: String = "",
//        isPrivate: Bool = false,
//        category: SampleCategoryChip? = SampleCategoryChip(
//            id: "",
//            name: "Unknown",
//            icon: "questionmark.circle.fill",
//            colour: "0xFFCF00"
//        ),
//        groupedItems: [RankoItem] = [],
//        onSave: ((RankoItem) -> Void)? = nil,
//        onDelete: (() -> Void)? = nil
//    ) {
//        self.listID = listID
//        _rankoName    = State(initialValue: rankoName)
//        _description  = State(initialValue: description)
//        _isPrivate    = State(initialValue: isPrivate)
//        _category     = State(initialValue: category)
//        
//        // Group flat array into rows by the thousands‐digit of "rank"
//        let dict = Dictionary(grouping: groupedItems) { $0.rank / 1000 }
//        let sortedKeys = dict.keys.sorted()
//        let rows = sortedKeys.compactMap { dict[$0] }
//        _groupedItems = State(initialValue: rows)
//        _onSave = State(initialValue: onSave)
//        self.onDelete = onDelete
//    }
//    
//    // MARK: - BODY VIEW
//    
//    var body: some View {
//        ZStack(alignment: .top) {
//            Color(hex: 0xFFF5E1).ignoresSafeArea()
//            ScrollView {
//                VStack(spacing: 7) {
//                    HStack {
//                        Text(rankoName)
//                            .font(.system(size: 28, weight: .black, design: .default))
//                            .foregroundColor(Color(hex: 0x6D400F))
//                        Spacer()
//                    }
//                    .padding(.top, 20)
//                    .padding(.leading, 20)
//                    
//                    HStack {
//                        Text(description.isEmpty ? "No description yet…" : description)
//                            .lineLimit(3)
//                            .font(.system(size: 12, weight: .bold, design: .default))
//                            .foregroundColor(Color(hex: 0x925611))
//                        Spacer()
//                    }
//                    .padding(.top, 5)
//                    .padding(.leading, 20)
//                    
//                    HStack(spacing: 8) {
//                        HStack(spacing: 4) {
//                            Image(systemName: isPrivate ? "lock.fill" : "globe.americas.fill")
//                                .font(.system(size: 12, weight: .bold, design: .default))
//                                .foregroundColor(.white)
//                                .padding(.leading, 10)
//                            Text(isPrivate ? "Private" : "Public")
//                                .font(.system(size: 12, weight: .bold, design: .default))
//                                .foregroundColor(.white)
//                                .padding(.trailing, 10)
//                                .padding(.vertical, 8)
//                        }
//                        .background(
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(Color(hex: 0xF2AB69))
//                        )
//                        
//                        if let cat = category {
//                            HStack(spacing: 4) {
//                                Image(systemName: cat.icon)
//                                    .font(.caption)
//                                    .fontWeight(.bold)
//                                    .foregroundColor(.white)
//                                    .padding(.leading, 10)
//                                Text(cat.name)
//                                    .font(.system(size: 12, weight: .bold, design: .default))
//                                    .foregroundColor(.white)
//                                    .padding(.trailing, 10)
//                                    .padding(.vertical, 8)
//                                
//                            }
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(categoryChipIconColors[cat.name] ?? .gray)
//                                    .opacity(0.6)
//                            )
//                        }
//                        
//                        Spacer()
//                        
//                        HStack(spacing: 3) {
//                            // Default List Button
//                            Button(action: { groupViewMode = .defaultList }) {
//                                VStack(spacing: 4) {
//                                    Image(systemName: "rectangle.compress.vertical")
//                                        .font(.system(size: 14, weight: .medium, design: .default))
//                                        .foregroundColor(groupViewMode == .defaultList ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
//                                        .padding(.bottom, 2)
//                                    if groupViewMode == .defaultList {
//                                        // Blue glowing underline when selected
//                                        Rectangle()
//                                            .fill(Color(hex: 0x6D400F))
//                                            .frame(width: 30, height: 2)
//                                            .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 4, x: 0, y: 0)
//                                    } else {
//                                        Color.clear.frame(width: 30, height: 2)
//                                    }
//                                }
//                            }
//                            
//                            // Large Grid Button
//                            Button(action: { groupViewMode = .largeGrid }) {
//                                VStack(spacing: 4) {
//                                    Image(systemName: "square.grid.2x2")
//                                        .font(.caption)
//                                        .foregroundColor(groupViewMode == .largeGrid ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
//                                        .padding(.bottom, 2)
//                                    if groupViewMode == .largeGrid {
//                                        Rectangle()
//                                            .fill(Color(hex: 0x6D400F))
//                                            .frame(width: 30, height: 2)
//                                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
//                                    } else {
//                                        Color.clear.frame(width: 30, height: 2)
//                                    }
//                                }
//                            }
//                            
//                            // Compact List Button
//                            Button(action: { groupViewMode = .biggerList }) {
//                                VStack(spacing: 4) {
//                                    Image(systemName: "inset.filled.topleft.topright.bottomleft.bottomright.rectangle")
//                                        .font(.caption)
//                                        .foregroundColor(groupViewMode == .biggerList ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
//                                        .padding(.bottom, 2)
//                                    if groupViewMode == .biggerList {
//                                        Rectangle()
//                                            .fill(Color(hex: 0x6D400F))
//                                            .frame(width: 30, height: 2)
//                                            .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 4, x: 0, y: 0)
//                                    } else {
//                                        Color.clear.frame(width: 30, height: 2)
//                                    }
//                                }
//                            }
//                        }
//                        .padding(.trailing, 8)
//                        
//                    }
//                    .padding(.leading, 20)
//                    
//                    Divider()
//                    
//                    switch groupViewMode {
//                    case .defaultList:
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRowView(
//                                        rowIndex:       i,
//                                        items:          groupedItems[i],
//                                        itemRows:       $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow:     $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                
//                                // “New row” placeholder
//                                Button {
//                                    groupedItems.append([])
//                                } label: {
//                                    HStack {
//                                        Image(systemName: "plus")
//                                            .foregroundColor(.white)
//                                            .fontWeight(.bold)
//                                            .font(.headline)
//                                    }
//                                    .padding(.vertical, 12)
//                                    .frame(maxWidth: .infinity)
//                                    .background(Color(hex: 0x6D400F))
//                                    .cornerRadius(8)
//                                    .padding(.horizontal)
//                                }
//                            }
//                            .padding(.top, 10)
//                            // leave space so content can scroll above the sticky pool + bottomBar
//                            .padding(.bottom, 180)
//                        }
//                        
//                    case .largeGrid:
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRowView2(
//                                        rowIndex:       i,
//                                        items:          groupedItems[i],
//                                        itemRows:       $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow:     $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                
//                                // “New row” placeholder
//                                Button {
//                                    groupedItems.append([])
//                                } label: {
//                                    HStack {
//                                        Image(systemName: "plus")
//                                            .foregroundColor(.white)
//                                            .fontWeight(.bold)
//                                            .font(.headline)
//                                    }
//                                    .padding(.vertical, 12)
//                                    .frame(maxWidth: .infinity)
//                                    .background(Color(hex: 0x6D400F))
//                                    .cornerRadius(8)
//                                    .padding(.horizontal)
//                                }
//                            }
//                            .padding(.top, 10)
//                            // leave space so content can scroll above the sticky pool + bottomBar
//                            .padding(.bottom, 180)
//                        }
//                        
//                    case .biggerList:
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRowView3(
//                                        rowIndex:       i,
//                                        items:          groupedItems[i],
//                                        itemRows:       $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow:     $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                
//                                // “New row” placeholder
//                                Button {
//                                    groupedItems.append([])
//                                } label: {
//                                    HStack {
//                                        Image(systemName: "plus")
//                                            .foregroundColor(.white)
//                                            .fontWeight(.bold)
//                                            .font(.headline)
//                                    }
//                                    .padding(.vertical, 12)
//                                    .frame(maxWidth: .infinity)
//                                    .background(Color(hex: 0x6D400F))
//                                    .cornerRadius(8)
//                                    .padding(.horizontal)
//                                }
//                            }
//                            .padding(.top, 10)
//                            // leave space so content can scroll above the sticky pool + bottomBar
//                            .padding(.bottom, 180)
//                        }
//                    }
//                    
//                    
//                    Spacer(minLength: 60) // leave room for bottom bar
//                }
//                .padding(.top, 20)
//            }
//            
//            VStack {
//                Spacer()
//                Rectangle()
//                    .frame(height: 90)
//                    .foregroundColor(tabBarPresent ? Color(hex: 0xFFEBC2) : .white)
//                    .blur(radius: 23)
//                    .opacity(tabBarPresent ? 1 : 0)
//                    .animation(.easeInOut(duration: 0.4), value: tabBarPresent) // ✅ Fast fade animation
//                    .ignoresSafeArea()
//            }
//            .ignoresSafeArea()
//            
//        }
//        .onAppear {
////            loadListFromFirebase()
//        }
//        .sheet(isPresented: $showAddItemsSheet, onDismiss: {
//            // When FilterChipPickerView closes, trigger the embeddedStickyPoolView sheet
//            showEmbeddedStickyPoolSheet = true
//        }) {
//            FilterChipPickerView(
//                selectedRankoItems: $unGroupedItems
//            )
//        }
//        .sheet(isPresented: $showEditDetailsSheet) {
//            DefaultListEditDetails(
//                rankoName: rankoName,
//                description: description,
//                isPrivate: isPrivate,
//                category: category
//            ) { newName, newDescription, newPrivate, newCategory in
//                rankoName    = newName
//                description  = newDescription
//                isPrivate    = newPrivate
//                category     = newCategory
//            }
//        }
//        .sheet(isPresented: $showReorderSheet) {
//            EmptyView()
//        }
//        .alert(isPresented: $showDeleteAlert) {
//            CustomDialog(
//                title: "Delete Ranko?",
//                content: "Are you sure you want to delete your Ranko.",
//                image: .init(
//                    content: "trash.fill",
//                    background: .red,
//                    foreground: .white
//                ),
//                button1: .init(
//                    content: "Delete",
//                    background: .red,
//                    foreground: .white,
//                    action: { _ in
//                        showDeleteAlert = false
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
//                            removeFeaturedRanko(listID: listID) { success in}
//                            deleteRanko() { success in
//                                if success {
//                                    print("🎉 Fields updated in Algolia")
//                                } else {
//                                    print("⚠️ Failed to update fields")
//                                }
//                            }
//                            onDelete!()
//                            dismiss()
//                        }
//                    }
//                ),
//                button2: .init(
//                    content: "Cancel",
//                    background: .orange,
//                    foreground: .white,
//                    action: { _ in
//                        showDeleteAlert = false
//                        showTabBar = false
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
//                            showTabBar = true
//                        }
//                    }
//                )
//            )
//            .transition(.blurReplace.combined(with: .push(from: .bottom)))
//        } background: {
//            Rectangle()
//                .fill(.primary.opacity(0.35))
//        }
//        .sheet(isPresented: $showEmbeddedStickyPoolSheet) {
//            embeddedStickyPoolView
//                .interactiveDismissDisabled(true) // prevents accidental swipe-down
//                .presentationDetents([.height(110)]) // customize detents if needed
//                .presentationDragIndicator(.hidden)
//                .presentationBackgroundInteraction(.enabled)
//                .onChange(of: unGroupedItems.count) { _, newValue in
//                    if newValue == 0 {
//                        withAnimation {
//                            showEmbeddedStickyPoolSheet = false  // Hide only the embedded view
//                        }
//                    }
//                }
//                .onAppear {
//                    if unGroupedItems.isEmpty {
//                        showEmbeddedStickyPoolSheet = false
//                    }
//                }
//        }
//        .sheet(isPresented: $showTabBar) {
//            VStack {
//                HStack(spacing: 0) {
//                    ForEach(GroupListPersonalTab.visibleCases, id: \.rawValue) { tab in
//                        VStack(spacing: 6) {
//                            Image(systemName: tab.symbolImage)
//                                .font(.title3)
//                                .symbolVariant(.fill)
//                                .frame(height: 28)
//                            
//                            Text(tab.rawValue)
//                                .font(.caption2)
//                                .fontWeight(.semibold)
//                        }
//                        .foregroundStyle(Color(hex: 0x925610))
//                        .frame(maxWidth: .infinity)
//                        .contentShape(.rect)
//                        .onTapGesture {
//                            activeTab = tab
//                            switch tab {
//                            case .addItems:
//                                showAddItemsSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .editDetails:
//                                showEditDetailsSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .reRank:
//                                showReorderSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .exit:
//                                showExitSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .empty:
//                                dismiss()
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 20)
//            }
//            .interactiveDismissDisabled(true)
//            .presentationDetents([.height(80)])
//            .presentationBackground((Color(hex: 0xfff9ee)))
//            .presentationBackgroundInteraction(.enabled)
//            .onAppear {
//                tabBarPresent = false      // Start from invisible
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                    withAnimation(.easeInOut(duration: 0.2)) {
//                        tabBarPresent = true
//                    }
//                }
//            }
//            .onDisappear {
//                withAnimation(.easeInOut(duration: 0.2)) {
//                    tabBarPresent = false
//                }
//            }
//        }
//        .sheet(item: $selectedDetailItem) { tappedItem in
//            let rowIndex = groupedItems.firstIndex { row in
//                row.contains { $0.id == tappedItem.id }
//            } ?? 0
//            
//            GroupItemDetailView(
//                items: groupedItems[rowIndex],
//                rowIndex: rowIndex,
//                numberOfRows: (groupedItems.count),
//                initialItem: tappedItem,
//                listID:  listID
//            ) { updatedItem in
//                if let idx = groupedItems[rowIndex]
//                    .firstIndex(where: { $0.id == updatedItem.id }) {
//                    groupedItems[rowIndex][idx] = updatedItem
//                }
//            }
//        }
//        .interactiveDismissDisabled(true)
//    }
//    
//    // MARK: - EMBEDDED STICKY POOL
//    private var embeddedStickyPoolView: some View {
//        VStack(spacing: 6) {
//            Text("Drag the below items to groups")
//                .font(.caption2)
//                .foregroundColor(.gray)
//                .padding(.top, 3)
//            
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 12) {
//                    ForEach(unGroupedItems) { item in
//                        GroupSelectedItemRow(item: item)
//                            .onDrag { NSItemProvider(object: item.id as NSString) }
//                    }
//                }
//                .padding(.horizontal, 8)
//                .padding(.vertical, 4)
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .onDrop(
//            of: ["public.text"],
//            delegate: RowDropDelegate(
//                itemRows:   $groupedItems,
//                unGrouped:  $unGroupedItems,
//                hoveredRow: $hoveredRow,
//                targetRow:  nil
//            )
//        )
//    }
//    
////    private func loadListFromFirebase() {
////        let ref = Database.database().reference()
////            .child("RankoData")
////            .child(listID)
////
////        ref.observeSingleEvent(of: .value, with: { snap in
////            guard let dict = snap.value as? [String: Any] else {
////                return
////            }
////
////            // Core fields
////            guard
////                let name = dict["RankoName"] as? String,
////                let description = dict["RankoDescription"] as? String,
////                let type = dict["RankoType"] as? String,
////                let isPrivate = dict["RankoPrivacy"] as? Bool,
////                let userID = dict["RankoUserID"] as? String,
////                let dateTimeStr = dict["RankoDateTime"] as? String
////            else {
////                return
////            }
////
////            // Category (nested)
////            let cat = dict["RankoCategory"] as? [String: Any] ?? [:]
////            let catName  = (cat["name"] as? String) ?? ""
////            let catIcon  = (cat["icon"] as? String) ?? ""
////            let catColour = UInt(cat["colour"] as! String) ?? UInt(0xFFFFFF)  // store as Int; convert to your Color later
////
////            // Items
////            let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
////            let items: [RankoItem] = itemsDict.compactMap { itemID, item in
////                guard
////                    let itemName = item["ItemName"] as? String,
////                    let itemDesc = item["ItemDescription"] as? String,
////                    let itemImage = item["ItemImage"] as? String
////                else { return nil }
////
////                let rank  = intFromAny(item["ItemRank"])  ?? 0
////                let votes = intFromAny(item["ItemVotes"]) ?? 0
////
////                let record = RankoRecord(
////                    objectID: itemID,
////                    ItemName: itemName,
////                    ItemDescription: itemDesc,
////                    ItemCategory: "category",  // replace if you store real per-item category
////                    ItemImage: itemImage
////                )
////                return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
////            }
////
//////            let list = RankoList(
//////                id: listID,
//////                listName: name,
//////                listDescription: description,
//////                type: type,
//////                categoryName: catName,
//////                categoryIcon: catIcon,
//////                categoryColour: catColour,
//////                isPrivate: isPrivate ? "Private" : "Public",
//////                userCreator: userID,
//////                timeCreated: dateTimeStr,
//////                timeUpdated: dateTimeStr,
//////                items: items
//////            )
////        })
////    }
//
//    // Helper to safely coerce Firebase numbers/strings into Int
//    private func intFromAny(_ any: Any?) -> Int? {
//        if let i = any as? Int { return i }
//        if let d = any as? Double { return Int(d) }
//        if let s = any as? String { return Int(s) }
//        if let n = any as? NSNumber { return n.intValue }
//        return nil
//    }
//    
//    private func fetchCategoryByID(_ id: String, completion: @escaping (SampleCategoryChip?) -> Void) {
//        let ref = Database.database().reference()
//            .child("AppData").child("Ranko").child("CategoryData").child("Definitions").child(id) // <- correct path
//
//        ref.observeSingleEvent(of: .value) { snap in
//            guard let dict = snap.value as? [String: Any] else {
//                completion(nil); return
//            }
//            let cd = SampleCategoryChip(
//                id: id,
//                name: dict["name"] as? String ?? id,
//                icon: (dict["icon"] as? String)!,
//                colour: (dict["colour"] as? String?)!!
//            )
//            completion(cd)
//        }
//    }
//
//    private func fetchCategoryByName(_ name: String, completion: @escaping (SampleCategoryChip?) -> Void) {
//        // scan CategoryData once; if your DB is large, consider caching
//        let ref = Database.database().reference()
//            .child("AppData").child("Ranko").child("CategoryData").child("Definitions")
//
//        ref.observeSingleEvent(of: .value) { snap in
//            guard let all = snap.value as? [String: [String: Any]] else {
//                completion(nil); return
//            }
//            // case-insensitive match on "name"
//            if let (id, dict) = all.first(where: { (_, v) in
//                (v["name"] as? String)?.caseInsensitiveCompare(name) == .orderedSame
//            }) {
//                let cd = SampleCategoryChip(
//                    id: id,
//                    name: (dict["name"] as? String) ?? name,
//                    icon: (dict["icon"] as? String)!,
//                    colour: (dict["colour"] as? String?)!!
//                )
//                completion(cd)
//            } else {
//                completion(nil)
//            }
//        }
//    }
//    
//    private func deleteRanko(completion: @escaping (Bool) -> Void
//    ) {
//        let db = Database.database().reference()
//        
//        let statusUpdate: [String: Any] = [
//            "RankoStatus": "deleted"
//        ]
//        
//        let listRef = db.child("RankoData").child(listID)
//        
//        // ✅ Update list fields
//        listRef.updateChildValues(statusUpdate) { error, _ in
//            if let err = error {
//                print("❌ Failed to update list fields: \(err.localizedDescription)")
//            } else {
//                print("✅ List fields updated successfully")
//            }
//        }
//        
//        let client = SearchClient(
//            appID: ApplicationID(rawValue: Secrets.algoliaAppID),
//            apiKey: APIKey(rawValue: Secrets.algoliaAPIKey)
//        )
//        let index = client.index(withName: "RankoLists")
//
//        // ✅ Prepare partial updates
//        let updates: [(ObjectID, PartialUpdate)] = [
//            (ObjectID(rawValue: listID), .update(attribute: "RankoStatus", value: "deleted"))
//        ]
//
//        // ✅ Perform batch update in Algolia
//        index.partialUpdateObjects(updates: updates) { result in
//            switch result {
//            case .success(let response):
//                print("✅ Ranko list status updated successfully:", response)
//                completion(true)
//            case .failure(let error):
//                print("❌ Failed to update Ranko list status:", error.localizedDescription)
//                completion(false)
//            }
//        }
//    }
//    
//    func removeFeaturedRanko(listID: String, completion: @escaping (Result<Void, Error>) -> Void) {
//        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
//            // No user; nothing to delete
//            completion(.success(()))
//            return
//        }
//
//        let featuredRef = Database.database()
//            .reference()
//            .child("UserData")
//            .child(uid)
//            .child("UserRankos")
//            .child("UserFeaturedRankos")
//
//        // 1) Load all featured slots
//        featuredRef.getData { error, snapshot in
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//
//            guard let snap = snapshot, snap.exists() else {
//                // No featured entries at all
//                completion(.success(()))
//                return
//            }
//
//            // 2) Find the slot whose value == listID
//            var didRemove = false
//            for case let child as DataSnapshot in snap.children {
//                if let value = child.value as? String, value == listID {
//                    didRemove = true
//                    // 3) Remove that child entirely
//                    featuredRef.child(child.key).removeValue { removeError, _ in
//                        if let removeError = removeError {
//                            completion(.failure(removeError))
//                        } else {
//                            // Optionally reload your local state here:
//                            // self.tryLoadFeaturedRankos()
//                            completion(.success(()))
//                        }
//                    }
//                    break
//                }
//            }
//
//            // 4) If no match was found, still report success
//            if !didRemove {
//                completion(.success(()))
//            }
//        }
//    }
//    
//    // MARK: - Firebase Update
//    private func updateListInFirebase() {
//        guard let category = category else { return }
//        
//        let db = Database.database().reference()
//        
//        // ✅ Prepare the top-level fields to update
//        let listUpdates: [String: Any] = [
//            "RankoName": rankoName,
//            "RankoDescription": description,
//            "RankoPrivacy": isPrivate,
//            "RankoCategory": category.name
//        ]
//        
//        let listRef = db.child("RankoData").child(listID)
//        
//        // ✅ Update list fields
//        listRef.updateChildValues(listUpdates) { error, _ in
//            if let err = error {
//                print("❌ Failed to update list fields: \(err.localizedDescription)")
//            } else {
//                print("✅ List fields updated successfully")
//            }
//        }
//        
//        // ✅ Prepare all RankoItems
//        var itemsUpdate: [String: Any] = [:]
//        for row in groupedItems {
//            for item in row {
//                itemsUpdate[item.id] = [
//                    "ItemName":        item.record.ItemName,
//                    "ItemDescription": item.record.ItemDescription,
//                    "ItemImage":       item.record.ItemImage,
//                    "ItemRank":        item.rank,
//                    "ItemVotes":       item.votes
//                ]
//            }
//        }
//        
//        // ✅ Update RankoItems node with the new data
//        listRef.child("RankoItems").setValue(itemsUpdate) { error, _ in
//            if let err = error {
//                print("❌ Failed to update RankoItems: \(err.localizedDescription)")
//            } else {
//                print("✅ RankoItems updated successfully")
//            }
//        }
//    }
//    
//    // MARK: - Algolia Update
//    private func updateListInAlgolia(
//        listID: String,
//        newName: String,
//        newDescription: String,
//        newCategory: String,
//        isPrivate: Bool,
//        completion: @escaping (Bool) -> Void
//    ) {
//        let client = SearchClient(
//            appID: ApplicationID(rawValue: Secrets.algoliaAppID),
//            apiKey: APIKey(rawValue: Secrets.algoliaAPIKey)
//        )
//        let index = client.index(withName: "RankoLists")
//        
//        // ✅ Prepare partial updates
//        let updates: [(ObjectID, PartialUpdate)] = [
//            (ObjectID(rawValue: listID), .update(attribute: "RankoName", value: .string(newName))),
//            (ObjectID(rawValue: listID), .update(attribute: "RankoDescription", value: .string(newDescription))),
//            (ObjectID(rawValue: listID), .update(attribute: "RankoCategory", value: .string(newCategory))),
//            (ObjectID(rawValue: listID), .update(attribute: "RankoPrivacy", value: .bool(isPrivate)))
//        ]
//        
//        // ✅ Perform batch update in Algolia
//        index.partialUpdateObjects(updates: updates) { result in
//            switch result {
//            case .success(let response):
//                print("✅ Ranko list fields updated successfully:", response)
//                completion(true)
//            case .failure(let error):
//                print("❌ Failed to update Ranko list fields:", error.localizedDescription)
//                completion(false)
//            }
//        }
//    }
//    
//    // MARK: – Helpers & DropDelegate
//    struct FlowLayout2: Layout {
//        var spacing: CGFloat = 3
//        
//        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
//            let maxWidth = proposal.width ?? .infinity
//            var currentRowWidth: CGFloat = 0, currentRowHeight: CGFloat = 0
//            var totalWidth: CGFloat = 0, totalHeight: CGFloat = 0
//            
//            for subview in subviews {
//                let size = subview.sizeThatFits(.unspecified)
//                if currentRowWidth + size.width > maxWidth {
//                    totalWidth = max(totalWidth, currentRowWidth)
//                    totalHeight += currentRowHeight + spacing
//                    currentRowWidth = size.width + spacing
//                    currentRowHeight = size.height
//                } else {
//                    currentRowWidth += size.width + spacing
//                    currentRowHeight = max(currentRowHeight, size.height)
//                }
//            }
//            totalWidth = max(totalWidth, currentRowWidth)
//            totalHeight += currentRowHeight
//            return CGSize(width: totalWidth, height: totalHeight)
//        }
//        
//        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//            var x = bounds.minX
//            var y = bounds.minY
//            var currentRowHeight: CGFloat = 0
//            
//            for subview in subviews {
//                let size = subview.sizeThatFits(.unspecified)
//                if x + size.width > bounds.maxX {
//                    x = bounds.minX
//                    y += currentRowHeight + spacing
//                    currentRowHeight = 0
//                }
//                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
//                x += size.width + spacing
//                currentRowHeight = max(currentRowHeight, size.height)
//            }
//        }
//    }
//    
//    struct GroupRowView: View {
//        let rowIndex: Int
//        let items: [RankoItem]
//        
//        // NEW: bindings to the parent’s state
//        @Binding var itemRows: [[RankoItem]]
//        @Binding var unGroupedItems: [RankoItem]
//        @Binding var hoveredRow: Int?
//        @Binding var selectedDetailItem: RankoItem?
//        
//        var body: some View {
//            HStack(alignment: .top, spacing: 8) {
//                // badge
//                VStack(alignment: .center) {
//                    ZStack {
//                        Image(systemName: "\(rowIndex + 1).circle")
//                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                        
//                        Group {
//                            switch rowIndex {
//                            case 0:
//                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 1:
//                                Image(systemName: "2.circle.fill")
//                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 2:
//                                Image(systemName: "3.circle.fill")
//                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            default:
//                                Image(systemName: "\(rowIndex + 1).circle.fill")
//                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            }
//                        }
//                    }
//                    .padding(.top, 10)
//                    
//                    let enumeratedItems = Array(items.enumerated())
//                    
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: 4) {
//                            ForEach(enumeratedItems, id: \.1.id) { pair in
//                                let (_, item) = pair
//                                GroupSelectedItemRow(
//                                    item:       item
//                                )
//                                .onDrag  { NSItemProvider(object: item.id as NSString) }
//                                .onTapGesture { selectedDetailItem = item }
//                            }
//                        }
//                        .padding(8)
//                    }
//                }
//            }
//            .frame(minHeight: 60)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color(hex: 0xFFE7B5))
//            )
//            .overlay(highlightOverlay)
//            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
//            .onDrop(of: ["public.text"], delegate:
//                        RowDropDelegate(
//                            itemRows: $itemRows,
//                            unGrouped: $unGroupedItems,
//                            hoveredRow: $hoveredRow,
//                            targetRow: rowIndex
//                        )
//            )
//        }
//        
//        @ViewBuilder
//        private var highlightOverlay: some View {
//            if hoveredRow == rowIndex {
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
//                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
//            }
//        }
//    }
//    
//    struct GroupRowView2: View {
//        let rowIndex: Int
//        let items: [RankoItem]
//        
//        // NEW: bindings to the parent’s state
//        @Binding var itemRows: [[RankoItem]]
//        @Binding var unGroupedItems: [RankoItem]
//        @Binding var hoveredRow: Int?
//        @Binding var selectedDetailItem: RankoItem?
//        
//        var body: some View {
//            HStack(alignment: .top, spacing: 8) {
//                // badge
//                VStack(alignment: .center) {
//                    ZStack {
//                        Image(systemName: "\(rowIndex + 1).circle")
//                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                        
//                        Group {
//                            switch rowIndex {
//                            case 0:
//                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 1:
//                                Image(systemName: "2.circle.fill")
//                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 2:
//                                Image(systemName: "3.circle.fill")
//                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            default:
//                                Image(systemName: "\(rowIndex + 1).circle.fill")
//                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            }
//                        }
//                    }
//                    .padding(.top, 10)
//                    
//                    // items
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: 8) {
//                            ForEach(items) { item in
//                                GroupSelectedItemRow2(item: item)
//                                    .onDrag { NSItemProvider(object: item.id as NSString) }
//                                    .onTapGesture {
//                                        selectedDetailItem = item  // TRIGGER SHEET
//                                    }
//                            }
//                        }
//                        .padding(8)
//                    }
//                }
//            }
//            .frame(minHeight: 60)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color(hex: 0xFFE7B5))
//            )
//            .overlay(highlightOverlay)
//            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
//            .onDrop(of: ["public.text"], delegate:
//                        RowDropDelegate(
//                            itemRows: $itemRows,
//                            unGrouped: $unGroupedItems,
//                            hoveredRow: $hoveredRow,
//                            targetRow: rowIndex
//                        )
//            )
//        }
//        
//        @ViewBuilder
//        private var highlightOverlay: some View {
//            if hoveredRow == rowIndex {
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
//                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
//            }
//        }
//    }
//    
//    struct GroupRowView3: View {
//        let rowIndex: Int
//        let items: [RankoItem]
//        
//        // NEW: bindings to the parent’s state
//        @Binding var itemRows: [[RankoItem]]
//        @Binding var unGroupedItems: [RankoItem]
//        @Binding var hoveredRow: Int?
//        @Binding var selectedDetailItem: RankoItem?
//        
//        var body: some View {
//            HStack(alignment: .top, spacing: 8) {
//                // badge
//                VStack(alignment: .center) {
//                    ZStack {
//                        Image(systemName: "\(rowIndex + 1).circle")
//                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                        
//                        Group {
//                            switch rowIndex {
//                            case 0:
//                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 1:
//                                Image(systemName: "2.circle.fill")
//                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            case 2:
//                                Image(systemName: "3.circle.fill")
//                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            default:
//                                Image(systemName: "\(rowIndex + 1).circle.fill")
//                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
//                            }
//                        }
//                    }
//                    
//                    .padding(.top, 10)
//                    
//                    // items
//                    FlowLayout2(spacing: 6) {
//                        ForEach(items) { item in
//                            GroupSelectedItemRow3(item: item)
//                                .onDrag { NSItemProvider(object: item.id as NSString) }
//                                .onTapGesture {
//                                    selectedDetailItem = item  // TRIGGER SHEET
//                                }
//                        }
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding([.leading, .bottom, .trailing], 8)
//                }
//            }
//            .frame(minHeight: 60)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color(hex: 0xFFE7B5))
//            )
//            .overlay(highlightOverlay)
//            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
//            .onDrop(of: ["public.text"], delegate:
//                        RowDropDelegate(
//                            itemRows: $itemRows,
//                            unGrouped: $unGroupedItems,
//                            hoveredRow: $hoveredRow,
//                            targetRow: rowIndex
//                        )
//            )
//        }
//        
//        @ViewBuilder
//        private var highlightOverlay: some View {
//            if hoveredRow == rowIndex {
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
//                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
//            }
//        }
//    }
//    /// Handles drops into a specific row (or nil => into unGroupedItems)
//    struct RowDropDelegate: DropDelegate {
//        @Binding var itemRows: [[RankoItem]]
//        @Binding var unGrouped: [RankoItem]
//        @Binding var hoveredRow: Int?     // ← NEW
//        let targetRow: Int?
//        
//        // Called when the drag first enters this row’s bounds
//        func dropEntered(info: DropInfo) {
//            if let r = targetRow {
//                hoveredRow = r
//            }
//        }
//        // Called when the drag leaves this row’s bounds
//        func dropExited(info: DropInfo) {
//            if hoveredRow == targetRow {
//                hoveredRow = nil
//            }
//        }
//        
//        func performDrop(info: DropInfo) -> Bool {
//            hoveredRow = nil   // clear highlight immediately
//            
//            guard let provider = info.itemProviders(for: ["public.text"]).first
//            else { return false }
//            
//            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
//                DispatchQueue.main.async {
//                    guard
//                        let data = data as? Data,
//                        let id = String(data: data, encoding: .utf8)
//                    else { return }
//                    
//                    // 1) Remove from wherever it is
//                    var dragged: RankoItem?
//                    if let idx = unGrouped.firstIndex(where: { $0.id == id }) {
//                        dragged = unGrouped.remove(at: idx)
//                    } else {
//                        for idx in itemRows.indices {
//                            if let j = itemRows[idx].firstIndex(where: { $0.id == id }) {
//                                dragged = itemRows[idx].remove(at: j)
//                                break
//                            }
//                        }
//                    }
//                    
//                    // 2) Insert into the new target
//                    if let item = dragged {
//                        if let row = targetRow {
//                            itemRows[row].append(item)
//                        } else {
//                            unGrouped.append(item)
//                        }
//                    }
//                }
//            }
//            
//            return true
//        }
//    }
//}
//
//enum GroupListPersonalTab: String, CaseIterable {
//    case addItems = "Add Items"
//    case editDetails = "Edit Details"
//    case reRank = "Re-Rank"
//    case exit = "Exit"
//    case empty = "Empty"
//    
//    var symbolImage: String {
//        switch self {
//        case .addItems:
//            return "circle.grid.2x2"
//        case .editDetails:
//            return "square.text.square"
//        case .reRank:
//            return "rectangle.stack"
//        case .exit:
//            return "door.left.hand.closed"
//        case .empty:
//            return ""
//        }
//    }
//    
//    static var visibleCases: [GroupListPersonalTab] {
//        return [.addItems, .editDetails, .reRank, .exit]
//    }
//}

