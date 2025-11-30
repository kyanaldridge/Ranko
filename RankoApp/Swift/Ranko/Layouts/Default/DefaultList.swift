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
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
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

struct DefaultListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @Environment(\.tabViewBottomAccessoryPlacement) var placement

    // Init properties
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
    @State var showEditItemSheet = false
    @State var showAddItemsSheet = false
    @State var showAddItemsButtonSheet = false
    @State var showEditDetailsSheet = false
    @State var showReorderSheet = false
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
    
    // Item states
    @State private var selectedRankoItems: [RankoItem]
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: (RankoItem) -> Void
    
    @State private var imageReloadToken = UUID()
    
    @State private var isPresentingSheet = false
    @State private var isExpanded = false
    @Namespace private var namespace
    @Namespace private var transition
    
    @State private var progressLoading: Bool = false       // ← shows the loader
    @State private var publishError: String? = nil         // ← error messaging
    
    // Blank Items composer
    @State private var showBlankItemsFS = false
    @State private var showBlankItemsButtonFS = false
    @State private var blankDrafts: [BlankItemDraft] = [BlankItemDraft()] // start with 1
    @State private var draftError: String? = nil

    // hold personal images picked for new items -> uploaded on publish
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image

    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        categoryName: String,
        categoryIcon: String,
        categoryColour: UInt,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _categoryName   = State(initialValue: categoryName)
        _categoryIcon = State(initialValue: categoryIcon)
        _categoryColour   = State(initialValue: categoryColour)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName)
        _originalDescription = State(initialValue: description)
        _originalIsPrivate = State(initialValue: isPrivate)
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
                                                            rankoID: rankoID
                                                        ) { newName, newDesc in
                                                            // build updated record & item
                                                            let rec = item.record
                                                            let updatedRecord = RankoRecord(
                                                                objectID: rec.objectID,
                                                                ItemName: newName,
                                                                ItemDescription: newDesc,
                                                                ItemCategory: "",
                                                                ItemImage: rec.ItemImage,
                                                                ItemGIF: rec.ItemGIF,
                                                                ItemVideo: rec.ItemVideo,
                                                                ItemAudio: rec.ItemAudio
                                                            )
                                                            let updatedItem = RankoItem(
                                                                id: item.id,
                                                                rank: item.rank,
                                                                votes: item.votes,
                                                                record: updatedRecord,
                                                                playCount: item.playCount
                                                            )
                                                            // callback to parent
                                                            onSave(updatedItem)
                                                        }
                                                    }
                                            }
                                            
                                            if selectedRankoItems.count == 0 {
                                                HStack {
                                                    Button {
                                                        showBlankItemsButtonFS = true
                                                    } label: {
                                                        Text("Add Blank Items")
                                                            .font(.custom("Nunito-Black", size: 15))
                                                    }
                                                    .tint(Color.red)
                                                    .foregroundStyle(Color.white)
                                                    .buttonStyle(.glassProminent)
                                                    .matchedTransitionSource(
                                                        id: "emptyBlankButton", in: transition
                                                    )
                                                    Button {
                                                        showAddItemsButtonSheet = true
                                                    } label: {
                                                        Text("Add Sample Items")
                                                            .font(.custom("Nunito-Black", size: 15))
                                                    }
                                                    .tint(Color.red)
                                                    .foregroundStyle(Color.white)
                                                    .buttonStyle(.glassProminent)
                                                    .matchedTransitionSource(
                                                        id: "emptySampleButton", in: transition
                                                    )
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
                                                        showBlankItemsFS = true
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
            .overlay {
                if progressLoading {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView("Saving your Ranko…")
                                .padding(.vertical, 8)
                            Text("Saving to Firebase + Algolia")
                                .font(.custom("Nunito-Black", size: 12))
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
            .fullScreenCover(isPresented: $showAddItemsSheet) {
                AddItemsPickerSheet(selectedRankoItems: $selectedRankoItems)
                    .presentationDetents([.large])
                    .interactiveDismissDisabled(true)
                    .navigationTransition(.zoom(sourceID: "sampleButton", in: transition))
            }
            .fullScreenCover(isPresented: $showAddItemsButtonSheet) {
                AddItemsPickerSheet(selectedRankoItems: $selectedRankoItems)
                    .presentationDetents([.large])
                    .interactiveDismissDisabled(true)
                    .navigationTransition(.zoom(sourceID: "emptySampleButton", in: transition))
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
            .fullScreenCover(isPresented: $rankButtonTapped) {
                DefaultListReRank(items: selectedRankoItems) { newOrder in
                    selectedRankoItems = newOrder
                }
                .navigationTransition(
                    .zoom(sourceID: "rankButton", in: transition)
                )
            }
            // SINGLE edit sheet bound to the selected item (no per-row sheets)
            .sheet(item: $itemToEdit) { item in
                EditItemView(item: item, rankoID: rankoID) { newName, newDesc in
                    let rec = item.record
                    let updatedRecord = RankoRecord(
                        objectID: rec.objectID,
                        ItemName: newName,
                        ItemDescription: newDesc,
                        ItemCategory: "",
                        ItemImage: rec.ItemImage,
                        ItemGIF: rec.ItemAudio,
                        ItemVideo: rec.ItemVideo,
                        ItemAudio: rec.ItemAudio
                    )
                    let updatedItem = RankoItem(
                        id: item.id,
                        rank: item.rank,
                        votes: item.votes,
                        record: updatedRecord,
                        playCount: item.playCount
                    )
                    onSave(updatedItem)
                }
            }
            .fullScreenCover(isPresented: $showBlankItemsFS) {
                BlankItemsComposer(
                    rankoID: rankoID,                  // 👈 add this
                    drafts: $blankDrafts,
                    error: $draftError,
                    canAddMore: blankDrafts.count < 10,
                    onCommit: { appendDraftsToSelectedRanko() }
                )
            }
            .fullScreenCover(isPresented: $showBlankItemsButtonFS) {
                BlankItemsComposer(
                    rankoID: rankoID,                  // 👈 add this
                    drafts: $blankDrafts,
                    error: $draftError,
                    canAddMore: blankDrafts.count < 10,
                    onCommit: { appendDraftsToSelectedRanko() }
                )
                .navigationTransition(.zoom(sourceID: "emptyBlankButton", in: transition))
            }
            .onAppear {
                refreshItemImages()
            }
        }
    }
    
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    // Item Helpers
    private func delete(_ item: RankoItem) {
        // attempt storage delete IFF this item used a personal image (not placeholder)
        let imgURL = item.record.ItemImage
        if !isPlaceholderURL(imgURL) {
            Task { await deleteStorageImage(rankoID: rankoID, itemID: item.id) }
        }

        selectedRankoItems.removeAll { $0.id == item.id }
        normalizeRanks()
    }

    private func moveToTop(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.insert(moved, at: 0)
        normalizeRanks()
    }

    private func moveToBottom(_ item: RankoItem) {
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
    
    @MainActor
    private func startPublishAndDismiss() {
        guard categoryName != "Unknown" else {
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

    // MARK: - Algolia (async)

    private func saveRankedListToAlgoliaAsync() async throws {
        guard categoryName != "" else { throw PublishErr.missingCategory }

        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)

        let listRecord = RankoListAlgolia(
            objectID:         rankoID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoStatus:      "active",
            RankoCategory:    categoryName,
            RankoUserID:      user_data.userID,
            RankoCreated:     rankoDateTime,
            RankoUpdated:     rankoDateTime,
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

    // MARK: - Firebase (async)

    private func saveRankedListToFirebaseAsync() async throws {
        guard categoryName != "Unknown" else { throw PublishErr.missingCategory }

        let db = FirestoreProvider.dbFilters
        let docRef = db.collection("ranko").document(rankoID)
        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        guard !rawUID.isEmpty else { throw PublishErr.invalidUserID }

        // Build Items payload (keep original IDs) for the items subcollection
        let itemsRef = docRef.collection("items")
        let normalizedTags: [String] = tags.isEmpty ? ["ranko", categoryName.lowercased()] : tags.map { $0.lowercased() }

        // Timestamp (AEST/AEDT) → "yyyyMMddHHmmss"
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let ts = formatter.string(from: now)

        // Ranko document shaped like import_ranko.py output
        let payload: [String: Any] = [
            "id": rankoID,
            "name": rankoName,
            "description": description,
            "lang": "en",
            "time": ["created": ts, "updated": ts],
            "category": categoryName,
            "country": "AUS",
            "privacy": isPrivate,
            "status": "active",
            "type": "default",
            "user_id": rawUID,
            "tags": normalizedTags,
            "category_meta": [
                "colour": String(categoryColour),
                "icon":   categoryIcon,
                "name":   categoryName
            ]
        ]

        try await docRef.setData(payload, merge: true)

        // purge removed items
        let existing = try await itemsRef.getDocuments()
        let keepIDs = Set(selectedRankoItems.map { $0.id })
        for doc in existing.documents where !keepIDs.contains(doc.documentID) {
            try await doc.reference.delete()
        }

        // write items
        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in selectedRankoItems {
                group.addTask {
                    try await itemsRef.document(item.id).setData(
                        [
                            "id": item.id,
                            "name": item.itemName,
                            "description": item.itemDescription,
                            "image": item.itemImage,
                            "gif": item.itemGIF ?? "",
                            "video": item.itemVideo ?? "",
                            "audio": item.itemAudio ?? "",
                            "rank": item.rank,
                            "votes": item.votes,
                            "plays": item.playCount
                        ],
                        merge: true
                    )
                }
            }
            try await group.waitForAll()
        }

        // mirror lightweight pointer for the user
        try await docRef.collection("userPointers")
            .document(rawUID)
            .setData(["category": categoryName], merge: true)
    }

    // MARK: - Errors

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

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(drafts, id: \.id) { draft in
                            let draftID = draft.id
                            DraftCard(
                                draft: bindingForDraft(id: draftID),      // ← binding resolved by id
                                title: "Blank Item #\((drafts.firstIndex(where: { $0.id == draftID }) ?? 0) + 1)",
                                subtitle: "tap to add image (optional)",
                                focusedField: $focusedField,
                                onTapImage: {
                                    activeDraftID = draftID
                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
                                    showNewImageSheet = true
                                },
                                onDelete: {
                                    removeDraft(id: draftID)              // ← remove by id (no captured i)
                                }
                            )
                            .contextMenu {
                                Button(role: .none) {                     // was .confirm (invalid role)
                                    activeDraftID = draftID
                                    backupImage = drafts.first(where: { $0.id == draftID })?.image
                                    showNewImageSheet = true
                                } label: { Label("Add Image", systemImage: "photo.fill") }

                                Button(role: .destructive) {
                                    removeDraft(id: draftID)
                                } label: { Label("Delete", systemImage: "trash") }

                                Button(role: .none) {
                                    // clear fields on the live binding if it still exists
                                    if let idx = drafts.firstIndex(where: { $0.id == draftID }) {
                                        drafts[idx].description = ""
                                        drafts[idx].image = nil
                                        drafts[idx].name = ""
                                        // try to delete uploaded image if not placeholder
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
                                    .font(.custom("Nunito-Black", size: 18))
                                Text("ADD ANOTHER BLANK ITEM")
                                    .font(.custom("Nunito-Black", size: 15))
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!canAddMore)
                        .opacity(canAddMore ? 1 : 0.5)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
                                .focused(focusedField, equals: .name(draft.id))   // ✅ use binding
                                .submitLabel(.next)
                                .onSubmit { focusedField.wrappedValue = .description(draft.id) } // ✅ jump to desc

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
                                .lineLimit(1...3)
                                .foregroundStyle(.gray)
                                .focused(focusedField, equals: .description(draft.id))  // ✅ use binding
                                .submitLabel(.done)
                                .onSubmit { hideKeyboard() }

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
                    .disabled(draft.isUploading)
                    .opacity(draft.isUploading ? 0.5 : 1)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: draft.description) {
                if draft.description.contains("\n") {
                    hideKeyboard()
                    draft.description = draft.description.replacingOccurrences(of: "\n", with: "")
                }
            }
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
    
    private func publishRanko() async throws {
        // 1) upload all personal images first (hard gate)
        try await uploadPersonalImagesAsync()

        // 2) now that uploads succeeded, rewrite ItemImage URLs for the affected items
        let urlBase = "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F"

        for idx in selectedRankoItems.indices {
            let itemID = selectedRankoItems[idx].id
            guard pendingPersonalImages[itemID] != nil else { continue }

            let newURL = "\(urlBase)\(itemID).jpg?alt=media&token="
            let oldRecord = selectedRankoItems[idx].record
            let updatedRecord = oldRecord.withItemImage(newURL)
            let updatedItem = selectedRankoItems[idx].withRecord(updatedRecord)

            selectedRankoItems[idx] = updatedItem
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
        var nextRank = (selectedRankoItems.map(\.rank).max() ?? 0) + 1

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
            selectedRankoItems.append(item)
            nextRank += 1
        }

        blankDrafts = [BlankItemDraft()]
        draftError = nil
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

struct BlankItemDraft: Identifiable, Equatable {
    let id = UUID().uuidString
    var image: UIImage? = nil
    var name: String = ""
    var description: String = ""
    var gif: String = ""
    var video: String = ""
    var audio: String = ""

    // new:
    var itemImageURL: String? = nil        // final URL to store in DB
    var isUploading: Bool = false          // spinner state
    var uploadError: String? = nil         // show to user if upload fails/times out
}

struct DefaultListAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var placement


    var body: some View {
        switch placement {
        case .inline:
            RankoCoachAccessory(onDismiss: {})
        case .expanded:
            EmptyView()
        case .none:
            EmptyView()
        case .some(_):
            EmptyView()
        }
    }
}

struct RankoCoachAccessory: View {
    var onDismiss: () -> Void
    @State private var accessoryWidth: CGFloat = 388.0
    @State private var accessoryHeight: CGFloat = 48.0
    
    @State private var pointerOffset: CGFloat = .zero
    @State private var pointerImage: String = "hand.point.up.left.fill"
    @State private var showPointer: Bool = false
    @State private var showDemoTabBar: Bool = false
    
    @State private var message1: Bool = false
    @State private var message2: Bool = false
    @State private var message3: Bool = false
    @State private var message4: Bool = false
    @State private var message5: Bool = false
    @State private var message6: Bool = false
    
    @State private var timelineTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        print("Height of Accessory: \(geometry.size.height)")
                        print("Width of Accessory: \(geometry.size.width)")
                        accessoryHeight = geometry.size.height
                        accessoryWidth = geometry.size.width
                    }
                HStack(alignment: .center, spacing: 5) {
                    Spacer(minLength: 0)
                    VStack {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .frame(height: accessoryHeight * 0.35)
                        Text("Add Items")
                            .font(.system(size: 7, weight: .semibold, design: .default))
                    }
                    .frame(width: 50/388 * accessoryWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    VStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .frame(height: accessoryHeight * 0.35)
                        Text("Details")
                            .font(.system(size: 7, weight: .semibold, design: .default))
                    }
                    .frame(width: 50/388 * accessoryWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    VStack {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .frame(height: accessoryHeight * 0.35)
                    }
                    .frame(width: 56/388 * accessoryWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    VStack {
                        Image(systemName: "rectangle.arrowtriangle.2.outward")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .frame(height: accessoryHeight * 0.35)
                        Text("Re-Rank")
                            .font(.system(size: 7, weight: .semibold, design: .default))
                    }
                    .frame(width: 50/388 * accessoryWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    VStack {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .frame(height: accessoryHeight * 0.35)
                        Text("Save")
                            .font(.system(size: 7, weight: .semibold, design: .default))
                    }
                    .frame(width: 50/388 * accessoryWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity)
                .frame(height: accessoryHeight)
                .opacity(showDemoTabBar ? 1 : 0)
                
                VStack {
                    if message1 {
                        Text("Welcome to RankoCreate!")
                            .font(.custom("Nunito-Black", size: 13))
                    } else if message2 {
                        Text("To Add Items, Swipe to ADD ITEMS!")
                            .font(.custom("Nunito-Black", size: 13))
                    } else if message3 {
                        Text("To Edit the Name, Description, Category or Privacy of Your Ranko, Swipe to DETAILS!")
                            .font(.custom("Nunito-Black", size: 13))
                    } else if message4 {
                        Text("To Re-Order Your Items, Swipe to RE-RANK!")
                            .font(.custom("Nunito-Black", size: 13))
                    } else if message5 {
                        Text("To Exit & Save or Delete Your Ranko, Swipe to SAVE!")
                            .font(.custom("Nunito-Black", size: 13))
                    } else if message6 {
                        Text("Enjoy Ranking!")
                            .font(.custom("Nunito-Black", size: 13))
                    }
                }
                .padding(.horizontal, 10)
                
                if showPointer {
                    Image(systemName: "\(pointerImage)")
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(hex: 0xFFFFFF))
                                .blur(radius: 2)
                        )
                        .offset(x: pointerOffset)
                }
                
            }
            .onAppear { startTimeline() }
            .onDisappear { timelineTask?.cancel() }
        }
    }
    
    // MARK: - Timeline runner
    private func startTimeline() {
        timelineTask?.cancel()
        timelineTask = Task { await runTimeline() }
    }
    
    @MainActor
    private func runTimeline() async {
        // helpers
        func sleep(_ s: TimeInterval) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        func resetPointer() { pointerOffset = 0 }
        
        // a reusable block for the “show bar → show pointer → tap → slide → point → hide” beat
        @MainActor
        func showAndPoint(to fractionOfWidth: CGFloat) async {
            withAnimation { showDemoTabBar = true }
            await sleep(0.4)
            withAnimation { showPointer = true }
            await sleep(0.4)
            withAnimation { pointerImage = "hand.tap.fill" }
            await sleep(1.4)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                pointerOffset = fractionOfWidth * accessoryWidth
            }
            await sleep(1.4)
            withAnimation { pointerImage = "hand.point.up.left.fill" }
            await sleep(1.4)
            withAnimation {
                showDemoTabBar = false
                showPointer = false
            }
        }
        
        // === timeline ===
        await sleep(1.2); withAnimation { message1.toggle() }
        await sleep(2.1); withAnimation { message1.toggle() }
        
        await sleep(0.7); withAnimation { message2.toggle() }
        await sleep(3.1); withAnimation { message2.toggle() }
        
        await sleep(0.7); await showAndPoint(to: -113/388.0)   // far-left slot
        await sleep(0.7); resetPointer(); withAnimation { message3.toggle() }
        await sleep(3.2); withAnimation { message3.toggle() }
        
        await sleep(0.7); await showAndPoint(to: -58/388.0)    // mid-left slot
        await sleep(0.7); resetPointer(); withAnimation { message4.toggle() }
        await sleep(3.2); withAnimation { message4.toggle() }
        
        await sleep(0.7); await showAndPoint(to: 58/388.0)     // mid-right slot
        await sleep(0.7); resetPointer(); withAnimation { message5.toggle() }
        await sleep(3.2); withAnimation { message5.toggle() }
        
        await sleep(0.7); await showAndPoint(to: 113/388.0)     // far-right slot
        await sleep(0.7); resetPointer(); withAnimation { message6.toggle() }
        await sleep(3.2); withAnimation { message6.toggle() }
        
        await sleep(3.2); onDismiss()
    }
}

struct DefaultListEditDetails: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: – Editable state
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var categoryName: String = ""
    @State private var categoryIcon: String = ""
    @State private var categoryColour: UInt = 0xFFFFFF
    @State private var selectedCategoryChip: SampleCategoryChip?
    @State private var initialCategoryName: String = ""
    @State private var initialCategoryIcon: String = ""
    @State private var initialCategoryColour: UInt = 0xFFFFFF

    // MARK: – UI state
    @FocusState private var nameFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @State private var showCategoryPicker: Bool = false   // (kept if you later want a modal)

    // Category tree state (mirrors CreateSheet)
    @StateObject private var repo = CategoryRepo()
    @State private var localSelection: SampleCategoryChip? = nil
    @State private var expandedParentID: String? = nil
    @State private var expandedSubID: String? = nil
    @State private var selectedPath: [String] = []

    // MARK: – Validation & shake
    @State private var rankoNameShake: CGFloat = 0
    private var isValid: Bool { !rankoName.isEmpty }

    private let onSave: (String, String, Bool, String, String, UInt) -> Void

    init(
        rankoName: String,
        description: String = "",
        isPrivate: Bool,
        categoryName: String,
        categoryIcon: String,
        categoryColour: UInt,
        onSave: @escaping (String, String, Bool, String, String, UInt) -> Void
    ) {
        self.onSave = onSave
        _rankoName  = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate  = State(initialValue: isPrivate)
        _categoryName = State(initialValue: categoryName)
        _categoryIcon = State(initialValue: categoryIcon)
        _categoryColour = State(initialValue: categoryColour)
        // if you pass a category, pre-expand its path on appear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    // MARK: Row 1 — Ranko Name + Privacy Toggle
                    HStack(alignment: .firstTextBaseline, spacing: 12) {

                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("ranko name")
                                    .font(.custom("Nunito-Black", size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(rankoName.count)/50")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            TextField("e.g. Top 20 Countries I Want To Visit", text: $rankoName)
                                .font(.custom("Nunito-Black", size: 16))
                                .foregroundColor(.black)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .focused($nameFocused)
                                .onChange(of: rankoName) { _, new in
                                    if new.count > 50 { rankoName = String(new.prefix(50)) }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.08))
                                )
                        }
                        .modifier(ShakeEffect(travelDistance: 8, shakesPerUnit: 3, animatableData: rankoNameShake))

                        // Privacy
                        VStack(alignment: .leading, spacing: 6) {
                            Text("private")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(.secondary)

                            Toggle(isOn: $isPrivate) {
                                HStack(spacing: 6) {
                                    Image(systemName: isPrivate ? "lock.fill" : "globe")
                                        .font(.system(size: 13, weight: .black))
                                    Text(isPrivate ? "Private" : "Public")
                                        .font(.custom("Nunito-Black", size: 14))
                                }
                                .foregroundColor(.black)
                            }
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                        }
                    }

                    // MARK: Description
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("description")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(description.count)/250")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        TextField("add a short description… (optional)", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .autocorrectionDisabled(true)
                            .font(.custom("Nunito-Black", size: 15))
                            .foregroundColor(.black)
                            .focused($descriptionFocused)
                            .onChange(of: description) { _, new in
                                if new.count > 250 { description = String(new.prefix(250)) }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.08))
                            )
                    }
                    .onChange(of: description) {
                        let draftDescription = description
                        if draftDescription.range(of: "\n") != nil {
                            hideKeyboard()
                            description = draftDescription.replacingOccurrences(of: "\n", with: "")
                        }
                    }

                    // MARK: Category (CreateSheet-style chips with expand/collapse)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("category")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(.secondary)
                            Text("*")
                                .font(.custom("Nunito-Black", size: 12))
                                .foregroundColor(.red.opacity(0.85))
                            // Selected tag (small helper)
                            if let sel = selectedCategoryChip {
                                HStack(spacing: 6) {
                                    Image(systemName: sel.icon)
                                    Text(sel.name).font(.custom("Nunito-Black", size: 13))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(Color.black.opacity(0.05))
                                )
                                .foregroundColor(.black)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: initialCategoryIcon)
                                    Text(initialCategoryName).font(.custom("Nunito-Black", size: 13))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(hex: initialCategoryColour).opacity(0.05)))
                                .foregroundColor(.black)
                            }
                        }

                        // Your same chip UI
                        VStack {
                            FlowLayout(spacing: 8) {
                                ForEach(displayedChips) { chip in
                                    let isSelected = selectedPath.contains(chip.id)
                                    EditCategoryChipButtonView(
                                        categoryChip: chip,
                                        isSelected: isSelected,
                                        color: .accentColor
                                    ) {
                                        handleChipTap(chip)

                                        // haptic
                                        let impact = UIImpactFeedbackGenerator(style: .soft)
                                        impact.prepare()
                                        impact.impactOccurred(intensity: 1.0)

                                        // persist final leaf as selectedCategoryChip
                                        if let leaf = selectedPath.last {
                                            let finalChip = repo.chip(for: leaf, level: max(0, selectedPath.count - 1))
                                            selectedCategoryChip = finalChip
                                        } else {
                                            selectedCategoryChip = nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .onChange(of: selectedCategoryChip) {
                            if selectedCategoryChip == nil {
                                categoryName = initialCategoryName
                                categoryIcon = initialCategoryIcon
                                categoryColour = initialCategoryColour
                            }
                        }

                        
                    }
                    .task {
                        repo.loadOnce()
                        if let pre = selectedCategoryChip {
                            // expand to preselected category path
                            let path = ancestorsPath(to: pre.id)
                            selectedPath = path
                            localSelection = repo.chip(for: pre.id, level: max(0, path.count - 1))
                            expandedParentID = path.first
                            expandedSubID = path.count >= 2 ? path[1] : nil
                        }
                    }
                }
                .padding(22)
            }
            .onAppear {
                initialCategoryName = categoryName
                initialCategoryIcon = categoryIcon
                initialCategoryColour = categoryColour
            }
            .background(Color.white)                // full white
            .scrollContentBackground(.hidden)       // just in case this is used inside a Form somewhere

            // MARK: Toolbar
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Details")
                        .font(.custom("Nunito-Black", size: 18))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveTapped()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Save Changes")
                }
            }
        }
        .interactiveDismissDisabled(true)
        .presentationDetents([.height(550)])       // tweak if needed
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Helpers (mirrors your CreateSheet logic)

private extension DefaultListEditDetails {

    var displayedChips: [SampleCategoryChip] {
        var flat = repo.topLevelChips
        guard let pid = expandedParentID,
              let pIdx = flat.firstIndex(where: { $0.id == pid })
        else { return flat }

        // insert level-1 after parent
        let level1 = repo.subChips(for: pid, parentLevel: 0)
        flat.insert(contentsOf: level1, at: pIdx + 1)

        // insert level-2 after the expanded sub
        if let sid = expandedSubID,
           let sIdx = flat.firstIndex(where: { $0.id == sid }),
           repo.hasSubs(sid) {
            let level2 = repo.subChips(for: sid, parentLevel: 1)
            flat.insert(contentsOf: level2, at: sIdx + 1)
        }
        return flat
    }

    func saveTapped() {
        guard !rankoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation { rankoNameShake += 1 }
            nameFocused = true
            return
        }
        
        onSave(rankoName, description, isPrivate, categoryName, categoryIcon, categoryColour)
        dismiss()
    }

    func ancestorsPath(to id: String) -> [String] {
        var path: [String] = [id]
        var cur = id
        while let p = repo.parentByChild[cur] {
            path.append(p)
            cur = p
        }
        return path.reversed()
    }

    func handleChipTap(_ chip: SampleCategoryChip) {
        let path = ancestorsPath(to: chip.id)
        let lvl  = max(0, path.count - 1)

        if let idx = selectedPath.firstIndex(of: chip.id) {
            // deselect from this node down
            selectedPath.removeSubrange(idx..<selectedPath.count)
            if let last = selectedPath.last {
                localSelection = repo.chip(for: last, level: max(0, selectedPath.count - 1))
            } else {
                localSelection = nil
            }
            withAnimation(.easeInOut(duration: 0.22)) {
                switch lvl {
                case 0:
                    expandedParentID = nil
                    expandedSubID = nil
                case 1:
                    if expandedSubID == chip.id { expandedSubID = nil }
                default: break
                }
            }
            return
        }

        // select full chain
        selectedPath = path
        localSelection = repo.chip(for: chip.id, level: lvl)

        withAnimation(.easeInOut(duration: 0.22)) {
            if lvl == 0 {
                expandedParentID = (expandedParentID == chip.id) ? nil : chip.id
                if expandedParentID == nil { expandedSubID = nil }
            } else if lvl == 1 {
                if let parent = path.first, expandedParentID != parent {
                    expandedParentID = parent
                }
                expandedSubID = (expandedSubID == chip.id) ? nil : chip.id
            } else {
                if path.count >= 2 {
                    let parent0 = path[0]
                    let parent1 = path[1]
                    if expandedParentID != parent0 { expandedParentID = parent0 }
                    if expandedSubID != parent1   { expandedSubID = parent1 }
                }
            }
        }
    }
}

struct EditCategoryChipButtonView: View {
    let categoryChip: SampleCategoryChip
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    private func bgOpacity(_ level: Int) -> Double {
        switch level { case 0: return 0.10; case 1: return 0.22; default: return 0.34 }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: categoryChip.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: 0xFFFFFF) : Color(hex: 0x1B2024))
                Text(categoryChip.name)
                    .font(.custom("Nunito-Black", size: 16))
                    .foregroundStyle(isSelected ? Color(hex: 0xFFFFFF) : Color(hex: 0x1B2024))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(isSelected ? 1 : bgOpacity(categoryChip.level)))
            )
        }
        .buttonStyle(.plain)
    }
}

struct TextView: UIViewRepresentable {
    
    typealias UIViewType = UITextView
    var configuration = { (view: UIViewType) in }
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIViewType {
        UIViewType()
    }
    
    func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<Self>) {
        configuration(uiView)
    }
}

struct DefaultListReRank: View {
    @Environment(\.dismiss) private var dismiss

    // Immutable source passed in
    private let originalItems: [RankoItem]
    private let onSave: ([RankoItem]) -> Void

    // Mutable working copy that the List will reorder
    @State private var draftItems: [RankoItem]
    @State var draggedItem : RankoItem?

    init(items: [RankoItem], onSave: @escaping ([RankoItem]) -> Void) {
        self.originalItems = items
        self.onSave = onSave
        _draftItems = State(initialValue: items)
    }

    var body: some View {
        ScrollView() {
            LazyVStack(spacing : 15) {
                ForEach(draftItems, id:\.self) { item in
                    let index = draftItems.firstIndex(where: { $0.id == item.id }) ?? 0
                    row(item: item, index: index)
                        .frame(minWidth:0, maxWidth:.infinity, minHeight:50)
                        .onDrag({
                            self.draggedItem = item
                            return NSItemProvider(item: nil, typeIdentifier: item.id)
                        }) .onDrop(of: [UTType.text], delegate: MyDropDelegate(item: item, items: $draftItems, draggedItem: $draggedItem))
                }
            }
            .padding(.vertical, 30)
            
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Button {
                        onSave(originalItems)
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("Nunito-Black", size: 22))
                            .padding(4)
                    }
                    .foregroundStyle(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0xC80000))
                    .buttonStyle(.glassProminent)
                    
                    Spacer()
                    Button {
                        for i in draftItems.indices { draftItems[i].rank = i + 1 }
                        onSave(draftItems)
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.custom("Nunito-Black", size: 22))
                            .padding(4)
                    }
                    .foregroundStyle(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0x00539B))
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(30)
        )
    }
    
    struct MyDropDelegate : DropDelegate {

        let item : RankoItem
        @Binding var items : [RankoItem]
        @Binding var draggedItem : RankoItem?

        func performDrop(info: DropInfo) -> Bool {
            return true
        }

        func dropEntered(info: DropInfo) {
            guard let draggedItem = self.draggedItem else {
                return
            }

            if draggedItem != item {
                let from = items.firstIndex(of: draggedItem)!
                let to = items.firstIndex(of: item)!
                withAnimation(.default) {
                    self.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }


    // MARK: - Row
    private func row(item: RankoItem, index: Int) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                // Badge 1: current index (SFSymbols numbered circles exist up to ~50)
                if index == 0 {
                    Image(systemName: "1.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.65, blue: 0))
                } else if index == 1 {
                    Image(systemName: "2.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.635, green: 0.7, blue: 0.698))
                } else if index == 2 {
                    Image(systemName: "3.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.56, green: 0.33, blue: 0))
                } else {
                    Image(systemName: "\(min(index + 1, 50)).circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF9864))
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            
            // Item info
            HStack(spacing: 4) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 35, height: 35)
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 35, height: 35)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 35, height: 35)
                            Image(systemName: "xmark.octagon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.trailing, 8)
                
                Text("\(item.itemName)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: 0x6D400F))
            }
            .lineLimit(1)
            Spacer()
            
            // Badge 2: compare original rank to current position (animated)
            let currentRank = item.rank
            let delta = currentRank - (index + 1)
            
            Group {
                if delta != 0 {
                    let goingUp = delta > 0
                    HStack(spacing: 2) {
                        Image(systemName: goingUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(goingUp ? .green : .red)
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                        Text(goingUp ? "\(delta)" : "\(delta * -1)")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(goingUp ? .green : .red)
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                    }
                }
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFFFFF))
                .shadow(color: Color(hex: 0x000000).opacity(0.2), radius: 4)
        )
        .padding(.horizontal, 25)
        .background(Color.gray.opacity(0))
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
