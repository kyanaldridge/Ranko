//
//  TierList_Spectate.swift
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
struct TierListSpectate: View {
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
    
    // Sheet states
    @State private var showTabBar = true
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
    
    @State private var isSaved = false
    @State private var showCloneSheet = false
    @State private var showExportSheet = false
    @State private var showShareController = false
    @State private var generatedImage: UIImage? = nil
    
    // selection mode
    @State private var selectionMode = false
    @State private var selectedItemIDs: Set<String> = []

    // selection action bar / sheets
    @State private var showSelectionBar = false
    @State private var showMoveSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    // if you track creator somewhere, bind it here
    @State private var creatorName: String = "@" + (UserInformation.shared.username.isEmpty ? "creator" : UserInformation.shared.username)
    private let onClone: () -> Void
    
    // Replace your old enum-based helper with this:
    private func tierConfigForRow(_ i: Int) -> TierConfig {
        if tiers.isEmpty { return TierConfig.defaultForPosition(0) } // ← S-tier
        let idx = max(0, min(i, tiers.count - 1))
        return tiers[idx]
    }
    // MARK: - INITIALISER
    init(
        rankoID: String,
        onClone: @escaping () -> Void,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        groupedItems: [[RankoItem]] = []
    ) {
        self.rankoID = rankoID
        self.onClone = onClone
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _groupedItems = State(initialValue: groupedItems)
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
                                    VStack(spacing: 5) {
                                        VStack {
                                            VStack(spacing: 5) {
                                                Image(systemName: "bookmark.fill")
                                                    .resizable().scaledToFit()
                                                    .frame(width: 20, height: 20)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(isSaved ? Color.yellow : Color.black)
                                                    .pulse($isSaved)
                                                
                                                Text("Save")
                                                    .font(.custom("Nunito-Black", size: 11))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)
                                                    .allowsTightening(true)
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
                                                        handleSaveTap()
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    }
                                    VStack(spacing: 5) {
                                        VStack {
                                            VStack(spacing: 5) {
                                                Image(systemName: "rectangle.on.rectangle")
                                                    .resizable().scaledToFit()
                                                    .frame(width: 20, height: 20)
                                                    .fontWeight(.bold)
                                                
                                                Text("Clone")
                                                    .font(.custom("Nunito-Black", size: 11))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)
                                                    .allowsTightening(true)
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
                                                        handleCloneTap()
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    }
                                    VStack(spacing: 5) {
                                        VStack {
                                            VStack(spacing: 5) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .resizable().scaledToFit()
                                                    .frame(width: 20, height: 20)
                                                    .fontWeight(.bold)
                                                
                                                Text("Share")
                                                    .font(.custom("Nunito-Black", size: 11))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)
                                                    .allowsTightening(true)
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
                                                        //handleShareTap()
                                                    }
                                            )
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Color.black.opacity(0.001))
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0xFFFFFF)))
                                    }
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
            
//            .sheet(isPresented: $showExportSheet) {
//                NavigationStack {
//                    Form {
//                        Section("Options") {
//                            Toggle("Include Creator", isOn: $exportIncludeCreator)
//                            Toggle("Dark Mode", isOn: $exportDarkMode)
//                            Toggle("Show Item Descriptions", isOn: $exportShowItemDescriptions)
//                            Toggle("Show Ranks", isOn: $exportShowRanks)
//                        }
//                        if let img = generatedImage {
//                            Section("Preview") {
//                                ScrollView([.vertical, .horizontal]) {
//                                    Image(uiImage: img).resizable().scaledToFit()
//                                        .frame(maxWidth: .infinity)
//                                }
//                                .frame(minHeight: 240)
//                            }
//                        }
//                    }
//                    .navigationTitle("Export Ranko")
//                    .toolbar {
//                        ToolbarItemGroup(placement: .bottomBar) {
//                            Button("Regenerate") {
//                                Task { generatedImage = await renderExportImage() }
//                            }
//                            Button("Save to Photos") {
//                                Task {
//                                    if let img = await renderExportImage() { saveToPhotos(img) }
//                                }
//                            }
//                            Button("Share…") {
//                                Task {
//                                    generatedImage = await renderExportImage()
//                                    showShareController = true
//                                }
//                            }
//                        }
//                    }
//                    .sheet(isPresented: $showShareController) {
//                        if let img = generatedImage {
//                            ShareSheet(items: [img])
//                        }
//                    }
//                    .onAppear {
//                        if generatedImage == nil {
//                            Task {                      // hop into an async context
//                                generatedImage = await renderExportImage()
//                            }
//                        }
//                    }
//                }
//            }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(progressLoading) // block sheet swipe
            .disabled(progressLoading)
            .refreshable {
                refreshItemImages()
            }
            .interactiveDismissDisabled(true)
        }
    }
    
    private func handleSaveTap() {
        let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) { isSaved = true }
        // optional: persist "saved" in your RTDB/Algolia (bookmark)
        // ...
        // small pulse reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.25)) { isSaved = false }
        }
    }
    
    

//    private func handleShareTap() {
//        Task {
//            generatedImage = await renderExportImage()
//            showExportSheet = true
//        }
//    }
    
    
    
    private func handleCloneTap() {
        let impact = UIImpactFeedbackGenerator(style: .heavy); impact.impactOccurred()
        dismiss()
        onClone()
    }
    
//    @MainActor
//    private func renderExportImage() async -> UIImage? {
//        // 1080px wide social poster; tweak if you want 1440 etc.
//        let exportWidth: CGFloat = 1080
//
//        // 1) preload images so they’re ready before rendering
//        let images = await preloadImages(for: selectedRankoItems)
//
//        // 2) build export view
//        let exportView = RankoExportView(
//            rankoName: rankoName,
//            description: description,
//            categoryName: categoryName,
//            categoryIcon: categoryIcon,
//            categoryColour: categoryColour,
//            creatorName: exportIncludeCreator ? creatorName : nil,
//            items: selectedRankoItems,
//            darkMode: exportDarkMode,
//            showItemDescriptions: exportShowItemDescriptions,
//            showRanks: exportShowRanks,
//            loadedImages: images
//        )
//        .frame(width: exportWidth, alignment: .topLeading)     // width locked
//        .fixedSize(horizontal: false, vertical: true)          // let height grow
//
//        // 3) measure the height SwiftUI actually needs
//        let host = UIHostingController(rootView: exportView)
//        host.view.backgroundColor = .clear
//        let target = CGSize(width: exportWidth, height: .greatestFiniteMagnitude)
//        let size = host.sizeThatFits(in: target)   // <- real content height
//
//        // 4) render with ImageRenderer at that exact size
//        let sizedView = exportView.frame(height: size.height, alignment: .top)
//        let renderer = ImageRenderer(content: sizedView)
//        renderer.scale = UIScreen.main.scale
//        renderer.proposedSize = .init(CGSize(width: exportWidth, height: size.height))
//        return renderer.uiImage
//    }
    
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

