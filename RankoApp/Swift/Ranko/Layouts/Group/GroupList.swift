//
//  GroupList.swift
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

    /// Use this for first-open in GroupListView so you start with exactly N tiers.
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
struct GroupListView: View {
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
    @State private var category: SampleCategoryChip?
    @State private var tags: [String] = []
    
    // Sheet states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var showEmbeddedStickyPoolSheet = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    
    @State private var addButtonTapped: Bool = false
    @State private var editButtonTapped: Bool = false
    @State private var rankButtonTapped: Bool = false
    @State private var exitButtonTapped: Bool = false
    
    @State private var addHoldButton: Bool = false
    @State private var editHoldButton: Bool = false
    @State private var rankHoldButton: Bool = false
    @State private var exitHoldButton: Bool = false
    
    @State private var exitButtonTranslation: CGSize = .zero
    @State private var exitButtonsTranslation: CGSize = .zero
    @State private var saveButtonHovered: Bool = false
    @State private var deleteButtonHovered: Bool = false
    @State private var exitButtonPosition: CGSize = .zero
    @State private var saveButtonPosition: CGSize = .zero
    @State private var deleteButtonPosition: CGSize = .zero
    
    @State private var addFrame: CGRect = .zero
    @State private var sampleFrame: CGRect = .zero
    @State private var blankFrame: CGRect = .zero
    
    @State private var addButtonTranslation: CGSize = .zero
    @State private var addButtonsTranslation: CGSize = .zero
    
    @State private var sampleButtonHovered: Bool = false
    @State private var blankButtonHovered: Bool = false
    
    @State private var exitFrame: CGRect = .zero
    @State private var saveFrame: CGRect = .zero
    @State private var deleteFrame: CGRect = .zero
    
    // Blank Items composer
    @State private var showBlankItemsFS = false
    @State private var blankDrafts: [BlankItemDraft] = [BlankItemDraft()] // start with 1
    @State private var draftError: String? = nil
    @Namespace private var transition
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [RankoItem] = []
    @State private var groupedItems: [[RankoItem]]
    @State private var selectedDetailItem: RankoItem? = nil
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
    @State private var activeTab: GroupListTab = .addItems
    
    @State private var tiers: [TierConfig] = TierConfig.starter(3)
    @State private var stagingTiers: [TierConfig] = []   // ← working copy for the sheet
    @State private var showTierEditor = false
    
    @State private var progressLoading: Bool = false       // ← shows the loader
    @State private var publishError: String? = nil         // ← error messaging
    
    // Replace your old enum-based helper with this:
    private func tierConfigForRow(_ i: Int) -> TierConfig {
        if tiers.isEmpty { return TierConfig.defaultForPosition(0) } // ← S-tier
        let idx = max(0, min(i, tiers.count - 1))
        return tiers[idx]
    }
    
    // hold personal images picked for new items -> uploaded on publish
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
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
    
    enum WrapMode: String, CaseIterable { case wrap, noWrap }
    
    private struct RankoToolbarTitleStack: View {
        let name: String
        let description: String
        @Binding var isPrivate: Bool
        let category: SampleCategoryChip?
        let categoryColor: Color
        @Binding var showEditDetailsSheet: Bool
        var onTapPrivacy: (() -> Void)?
        var onTapCategory: (() -> Void)?
        
        @AppStorage("group_wrap_mode")    private var wrapMode: RowLayout = .wrap
        @AppStorage("group_content_mode") private var contentMode: ContentDisplay = .textAndImage
        @AppStorage("group_size_mode")    private var sizeMode: ItemSize = .medium
        
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
                    
                    if let cat = category {
                        Button {
                            if let onTapCategory { onTapCategory() } else { showEditDetailsSheet = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11, weight: .black))
                                Text(cat.name)
                                    .font(.custom("Nunito-Black", size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(categoryColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .padding(.top, 5)
                .padding(.leading, 20)
            }
            .contextMenu {
                Button {} label: { Label("Edit Details", systemImage: "pencil") }
                Divider()
                Button {} label: { Label("Re-Rank Items", systemImage: "chevron.up.chevron.down") }
                Divider()
                Button(role: .destructive) {} label: { Label("Delete Ranko", systemImage: "trash") }
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
                                        GroupRow(
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: .wrap,                    // wrap/noWrap allowed even on large
                                            contentDisplay: contentMode,
                                            itemSize: .large,
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
                            
                        } else if wrapMode == .wrap {
                            // wrap = FlowLayout
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 12) {
                                    ForEach(groupedItems.indices, id: \.self) { i in
                                        GroupRow(
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: .wrap,
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
                                        GroupRow(
                                            rowIndex: i,
                                            tier: tierConfigForRow(i),
                                            items: groupedItems[i],
                                            itemRows: $groupedItems,
                                            unGroupedItems: $unGroupedItems,
                                            hoveredRow: $hoveredRow,
                                            selectedDetailItem: $selectedDetailItem,
                                            layout: .noWrap,
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
                    .padding(.top, 20)
                }
                .onAppear {
                    ensureAtLeastRows(3)   // 👈 auto-insert three rows if fewer exist
                }
                VStack {
                    Spacer()
                    HStack {
                        GlassEffectContainer(spacing: 45) {
                            HStack(alignment: .bottom, spacing: 10) {
                                VStack(spacing: -5) {
                                    VStack {
                                        VStack(spacing: 5) {
                                            if addButtonTapped {
                                                ZStack {
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color.clear)
                                                        .offset(addButtonTranslation)
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color(hex: 0x000000))
                                                }
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
                                                        addHoldButton = true
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { addHoldButton = false }
                                                    }
                                                }
                                                .sequenced(before:
                                                            DragGesture()
                                                    .onChanged { value in
                                                        guard addButtonTapped else { return }
                                                        
                                                        // ensure we have frames
                                                        let hasFrames = addFrame != .zero && sampleFrame != .zero && blankFrame != .zero
                                                        guard hasFrames else { return }
                                                        
                                                        // define origin/targets in the same space
                                                        let origin = addFrame.center
                                                        let sampleVec = sampleFrame.center - origin
                                                        let blankVec  = blankFrame.center - origin
                                                        let sampleLen = sampleVec.length
                                                        let blankLen  = blankVec.length
                                                        guard sampleLen > 1, blankLen > 1 else { return }
                                                        
                                                        // unit directions
                                                        let uSample = sampleVec.normalized
                                                        let uBlank  = blankVec.normalized
                                                        
                                                        // current drag as a vector
                                                        let v = CGPoint(x: value.translation.width, y: value.translation.height)
                                                        
                                                        // projections onto each ray
                                                        let pSample = v.dot(uSample)
                                                        let pBlank  = v.dot(uBlank)
                                                        
                                                        // choose which ray we're moving along (favor positive progress)
                                                        let chooseSample: Bool
                                                        if pSample <= 0 && pBlank <= 0 {
                                                            chooseSample = pSample >= pBlank // both negative: pick the "less negative"
                                                        } else if pSample > 0 && pBlank <= 0 {
                                                            chooseSample = true
                                                        } else if pBlank > 0 && pSample <= 0 {
                                                            chooseSample = false
                                                        } else {
                                                            chooseSample = pSample >= pBlank
                                                        }
                                                        
                                                        // clamp progress along the chosen ray
                                                        let rayU  = chooseSample ? uSample : uBlank
                                                        let rayL  = chooseSample ? sampleLen : blankLen
                                                        let proj  = (chooseSample ? pSample : pBlank).clamped(0, rayL)
                                                        let snapped = rayU * proj
                                                        
                                                        // apply as translation
                                                        addButtonTranslation = CGSize(width: snapped.x, height: snapped.y)
                                                        
                                                        // hover highlight near the end (70%+)
                                                        let nearEnd = proj > (rayL * 0.7)
                                                        sampleButtonHovered   = chooseSample && nearEnd
                                                        blankButtonHovered = !chooseSample && nearEnd
                                                    }
                                                    .onEnded { _ in
                                                        guard addButtonTapped else { return }
                                                        
                                                        // compute final progress to decide commit
                                                        let origin = addFrame.center
                                                        let sampleVec = sampleFrame.center - origin
                                                        let blankVec  = blankFrame.center - origin
                                                        let sampleLen = sampleVec.length
                                                        let blankLen  = blankVec.length
                                                        guard sampleLen > 1, blankLen > 1 else {
                                                            withAnimation {
                                                                addButtonTranslation = .zero
                                                                sampleButtonHovered = false
                                                                blankButtonHovered = false
                                                                addButtonTapped = false
                                                            }
                                                            return
                                                        }
                                                        
                                                        let current = CGPoint(x: addButtonTranslation.width, y: addButtonTranslation.height)
                                                        let progressOnSample = current.dot(sampleVec.normalized) / sampleLen
                                                        let progressOnBlank  = current.dot(blankVec.normalized)  / blankLen
                                                        
                                                        // commit threshold
                                                        let threshold: CGFloat = 0.7
                                                        
                                                        if progressOnSample >= threshold {
                                                            // commit Save
                                                            showAddItemsSheet = true
                                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                                addButtonTranslation = .zero
                                                                sampleButtonHovered = false
                                                                blankButtonHovered = false
                                                                addButtonTapped = false
                                                            }
                                                        } else if progressOnBlank >= threshold {
                                                            // commit Delete (your current action = dismiss)
                                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                                addButtonTranslation = .zero
                                                                sampleButtonHovered = false
                                                                blankButtonHovered = false
                                                                addButtonTapped = false
                                                            }
                                                            print("Blank would open")
                                                        } else {
                                                            // snap back
                                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                                addButtonTranslation = .zero
                                                                sampleButtonHovered = false
                                                                blankButtonHovered = false
                                                                addButtonTapped = false
                                                            }
                                                        }
                                                    }
                                                          )
                                        )
                                    }
                                    .onChange(of: sampleButtonHovered) { old, new in
                                        if new == true {
                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 1.0)
                                        }
                                        if new == false {
                                            let impact = UIImpactFeedbackGenerator(style: .soft)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 0.6)
                                        }
                                    }
                                    .onChange(of: blankButtonHovered) { old, new in
                                        if new == true {
                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 1.0)
                                        }
                                        if new == false {
                                            let impact = UIImpactFeedbackGenerator(style: .soft)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 0.6)
                                        }
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(Color.black.opacity(0.001))
                                    .contentShape(Rectangle())
                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    .overlay(alignment: .top) {
                                        if addButtonTapped {
                                            HStack {
                                                // Delete
                                                VStack(spacing: 5) {
                                                    Image(systemName: "square.dashed")
                                                        .resizable().scaledToFit()
                                                        .frame(width: blankButtonHovered ? 35 : 20, height: blankButtonHovered ? 35 : 20)
                                                    Text("Blank")
                                                        .font(.custom("Nunito-Black", size: blankButtonHovered ? 15 : 11))
                                                }
                                                .frame(width: 65, height: 65)
                                                .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                .background(
                                                    GeometryReader { gp in
                                                        Color.clear
                                                            .onAppear { blankFrame = gp.frame(in: .named("exitbar")) }
                                                            .onChange(of: gp.size) { _, _ in blankFrame = gp.frame(in: .named("exitbar")) }
                                                    }
                                                )
                                                .simultaneousGesture(
                                                    LongPressGesture(minimumDuration: 0.0).onEnded { _ in
                                                        withAnimation { addButtonTapped = false }
                                                        openBlankComposer()
                                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                        impact.prepare()
                                                        impact.impactOccurred(intensity: 1.0)
                                                    }
                                                )
                                                
                                                // Save
                                                VStack(spacing: 5) {
                                                    Image(systemName: "square.dashed.inset.filled")
                                                        .resizable().scaledToFit()
                                                        .frame(width: sampleButtonHovered ? 35 : 20, height: sampleButtonHovered ? 35 : 20)
                                                    Text("Sample")
                                                        .font(.custom("Nunito-Black", size: sampleButtonHovered ? 15 : 11))
                                                        .matchedTransitionSource(
                                                            id: "sampleButton", in: transition
                                                        )
                                                }
                                                .frame(width: 65, height: 65)
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
                                    Image(systemName: "arrow.up.arrow.down")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .fontWeight(.bold)
                                    
                                    Text("Rank")
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
                                            withAnimation { rankButtonTapped = true }
                                        }
                                )
                                .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                VStack(spacing: -5) {
                                    VStack {
                                        VStack(spacing: 5) {
                                            if exitButtonTapped {
                                                ZStack {
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color.clear)
                                                        .offset(exitButtonTranslation)
                                                    Image(systemName: "xmark")
                                                        .resizable().scaledToFit()
                                                        .frame(width: 20, height: 20)
                                                        .fontWeight(.black)
                                                        .foregroundStyle(Color(hex: 0x000000))
                                                }
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
                                                        exitHoldButton = true
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exitHoldButton = false }
                                                    }
                                                }
                                                .sequenced(before:
                                                            DragGesture()
                                                    .onChanged { value in
                                                        guard exitButtonTapped else { return }
                                                        
                                                        // ensure we have frames
                                                        let hasFrames = exitFrame != .zero && saveFrame != .zero && deleteFrame != .zero
                                                        guard hasFrames else { return }
                                                        
                                                        // define origin/targets in the same space
                                                        let origin = exitFrame.center
                                                        let saveVec = saveFrame.center - origin
                                                        let delVec  = deleteFrame.center - origin
                                                        let saveLen = saveVec.length
                                                        let delLen  = delVec.length
                                                        guard saveLen > 1, delLen > 1 else { return }
                                                        
                                                        // unit directions
                                                        let uSave = saveVec.normalized
                                                        let uDel  = delVec.normalized
                                                        
                                                        // current drag as a vector
                                                        let v = CGPoint(x: value.translation.width, y: value.translation.height)
                                                        
                                                        // projections onto each ray
                                                        let pSave = v.dot(uSave)
                                                        let pDel  = v.dot(uDel)
                                                        
                                                        // choose which ray we're moving along (favor positive progress)
                                                        let chooseSave: Bool
                                                        if pSave <= 0 && pDel <= 0 {
                                                            chooseSave = pSave >= pDel // both negative: pick the "less negative"
                                                        } else if pSave > 0 && pDel <= 0 {
                                                            chooseSave = true
                                                        } else if pDel > 0 && pSave <= 0 {
                                                            chooseSave = false
                                                        } else {
                                                            chooseSave = pSave >= pDel
                                                        }
                                                        
                                                        // clamp progress along the chosen ray
                                                        let rayU  = chooseSave ? uSave : uDel
                                                        let rayL  = chooseSave ? saveLen : delLen
                                                        let proj  = (chooseSave ? pSave : pDel).clamped(0, rayL)
                                                        let snapped = rayU * proj
                                                        
                                                        // apply as translation
                                                        exitButtonTranslation = CGSize(width: snapped.x, height: snapped.y)
                                                        
                                                        // hover highlight near the end (70%+)
                                                        let nearEnd = proj > (rayL * 0.7)
                                                        saveButtonHovered   = chooseSave && nearEnd
                                                        deleteButtonHovered = !chooseSave && nearEnd
                                                    }
                                                    .onEnded { _ in
                                                        guard exitButtonTapped else { return }
                                                        
                                                        // compute final progress to decide commit
                                                        let origin = exitFrame.center
                                                        let saveVec = saveFrame.center - origin
                                                        let delVec  = deleteFrame.center - origin
                                                        let saveLen = saveVec.length
                                                        let delLen  = delVec.length
                                                        guard saveLen > 1, delLen > 1 else {
                                                            withAnimation {
                                                                exitButtonTranslation = .zero
                                                                saveButtonHovered = false
                                                                deleteButtonHovered = false
                                                                exitButtonTapped = false
                                                            }
                                                            return
                                                        }
                                                        
                                                        let current = CGPoint(x: exitButtonTranslation.width, y: exitButtonTranslation.height)
                                                        let progressOnSave = current.dot(saveVec.normalized) / saveLen
                                                        let progressOnDel  = current.dot(delVec.normalized)  / delLen
                                                        
                                                        // commit threshold
                                                        let threshold: CGFloat = 0.7
                                                        
                                                        if progressOnSave >= threshold {
                                                            // commit Save
                                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                                exitButtonTranslation = .zero
                                                                saveButtonHovered = false
                                                                deleteButtonHovered = false
                                                                exitButtonTapped = false
                                                            }
                                                            //                                                        startPublishAndDismiss()
                                                        } else if progressOnDel >= threshold {
                                                            // commit Delete (your current action = dismiss)
                                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                                exitButtonTranslation = .zero
                                                                saveButtonHovered = false
                                                                deleteButtonHovered = false
                                                                exitButtonTapped = false
                                                            }
                                                            Task {
                                                                //                                                            await deleteRankoPersonalFolderAsync(rankoID: listID)
                                                                // if you also remove DB/Algolia here, do it after the cleanup:
                                                                // try? await deleteRankoFromFirebase(listUUID)
                                                                // try? await deleteRankoFromAlgolia(listUUID)
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                                                    dismiss()
                                                                }
                                                            }
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
                                                        } else {
                                                            // snap back
                                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                                exitButtonTranslation = .zero
                                                                saveButtonHovered = false
                                                                deleteButtonHovered = false
                                                                exitButtonTapped = false
                                                            }
                                                        }
                                                    }
                                                          )
                                        )
                                    }
                                    .onChange(of: saveButtonHovered) { old, new in
                                        if new == true {
                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 1.0)
                                        }
                                        if new == false {
                                            let impact = UIImpactFeedbackGenerator(style: .soft)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 0.6)
                                        }
                                    }
                                    .onChange(of: deleteButtonHovered) { old, new in
                                        if new == true {
                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 1.0)
                                        }
                                        if new == false {
                                            let impact = UIImpactFeedbackGenerator(style: .soft)
                                            impact.prepare()
                                            impact.impactOccurred(intensity: 0.6)
                                        }
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
                                                        .frame(width: deleteButtonHovered ? 35 : 20, height: deleteButtonHovered ? 35 : 20)
                                                    Text("Delete")
                                                        .font(.custom("Nunito-Black", size: deleteButtonHovered ? 15 : 11))
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
                                                        .frame(width: saveButtonHovered ? 35 : 20, height: saveButtonHovered ? 35 : 20)
                                                    Text("Save")
                                                        .font(.custom("Nunito-Black", size: saveButtonHovered ? 15 : 11))
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
                                                        //                                                    startPublishAndDismiss()  // ← NEW
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RankoToolbarTitleStack(
                        name: rankoName,
                        description: description,
                        isPrivate: $isPrivate,
                        category: category,
                        categoryColor: category.flatMap { categoryChipIconColors[$0.name] } ?? .gray.opacity(0.7),
                        showEditDetailsSheet: $showEditDetailsSheet,
                        onTapPrivacy: { showEditDetailsSheet = true },   // or: { isPrivate.toggle() }
                        onTapCategory: { showEditDetailsSheet = true }
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(rankoName). \(description). \(isPrivate ? "Private" : "Public"). \(category?.name ?? "")")
                }
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
            .sheet(isPresented: $editButtonTapped) {
                DefaultListEditDetails(
                    rankoName: rankoName,
                    description: description,
                    isPrivate: isPrivate,
                    category: category
                ) { newName, newDescription, newPrivate, newCategory in
                    rankoName   = newName
                    description = newDescription
                    isPrivate   = newPrivate
                    category    = newCategory
                }
                .navigationTransition(
                    .zoom(sourceID: "editButton", in: transition)
                )
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
            .fullScreenCover(isPresented: $showBlankItemsFS, onDismiss: {
                // reset again so next open is clean (even if user cancelled)
                blankDrafts = [BlankItemDraft()]
                draftError = nil
            }) {
                BlankItemsComposer(
                    rankoID: rankoID,
                    drafts: $blankDrafts,
                    error: $draftError,
                    canAddMore: blankDrafts.count < 10,
                    onCommit: {
                        appendDraftsToSelectedRanko()
                        showEmbeddedStickyPoolSheet = true
                    }
                )
            }
            .interactiveDismissDisabled(true)
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
            }
            .frame(minWidth: 70, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: tier.colorHex))
            )
            .padding(8)
        }
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
        let bucketPathRoot = "rankoPersonalImages/\(rankoID)" // use your listUUID as rankoID

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

        for draft in blankDrafts {
            let newItemID = UUID().uuidString
            let url = draft.itemImageURL ?? placeholderURL

            let rec = RankoRecord(
                objectID: newItemID,
                ItemName: draft.name,
                ItemDescription: draft.description,
                ItemCategory: "",
                ItemImage: url,
                ItemGIF: draft.gif,
                ItemVideo: draft.video,
                ItemAudio: draft.audio
            )
            let item = RankoItem(id: newItemID, rank: nextRank, votes: 0, record: rec, playCount: 0)
            unGroupedItems.append(item)
            nextRank += 1
        }

        blankDrafts = [BlankItemDraft()]
        draftError = nil
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
                        GroupItemCell(
                            item: item,
                            contentDisplay: contentMode,
                            itemSize: sizeMode
                        )
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
    
    @MainActor
    private func startPublishAndDismiss() {
        guard category != nil else {
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

        for idx in groupedItems.indices {
            let itemID = groupedItems[idx].id
            guard pendingPersonalImages[itemID] != nil else { continue }

            let newURL = "\(urlBase)\(itemID).jpg?alt=media&token="
            let oldRecord = groupedItems[idx].record
            let updatedRecord = oldRecord.withItemImage(newURL)
            let updatedItem = groupedItems[idx].withRecord(updatedRecord)

            groupedItems[idx] = updatedItem
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

    func saveRankedListToFirebaseAsync() {
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
                    "ItemVotes":       0,
                    
                    // Extra media/stat fields to match your sample schema
                    "ItemGIF":   item.itemGIF,
                    "ItemVideo": item.itemVideo,
                    "ItemAudio": item.itemAudio,
                    "PlayCount": item.playCount
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
            "RankoID":          rankoID,
            "RankoName":        rankoName,
            "RankoDescription": description,
            "RankoType":        "group",
            "RankoPrivacy":     isPrivate,
            "RankoStatus":      "active",
            "RankoCategory":    category.name,
            "RankoUserID":      user_data.userID,
            "RankoItems":       rankoItemsDict,
            "RankoDateTime":    rankoDateTime,
            "RankoTiers":       tiersPayload()              // 👈 NEW
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

        // Category object (use hex string like "0xFFCF00")
        let colourString: String = normalizeHexString(category.colour)

        let categoryDict: [String: Any] = [
            "colour": colourString,
            "icon":   category.icon,
            "name":   category.name
        ]

        // Details (fill tags/region/lang with smart defaults if you don't have UI for them yet)
        let normalizedTags: [String] = tags.isEmpty ? ["ranko", category.name.lowercased()] : tags

        let rankoDetails: [String: Any] = [
            "id":          rankoID,
            "name":        rankoName,
            "description": description,
            "type":        "default",
            "user_id":     user_data.userID,
            "tags":        normalizedTags,
            "region":      "AUS",
            "language":    "en",
            "downloaded":  true
        ]

        // Privacy block (match your example)
        let rankoPrivacy: [String: Any] = [
            "private":   isPrivate,
            "cloneable": true,
            "comments":  true,
            "likes":     true,
            "shares":    true,
            "saves":     true,
            "status":    "active"
        ]

        // Statistics (start at 0; your sample shows some nonzero values — adjust if you keep history)
        let rankoStats: [String: Any] = [
            "views":  0,
            "saves":  0,
            "shares": 0,
            "clones": 0
        ]

        // Full payload shaped like your sample
        let payload: [String: Any] = [
            "RankoDetails":   rankoDetails,
            "RankoCategory":  categoryDict,
            "RankoPrivacy":   rankoPrivacy,
            "RankoDateTime":  ["updated": rankoDateTime, "created": rankoDateTime],   // <- exact keys
            "RankoStatistics": rankoStats,
            "RankoLikes":     [:], // empty map to start
            "RankoComments":  [:], // empty map to start
            "RankoItems":     rankoItemsDict
        ]

        // write the Ranko and mirror minimal info under the user
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await setValueAsync(
                    db.child("RankoData").child(self.rankoID),
                    value: payload
                )
            }
            group.addTask {
                // keep a lightweight pointer under the user (you can mirror more later)
                try await setValueAsync(
                    db.child("UserData").child(user_data.userID)
                      .child("UserRankos").child("UserActiveRankos")
                      .child(self.rankoID),
                    value: category.name
                )
            }
            try await group.waitForAll()
        }
        
        
        
        
        
        
        
    }
    
    
    // Wrap Firebase setValue into async/await
    private func setValueAsync(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { err, _ in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
    }
    
    private func tiersPayload() -> [String: Any] {
        var out: [String: Any] = [:]
        for (i, t) in tiers.enumerated() {
            let key = String(format: "%03d", i + 1)   // keep order stable
            out[key] = [
                "Code": t.code,
                "Label": t.label,
                "ColorHex": String(format: "%06X", t.colorHex) // store as hex string too
            ]
        }
        return out
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
    
    struct GroupItemCell: View {
        let item: RankoItem
        let contentDisplay: ContentDisplay
        let itemSize: ItemSize

        private var isVertical: Bool { itemSize == .large }

        var body: some View {
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
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(radius: 1)
            )
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
                            .font(.system(size: itemSize.descFont, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 60, alignment: .leading)
            }
        }
    }
    
    struct GroupRow: View {
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
            HStack(alignment: .top, spacing: 4) {
                TierHeader(tier: tier)

                switch layout {
                case .noWrap:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSize == .large ? 8 : 4) {
                            ForEach(items) { item in
                                GroupItemCell(item: item, contentDisplay: contentDisplay, itemSize: itemSize)
                                    .onDrag { NSItemProvider(object: item.id as NSString) }
                                    .onTapGesture { selectedDetailItem = item }
                            }
                        }
                        .padding(8)
                    }
                case .wrap:
                    FlowLayout2(spacing: itemSize == .large ? 8 : 6) {
                        ForEach(items) { item in
                            GroupItemCell(item: item, contentDisplay: contentDisplay, itemSize: itemSize)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFFFFF)).shadow(radius: 2)
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(itemRows: $itemRows, unGrouped: $unGroupedItems, hoveredRow: $hoveredRow, targetRow: rowIndex)
            )
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
                .disabled(!canDelete) // ← disables if there are any items
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
    
    struct GroupListHeaderAndRows: View {
        // header
        let rankoName: String
        let description: String
        let isPrivate: Bool
        let category: SampleCategoryChip?
        let categoryChipIconColors: [String: Color]

        // data
        @Binding var groupedItems: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        // knobs
        @Binding var wrapMode: RowLayout
        @Binding var contentDisplay: ContentDisplay
        @Binding var itemSize: ItemSize

        // helpers provided by parent
        let tierForRow: (Int) -> Tier

        var body: some View {
            
        }

        // add-row button reused in all branches
        private var addRowButton: some View {
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





// MARK: - GROUP LIST VIEW
//struct GroupListView: View {
//    @Environment(\.dismiss) var dismiss
//    @StateObject private var user_data = UserInformation.shared
//    
//    @AppStorage("group_wrap_mode")    private var wrapMode: RowLayout = .wrap
//    @AppStorage("group_content_mode") private var contentMode: ContentDisplay = .textAndImage
//    @AppStorage("group_size_mode")    private var sizeMode: ItemSize = .medium
//    
//    // MARK: - RANKO LIST DATA
//    @State private var rankoID: String = UUID().uuidString
//    @State private var rankoName: String
//    @State private var description: String
//    @State private var isPrivate: Bool
//    @State private var category: SampleCategoryChip?
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
//    
//    @State private var addButtonTapped: Bool = false
//    @State private var editButtonTapped: Bool = false
//    @State private var rankButtonTapped: Bool = false
//    @State private var exitButtonTapped: Bool = false
//    
//    @State private var addHoldButton: Bool = false
//    @State private var editHoldButton: Bool = false
//    @State private var rankHoldButton: Bool = false
//    @State private var exitHoldButton: Bool = false
//    
//    @State private var exitButtonTranslation: CGSize = .zero
//    @State private var exitButtonsTranslation: CGSize = .zero
//    @State private var saveButtonHovered: Bool = false
//    @State private var deleteButtonHovered: Bool = false
//    @State private var exitButtonPosition: CGSize = .zero
//    @State private var saveButtonPosition: CGSize = .zero
//    @State private var deleteButtonPosition: CGSize = .zero
//    
//    @State private var addFrame: CGRect = .zero
//    @State private var sampleFrame: CGRect = .zero
//    @State private var blankFrame: CGRect = .zero
//    
//    @State private var addButtonTranslation: CGSize = .zero
//    @State private var addButtonsTranslation: CGSize = .zero
//    
//    @State private var sampleButtonHovered: Bool = false
//    @State private var blankButtonHovered: Bool = false
//    
//    @State private var exitFrame: CGRect = .zero
//    @State private var saveFrame: CGRect = .zero
//    @State private var deleteFrame: CGRect = .zero
//    
//    // Blank Items composer
//    @State private var showBlankItemsFS = false
//    @State private var blankDrafts: [BlankItemDraft] = [BlankItemDraft()] // start with 1
//    @State private var draftError: String? = nil
//    @Namespace private var transition
//    
//    // MARK: - ITEM VARIABLES
//    @State private var unGroupedItems: [RankoItem] = []
//    @State private var groupedItems: [[RankoItem]]
//    @State private var selectedDetailItem: RankoItem? = nil
//    
//    // MARK: - OTHER VARIABLES (INC. TOAST)
//    @State private var hoveredRow: Int? = nil
//    
//    @State private var activeTab: GroupListTab = .addItems
//    
//    @State private var tiers: [TierConfig] = TierConfig.defaults()
//    @State private var showTierEditor = false
//
//    // Replace your old enum-based helper with this:
//    private func tierConfigForRow(_ i: Int) -> TierConfig {
//        if tiers.isEmpty { return TierConfig.defaults().first! }
//        let idx = min(max(i, 0), tiers.count - 1)   // clamp to last tier if overflows
//        return tiers[idx]
//    }
//    
//    // hold personal images picked for new items -> uploaded on publish
//    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
//    // MARK: - INITIALISER
//    
//    init(
//        rankoName: String,
//        description: String,
//        isPrivate: Bool,
//        category: SampleCategoryChip?,
//        groupedItems items: [RankoItem]? = nil
//    ) {
//        _rankoName   = State(initialValue: rankoName)
//        _description = State(initialValue: description)
//        _isPrivate   = State(initialValue: isPrivate)
//        _category    = State(initialValue: category)
//        if let items = items, !items.isEmpty {
//            let maxGroup = items.map { $0.rank / 1000 }.max() ?? 0
//            var buckets: [[RankoItem]] = Array(repeating: [], count: maxGroup)
//            for item in items {
//                let bucket = item.rank / 1000
//                if bucket >= 1 && bucket <= maxGroup {
//                    buckets[bucket - 1].append(item)
//                }
//            }
//            _groupedItems = State(initialValue: buckets)
//        } else {
//            _groupedItems = State(initialValue: [])
//        }
//    }
//    
//    enum WrapMode: String, CaseIterable { case wrap, noWrap }
//    
//    // MARK: - Tiers
//    enum Tier: Int, CaseIterable, Identifiable {
//        case s, a, b, c, d, e, f
//        var id: Int { rawValue }
//
//        var letter: String {
//            switch self {
//            case .s: return "S"
//            case .a: return "A"
//            case .b: return "B"
//            case .c: return "C"
//            case .d: return "D"
//            case .e: return "E"
//            case .f: return "F"
//            }
//        }
//
//        var label: String {
//            switch self {
//            case .s: return "Legendary"
//            case .a: return "Excellent"
//            case .b: return "Solid"
//            case .c: return "Average"
//            case .d: return "Weak"
//            case .e: return "Poor"
//            case .f: return "Useless"
//            }
//        }
//
//        var color: Color {
//            // tuned to match the sample look
//            switch self {
//            case .s: return Color(hex: 0xC44536) // red
//            case .a: return Color(hex: 0xBF7B2F) // orange
//            case .b: return Color(hex: 0xBFA254) // gold
//            case .c: return Color(hex: 0x4DA35A) // green
//            case .d: return Color(hex: 0x3F7F74) // teal
//            case .e: return Color(hex: 0x3F63A7) // blue
//            case .f: return Color(hex: 0x6C46B3) // purple
//            }
//        }
//    }
//
//    // Safely map a row index to a tier (clamps to F if there are more than 7 rows)
//    private func tierForRow(_ i: Int) -> Tier {
//        if i >= 0 && i < Tier.allCases.count { return Tier.allCases[i] }
//        return .f
//    }
//
//    // The colored square tier box (letter + tiny label)
//    struct TierBox: View {
//        let tier: Tier
//        var body: some View {
//            VStack(spacing: 2) {
//                Text(tier.letter)
//                    .font(.system(size: 18, weight: .black, design: .rounded))
//                    .foregroundStyle(.white)
//                    .padding(.top, 6)
//                    .padding(.horizontal, 16)
//
//                Text(tier.label)
//                    .font(.system(size: 9, weight: .semibold, design: .rounded))
//                    .foregroundStyle(.white.opacity(0.95))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.7)
//                    .padding(.bottom, 6)
//                    .padding(.horizontal, 6)
//            }
//            .frame(minWidth: 70, minHeight: 50)
//            .background(
//                RoundedRectangle(cornerRadius: 12, style: .continuous)
//                    .fill(tier.color)
//            )
//            .padding(8)
//            .contextMenu {
//                Button(role: .destructive) {
//                    
//                } label: {
//                    Label("Delete Tier", systemImage: "trash")
//                }
//            }
//        }
//    }
//    
//    // MARK: - BODY VIEW
//    
//    var body: some View {
//        ZStack(alignment: .top) {
//            Color(hex: 0xFFFFFF)
//                .ignoresSafeArea()
//            ScrollView {
//                VStack(spacing: 7) {
//
//                    // HEADER
//                    VStack(spacing: 6) {
//                        HStack {
//                            Text(rankoName)
//                                .font(.custom("Nunito-Black", size: 24))
//                                .foregroundStyle(Color(hex: 0x514343))
//                                .kerning(-0.4)
//                            Spacer()
//                        }
//                        .padding(.top, 20)
//                        .padding(.leading, 20)
//
//                        HStack {
//                            Text(description.isEmpty ? "No description yet…" : description)
//                                .lineLimit(3)
//                                .font(.custom("Nunito-Black", size: 13))
//                                .foregroundStyle(Color(hex: 0x514343))
//                            Spacer()
//                        }
//                        .padding(.top, 5)
//                        .padding(.leading, 20)
//
//                        HStack(spacing: 8) {
//                            HStack(spacing: 4) {
//                                Image(systemName: isPrivate ? "lock.fill" : "globe.americas.fill")
//                                    .font(.system(size: 12, weight: .bold))
//                                    .foregroundColor(.white)
//                                    .padding(.leading, 10)
//                                Text(isPrivate ? "Private" : "Public")
//                                    .font(.system(size: 12, weight: .bold))
//                                    .foregroundColor(.white)
//                                    .padding(.trailing, 10)
//                                    .padding(.vertical, 8)
//                            }
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(Color(hex: 0xF2AB69))
//                            )
//
//                            if let cat = category {
//                                HStack(spacing: 4) {
//                                    Image(systemName: cat.icon)
//                                        .font(.caption).fontWeight(.bold)
//                                        .foregroundColor(.white)
//                                        .padding(.leading, 10)
//                                    Text(cat.name)
//                                        .font(.system(size: 12, weight: .bold))
//                                        .foregroundColor(.white)
//                                        .padding(.trailing, 10)
//                                        .padding(.vertical, 8)
//                                }
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(categoryChipIconColors[cat.name] ?? .gray)
//                                        .opacity(0.6)
//                                )
//                            }
//                            Spacer()
//                        }
//                        .padding(.top, 5)
//                        .padding(.leading, 20)
//                    }
//                    .contextMenu {
//                        Button {} label: { Label("Edit Details", systemImage: "pencil") }
//                        Divider()
//                        Button {} label: { Label("Re-Rank Items", systemImage: "chevron.up.chevron.down") }
//                        Divider()
//                        Button(role: .destructive) {} label: { Label("Delete Ranko", systemImage: "trash") }
//                    }
//
//                    Spacer()
//
//                    // KNOBS (3 groups of pills)
//                    HStack(alignment: .top, spacing: 8) {
//
//                        // LEFT — wrap / no wrap
//                        VerticalDropdownPicker<RowLayout>(
//                            selection: $wrapMode,
//                            title: { $0.title },
//                            systemIcon: { $0.icon },
//                            accent: Color(hex: 0x6D400F)
//                        )
//
//                        // MIDDLE — content
//                        VerticalDropdownPicker<ContentDisplay>(
//                            selection: $contentMode,
//                            title: { $0.title },
//                            systemIcon: { $0.icon },
//                            accent: Color(hex: 0x6D400F)
//                        )
//
//                        // RIGHT — size (small / medium / large)
//                        VerticalDropdownPicker<ItemSize>(
//                            selection: $sizeMode,
//                            title: { $0.title },
//                            systemIcon: { $0.icon },
//                            accent: Color(hex: 0x6D400F)
//                        )
//                    }
//                    .padding(.horizontal, 12)
//                    .padding(.top, 6)
//
//                    Divider()
//
//                    // ROWS (route based on knobs)
//                    if sizeMode == .large {
//                        // large = vertical/grid-like cards
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRow(
//                                        rowIndex: i,
//                                        tier: tierConfigForRow(i),
//                                        items: groupedItems[i],
//                                        itemRows: $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow: $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem,
//                                        layout: .wrap,                    // wrap/noWrap allowed even on large
//                                        contentDisplay: contentMode,
//                                        itemSize: .large,
//                                        onEditTiers: { showTierEditor = true }
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                addRowButton
//                            }
//                            .padding(.top, 10)
//                            .padding(.bottom, 180)
//                        }
//
//                    } else if wrapMode == .wrap {
//                        // wrap = FlowLayout
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRow(
//                                        rowIndex: i,
//                                        tier: tierConfigForRow(i),
//                                        items: groupedItems[i],
//                                        itemRows: $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow: $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem,
//                                        layout: .wrap,
//                                        contentDisplay: contentMode,
//                                        itemSize: sizeMode,
//                                        onEditTiers: { showTierEditor = true }
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                addRowButton
//                            }
//                            .padding(.top, 10)
//                            .padding(.bottom, 180)
//                        }
//
//                    } else {
//                        // noWrap = horizontal scrollers
//                        ScrollView(.vertical, showsIndicators: false) {
//                            VStack(spacing: 12) {
//                                ForEach(groupedItems.indices, id: \.self) { i in
//                                    GroupRow(
//                                        rowIndex: i,
//                                        tier: tierConfigForRow(i),
//                                        items: groupedItems[i],
//                                        itemRows: $groupedItems,
//                                        unGroupedItems: $unGroupedItems,
//                                        hoveredRow: $hoveredRow,
//                                        selectedDetailItem: $selectedDetailItem,
//                                        layout: .noWrap,
//                                        contentDisplay: contentMode,
//                                        itemSize: sizeMode,
//                                        onEditTiers: { showTierEditor = true }
//                                    )
//                                    .padding(.horizontal, 8)
//                                }
//                                addRowButton
//                            }
//                            .padding(.top, 10)
//                            .padding(.bottom, 180)
//                        }
//                    }
//
//                    Spacer(minLength: 60)
//                }
//                .padding(.top, 20)
//            }
//            .onAppear {
//                ensureAtLeastRows(3)   // 👈 auto-insert three rows if fewer exist
//            }
//            VStack {
//                ...
//            }
//            .coordinateSpace(name: "exitbar")   // ← add this
//            .padding(.bottom, 10)
//            
//        }
//        .sheet(isPresented: $showTierEditor) {
//            TierEditorSheet(tiers: $tiers)
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
//                listID:  rankoID
//            ) { updatedItem in
//                if let idx = groupedItems[rowIndex]
//                                .firstIndex(where: { $0.id == updatedItem.id }) {
//                    groupedItems[rowIndex][idx] = updatedItem
//                }
//            }
//        }
//        .fullScreenCover(isPresented: $showBlankItemsFS, onDismiss: {
//            // When FilterChipPickerView closes, trigger the embeddedStickyPoolView sheet
//            showEmbeddedStickyPoolSheet = true
//        }) {
//            BlankItemsComposer(
//                rankoID: rankoID,                  // 👈 add this
//                drafts: $blankDrafts,
//                error: $draftError,
//                canAddMore: blankDrafts.count < 10,
//                onCommit: { appendDraftsToSelectedRanko() }
//            )
//        }
//        .interactiveDismissDisabled(true)
//    }
//    
//    // MARK: - Tier Editor Sheet
//    struct TierEditorSheet: View {
//        @Environment(\.dismiss) private var dismiss
//
//        @Binding var tiers: [TierConfig]                 // edits write back to GroupListView
//
//        @State private var activeColorTierID: String? = nil
//        @State private var showColorPicker = false
//        @State private var tempColor: Color = .white
//
//        private let maxTiers = 25
//
//        var body: some View {
//            NavigationStack {
//                ScrollView {
//                    VStack(spacing: 12) {
//                        ForEach($tiers) { $tier in
//                            TierCard(
//                                tier: $tier,
//                                onTapColor: {
//                                    activeColorTierID = tier.id
//                                    tempColor = Color(hex: tier.colorHex)
//                                    showColorPicker = true
//                                },
//                                onDelete: {
//                                    if let idx = tiers.firstIndex(where: { $0.id == tier.id }) {
//                                        // keep at least 1 tier
//                                        if tiers.count > 1 { tiers.remove(at: idx) }
//                                    }
//                                }
//                            )
//                        }
//                        
//                        Button {
//                            guard tiers.count < maxTiers else { return }
//                            // Add a default next tier (G, H, … or just numbered)
//                            let next = nextTierCode(existing: tiers.map(\.code))
//                            tiers.append(TierConfig(code: next, label: "Custom", colorHex: 0x888888))
//                        } label: {
//                            HStack(spacing: 8) {
//                                Image(systemName: "plus.circle.fill")
//                                Text("ADD TIER")
//                            }
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .disabled(tiers.count >= maxTiers)
//                        .opacity(tiers.count >= maxTiers ? 0.5 : 1)
//                        .padding(.top, 8)
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 12)
//                }
//                .navigationTitle("Edit Tiers")
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button("Cancel") { dismiss() }
//                    }
//                    ToolbarItem(placement: .confirmationAction) {
//                        Button("Done") {
//                            normalizeAll()
//                            dismiss()
//                        }
//                    }
//                }
//            }
//            // Color picker presented when tapping the color swatch
//            .sheet(isPresented: $showColorPicker) {
//                VStack(spacing: 16) {
//                    Text("Pick Tier Color").font(.headline)
//                    ColorPicker("Color", selection: $tempColor, supportsOpacity: false)
//                        .labelsHidden()
//                        .frame(maxWidth: .infinity, alignment: .center)
//                        .padding()
//                    
//                    Button {
//                        if let id = activeColorTierID,
//                           let idx = tiers.firstIndex(where: { $0.id == id }) {
//                            tiers[idx].colorHex = colorToHex(tempColor)   // store HEX
//                        }
//                        showColorPicker = false
//                    } label: {
//                        Text("Use This Color")
//                            .font(.system(size: 16, weight: .bold))
//                            .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .padding(.horizontal)
//                }
//                .presentationDetents([.height(240)])
//            }
//        }
//
//        // clamp text & uppercase codes
//        private func normalizeAll() {
//            for i in tiers.indices {
//                tiers[i].code  = String(tiers[i].code.uppercased().prefix(3))
//                tiers[i].label = String(tiers[i].label.prefix(10))
//            }
//        }
//
//        private func nextTierCode(existing: [String]) -> String {
//            // Try G..Z then AA.. if needed; fall back to numeric
//            let base = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
//            let used = Set(existing.map { $0.uppercased() })
//
//            // single letters
//            for ch in base {
//                let s = String(ch)
//                if !used.contains(s) { return s }
//            }
//            // double letters
//            for ch1 in base {
//                for ch2 in base {
//                    let s = "\(ch1)\(ch2)"
//                    if !used.contains(s) { return s }
//                }
//            }
//            // fallback
//            var i = 1
//            while used.contains("T\(i)") { i += 1 }
//            return "T\(i)"
//        }
//    }
//
//    // A single editable card for one tier
//    private struct TierCard: View {
//        @Binding var tier: TierConfig
//        var onTapColor: () -> Void
//        var onDelete: () -> Void
//
//        var body: some View {
//            VStack(spacing: 12) {
//                HStack {
//                    Text("Tier").font(.caption).foregroundStyle(.secondary)
//                    Spacer()
//                    Button(role: .destructive, action: onDelete) {
//                        Label("Delete", systemImage: "trash")
//                    }
//                    .labelStyle(.titleAndIcon)
//                    .font(.caption)
//                }
//
//                HStack(spacing: 10) {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("CODE (max 3)").font(.caption).foregroundStyle(.secondary)
//                        TextField("S", text: Binding(
//                            get: { tier.code },
//                            set: { tier.code = String($0.uppercased().prefix(3)) }
//                        ))
//                        .textFieldStyle(.roundedBorder)
//                        .frame(maxWidth: 120)
//                    }
//
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("SUBTITLE (max 10)").font(.caption).foregroundStyle(.secondary)
//                        TextField("Legendary", text: Binding(
//                            get: { tier.label },
//                            set: { tier.label = String($0.prefix(10)) }
//                        ))
//                        .textFieldStyle(.roundedBorder)
//                        .frame(maxWidth: 220)
//                    }
//
//                    Spacer()
//
//                    // color swatch opens a color picker sheet
//                    Button(action: onTapColor) {
//                        RoundedRectangle(cornerRadius: 10)
//                            .fill(Color(hex: tier.colorHex))
//                            .frame(width: 56, height: 36)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 10)
//                                    .stroke(.black.opacity(0.08), lineWidth: 1)
//                            )
//                    }
//                    .buttonStyle(.plain)
//                    .accessibilityLabel("Change color")
//                }
//            }
//            .padding(14)
//            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
//        }
//    }
//    
//    // MARK: - Tier header box using TierConfig
//    struct TierHeader: View {
//        let tier: TierConfig
//        var body: some View {
//            VStack(spacing: 2) {
//                Text(tier.code)
//                    .font(.system(size: 18, weight: .black, design: .rounded))
//                    .foregroundStyle(.white)
//                    .padding(.top, 6)
//                    .padding(.horizontal, 16)
//
//                Text(tier.label)
//                    .font(.system(size: 9, weight: .semibold, design: .rounded))
//                    .foregroundStyle(.white.opacity(0.95))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.7)
//                    .padding(.bottom, 6)
//                    .padding(.horizontal, 6)
//            }
//            .frame(minWidth: 70, minHeight: 50)
//            .background(
//                RoundedRectangle(cornerRadius: 12, style: .continuous)
//                    .fill(Color(hex: tier.colorHex))
//            )
//            .padding(8)
//        }
//    }
//    
//    private func ensureAtLeastRows(_ n: Int = 3) {
//        if groupedItems.count < n {
//            groupedItems.append(contentsOf: Array(repeating: [], count: n - groupedItems.count))
//        }
//    }
//    
//    private var addRowButton: some View {
//        Button {
//            groupedItems.append([])
//        } label: {
//            HStack {
//                Image(systemName: "plus")
//                    .foregroundColor(.white)
//                    .fontWeight(.bold)
//                    .font(.headline)
//            }
//            .padding(.vertical, 12)
//            .frame(maxWidth: .infinity)
//            .background(Color(hex: 0x6D400F))
//            .cornerRadius(8)
//            .padding(.horizontal)
//        }
//    }
//    
//    private struct BlankItemsComposer: View {
//        @Environment(\.dismiss) private var dismiss
//        @StateObject private var user_data = UserInformation.shared
//
//        let rankoID: String
//
//        @Binding var drafts: [BlankItemDraft]
//        @Binding var error: String?
//        let canAddMore: Bool
//        let onCommit: () -> Void
//
//        @State private var activeDraftID: String? = nil
//        @State private var showNewImageSheet = false
//        @State private var showPhotoPicker = false
//        @State private var showImageCropper = false
//        @State private var imageForCropping: UIImage? = nil
//        @State private var backupImage: UIImage? = nil
//        @State private var isCleaningUp = false
//        
//        @FocusState private var focusedField: Field?
//        enum Field: Hashable { case name(String), description(String) }
//
//        // convenience
//        private var placeholderURL: String {
//            "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
//        }
//        private func finalURL(for draftID: String) -> String {
//            "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F\(draftID).jpg?alt=media&token="
//        }
//        
//        private var anyUploading: Bool {
//            drafts.contains { $0.isUploading }
//        }
//
//        private var hasUploadError: Bool {
//            drafts.contains { $0.uploadError != nil }
//        }
//
//        /// true when every draft is "image-ready":
//        /// - no image: ok
//        /// - has image: must have finished upload (itemImageURL != nil) and no error
//        private var imagesReady: Bool {
//            drafts.allSatisfy { d in
//                if d.image == nil {
//                    return !d.isUploading && d.uploadError == nil
//                } else {
//                    return !d.isUploading && d.uploadError == nil && d.itemImageURL != nil
//                }
//            }
//        }
//
//        var body: some View {
//            NavigationStack {
//                ScrollView {
//                    VStack(spacing: 16) {
//                        ForEach(drafts, id: \.id) { draft in
//                            let draftID = draft.id
//                            DraftCard(
//                                draft: bindingForDraft(id: draftID),      // ← binding resolved by id
//                                title: "Blank Item #\((drafts.firstIndex(where: { $0.id == draftID }) ?? 0) + 1)",
//                                subtitle: "tap to add image (optional)",
//                                focusedField: $focusedField,
//                                onTapImage: {
//                                    activeDraftID = draftID
//                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
//                                    showNewImageSheet = true
//                                },
//                                onDelete: {
//                                    removeDraft(id: draftID)              // ← remove by id (no captured i)
//                                }
//                            )
//                            .contextMenu {
//                                Button(role: .none) {                     // was .confirm (invalid role)
//                                    activeDraftID = draftID
//                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
//                                    showNewImageSheet = true
//                                } label: { Label("Add Image", systemImage: "photo.fill") }
//
//                                Button(role: .destructive) {
//                                    removeDraft(id: draftID)
//                                } label: { Label("Delete", systemImage: "trash") }
//
//                                Button(role: .none) {
//                                    // clear fields on the live binding if it still exists
//                                    if let idx = drafts.firstIndex(where: { $0.id == draftID }) {
//                                        drafts[idx].description = ""
//                                        drafts[idx].image = nil
//                                        drafts[idx].name = ""
//                                        // try to delete uploaded image if not placeholder
//                                        if !isPlaceholderURL(drafts[idx].itemImageURL) {
//                                            Task { await deleteStorageImage(rankoID: rankoID, itemID: draftID) }
//                                        }
//                                        DispatchQueue.main.async { focusedField = .name(draftID) }
//                                    }
//                                } label: { Label("Clear All", systemImage: "delete.right.fill") }
//                            }
//                        }
//                        
//                        Button {
//                            let newDraft = BlankItemDraft()
//                            let newID = newDraft.id
//                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                                drafts.append(newDraft)
//                            }
//                            DispatchQueue.main.async { focusedField = .name(newID) }
//                        } label: {
//                            HStack(spacing: 12) {
//                                Image(systemName: "plus")
//                                    .font(.custom("Nunito-Black", size: 18))
//                                Text("ADD ANOTHER BLANK ITEM")
//                                    .font(.custom("Nunito-Black", size: 15))
//                            }
//                        }
//                        .buttonStyle(.glassProminent)
//                        .disabled(!canAddMore)
//                        .opacity(canAddMore ? 1 : 0.5)
//                        .padding(.top, 8)
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 12)
//                }
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarLeading) {
//                        Button {
//                            Task {
//                                isCleaningUp = true
//                                // try to delete all uploaded personal images for current drafts
//                                await deleteAllDraftImages()
//                                isCleaningUp = false
//                                dismiss()
//                            }
//                        } label: {
//                            HStack(spacing: 6) {
//                                Image(systemName: "xmark")
//                                if isCleaningUp {
//                                    ProgressView().controlSize(.mini)
//                                }
//                            }
//                        }
//                        .disabled(isCleaningUp || !imagesReady)
//                    }
//                    ToolbarItem(placement: .principal) {
//                        Text("Add New Blank Items")
//                            .font(.custom("Nunito-Black", size: 20))
//                    }
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button {
//                            // validate names
//                            let bad = drafts.first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
//                            if bad != nil {
//                                error = "please give every blank item a name (the * one)."
//                                return
//                            }
//                            
//                            // extra guard: images must be ready
//                            guard imagesReady else {
//                                error = hasUploadError
//                                ? "fix image upload errors before saving."
//                                : "please wait for images to finish uploading."
//                                return
//                            }
//                            
//                            // fill placeholder URL for any imageless drafts before commit
//                            for i in drafts.indices where drafts[i].itemImageURL == nil {
//                                drafts[i].itemImageURL = placeholderURL
//                            }
//                            error = nil
//                            onCommit()
//                            dismiss()
//                        } label: {
//                            HStack(spacing: 6) {
//                                Image(systemName: "plus")
//                                    .font(.system(size: 18, weight: .bold))
//                                // tiny spinner if anything is still uploading
//                                if anyUploading {
//                                    ProgressView().controlSize(.mini)
//                                }
//                            }
//                        }
//                        .disabled(!imagesReady)   // ← hard lock until uploads are done & clean
//                    }
//                }
//                .alert("upload error", isPresented: .init(
//                    get: { drafts.contains { $0.uploadError != nil } },
//                    set: { if !$0 { for i in drafts.indices { drafts[i].uploadError = nil } } }
//                )) {
//                    Button("ok", role: .cancel) {}
//                } message: {
//                    Text(drafts.first(where: { $0.uploadError != nil })?.uploadError ?? "unknown error")
//                }
//            }
//            .navigationTitle("")
//            .navigationBarTitleDisplayMode(.inline)
//            .sheet(isPresented: $showNewImageSheet) {
//                NewImageSheet(pickFromLibrary: {
//                    showNewImageSheet = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPhotoPicker = true }
//                })
//                .presentationDetents([.fraction(0.4)])
//                .presentationBackground(Color.white)
//            }
//            .sheet(isPresented: $showPhotoPicker) {
//                ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
//            }
//            .fullScreenCover(isPresented: $showImageCropper) {
//                if let img = imageForCropping {
//                    SwiftyCropView(
//                        imageToCrop: img,
//                        maskShape: .square,
//                        configuration: SwiftyCropConfiguration(
//                            maxMagnificationScale: 8.0,
//                            maskRadius: 190.0,
//                            cropImageCircular: false,
//                            rotateImage: false,
//                            rotateImageWithButtons: true,
//                            usesLiquidGlassDesign: true,
//                            zoomSensitivity: 3.0
//                        ),
//                        onCancel: {
//                            imageForCropping = nil
//                            showImageCropper = false
//                            restoreBackupForActiveDraft()
//                        },
//                        onComplete: { cropped in
//                            imageForCropping = nil
//                            showImageCropper = false
//                            // 👇 immediately try to upload with timeout
//                            if let id = activeDraftID { Task { await uploadCropped(cropped!, for: id) } }
//                        }
//                    )
//                }
//            }
//            .onChange(of: imageForCropping) { _, newVal in
//                if newVal != nil { showImageCropper = true }
//            }
//        }
//        
//        // Safely produce a Binding<BlankItemDraft> by id.
//        // If the draft got removed, the getter returns a harmless placeholder (so SwiftUI won’t crash during transition).
//        private func bindingForDraft(id: String) -> Binding<BlankItemDraft> {
//            Binding(
//                get: {
//                    drafts.first(where: { $0.id == id }) ?? BlankItemDraft()
//                },
//                set: { updated in
//                    if let idx = drafts.firstIndex(where: { $0.id == id }) {
//                        drafts[idx] = updated
//                    }
//                }
//            )
//        }
//
//        // Centralized, index-safe removal with focus + cleanup + animation.
//        private func removeDraft(id: String) {
//            guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
//            let draft = drafts[idx]
//
//            // try to delete uploaded image if it’s not a placeholder
//            if !isPlaceholderURL(draft.itemImageURL) {
//                Task { await deleteStorageImage(rankoID: rankoID, itemID: id) }
//            }
//
//            // compute a sensible neighbor BEFORE mutation
//            let nextFocusID: String? = {
//                if drafts.count <= 1 { return nil }
//                let neighborIndex = idx == drafts.count - 1 ? idx - 1 : idx + 1
//                return drafts[neighborIndex].id
//            }()
//
//            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                drafts.remove(at: idx)
//                if drafts.isEmpty { drafts.append(BlankItemDraft()) }
//            }
//
//            // restore focus after the view updates
//            DispatchQueue.main.async {
//                if let nid = nextFocusID, drafts.contains(where: { $0.id == nid }) {
//                    focusedField = .name(nid)
//                } else if let firstID = drafts.first?.id {
//                    focusedField = .name(firstID)
//                }
//            }
//
//            print("deleting itemID: \(id)")
//        }
//        
//        private func makeJPEGMetadata(rankoID: String, itemID: String, userID: String) -> StorageMetadata {
//            let md = StorageMetadata()
//            md.contentType = "image/jpeg"
//
//            // add some useful tags like your profile code does (timestamp, owner, etc.)
//            let now = Date()
//            let fmt = DateFormatter()
//            fmt.locale = Locale(identifier: "en_US_POSIX")
//            fmt.timeZone = TimeZone(identifier: "Australia/Sydney") // AEST/AEDT
//            fmt.dateFormat = "yyyyMMddHHmmss"
//            let ts = fmt.string(from: now)
//
//            md.customMetadata = [
//                "rankoID": rankoID,
//                "itemID": itemID,
//                "userID": userID,
//                "uploadedAt": ts
//            ]
//            return md
//        }
//
//        // MARK: - Upload w/ 10s timeout
//
//        private func uploadCropped(_ img: UIImage, for draftID: String) async {
//            guard let data = img.jpegData(compressionQuality: 0.9) else {
//                setUpload(error: "couldn't encode image", for: draftID); return
//            }
//            setUploading(true, for: draftID)
//
//            let path = "rankoPersonalImages/\(rankoID)/\(draftID).jpg"
//            let ref  = Storage.storage().reference().child(path)
//            let metadata = makeJPEGMetadata(rankoID: rankoID, itemID: draftID, userID: user_data.userID)
//
//            do {
//                try await withTimeout(seconds: 10) {
//                    _ = try await ref.putDataAsync(data, metadata: metadata)  // 👈 pass metadata
//                }
//
//                // success → set image + deterministic URL string (your requested format)
//                setUploadSuccess(image: img, url: finalURL(for: draftID), for: draftID)
//                print("image uploaded successfully for itemID: \(draftID)")
//
//                // (optional) also mirror a tiny index in Realtime DB like your profile fn:
//                // try? await setValueAsync(
//                //   Database.database().reference()
//                //     .child("RankoData").child(rankoID)
//                //     .child("RankoItemImages").child(draftID),
//                //   value: ["path": path, "modified": metadata.customMetadata?["uploadedAt"] ?? ""]
//                // )
//
//            } catch {
//                let msg: String
//                if error is TimeoutErr { msg = "upload timed out, please try again." }
//                else { msg = (error as NSError).localizedDescription }
//                setUpload(error: msg, for: draftID)
//            }
//        }
//
//        private enum TimeoutErr: Error { case timedOut }
//        private func withTimeout<T>(seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
//            try await withThrowingTaskGroup(of: T.self) { group in
//                group.addTask { try await op() }
//                group.addTask {
//                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
//                    throw TimeoutErr.timedOut
//                }
//                let result = try await group.next()!
//                group.cancelAll()
//                return result
//            }
//        }
//
//        // MARK: - Draft mutations
//
//        private func setUploading(_ uploading: Bool, for id: String) {
//            if let i = drafts.firstIndex(where: { $0.id == id }) {
//                drafts[i].isUploading = uploading
//                drafts[i].uploadError = nil
//            }
//        }
//        private func setUploadSuccess(image: UIImage, url: String, for id: String) {
//            if let i = drafts.firstIndex(where: { $0.id == id }) {
//                drafts[i].image = image
//                drafts[i].itemImageURL = url
//                drafts[i].isUploading = false
//                drafts[i].uploadError = nil
//            }
//        }
//        private func setUpload(error: String, for id: String) {
//            if let i = drafts.firstIndex(where: { $0.id == id }) {
//                drafts[i].isUploading = false
//                drafts[i].uploadError = error
//            }
//        }
//
//        private func restoreBackupForActiveDraft() {
//            guard let id = activeDraftID, let backup = backupImage,
//                  let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
//            drafts[idx].image = backup
//        }
//        
//        private func deleteAllDraftImages() async {
//            // collect every draft that has a *non-placeholder* uploaded URL
//            let targets = drafts
//                .filter { !isPlaceholderURL($0.itemImageURL) }
//                .map { $0.id }
//
//            guard !targets.isEmpty else { return }
//
//            // delete all in parallel but don't hang forever
//            do {
//                try await withTimeout(seconds: 10) {
//                    try await withThrowingTaskGroup(of: Void.self) { group in
//                        for id in targets {
//                            group.addTask {
//                                await deleteStorageImage(rankoID: rankoID, itemID: id)
//                            }
//                        }
//                        // wait (errors are already caught inside deleteStorageImage; it never throws)
//                        try await group.waitForAll()
//                    }
//                }
//            } catch {
//                // optional: you could surface a toast here if you want
//                #if DEBUG
//                print("⚠️ cleanup timeout/err: \(error.localizedDescription)")
//                #endif
//            }
//        }
//    }
//
//    // one draft card UI
//    private struct DraftCard: View {
//        @Binding var draft: BlankItemDraft
//        let title: String
//        let subtitle: String
//        let focusedField: FocusState<BlankItemsComposer.Field?>.Binding   // ✅ accept focus binding
//        var onTapImage: () -> Void
//        var onDelete: () -> Void
//
//        var body: some View {
//            VStack(alignment: .leading, spacing: 12) {
//                HStack {
//                    Text(title.uppercased())
//                        .font(.custom("Nunito-Black", size: 12))
//                        .foregroundStyle(.secondary)
//                    Spacer()
//                    if draft.isUploading { ProgressView().controlSize(.small) }
//                }
//                
//                HStack {
//                    Spacer(minLength: 0)
//                    Button(action: onTapImage) {
//                        ZStack {
//                            RoundedRectangle(cornerRadius: 14)
//                                .fill(Color.gray.opacity(0.06))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 14)
//                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
//                                )
//                                .frame(width: 240, height: 240)
//                            
//                            if let img = draft.image {
//                                Image(uiImage: img)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 240, height: 240, alignment: .center)
//                                    .clipShape(RoundedRectangle(cornerRadius: 14))
//                                    .contentShape(Rectangle())
//                            } else {
//                                VStack(spacing: 10) {
//                                    Image(systemName: "photo.on.rectangle.angled")
//                                        .font(.system(size: 28, weight: .black))
//                                        .opacity(0.35)
//                                    Text(subtitle.uppercased())
//                                        .font(.custom("Nunito-Black", size: 13))
//                                        .opacity(0.6)
//                                }
//                                .frame(width: 240, height: 240, alignment: .center)
//                                .contentShape(Rectangle())
//                            }
//                        }
//                    }
//                    .buttonStyle(.plain)
//                    .disabled(draft.isUploading)
//                    Spacer(minLength: 0)
//                }
//                .frame(maxWidth: .infinity)
//                
//                VStack(spacing: 14) {
//                    // NAME
//                    VStack(spacing: 5) {
//                        HStack {
//                            Text("Item Name".uppercased())
//                                .foregroundColor(.secondary)
//                                .font(.custom("Nunito-Black", size: 12))
//                            Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
//                            Spacer(minLength: 0)
//                        }
//                        .padding(.leading, 6)
//
//                        HStack(spacing: 6) {
//                            Image(systemName: "textformat.size.larger").foregroundColor(.gray).padding(.trailing, 1)
//                            TextField("Item Name *", text: $draft.name)
//                                .font(.custom("Nunito-Black", size: 18))
//                                .autocorrectionDisabled(true)
//                                .onChange(of: draft.name) { _, v in
//                                    if v.count > 50 { draft.name = String(v.prefix(50)) }
//                                }
//                                .foregroundStyle(.gray)
//                                .focused(focusedField, equals: .name(draft.id))   // ✅ use binding
//                                .submitLabel(.next)
//                                .onSubmit { focusedField.wrappedValue = .description(draft.id) } // ✅ jump to desc
//
//                            Spacer()
//                            Text("\(draft.name.count)/50")
//                                .font(.caption2).fontWeight(.light)
//                                .padding(.top, 15).foregroundColor(.secondary)
//                        }
//                        .padding(8)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .foregroundColor(Color.gray.opacity(0.08))
//                                .allowsHitTesting(false)
//                        )
//                    }
//
//                    // DESCRIPTION
//                    VStack(spacing: 5) {
//                        HStack {
//                            Text("Description".uppercased())
//                                .foregroundColor(.secondary)
//                                .font(.custom("Nunito-Black", size: 12))
//                                .padding(.leading, 6)
//                            Spacer(minLength: 0)
//                        }
//
//                        HStack {
//                            Image(systemName: "textformat.size.smaller").foregroundColor(.gray).padding(.trailing, 1)
//                            TextField("Item Description (optional)", text: $draft.description, axis: .vertical)
//                                .font(.custom("Nunito-Black", size: 18))
//                                .autocorrectionDisabled(true)
//                                .onChange(of: draft.description) { _, v in
//                                    if v.count > 100 { draft.description = String(v.prefix(100)) }
//                                }
//                                .lineLimit(1...3)
//                                .foregroundStyle(.gray)
//                                .focused(focusedField, equals: .description(draft.id))  // ✅ use binding
//                                .submitLabel(.done)
//                                .onSubmit { hideKeyboard() }
//
//                            Spacer()
//                            Text("\(draft.description.count)/100")
//                                .font(.caption2).fontWeight(.light)
//                                .padding(.top, 15).foregroundColor(.secondary)
//                        }
//                        .padding(8)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .foregroundColor(Color.gray.opacity(0.08))
//                                .allowsHitTesting(false)
//                        )
//                    }
//                }
//
//                HStack {
//                    if let err = draft.uploadError {
//                        Label(err, systemImage: "exclamationmark.triangle.fill")
//                            .foregroundColor(.red)
//                            .font(.caption)
//                            .lineLimit(2)
//                    }
//                    Spacer()
//                    Button(action: onDelete) {
//                        HStack {
//                            Image(systemName: "trash.fill").font(.system(size: 13, weight: .semibold))
//                            Text("DELETE").font(.custom("Nunito-Black", size: 13))
//                        }
//                    }
//                    .buttonStyle(.borderless)
//                    .disabled(draft.isUploading)
//                    .opacity(draft.isUploading ? 0.5 : 1)
//                }
//            }
//            .padding(14)
//            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
//            .onChange(of: draft.description) {
//                if draft.description.contains("\n") {
//                    hideKeyboard()
//                    draft.description = draft.description.replacingOccurrences(of: "\n", with: "")
//                }
//            }
//        }
//    }
//
//    // “photos” bottom sheet like your EditProfileView
//    private struct NewImageSheet: View {
//        var pickFromLibrary: () -> Void
//        var body: some View {
//            ScrollView {
//                VStack(spacing: 16) {
//                    HStack {
//                        Text("Photos").font(.system(size: 14, weight: .bold))
//                        Spacer()
//                        Button(action: pickFromLibrary) {
//                            Text("Show Photo Library")
//                                .font(.system(size: 14, weight: .medium))
//                                .foregroundColor(Color(hex: 0x0288FE))
//                        }
//                    }
//                    .padding(.horizontal, 24)
//
//                    // simple row buttons (camera/files hooks left for you if needed)
//                    Divider().padding(.horizontal, 24)
//                    Button(action: pickFromLibrary) {
//                        HStack(spacing: 12) {
//                            Image(systemName: "photo.stack")
//                            Text("Photo Library")
//                            Spacer()
//                        }
//                        .padding(.horizontal, 24)
//                    }
//                    Button(action: {}) {
//                        HStack(spacing: 12) {
//                            Image(systemName: "folder")
//                            Text("Files")
//                            Spacer()
//                        }
//                        .padding(.horizontal, 24)
//                    }
//                }
//                .padding(.top, 18)
//            }
//        }
//    }
//    
//    private enum PublishErr: LocalizedError {
//        case missingCategory
//        case invalidUserID
//
//        var errorDescription: String? {
//            switch self {
//            case .missingCategory: return "Please pick a category before saving."
//            case .invalidUserID:   return "Invalid user ID. Please sign in again."
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private func pill(_ title: String, system: String, isOn: Bool, action: @escaping () -> Void) -> some View {
//        Button(action: action) {
//            HStack(spacing: 6) {
//                Image(systemName: system).font(.system(size: 12, weight: .semibold))
//                Text(title).font(.custom("Nunito-Black", size: 12)).kerning(-0.2)
//            }
//            .padding(.vertical, 8).padding(.horizontal, 12)
//            .background(
//                Capsule(style: .continuous)
//                    .fill(isOn ? Color(hex: 0x6D400F) : Color(hex: 0xEDB26E).opacity(0.25))
//            )
//            .foregroundStyle(isOn ? .white : Color(hex: 0x6D400F))
//        }
//        .buttonStyle(.plain)
//    }
//    
//    private func uploadPersonalImagesAsync() async throws {
//        guard !pendingPersonalImages.isEmpty else { return }
//
//        let storage = Storage.storage()
//        let bucketPathRoot = "rankoPersonalImages/\(rankoID)" // use your listUUID as rankoID
//
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            for (itemID, image) in pendingPersonalImages {
//                group.addTask {
//                    let ref = storage.reference().child("\(bucketPathRoot)/\(itemID).jpg")
//                    guard let data = image.jpegData(compressionQuality: 0.9) else {
//                        throw PublishErr.invalidUserID // reusing an error; you can add a dedicated one
//                    }
//                    _ = try await ref.putDataAsync(data, metadata: nil)
//                }
//            }
//            try await group.waitForAll()
//        }
//    }
//    
//    private func deleteRankoPersonalFolderAsync(rankoID: String) async {
//        let root = Storage.storage().reference()
//            .child("rankoPersonalImages")
//            .child(rankoID)
//        await deleteAllRecursively(at: root)
//    }
//
//    private func deleteAllRecursively(at ref: StorageReference) async {
//        do {
//            let list = try await ref.listAll()
//            try await withThrowingTaskGroup(of: Void.self) { group in
//                for item in list.items {
//                    group.addTask {
//                        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//                            item.delete { err in
//                                if let err = err { cont.resume(throwing: err) }
//                                else { cont.resume() }
//                            }
//                        }
//                    }
//                }
//                for prefix in list.prefixes {
//                    group.addTask { await deleteAllRecursively(at: prefix) }
//                }
//                try await group.waitForAll()
//            }
//            // Folders aren't real objects; deleting ref is typically a no-op, ignore errors.
//            _ = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//                ref.delete { _ in cont.resume() }
//            }
//        } catch {
//            #if DEBUG
//            print("⚠️ failed to purge \(ref.fullPath): \(error.localizedDescription)")
//            #endif
//        }
//    }
//    
//    private func appendDraftsToSelectedRanko() {
//        let placeholderURL = "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
//        var nextRank = (unGroupedItems.map(\.rank).max() ?? 0) + 1
//
//        for draft in blankDrafts {
//            let newItemID = UUID().uuidString
//            let url = draft.itemImageURL ?? placeholderURL
//
//            let rec = RankoRecord(
//                objectID: newItemID,
//                ItemName: draft.name,
//                ItemDescription: draft.description,
//                ItemCategory: "",
//                ItemImage: url,
//                ItemGIF: draft.gif,
//                ItemVideo: draft.video,
//                ItemAudio: draft.audio
//            )
//            let item = RankoItem(id: newItemID, rank: nextRank, votes: 0, record: rec, playCount: 0)
//            unGroupedItems.append(item)
//            nextRank += 1
//        }
//
//        blankDrafts = [BlankItemDraft()]
//        draftError = nil
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
//                        GroupItemCell(
//                            item: item,
//                            contentDisplay: contentMode,
//                            itemSize: sizeMode
//                        )
//                        .onDrag { NSItemProvider(object: item.id as NSString) }
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
//    func saveRankedListToAlgolia() {
//        guard let category = category else {
//            print("❌ Cannot save: no category selected")
//            return
//        }
//
//        let now = Date()
//        let aedtFormatter = DateFormatter()
//        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
//        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
//        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
//        let rankoDateTime = aedtFormatter.string(from: now)
//
//        // 1) Build Group List Codable Struct
//        let listRecord = RankoListAlgolia(
//            objectID:         rankoID,
//            RankoName:        rankoName,
//            RankoDescription: description,
//            RankoType:        "default",
//            RankoPrivacy:     isPrivate,
//            RankoStatus:      "active",
//            RankoCategory:    category.name,
//            RankoUserID:      user_data.userID,
//            RankoCreated:    rankoDateTime,
//            RankoUpdated:    rankoDateTime,
//            RankoLikes:       0,
//            RankoComments:    0,
//            RankoVotes:       0
//        )
//
//        // 3) Upload to Algolia
//        let group = DispatchGroup()
//
//        group.enter()
//        listsIndex.saveObject(listRecord) { result in
//            switch result {
//            case .success:
//                print("✅ List uploaded to Algolia")
//            case .failure(let error):
//                print("❌ Error uploading list: \(error)")
//            }
//            group.leave()
//        }
//
//        group.notify(queue: .main) {
//            print("🎉 Upload to Algolia completed")
//        }
//    }
//
//    func saveRankedListToFirebase() {
//        // 1) Make sure we actually have a category
//        guard let category = category else {
//            print("❌ Cannot save: no category selected")
//            return
//        }
//
//        let db = Database.database().reference()
//        
//        
//        var rankoItemsDict: [String: Any] = [:]
//
//        for (r, row) in groupedItems.enumerated() {
//            let rowCode = String(format: "%03d", r + 1)
//            for (c, item) in row.enumerated() {
//                let colCode = String(format: "%03d", c + 1)
//                let rankString = rowCode + colCode
//                let rankInt = Int(rankString) ?? (r * 1000 + c)
//
//                // ✅ Generate a unique key per item
//                let itemID = UUID().uuidString
//
//                rankoItemsDict[itemID] = [
//                    "ItemID":          itemID,
//                    "ItemName":        item.itemName,
//                    "ItemDescription": item.itemDescription,
//                    "ItemImage":       item.itemImage,
//                    "ItemRank":        rankInt,
//                    "ItemVotes":       0
//                ]
//            }
//        }
//
//        // 3) Prepare both AEDT and local timestamps
//        let now = Date()
//
//        let aedtFormatter = DateFormatter()
//        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
//        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
//        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
//        let rankoDateTime = aedtFormatter.string(from: now)
//
//        // 4) Top-level list payload with both fields
//        let listDataForFirebase: [String: Any] = [
//            "RankoID":          rankoID,
//            "RankoName":        rankoName,
//            "RankoDescription": description,
//            "RankoType":        "group",
//            "RankoPrivacy":     isPrivate,
//            "RankoStatus":      "active",
//            "RankoCategory":    category.name,
//            "RankoUserID":      user_data.userID,
//            "RankoItems":       rankoItemsDict,
//            "RankoDateTime":    rankoDateTime,
//            "RankoTiers":       tiersPayload()              // 👈 NEW
//        ]
//
//        // 5) Write the main list node
//        db.child("RankoData")
//          .child(rankoID)
//          .setValue(listDataForFirebase) { error, _ in
//            if let err = error {
//                print("❌ Error saving list: \(err.localizedDescription)")
//            } else {
//                print("✅ List saved successfully")
//            }
//        }
//
//        // 6) Write the user’s index of lists
//        db.child("UserData")
//          .child(user_data.userID)
//          .child("UserRankos")
//          .child("UserActiveRankos")
//          .child(rankoID)
//          .setValue(category.name) { error, _ in
//            if let err = error {
//                print("❌ Error saving list to user: \(err.localizedDescription)")
//            } else {
//                print("✅ List saved successfully to user")
//            }
//        }
//    }
//    
//    private func tiersPayload() -> [String: Any] {
//        var out: [String: Any] = [:]
//        for (i, t) in tiers.enumerated() {
//            let key = String(format: "%03d", i + 1)   // keep order stable
//            out[key] = [
//                "Code": t.code,
//                "Label": t.label,
//                "ColorHex": String(format: "%06X", t.colorHex) // store as hex string too
//            ]
//        }
//        return out
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
//    struct GroupItemCell: View {
//        let item: RankoItem
//        let contentDisplay: ContentDisplay
//        let itemSize: ItemSize
//
//        private var isVertical: Bool { itemSize == .large }
//
//        var body: some View {
//            Group {
//                if isVertical {
//                    VStack(spacing: 10) {
//                        imageView
//                        textStack
//                    }
//                } else {
//                    HStack(spacing: 8) {
//                        imageView
//                        textStack
//                    }
//                }
//            }
//            .padding(8)
//            .background(
//                RoundedRectangle(cornerRadius: 12, style: .continuous)
//                    .fill(Color.white)
//                    .shadow(radius: 1)
//            )
//        }
//
//        @ViewBuilder
//        private var imageView: some View {
//            if contentDisplay != .textOnly {
//                AsyncImage(url: URL(string: item.itemImage)) { phase in
//                    switch phase {
//                    case .empty:  Color.gray.opacity(0.15)
//                    case .failure: Color.gray.opacity(0.25)
//                    case .success(let img): img.resizable().scaledToFill()
//                    @unknown default: Color.gray.opacity(0.15)
//                    }
//                }
//                .frame(width: itemSize.thumb, height: itemSize.thumb)
//                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            }
//        }
//
//        @ViewBuilder
//        private var textStack: some View {
//            if contentDisplay != .imageOnly {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(item.itemName)
//                        .font(.custom("Nunito-Black", size: itemSize.nameFont))
//                        .lineLimit(1)
//                    if !item.itemDescription.isEmpty {
//                        Text(item.itemDescription)
//                            .font(.system(size: itemSize.descFont, weight: .regular))
//                            .foregroundStyle(.secondary)
//                            .lineLimit(1)
//                    }
//                }
//                .frame(minWidth: 60, alignment: .leading)
//            }
//        }
//    }
//    
//    struct GroupRow: View {
//        let rowIndex: Int
//        let tier: TierConfig
//        let items: [RankoItem]
//        
//        @Binding var itemRows: [[RankoItem]]
//        @Binding var unGroupedItems: [RankoItem]
//        @Binding var hoveredRow: Int?
//        @Binding var selectedDetailItem: RankoItem?
//
//        let layout: RowLayout
//        let contentDisplay: ContentDisplay
//        let itemSize: ItemSize
//        var onEditTiers: () -> Void = {}
//
//        var body: some View {
//            HStack(alignment: .top, spacing: 4) {
//                TierHeader(tier: tier)
//
//                switch layout {
//                case .noWrap:
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: itemSize == .large ? 8 : 4) {
//                            ForEach(items) { item in
//                                GroupItemCell(item: item, contentDisplay: contentDisplay, itemSize: itemSize)
//                                    .onDrag { NSItemProvider(object: item.id as NSString) }
//                                    .onTapGesture { selectedDetailItem = item }
//                            }
//                        }
//                        .padding(8)
//                    }
//                case .wrap:
//                    FlowLayout2(spacing: itemSize == .large ? 8 : 6) {
//                        ForEach(items) { item in
//                            GroupItemCell(item: item, contentDisplay: contentDisplay, itemSize: itemSize)
//                                .onDrag { NSItemProvider(object: item.id as NSString) }
//                                .onTapGesture { selectedDetailItem = item }
//                        }
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding([.leading, .bottom, .trailing], 8)
//                }
//            }
//            .frame(minHeight: 60)
//            .background(
//                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFFFFF)).shadow(radius: 2)
//            )
//            .overlay(highlightOverlay)
//            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
//            .onDrop(of: ["public.text"], delegate:
//                RowDropDelegate(itemRows: $itemRows, unGrouped: $unGroupedItems, hoveredRow: $hoveredRow, targetRow: rowIndex)
//            )
//            .contextMenu {
//                Button { onEditTiers() } label: { Label("Edit Tiers…", systemImage: "pencil") }
//                Divider()
//                Button(role: .destructive) {} label: { Label("Delete Tier", systemImage: "trash") }
//            }
//        }
//
//        @ViewBuilder private var highlightOverlay: some View {
//            if hoveredRow == rowIndex {
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
//                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
//            }
//        }
//    }
//    
//    struct GroupListHeaderAndRows: View {
//        // header
//        let rankoName: String
//        let description: String
//        let isPrivate: Bool
//        let category: SampleCategoryChip?
//        let categoryChipIconColors: [String: Color]
//
//        // data
//        @Binding var groupedItems: [[RankoItem]]
//        @Binding var unGroupedItems: [RankoItem]
//        @Binding var hoveredRow: Int?
//        @Binding var selectedDetailItem: RankoItem?
//
//        // knobs
//        @Binding var wrapMode: RowLayout
//        @Binding var contentDisplay: ContentDisplay
//        @Binding var itemSize: ItemSize
//
//        // helpers provided by parent
//        let tierForRow: (Int) -> Tier
//
//        var body: some View {
//            
//        }
//
//        // add-row button reused in all branches
//        private var addRowButton: some View {
//            Button {
//                groupedItems.append([])
//            } label: {
//                HStack {
//                    Image(systemName: "plus")
//                        .foregroundColor(.white)
//                        .fontWeight(.bold)
//                        .font(.headline)
//                }
//                .padding(.vertical, 12)
//                .frame(maxWidth: .infinity)
//                .background(Color(hex: 0x6D400F))
//                .cornerRadius(8)
//                .padding(.horizontal)
//            }
//        }
//    }
//    
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
//    
//    struct VerticalDropdownPicker<T: OrderedKnob>: View where T.AllCases == [T] {
//        @Binding var selection: T
//        @State private var isExpanded = false
//
//        let title: (T) -> String
//        let systemIcon: (T) -> String
//        let accent: Color
//
//        private var order: [T] { T.ordered }
//
//        private var above: [T] {
//            guard let idx = order.firstIndex(of: selection) else { return [] }
//            return Array(order.prefix(idx).reversed())
//        }
//        private var below: [T] {
//            guard let idx = order.firstIndex(of: selection) else { return [] }
//            return Array(order.suffix(from: idx + 1))
//        }
//
//        var body: some View {
//            VStack(spacing: 6) {
//                if isExpanded {
//                    ForEach(above, id: \.self) { option in
//                        optionButton(option, subtle: true) { selection = option; isExpanded = false }
//                    }
//                }
//                optionButton(selection, subtle: false) {
//                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { isExpanded.toggle() }
//                }
//                if isExpanded {
//                    ForEach(below, id: \.self) { option in
//                        optionButton(option, subtle: true) { selection = option; isExpanded = false }
//                    }
//                }
//            }
//            .animation(.easeInOut(duration: 0.18), value: isExpanded)
//        }
//
//        @ViewBuilder
//        private func optionButton(_ option: T, subtle: Bool, _ action: @escaping () -> Void) -> some View {
//            Button(action: action) {
//                HStack(spacing: 6) {
//                    Image(systemName: systemIcon(option)).font(.system(size: 12, weight: .semibold))
//                    Text(title(option)).font(.custom("Nunito-Black", size: 12)).kerning(-0.2)
//                }
//                .padding(.vertical, 8)
//                .padding(.horizontal, 12)
//                .frame(minWidth: 96)
//                .background(Capsule(style: .continuous).fill(subtle ? accent.opacity(0.12) : accent))
//                .foregroundStyle(subtle ? accent : .white)
//                .contentShape(Rectangle())
//            }
//            .buttonStyle(.plain)
//            .transition(.move(edge: subtle ? .bottom : .top).combined(with: .opacity))
//        }
//    }
//}













