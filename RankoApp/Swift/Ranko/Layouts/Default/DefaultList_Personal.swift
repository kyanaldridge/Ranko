//
//  DefaultList_Personal.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import Foundation
import InstantSearch
import UIKit
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseAnalytics
import PhotosUI
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

struct DefaultListPersonal: View {
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
    @State private var categoryName: String
    @State private var categoryIcon: String
    @State private var categoryColour: UInt
    
    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategoryName: String = ""
    @State private var originalCategoryIcon: String = ""
    @State private var originalCategoryColour: UInt = 0xFFFFFF
    
    // Sheets & states
    @State private var possiblyEdited = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    @State var showDeleteAlert = false
    @State var showLeaveAlert = false
    
    @State private var selectedRankoItems: [RankoItem] = []
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: (RankoItem) -> Void
    private let onDelete: (() -> Void)?
    
    @State private var addButtonTapped: Bool = false
    @State private var editButtonTapped: Bool = false
    @State private var rankButtonTapped: Bool = false
    @State private var exitButtonTapped: Bool = false
    
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
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
    
    // MARK: - Init now only requires rankoID
    init(
        rankoID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        categoryName: String,
        categoryIcon: String,
        categoryColour: UInt,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.rankoID = rankoID
        self.onDelete = onDelete
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _categoryName = State(initialValue: categoryName)
        _categoryIcon = State(initialValue: categoryIcon)
        _categoryColour = State(initialValue: categoryColour)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)
        
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
            .onAppear {
                loadListFromFirebase()
                refreshItemImages()
            }
            .sheet(isPresented: $addButtonTapped, onDismiss : {
                possiblyEdited = true
            }) {
                FilterChipPickerView(
                    selectedRankoItems: $selectedRankoItems
                )
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
            .sheet(isPresented: $rankButtonTapped) {
                DefaultListReRank(
                    items: selectedRankoItems,
                    onSave: { newOrder in
                        selectedRankoItems = newOrder
                        possiblyEdited = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showBlankItemsFS, onDismiss : {
                possiblyEdited = true
            }) {
                BlankItemsComposer(
                    rankoID: rankoID,                  // 👈 add this
                    drafts: $blankDrafts,
                    error: $draftError,
                    canAddMore: blankDrafts.count < 10,
                    onCommit: { appendDraftsToSelectedRanko() }
                )
            }
            .alert(isPresented: $showDeleteAlert) {
                CustomDialog(
                    title: "Delete Ranko?",
                    content: "Are you sure you want to delete your Ranko.",
                    image: .init(
                        content: "trash.fill",
                        background: .red,
                        foreground: .white
                    ),
                    button1: .init(
                        content: "Delete",
                        background: .red,
                        foreground: .white,
                        action: { _ in
                            showDeleteAlert = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                removeFeaturedRanko(rankoID: rankoID) { success in}
                                deleteRanko() { success in
                                    if success {
                                        print("🎉 Fields updated in Algolia")
                                    } else {
                                        print("⚠️ Failed to update fields")
                                    }
                                }
                                onDelete!()
                                dismiss()
                            }
                        }
                    ),
                    button2: .init(
                        content: "Cancel",
                        background: .orange,
                        foreground: .white,
                        action: { _ in
                            showDeleteAlert = false
                        }
                    )
                )
                .transition(.blurReplace.combined(with: .push(from: .bottom)))
            } background: {
                Rectangle()
                    .fill(.primary.opacity(0.35))
            }
            .sheet(item: $selectedItem) { tapped in
                ItemDetailView(
                    items: selectedRankoItems,
                    initialItem: tapped,
                    rankoID: rankoID
                ) { updated in
                    // replace the old item with the updated one
                    possiblyEdited = true
                    if let idx = selectedRankoItems.firstIndex(where: { $0.id == updated.id }) {
                        selectedRankoItems[idx] = updated
                    }
                }
            }
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
                ItemImage: url,                              // 👈 DB value visible in your rows
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
    
    // one draft card UI
    private struct DraftCard: View {
        @Binding var draft: BlankItemDraft
        let title: String
        let subtitle: String
        var onTapImage: () -> Void
        var onDelete: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title.uppercased())
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if draft.isUploading {
                        ProgressView().controlSize(.small)
                    }
                }
                
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
                                .resizable().scaledToFill()
                                .frame(width: 240, height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 28, weight: .black))
                                    .opacity(0.35)
                                Text(subtitle.uppercased())
                                    .font(.custom("Nunito-Black", size: 13))
                                    .opacity(0.6)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(draft.isUploading)
                
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("Item Name *", text: $draft.name)
                            .font(.system(size: 16, weight: .heavy))
                            .autocorrectionDisabled(true)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    
                    TextField("Item Description (optional)", text: $draft.description, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .semibold))
                        .autocorrectionDisabled(true)
                        .padding(10)
                        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
                
                HStack {
                    if let err = draft.uploadError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(draft.isUploading)
                    .opacity(draft.isUploading ? 0.5 : 1)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: draft.description) {
                let draftDescription = draft.description
                if draftDescription.range(of: "\n") != nil {
                    hideKeyboard()
                    draft.description = draftDescription.replacingOccurrences(of: "\n", with: "")
                }
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
    
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    private func startSave() {
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
        updateListInFirebase { success, errMsg in
            firebaseOK = success
            if !success, firstError == nil { firstError = errMsg ?? "Firebase save failed." }
            group.leave()
        }
        
        // 2) Algolia
        group.enter()
        updateListInAlgolia(
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
                categoryColour = UInt(catColour) ?? 0xFFFFFF
                
                selectedRankoItems = parsedItems.sorted { $0.rank < $1.rank }
                
                // originals (for revert)
                originalRankoName = name
                originalDescription = des
                originalIsPrivate = priv
                originalCategoryName = catName
                originalCategoryIcon = catIcon
                originalCategoryColour = UInt(catColour) ?? 0xFFFFFF
                return
            }
            
            // ---------- OLD SCHEMA (fallback) ----------
            let name = (root["RankoName"] as? String) ?? ""
            let des  = (root["RankoDescription"] as? String) ?? ""
            let priv = (root["RankoPrivacy"] as? Bool) ?? false
            
            var catName = ""
            var catIcon = "circle"
            var catColour = "0x000000"
            if let catObj = root["RankoCategory"] as? [String: Any] {
                catName = (catObj["name"] as? String) ?? ""
                catIcon = (catObj["icon"] as? String) ?? "circle"
                catColour = (catObj["colour"] as? String) ?? "0x000000"
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
            categoryColour = UInt(catColour) ?? 0xFFFFFF
            selectedRankoItems = parsedItems.sorted { $0.rank < $1.rank }
            
            originalRankoName = name
            originalDescription = des
            originalIsPrivate = priv
            originalCategoryName = catName
            originalCategoryIcon = catIcon
            originalCategoryColour = UInt(catColour) ?? 0xFFFFFF
        }
    }
    
    private struct BlankItemsComposer: View {
        @Environment(\.dismiss) private var dismiss
        @StateObject private var user_data = UserInformation.shared
        
        let rankoID: String                                  // 👈 new
        
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
                        ForEach(drafts.indices, id: \.self) { i in
                            DraftCard(
                                draft: $drafts[i],
                                title: "new item",
                                subtitle: "tap to add image (optional)",
                                onTapImage: {
                                    activeDraftID = drafts[i].id
                                    backupImage = drafts[i].image
                                    showNewImageSheet = true
                                },
                                onDelete: {
                                    // try to delete only if it was a real uploaded image
                                    let draft = drafts[i]
                                    if !isPlaceholderURL(draft.itemImageURL) {
                                        Task { await deleteStorageImage(rankoID: rankoID, itemID: draft.id) }
                                    }
                                    
                                    withAnimation {
                                        drafts.remove(at: i)
                                        if drafts.isEmpty { drafts.append(BlankItemDraft()) }
                                    }
                                    
                                    print("deleting itemID: \(draft.id)")
                                }
                            )
                            .contextMenu {
                                Button(role: .confirm) {
                                    activeDraftID = drafts[i].id
                                    backupImage = drafts[i].image
                                    showNewImageSheet = true
                                } label: { Label("Add Image", systemImage: "photo.fill") }
                                
                                Button(role: .destructive) {
                                    let draft = drafts[i]
                                    if !isPlaceholderURL(draft.itemImageURL) {
                                        Task { await deleteStorageImage(rankoID: rankoID, itemID: draft.id) }
                                    }
                                    
                                    withAnimation {
                                        drafts.remove(at: i)
                                        if drafts.isEmpty { drafts.append(BlankItemDraft()) }
                                    }
                                    
                                    print("deleting itemID: \(draft.id)")
                                    
                                } label: { Label("Delete", systemImage: "trash") }
                                
                                Button(role: .close) {
                                    drafts[i].description = ""
                                    drafts[i].image = nil
                                    drafts[i].name = ""
                                    
                                    let draft = drafts[i]
                                    
                                    if !isPlaceholderURL(draft.itemImageURL) {
                                        Task { await deleteStorageImage(rankoID: rankoID, itemID: draft.id) }
                                    }
                                    
                                    print("deleting itemID: \(draft.id)")
                                    
                                } label: { Label("Clear All", systemImage: "delete.right.fill") }
                            }
                        }
                        
                        Button {
                            withAnimation { drafts.append(BlankItemDraft()) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.app.fill")
                                    .font(.custom("Nunito-Black", size: 18))
                                Text("add another blank item")
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
    
    
    // Helper to safely coerce Firebase numbers/strings into Int
    private func intFromAny(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }
    
    // Item Helpers
    private func delete(_ item: RankoItem) {
        selectedRankoItems.removeAll { $0.id == item.id }
        normalizeRanks()
        possiblyEdited = true
    }
    
    private func moveToTop(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.insert(moved, at: 0)
        normalizeRanks()
        possiblyEdited = true
    }
    
    private func moveToBottom(_ item: RankoItem) {
        guard let idx = selectedRankoItems.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = selectedRankoItems.remove(at: idx)
        selectedRankoItems.append(moved)
        normalizeRanks()
        possiblyEdited = true
    }
    
    private func normalizeRanks() {
        for index in selectedRankoItems.indices {
            selectedRankoItems[index].rank = index + 1
        }
    }
    
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
    
    // MARK: - Firebase Update
    private func updateListInFirebase(completion: @escaping (_ success: Bool, _ errorMessage: String?) -> Void) {
        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(rankoID)
        
        // AEDT/AEST timestamp
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        fmt.dateFormat = "yyyyMMddHHmmss"
        let ts = fmt.string(from: now)
        
        // resolve category fields from either chip or separate fields
        let catNameOut  = categoryName
        let catIconOut  = categoryIcon
        let colourOut   = categoryColour
        
        // fan-out partial updates to nested paths
        let updates: [String: Any] = [
            "RankoDetails/name":        rankoName,
            "RankoDetails/description": description,
            
            "RankoPrivacy/private":     isPrivate,
            
            "RankoCategory/name":       catNameOut,
            "RankoCategory/icon":       catIconOut,
            "RankoCategory/colour":     colourOut,
            
            "RankoDateTime/updated":    ts
        ]
        
        // rebuild RankoItems blob
        var itemsUpdate: [String: Any] = [:]
        for it in selectedRankoItems {
            itemsUpdate[it.id] = [
                "ItemID":          it.id,
                "ItemName":        it.record.ItemName,
                "ItemDescription": it.record.ItemDescription,
                "ItemImage":       it.record.ItemImage,
                "ItemRank":        it.rank,
                "ItemVotes":       it.votes,
                "ItemGIF":         "",
                "ItemVideo":       "",
                "ItemAudio":       "",
                "PlayCount":       0
            ]
        }
        
        // run both writes
        let group = DispatchGroup()
        var ok1 = false, ok2 = false
        var err: String?
        
        group.enter()
        listRef.updateChildValues(updates) { e, _ in
            ok1 = (e == nil)
            if let e = e { err = "details/privacy/category: \(e.localizedDescription)" }
            group.leave()
        }
        
        group.enter()
        listRef.child("RankoItems").setValue(itemsUpdate) { e, _ in
            ok2 = (e == nil)
            if let e = e, err == nil { err = "items: \(e.localizedDescription)" }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(ok1 && ok2, ok1 && ok2 ? nil : (err ?? "unknown firebase error"))
        }
    }
    
    // MARK: - Algolia Update
    private func updateListInAlgolia(
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
        
        // ✅ Prepare partial updates
        let updates: [(ObjectID, PartialUpdate)] = [
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoName", value: .string(newName))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoDescription", value: .string(newDescription))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoCategory", value: .string(newCategory))),
            (ObjectID(rawValue: rankoID), .update(attribute: "RankoPrivacy", value: .bool(isPrivate)))
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

