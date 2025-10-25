//
//  DefaultList_Spectate.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import InstantSearchCore
import Firebase
import FirebaseAuth
import FirebaseStorage
import Foundation
import AlgoliaSearchClient
import UIKit
import Photos

extension Color {
    /// Accepts "0xFFC800", "#FFC800", "FFC800", "FC8" (shorthand), and 8-digit "RRGGBBAA".
    /// If 8 digits are given, treats them as RRGGBBAA. Use `opacity` param to override for 6-digit/3-digit cases.
    init(hex: String, opacity: Double = 1.0) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#")  { s.removeFirst() }
        if s.hasPrefix("0x") { s.removeFirst(2) }

        // expand shorthand: RGB -> RRGGBB, RGBA -> RRGGBBAA
        if s.count == 3 || s.count == 4 {
            s = s.map { String(repeating: $0, count: 2) }.joined()
        }

        func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

        var r = 1.0, g = 1.0, b = 1.0, a = opacity

        if let value = UInt64(s, radix: 16) {
            switch s.count {
            case 6: // RRGGBB
                r = Double((value & 0xFF0000) >> 16) / 255.0
                g = Double((value & 0x00FF00) >> 8)  / 255.0
                b = Double( value & 0x0000FF)        / 255.0
                // a stays as passed-in opacity
            case 8: // RRGGBBAA
                r = Double((value & 0xFF000000) >> 24) / 255.0
                g = Double((value & 0x00FF0000) >> 16) / 255.0
                b = Double((value & 0x0000FF00) >> 8)  / 255.0
                a = Double( value & 0x000000FF)        / 255.0
            default:
                break // keep defaults
            }
        }

        self = Color(.sRGB, red: clamp(r), green: clamp(g), blue: clamp(b), opacity: clamp(a))
    }
}

struct DefaultListSpectate: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    @Namespace private var namespace
    @Namespace private var transition
    
    // Required property
    let rankoID: String
    
    // Optional editable properties with defaults
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var categoryName: String = "Unknown"
    @State private var categoryIcon: String = "questionmark"
    @State private var categoryColour: String = "0x000000"
    
    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategoryName: String = ""
    @State private var originalCategoryIcon: String = ""
    @State private var originalCategoryColour: String = ""
    
    // Sheets & states
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    @State var showDeleteAlert = false
    @State var showLeaveAlert = false
    
    @State private var selectedRankoItems: [RankoItem] = []
    @State private var selectedItem: RankoItem? = nil
    
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
    
    @State private var addButtonTranslation: CGSize = .zero
    @State private var addButtonsTranslation: CGSize = .zero
    
    @State private var saveButtonHovered: Bool = false
    @State private var deleteButtonHovered: Bool = false
    @State private var cancelButtonHovered: Bool = false
    
    @State private var sampleButtonHovered: Bool = false
    @State private var blankButtonHovered: Bool = false
    
    @State private var exitFrame: CGRect = .zero
    @State private var saveFrame: CGRect = .zero
    @State private var deleteFrame: CGRect = .zero
    @State private var cancelFrame: CGRect = .zero
    
    @State private var addFrame: CGRect = .zero
    @State private var sampleFrame: CGRect = .zero
    @State private var blankFrame: CGRect = .zero
    
    @State private var isPresentingSheet = false
    @State private var isExpanded = false
    
    @State private var progressLoading: Bool = false       // ← shows the loader
    @State private var publishError: String? = nil         // ← error messaging
    @State private var imageReloadToken = UUID()
    
    // Blank Items composer
    @State private var showBlankItemsFS = false
    @State private var blankDrafts: [BlankItemDraft] = [BlankItemDraft()] // start with 1
    @State private var draftError: String? = nil

    // hold personal images picked for new items -> uploaded on publish
    @State private var isSaved = false
    @State private var showCloneSheet = false
    @State private var showExportSheet = false
    @State private var showShareController = false
    @State private var generatedImage: UIImage? = nil

    // export options
    @State private var exportIncludeCreator = true
    @State private var exportDarkMode = false
    @State private var exportShowItemDescriptions = true
    @State private var exportShowRanks = true

    // if you track creator somewhere, bind it here
    @State private var creatorName: String = "@" + (UserInformation.shared.username.isEmpty ? "creator" : UserInformation.shared.username)
    private let onClone: () -> Void
    
    // MARK: - Init now only requires rankoID
    init(
        rankoID: String,
        onClone: @escaping () -> Void,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        selectedRankoItems: [RankoItem] = []
    ) {
        self.rankoID = rankoID
        self.onClone = onClone
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        
        _originalRankoName = State(initialValue: rankoName ?? "")
        _originalDescription = State(initialValue: description ?? "")
        _originalIsPrivate = State(initialValue: isPrivate ?? false)
        _originalCategoryName = State(initialValue: categoryName)
        _originalCategoryIcon = State(initialValue: categoryIcon)
        _originalCategoryColour = State(initialValue: categoryColour)
    }
    
    private struct RankoToolbarTitleStack: View {
        @StateObject private var user_data = UserInformation.shared
        let name: String
        let description: String
        @Binding var isPrivate: Bool
        let categoryName: String
        let categoryIcon: String
        let categoryColour: String
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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(hex: 0xFFFFFF)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            ScrollView {
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
                                                            
                                                        }) {
                                                            Label("View Item", systemImage: "magnifyingglass")
                                                        }
                                                    }
                                            }
                                        }
                                        .id(imageReloadToken)
                                        .padding(.top, 70)
                                        .padding(.bottom, 120)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
                
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
                                                    handleShareTap()
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(progressLoading) // block sheet swipe
            .disabled(progressLoading)                   // block touches
            .refreshable {
                refreshItemImages()
            }
            .onAppear {
                loadListFromFirebase()
                refreshItemImages()
            }
            .sheet(isPresented: $showExportSheet) {
                NavigationStack {
                    Form {
                        Section("Options") {
                            Toggle("Include Creator", isOn: $exportIncludeCreator)
                            Toggle("Dark Mode", isOn: $exportDarkMode)
                            Toggle("Show Item Descriptions", isOn: $exportShowItemDescriptions)
                            Toggle("Show Ranks", isOn: $exportShowRanks)
                        }
                        if let img = generatedImage {
                            Section("Preview") {
                                ScrollView([.vertical, .horizontal]) {
                                    Image(uiImage: img).resizable().scaledToFit()
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(minHeight: 240)
                            }
                        }
                    }
                    .navigationTitle("Export Ranko")
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Regenerate") {
                                Task { generatedImage = await renderExportImage() }
                            }
                            Button("Save to Photos") {
                                Task {
                                    if let img = await renderExportImage() { saveToPhotos(img) }
                                }
                            }
                            Button("Share…") {
                                Task {
                                    generatedImage = await renderExportImage()
                                    showShareController = true
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showShareController) {
                        if let img = generatedImage {
                            ShareSheet(items: [img])
                        }
                    }
                    .onAppear {
                        if generatedImage == nil {
                            Task {                      // hop into an async context
                                generatedImage = await renderExportImage()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func resetExitDragState() {
        withAnimation { exitButtonTranslation = .zero }
        withAnimation { saveButtonHovered = false }
        withAnimation { deleteButtonHovered = false }
        withAnimation { cancelButtonHovered = false }
        withAnimation { exitButtonTapped = false }
    }
    
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    private func loadListFromFirebase() {
        let ref = Database.database().reference()
            .child("RankoData")
            .child(rankoID)

        func parseColourToUInt(_ any: Any?) -> UInt {
            // accepts: "0xFFCF00", "#FFCF00", "FFCF00", 16763904, NSNumber, etc.
            if let n = any as? NSNumber { return UInt(truncating: n) & 0x00FF_FFFF }
            if let i = any as? Int { return UInt(i & 0x00FF_FFFF) }
            if let s = any as? String {
                var hex = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let dec = Int(hex) { return UInt(dec & 0x00FF_FFFF) }
                if hex.hasPrefix("#") { hex.removeFirst() }
                if hex.hasPrefix("0x") { hex.removeFirst(2) }
                if let v = Int(hex, radix: 16) { return UInt(v & 0x00FF_FFFF) }
            }
            return 0x446D7A
        }

        ref.observeSingleEvent(of: .value) { snap in
            guard let root = snap.value as? [String: Any] else { return }

            // ---------- NEW SCHEMA ----------
            let details = root["RankoDetails"] as? [String: Any]
            let privacy = root["RankoPrivacy"] as? [String: Any]
            let cat     = root["RankoCategory"] as? [String: Any]
            let items   = root["RankoItems"] as? [String: Any] ?? [:]

            if details != nil || privacy != nil || cat != nil {
                // details
                let name = (details?["name"] as? String) ?? ""
                let des  = (details?["description"] as? String) ?? ""
                let priv = (privacy?["private"] as? Bool) ?? false

                // category
                let catName  = (cat?["name"] as? String) ?? ""
                let catIcon  = (cat?["icon"] as? String) ?? "circle"
                let catColour = (cat?["colour"] as? String) ?? "0x000000"

                // items
                let parsedItems: [RankoItem] = items.compactMap { (k, v) in
                    guard let it = v as? [String: Any] else { return nil }
                    guard
                        let itemName  = it["ItemName"] as? String,
                        let itemDesc  = it["ItemDescription"] as? String,
                        let itemImage = it["ItemImage"] as? String,
                        let itemGIF    = it["ItemGIF"] as? String,
                        let itemVideo    = it["ItemVideo"] as? String,
                        let itemAudio    = it["ItemAudio"] as? String
                    else { return nil }
                    let rank  = intFromAny(it["ItemRank"])  ?? 0
                    let votes = intFromAny(it["ItemVotes"]) ?? 0
                    let rec = RankoRecord(objectID: k, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                    let plays = intFromAny(it["PlayCount"]) ?? 0
                    return RankoItem(id: k, rank: rank, votes: votes, record: rec, playCount: plays)
                }

                // assign UI state
                rankoName = name
                description = des
                isPrivate = priv
                categoryName = catName
                categoryIcon = catIcon
                categoryColour = catColour

                selectedRankoItems = parsedItems.sorted { $0.rank < $1.rank }

                // originals (for revert)
                originalRankoName = name
                originalDescription = des
                originalIsPrivate = priv
                originalCategoryName = catName
                originalCategoryIcon = catIcon
                originalCategoryColour = catColour
                return
            }

            // ---------- OLD SCHEMA (fallback) ----------
            let name = (root["RankoName"] as? String) ?? ""
            let des  = (root["RankoDescription"] as? String) ?? ""
            let priv = (root["RankoPrivacy"] as? Bool) ?? false

            var catName = ""
            var catIcon = "circle"
            var catColourUInt = "0x000000"
            if let catObj = root["RankoCategory"] as? [String: Any] {
                catName = (catObj["name"] as? String) ?? ""
                catIcon = (catObj["icon"] as? String) ?? "circle"
                catColourUInt = (catObj["colour"] as? String) ?? "0x000000"
            } else if let catStr = root["RankoCategory"] as? String {
                catName = catStr
            }

            let itemsDict = root["RankoItems"] as? [String: [String: Any]] ?? [:]
            let parsedItems: [RankoItem] = itemsDict.compactMap { (itemID, it) in
                guard
                    let itemName  = it["ItemName"] as? String,
                    let itemDesc  = it["ItemDescription"] as? String,
                    let itemImage = it["ItemImage"] as? String,
                    let itemGIF    = it["ItemGIF"] as? String,
                    let itemVideo    = it["ItemVideo"] as? String,
                    let itemAudio    = it["ItemAudio"] as? String
                else { return nil }
                let rank  = intFromAny(it["ItemRank"])  ?? 0
                let votes = intFromAny(it["ItemVotes"]) ?? 0
                let rec = RankoRecord(objectID: itemID, ItemName: itemName, ItemDescription: itemDesc, ItemCategory: "", ItemImage: itemImage, ItemGIF: itemGIF, ItemVideo: itemVideo, ItemAudio: itemAudio)
                let plays = intFromAny(it["PlayCount"]) ?? 0
                return RankoItem(id: itemID, rank: rank, votes: votes, record: rec, playCount: plays)
            }

            // assign UI state
            rankoName = name
            description = des
            isPrivate = priv
            categoryName = catName
            categoryIcon = catIcon
            categoryColour = catColourUInt
            selectedRankoItems = parsedItems.sorted { $0.rank < $1.rank }

            originalRankoName = name
            originalDescription = des
            originalIsPrivate = priv
            originalCategoryName = catName
            originalCategoryIcon = catIcon
            originalCategoryColour = catColourUInt
        }
    }


    // Helper to safely coerce Firebase numbers/strings into Int
    private func intFromAny(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }
    
    private func handleCloneTap() {
        let impact = UIImpactFeedbackGenerator(style: .heavy); impact.impactOccurred()
        dismiss()
        onClone()
    }
    
    @MainActor
    private func renderExportImage() async -> UIImage? {
        // 1080px wide social poster; tweak if you want 1440 etc.
        let exportWidth: CGFloat = 1080

        // 1) preload images so they’re ready before rendering
        let images = await preloadImages(for: selectedRankoItems)

        // 2) build export view
        let exportView = RankoExportView(
            rankoName: rankoName,
            description: description,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            categoryColour: categoryColour,
            creatorName: exportIncludeCreator ? creatorName : nil,
            items: selectedRankoItems,
            darkMode: exportDarkMode,
            showItemDescriptions: exportShowItemDescriptions,
            showRanks: exportShowRanks,
            loadedImages: images
        )
        .frame(width: exportWidth, alignment: .topLeading)     // width locked
        .fixedSize(horizontal: false, vertical: true)          // let height grow

        // 3) measure the height SwiftUI actually needs
        let host = UIHostingController(rootView: exportView)
        host.view.backgroundColor = .clear
        let target = CGSize(width: exportWidth, height: .greatestFiniteMagnitude)
        let size = host.sizeThatFits(in: target)   // <- real content height

        // 4) render with ImageRenderer at that exact size
        let sizedView = exportView.frame(height: size.height, alignment: .top)
        let renderer = ImageRenderer(content: sizedView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = .init(CGSize(width: exportWidth, height: size.height))
        return renderer.uiImage
    }

    struct ShareSheet: UIViewControllerRepresentable {
        let items: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }

    private func saveToPhotos(_ image: UIImage) {
        // ensure you have NSPhotoLibraryAddUsageDescription in Info.plist
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        let impact = UINotificationFeedbackGenerator(); impact.notificationOccurred(.success)
    }

    private func handleShareTap() {
        Task {
            generatedImage = await renderExportImage()
            showExportSheet = true
        }
    }
    
    private func preloadImages(for items: [RankoItem], maxBytes: Int = 1_500_000) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for it in items {
                let urlStr = it.record.ItemImage
                let id = it.id
                group.addTask {
                    guard let url = URL(string: urlStr) else { return (id, nil) }
                    var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
                    req.setValue("image/*", forHTTPHeaderField: "Accept")
                    do {
                        let (data, _) = try await URLSession.shared.data(for: req)
                        if data.count <= maxBytes, let img = UIImage(data: data) {
                            return (id, img)
                        }
                    } catch { /* ignore */ }
                    return (id, nil)
                }
            }
            var out: [String: UIImage] = [:]
            for await (id, img) in group {
                if let img { out[id] = img }
            }
            return out
        }
    }
}

struct Pulse: ViewModifier {
    @Binding var active: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.15 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.55).repeatCount(1), value: active)
    }
}

extension View { func pulse(_ active: Binding<Bool>) -> some View { modifier(Pulse(active: active)) } }

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

struct RankoExportView: View {
    let rankoName: String
    let description: String
    let categoryName: String
    let categoryIcon: String?
    let categoryColour: String
    let creatorName: String?
    let items: [RankoItem]
    let darkMode: Bool
    let showItemDescriptions: Bool
    let showRanks: Bool
    let loadedImages: [String: UIImage]   // <- NEW map: item.id -> UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // header
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: categoryIcon ?? "circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: categoryColour))
                    Text(rankoName)
                        .font(.system(size: 36, weight: .black))
                        .fixedSize(horizontal: false, vertical: true)     // allow wrap
                }
                if let creator = creatorName {
                    Text(creator)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if !description.isEmpty {
                    Text(description)
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(categoryName.uppercased())
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: categoryColour).opacity(0.18), in: Capsule())
            }

            Divider()

            // items
            VStack(spacing: 14) {
                ForEach(items.sorted { $0.rank < $1.rank }) { item in
                    HStack(alignment: .top, spacing: 12) {
                        // use preloaded image or gray box
                        Group {
                            if let ui = loadedImages[item.id] {
                                Image(uiImage: ui).resizable().scaledToFill()
                            } else {
                                Color.gray.opacity(0.15)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                if showRanks {
                                    Text("#\(item.rank)")
                                        .font(.system(size: 12, weight: .heavy))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                }
                                Text(item.record.ItemName)
                                    .font(.system(size: 17, weight: .heavy))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if showItemDescriptions, !item.record.ItemDescription.isEmpty {
                                Text(item.record.ItemDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(24)
        .background(darkMode ? Color.black : Color.white)
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}
