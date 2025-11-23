//
//  TierList.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 28/5/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import AlgoliaSearchClient

private extension CGFloat {
    func clamped(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let lower = Swift.min(a, b)
        let upper = Swift.max(a, b)
        return Swift.min(Swift.max(self, lower), upper)
    }
}

private extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
    var length: CGFloat { sqrt(x*x + y*y) }
    var normalized: CGPoint { let L = max(length, 0.0001); return .init(x: x/L, y: y/L) }
    func dot(_ p: CGPoint) -> CGFloat { x*p.x + y*p.y }
}

extension DatabaseReference {
    func setValueAsync(_ value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.setValue(value) { err, _ in
                if let err = err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume()
                }
            }
        }
    }
}

protocol OrderedKnob: CaseIterable, Hashable, Identifiable {
    static var ordered: [Self] { get }
}

private extension CGRect {
    var center: CGPoint { .init(x: midX, y: midY) }
}

extension RowLayout: OrderedKnob {
    static var ordered: [RowLayout] { [.wrap, .noWrap] }
}
extension ContentDisplay: OrderedKnob {
    static var ordered: [ContentDisplay] { [.textAndImage, .textOnly, .imageOnly] }
}
extension ItemSize: OrderedKnob {
    static var ordered: [ItemSize] { [.small, .medium, .large] }
}

enum RowLayout: String, CaseIterable, Hashable, Identifiable { case wrap, noWrap
    var id: String { rawValue }
    var title: String { self == .wrap ? "Wrapped" : "No Wrap" }
    var icon: String { self == .wrap ? "inset.filled.topleft.topright.bottomhalf.rectangle" : "square.grid.3x1.below.line.grid.1x2.fill" }
}

enum ContentDisplay: String, CaseIterable, Hashable, Identifiable { case textAndImage, textOnly, imageOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .textAndImage: return "Default"
        case .textOnly:     return "Text Only"
        case .imageOnly:    return "Image Only"
        }
    }
    var icon: String {
        switch self {
        case .textAndImage: return "text.below.photo.fill"
        case .textOnly:     return "textformat"
        case .imageOnly:    return "photo"
        }
    }
}

enum ItemSize: String, CaseIterable, Hashable, Identifiable { case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }
    var icon: String {
        switch self {
        case .small:  return "circle.grid.3x3.fill"
        case .medium: return "square.grid.2x2.fill"
        case .large:  return "square.fill"
        }
    }
    var thumb: CGFloat { self == .small ? 52 : (self == .medium ? 74 : 120) }
    var nameFont: CGFloat { self == .small ? 12 : (self == .medium ? 14 : 16) }
    var descFont: CGFloat { self == .small ? 10 : (self == .medium ? 12 : 13) }
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

// MARK: - Tier config model (editable)
struct TierConfig: Identifiable, Hashable {
    let id: String = UUID().uuidString
    var code: String      // e.g. "S"
    var label: String     // e.g. "Legendary"
    var colorHex: Int     // 0xRRGGBB
}

extension TierConfig {
    // full catalog S…Z
    static let letters: [String] = [
        "S","A","B","C","D","E","F",
        "G","H","I","J","K","L","M","N","O","P","Q","R","S2","T","U","V","W","X","Y","Z"
    ]
    static let labels: [String] = [
        "Legendary","Excellent","Solid","Average","Weak","Poor","Useless",
        "Decent","Okay","Meh","Flawed","Bad","Trash","Low","Bottom",
        "Minor","Subpar","Rough","Edge","Spare","Under","Vague","Weary","Worn","Xtra","Yield","Zero"
    ]
    static let colorsHex: [Int] = [
        0xC44536, 0xBF7B2F, 0xBFA254, 0x4DA35A, 0x3F7F74, 0x3F63A7, 0x6C46B3,
        0xA24A3A, 0xA46C33, 0xA89060, 0x3F9251, 0x3A6F69, 0x365A95, 0x5C45A6,
        0x8F3F33, 0x945F2E, 0x9F8458, 0x368647, 0x316B62, 0x2F568A, 0x523F98,
        0x7E362B, 0x86572A, 0x927C52, 0x2F7940, 0x2A6158, 0x274E80, 0x47388C
    ]

    static func defaultForPosition(_ idx: Int) -> TierConfig {
        let i = max(0, min(idx, letters.count - 1))
        // special-case already baked in: index 2 = B / Solid / 0xBFA254
        return TierConfig(code: letters[i], label: labels[i], colorHex: colorsHex[i])
    }

    /// Use this for first-open in TierListView so you start with exactly N tiers.
    static func starter(_ count: Int = 3) -> [TierConfig] {
        return (0..<max(0, count)).map { defaultForPosition($0) }
    }
}

// MARK: - Color <-> HEX helpers
extension Color {
    init(hex: Int) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

#if canImport(UIKit)
import UIKit
private func colorToHex(_ color: Color) -> Int {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    let R = Int(round(r * 255)), G = Int(round(g * 255)), B = Int(round(b * 255))
    return (R << 16) | (G << 8) | B
}
#else
import AppKit
private func colorToHex(_ color: Color) -> Int {
    let ns = NSColor(color)
    guard let srgb = ns.usingColorSpace(.sRGB) else { return 0xFFFFFF }
    let R = Int(round(srgb.redComponent   * 255))
    let G = Int(round(srgb.greenComponent * 255))
    let B = Int(round(srgb.blueComponent  * 255))
    return (R << 16) | (G << 8) | B
}
#endif

// MARK: - GROUP LIST VIEW
struct TierListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @AppStorage("group_wrap_mode")    private var wrapMode: RowLayout = .wrap
    @AppStorage("group_content_mode") private var contentMode: ContentDisplay = .textAndImage
    @AppStorage("group_size_mode")    private var sizeMode: ItemSize = .medium
    
    // MARK: - RANKO LIST DATA
    @State private var rankoID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var categoryName: String
    @State private var categoryIcon: String
    @State private var categoryColour: UInt
    @State private var tags: [String] = []
    
    // to revert to old values
    @State private var originalRankoName: String
    @State private var originalDescription: String
    @State private var originalIsPrivate: Bool
    @State private var originalCategoryName: String = ""
    @State private var originalCategoryIcon: String = ""
    @State private var originalCategoryColour: UInt = 0xFFFFFF
    
    // Sheet states
    @State private var showTabBar = true
    @State private var showEmbeddedStickyPoolSheet = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    
    @State private var addButtonTapped: Bool = false
    @State private var editButtonTapped: Bool = false
    @State private var exitButtonTapped: Bool = false
    
    @State private var addFrame: CGRect = .zero
    @State private var sampleFrame: CGRect = .zero
    @State private var blankFrame: CGRect = .zero
    
    @State private var exitFrame: CGRect = .zero
    @State private var saveFrame: CGRect = .zero
    @State private var deleteFrame: CGRect = .zero
    
    // Blank Items composer
    @State private var showBlankItemsFS = false
    @State private var blankDrafts: [BlankItemDraft] = [BlankItemDraft()] // start with 1
    @State private var draftError: String? = nil
    @Namespace private var transition
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
    @State private var imageReloadToken = UUID()
    
    @State private var progressLoading: Bool = false       // ← shows the loader
    @State private var publishError: String? = nil         // ← error messaging
    
    // selection mode
    @State private var selectionMode = false
    @State private var selectedItemIDs: Set<String> = []

    // selection action bar / sheets
    @State private var showSelectionBar = false
    @State private var showMoveSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    // Replace your old enum-based helper with this:
    private func tierConfigForRow(_ i: Int) -> TierConfig {
        if tiers.isEmpty { return TierConfig.defaultForPosition(0) } // ← S-tier
        let idx = max(0, min(i, tiers.count - 1))
        return tiers[idx]
    }
    
    // hold personal images picked for new items -> uploaded on publish
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
    
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [RankoItem] = []
    @State private var groupedItems: [[RankoItem]]
    @State private var selectedDetailItem: RankoItem? = nil

    private let seedItems: [RankoItem]

    @State private var tiers: [TierConfig] = TierConfig.starter(3)
    @State private var stagingTiers: [TierConfig] = []
    @State private var showTierEditor = false
    @State private var itemsWereJustAdded = false

    // ─────────────────────────────────────────────────────────────────────────────
    // 1) make this STATIC so it doesn't touch `self` during init
    private static func organizeItemsIntoRows(_ items: [RankoItem], minRowCount: Int) -> [[RankoItem]] {
        @inline(__always)
        func decode(_ r: Int) -> (row: Int, pos: Int) {
            if r >= 1000 { return (max(1, r / 1000), max(1, r % 1000)) }
            return (1, max(1, r))
        }
        let maxRowFromData = items.map { decode($0.rank).row }.max() ?? 0
        let rowCount = max(minRowCount, maxRowFromData)
        
        var buckets = Array(repeating: [RankoItem](), count: rowCount)
        for it in items {
            let (row, _) = decode(it.rank)
            let idx = min(max(1, row), rowCount) - 1
            buckets[idx].append(it)
        }
        for i in buckets.indices {
            buckets[i].sort { a, b in
                let pa = decode(a.rank).pos, pb = decode(b.rank).pos
                if pa != pb { return pa < pb }
                if a.rank != b.rank { return a.rank < b.rank }
                return a.id < b.id
            }
        }
        return buckets
    }

    // MARK: - INITIALISER
    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        categoryName: String,
        categoryIcon: String,
        categoryColour: UInt,
        groupedItems items: [RankoItem]? = nil
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _categoryName   = State(initialValue: categoryName)
        _categoryIcon = State(initialValue: categoryIcon)
        _categoryColour   = State(initialValue: categoryColour)

        // store the incoming items for later
        self.seedItems = items ?? []

        // first layout using a fixed minimum (don’t reference any @State yet)
        let initialMinRows = 3
        if !self.seedItems.isEmpty {
            _groupedItems = State(
                initialValue: Self.organizeItemsIntoRows(self.seedItems, minRowCount: initialMinRows)
            )
        } else {
            _groupedItems = State(initialValue: [])
        }

        // 2) initialize "original*" WITHOUT touching other @State vars
        _originalRankoName      = State(initialValue: rankoName)
        _originalDescription    = State(initialValue: description)
        _originalIsPrivate      = State(initialValue: isPrivate)
        _originalCategoryName   = State(initialValue: "Unknown")
        _originalCategoryIcon   = State(initialValue: "questionmark")
        _originalCategoryColour = State(initialValue: 0x000000)
    }
    
    enum WrapMode: String, CaseIterable { case wrap, noWrap }
    
    private struct RankoToolbarTitleStack: View {
        @StateObject private var user_data = UserInformation.shared
        let name: String
        let description: String
        @Binding var isPrivate: Bool
        let categoryName: String
        let categoryIcon: String
        let categoryColour: UInt
        @Binding var showEditDetailsSheet: Bool
        var onTapPrivacy: (() -> Void)?
        var onTapCategory: (() -> Void)?

        var body: some View {
            VStack(spacing: 6) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 50)
                // ranko name (top)
                Text(name.isEmpty ? "untitled ranko" : name)
                    .font(.custom("Nunito-Black", size: 18))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contextMenu {
                        Button {
                            showEditDetailsSheet = true
                        } label: {
                            Label("Edit Details", systemImage: "pencil")
                        }
                    }

                // description (middle)
                Text(description.isEmpty ? "no description yet..." : description)
                    .font(.custom("Nunito-Black", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity)
                    .contextMenu {
                        Button {
                            showEditDetailsSheet = true
                        } label: {
                            Label("Edit Details", systemImage: "pencil")
                        }
                    }

                // privacy + category (bottom)
                HStack(spacing: 8) {
                    Button {
                        // prefer explicit callback; fallback to opening the sheet
                        if let onTapPrivacy { onTapPrivacy() } else { showEditDetailsSheet = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isPrivate ? "lock.fill" : "globe.americas.fill")
                                .font(.system(size: 11, weight: .black))
                            Text(isPrivate ? "Private" : "Public")
                                .font(.custom("Nunito-Black", size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0xF2AB69), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            showEditDetailsSheet = true
                        } label: {
                            Label("Edit Details", systemImage: "pencil")
                        }
                        Button {
                            isPrivate.toggle()
                        } label: {
                            Label(isPrivate ? "Make Public" : "Make Private",
                                  systemImage: isPrivate ? "globe.americas.fill" : "lock.fill")
                        }
                    }

                    if categoryName != "" {
                        Button {
                            if let onTapCategory { onTapCategory() } else { showEditDetailsSheet = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 11, weight: .black))
                                Text(categoryName)
                                    .font(.custom("Nunito-Black", size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: categoryColour).opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                showEditDetailsSheet = true
                            } label: {
                                Label("Edit Details", systemImage: "pencil")
                            }
                        }
                    }
                }
                .frame(minWidth: CGFloat(user_data.deviceWidth))
            }
            .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - BODY VIEW
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView {
                    
                    VStack(spacing: 7) {
                        
                        
                        // KNOBS (3 groups of pills)
                        HStack(alignment: .top, spacing: 8) {
                            
                            // LEFT — wrap / no wrap
                            VerticalDropdownPicker<RowLayout>(
                                selection: $wrapMode,
                                title: { $0.title },
                                systemIcon: { $0.icon },
                                accent: Color(hex: 0x6D400F)
                            )
                            
                            // MIDDLE — content
                            VerticalDropdownPicker<ContentDisplay>(
                                selection: $contentMode,
                                title: { $0.title },
                                systemIcon: { $0.icon },
                                accent: Color(hex: 0x6D400F)
                            )
                            
                            // RIGHT — size (small / medium / large)
                            VerticalDropdownPicker<ItemSize>(
                                selection: $sizeMode,
                                title: { $0.title },
                                systemIcon: { $0.icon },
                                accent: Color(hex: 0x6D400F)
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        
                        if sizeMode == .large {
                            // large = vertical/grid-like cards
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 12) {
                                    ForEach(groupedItems.indices, id: \.self) { i in
                                        TierRow(
                                            selectionOn: showSelectionBar,                 // your selection mode flag
                                            selectedIDs: selectedItemIDs,                  // your Set<String>
                                            onToggleSelect: { id in toggleSelection(id) }, // your toggle function
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: wrapMode,
                                            contentDisplay: contentMode,
                                            itemSize: sizeMode,
                                            onEditTiers: {
                                                stagingTiers = tiers            // ← clone current tiers
                                                showTierEditor = true
                                            },
                                            canDelete: groupedItems[i].isEmpty,          // ← enable only when empty
                                            onDeleteTier: { idx in deleteTierRow(at: idx) }  // ← calls helper
                                        )
                                        .padding(.horizontal, 8)
                                    }
                                    addRowButton
                                }
                                .id(imageReloadToken)
                                .padding(.top, 10)
                                .padding(.bottom, 180)
                            }
                            
                        } else if wrapMode == .wrap {
                            // wrap = FlowLayout
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 12) {
                                    ForEach(groupedItems.indices, id: \.self) { i in
                                        TierRow(
                                            selectionOn: showSelectionBar,                 // your selection mode flag
                                            selectedIDs: selectedItemIDs,                  // your Set<String>
                                            onToggleSelect: { id in toggleSelection(id) }, // your toggle function
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: wrapMode,
                                            contentDisplay: contentMode,
                                            itemSize: sizeMode,
                                            onEditTiers: {
                                                stagingTiers = tiers            // ← clone current tiers
                                                showTierEditor = true
                                            },
                                            canDelete: groupedItems[i].isEmpty,          // ← enable only when empty
                                            onDeleteTier: { idx in deleteTierRow(at: idx) }  // ← calls helper
                                        )
                                        .padding(.horizontal, 8)
                                    }
                                    addRowButton
                                }
                                .padding(.top, 10)
                                .padding(.bottom, 180)
                            }
                            
                        } else {
                            // noWrap = horizontal scrollers
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 12) {
                                    ForEach(groupedItems.indices, id: \.self) { i in
                                        TierRow(
                                            selectionOn: showSelectionBar,                 // your selection mode flag
                                            selectedIDs: selectedItemIDs,                  // your Set<String>
                                            onToggleSelect: { id in toggleSelection(id) }, // your toggle function
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: wrapMode,
                                            contentDisplay: contentMode,
                                            itemSize: sizeMode,
                                            onEditTiers: {
                                                stagingTiers = tiers            // ← clone current tiers
                                                showTierEditor = true
                                            },
                                            canDelete: groupedItems[i].isEmpty,          // ← enable only when empty
                                            onDeleteTier: { idx in deleteTierRow(at: idx) }  // ← calls helper
                                        )
                                        .padding(.horizontal, 8)
                                    }
                                    addRowButton
                                }
                                .padding(.top, 10)
                                .padding(.bottom, 180)
                            }
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top, 60)
                }
                .onAppear {
                    ensureAtLeastRows(3)   // 👈 auto-insert three rows if fewer exist
                }
                if showTabBar {
                    VStack {
                        Spacer()
                        HStack {
                            GlassEffectContainer(spacing: 45) {
                                HStack(alignment: .bottom, spacing: 10) {
                                    VStack(spacing: -5) {
                                        VStack {
                                            VStack(spacing: 5) {
                                                if addButtonTapped {
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color(hex: 0x000000))
                                                } else {
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "plus.square.dashed")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 20, height: 20)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(Color(hex: 0x000000))
                                                        
                                                        Text("Add")
                                                            .font(.custom("Nunito-Black", size: 11))
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.7)
                                                            .allowsTightening(true)
                                                    }
                                                }
                                            }
                                            .frame(width: 60, height: 60)
                                            .background(Color.black.opacity(0.001))
                                            .contentShape(Circle())
                                            // capture exit button frame
                                            .background(
                                                GeometryReader { gp in
                                                    Color.clear
                                                        .onAppear { addFrame = gp.frame(in: .named("exitbar")) }
                                                        .onChange(of: gp.size) { _, _ in addFrame = gp.frame(in: .named("exitbar")) }
                                                }
                                            )
                                            .gesture(
                                                LongPressGesture(minimumDuration: 0.01)
                                                    .onEnded { _ in
                                                        if addButtonTapped {
                                                            withAnimation { addButtonTapped = false }
                                                        } else {
                                                            withAnimation { addButtonTapped = true }
                                                        }
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                        .overlay(alignment: .top) {
                                            if addButtonTapped {
                                                HStack {
                                                    // Blank Button
                                                    Button {
                                                        withAnimation { addButtonTapped = false }
                                                        openBlankComposer()
                                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                        impact.prepare()
                                                        impact.impactOccurred(intensity: 1.0)
                                                    } label: {
                                                        VStack(spacing: 5) {
                                                            Image(systemName: "square.dashed")
                                                                .resizable().scaledToFit()
                                                                .frame(width: 20, height: 20)
                                                            Text("Blank")
                                                                .font(.custom("Nunito-Black", size: 11))
                                                        }
                                                        .frame(width: 65, height: 65)
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { blankFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in blankFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    // Sample Button
                                                    Button {
                                                        showAddItemsSheet = true
                                                        withAnimation { addButtonTapped = false }
                                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                        impact.prepare()
                                                        impact.impactOccurred(intensity: 1.0)
                                                    } label: {
                                                        VStack(spacing: 5) {
                                                            Image(systemName: "square.dashed.inset.filled")
                                                                .resizable().scaledToFit()
                                                                .frame(width: 20, height: 20)
                                                            Text("Sample")
                                                                .font(.custom("Nunito-Black", size: 11))
                                                                .matchedTransitionSource(
                                                                    id: "sampleButton", in: transition
                                                                )
                                                        }
                                                        .frame(width: 65, height: 65)
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { sampleFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in sampleFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .simultaneousGesture(
                                                        LongPressGesture(minimumDuration: 0.0).onEnded { _ in
                                                            showAddItemsSheet = true
                                                            withAnimation { addButtonTapped = false }
                                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                            impact.prepare()
                                                            impact.impactOccurred(intensity: 1.0)
                                                        }
                                                    )
                                                }
                                                .offset(y: -55)
                                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                                .zIndex(50)
                                                .allowsHitTesting(true)
                                            }
                                        }
                                    }
                                    VStack(spacing: 5) {
                                        Image(systemName: "switch.2")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Edit")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "editButton", in: transition
                                            )
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation { editButtonTapped = true }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    VStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Select")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "rankButton", in: transition
                                            )
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation {
                                                    selectionMode = true
                                                    showTabBar = false
                                                    showSelectionBar = true
                                                    selectedItemIDs.removeAll()
                                                }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    VStack(spacing: -5) {
                                        VStack {
                                            VStack(spacing: 5) {
                                                if exitButtonTapped {
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color(hex: 0x000000))
                                                } else {
                                                    ZStack(alignment: .bottomLeading) {
                                                        Image(systemName: "rectangle.portrait.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 20, height: 20)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(Color(hex: 0x000000))
                                                        Image(systemName: "figure.walk")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 15, height: 15)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(Color(hex: 0xFFFFFF))
                                                            .offset(x: 2, y: -2)
                                                    }
                                                    
                                                    Text("Exit")
                                                        .font(.custom("Nunito-Black", size: 11))
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.7)
                                                        .allowsTightening(true)
                                                }
                                            }
                                            .frame(width: 60, height: 60)
                                            .background(Color.black.opacity(0.001))
                                            .contentShape(Circle())
                                            // capture exit button frame
                                            .background(
                                                GeometryReader { gp in
                                                    Color.clear
                                                        .onAppear { exitFrame = gp.frame(in: .named("exitbar")) }
                                                        .onChange(of: gp.size) { _, _ in exitFrame = gp.frame(in: .named("exitbar")) }
                                                }
                                            )
                                            .gesture(
                                                LongPressGesture(minimumDuration: 0.01)
                                                    .onEnded { _ in
                                                        if exitButtonTapped {
                                                            withAnimation { exitButtonTapped = false }
                                                        } else {
                                                            withAnimation { exitButtonTapped = true }
                                                        }
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                        .overlay(alignment: .top) {
                                            if exitButtonTapped {
                                                HStack {
                                                    // Delete
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "trash.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 20, height: 20)
                                                        Text("Delete")
                                                            .font(.custom("Nunito-Black", size: 11))
                                                    }
                                                    .frame(width: 65, height: 65)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { deleteFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in deleteFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .simultaneousGesture(
                                                        LongPressGesture(minimumDuration: 0.0).onEnded { _ in
                                                            withAnimation { DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() } }
                                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                            impact.prepare()
                                                            impact.impactOccurred(intensity: 1.0)
                                                        }
                                                    )
                                                    
                                                    // Save
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "square.and.arrow.down.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 20, height: 20)
                                                        Text("Save")
                                                            .font(.custom("Nunito-Black", size: 11))
                                                    }
                                                    .frame(width: 65, height: 65)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { saveFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in saveFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .simultaneousGesture(
                                                        LongPressGesture(minimumDuration: 0.0).onEnded { _ in
                                                            withAnimation { exitButtonTapped = false }
                                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                            impact.prepare()
                                                            impact.impactOccurred(intensity: 1.0)
                                                            startPublishAndDismiss()  // ← NEW
                                                        }
                                                    )
                                                }
                                                .offset(y: -55)
                                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                                .zIndex(50)
                                                .allowsHitTesting(true)
                                            }
                                        }
                                    }
                                }
                            }
                            .shadow(color: Color(hex: 0x000000).opacity(0.15), radius: 4)
                        }
                    }
                    .coordinateSpace(name: "exitbar")   // ← add this
                    .padding(.bottom, 10)
                }
                
                
                
                if showSelectionBar {
                    VStack {
                        Spacer()
                        HStack {
                            GlassEffectContainer(spacing: 45) {
                                HStack(alignment: .bottom, spacing: 10) {
                                    VStack(spacing: 5) {
                                        Image(systemName: "pencil")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Edit")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "itemEditButton", in: transition
                                            )
                                    }
                                    .opacity(!selectedItemIDs.isEmpty ? 1 : 0.25)
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation {
                                                    if !selectedItemIDs.isEmpty {
                                                        showEditSheet = true
                                                    }
                                                }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    
                                    VStack(spacing: 5) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Move")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "itemMoveButton", in: transition
                                            )
                                    }
                                    .opacity(!selectedItemIDs.isEmpty ? 1 : 0.25)
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation {
                                                    if !selectedItemIDs.isEmpty {
                                                        showMoveSheet = true
                                                    }
                                                }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    
                                    VStack(spacing: 5) {
                                        Image(systemName: "trash")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Delete")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "itemDeleteButton", in: transition
                                            )
                                    }
                                    .opacity(!selectedItemIDs.isEmpty ? 1 : 0.25)
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation {
                                                    if !selectedItemIDs.isEmpty {
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    
                                    VStack(spacing: 5) {
                                        Image(systemName: "checkmark")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .fontWeight(.bold)
                                        
                                        Text("Done")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                            .matchedTransitionSource(
                                                id: "itemDoneButton", in: transition
                                            )
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Circle())
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                                    selectionMode = false
                                                    showSelectionBar = false
                                                    showTabBar = true
                                                    selectedItemIDs.removeAll()
                                                }
                                            }
                                    )
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                }
                            }
                            .shadow(color: Color(hex: 0x000000).opacity(0.15), radius: 4)
                        }
                    }
                    .coordinateSpace(name: "exitbar")   // ← add this
                    .padding(.bottom, 10)
                }
            }
            .onAppear {
                guard !seedItems.isEmpty else { return }
                let exactMinRows = max(3, tiers.count)      // respect your configured tiers
                groupedItems = TierListView.organizeItemsIntoRows(seedItems, minRowCount: exactMinRows)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RankoToolbarTitleStack(
                        name: rankoName,
                        description: description,
                        isPrivate: $isPrivate,
                        categoryName: categoryName,
                        categoryIcon: categoryIcon,
                        categoryColour: categoryColour,
                        showEditDetailsSheet: $showEditDetailsSheet,
                        onTapPrivacy: {  },   // or: { isPrivate.toggle() }
                        onTapCategory: {  }
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(rankoName). \(description). \(isPrivate ? "Private" : "Public"). \(categoryName)")
                }
            }
            .alert("Delete selected items?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteSelectedItems()
                    exitSelection()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("\(selectedItemIDs.count) item(s) will be removed.")
            }
            .sheet(isPresented: $showTierEditor) {
                TierEditorSheet(
                    tiers: $stagingTiers,                   // ← edit the staging copy
                    lockedCount: groupedItems.count,
                    onConfirm: { finalCount in
                        // ✅ commit changes
                        tiers = stagingTiers
                        
                        // grow rows to match (never shrink to avoid nuking existing tiers/items)
                        if finalCount > groupedItems.count {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                let delta = finalCount - groupedItems.count
                                groupedItems.append(contentsOf: Array(repeating: [], count: delta))
                            }
                        }
                    }
                )
                .interactiveDismissDisabled(true)
                .presentationBackground(.white)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(progressLoading) // block pull-to-dismiss on sheets while saving
            .disabled(progressLoading)                   // block interactions while saving
            .alert("Couldn't publish", isPresented: .init(
                get: { publishError != nil },
                set: { if !$0 { publishError = nil } }
            )) {
                Button("Retry") {
                    startPublishAndDismiss()
                }
                Button("Cancel", role: .cancel) {
                    // 🔥 Nuke only if the user gives up
                    Task { await deleteRankoPersonalFolderAsync(rankoID: rankoID) }
                }
            } message: {
                Text(publishError ?? "Something went wrong.")
            }
            .refreshable {
                refreshItemImages()
            }
            .sheet(isPresented: $showEditDetailsSheet) {
                DefaultListEditDetails(
                    rankoName: rankoName,
                    description: description,
                    isPrivate: isPrivate,
                    categoryName: categoryName,
                    categoryIcon: categoryIcon,
                    categoryColour: categoryColour
                ) { newName, newDescription, newPrivate, newCategoryName, newCategoryIcon, newCategoryColour in
                    rankoName      = newName
                    description    = newDescription
                    isPrivate      = newPrivate
                    categoryName   = newCategoryName
                    categoryIcon   = newCategoryIcon
                    categoryColour = newCategoryColour
                }
            }
            .sheet(isPresented: $editButtonTapped) {
                DefaultListEditDetails(
                    rankoName: rankoName,
                    description: description,
                    isPrivate: isPrivate,
                    categoryName: categoryName,
                    categoryIcon: categoryIcon,
                    categoryColour: categoryColour
                ) { newName, newDescription, newPrivate, newCategoryName, newCategoryIcon, newCategoryColour in
                    rankoName      = newName
                    description    = newDescription
                    isPrivate      = newPrivate
                    categoryName   = newCategoryName
                    categoryIcon   = newCategoryIcon
                    categoryColour = newCategoryColour
                }
                .navigationTransition(
                    .zoom(sourceID: "editButton", in: transition)
                )
            }
            .sheet(isPresented: $showEditSheet) {
                EditItemsComposer(
                    rankoID: rankoID,     // <- pass your list’s id
                    items: selectedItems(),       // items user picked
                    onSave: { edited in
                        applyEdits(edited)
                        exitSelection()
                    },
                    onCancel: {
                        exitSelection()
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(item: $selectedDetailItem) { tappedItem in
                let rowIndex = groupedItems.firstIndex { row in
                    row.contains { $0.id == tappedItem.id }
                } ?? 0
                
                TierItemDetailView(
                    items: groupedItems[rowIndex],
                    rowIndex: rowIndex,
                    numberOfRows: (groupedItems.count),
                    initialItem: tappedItem,
                    rankoID:  rankoID
                ) { updatedItem in
                    if let idx = groupedItems[rowIndex]
                        .firstIndex(where: { $0.id == updatedItem.id }) {
                        groupedItems[rowIndex][idx] = updatedItem
                    }
                }
            }
            .sheet(isPresented: $showMoveSheet) {
                NavigationStack {
                    List {
                        ForEach(Array(tiers.enumerated()), id: \.offset) { (idx, t) in
                            let rowNumber = idx + 1
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: t.colorHex))
                                    .frame(width: 14, height: 14)
                                Text("\(t.code) • \(t.label)")
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                moveSelected(toRow: rowNumber)
                                exitSelection()
                            }
                        }
                    }
                    .navigationTitle("Move to Tier")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showMoveSheet = false }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddItemsSheet) {
                AddItemsPickerSheet(selectedRankoItems: $unGroupedItems)
                    .presentationDetents([.large])
                    .interactiveDismissDisabled(true)
                    .navigationTransition(.zoom(sourceID: "sampleButton", in: transition))
            }
            .onChange(of: showAddItemsSheet) { wasShowing, isShowing in
                // When the add items sheet closes, check if we should show the pool
                if wasShowing && !isShowing {
                    showStickyPoolIfNeeded()
                }
            }
            
            .fullScreenCover(isPresented: $showBlankItemsFS, onDismiss: {
                blankDrafts = [BlankItemDraft()]
                draftError = nil
                showStickyPoolIfNeeded()
            }) {
                BlankItemsComposer(
                    rankoID: rankoID,
                    drafts: $blankDrafts,
                    error: $draftError,
                    canAddMore: blankDrafts.count < 10,
                    onCommit: {
                        appendDraftsToSelectedRanko()
                    }
                )
            }

            // 4. Update your embeddedStickyPoolSheet configuration:

            .sheet(isPresented: $showEmbeddedStickyPoolSheet) {
                embeddedStickyPoolView
                    .interactiveDismissDisabled(false)
                    .presentationDetents([.height(160)])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationBackground(.clear)
            }
//            .onChange(of: unGroupedItems.count) { oldCount, newCount in
//                // Auto-hide when empty
//                if newCount == 0 && showEmbeddedStickyPoolSheet {
//                    withAnimation {
//                        showEmbeddedStickyPoolSheet = false
//                    }
//                }
//                // Auto-show when items added (and no blocking sheets)
//                else if newCount > 0 && newCount > oldCount {
//                    showStickyPoolIfNeeded()
//                }
//            }

             //4. Also watch for when items are dragged out of pool into tiers
            .onChange(of: groupedItems.flatMap { $0 }.count) { _, _ in
                // If pool became empty due to dragging, hide it
                if unGroupedItems.isEmpty && showEmbeddedStickyPoolSheet {
                    withAnimation {
                        showEmbeddedStickyPoolSheet = false
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
    
    private func deleteSelectedItems() {
        for rowIdx in groupedItems.indices {
            groupedItems[rowIdx].removeAll { selectedItemIDs.contains($0.id) }
        }
        // optional: delete from Firebase Storage (images) + RTDB here
    }
    
    private func moveSelected(toRow targetRow: Int) {
        // 1) pull out selected
        var moving: [RankoItem] = []
        for rowIdx in groupedItems.indices {
            groupedItems[rowIdx].removeAll { it in
                if selectedItemIDs.contains(it.id) { moving.append(it); return true }
                return false
            }
        }
        // 2) insert into target row
        let posStart = groupedItems[targetRow - 1].count
        ensureAtLeastRows(targetRow)
        for (offset, var it) in moving.enumerated() {
            let position = posStart + offset + 1
            let newRank = Double(targetRow) + Double(position) / 10_000.0
            it.rank = Int(newRank)
            groupedItems[targetRow - 1].append(it)
        }
        // 3) re-sort target row by rank
        groupedItems[targetRow - 1].sort { $0.rank < $1.rank }

        // optional: write updates to Firebase here
    }
    
    @ViewBuilder
    private func label(_ title: String, _ sf: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: sf).font(.system(size: 14, weight: .black))
            Text(title).font(.custom("Nunito-Black", size: 14))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.9), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
    
    @inlinable
    func decimalRank(rowNumber: Int, position: Int) -> Double {
        Double(rowNumber) + Double(position) / 10_000.0
    }
    
    private func refreshItemImages() {
        guard !groupedItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    private func showStickyPoolIfNeeded() {
        // Only show if:
        // 1. There are items
        // 2. Sheet isn't already showing
        // 3. No other fullscreen sheets are active
        if !unGroupedItems.isEmpty &&
           !showEmbeddedStickyPoolSheet &&
           !showAddItemsSheet &&
           !showBlankItemsFS {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showEmbeddedStickyPoolSheet = true
            }
        }
    }

    
    // MARK: - Tier Editor Sheet
    struct TierEditorSheet: View {
        @Environment(\.dismiss) private var dismiss

        @Binding var tiers: [TierConfig]
        let lockedCount: Int
        var onConfirm: ((Int) -> Void)? = nil

        @State private var activeColorTierID: String? = nil
        @State private var showColorPicker = false
        @State private var tempColor: Color = .white

        // keyboard focus per-tier
        @FocusState private var focus: Field?
        enum Field: Hashable {
            case code(String)      // tier.id
            case subtitle(String)  // tier.id
        }

        private let maxTiers = 25

        var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array($tiers.enumerated()), id: \.element.id) { idx, $tier in
                            TierCard(
                                index: idx,
                                tier: $tier,
                                isDeleteDisabled: idx < lockedCount,
                                onTapColor: {
                                    activeColorTierID = tier.id
                                    tempColor = Color(hex: tier.colorHex)
                                    showColorPicker = true
                                },
                                onDefault: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        tiers[idx] = TierConfig.defaultForPosition(idx)
                                    }
                                },
                                onDelete: {
                                    guard idx >= lockedCount else { return }
                                    tiers.remove(at: idx)
                                },
                                focus: $focus, // ← pass the FocusState<Field?>.Binding
                                onSubmitCode: {
                                    focus = .subtitle(tier.id)
                                },
                                onSubmitSubtitle: {
                                    if idx + 1 < tiers.count {
                                        focus = .code(tiers[idx + 1].id)
                                    } else if tiers.count < maxTiers {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                            tiers.append(TierConfig.defaultForPosition(tiers.count))
                                        }
                                        let newID = tiers.last!.id
                                        DispatchQueue.main.async { focus = .code(newID) }
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        Button {
                            guard tiers.count < maxTiers else { return }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                tiers.append(TierConfig.defaultForPosition(tiers.count))
                            }
                            let newID = tiers.last!.id
                            DispatchQueue.main.async { focus = .code(newID) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.rectangle")
                                Text("ADD TIER")
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                        .disabled(tiers.count >= maxTiers)
                        .opacity(tiers.count >= maxTiers ? 0.5 : 1)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .navigationTitle("Edit Tiers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 18, weight: .bold))
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {                             // ✅ apply
                            normalizeAll()
                            onConfirm?(tiers.count)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                        }
                    }
                }
                // KEYBOARD TOOLBAR
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button { if let id = focusedTierID() { focus = .code(id) } }
                               label: { Image(systemName: "textformat.abc") }
                           .disabled({ if case .code = focus { return true }; return false }())

                        Spacer(minLength: 36)

                        Button { if let id = focusedTierID() { focus = .subtitle(id) } }
                               label: { Image(systemName: "text.alignleft") }
                           .disabled({ if case .subtitle = focus { return true }; return false }())

                        Spacer(minLength: 36)

                        Button {
                            if let id = focusedTierID(), let t = tiers.first(where: { $0.id == id }) {
                                activeColorTierID = t.id; tempColor = Color(hex: t.colorHex); showColorPicker = true
                            }
                        } label: { Image(systemName: "paintpalette") }

                        Spacer(minLength: 36)

                        Button {
                            if let id = focusedTierID(), let i = tiers.firstIndex(where: { $0.id == id }) {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    tiers[i] = TierConfig.defaultForPosition(i)
                                }
                            }
                        } label: { Image(systemName: "arrow.counterclockwise") }

                        Spacer(minLength: 36)

                        Button {
                            if let id = focusedTierID(), let i = tiers.firstIndex(where: { $0.id == id }), i >= lockedCount {
                                tiers.remove(at: i)
                            }
                        } label: { Image(systemName: "trash") }
                        .disabled({
                            if let id = focusedTierID(), let i = tiers.firstIndex(where: { $0.id == id }) { return i < lockedCount }
                            return true
                        }())

                        Spacer() // push dismiss all the way right

                        Button { hideKeyboard() } label: { Image(systemName: "keyboard.chevron.compact.down") }
                    }
                }
            }
            .font(.custom("Nunito-Black", size: 16))
            .presentationBackground(.white)
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showColorPicker) {
                VStack(spacing: 16) {
                    Text("Pick Tier Color").font(.custom("Nunito-Black", size: 18))
                    ColorPicker("", selection: $tempColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding()

                    Button {
                        if let id = activeColorTierID,
                           let idx = tiers.firstIndex(where: { $0.id == id }) {
                            tiers[idx].colorHex = colorToHex(tempColor)
                        }
                        showColorPicker = false
                    } label: {
                        Text("Use This Color")
                            .font(.custom("Nunito-Black", size: 16))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .presentationDetents([ .height(240) ])
                .presentationBackground(.white)
            }
        }

        // MARK: helpers
        private func normalizeAll() {
            for i in tiers.indices {
                tiers[i].code  = String(tiers[i].code.uppercased().prefix(3))
                tiers[i].label = String(tiers[i].label.prefix(10))
            }
        }
        private func focusedTierID() -> String? {
            switch focus {
            case .code(let id):      return id
            case .subtitle(let id):  return id
            default: return tiers.first?.id
            }
        }
        private var isCodeFocused: Bool {
            if case .code = focus { return true }
            return false
        }
        private var isSubtitleFocused: Bool {
            if case .subtitle = focus { return true }
            return false
        }
    }

    // A single editable card for one tier
    private struct TierCard: View {
        let index: Int
        @Binding var tier: TierConfig
        var isDeleteDisabled: Bool
        var onTapColor: () -> Void
        var onDefault: () -> Void
        var onDelete: () -> Void

        // ✅ take the parent's FocusState enum binding
        var focus: FocusState<TierEditorSheet.Field?>.Binding

        var onSubmitCode: () -> Void
        var onSubmitSubtitle: () -> Void

        var body: some View {
            VStack(spacing: 12) {
                HStack {
                    Text("TIER #\(index + 1)")
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 18) {
                        Button(action: onDefault) {
                            Label("Default", systemImage: "arrow.counterclockwise")
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.custom("Nunito-Black", size: 12))

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.custom("Nunito-Black", size: 12))
                        .disabled(isDeleteDisabled)
                        .opacity(isDeleteDisabled ? 0.35 : 1)
                    }
                }

                HStack(spacing: 10) {
                    // CODE
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CODE (max 3)")
                            .font(.custom("Nunito-Black", size: 10))
                            .foregroundStyle(.secondary)

                        TextField("S", text: Binding(
                            get: { tier.code },
                            set: { tier.code = String($0.uppercased().prefix(3)) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .font(.custom("Nunito-Black", size: 15))
                        // ✅ enum-based focus
                        .focused(focus, equals: .code(tier.id))
                        .submitLabel(.next)
                        .onSubmit { onSubmitCode() }
                    }

                    // SUBTITLE
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUBTITLE (max 10)")
                            .font(.custom("Nunito-Black", size: 10))
                            .foregroundStyle(.secondary)

                        TextField("Legendary", text: Binding(
                            get: { tier.label },
                            set: { tier.label = String($0.prefix(10)) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .font(.custom("Nunito-Black", size: 15))
                        // ✅ enum-based focus
                        .focused(focus, equals: .subtitle(tier.id))
                        .submitLabel(.done)
                        .onSubmit { onSubmitSubtitle() }
                    }

                    Spacer()

                    // color swatch with centered pencil
                    Button(action: onTapColor) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: tier.colorHex))
                                .frame(width: 56, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.black.opacity(0.08), lineWidth: 1)
                                )
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change color")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.05))   // grayer background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
    }
    
    // MARK: - Tier header box using TierConfig
    struct TierHeader: View {
        let tier: TierConfig
        var body: some View {
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                
                Text(tier.code)
                    .font(.custom("Nunito-Black", size: 18))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .padding(.horizontal, 16)

                Text(tier.label)
                    .font(.custom("Nunito-Black", size: 9))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 6)
                    .padding(.horizontal, 6)
                
                Spacer(minLength: 0)
            }
            .frame(minWidth: 70, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: tier.colorHex))
            )
            .padding(8)
        }
    }
        
    private func selectableItemRow(_ item: RankoItem) -> some View {
        HStack(spacing: 10) {
            if selectionMode {
                Button {
                    toggleSelection(item.id)
                } label: {
                    Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(selectedItemIDs.contains(item.id) ? Color(hex: 0x2ECC71) : Color(hex: 0xC8C8C8))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            // your existing thumbnail + title
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text(item.itemName)
                .font(.custom("Nunito-Black", size: 14))
                .foregroundColor(Color(hex: 0x666666))
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectionMode { toggleSelection(item.id) }
            else { /* normal tap behavior if needed */ }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedItemIDs.contains(id) { selectedItemIDs.remove(id) }
        else { selectedItemIDs.insert(id) }
    }
    
    private func ensureAtLeastRows(_ n: Int = 3) {
        if groupedItems.count < n {
            groupedItems.append(contentsOf: Array(repeating: [], count: n - groupedItems.count))
        }
    }
    
    private func ensureTierCountMatchesRows() {
        while tiers.count < groupedItems.count {
            tiers.append(TierConfig.defaultForPosition(tiers.count))
        }
    }
    
    private var addRowButton: some View {
        Button {
            groupedItems.append([])
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                ensureTierCountMatchesRows()
            }
        } label: {
            HStack {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                Text("ADD TIER")
                    .foregroundColor(.white)
                    .font(.custom("Nunito-Black", size: 16))
                
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x0C7DFF))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    struct EditItemsComposer: View {
        @Environment(\.dismiss) private var dismiss
        @StateObject private var user_data = UserInformation.shared

        // Immutable inputs
        let rankoID: String
        let items: [RankoItem]
        let onSave: ([RankoItem]) -> Void
        let onCancel: () -> Void

        // Local editable working copies (UI state mirrors BlankItemsComposer)
        @State private var edits: [EditableItem]

        // Image edit flow (same as BlankItemsComposer)
        @State private var activeEditID: String? = nil
        @State private var showNewImageSheet = false
        @State private var showPhotoPicker = false
        @State private var showImageCropper = false
        @State private var imageForCropping: UIImage? = nil
        @State private var backupImage: UIImage? = nil
        @State private var backupURLString: String? = nil

        // Alerts
        @State private var uploadAlertMessage: String? = nil

        // Focus (keeps inputs identical to BlankItemsComposer UX)
        @FocusState private var focusedField: Field?
        enum Field: Hashable { case name(String), description(String) }

        // MARK: - Init from immutable inputs
        init(rankoID: String,
             items: [RankoItem],
             onSave: @escaping ([RankoItem]) -> Void,
             onCancel: @escaping () -> Void) {
            self.rankoID = rankoID
            self.items = items
            self.onSave = onSave
            self.onCancel = onCancel
            self._edits = State(initialValue: items.map {
                EditableItem(
                    id: $0.id,
                    name: $0.record.ItemName,
                    description: $0.record.ItemDescription,
                    imageURL: $0.record.ItemImage,      // URL string
                    localImage: nil,                    // lazy-load if you want
                    rank: $0.rank,
                    votes: $0.votes,
                    playCount: $0.playCount,
                    gif: $0.record.ItemGIF,
                    video: $0.record.ItemVideo,
                    audio: $0.record.ItemAudio,
                    category: "",
                    isUploading: false,
                    uploadError: nil
                )
            })
        }

        // MARK: - Body
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach($edits) { $edit in
                            EditableCard(
                                edit: $edit,
                                title: "Edit Item #\(indexOf(edit.id) + 1)",
                                subtitle: "tap to change image",
                                focusedField: $focusedField,
                                onTapImage: { beginImageChange(for: edit.id) }
                            )
                            .contextMenu {
                                Button {
                                    beginImageChange(for: edit.id)
                                } label: { Label("Change Image", systemImage: "photo.fill") }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onCancel()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Edit Items")
                            .font(.custom("Nunito-Black", size: 20))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Rebuild immutable RankoItems from edits
                            let updated: [RankoItem] = edits.compactMap { e in
                                guard let original = items.first(where: { $0.id == e.id }) else { return nil }
                                let newRecord = RankoRecord(
                                    objectID: e.id,
                                    ItemName: e.name,
                                    ItemDescription: e.description,
                                    ItemCategory: "",
                                    ItemImage: e.imageURL,     // updated URL if upload succeeded
                                    ItemGIF: e.gif,
                                    ItemVideo: e.video,
                                    ItemAudio: e.audio
                                )
                                return RankoItem(
                                    id: e.id,
                                    rank: original.rank,       // keep rank (or use e.rank if you allow edits)
                                    votes: original.votes,
                                    record: newRecord,
                                    playCount: original.playCount
                                )
                            }
                            onSave(updated)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                if edits.contains(where: { $0.isUploading }) {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                        }
                        .disabled(edits.contains { $0.isUploading })
                    }
                }
                .sheet(isPresented: $showNewImageSheet) {
                    NewImageSheet(pickFromLibrary: {
                        showNewImageSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPhotoPicker = true }
                    })
                    .presentationDetents([.fraction(0.4)])
                    .presentationBackground(Color.white)
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
                }
                .fullScreenCover(isPresented: $showImageCropper) {
                    if let img = imageForCropping {
                        SwiftyCropView(
                            imageToCrop: img,
                            maskShape: .square,
                            configuration: SwiftyCropConfiguration(
                                maxMagnificationScale: 8.0,
                                maskRadius: 190.0,
                                cropImageCircular: false,
                                rotateImage: false,
                                rotateImageWithButtons: true,
                                usesLiquidGlassDesign: true,
                                zoomSensitivity: 3.0
                            ),
                            onCancel: {
                                imageForCropping = nil
                                showImageCropper = false
                                restoreBackupForActiveEdit()
                            },
                            onComplete: { cropped in
                                imageForCropping = nil
                                showImageCropper = false
                                if let id = activeEditID, let c = cropped {
                                    Task { await uploadCropped(c, for: id) }
                                }
                            }
                        )
                    }
                }
                .onChange(of: imageForCropping) { _, newVal in
                    if newVal != nil { showImageCropper = true }
                }
                .alert("Image upload failed", isPresented: .init(
                    get: { uploadAlertMessage != nil },
                    set: { if !$0 { uploadAlertMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(uploadAlertMessage ?? "Unknown error")
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }

        // MARK: - Card identical styling to BlankItemsComposer
        private struct EditableCard: View {
            @Binding var edit: EditableItem
            let title: String
            let subtitle: String
            let focusedField: FocusState<EditItemsComposer.Field?>.Binding
            var onTapImage: () -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(title.uppercased())
                            .font(.custom("Nunito-Black", size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if edit.isUploading { ProgressView().controlSize(.small) }
                    }

                    // Image block (tap to change)
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: onTapImage) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .frame(width: 240, height: 240)

                                if let img = edit.localImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 240, height: 240)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .contentShape(Rectangle())
                                } else {
                                    AsyncImage(url: URL(string: edit.imageURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable()
                                                .scaledToFill()
                                                .frame(width: 240, height: 240)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        default:
                                            VStack(spacing: 10) {
                                                Image(systemName: "photo.on.rectangle.angled")
                                                    .font(.system(size: 28, weight: .black))
                                                    .opacity(0.35)
                                                Text(subtitle.uppercased())
                                                    .font(.custom("Nunito-Black", size: 13))
                                                    .opacity(0.6)
                                            }
                                            .frame(width: 240, height: 240)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(edit.isUploading)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)

                    // Fields block (mirrors BlankItemsComposer styles/symbols)
                    VStack(spacing: 14) {
                        // NAME
                        VStack(spacing: 5) {
                            HStack {
                                Text("Item Name".uppercased())
                                    .foregroundColor(.secondary)
                                    .font(.custom("Nunito-Black", size: 12))
                                Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 6)

                            HStack(spacing: 6) {
                                Image(systemName: "textformat.size.larger").foregroundColor(.gray).padding(.trailing, 1)
                                TextField("Item Name *", text: $edit.name)
                                    .font(.custom("Nunito-Black", size: 18))
                                    .autocorrectionDisabled(true)
                                    .onChange(of: edit.name) { _, v in
                                        if v.count > 50 { edit.name = String(v.prefix(50)) }
                                    }
                                    .foregroundStyle(.gray)
                                    .focused(focusedField, equals: .name(edit.id))
                                    .submitLabel(.next)
                                    .onSubmit { focusedField.wrappedValue = .description(edit.id) }

                                Spacer()
                                Text("\(edit.name.count)/50")
                                    .font(.caption2).fontWeight(.light)
                                    .padding(.top, 15).foregroundColor(.secondary)
                            }
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(Color.gray.opacity(0.08))
                                    .allowsHitTesting(false)
                            )
                        }

                        // DESCRIPTION
                        VStack(spacing: 5) {
                            HStack {
                                Text("Description".uppercased())
                                    .foregroundColor(.secondary)
                                    .font(.custom("Nunito-Black", size: 12))
                                    .padding(.leading, 6)
                                Spacer(minLength: 0)
                            }

                            HStack {
                                Image(systemName: "textformat.size.smaller").foregroundColor(.gray).padding(.trailing, 1)
                                TextField("Item Description (optional)", text: $edit.description, axis: .vertical)
                                    .font(.custom("Nunito-Black", size: 18))
                                    .autocorrectionDisabled(true)
                                    .onChange(of: edit.description) { _, v in
                                        if v.count > 100 { edit.description = String(v.prefix(100)) }
                                    }
                                    .foregroundStyle(.gray)
                                    .focused(focusedField, equals: .description(edit.id))
                                    .submitLabel(.done)

                                Spacer()
                                Text("\(edit.description.count)/100")
                                    .font(.caption2).fontWeight(.light)
                                    .padding(.top, 15).foregroundColor(.secondary)
                            }
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(Color.gray.opacity(0.08))
                                    .allowsHitTesting(false)
                            )
                        }
                    }

                    if let err = edit.uploadError {
                        HStack {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }

        // MARK: - Editable working copy
        struct EditableItem: Identifiable {
            let id: String
            var name: String
            var description: String
            var imageURL: String
            var localImage: UIImage?

            // keep around (not editable here)
            var rank: Int
            var votes: Int
            var playCount: Int

            var gif: String?
            var video: String?
            var audio: String?
            var category: String

            // upload flags
            var isUploading: Bool
            var uploadError: String?
        }

        // MARK: - Image flow hooks (mirrors BlankItemsComposer)
        private func beginImageChange(for id: String) {
            activeEditID = id
            if let idx = edits.firstIndex(where: { $0.id == id }) {
                backupImage = edits[idx].localImage
                backupURLString = edits[idx].imageURL
            }
            showNewImageSheet = true
        }

        private func finalURL(for itemID: String) -> String {
            "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F\(itemID).jpg?alt=media&token="
        }

        private func makeJPEGMetadata(rankoID: String, itemID: String, userID: String) -> StorageMetadata {
            let md = StorageMetadata()
            md.contentType = "image/jpeg"
            let now = Date()
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
            fmt.dateFormat = "yyyyMMddHHmmss"
            md.customMetadata = [
                "rankoID": rankoID,
                "itemID": itemID,
                "userID": userID,
                "uploadedAt": fmt.string(from: now)
            ]
            return md
        }

        private enum TimeoutErr: Error { case timedOut }

        private func withTimeout<T>(seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await op() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw TimeoutErr.timedOut
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }

        private func setUploading(_ uploading: Bool, for id: String) {
            if let i = edits.firstIndex(where: { $0.id == id }) {
                edits[i].isUploading = uploading
                if uploading { edits[i].uploadError = nil }
            }
        }

        private func setUploadSuccess(image: UIImage, url: String, for id: String) {
            if let i = edits.firstIndex(where: { $0.id == id }) {
                edits[i].localImage = image
                edits[i].imageURL = url
                edits[i].isUploading = false
                edits[i].uploadError = nil
            }
        }

        private func setUpload(error: String, for id: String) {
            if let i = edits.firstIndex(where: { $0.id == id }) {
                edits[i].isUploading = false
                edits[i].uploadError = error
            }
        }

        private func restoreBackupForActiveEdit() {
            guard let id = activeEditID, let idx = edits.firstIndex(where: { $0.id == id }) else { return }
            // revert
            edits[idx].localImage = backupImage
            if let oldURL = backupURLString {
                edits[idx].imageURL = oldURL
            }
        }

        private func uploadCropped(_ img: UIImage, for itemID: String) async {
            guard let data = img.jpegData(compressionQuality: 0.9) else {
                setUpload(error: "Couldn't encode image", for: itemID)
                uploadAlertMessage = "Couldn't encode image."
                restoreBackupForActiveEdit()
                return
            }
            setUploading(true, for: itemID)

            let path = "rankoPersonalImages/\(rankoID)/\(itemID).jpg"
            let ref  = Storage.storage().reference().child(path)
            let metadata = makeJPEGMetadata(rankoID: rankoID, itemID: itemID, userID: user_data.userID)

            do {
                try await withTimeout(seconds: 10) {
                    _ = try await ref.putDataAsync(data, metadata: metadata)
                }
                // success
                setUploadSuccess(image: img, url: finalURL(for: itemID), for: itemID)
            } catch {
                let msg: String
                if error is TimeoutErr { msg = "Upload timed out. Please try again." }
                else { msg = (error as NSError).localizedDescription }
                setUpload(error: msg, for: itemID)
                uploadAlertMessage = msg
                restoreBackupForActiveEdit()
            }
        }

        // MARK: - Helpers
        private func indexOf(_ id: String) -> Int {
            (edits.firstIndex { $0.id == id } ?? 0) + 1
        }
    }
    
    private func selectedItems() -> [RankoItem] {
        groupedItems.flatMap { $0 }.filter { selectedItemIDs.contains($0.id) }
    }

    private func applyEdits(_ edited: [RankoItem]) {
        let map = Dictionary(uniqueKeysWithValues: edited.map { ($0.id, $0) })
        for rowIdx in groupedItems.indices {
            for colIdx in groupedItems[rowIdx].indices {
                let id = groupedItems[rowIdx][colIdx].id
                if let updated = map[id] {
                    groupedItems[rowIdx][colIdx] = updated
                }
            }
        }
        // optional: write updates to Firebase here
    }

    private func exitSelection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            selectionMode = false
            showSelectionBar = false
            showTabBar = true
            selectedItemIDs.removeAll()
        }
    }
    
    private struct BlankItemsComposer: View {
        @Environment(\.dismiss) private var dismiss
        @StateObject private var user_data = UserInformation.shared

        let rankoID: String

        @Binding var drafts: [BlankItemDraft]
        @Binding var error: String?
        let canAddMore: Bool
        let onCommit: () -> Void

        @State private var activeDraftID: String? = nil
        @State private var showNewImageSheet = false
        @State private var showPhotoPicker = false
        @State private var showImageCropper = false
        @State private var imageForCropping: UIImage? = nil
        @State private var backupImage: UIImage? = nil
        @State private var isCleaningUp = false
        
        private let maxItems = 10
        
        @FocusState private var focusedField: Field?
        enum Field: Hashable { case name(String), description(String) }
        
        // convenience
        private var placeholderURL: String {
            "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
        }
        private func finalURL(for draftID: String) -> String {
            "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F\(draftID).jpg?alt=media&token="
        }
        
        private var anyUploading: Bool {
            drafts.contains { $0.isUploading }
        }

        private var hasUploadError: Bool {
            drafts.contains { $0.uploadError != nil }
        }

        /// true when every draft is "image-ready":
        /// - no image: ok
        /// - has image: must have finished upload (itemImageURL != nil) and no error
        private var imagesReady: Bool {
            drafts.allSatisfy { d in
                if d.image == nil {
                    return !d.isUploading && d.uploadError == nil
                } else {
                    return !d.isUploading && d.uploadError == nil && d.itemImageURL != nil
                }
            }
        }
        
        private func currentFocusedID() -> String? {
            switch focusedField {
            case .name(let id):        return id
            case .description(let id): return id
            default: return nil
            }
        }

        private func toggleFocusForCurrentDraft() {
            guard let id = currentFocusedID() else { return }
            switch focusedField {
            case .name:
                focusedField = .description(id)
            case .description:
                focusedField = .name(id)
            default:
                break
            }
        }

        private func openImageForFocusedDraft() {
            if let id = currentFocusedID(),
               let _ = drafts.firstIndex(where: { $0.id == id }) {
                activeDraftID = id
                backupImage = drafts.first(where: { $0.id == id })?.image
                showNewImageSheet = true
            }
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(drafts, id: \.id) { draft in
                            let draftID = draft.id
                            DraftCard(
                                draft: bindingForDraft(id: draftID),
                                title: "Blank Item #\((drafts.firstIndex(where: { $0.id == draftID }) ?? 0) + 1)",
                                subtitle: "tap to add image (optional)",
                                focusedField: $focusedField,
                                onTapImage: {
                                    activeDraftID = draftID
                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
                                    showNewImageSheet = true
                                },
                                onDelete: { removeDraft(id: draftID) },
                                onSubmitDescription: { id in
                                    if let i = drafts.firstIndex(where: { $0.id == id }) {
                                        let next = i + 1
                                        if next < drafts.count {
                                            focusedField = .name(drafts[next].id)
                                        } else if drafts.count < maxItems {
                                            let newDraft = BlankItemDraft()
                                            let newID = newDraft.id
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                drafts.append(newDraft)
                                            }
                                            DispatchQueue.main.async { focusedField = .name(newID) }
                                        } else {
                                            hideKeyboard()
                                        }
                                    }
                                }
                            )
                            .contextMenu {
                                Button {
                                    activeDraftID = draftID
                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
                                    showNewImageSheet = true
                                } label: { Label("Add Image", systemImage: "photo.fill") }

                                Button(role: .destructive) {
                                    removeDraft(id: draftID)
                                } label: { Label("Delete", systemImage: "trash") }

                                Button {
                                    if let idx = drafts.firstIndex(where: { $0.id == draftID }) {
                                        drafts[idx].description = ""
                                        drafts[idx].image = nil
                                        drafts[idx].name = ""
                                        if !isPlaceholderURL(drafts[idx].itemImageURL) {
                                            Task { await deleteStorageImage(rankoID: rankoID, itemID: draftID) }
                                        }
                                        DispatchQueue.main.async { focusedField = .name(draftID) }
                                    }
                                } label: { Label("Clear All", systemImage: "delete.right.fill") }
                            }
                        }
                        
                        Button {
                            let newDraft = BlankItemDraft()
                            let newID = newDraft.id
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                drafts.append(newDraft)
                            }
                            DispatchQueue.main.async { focusedField = .name(newID) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.custom("Nunito-Black", size: 20))
                                Text("ADD ANOTHER BLANK ITEM")
                                    .font(.custom("Nunito-Black", size: 16))
                                    .padding(.vertical, 2)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)                    // ← blue flavored
                        .disabled(!canAddMore)
                        .opacity(canAddMore ? 1 : 0.5)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button { openImageForFocusedDraft() } label: { Image(systemName: "photo.on.rectangle") }

                        Spacer(minLength: 36)

                        Button { toggleFocusForCurrentDraft() } label: { Image(systemName: "arrow.left.arrow.right") }

                        Spacer(minLength: 36)

                        Button { if let id = currentFocusedID() { focusedField = .name(id) } }
                               label: { Image(systemName: "textformat.size.larger") }
                           .disabled({ if case .name = focusedField { return true }; return false }())

                        Spacer(minLength: 36)

                        Button { if let id = currentFocusedID() { focusedField = .description(id) } }
                               label: { Image(systemName: "textformat.size.smaller") }
                           .disabled({ if case .description = focusedField { return true }; return false }())

                        Spacer() // push dismiss right

                        Button { hideKeyboard() } label: { Image(systemName: "keyboard.chevron.compact.down") }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Task {
                                isCleaningUp = true
                                // try to delete all uploaded personal images for current drafts
                                await deleteAllDraftImages()
                                isCleaningUp = false
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                if isCleaningUp {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                        }
                        .disabled(isCleaningUp || !imagesReady)
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Add New Blank Items")
                            .font(.custom("Nunito-Black", size: 20))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // validate names
                            let bad = drafts.first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            if bad != nil {
                                error = "please give every blank item a name (the * one)."
                                return
                            }
                            
                            // extra guard: images must be ready
                            guard imagesReady else {
                                error = hasUploadError
                                ? "fix image upload errors before saving."
                                : "please wait for images to finish uploading."
                                return
                            }
                            
                            // fill placeholder URL for any imageless drafts before commit
                            for i in drafts.indices where drafts[i].itemImageURL == nil {
                                drafts[i].itemImageURL = placeholderURL
                            }
                            error = nil
                            onCommit()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                // tiny spinner if anything is still uploading
                                if anyUploading {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                        }
                        .disabled(!imagesReady)   // ← hard lock until uploads are done & clean
                    }
                }
                .alert("upload error", isPresented: .init(
                    get: { drafts.contains { $0.uploadError != nil } },
                    set: { if !$0 { for i in drafts.indices { drafts[i].uploadError = nil } } }
                )) {
                    Button("ok", role: .cancel) {}
                } message: {
                    Text(drafts.first(where: { $0.uploadError != nil })?.uploadError ?? "unknown error")
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNewImageSheet) {
                NewImageSheet(pickFromLibrary: {
                    showNewImageSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPhotoPicker = true }
                })
                .presentationDetents([.fraction(0.4)])
                .presentationBackground(Color.white)
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
            }
            .fullScreenCover(isPresented: $showImageCropper) {
                if let img = imageForCropping {
                    SwiftyCropView(
                        imageToCrop: img,
                        maskShape: .square,
                        configuration: SwiftyCropConfiguration(
                            maxMagnificationScale: 8.0,
                            maskRadius: 190.0,
                            cropImageCircular: false,
                            rotateImage: false,
                            rotateImageWithButtons: true,
                            usesLiquidGlassDesign: true,
                            zoomSensitivity: 3.0
                        ),
                        onCancel: {
                            imageForCropping = nil
                            showImageCropper = false
                            restoreBackupForActiveDraft()
                        },
                        onComplete: { cropped in
                            imageForCropping = nil
                            showImageCropper = false
                            // 👇 immediately try to upload with timeout
                            if let id = activeDraftID { Task { await uploadCropped(cropped!, for: id) } }
                        }
                    )
                }
            }
            .onChange(of: imageForCropping) { _, newVal in
                if newVal != nil { showImageCropper = true }
            }
        }
        
        // Safely produce a Binding<BlankItemDraft> by id.
        // If the draft got removed, the getter returns a harmless placeholder (so SwiftUI won’t crash during transition).
        private func bindingForDraft(id: String) -> Binding<BlankItemDraft> {
            Binding(
                get: {
                    drafts.first(where: { $0.id == id }) ?? BlankItemDraft()
                },
                set: { updated in
                    if let idx = drafts.firstIndex(where: { $0.id == id }) {
                        drafts[idx] = updated
                    }
                }
            )
        }

        // Centralized, index-safe removal with focus + cleanup + animation.
        private func removeDraft(id: String) {
            guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
            let draft = drafts[idx]

            // try to delete uploaded image if it’s not a placeholder
            if !isPlaceholderURL(draft.itemImageURL) {
                Task { await deleteStorageImage(rankoID: rankoID, itemID: id) }
            }

            // compute a sensible neighbor BEFORE mutation
            let nextFocusID: String? = {
                if drafts.count <= 1 { return nil }
                let neighborIndex = idx == drafts.count - 1 ? idx - 1 : idx + 1
                return drafts[neighborIndex].id
            }()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                drafts.remove(at: idx)
                if drafts.isEmpty { drafts.append(BlankItemDraft()) }
            }

            // restore focus after the view updates
            DispatchQueue.main.async {
                if let nid = nextFocusID, drafts.contains(where: { $0.id == nid }) {
                    focusedField = .name(nid)
                } else if let firstID = drafts.first?.id {
                    focusedField = .name(firstID)
                }
            }

            print("deleting itemID: \(id)")
        }
        
        private func makeJPEGMetadata(rankoID: String, itemID: String, userID: String) -> StorageMetadata {
            let md = StorageMetadata()
            md.contentType = "image/jpeg"

            // add some useful tags like your profile code does (timestamp, owner, etc.)
            let now = Date()
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(identifier: "Australia/Sydney") // AEST/AEDT
            fmt.dateFormat = "yyyyMMddHHmmss"
            let ts = fmt.string(from: now)

            md.customMetadata = [
                "rankoID": rankoID,
                "itemID": itemID,
                "userID": userID,
                "uploadedAt": ts
            ]
            return md
        }

        // MARK: - Upload w/ 10s timeout

        private func uploadCropped(_ img: UIImage, for draftID: String) async {
            guard let data = img.jpegData(compressionQuality: 0.9) else {
                setUpload(error: "couldn't encode image", for: draftID); return
            }
            setUploading(true, for: draftID)

            let path = "rankoPersonalImages/\(rankoID)/\(draftID).jpg"
            let ref  = Storage.storage().reference().child(path)
            let metadata = makeJPEGMetadata(rankoID: rankoID, itemID: draftID, userID: user_data.userID)

            do {
                try await withTimeout(seconds: 10) {
                    _ = try await ref.putDataAsync(data, metadata: metadata)  // 👈 pass metadata
                }

                // success → set image + deterministic URL string (your requested format)
                setUploadSuccess(image: img, url: finalURL(for: draftID), for: draftID)
                print("image uploaded successfully for itemID: \(draftID)")

                // (optional) also mirror a tiny index in Realtime DB like your profile fn:
                // try? await setValueAsync(
                //   Database.database().reference()
                //     .child("RankoData").child(rankoID)
                //     .child("RankoItemImages").child(draftID),
                //   value: ["path": path, "modified": metadata.customMetadata?["uploadedAt"] ?? ""]
                // )

            } catch {
                let msg: String
                if error is TimeoutErr { msg = "upload timed out, please try again." }
                else { msg = (error as NSError).localizedDescription }
                setUpload(error: msg, for: draftID)
            }
        }

        private enum TimeoutErr: Error { case timedOut }
        private func withTimeout<T>(seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await op() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw TimeoutErr.timedOut
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }

        // MARK: - Draft mutations

        private func setUploading(_ uploading: Bool, for id: String) {
            if let i = drafts.firstIndex(where: { $0.id == id }) {
                drafts[i].isUploading = uploading
                drafts[i].uploadError = nil
            }
        }
        private func setUploadSuccess(image: UIImage, url: String, for id: String) {
            if let i = drafts.firstIndex(where: { $0.id == id }) {
                drafts[i].image = image
                drafts[i].itemImageURL = url
                drafts[i].isUploading = false
                drafts[i].uploadError = nil
            }
        }
        private func setUpload(error: String, for id: String) {
            if let i = drafts.firstIndex(where: { $0.id == id }) {
                drafts[i].isUploading = false
                drafts[i].uploadError = error
            }
        }

        private func restoreBackupForActiveDraft() {
            guard let id = activeDraftID, let backup = backupImage,
                  let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
            drafts[idx].image = backup
        }
        
        private func deleteAllDraftImages() async {
            // collect every draft that has a *non-placeholder* uploaded URL
            let targets = drafts
                .filter { !isPlaceholderURL($0.itemImageURL) }
                .map { $0.id }

            guard !targets.isEmpty else { return }

            // delete all in parallel but don't hang forever
            do {
                try await withTimeout(seconds: 10) {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for id in targets {
                            group.addTask {
                                await deleteStorageImage(rankoID: rankoID, itemID: id)
                            }
                        }
                        // wait (errors are already caught inside deleteStorageImage; it never throws)
                        try await group.waitForAll()
                    }
                }
            } catch {
                // optional: you could surface a toast here if you want
                #if DEBUG
                print("⚠️ cleanup timeout/err: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // one draft card UI
    private struct DraftCard: View {
        @Binding var draft: BlankItemDraft
        let title: String
        let subtitle: String
        let focusedField: FocusState<BlankItemsComposer.Field?>.Binding   // ✅ accept focus binding
        var onTapImage: () -> Void
        var onDelete: () -> Void
        var onSubmitDescription: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title.uppercased())
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if draft.isUploading { ProgressView().controlSize(.small) }
                }
                
                HStack {
                    Spacer(minLength: 0)
                    Button(action: onTapImage) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.gray.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                )
                                .frame(width: 240, height: 240)
                            
                            if let img = draft.image {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 240, alignment: .center)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .contentShape(Rectangle())
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 28, weight: .black))
                                        .opacity(0.35)
                                    Text(subtitle.uppercased())
                                        .font(.custom("Nunito-Black", size: 13))
                                        .opacity(0.6)
                                }
                                .frame(width: 240, height: 240, alignment: .center)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.isUploading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 14) {
                    // NAME
                    VStack(spacing: 5) {
                        HStack {
                            Text("Item Name".uppercased())
                                .foregroundColor(.secondary)
                                .font(.custom("Nunito-Black", size: 12))
                            Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 6)

                        HStack(spacing: 6) {
                            Image(systemName: "textformat.size.larger").foregroundColor(.gray).padding(.trailing, 1)
                            TextField("Item Name *", text: $draft.name)
                                .font(.custom("Nunito-Black", size: 18))
                                .autocorrectionDisabled(true)
                                .onChange(of: draft.name) { _, v in
                                    if v.count > 50 { draft.name = String(v.prefix(50)) }
                                }
                                .foregroundStyle(.gray)
                                .focused(focusedField, equals: .name(draft.id))
                                .submitLabel(.next)
                                .onSubmit { focusedField.wrappedValue = .description(draft.id) }

                            Spacer()
                            Text("\(draft.name.count)/50")
                                .font(.caption2).fontWeight(.light)
                                .padding(.top, 15).foregroundColor(.secondary)
                        }
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundColor(Color.gray.opacity(0.08))
                                .allowsHitTesting(false)
                        )
                    }

                    // DESCRIPTION
                    VStack(spacing: 5) {
                        HStack {
                            Text("Description".uppercased())
                                .foregroundColor(.secondary)
                                .font(.custom("Nunito-Black", size: 12))
                                .padding(.leading, 6)
                            Spacer(minLength: 0)
                        }

                        HStack {
                            Image(systemName: "textformat.size.smaller").foregroundColor(.gray).padding(.trailing, 1)
                            TextField("Item Description (optional)", text: $draft.description, axis: .vertical)
                                .font(.custom("Nunito-Black", size: 18))
                                .autocorrectionDisabled(true)
                                .onChange(of: draft.description) { _, v in
                                    if v.count > 100 { draft.description = String(v.prefix(100)) }
                                }
                                .foregroundStyle(.gray)
                                .focused(focusedField, equals: .description(draft.id))  // ✅ use binding
                                .submitLabel(.next)
                                .onSubmit { onSubmitDescription(draft.id) }
                                .onChange(of: draft.description) { _, v in
                                    if v.contains("\n") {
                                        onSubmitDescription(draft.id)
                                        draft.description = v.replacingOccurrences(of: "\n", with: "")
                                    }
                                }

                            Spacer()
                            Text("\(draft.description.count)/100")
                                .font(.caption2).fontWeight(.light)
                                .padding(.top, 15).foregroundColor(.secondary)
                        }
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundColor(Color.gray.opacity(0.08))
                                .allowsHitTesting(false)
                        )
                    }
                }

                HStack {
                    if let err = draft.uploadError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: onDelete) {
                        HStack {
                            Image(systemName: "trash.fill").font(.system(size: 13, weight: .semibold))
                            Text("DELETE").font(.custom("Nunito-Black", size: 13))
                        }
                    }
                    .buttonStyle(.borderless)
                    .tint(.red)
                    .foregroundStyle(.red)      // ensure it's red even in borderless
                    .disabled(draft.isUploading)
                    .opacity(draft.isUploading ? 0.5 : 1)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func deleteTierRow(at index: Int) {
        guard groupedItems.indices.contains(index) else { return }
        // only allow delete if the row is empty
        guard groupedItems[index].isEmpty else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            groupedItems.remove(at: index)
            if tiers.indices.contains(index) {
                tiers.remove(at: index)
            }
            // keep hoveredRow sane
            if let h = hoveredRow, h >= groupedItems.count { hoveredRow = groupedItems.indices.last }
        }
    }

    // “photos” bottom sheet like your EditProfileView
    private struct NewImageSheet: View {
        var pickFromLibrary: () -> Void
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Photos").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button(action: pickFromLibrary) {
                            Text("Show Photo Library")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x0288FE))
                        }
                    }
                    .padding(.horizontal, 24)

                    // simple row buttons (camera/files hooks left for you if needed)
                    Divider().padding(.horizontal, 24)
                    Button(action: pickFromLibrary) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                            Text("Photo Library")
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                            Text("Files")
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 18)
            }
        }
    }
    
    private enum PublishErr: LocalizedError {
        case missingCategory
        case invalidUserID

        var errorDescription: String? {
            switch self {
            case .missingCategory: return "Please pick a category before saving."
            case .invalidUserID:   return "Invalid user ID. Please sign in again."
            }
        }
    }
    
    private func openBlankComposer() {
        blankDrafts = [BlankItemDraft()]   // ← always fresh
        draftError = nil
        showBlankItemsFS = true
    }
    
    @ViewBuilder
    private func pill(_ title: String, system: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system).font(.system(size: 12, weight: .semibold))
                Text(title).font(.custom("Nunito-Black", size: 12)).kerning(-0.2)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E).opacity(0.25))
            )
            .foregroundStyle(isOn ? .white : Color(hex: 0x6D400F))
        }
        .buttonStyle(.plain)
    }
    
    private func uploadPersonalImagesAsync() async throws {
        guard !pendingPersonalImages.isEmpty else { return }

        let storage = Storage.storage()
        let bucketPathRoot = "rankoPersonalImages/\(rankoID)" // use your rankoID as rankoID

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (itemID, image) in pendingPersonalImages {
                group.addTask {
                    let ref = storage.reference().child("\(bucketPathRoot)/\(itemID).jpg")
                    guard let data = image.jpegData(compressionQuality: 0.9) else {
                        throw PublishErr.invalidUserID // reusing an error; you can add a dedicated one
                    }
                    _ = try await ref.putDataAsync(data, metadata: nil)
                }
            }
            try await group.waitForAll()
        }
    }
    
    private func deleteRankoPersonalFolderAsync(rankoID: String) async {
        let root = Storage.storage().reference()
            .child("rankoPersonalImages")
            .child(rankoID)
        await deleteAllRecursively(at: root)
    }

    private func deleteAllRecursively(at ref: StorageReference) async {
        do {
            let list = try await ref.listAll()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in list.items {
                    group.addTask {
                        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                            item.delete { err in
                                if let err = err { cont.resume(throwing: err) }
                                else { cont.resume() }
                            }
                        }
                    }
                }
                for prefix in list.prefixes {
                    group.addTask { await deleteAllRecursively(at: prefix) }
                }
                try await group.waitForAll()
            }
            // Folders aren't real objects; deleting ref is typically a no-op, ignore errors.
            _ = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ref.delete { _ in cont.resume() }
            }
        } catch {
            #if DEBUG
            print("⚠️ failed to purge \(ref.fullPath): \(error.localizedDescription)")
            #endif
        }
    }
    
    private func appendDraftsToSelectedRanko() {
        let placeholderURL = "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
        var nextRank = (unGroupedItems.map(\.rank).max() ?? 0) + 1

        print("🔍 Starting append: unGroupedItems.count = \(unGroupedItems.count)")
        print("🔍 blankDrafts.count = \(blankDrafts.count)")

        for draft in blankDrafts {
            // Generate a unique 12-character ID for this item
            let itemID = randomString(length: 12)
            
            // Use the uploaded URL if available, otherwise use placeholder
            let imageURL = draft.itemImageURL ?? placeholderURL

            // Create the RankoRecord
            let rec = RankoRecord(
                objectID: itemID,
                ItemName: draft.name,
                ItemDescription: draft.description,
                ItemCategory: "",
                ItemImage: imageURL,
                ItemGIF: draft.gif.isEmpty ? nil : draft.gif,
                ItemVideo: draft.video.isEmpty ? nil : draft.video,
                ItemAudio: draft.audio.isEmpty ? nil : draft.audio
            )
            
            // Create the RankoItem
            let item = RankoItem(
                id: itemID,
                rank: nextRank,
                votes: 0,
                record: rec,
                playCount: 0
            )
            
            print("✅ Adding item: \(item.itemName) (ID: \(itemID))")
            unGroupedItems.append(item)
            nextRank += 1
        }

        print("🔍 After append: unGroupedItems.count = \(unGroupedItems.count)")

        // Reset the drafts
        blankDrafts = [BlankItemDraft()]
        draftError = nil
    }
    
    // MARK: - EMBEDDED STICKY POOL
    private var embeddedStickyPoolView: some View {
        VStack(spacing: 8) {
            // Header with item count and close button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: 0x6D400F))
                    
                    Text("Item Pool")
                        .font(.custom("Nunito-Black", size: 14))
                        .foregroundColor(Color(hex: 0x6D400F))
                    
                    Text("(\(unGroupedItems.count))")
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        showEmbeddedStickyPoolSheet = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Instructions
            Text(showSelectionBar
                 ? "Selection active — dragging is disabled"
                 : "Drag items below to add them to tiers")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            // Items scroll view
            if unGroupedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No items in pool")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(unGroupedItems) { item in
                            TierItemCell(
                                item: item,
                                contentDisplay: .textAndImage,
                                itemSize: .small,
                                showSelectionBar: false,
                                isSelected: false,
                                onSelect: { _ in }
                            )
                            .modifier(DragIfEnabled(enabled: !showSelectionBar, id: item.id))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .modifier(StickyPoolDropModifier(
            enabled: !showSelectionBar,
            itemRows: $groupedItems,
            unGrouped: $unGroupedItems,
            hoveredRow: $hoveredRow
        ))
    }

    // Helper: conditionally attach onDrag
    private struct DragIfEnabled: ViewModifier {
        let enabled: Bool
        let id: String
        func body(content: Content) -> some View {
            if enabled {
                content.onDrag { NSItemProvider(object: id as NSString) }
            } else {
                content
            }
        }
    }

    // Helper: conditionally attach onDrop (from earlier message)
    private struct StickyPoolDropModifier: ViewModifier {
        let enabled: Bool
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGrouped: [RankoItem]
        @Binding var hoveredRow: Int?

        func body(content: Content) -> some View {
            if enabled {
                content.onDrop(
                    of: ["public.text"],
                    delegate: RowDropDelegate(
                        itemRows:   $itemRows,
                        unGrouped:  $unGrouped,
                        hoveredRow: $hoveredRow,
                        targetRow:  nil
                    )
                )
            } else {
                content
            }
        }
    }
    
    @MainActor
    private func startPublishAndDismiss() {
        guard categoryName != "" else {
            publishError = "Please pick a category before saving."
            return
        }
        progressLoading = true
        Task {
            do {
                try await publishRanko()
                progressLoading = false
                dismiss()
            } catch {
                progressLoading = false
                publishError = error.localizedDescription
            }
        }
    }
    
    func normalizeHexString(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        if s.hasPrefix("#") { s.removeFirst() }
        // keep only hex digits
        s = s.filter { "0123456789abcdefABCDEF".contains($0) }
        guard let intVal = UInt32(s, radix: 16) else { return "0x446D7A" }
        return String(format: "0x%06X", intVal)
    }
    
    private func publishRanko() async throws {
        // 1) upload all personal images first (hard gate)
        try await uploadPersonalImagesAsync()

        // 2) now that uploads succeeded, rewrite ItemImage URLs for the affected items
        let urlBase = "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F"

        for rowIdx in groupedItems.indices {
            for itemIdx in groupedItems[rowIdx].indices {
                let item = groupedItems[rowIdx][itemIdx]
                let itemID = item.id
                guard pendingPersonalImages[itemID] != nil else { continue }

                let newURL = "\(urlBase)\(itemID).jpg?alt=media&token="
                let updatedRecord = item.record.withItemImage(newURL)
                let updatedItem = item.withRecord(updatedRecord)
                groupedItems[rowIdx][itemIdx] = updatedItem
            }
        }

        // 3) proceed with both saves
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await saveRankedListToAlgoliaAsync() }
            group.addTask { try await saveRankedListToFirebaseAsync() }
            try await group.waitForAll()
        }

        // 4) clear cache on success
        pendingPersonalImages.removeAll()
    }
    
    func saveRankedListToAlgoliaAsync() async throws {
        guard categoryName != "" else {
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
            RankoCategory:    categoryName,
            RankoUserID:      user_data.userID,
            RankoCreated:    rankoDateTime,
            RankoUpdated:    rankoDateTime,
            RankoLikes:       0,
            RankoComments:    0,
            RankoVotes:       0
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            listsIndex.saveObject(listRecord) { result in
                switch result {
                case .success:
                    cont.resume()
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }

    @MainActor
    func saveRankedListToFirebaseAsync() async throws {
        // 1) Must have a category
        guard categoryName != "" else {
            print("❌ Cannot save: no category selected")
            return
        }

        let db = Database.database().reference()

        // 2) Build items with decimal ranks + tier linkage
        var rankoItemsDict: [String: Any] = [:]

        for (rowIdx, row) in groupedItems.enumerated() {
            let rowNumber = rowIdx + 1
            _ = tierConfigForRow(rowIdx)

            for (posIdx, item) in row.enumerated() {
                let position = posIdx + 1
                let rankDouble = decimalRank(rowNumber: rowNumber, position: position)

                // unique key per item node in RankoItems
                let itemID = UUID().uuidString

                rankoItemsDict[itemID] = [
                    "ItemID":          itemID,
                    "ItemName":        item.itemName,
                    "ItemDescription": item.itemDescription,
                    "ItemImage":       item.itemImage,

                    // 👇 NEW: decimal rank format
                    "ItemRank":        rankDouble,       // Double: 1.0001, 4.0012, …

                    "ItemVotes":       0,

                    // keep your extra media/stat fields
                    "ItemGIF":         item.itemGIF,
                    "ItemVideo":       item.itemVideo,
                    "ItemAudio":       item.itemAudio,
                    "PlayCount":       item.playCount
                ]
            }
        }

        // 3) Timestamps
        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)

        // 4) Category object (use your existing normalizer)
        let categoryDict: [String: Any] = [
            "colour": String(categoryColour),
            "icon":   categoryIcon,
            "name":   categoryName
        ]

        // 5) Details / Privacy / Stats
        let normalizedTags: [String] = tags.isEmpty ? ["ranko", categoryName.lowercased()] : tags

        let rankoDetails: [String: Any] = [
            "id":          rankoID,
            "name":        rankoName,
            "description": description,
            "type":        "tier",
            "user_id":     user_data.userID,
            "tags":        normalizedTags,
            "region":      "AUS",
            "language":    "en",
            "downloaded":  true
        ]

        let rankoPrivacy: [String: Any] = [
            "private":   isPrivate,
            "cloneable": true,
            "comments":  true,
            "likes":     true,
            "shares":    true,
            "saves":     true,
            "status":    "active"
        ]

        let rankoStats: [String: Any] = [
            "views":  0,
            "saves":  0,
            "shares": 0,
            "clones": 0
        ]

        // 6) NEW: tiers block
        let rankoTiers = tiersPayload(from: tiers)

        // 7) Full payload (single write shape)
        let payload: [String: Any] = [
            // blocks shaped like your sample schema
            "RankoDetails":      rankoDetails,
            "RankoCategory":     categoryDict,
            "RankoPrivacy":   rankoPrivacy,
            "RankoStatistics":   rankoStats,
            "RankoDateTime":     ["updated": rankoDateTime, "created": rankoDateTime],
            "RankoTiers":        rankoTiers,
            "RankoItems":        rankoItemsDict,

            // init empty maps
            "RankoLikes":        [:],
            "RankoComments":     [:]
        ]

        // 8) Write the Ranko and mirror under the user (async/await)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await db.child("RankoData")
                            .child(self.rankoID)
                            .setValueAsync(payload)
            }
            group.addTask {
                try await db.child("UserData")
                            .child(self.user_data.userID)
                            .child("UserRankos")
                            .child("UserActiveRankos")
                            .child(self.rankoID)
                            .setValueAsync(categoryName)
            }
            try await group.waitForAll()
        }

        print("✅ List saved with decimal ranks + tier metadata")
    }
    
    
    // Wrap Firebase setValue into async/await
    private func setValueAsync(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { err, _ in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
    }
    
    private func tiersPayload(from tiers: [TierConfig]) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (idx, t) in tiers.enumerated() {
            let rowNumber = idx + 1
            dict["\(rowNumber)"] = [
                "Index":    rowNumber,
                "Code":     t.code,
                "Label":    t.label,
                "ColorHex": t.colorHex
            ]
        }
        return dict
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
    
    struct TierItemCell: View {
        let item: RankoItem
        let contentDisplay: ContentDisplay
        let itemSize: ItemSize
        let showSelectionBar: Bool
        let isSelected: Bool
        let onSelect: (String) -> Void

        private var isVertical: Bool { itemSize == .large }

        var body: some View {
            HStack(spacing: 10) {
                // ✅ Checkbox (only in selection mode)
                if showSelectionBar {
                    Button {
                        onSelect(item.id)
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isSelected ? Color(hex: 0x2ECC71) : Color(hex: 0xC8C8C8))
                            .contentTransition(.symbolEffect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSelected ? "Deselect item" : "Select item")
                    .accessibilityHint(item.itemName)
                    .transition(.scale.combined(with: .opacity))
                }

                // Content
                Group {
                    if isVertical {
                        VStack(spacing: 10) {
                            imageView
                            textStack
                        }
                    } else {
                        HStack(spacing: 8) {
                            imageView
                            textStack
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(radius: 1)
            )
            // Tap anywhere to toggle when selecting
            .contentShape(Rectangle())
            .onTapGesture {
                if showSelectionBar { onSelect(item.id) }
            }
        }

        @ViewBuilder
        private var imageView: some View {
            if contentDisplay != .textOnly {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    switch phase {
                    case .empty:  Color.gray.opacity(0.15)
                    case .failure: Color.gray.opacity(0.25)
                    case .success(let img): img.resizable().scaledToFill()
                    @unknown default: Color.gray.opacity(0.15)
                    }
                }
                .frame(width: itemSize.thumb, height: itemSize.thumb)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }

        @ViewBuilder
        private var textStack: some View {
            if contentDisplay != .imageOnly {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemName)
                        .font(.custom("Nunito-Black", size: itemSize.nameFont))
                        .lineLimit(1)
                    if !item.itemDescription.isEmpty {
                        Text(item.itemDescription)
                            .font(.custom("Nunito-Black", size: itemSize.descFont))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 60, alignment: .leading)
            }
        }
    }
    
    struct TierRow: View {
        // 🔁 selection
        let selectionOn: Bool
        let selectedIDs: Set<String>
        let onToggleSelect: (String) -> Void

        let rowIndex: Int
        let tier: TierConfig
        let items: [RankoItem]
        
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        let layout: RowLayout
        let contentDisplay: ContentDisplay
        let itemSize: ItemSize
        var onEditTiers: () -> Void = {}
        var canDelete: Bool = false
        var onDeleteTier: (Int) -> Void = { _ in }

        var body: some View {
            ZStack {
                switch layout {
                case .noWrap:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSize == .large ? 8 : 4) {
                            Rectangle()
                                .fill(Color(.clear))
                                .frame(width: 75)
                            ForEach(items) { item in
                                cell(for: item)
                            }
                        }
                        .padding(8)
                    }
                case .wrap:
                    HStack {
                        Rectangle()
                            .fill(Color(.clear))
                            .frame(width: 75)
                        FlowLayout2(spacing: itemSize == .large ? 8 : 6) {
                            ForEach(items) { item in
                                cell(for: item)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                }
                
                HStack {
                    TierHeader(tier: tier)
                        .opacity(0.8)
                        .contextMenu {
                            Button { onEditTiers() } label: {
                                Label("Edit Tiers…", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                onDeleteTier(rowIndex)
                            } label: {
                                Label(canDelete ? "Delete Tier" : "Delete Tier (empty only)", systemImage: "trash")
                            }
                            .disabled(!canDelete)
                        }
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFFFFF)).shadow(radius: 2)
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            // Disable drop when selecting to avoid conflict
            .modifier(RowDropIfEnabled(
                enabled: !selectionOn,
                itemRows: $itemRows,
                unGrouped: $unGroupedItems,
                hoveredRow: $hoveredRow,
                targetRow: rowIndex
            ))
        }

        // MARK: - Cell factory uses injected selection state
        @ViewBuilder
        private func cell(for item: RankoItem) -> some View {
            if selectionOn {
                TierItemCell(
                    item: item,
                    contentDisplay: contentDisplay,
                    itemSize: itemSize,
                    showSelectionBar: true,
                    isSelected: selectedIDs.contains(item.id),
                    onSelect: { id in onToggleSelect(id) }
                )
                .onTapGesture { onToggleSelect(item.id) }
            } else {
                TierItemCell(
                    item: item,
                    contentDisplay: contentDisplay,
                    itemSize: itemSize,
                    showSelectionBar: false,
                    isSelected: false,
                    onSelect: { _ in }
                )
                .onDrag { NSItemProvider(object: item.id as NSString) }
                .onTapGesture { selectedDetailItem = item }
            }
        }

        @ViewBuilder private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }

    // Conditionally attach onDrop
    private struct RowDropIfEnabled: ViewModifier {
        let enabled: Bool
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGrouped: [RankoItem]
        @Binding var hoveredRow: Int?
        let targetRow: Int

        func body(content: Content) -> some View {
            if enabled {
                content.onDrop(
                    of: ["public.text"],
                    delegate: RowDropDelegate(itemRows: $itemRows,
                                              unGrouped: $unGrouped,
                                              hoveredRow: $hoveredRow,
                                              targetRow: targetRow)
                )
            } else {
                content
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
    
    struct VerticalDropdownPicker<T: OrderedKnob>: View where T.AllCases == [T] {
        @Binding var selection: T
        @State private var isExpanded = false

        let title: (T) -> String
        let systemIcon: (T) -> String
        let accent: Color

        private var order: [T] { T.ordered }

        private var above: [T] {
            guard let idx = order.firstIndex(of: selection) else { return [] }
            return Array(order.prefix(idx).reversed())
        }
        private var below: [T] {
            guard let idx = order.firstIndex(of: selection) else { return [] }
            return Array(order.suffix(from: idx + 1))
        }

        var body: some View {
            VStack(spacing: 6) {
                if isExpanded {
                    ForEach(above, id: \.self) { option in
                        optionButton(option, subtle: true) { selection = option; isExpanded = false }
                    }
                }
                optionButton(selection, subtle: false) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { isExpanded.toggle() }
                }
                if isExpanded {
                    ForEach(below, id: \.self) { option in
                        optionButton(option, subtle: true) { selection = option; isExpanded = false }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isExpanded)
        }

        @ViewBuilder
        private func optionButton(_ option: T, subtle: Bool, _ action: @escaping () -> Void) -> some View {
            Button {
                withAnimation {
                    action()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: systemIcon(option))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text(title(option)).font(.custom("Nunito-Black", size: 12)).kerning(-0.2)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(minWidth: 96)
                .background(Capsule(style: .continuous).fill(subtle ? Color(hex: 0x292A30).opacity(0.12) : Color(hex: 0x292A30)))
                .foregroundStyle(subtle ? Color(hex: 0x292A30) : .white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .transition(.move(edge: subtle ? .bottom : .top).combined(with: .opacity))
        }
    }
    
    private let tierLetters: [String] =
        ["S","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S2","T","U","V","W","X","Y","Z"]

    private let tierLabels: [String] = [
        "Legendary","Excellent","Solid","Average","Weak","Poor","Useless",
        "Decent","Okay","Meh","Flawed","Bad","Trash","Low","Bottom",
        "Minor","Subpar","Rough","Edge","Spare","Under","Vague","Weary","Worn","Xtra","Yield","Zero"
    ]

    // A palette that spans warm→cool; first 7 match your A–F mapping, rest are pleasant sweep
    private let tierColorsHex: [Int] = [
        0xC44536, 0xBF7B2F, 0xBFA254, 0x4DA35A, 0x3F7F74, 0x3F63A7, 0x6C46B3,
        0xA24A3A, 0xA46C33, 0xA89060, 0x3F9251, 0x3A6F69, 0x365A95, 0x5C45A6,
        0x8F3F33, 0x945F2E, 0x9F8458, 0x368647, 0x316B62, 0x2F568A, 0x523F98,
        0x7E362B, 0x86572A, 0x927C52, 0x2F7940, 0x2A6158, 0x274E80, 0x47388C
    ]

    private func defaultTierForPosition(_ idx: Int) -> TierConfig {
        // Guarantee enough entries by clamping
        let i = min(idx, tierLetters.count - 1)
        var code  = tierLetters[i]
        var label = tierLabels[i]
        var hex   = tierColorsHex[i]

        // Special case you asked for: TIER #3 (index 2) is B / Solid / 0xBFA254
        if idx == 2 {
            code = "B"; label = "Solid"; hex = 0xBFA254
        }
        return TierConfig(code: code, label: label, colorHex: hex)
    }

    // Safely map a row index to a tier (clamps to F if there are more than 7 rows)
    private func tierForRow(_ i: Int) -> Tier {
        if i >= 0 && i < Tier.allCases.count { return Tier.allCases[i] }
        return .f
    }
}

private let placeholderItemURL =
  "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="

@inline(__always)
private func isPlaceholderURL(_ url: String?) -> Bool {
    guard let url = url else { return true }
    return url.contains("/placeholderImages%2FitemPlaceholder.png")
}

@inline(__always)
private func personalImagePath(rankoID: String, itemID: String) -> String {
    "rankoPersonalImages/\(rankoID)/\(itemID).jpg"
}

private func deleteStorageImage(rankoID: String, itemID: String) async {
    let ref = Storage.storage().reference().child(personalImagePath(rankoID: rankoID, itemID: itemID))
    do {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.delete { err in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
        #if DEBUG
        print("✅ deleted storage image for \(itemID)")
        #endif
    } catch {
        // swallow errors (file may not exist, race with upload, etc.)
        #if DEBUG
        print("⚠️ delete failed for \(itemID): \(error.localizedDescription)")
        #endif
    }
}

// already used for upload timeout — reuse for cleanup too
private enum TimeoutErr: Error { case timedOut }
private func withTimeout<T>(seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutErr.timedOut
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private extension UUID {
    var string: String { uuidString }
}

private extension StorageReference {
    func putDataAsync(_ data: Data, metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { cont in
            self.putData(data, metadata: metadata) { meta, err in
                if let err = err { cont.resume(throwing: err) }
                else { cont.resume(returning: meta ?? StorageMetadata()) }
            }
        }
    }
}

// helpers — keeps your code tidy
private extension RankoRecord {
    func withItemImage(_ url: String) -> RankoRecord {
        RankoRecord(
            objectID: objectID,
            ItemName: ItemName,
            ItemDescription: ItemDescription,
            ItemCategory: ItemCategory,
            ItemImage: url,
            ItemGIF: ItemGIF,
            ItemVideo: ItemVideo,
            ItemAudio: ItemAudio
        )
    }
}

private extension RankoItem {
    func withRecord(_ newRecord: RankoRecord) -> RankoItem {
        RankoItem(
            id: id,
            rank: rank,
            votes: votes,
            record: newRecord,
            playCount: playCount
        )
    }
}

