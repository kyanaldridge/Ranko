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

struct DefaultListPersonal: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    @Namespace private var namespace
    @Namespace private var transition
    
    // Required property
    let listID: String
    
    // Optional editable properties with defaults
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var category: SampleCategoryChip? = nil
    @State private var categoryName: String = ""
    @State private var categoryIcon: String? = nil
    @State private var categoryColour: UInt = 0x000000
    
    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategory: SampleCategoryChip? = nil
    
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
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
    
    // MARK: - Init now only requires listID
    init(
        listID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        category: SampleCategoryChip? = nil,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.listID = listID
        self.onDelete = onDelete
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)
        
        _originalRankoName = State(initialValue: rankoName ?? "")
        _originalDescription = State(initialValue: description ?? "")
        _originalIsPrivate = State(initialValue: isPrivate ?? false)
        _originalCategory = State(initialValue: category)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 6) {
                    HStack {
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
                                HStack(spacing: 4) {
                                    Image(systemName: categoryIcon ?? "circle")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.leading, 10)
                                    Text(categoryName)
                                        .font(.system(size: 12, weight: .bold, design: .default))
                                        .foregroundColor(.white)
                                        .padding(.trailing, 10)
                                        .padding(.vertical, 8)
                                    
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: categoryColour))
                                        .opacity(0.6)
                                )
                                
                                Spacer()
                            }
                            .padding(.top, 5)
                            .padding(.leading, 20)
                        }
                        
                        Spacer()
                        
                        Button {
                            if possiblyEdited {
                                showLeaveAlert = true
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .black))
                                .padding(.vertical, 5)
                        }
                        .foregroundColor(Color(hex: 0x514343))
                        .tint(Color(hex: 0xFFFFFF))
                        .buttonStyle(.glassProminent)
                        .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 4, x: 0, y: 0)
                        .alert(isPresented: $showLeaveAlert) {
                            CustomDialog(
                                title: "Leave Without Saving?",
                                content: "Are you sure you want to leave your Ranko without saving? All your changes will be lost.",
                                image: .init(
                                    content: "figure.walk.departure",
                                    background: .orange,
                                    foreground: .white
                                ),
                                button1: .init(
                                    content: "Leave",
                                    background: .orange,
                                    foreground: .white,
                                    action: { _ in
                                        showLeaveAlert = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            dismiss()
                                        }
                                    }
                                ),
                                button2: .init(
                                    content: "Cancel",
                                    background: .red,
                                    foreground: .white,
                                    action: { _ in
                                        showLeaveAlert = false
                                    }
                                )
                            )
                            .transition(.blurReplace.combined(with: .push(from: .bottom)))
                        } background: {
                            Rectangle()
                                .fill(.primary.opacity(0.35))
                        }
                    }
                    .padding(.trailing, 20)
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
                                                    EditItemView(item: item, listID: listID) { newName, newDesc in
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
                                                .sheet(isPresented: $showEditItemSheet) {
                                                    // Determine which item is centered
                                                    EditItemView(
                                                        item: item,
                                                        listID: listID
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
                                    }
                                    .id(imageReloadToken)
                                    .padding(.top, 25)
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
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                    exitButtonTapped.toggle()
                                                }
                                                let impact = UIImpactFeedbackGenerator(style: .soft)
                                                impact.prepare(); impact.impactOccurred(intensity: 0.8)
                                            }
                                            .sequenced(before:
                                                        DragGesture()
                                                .onChanged { value in
                                                    guard exitButtonTapped else { return }
                                                    
                                                    // make sure frames exist
                                                    let hasFrames = exitFrame != .zero && saveFrame != .zero && deleteFrame != .zero && cancelFrame != .zero
                                                    guard hasFrames else { return }
                                                    
                                                    let origin = exitFrame.center
                                                    let saveVec   = saveFrame.center   - origin
                                                    let cancelVec = cancelFrame.center - origin
                                                    let delVec    = deleteFrame.center - origin
                                                    
                                                    let lenS = saveVec.length, lenC = cancelVec.length, lenD = delVec.length
                                                    guard lenS > 1, lenC > 1, lenD > 1 else { return }
                                                    
                                                    let uS = saveVec.normalized
                                                    let uC = cancelVec.normalized
                                                    let uD = delVec.normalized
                                                    
                                                    // current drag vector
                                                    let v = CGPoint(x: value.translation.width, y: value.translation.height)
                                                    
                                                    // projections along each ray
                                                    let pS = v.dot(uS)
                                                    let pC = v.dot(uC)
                                                    let pD = v.dot(uD)
                                                    
                                                    // choose exactly one ray with the largest positive projection
                                                    enum Target { case save, cancel, delete }
                                                    let choices: [(proj: CGFloat, u: CGPoint, len: CGFloat, tgt: Target, priority: Int)] = [
                                                        (pS, uS, lenS, .save,   3),
                                                        (pC, uC, lenC, .cancel, 2),
                                                        (pD, uD, lenD, .delete, 1)
                                                    ]
                                                    // tie-break by priority if projections are equal
                                                    let best = choices.max { a, b in
                                                        if a.proj == b.proj { return a.priority < b.priority }
                                                        return a.proj < b.proj
                                                    }!
                                                    
                                                    // if best projection is not forward, clear hovers
                                                    guard best.proj > 0 else {
                                                        withAnimation { exitButtonTranslation = .zero }
                                                        withAnimation { saveButtonHovered = false }
                                                        withAnimation { cancelButtonHovered = false }
                                                        withAnimation { deleteButtonHovered = false }
                                                        return
                                                    }
                                                    
                                                    // clamp along the best ray
                                                    let proj = min(best.proj, best.len)
                                                    let snapped = best.u * max(0, proj)
                                                    exitButtonTranslation = CGSize(width: snapped.x, height: snapped.y)
                                                    
                                                    // EXCLUSIVE hover: only the best ray can be hovered
                                                    let progress = max(0, proj) / best.len
                                                    let isNearEnd = progress >= 0.7
                                                    withAnimation { saveButtonHovered   = isNearEnd && best.tgt == .save }
                                                    withAnimation { cancelButtonHovered = isNearEnd && best.tgt == .cancel }
                                                    withAnimation { deleteButtonHovered = isNearEnd && best.tgt == .delete }
                                                }
                                                .onEnded { _ in
                                                    guard exitButtonTapped else { return }
                                                    
                                                    let origin = exitFrame.center
                                                    let saveVec   = saveFrame.center   - origin
                                                    let cancelVec = cancelFrame.center - origin
                                                    let delVec    = deleteFrame.center - origin
                                                    
                                                    let lenS = saveVec.length, lenC = cancelVec.length, lenD = delVec.length
                                                    guard lenS > 1, lenC > 1, lenD > 1 else {
                                                        withAnimation { resetExitDragState() }
                                                        return
                                                    }
                                                    
                                                    let current = CGPoint(x: exitButtonTranslation.width, y: exitButtonTranslation.height)
                                                    let progS = max(0, current.dot(saveVec.normalized))   / lenS
                                                    let progC = max(0, current.dot(cancelVec.normalized)) / lenC
                                                    let progD = max(0, current.dot(delVec.normalized))    / lenD
                                                    
                                                    let threshold: CGFloat = 0.7
                                                    
                                                    // pick a single winner
                                                    enum Action { case save, cancel, delete, none }
                                                    let winners: [(CGFloat, Action, Int)] = [
                                                        (progS, .save,   3),
                                                        (progC, .cancel, 2),
                                                        (progD, .delete, 1)
                                                    ]
                                                    let best = winners.max { a, b in
                                                        if a.0 == b.0 { return a.2 < b.2 }  // tie-break
                                                        return a.0 < b.0
                                                    }!
                                                    
                                                    if best.0 >= threshold {
                                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { resetExitDragState() }
                                                        switch best.1 {
                                                        case .save:   startSave()
                                                        case .cancel: dismiss()
                                                        case .delete: showDeleteAlert = true
                                                        case .none:   break
                                                        }
                                                    } else {
                                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { resetExitDragState() }
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
                                .onChange(of: cancelButtonHovered) { old, new in
                                    if new == true {
                                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                                        impact.prepare()
                                        impact.impactOccurred(intensity: 1.0)
                                    } else {
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
                                        HStack(spacing: -10) {
                                            // DELETE
                                            VStack(spacing: 5) {
                                                Image(systemName: "trash.fill")
                                                    .resizable().scaledToFit()
                                                    .frame(width: deleteButtonHovered ? 25 : 17,
                                                           height: deleteButtonHovered ? 25 : 17)
                                                Text("Delete")
                                                    .font(.custom("Nunito-Black", size: deleteButtonHovered ? 12 : 10))
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
                                                    .frame(width: cancelButtonHovered ? 25 : 17,
                                                           height: cancelButtonHovered ? 25 : 17)
                                                Text("Cancel")
                                                    .font(.custom("Nunito-Black", size: cancelButtonHovered ? 12 : 10))
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
                                                    .frame(width: saveButtonHovered ? 25 : 17,
                                                           height: saveButtonHovered ? 25 : 17)
                                                Text("Save")
                                                    .font(.custom("Nunito-Black", size: saveButtonHovered ? 12 : 10))
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
                category: category
            ) { newName, newDescription, newPrivate, newCategory in
                rankoName   = newName
                description = newDescription
                isPrivate   = newPrivate
                category    = newCategory
                possiblyEdited = true
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
                rankoID: listID,                  // 👈 add this
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
                            removeFeaturedRanko(listID: listID) { success in}
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
                listID: listID
            ) { updated in
                // replace the old item with the updated one
                possiblyEdited = true
                if let idx = selectedRankoItems.firstIndex(where: { $0.id == updated.id }) {
                    selectedRankoItems[idx] = updated
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
    
    private func startSave() {
        guard category != nil || !categoryName.isEmpty else {
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
            listID: listID,
            newName: rankoName,
            newDescription: description,
            newCategory: category?.name ?? categoryName,
            isPrivate: isPrivate
        ) { success in
            algoliaOK = success
            if !success, firstError == nil { firstError = "Algolia update failed." }
            group.leave()
        }

        group.notify(queue: .main) {
            progressLoading = false
            if firebaseOK && algoliaOK {
                possiblyEdited = false
                // optional: toast / haptic
            } else {
                publishError = firstError ?? "Failed to save."
            }
        }
    }
    
    private func loadListFromFirebase() {
        let ref = Database.database().reference()
            .child("RankoData")
            .child(listID)

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
                let catColour = parseColourToUInt(cat?["colour"])

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
                originalCategory = category // keep as-is if you use SampleCategoryChip elsewhere
                return
            }

            // ---------- OLD SCHEMA (fallback) ----------
            let name = (root["RankoName"] as? String) ?? ""
            let des  = (root["RankoDescription"] as? String) ?? ""
            let priv = (root["RankoPrivacy"] as? Bool) ?? false

            var catName = ""
            var catIcon = "circle"
            var catColourUInt: UInt = 0x446D7A
            if let catObj = root["RankoCategory"] as? [String: Any] {
                catName = (catObj["name"] as? String) ?? ""
                catIcon = (catObj["icon"] as? String) ?? "circle"
                catColourUInt = parseColourToUInt(catObj["colour"])
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
            originalCategory = category
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
        
        let listRef = db.child("RankoData").child(listID)
        
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
            (ObjectID(rawValue: listID), .update(attribute: "RankoStatus", value: "deleted"))
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
    
    func removeFeaturedRanko(listID: String, completion: @escaping (Result<Void, Error>) -> Void) {
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

            // 2) Find the slot whose value == listID
            var didRemove = false
            for case let child as DataSnapshot in snap.children {
                if let value = child.value as? String, value == listID {
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
        let listRef = db.child("RankoData").child(listID)

        // AEDT/AEST timestamp
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        fmt.dateFormat = "yyyyMMddHHmmss"
        let ts = fmt.string(from: now)

        // resolve category fields from either chip or separate fields
        let catNameOut  = category?.name ?? categoryName
        let catIconOut  = category?.icon ?? categoryIcon ?? "circle"

        // prefer whatever your chip stores; else use the UInt state you already show
        let colourOut: String = {
            if let s = category?.colour as? String { return s }                  // already "0xRRGGBB"
            if let i = category?.colour as? Int { return String(format: "0x%06X", i & 0x00FF_FFFF) }
            return String(format: "0x%06X", Int(categoryColour) & 0x00FF_FFFF)   // from @State UInt
        }()

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

