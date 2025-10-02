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
    @State private var category: SampleCategoryChip?
    
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
    @State private var unGroupedItems: [RankoItem] = []
    @State private var groupedItems: [[RankoItem]]
    @State private var selectedDetailItem: RankoItem? = nil
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
    @State private var activeTab: GroupListTab = .addItems
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    // MARK: - INITIALISER
    
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: SampleCategoryChip?,
        groupedItems items: [RankoItem]? = nil
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        if let items = items, !items.isEmpty {
            let maxGroup = items.map { $0.rank / 1000 }.max() ?? 0
            var buckets: [[RankoItem]] = Array(repeating: [], count: maxGroup)
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
    
    // MARK: - Tiers
    enum Tier: Int, CaseIterable, Identifiable {
        case s, a, b, c, d, e, f
        var id: Int { rawValue }

        var letter: String {
            switch self {
            case .s: return "S"
            case .a: return "A"
            case .b: return "B"
            case .c: return "C"
            case .d: return "D"
            case .e: return "E"
            case .f: return "F"
            }
        }

        var label: String {
            switch self {
            case .s: return "Legendary"
            case .a: return "Excellent"
            case .b: return "Solid"
            case .c: return "Average"
            case .d: return "Weak"
            case .e: return "Poor"
            case .f: return "Useless"
            }
        }

        var color: Color {
            // tuned to match the sample look
            switch self {
            case .s: return Color(hex: 0xC44536) // red
            case .a: return Color(hex: 0xBF7B2F) // orange
            case .b: return Color(hex: 0xBFA254) // gold
            case .c: return Color(hex: 0x4DA35A) // green
            case .d: return Color(hex: 0x3F7F74) // teal
            case .e: return Color(hex: 0x3F63A7) // blue
            case .f: return Color(hex: 0x6C46B3) // purple
            }
        }
    }

    // Safely map a row index to a tier (clamps to F if there are more than 7 rows)
    private func tierForRow(_ i: Int) -> Tier {
        if i >= 0 && i < Tier.allCases.count { return Tier.allCases[i] }
        return .f
    }

    // The colored square tier box (letter + tiny label)
    struct TierBox: View {
        let tier: Tier
        var body: some View {
            VStack(spacing: 2) {
                Text(tier.letter)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .padding(.horizontal, 16)

                Text(tier.label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 6)
                    .padding(.horizontal, 6)
            }
            .frame(minWidth: 70, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tier.color)
            )
            .padding(8)
            .contextMenu {
                Button(role: .destructive) {
                    
                } label: {
                    Label("Delete Tier", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - BODY VIEW
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 7) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(rankoName)
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundStyle(Color(hex: 0x514343))
                                .kerning(-0.4)
                            Spacer()
                        }
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        
                        HStack {
                            Text(description.isEmpty ? "No description yet…" : description)
                                .lineLimit(3)
                                .font(.custom("Nunito-Black", size: 13))
                                .foregroundStyle(Color(hex: 0x514343))
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
                    .contextMenu {
                        Button {
                            
                        } label: {
                            Label("Edit Details", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button {
                            
                        } label: {
                            Label("Re-Rank Items", systemImage: "chevron.up.chevron.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            
                        } label: {
                            Label("Delete Ranko", systemImage: "trash")
                        }
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
                    
                    Divider()
                    
                    switch groupViewMode {
                    case .defaultList:
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(groupedItems.indices, id: \.self) { i in
                                    GroupRowView(
                                        rowIndex: i,
                                        tier: tierForRow(i),
                                        items: groupedItems[i],
                                        itemRows: $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow: $hoveredRow,
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
                                        rowIndex: i,
                                        tier: tierForRow(i),
                                        items: groupedItems[i],
                                        itemRows: $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow: $hoveredRow,
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
                                        rowIndex: i,
                                        tier: tierForRow(i),
                                        items: groupedItems[i],
                                        itemRows: $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow: $hoveredRow,
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

        // 1) Build Group List Codable Struct
        let listRecord = RankoListAlgolia(
            objectID:         rankoID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoStatus:      "active",
            RankoCategory:    category.name,
            RankoUserID:      user_data.userID,
            RankoCreated:    rankoDateTime,
            RankoUpdated:    rankoDateTime,
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
            "RankoStatus":          "active",
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
          .child("UserRankos")
          .child("UserActiveRankos")
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
        let tier: Tier
        let items: [RankoItem]
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 4) {
                // 🔁 tier box replaces number badge
                TierBox(tier: tier)

                let enumeratedItems = Array(items.enumerated())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(enumeratedItems, id: \.1.id) { pair in
                            let (_, item) = pair
                            GroupSelectedItemRow(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFFFFF))
                    .shadow(radius: 2)
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(itemRows: $itemRows, unGrouped: $unGroupedItems, hoveredRow: $hoveredRow, targetRow: rowIndex)
            )
        }

        @ViewBuilder private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView2: View {
        let rowIndex: Int
        let tier: Tier
        let items: [RankoItem]
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .center, spacing: 4) {
                // 🔁 tier box
                TierBox(tier: tier)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            GroupSelectedItemRow2(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFFFFF))
                    .shadow(radius: 2)
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(itemRows: $itemRows, unGrouped: $unGroupedItems, hoveredRow: $hoveredRow, targetRow: rowIndex)
            )
        }

        @ViewBuilder private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView3: View {
        let rowIndex: Int
        let tier: Tier
        let items: [RankoItem]
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 4) {
                // 🔁 tier box
                TierBox(tier: tier)

                FlowLayout2(spacing: 6) {
                    ForEach(items) { item in
                        GroupSelectedItemRow3(item: item)
                            .onDrag { NSItemProvider(object: item.id as NSString) }
                            .onTapGesture { selectedDetailItem = item }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.leading, .bottom, .trailing], 8)
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFFFFF))
                    .shadow(radius: 2)
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(itemRows: $itemRows, unGrouped: $unGroupedItems, hoveredRow: $hoveredRow, targetRow: rowIndex)
            )
        }

        @ViewBuilder private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    /// Handles drops into a specific row (or nil => into unGroupedItems)
    struct RowDropDelegate: DropDelegate {
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGrouped: [RankoItem]
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
                    var dragged: RankoItem?
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
    let item: RankoItem

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: URL(string: item.itemImage)) { phase in
                switch phase {
                case .empty:
                    Color.gray.frame(width: 40, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 40, height: 40)
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
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(radius: 2)
        )
    }
}

struct GroupSelectedItemRow2: View {
    let item: RankoItem

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
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(radius: 2)
        )
    }
}


struct GroupSelectedItemRow3: View {
    let item: RankoItem

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: URL(string: item.itemImage)) { phase in
                switch phase {
                case .empty:
                    Color.gray.frame(width: 40, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 40, height: 40)
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
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(radius: 2)
        )
    }
}

















