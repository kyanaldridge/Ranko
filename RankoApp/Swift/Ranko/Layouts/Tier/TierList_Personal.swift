//
//  TierList_Personal.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
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

private extension CGRect {
    var center: CGPoint { .init(x: midX, y: midY) }
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

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? { (self?.isEmpty ?? true) ? nil : self }
}

// MARK: - GROUP LIST VIEW
struct TierListPersonal: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    
    @AppStorage("group_wrap_mode")    private var wrapMode: RowLayout = .wrap
    @AppStorage("group_content_mode") private var contentMode: ContentDisplay = .textAndImage
    @AppStorage("group_size_mode")    private var sizeMode: ItemSize = .medium
    
    // Required property
    let rankoID: String
    
    // MARK: - RANKO LIST DATA
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var categoryName: String = "Unknown"
    @State private var categoryIcon: String = "questionmark"
    @State private var categoryColour: UInt = 0xFFFFFF
    @State private var tags: [String] = []
    
    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategoryName: String = ""
    @State private var originalCategoryIcon: String = ""
    @State private var originalCategoryColour: UInt = 0xFFFFFF
    
    // Sheet states
    @State private var possiblyEdited = false
    @State private var showTabBar = true
    @State private var showEmbeddedStickyPoolSheet = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State private var onSave: (RankoItem) -> Void
    private let onDelete: (() -> Void)?
    
    @State private var addButtonTapped: Bool = false
    @State private var editButtonTapped: Bool = false
    @State private var exitButtonTapped: Bool = false
    
    @State private var addFrame: CGRect = .zero
    @State private var sampleFrame: CGRect = .zero
    @State private var blankFrame: CGRect = .zero
    
    @State private var exitFrame: CGRect = .zero
    @State private var saveFrame: CGRect = .zero
    @State private var cancelFrame: CGRect = .zero
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
    
    @State private var tiers: [TierConfig] = TierConfig.starter(3)
    @State private var stagingTiers: [TierConfig] = []   // ← working copy for the sheet
    @State private var showTierEditor = false
    
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
    // MARK: - INITIALISER
    init(
        rankoID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        groupedItems: [[RankoItem]] = [],     // ← fix type & default
        onSave: @escaping (RankoItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.rankoID = rankoID
        self.onDelete = onDelete
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _groupedItems = State(initialValue: groupedItems)       // ← no force-cast
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName ?? "")
        _originalDescription = State(initialValue: description ?? "")
        _originalIsPrivate = State(initialValue: isPrivate ?? false)
        _originalCategoryName = State(initialValue: categoryName)
        _originalCategoryIcon = State(initialValue: categoryIcon)
        _originalCategoryColour = State(initialValue: categoryColour)
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
                                                    // Delete
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "square.dashed")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 20, height: 20)
                                                        Text("Blank")
                                                            .font(.custom("Nunito-Black", size: 11))
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
                                                            print("Blank would open")
                                                            withAnimation { addButtonTapped = false }
                                                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                            impact.prepare()
                                                            impact.impactOccurred(intensity: 1.0)
                                                        }
                                                    )
                                                    
                                                    // Save
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
                                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                            exitButtonTapped.toggle()
                                                        }
                                                        let impact = UIImpactFeedbackGenerator(style: .soft)
                                                        impact.prepare(); impact.impactOccurred(intensity: 0.8)
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                        .overlay(alignment: .top) {
                                            if exitButtonTapped {
                                                HStack(spacing: -10) {
                                                    // DELETE
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "trash.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 17,
                                                                   height: 17)
                                                        Text("Delete")
                                                            .font(.custom("Nunito-Black", size: 10))
                                                    }
                                                    .frame(width: 60, height: 60)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { deleteFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in deleteFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .onTapGesture {
                                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                        impact.prepare(); impact.impactOccurred(intensity: 1.0)
                                                        withAnimation { exitButtonTapped = false }
                                                        showDeleteAlert = true
                                                    }
                                                    .offset(y: -40)
                                                    
                                                    // CANCEL (new) → dismiss
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 17,
                                                                   height: 17)
                                                        Text("Cancel")
                                                            .font(.custom("Nunito-Black", size: 10))
                                                    }
                                                    .frame(width: 60, height: 60)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { cancelFrame = gp.frame(in: .named("exitbar")) }   // 👈 capture Cancel frame
                                                                .onChange(of: gp.size) { _, _ in cancelFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .onTapGesture {
                                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                                        impact.prepare(); impact.impactOccurred(intensity: 0.9)
                                                        withAnimation { exitButtonTapped = false }
                                                        dismiss()
                                                    }
                                                    .offset(y: -55)
                                                    
                                                    // SAVE
                                                    VStack(spacing: 5) {
                                                        Image(systemName: "square.and.arrow.down.fill")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 17,
                                                                   height: 17)
                                                        Text("Save")
                                                            .font(.custom("Nunito-Black", size: 10))
                                                    }
                                                    .frame(width: 60, height: 60)
                                                    .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                                    .background(
                                                        GeometryReader { gp in
                                                            Color.clear
                                                                .onAppear { saveFrame = gp.frame(in: .named("exitbar")) }
                                                                .onChange(of: gp.size) { _, _ in saveFrame = gp.frame(in: .named("exitbar")) }
                                                        }
                                                    )
                                                    .onTapGesture {
                                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                                        impact.prepare(); impact.impactOccurred(intensity: 1.0)
                                                        withAnimation { exitButtonTapped = false }
                                                        startSave()
                                                    }
                                                    .offset(y: -40)
                                                }
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
            .overlay {
                if progressLoading {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView("Saving Ranko…") // 👈 your requested copy
                                .padding(.vertical, 8)
                            Text("Waiting for Firebase + Algolia")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .onAppear {
                loadListFromFirebase()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color(hex: 0x000000))
                }
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
            .interactiveDismissDisabled(progressLoading) // block sheet swipe
            .disabled(progressLoading)                   // block touches
            .alert("Couldn't save", isPresented: .init(
                get: { publishError != nil },
                set: { if !$0 { publishError = nil } }
            )) {
                Button("Retry") { startSave() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(publishError ?? "Something went wrong.")
            }
            .refreshable {
                refreshItemImages()
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
//            .alert(isPresented: $showDeleteAlert) {
//                CustomDialog(
//                    title: "Delete Ranko?",
//                    content: "Are you sure you want to delete your Ranko.",
//                    image: .init(
//                        content: "trash.fill",
//                        background: .red,
//                        foreground: .white
//                    ),
//                    button1: .init(
//                        content: "Delete",
//                        background: .red,
//                        foreground: .white,
//                        action: { _ in
//                            showDeleteAlert = false
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
//                                removeFeaturedRanko(rankoID: rankoID) { success in }
//                                deleteRanko() { success in
//                                    if success {
//                                        print("🎉 Fields updated in Algolia")
//                                    } else {
//                                        print("⚠️ Failed to update fields")
//                                    }
//                                }
//                                onDelete!()
//                                dismiss()
//                            }
//                        }
//                    ),
//                    button2: .init(
//                        content: "Cancel",
//                        background: .orange,
//                        foreground: .white,
//                        action: { _ in
//                            showDeleteAlert = false
//                        }
//                    )
//                )
//                .transition(.blurReplace.combined(with: .push(from: .bottom)))
//            }
            .interactiveDismissDisabled(true)
        }
    }
    
    private func intFromAny(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String, let i = Int(s) { return i }
        return nil
    }

    private func doubleFromAny(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String, let d = Double(s) { return d }
        return nil
    }

    /// normalizes hex like "#FFC800", "0xFFC800", "FFC800", "FC8" → "0xRRGGBB" (no alpha)
    private func normalizeHexString(_ s: Any?) -> String {
        guard var raw = (s as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "0x514343" }
        raw = raw.lowercased()
        if raw.hasPrefix("#")  { raw.removeFirst() }
        if raw.hasPrefix("0x") { raw.removeFirst(2) }
        if raw.count == 3 { // shorthand RGB
            raw = raw.map { String(repeating: $0, count: 2) }.joined()
        }
        // strip alpha if 8 chars
        if raw.count == 8 { raw = String(raw.prefix(6)) }
        return "0x" + raw.uppercased()
    }

    /// builds decimal rank if missing (row + position/10000)
    private func decimalRank(row: Int, position: Int) -> Double {
        Double(row) + (Double(position) / 10000.0)
    }

    /// take a decimal rank and return (row, position) if server didn’t store Row/Position
    private func rowPos(from decimal: Double) -> (row: Int, pos: Int) {
        let row = Int(floor(decimal))
        let pos = max(1, Int(round((decimal - floor(decimal)) * 10000.0)))
        return (row, pos)
    }

    private func parseHexUInt(_ s: String) -> UInt? {
        var str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.lowercased().hasPrefix("0x") { str.removeFirst(2) }
        return UInt(str, radix: 16)
    }
    
    @inline(__always)
    private func dbg(_ msg: String) {
        print("🧪 [TierListPersonal] \(msg)")
    }

    // MARK: - Loader
    private func loadListFromFirebase() {
        let ref = Database.database().reference()
            .child("RankoData")
            .child(rankoID)
        
        dbg("➡️ starting load for path: /RankoData/\(rankoID)")
        progressLoading = true
        
        ref.observeSingleEvent(of: .value, with: { snap in
            guard snap.exists() else {
                dbg("❌ snapshot doesn't exist for \(self.rankoID)")
                DispatchQueue.main.async { self.progressLoading = false }
                return
            }
            guard let dict = snap.value as? [String: Any] else {
                dbg("❌ couldn't cast snapshot.value → [String:Any]. raw=\(String(describing: snap.value))")
                DispatchQueue.main.async { self.progressLoading = false }
                return
            }
            dbg("Checkpoint A — root keys: \(Array(dict.keys).sorted())")
            
            // ── DETAILS (name/desc/type/user) ─────────────────────────────────
            let details = dict["RankoDetails"] as? [String: Any] ?? [:]
            dbg("Checkpoint B — RankoDetails keys: \(Array(details.keys).sorted())")
            
            guard
                let name   = details["name"] as? String,
                let desc   = details["description"] as? String
            else {
                dbg("❌ DETAILS guard failed. values: " +
                    "name=\(String(describing: details["name"])) " +
                    "desc=\(String(describing: details["description"])) " +
                    "type=\(String(describing: details["type"])) " +
                    "user_id=\(String(describing: details["user_id"]))")
                DispatchQueue.main.async { self.progressLoading = false }
                return
            }
            
            let tags = details["tags"] as? [String] ?? []
            
            // ── PRIVACY (nested object) ───────────────────────────────────────
            let privacy = dict["RankoPrivacy"] as? [String: Any] ?? [:]
            let privacyBool = (privacy["private"] as? Bool) ?? false
            dbg("Checkpoint C — privacy.private=\(privacyBool)")
            
            // ── DATE/TIME (nested object) ─────────────────────────────────────
            let dt = dict["RankoDateTime"] as? [String: Any] ?? [:]
            let created = (dt["created"] as? String) ?? ""
            let updated = (dt["updated"] as? String) ?? created
            dbg("Checkpoint D — created=\(created) updated=\(updated)")
            
            // ── CATEGORY (nested) ─────────────────────────────────────────────
            let cat = dict["RankoCategory"] as? [String: Any] ?? [:]
            let catName  = (cat["name"] as? String) ?? ""
            let catIcon  = (cat["icon"] as? String) ?? ""
            let catColourUInt: UInt = {
                if let s = cat["colour"] as? String { return parseHexUInt(s) ?? 0xFFFFFF }
                if let n = cat["colour"] as? Int   { return UInt(n) }
                return 0xFFFFFF
            }()
            dbg("Checkpoint E — Category name='\(catName)' icon='\(catIcon)' colour=\(String(format:"0x%06X", catColourUInt))")
            
            // ── TIERS (array, 1-based, first element null) ────────────────────
            // Example (index 1..7): { Code:"S", ColorHex:12862774, Index:1, Label:"Legendary" }
            let tiersAny = dict["RankoTiers"]
            let tiersArray = tiersAny as? [Any] ?? []     // allow null @ index 0
            dbg("Checkpoint F — tiers array count=\(tiersArray.count) (expect >= 2 with index 0 null)")
            
            struct RankoTierLight { let index:Int; let code:String; let label:String; let colorHexInt:Int }
            
            let loadedTiers: [RankoTierLight] = tiersArray.compactMap { e in
                guard let t = e as? [String: Any] else { return nil }    // skips the leading null
                guard
                    let idx = intFromAny(t["Index"]),
                    let code = t["Code"] as? String,
                    let label = t["Label"] as? String
                else { return nil }
                // ColorHex in your export is an Int (e.g., 12862774)
                let colorInt = intFromAny(t["ColorHex"]) ?? 0xBFA254
                return RankoTierLight(index: idx, code: code, label: label, colorHexInt: colorInt)
            }
                .sorted { $0.index < $1.index }
            
            dbg("Checkpoint G — parsed tiers: \(loadedTiers.map { "#\($0.index)=\($0.code):\($0.label)@\(String(format:"0x%06X", $0.colorHexInt))" })")
            
            let finalTierConfigs: [TierConfig] = {
                let mapped = loadedTiers.map { TierConfig(code: $0.code, label: $0.label, colorHex: $0.colorHexInt) }
                return mapped.isEmpty ? TierConfig.starter(3) : mapped
            }()
            dbg("Checkpoint H — TierConfig count: \(finalTierConfigs.count)")
            
            // ── ITEMS ─────────────────────────────────────────────────────────
            let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
            dbg("Checkpoint I — items node found: \(itemsDict.count) entries")
            
            let items: [RankoItem] = itemsDict.compactMap { (itemID, item) -> RankoItem? in
                guard
                    let itemName  = item["ItemName"] as? String,
                    let itemDesc  = item["ItemDescription"] as? String,
                    let itemImage = item["ItemImage"] as? String
                else {
                    dbg("⚠️ item '\(itemID)' missing required fields. keys=\(Array(item.keys))")
                    return nil
                }
                
                let rankFloat  = doubleFromAny(item["ItemRank"]) ?? 0.0
                let votes      = intFromAny(item["ItemVotes"]) ?? 0
                
                let record = RankoRecord(
                    objectID: itemID,
                    ItemName: itemName,
                    ItemDescription: itemDesc,
                    ItemCategory: (item["ItemCategory"] as? String) ?? "category",
                    ItemImage: itemImage,
                    ItemGIF: (item["ItemGIF"] as? String).nilIfEmpty,
                    ItemVideo: (item["ItemVideo"] as? String).nilIfEmpty,
                    ItemAudio: (item["ItemAudio"] as? String).nilIfEmpty
                )
                
                return RankoItem(
                    id: itemID,
                    rank: Int(rankFloat * 10000),     // keep a stable sort if needed
                    votes: votes,
                    record: record,
                    playCount: intFromAny(item["PlayCount"]) ?? 0
                )
            }
            
            dbg("Checkpoint J — parsed items: \(items.count)")
            
            // group by tier index:
            // if no explicit per-item tier index exists, derive it from integer part of ItemRank (e.g., 1.0001 → tier 1)
            let tierCount = max(finalTierConfigs.count, 1)
            var rows = Array(repeating: [RankoItem](), count: tierCount)
            
            // quick map for lookup
            let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            
            // try explicit keys first; if none, fallback to derived
            var hadExplicit = false
            for (itemID, raw) in itemsDict {
                if let idx1 = ["ItemTierIndex", "TierIndex", "Tier"].compactMap({ intFromAny(raw[$0]) }).first,
                   let itm = byID[itemID], idx1 >= 1, idx1 <= tierCount {
                    rows[idx1 - 1].append(itm)
                    hadExplicit = true
                }
            }
            
            if !hadExplicit {
                dbg("ℹ️ no explicit per-item tier index found; deriving from ItemRank’s integer part")
                for (itemID, raw) in itemsDict {
                    let rankFloat = doubleFromAny(raw["ItemRank"]) ?? 0.0
                    let idx = min(max(Int(floor(rankFloat)), 1), tierCount)   // 1-based
                    if let itm = byID[itemID] {
                        rows[idx - 1].append(itm)
                    }
                }
            }
            
            let finalRows: [[RankoItem]] = rows.map { $0.sorted { $0.rank < $1.rank } }
            dbg("Checkpoint K — grouped rows counts by tier: \(finalRows.map(\.count))")
            
            // ── PUSH INTO UI (MAIN THREAD) ────────────────────────────────────
            DispatchQueue.main.async {
                self.progressLoading = false
                
                // toolbar title stack inputs
                self.rankoName      = name
                self.description    = desc
                self.isPrivate      = privacyBool
                self.categoryName   = catName
                self.categoryIcon   = catIcon
                self.categoryColour = UInt("0x" + String(catColourUInt, radix: 16, uppercase: true)) ?? 0xFFFFFF
                self.tags           = tags
                
                // tiers + items
                self.tiers          = finalTierConfigs
                self.unGroupedItems = items.sorted { $0.rank < $1.rank }
                self.groupedItems   = finalRows
                
                // originals (for revert)
                self.originalRankoName = self.rankoName
                self.originalDescription = self.description
                self.originalIsPrivate = self.isPrivate
                self.originalCategoryName = self.categoryName
                self.originalCategoryIcon = self.categoryIcon
                self.originalCategoryColour = self.categoryColour
                
                self.imageReloadToken = UUID()
                
                dbg("✅ UI state updated — name='\(self.rankoName)' tiers=\(self.tiers.count) rows=\(self.groupedItems.count)")
            }
        })
    }

    /// Parses "YYYYMMDDhhmmss" or seconds-since-epoch to Date.
    private func parseYYYYMMDDhhmmss(_ any: Any?) -> Date? {
        if let s = any as? String {
            // try strict "yyyyMMddHHmmss"
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMddHHmmss"
            if let d = f.date(from: s) { return d }
            // try seconds since epoch in string
            if let secs = TimeInterval(s) { return Date(timeIntervalSince1970: secs) }
        } else if let n = any as? TimeInterval {
            return Date(timeIntervalSince1970: n)
        } else if let i = any as? Int {
            return Date(timeIntervalSince1970: TimeInterval(i))
        }
        return nil
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
            Text(showSelectionBar
                 ? "Selection active — dragging is disabled here"
                 : "Drag the below items to groups")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top, 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(unGroupedItems) { item in
                        // ⛔️ No selection UI in the sticky pool
                        TierItemCell(
                            item: item,
                            contentDisplay: contentMode,
                            itemSize: sizeMode,
                            showSelectionBar: false,        // <- force OFF
                            isSelected: false,
                            onSelect: { _ in }               // unused
                        )
                        // Only allow dragging when not in selection mode
                        .modifier(DragIfEnabled(enabled: !showSelectionBar, id: item.id))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        // Only allow dropping when not in selection mode
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
    
    func normalizeHexString(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        if s.hasPrefix("#") { s.removeFirst() }
        // keep only hex digits
        s = s.filter { "0123456789abcdefABCDEF".contains($0) }
        guard let intVal = UInt32(s, radix: 16) else { return "0x446D7A" }
        return String(format: "0x%06X", intVal)
    }
    
    private func startSave() {
        // Basic guard like DefaultList
        guard !categoryName.isEmpty else {
            publishError = "Please pick a category before saving."
            return
        }
        progressLoading = true
        publishError = nil

        let group = DispatchGroup()
        var firebaseOK = false
        var algoliaOK = false
        var firstError: String?

        // 1) Firebase
        group.enter()
        updateTierListInFirebase { success, err in
            firebaseOK = success
            if !success, firstError == nil { firstError = err ?? "Firebase save failed." }
            group.leave()
        }

        // 2) Algolia (partial updates)
        group.enter()
        updateTierListInAlgolia(
            rankoID: rankoID,
            newName: rankoName,
            newDescription: description,
            newCategory: categoryName,
            isPrivate: isPrivate
        ) { success in
            algoliaOK = success
            if !success, firstError == nil { firstError = "Algolia update failed." }
            group.leave()
        }

        group.notify(queue: .main) {
            progressLoading = false
            if firebaseOK && algoliaOK {
                print("Saved RankoID: \(rankoID) --- \(rankoName)")
                dismiss()
                
            } else {
                publishError = firstError ?? "Failed to save."
            }
        }
    }
    
    private func updateTierListInFirebase(completion: @escaping (Bool, String?) -> Void) {
        let db = Database.database().reference()

        // 1) Items map (id -> fields)
        // Row indices are 1-based (tier 1..N). Position is 1..rowCount.
        var itemsDict: [String: Any] = [:]
        for (rowIdx, row) in groupedItems.enumerated() {
            let rowNumber = rowIdx + 1
            for (pos, item) in row.enumerated() {
                let position = pos + 1
                // Maintain your decimal rank style: row + position/10000
                let decimal = decimalRank(rowNumber: rowNumber, position: position)

                let rec = item.record
                itemsDict[item.id] = [
                    "ItemID":          item.id,
                    "ItemName":        rec.ItemName,
                    "ItemDescription": rec.ItemDescription,
                    "ItemCategory":    rec.ItemCategory,
                    "ItemImage":       rec.ItemImage,
                    "ItemGIF":         rec.ItemGIF ?? "",
                    "ItemVideo":       rec.ItemVideo ?? "",
                    "ItemAudio":       rec.ItemAudio ?? "",
                    "ItemRank":        decimal,
                    "ItemRow":         rowNumber,
                    "ItemPosition":    position,
                    "ItemVotes":       item.votes,
                    "PlayCount":       item.playCount
                ]
            }
        }

        // 2) Category object (string hex like "0xFFC800")
        let categoryDict: [String: Any] = [
            "colour": categoryColour,
            "icon":   categoryIcon,
            "name":   categoryName
        ]

        // 3) Details / Privacy / Stats
        let normalizedTags: [String] = tags.isEmpty ? ["ranko", categoryName.lowercased()] : tags
        let now = Int(Date().timeIntervalSince1970)

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

        // 4) Tiers block from your `tiers` model
        let tiersDict = tiersPayload(from: tiers) // uses your helper below

        // 5) Final payload
        let payload: [String: Any] = [
            "RankoDetails":    rankoDetails,
            "RankoCategory":   categoryDict,
            "RankoPrivacy":    rankoPrivacy,
            "RankoStatistics": rankoStats,
            "RankoDateTime":   ["updated": now, "created": now],
            "RankoTiers":      tiersDict,
            "RankoItems":      itemsDict,

            // init empties to match your schema
            "RankoLikes":      [:],
            "RankoComments":   [:]
        ]

        // 6) Run both writes like you do elsewhere (list + mirror under user)
        let listRef  = db.child("RankoData").child(rankoID)
        let userRef  = db.child("UserData").child(user_data.userID)
                        .child("UserRankos").child("UserActiveRankos").child(rankoID)

        let writes = DispatchGroup()
        var ok1 = false, ok2 = false
        var err: String?

        writes.enter()
        listRef.setValue(payload) { e, _ in
            ok1 = (e == nil)
            if let e = e { err = "set list: \(e.localizedDescription)" }
            writes.leave()
        }

        writes.enter()
        userRef.setValue(categoryName) { e, _ in
            ok2 = (e == nil)
            if let e = e, err == nil { err = "mirror user node: \(e.localizedDescription)" }
            writes.leave()
        }

        writes.notify(queue: .main) {
            completion(ok1 && ok2, ok1 && ok2 ? nil : (err ?? "unknown firebase error"))
        }
    }
    
    private func updateTierListInAlgolia(
        rankoID: String,
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

        // Partial updates — mirror DefaultListPersonal
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoName",        value: .string(newName))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoDescription", value: .string(newDescription))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoCategory",    value: .string(newCategory))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoPrivacy",     value: .bool(isPrivate)))
        ]

        index.partialUpdateObjects(updates: updates) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let err):
                print("⚠️ Algolia error:", err.localizedDescription)
                completion(false)
            }
        }
    }
    
    func removeFeaturedRanko(rankoID: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
            
            // 2) Find the slot whose value == rankoID
            var didRemove = false
            for case let child as DataSnapshot in snap.children {
                if let value = child.value as? String, value == rankoID {
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
    
    private func deleteRanko(completion: @escaping (Bool) -> Void
    ) {
        let db = Database.database().reference()
        
        let statusUpdate: [String: Any] = [
            "RankoStatus": "deleted"
        ]
        
        let listRef = db.child("RankoData").child(rankoID)
        
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
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoStatus", value: "deleted"))
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
                            .font(.system(size: itemSize.descFont, weight: .regular))
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
            HStack(alignment: .top, spacing: 4) {
                TierHeader(tier: tier)
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

                switch layout {
                case .noWrap:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSize == .large ? 8 : 4) {
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
