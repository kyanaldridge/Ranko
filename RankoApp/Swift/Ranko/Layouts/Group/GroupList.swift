//
//  GroupList.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 28/5/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import AlgoliaSearchClient


// MARK: - GROUP LIST VIEW
struct GroupListView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList
    
    // MARK: - RANKO LIST DATA
    @State private var rankoID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    
    // Sheet states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var showEmbeddedStickyPoolSheet = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [AlgoliaRankoItem] = []
    @State private var groupedItems: [[AlgoliaRankoItem]]
    @State private var selectedDetailItem: AlgoliaRankoItem? = nil
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
    @State private var activeTab: GroupListTab = .addItems
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    
    enum TabType {
        case edit, add, reorder
    }
    // MARK: - INITIALISER
    
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: CategoryChip?,
        groupedItems items: [AlgoliaRankoItem]? = nil
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        if let items = items, !items.isEmpty {
            let maxGroup = items.map { $0.rank / 1000 }.max() ?? 0
            var buckets: [[AlgoliaRankoItem]] = Array(repeating: [], count: maxGroup)
            for item in items {
                let bucket = item.rank / 1000
                if bucket >= 1 && bucket <= maxGroup {
                    buckets[bucket - 1].append(item)
                }
            }
            _groupedItems = State(initialValue: buckets)
        } else {
            _groupedItems = State(initialValue: [])
        }
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
                        
                        Spacer()
                        
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
                                    .background(Color(hex: 0x6D400F))
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
                                    .background(Color(hex: 0x6D400F))
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
                                    .background(Color(hex: 0x6D400F))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
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
        .sheet(isPresented: $showAddItemsSheet, onDismiss: {
            // When FilterChipPickerView closes, trigger the embeddedStickyPoolView sheet
            showEmbeddedStickyPoolSheet = true
        }) {
            FilterChipPickerView(
                selectedRankoItems: $unGroupedItems
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
            EmptyView()
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
                    }   // dismiss DefaultListView without saving
                }
            )
        }
        .sheet(isPresented: $showEmbeddedStickyPoolSheet) {
            embeddedStickyPoolView
                .interactiveDismissDisabled(true) // prevents accidental swipe-down
                .presentationDetents([.height(110)]) // customize detents if needed
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled)
                .onChange(of: unGroupedItems.count) { _, newValue in
                    if newValue == 0 {
                        withAnimation {
                            showEmbeddedStickyPoolSheet = false  // Hide only the embedded view
                        }
                    }
                }
                .onAppear {
                    if unGroupedItems.isEmpty {
                        showEmbeddedStickyPoolSheet = false
                    }
                }
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(GroupListTab.visibleCases, id: \.rawValue) { tab in
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
        .sheet(item: $selectedDetailItem) { tappedItem in
            let rowIndex = groupedItems.firstIndex { row in
                row.contains { $0.id == tappedItem.id }
            } ?? 0

            GroupItemDetailView(
                items: groupedItems[rowIndex],
                rowIndex: rowIndex,
                numberOfRows: (groupedItems.count),
                initialItem: tappedItem,
                listID:  rankoID
            ) { updatedItem in
                if let idx = groupedItems[rowIndex]
                                .firstIndex(where: { $0.id == updatedItem.id }) {
                    groupedItems[rowIndex][idx] = updatedItem
                }
            }
        }
        .interactiveDismissDisabled(true)
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
    
    func saveRankedListToAlgolia() {
        guard let category = category else {
            print("❌ Cannot save: no category selected")
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
            objectID:         rankoID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "group",
            RankoPrivacy:     isPrivate,
            RankoCategory:    category.name,
            RankoUserID:      user_data.userID,
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
    }

    func saveRankedListToFirebase() {
        // 1) Make sure we actually have a category
        guard let category = category else {
            print("❌ Cannot save: no category selected")
            return
        }

        let db = Database.database().reference()
        
        
        var rankoItemsDict: [String: Any] = [:]

        for (r, row) in groupedItems.enumerated() {
            let rowCode = String(format: "%03d", r + 1)
            for (c, item) in row.enumerated() {
                let colCode = String(format: "%03d", c + 1)
                let rankString = rowCode + colCode
                let rankInt = Int(rankString) ?? (r * 1000 + c)

                // ✅ Generate a unique key per item
                let itemID = UUID().uuidString

                rankoItemsDict[itemID] = [
                    "ItemID":          itemID,
                    "ItemName":        item.itemName,
                    "ItemDescription": item.itemDescription,
                    "ItemImage":       item.itemImage,
                    "ItemRank":        rankInt,
                    "ItemVotes":       0
                ]
            }
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
            "RankoID":              rankoID,
            "RankoName":            rankoName,
            "RankoDescription":     description,
            "RankoType":            "group",
            "RankoPrivacy":         isPrivate,
            "RankoCategory":        category.name,
            "RankoUserID":          user_data.userID,
            "RankoItems":           rankoItemsDict,
            "RankoDateTime":        rankoDateTime
        ]

        // 5) Write the main list node
        db.child("RankoData")
          .child(rankoID)
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
          .child("RankoData")
          .child(rankoID)
          .setValue(category.name) { error, _ in
            if let err = error {
                print("❌ Error saving list to user: \(err.localizedDescription)")
            } else {
                print("✅ List saved successfully to user")
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

enum GroupListTab: String, CaseIterable {
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
    
    static var visibleCases: [GroupListTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}


struct GroupSelectedItemRow: View {
    let item: AlgoliaRankoItem

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: URL(string: item.itemImage)) { phase in
                switch phase {
                case .empty:
                    Color.gray.frame(width: 30, height: 30)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 30, height: 30)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: 0x6D400F))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
        )
    }
}

struct GroupSelectedItemRow2: View {
    let item: AlgoliaRankoItem

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: item.itemImage)) { phase in
                switch phase {
                case .empty:
                    Color.gray.frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 80, height: 80)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: 0x6D400F))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
        )
    }
}


struct GroupSelectedItemRow3: View {
    let item: AlgoliaRankoItem

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: URL(string: item.itemImage)) { phase in
                switch phase {
                case .empty:
                    Color.gray.frame(width: 30, height: 30)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 30, height: 30)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: 0x6D400F))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
        )
    }
}

// MARK: - GROUP LIST VIEW
struct GroupListView2: View {
    
    // MARK: - ENVIRONMENTS
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - APP STORAGE
    @StateObject private var user_data = UserInformation.shared
    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList
    
    // MARK: - RANKO LIST DATA
    @State private var rankoID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: CategoryChip?
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [AlgoliaRankoItem] = []
    @State private var groupedItems: [[AlgoliaRankoItem]]
    @State private var selectedDetailItem: AlgoliaRankoItem? = nil
    
    // MARK: - VIEW TRACKERS
    @State private var activeAction: GroupListAction? = nil
    @State private var showCancelAlert = false
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    
    // MARK: - INITIALISER
    
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: CategoryChip?,
        groupedItems items: [AlgoliaRankoItem]? = nil
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        if let items = items, !items.isEmpty {
            let maxGroup = items.map { $0.rank / 1000 }.max() ?? 0
            var buckets: [[AlgoliaRankoItem]] = Array(repeating: [], count: maxGroup)
            for item in items {
                let bucket = item.rank / 1000
                if bucket >= 1 && bucket <= maxGroup {
                    buckets[bucket - 1].append(item)
                }
            }
            _groupedItems = State(initialValue: buckets)
        } else {
            _groupedItems = State(initialValue: [])
        }
    }
    
    // MARK: - BODY VIEW
    
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
            
            // Removed standalone sticky pool overlay
            
            // MARK: – Bottom bar (with sticky pool inside)
            bottomBar
                .padding(.horizontal, 20)
        }
        
        // MARK: - SHEETS & ALERTS
        .sheet(item: $activeAction, content: sheetContent)
        .sheet(item: $selectedDetailItem) { tappedItem in
            let rowIndex = groupedItems.firstIndex { row in
                row.contains { $0.id == tappedItem.id }
            } ?? 0

            GroupItemDetailView(
                items: groupedItems[rowIndex],
                rowIndex: rowIndex,
                numberOfRows: (groupedItems.count),
                initialItem: tappedItem,
                listID:  rankoID
            ) { updatedItem in
                if let idx = groupedItems[rowIndex]
                                .firstIndex(where: { $0.id == updatedItem.id }) {
                    groupedItems[rowIndex][idx] = updatedItem
                }
            }
        }
        .interactiveDismissDisabled(true)
        .alert("Unsaved Changes", isPresented: $showCancelAlert) {
            Button("Yes", role: .destructive) { dismiss() }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text("Any changes made will not be saved. Do you want to cancel?")
        }
    }
    
    // MARK: - HEADER - DESCRIPTION - CATEGORY - PRIVACY -
    private var header: some View {
        HStack {
            Text(rankoName)
                .font(.title2)
                .fontWeight(.black)
            Spacer()
        }
        .padding(.leading, 15)
    }
    
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
        .padding(.leading, 15)
    }
    
    private var categoryPrivacyView: some View {
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
            groupViewModeButtons
            
        }
        .padding(.leading, 20)
    }
    
    // MARK: - BOTTOM BAR
    private var bottomBar: some View {
            VStack(spacing: 0) {
                
                HStack(spacing: 6) {
                    VStack {
                        if !unGroupedItems.isEmpty {
                            embeddedStickyPoolView
                        }
                        HStack(spacing: 0) {
                            ForEach(GroupListAction.allCases) { action in
                            if action == .publish {
                                pressAndHoldButton(
                                    action: action,
                                    symbolName: buttonSymbols[action.rawValue] ?? "",
                                    onPerform: {
                                        // Success haptic right before performing the action
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.success)
                                        saveRankedList()
                                        dismiss()
                                    },
                                    onTapToast: {
                                        // Error haptic when they only tap
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.error)
                                        showTemporaryToast("Hold down button to Publish")
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
                                        dismiss()
                                    },
                                    onTapToast: {
                                        // Error haptic when they only tap
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.error)
                                        showTemporaryToast("Hold down button to Delete")
                                    }
                                )
                            }
                            else if action == .leave {
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
                                        Text("Leave")
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
                                    case .addItems, .editDetails:
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
                    
            }
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 17)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 8)
            )
        }
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
    
    // MARK: - RESULTS SECTION
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
    
    // MARK: - PRESS & HOLD FUNCTION
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

    // MARK: - TOAST
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
    
    // MARK: - ITEM COUNTER
    private var totalItems: Int { groupedItems.flatMap{$0}.count }
    
    // MARK: - BOTTOM BAR BUTTON FUNCTIONS
    @ViewBuilder
    private func sheetContent(for action: GroupListAction) -> some View {
        switch action {
        case .publish:
            EmptyView() // never present a sheet for Publish
        case .addItems:
            FilterChipPickerView(selectedRankoItems: $unGroupedItems)
        case .editDetails:
            GroupListEditDetails(
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
        case .delete:
            EmptyView() // never present a sheet for Delete
        case .leave:
            EmptyView()
        }
    }
    
    // MARK: - GROUP LIST ACTION -
    enum GroupListAction: String, Identifiable, CaseIterable {
        var id: String { self.rawValue }
        case publish     = "Publish"
        case addItems    = "Add Items"
        case editDetails = "Edit Details"
        case delete      = "Delete"
        case leave       = "Leave"
    }

    var buttonSymbols: [String: String] {
        [
            "Publish":      "paperplane",
            "Add Items":    "plus",
            "Edit Details": "pencil",
            "Delete":       "trash",
            "Leave":        "door.left.hand.open"
        ]
    }
    
    func saveRankedList() {
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
        
        // 2) Build Grouped Items with Rank encoding
        var itemRecords: [RankoItemRecord] = []

        // 1) Build Group List Codable Struct
        let listRecord = RankoListRecord(
            objectID:         rankoID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "group",
            RankoPrivacy:     isPrivate,
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
            RankoItems: Dictionary(uniqueKeysWithValues: itemRecords.map { item in
                return (item.objectID, ["Rank": item.ItemRank, "Votes": item.ItemVotes])
            })

        )

        for (r, row) in groupedItems.enumerated() {
            let rowCode = String(format: "%03d", r + 1)
            for (c, item) in row.enumerated() {
                let colCode = String(format: "%03d", c + 1)
                let rankString = rowCode + colCode
                let rankInt = Int(rankString) ?? (r * 1000 + c)

                let itemRecord = RankoItemRecord(
                    objectID:        item.id,
                    ItemName:        item.itemName,
                    ItemDescription: item.itemDescription,
                    ItemImage:       item.itemImage,
                    ItemRank:        rankInt,
                    ItemVotes:       0,
                    ListID:          rankoID
                )
                itemRecords.append(itemRecord)
            }
        }

        // 3) Upload to Algolia
        let group = DispatchGroup()

        group.enter()
        listsIndex.saveObject(listRecord) { result in
            switch result {
            case .success:
                print("✅ Group list uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading group list: \(error)")
            }
            group.leave()
        }

        group.enter()
        itemsIndex.saveObjects(itemRecords) { result in
            switch result {
            case .success:
                print("✅ Group items uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading group items: \(error)")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            print("🎉 Group upload to Algolia completed")
        }
        
        let nullFields: [String: Any?] = [
            "RankoID": rankoID,
            "RankoLikes": nil,
            "RankoComments": nil,
            "RankoVoters": nil
        ]

        let finalData = nullFields.mapValues { $0 ?? NSNull() }
        
        let db = Database.database().reference()
        db.child("RankoLists").child(rankoID).setValue(finalData)
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

struct GroupListView_Previews: PreviewProvider {
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
        GroupListView(
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: CategoryChip(name: "Countries", icon: "globe.europe.africa.fill", category: "Geography", synonym: ""),
            groupedItems: sampleItems
        )
        .previewLayout(.sizeThatFits)
    }
}

















