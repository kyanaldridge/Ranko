//
//  GroupList_Spectate.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import Firebase
import AlgoliaSearchClient

// MARK: - GROUP LIST VIEW
struct GroupListSpectate: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList
    
    // MARK: - RANKO LIST DATA
    let listID: String
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    @State private var creatorID: String
    @State private var creatorName: String
    @State private var creatorImage: UIImage?
    
    // Sheet states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var showEmbeddedStickyPoolSheet = false
    @State private var spectateProfile = false
    @State var showEditDetailsSheet = false
    @State var showCloneSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var toastID = UUID()
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [AlgoliaRankoItem] = []
    @State private var groupedItems: [[AlgoliaRankoItem]]
    @State private var selectedDetailItem: AlgoliaRankoItem? = nil
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
    @State private var activeTab: GroupListSpectateTab = .clone
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    
    enum TabType {
        case edit, add, reorder
    }
    // MARK: - INITIALISER
    
    init(
        listID: String,
        rankoName: String = "Not Found",
        description: String = "",
        isPrivate: Bool = false,
        category: CategoryChip? = CategoryChip(
            name: "Unknown",
            icon: "questionmark.circle.fill",
            category: "Unknown",
            synonym: ""
        ),
        creatorID: String = "",
        creatorName: String = "searching...",
        creatorImage: UIImage? = nil,
        groupedItems: [AlgoliaRankoItem] = []
    ) {
        self.listID = listID
        _rankoName    = State(initialValue: rankoName)
        _description  = State(initialValue: description)
        _isPrivate    = State(initialValue: isPrivate)
        _category     = State(initialValue: category)
        self.creatorID = creatorID
        _creatorName = State(initialValue: creatorName)
        
        // Group flat array into rows by the thousands‐digit of rank
        let dict = Dictionary(grouping: groupedItems) { $0.rank / 1000 }
        let sortedKeys = dict.keys.sorted()
        let rows = sortedKeys.compactMap { dict[$0] }
        _groupedItems = State(initialValue: rows)
    }
    
    // MARK: - BODY VIEW
    
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
                        
                        HStack(spacing: 7) {
                            Group {
                                if let img = creatorImage {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 18, height: 18)
                                        Image(uiImage: img)
                                            .resizable()
                                    }
                                    .clipShape(Circle())
                                    
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
                        
                        HStack(spacing: 3) {
                            // Default List Button
                            Button(action: { groupViewMode = .defaultList }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "rectangle.compress.vertical")
                                        .font(.system(size: 14, weight: .medium, design: .default))
                                        .foregroundColor(groupViewMode == .defaultList ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
                                        .padding(.bottom, 2)
                                    if groupViewMode == .defaultList {
                                        // Blue glowing underline when selected
                                        Rectangle()
                                            .fill(Color(hex: 0x6D400F))
                                            .frame(width: 30, height: 2)
                                            .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 4, x: 0, y: 0)
                                    } else {
                                        Color.clear.frame(width: 30, height: 2)
                                    }
                                }
                            }
                            
                            // Large Grid Button
                            Button(action: { groupViewMode = .largeGrid }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.caption)
                                        .foregroundColor(groupViewMode == .largeGrid ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
                                        .padding(.bottom, 2)
                                    if groupViewMode == .largeGrid {
                                        Rectangle()
                                            .fill(Color(hex: 0x6D400F))
                                            .frame(width: 30, height: 2)
                                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                                    } else {
                                        Color.clear.frame(width: 30, height: 2)
                                    }
                                }
                            }
                            
                            // Compact List Button
                            Button(action: { groupViewMode = .biggerList }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "inset.filled.topleft.topright.bottomleft.bottomright.rectangle")
                                        .font(.caption)
                                        .foregroundColor(groupViewMode == .biggerList ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E))
                                        .padding(.bottom, 2)
                                    if groupViewMode == .biggerList {
                                        Rectangle()
                                            .fill(Color(hex: 0x6D400F))
                                            .frame(width: 30, height: 2)
                                            .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 4, x: 0, y: 0)
                                    } else {
                                        Color.clear.frame(width: 30, height: 2)
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 8)
                        
                    }
                    .padding(.leading, 20)
                    
                    Divider()
                    
                    switch groupViewMode {
                    case .defaultList:
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(groupedItems.indices, id: \.self) { i in
                                    GroupRowView(
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
                                        selectedDetailItem: $selectedDetailItem
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.top, 10)
                            // leave space so content can scroll above the sticky pool + bottomBar
                            .padding(.bottom, 180)
                        }
                        
                    case .largeGrid:
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(groupedItems.indices, id: \.self) { i in
                                    GroupRowView2(
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
                                        selectedDetailItem: $selectedDetailItem
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.top, 10)
                            // leave space so content can scroll above the sticky pool + bottomBar
                            .padding(.bottom, 180)
                        }
                        
                    case .biggerList:
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                
                                ForEach(groupedItems.indices, id: \.self) { i in
                                    GroupRowView3(
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
                                        selectedDetailItem: $selectedDetailItem
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.top, 10)
                            // leave space so content can scroll above the sticky pool + bottomBar
                            .padding(.bottom, 180)
                        }
                    }
                    
                    
                    Spacer(minLength: 60) // leave room for bottom bar
                }
                .padding(.top, 20)
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
        .animation(.easeInOut(duration: 0.25), value: toastID)
        .onAppear {
            fetchCreatorName()
            loadListFromFirebase()
        }
        .fullScreenCover(isPresented: $showCloneSheet) {
            let itemsToCopy = groupedItems.flatMap { $0 } + unGroupedItems
                GroupListView(
                    rankoName:   rankoName,
                    description: description,
                    isPrivate:   isPrivate,
                    category:    category,
                    groupedItems: itemsToCopy
                )
        }
        .onChange(of: showCloneSheet) { _, isPresented in
            // when it flips from true → false…
            if !isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(GroupListSpectateTab.visibleCases, id: \.rawValue) { tab in
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
        .sheet(item: $selectedDetailItem) { tappedItem in
            let rowIndex = groupedItems.firstIndex { row in
                row.contains { $0.id == tappedItem.id }
            } ?? 0
            
            GroupItemDetailView(
                items: groupedItems[rowIndex],
                rowIndex: rowIndex,
                numberOfRows: (groupedItems.count),
                initialItem: tappedItem,
                listID:  listID
            ) { updatedItem in
                if let idx = groupedItems[rowIndex]
                    .firstIndex(where: { $0.id == updatedItem.id }) {
                    groupedItems[rowIndex][idx] = updatedItem
                }
            }
        }
        .interactiveDismissDisabled(true)
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
    
    // MARK: - EMBEDDED STICKY POOL
    private var embeddedStickyPoolView: some View {
        VStack(spacing: 6) {
            Text("Drag the below items to groups")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top, 3)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(unGroupedItems) { item in
                        GroupSelectedItemRow(item: item)
                            .onDrag { NSItemProvider(object: item.id as NSString) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .onDrop(
            of: ["public.text"],
            delegate: RowDropDelegate(
                itemRows:   $groupedItems,
                unGrouped:  $unGroupedItems,
                hoveredRow: $hoveredRow,
                targetRow:  nil
            )
        )
    }
    
    // MARK: — Fetchers
    private func loadProfileImage() {
        let ref = Database.database().reference()
            .child("UserData")
            .child(creatorID)
            .child("UserProfilePicture")
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
                            ItemCategory: "",
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
                    
                    DispatchQueue.main.async {
                        // If you also want them in the “ungrouped pool”:
                        self.unGroupedItems = loaded
                        
                        // Group by the thousands-digit of `rank`:
                        let groupedDict = Dictionary(grouping: loaded) { $0.rank / 1000 }
                        self.groupedItems = groupedDict
                            .sorted(by: { $0.key < $1.key })
                            .map { $0.value }
                    }
                }
            }
        },
                                   withCancel: { error in
            print("❌ Firebase load error:", error.localizedDescription)
        })
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
        for row in groupedItems {
            for item in row {
                itemsUpdate[item.id] = [
                    "ItemName":        item.record.ItemName,
                    "ItemDescription": item.record.ItemDescription,
                    "ItemImage":       item.record.ItemImage,
                    "ItemRank":        item.rank,
                    "ItemVotes":       item.votes
                ]
            }
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
    
    // MARK: – Helpers & DropDelegate
    struct FlowLayout2: Layout {
        var spacing: CGFloat = 3
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var currentRowWidth: CGFloat = 0, currentRowHeight: CGFloat = 0
            var totalWidth: CGFloat = 0, totalHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentRowWidth + size.width > maxWidth {
                    totalWidth = max(totalWidth, currentRowWidth)
                    totalHeight += currentRowHeight + spacing
                    currentRowWidth = size.width + spacing
                    currentRowHeight = size.height
                } else {
                    currentRowWidth += size.width + spacing
                    currentRowHeight = max(currentRowHeight, size.height)
                }
            }
            totalWidth = max(totalWidth, currentRowWidth)
            totalHeight += currentRowHeight
            return CGSize(width: totalWidth, height: totalHeight)
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var currentRowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > bounds.maxX {
                    x = bounds.minX
                    y += currentRowHeight + spacing
                    currentRowHeight = 0
                }
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
    }
    
    struct GroupRowView: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    let enumeratedItems = Array(items.enumerated())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(enumeratedItems, id: \.1.id) { pair in
                                let (_, item) = pair
                                GroupSelectedItemRow(
                                    item:       item
                                )
                                .onDrag  { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView2: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    // items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                GroupSelectedItemRow2(item: item)
                                    .onDrag { NSItemProvider(object: item.id as NSString) }
                                    .onTapGesture {
                                        selectedDetailItem = item  // TRIGGER SHEET
                                    }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView3: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    
                    .padding(.top, 10)
                    
                    // items
                    FlowLayout2(spacing: 6) {
                        ForEach(items) { item in
                            GroupSelectedItemRow3(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture {
                                    selectedDetailItem = item  // TRIGGER SHEET
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.leading, .bottom, .trailing], 8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    /// Handles drops into a specific row (or nil => into unGroupedItems)
    struct RowDropDelegate: DropDelegate {
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGrouped: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?     // ← NEW
        let targetRow: Int?
        
        // Called when the drag first enters this row’s bounds
        func dropEntered(info: DropInfo) {
            if let r = targetRow {
                hoveredRow = r
            }
        }
        // Called when the drag leaves this row’s bounds
        func dropExited(info: DropInfo) {
            if hoveredRow == targetRow {
                hoveredRow = nil
            }
        }
        
        func performDrop(info: DropInfo) -> Bool {
            hoveredRow = nil   // clear highlight immediately
            
            guard let provider = info.itemProviders(for: ["public.text"]).first
            else { return false }
            
            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
                DispatchQueue.main.async {
                    guard
                        let data = data as? Data,
                        let id = String(data: data, encoding: .utf8)
                    else { return }
                    
                    // 1) Remove from wherever it is
                    var dragged: AlgoliaRankoItem?
                    if let idx = unGrouped.firstIndex(where: { $0.id == id }) {
                        dragged = unGrouped.remove(at: idx)
                    } else {
                        for idx in itemRows.indices {
                            if let j = itemRows[idx].firstIndex(where: { $0.id == id }) {
                                dragged = itemRows[idx].remove(at: j)
                                break
                            }
                        }
                    }
                    
                    // 2) Insert into the new target
                    if let item = dragged {
                        if let row = targetRow {
                            itemRows[row].append(item)
                        } else {
                            unGrouped.append(item)
                        }
                    }
                }
            }
            
            return true
        }
    }
}

enum GroupListSpectateTab: String, CaseIterable {
    case save = "Save Ranko"
    case clone = "Clone"
    case exit = "Exit"
    case empty = "Empty"
    
    var symbolImage: String {
        switch self {
        case .save:
            return "bookmark.fill"
        case .clone:
            return "square.fill.on.square.fill"
        case .exit:
            return "door.left.hand.closed"
        case .empty:
            return ""
        }
    }
    
    static var visibleCases: [GroupListSpectateTab] {
        return [.save, .clone, .exit]
    }
}


struct GroupListSpectate3: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var user_data = UserInformation.shared

    /// The existing list’s ID in your RTDB
    let listID: String

    // MARK: – Editable state
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    @State private var rankoType: String = ""
    @State private var creatorID: String
    @State private var creatorName: String
    @State private var profileImage: UIImage?
    
    // State to track which sheet to present
    @State private var unGroupedItems: [AlgoliaRankoItem] = []
    @State private var groupedItems: [[AlgoliaRankoItem]]
    @State private var selectedDetailItem: AlgoliaRankoItem? = nil
    @State private var spectateProfile: Bool = false

    // MARK: – UI state
    @State private var activeAction: GroupListAction? = nil
    @State private var showCancelAlert = false

    @State private var changeMade: Bool = false
    @State private var hoveredRow: Int? = nil
    @State private var didLoad: Bool = false
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: – Toast
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    
    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList

    init(
        listID: String,
        rankoName: String = "Not Found",
        description: String = "",
        isPrivate: Bool = false,
        category: CategoryChip? = CategoryChip(
            name: "Unknown",
            icon: "questionmark.circle.fill",
            category: "Unknown",
            synonym: ""
        ),
        creatorID: String = "",
        creatorName: String = "searching...",
        creatorImage: UIImage? = nil,
        groupedItems: [AlgoliaRankoItem] = []
    ) {
        self.listID = listID
        _rankoName    = State(initialValue: rankoName)
        _description  = State(initialValue: description)
        _isPrivate    = State(initialValue: isPrivate)
        _category     = State(initialValue: category)
        self.creatorID = creatorID
        _creatorName = State(initialValue: creatorName)
        
        // Group flat array into rows by the thousands‐digit of rank
        let dict = Dictionary(grouping: groupedItems) { $0.rank / 1000 }
        let sortedKeys = dict.keys.sorted()
        let rows = sortedKeys.compactMap { dict[$0] }
        _groupedItems = State(initialValue: rows)
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
                    resultsSection
                    Spacer(minLength: 60) // leave room for bottom bar
                }
                .padding(.top, 20)
            }
            
            
            
            // MARK: – Sticky pool of ungrouped items (if any)
            if !unGroupedItems.isEmpty {
                stickyPoolView
            }
            
            // MARK: – Bottom bar
            bottomBar
        }
        .onAppear {
            guard !didLoad else { return }
            loadList(listID: listID)
            didLoad = true
        }
        .sheet(isPresented: $spectateProfile) {
            ProfileSpectateView(userID: creatorID)
        }
        .sheet(item: $activeAction, content: sheetContent)
        .sheet(item: $selectedDetailItem) { tappedItem in
            // figure out which row this item is in
            let rowIndex = groupedItems.firstIndex { row in
                row.contains { $0.id == tappedItem.id }
            } ?? 0

            GroupItemDetailViewSpectate(
                items: groupedItems[rowIndex],
                rowIndex: rowIndex,
                numberOfRows: (groupedItems.count),
                initialItem: tappedItem,
                listID:  listID
            ) { updatedItem in
                // write the updated item back into the same row
                if let idx = groupedItems[rowIndex]
                                .firstIndex(where: { $0.id == updatedItem.id }) {
                    groupedItems[rowIndex][idx] = updatedItem
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showCancelAlert) {
            Button("Yes", role: .destructive) { dismiss() }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text("Any changes made will not be saved. Do you want to cancel?")
        }
    }

      // MARK: – Sticky pool extracted
    private var stickyPoolView: some View {
        VStack(spacing: 6) {
            Text("Drag the below items to groups")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(unGroupedItems) { item in
                        GroupSelectedItemRow(item: item)
                            .onDrag { NSItemProvider(object: item.id as NSString) }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .onDrop(
            of: ["public.text"],
            delegate: RowDropDelegate(
                itemRows:   $groupedItems,
                unGrouped:  $unGroupedItems,
                hoveredRow: $hoveredRow,
                targetRow:  nil
            )
        )
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        switch groupViewMode {
        case .defaultList:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(groupedItems.indices, id: \.self) { i in
                        GroupRowView(
                            rowIndex:       i,
                            items:          groupedItems[i],
                            itemRows:       $groupedItems,
                            unGroupedItems: $unGroupedItems,
                            hoveredRow:     $hoveredRow,
                            selectedDetailItem: $selectedDetailItem
                        )
                        .padding(.horizontal, 8)
                    }
                    
                    // “New row” placeholder
                    Button {
                        groupedItems.append([])
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                // leave space so content can scroll above the sticky pool + bottomBar
                .padding(.bottom, 180)
            }
            
        case .largeGrid:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(groupedItems.indices, id: \.self) { i in
                        GroupRowView2(
                            rowIndex:       i,
                            items:          groupedItems[i],
                            itemRows:       $groupedItems,
                            unGroupedItems: $unGroupedItems,
                            hoveredRow:     $hoveredRow,
                            selectedDetailItem: $selectedDetailItem
                        )
                        .padding(.horizontal, 8)
                    }
                    
                    // “New row” placeholder
                    Button {
                        groupedItems.append([])
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                // leave space so content can scroll above the sticky pool + bottomBar
                .padding(.bottom, 180)
            }
            
        case .biggerList:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    
                    ForEach(groupedItems.indices, id: \.self) { i in
                        GroupRowView3(
                            rowIndex:       i,
                            items:          groupedItems[i],
                            itemRows:       $groupedItems,
                            unGroupedItems: $unGroupedItems,
                            hoveredRow:     $hoveredRow,
                            selectedDetailItem: $selectedDetailItem
                        )
                        .padding(.horizontal, 8)
                    }
                    
                    // “New row” placeholder
                    Button {
                        groupedItems.append([])
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                // leave space so content can scroll above the sticky pool + bottomBar
                .padding(.bottom, 180)
            }
        }
        
    }
    // MARK: – Load existing list
    private func loadList(listID: String) {
        
    }

    // MARK: – Update existing list
    private func updateRankedList() {
        print("UpdateRankedList activated")
    }
    
    private func deleteRankedList() {
        
        // sanitize user key
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
//        dismiss()
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
        .padding(.leading, 20)
    }

    // MARK: — Description View
    private var descriptionView: some View {
        HStack {
            if description.isEmpty {
                Text("No description yet…")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            } else {
                Text(description)
                    .lineLimit(3)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.leading, 20)
    }

    // MARK: — Category & Privacy View
    private var categoryPrivacyView: some View {
        VStack {
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: isPrivate ? "lock.fill" : "globe")
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.leading, 7)
                        .font(.caption)
                    Text(isPrivate ? "Private" : "Public")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .padding(.trailing, 7)
                        .font(.caption)
                }
                .background(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(isPrivate ? .orange : .blue)
                HStack {
                    Image(systemName: category!.icon)
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.leading, 7)
                        .font(.caption)
                    Text(category!.name)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .padding(.trailing, 7)
                        .font(.caption)
                }
                .background(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(categoryChipIconColors[category!.name])
                Spacer()
                
                
            }
            .padding(.leading, 20)
            
            HStack {
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
                groupViewModeButtons
            }
            .padding(.leading, 20)
            .padding([.top, .trailing], 8)
            
            
            
        }
    }

    // MARK: — Bottom Bar Overlay
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(GroupListAction.allCases) { action in
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
                        }
                        else {
                            // Other actions (addItems, reRank, editDetails)
                            Button {
                                switch action {
                                case .copy, .share:
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
//                    }
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
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: — Press-and-Hold Button with Separate Forward/Reverse Rings
    @ViewBuilder
    private func pressAndHoldButton(
        action: GroupListAction,
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
    // MARK: – Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for action: GroupListAction) -> some View {
        switch action {
        case .copy:
            let itemsToCopy = groupedItems.flatMap { $0 } + unGroupedItems
                GroupListView(
                    rankoName:   rankoName,
                    description: description,
                    isPrivate:   isPrivate,
                    category:    category,
                    groupedItems: itemsToCopy
                )
        case .share:
            EmptyView()
        case .exit:
            EmptyView()
        }
    }
    
    // MARK: – Helpers
    
    enum GroupListAction: String, Identifiable, CaseIterable {
        var id: String { self.rawValue }
        case copy        = "Copy"
        case share       = "Share"
        case exit        = "Exit"
    }

    var buttonSymbols: [String: String] {
        [
            "Copy":       "plus.square.on.square.fill",
            "Share":      "paperplane",
            "Exit":       "door.left.hand.open"
        ]
    }
    private var groupViewModeButtons: some View {
        HStack(spacing: 3) {
            // Default List Button
            Button(action: { groupViewMode = .defaultList }) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.caption)
                        .foregroundColor(groupViewMode == .defaultList ? .blue : .gray)
                        .padding(.bottom, 2)
                    if groupViewMode == .defaultList {
                        // Blue glowing underline when selected
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }
            
            // Large Grid Button
            Button(action: { groupViewMode = .largeGrid }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption)
                        .foregroundColor(groupViewMode == .largeGrid ? .blue : .gray)
                        .padding(.bottom, 2)
                    if groupViewMode == .largeGrid {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }
            
            // Compact List Button
            Button(action: { groupViewMode = .biggerList }) {
                VStack(spacing: 4) {
                    Image(systemName: "inset.filled.topleft.topright.bottomleft.bottomright.rectangle")
                        .font(.caption)
                        .foregroundColor(groupViewMode == .biggerList ? .blue : .gray)
                        .padding(.bottom, 2)
                    if groupViewMode == .biggerList {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }
        }
        .padding(.trailing, 8)
    }
    // MARK: – Helpers & DropDelegate
    struct FlowLayout2: Layout {
        var spacing: CGFloat = 3

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var currentRowWidth: CGFloat = 0, currentRowHeight: CGFloat = 0
            var totalWidth: CGFloat = 0, totalHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentRowWidth + size.width > maxWidth {
                    totalWidth = max(totalWidth, currentRowWidth)
                    totalHeight += currentRowHeight + spacing
                    currentRowWidth = size.width + spacing
                    currentRowHeight = size.height
                } else {
                    currentRowWidth += size.width + spacing
                    currentRowHeight = max(currentRowHeight, size.height)
                }
            }
            totalWidth = max(totalWidth, currentRowWidth)
            totalHeight += currentRowHeight
            return CGSize(width: totalWidth, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var currentRowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > bounds.maxX {
                    x = bounds.minX
                    y += currentRowHeight + spacing
                    currentRowHeight = 0
                }
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
    }
    
    struct GroupRowView: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    Group {
                        switch rowIndex {
                        case 0:
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
                                .font(.body)
                                .padding(3)
                        case 1:
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
                                .font(.body)
                                .padding(3)
                        case 2:
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
                                .font(.body)
                                .padding(3)
                        default:
                            Text("\(rowIndex + 1)")
                                .font(.caption)
                                .padding(5)
                                .fontWeight(.heavy)
                        }
                    }
                    .font(.title2)
                    .padding(.top, 10)
                    
                    let enumeratedItems = Array(items.enumerated())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(enumeratedItems, id: \.1.id) { pair in
                                let (_, item) = pair
                                GroupSelectedItemRow(
                                    item:       item
                                )
                                .onDrag  { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 4)
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
                    .shadow(color: Color.blue.opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView2: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    Group {
                        switch rowIndex {
                        case 0: Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.body).padding(3)
                        case 1: Image(systemName: "2.circle.fill").foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.body).padding(3)
                        case 2: Image(systemName: "3.circle.fill").foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.body).padding(3)
                        default: Text("\(rowIndex + 1)").font(.caption).padding(5).fontWeight(.heavy)
                        }
                    }
                    .font(.title2)
                    .padding(.top, 10)
                    
                    // items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                GroupSelectedItemRow2(item: item)
                                    .onDrag { NSItemProvider(object: item.id as NSString) }
                                    .onTapGesture {
                                        selectedDetailItem = item  // TRIGGER SHEET
                                    }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 4)
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.blue, lineWidth: 2)
                  .shadow(color: Color.blue.opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView3: View {
        let rowIndex: Int
        let items: [AlgoliaRankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGroupedItems: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: AlgoliaRankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    Group {
                        switch rowIndex {
                        case 0: Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.body).padding(3)
                        case 1: Image(systemName: "2.circle.fill").foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.body).padding(3)
                        case 2: Image(systemName: "3.circle.fill").foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.body).padding(3)
                        default: Text("\(rowIndex + 1)").font(.caption).padding(5).fontWeight(.heavy)
                        }
                    }
                    .font(.title2)
                    .padding(.top, 10)
                    
                    // items
                    FlowLayout2(spacing: 6) {
                        ForEach(items) { item in
                            GroupSelectedItemRow3(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture {
                                    selectedDetailItem = item  // TRIGGER SHEET
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.leading, .bottom, .trailing], 8)
                }
            }
            .frame(minHeight: 60)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 4)
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.blue, lineWidth: 2)
                  .shadow(color: Color.blue.opacity(0.6), radius: 8)
            }
        }
    }
    /// Handles drops into a specific row (or nil => into unGroupedItems)
    struct RowDropDelegate: DropDelegate {
        @Binding var itemRows: [[AlgoliaRankoItem]]
        @Binding var unGrouped: [AlgoliaRankoItem]
        @Binding var hoveredRow: Int?     // ← NEW
        let targetRow: Int?
        
        // Called when the drag first enters this row’s bounds
        func dropEntered(info: DropInfo) {
            if let r = targetRow {
                hoveredRow = r
            }
        }
        // Called when the drag leaves this row’s bounds
        func dropExited(info: DropInfo) {
            if hoveredRow == targetRow {
                hoveredRow = nil
            }
        }
            
        func performDrop(info: DropInfo) -> Bool {
            hoveredRow = nil   // clear highlight immediately
            
            guard let provider = info.itemProviders(for: ["public.text"]).first
            else { return false }
            
            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
                DispatchQueue.main.async {
                    guard
                        let data = data as? Data,
                        let id = String(data: data, encoding: .utf8)
                    else { return }
                    
                    // 1) Remove from wherever it is
                    var dragged: AlgoliaRankoItem?
                    if let idx = unGrouped.firstIndex(where: { $0.id == id }) {
                        dragged = unGrouped.remove(at: idx)
                    } else {
                        for idx in itemRows.indices {
                            if let j = itemRows[idx].firstIndex(where: { $0.id == id }) {
                                dragged = itemRows[idx].remove(at: j)
                                break
                            }
                        }
                    }
                    
                    // 2) Insert into the new target
                    if let item = dragged {
                        if let row = targetRow {
                            itemRows[row].append(item)
                        } else {
                            unGrouped.append(item)
                        }
                    }
                }
            }
            
            return true
        }
    }
}


struct GroupListSpectateView_Previews: PreviewProvider {
    // Create 10 sample AlgoliaRankoItem instances representing top destinations
    static var sampleItems: [AlgoliaRankoItem] = [
        AlgoliaRankoItem(
            id: UUID().uuidString,
            rank: 1001,
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
            rank: 1002,
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
            rank: 2001,
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
            rank: 3001,
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
            rank: 3002,
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
            rank: 3003,
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
            rank: 3004,
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
            rank: 4001,
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
            rank: 5001,
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
            rank: 5002,
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
        GroupListSpectate(
            listID: UUID().uuidString,
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: CategoryChip(name: "Countries", icon: "globe.europe.africa.fill", category: "Geography", synonym: ""),
            groupedItems: sampleItems
        )
        .previewLayout(.sizeThatFits)
    }
}


