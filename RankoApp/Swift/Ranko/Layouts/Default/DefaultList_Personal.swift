//
//  DefaultList_Personal.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import InstantSearchCore
import Firebase
import FirebaseAuth
import Foundation
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
    @State private var categoryID: String = ""
    @State private var categoryName: String = ""
    @State private var categoryIcon: String? = nil
    
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
    
    @State private var activeTab: DefaultListPersonalTab = .addItems
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
                                                            ItemImage: rec.ItemImage
                                                        )
                                                        let updatedItem = RankoItem(
                                                            id: item.id,
                                                            rank: item.rank,
                                                            votes: item.votes,
                                                            record: updatedRecord
                                                        )
                                                        // callback to parent
                                                        onSave(updatedItem)
                                                    }
                                                }
                                        }
                                    }
                                    .id(imageReloadToken)
                                    .padding(.top, 25)
                                    .padding(.bottom, 30)
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
        .sheet(isPresented: $showAddItemsSheet, onDismiss : {
            possiblyEdited = true
        }) {
            FilterChipPickerView(
                selectedRankoItems: $selectedRankoItems
            )
        }
        .sheet(isPresented: $showEditDetailsSheet) {
            DefaultListEditDetails(
                rankoName: rankoName,
                description: description,
                isPrivate: isPrivate,
                category: category
            ) { newName, newDescription, newPrivate, newCategory in
                possiblyEdited = true
                rankoName    = newName
                description  = newDescription
                isPrivate    = newPrivate
                category     = newCategory
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            DefaultListReRank(
                items: selectedRankoItems,
                onSave: { newOrder in
                    selectedRankoItems = newOrder
                    possiblyEdited = true
                }
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
                if let idx = selectedRankoItems.firstIndex(where: { $0.id == updated.id }) {
                    selectedRankoItems[idx] = updated
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
        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(listID)

        listRef.observeSingleEvent(of: .value, with: { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("⚠️ No data at RankoData/\(listID)")
                return
            }

            // map top-level
            let rankoName   = data["RankoName"]        as? String ?? ""
            let description = data["RankoDescription"] as? String ?? ""
            let isPrivate   = data["RankoPrivacy"]     as? Bool   ?? false

            // push to UI on main
            DispatchQueue.main.async {
                self.rankoName   = rankoName
                self.description = description
                self.isPrivate   = isPrivate
            }

            // --- ITEMS ---
            if let itemsDict = data["RankoItems"] as? [String: [String: Any]] {
                var loaded: [RankoItem] = []

                for (_, itemData) in itemsDict {
                    guard
                        let id    = itemData["ItemID"]          as? String,
                        let name  = itemData["ItemName"]        as? String,
                        let desc  = itemData["ItemDescription"] as? String,
                        let image = itemData["ItemImage"]       as? String,
                        let rank  = itemData["ItemRank"]        as? Int,
                        let votes = itemData["ItemVotes"]       as? Int
                    else { continue }

                    let record = RankoRecord(
                        objectID: id,
                        ItemName: name,
                        ItemDescription: desc,
                        ItemCategory: "",   // populate if you store per-item cats
                        ItemImage: image
                    )

                    loaded.append(RankoItem(id: id, rank: rank, votes: votes, record: record))
                }

                DispatchQueue.main.async {
                    self.selectedRankoItems = loaded.sorted { $0.rank < $1.rank }
                }
            }

        }, withCancel: { error in
            print("❌ Firebase load error:", error.localizedDescription)
        })
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
        // allow save even if category object is nil, fall back to stored strings
        let catName = category?.name ?? categoryName

        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(listID)

        // top-level fields
        let listUpdates: [String: Any] = [
            "RankoName": rankoName,
            "RankoDescription": description,
            "RankoPrivacy": isPrivate,
            "RankoCategory": catName
        ]

        // items blob
        var itemsUpdate: [String: Any] = [:]
        for item in selectedRankoItems {
            itemsUpdate[item.id] = [
                "ItemID": item.id,
                "ItemName": item.record.ItemName,
                "ItemDescription": item.record.ItemDescription,
                "ItemImage": item.record.ItemImage,
                "ItemRank": item.rank,
                "ItemVotes": item.votes
            ]
        }

        // run both writes, then call completion
        let group = DispatchGroup()
        var ok1 = false, ok2 = false
        var errMsg: String?

        group.enter()
        listRef.updateChildValues(listUpdates) { error, _ in
            ok1 = (error == nil)
            if let e = error { errMsg = "List fields: \(e.localizedDescription)" }
            group.leave()
        }

        group.enter()
        listRef.child("RankoItems").setValue(itemsUpdate) { error, _ in
            ok2 = (error == nil)
            if let e = error, errMsg == nil { errMsg = "Items: \(e.localizedDescription)" }
            group.leave()
        }

        group.notify(queue: .main) {
            completion(ok1 && ok2, errMsg)
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

struct DefaultListPersonal2: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared

    // Required property
    let listID: String

    // Optional editable properties with defaults
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var category: SampleCategoryChip? = nil
    @State private var categoryID: String = ""
    @State private var categoryName: String = ""
    @State private var categoryIcon: String? = nil

    // Original values (to revert if needed)
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategory: SampleCategoryChip? = nil

    // Sheets & states
    @State private var showTabBar = true
    @State private var tabBarPresent = false
    @State private var possiblyEdited = false
    @State var showEditDetailsSheet = false
    @State var showAddItemsSheet = false
    @State var showReorderSheet = false
    @State var showEditItemSheet = false
    @State var showExitSheet = false
    @State private var showDeleteAlert = false
    @State private var showLeaveAlert = false

    @State private var activeTab: DefaultListPersonalTab = .addItems
    @State private var selectedRankoItems: [RankoItem] = []
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: ((RankoItem) -> Void)? = nil
    private let onDelete: (() -> Void)?

    enum TabType { case edit, add, reorder }

    // MARK: - Init now only requires listID
    init(
        listID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        category: SampleCategoryChip? = nil,
        selectedRankoItems: [RankoItem] = [],
        onSave: ((RankoItem) -> Void)? = nil,
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
            Color(hex: 0xFFF5E1).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 7) {
                    HStack {
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
                        }
                        Spacer(minLength: 0)
                        Button {
                            if possiblyEdited {
                                showLeaveAlert = true
                            } else {
                                showTabBar = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    dismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .heavy, design: .default))
                                .padding(.vertical, 6)
                        }
                        .foregroundColor(Color(hex: 0x6D400F))
                        .tint(Color(hex: 0xFFF9EE))
                        .buttonStyle(.glassProminent)
                        .padding(.trailing, 30)
                    }
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
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
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
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        showTabBar = true
                                    }
                                }
                            )
                        )
                        .transition(.blurReplace.combined(with: .push(from: .bottom)))
                    } background: {
                        Rectangle()
                            .fill(.primary.opacity(0.35))
                    }
                    
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
                .padding(.bottom, 5)
                
                VStack {
                    ScrollView {
                        ForEach(selectedRankoItems.sorted { $0.rank < $1.rank }) { item in
                            DefaultListItemRow(item: item)
                                .onTapGesture {
                                    showTabBar = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        selectedItem = item
                                    }
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
                                        listID: listID
                                    ) { newName, newDesc in
                                        // build updated record & item
                                        let rec = item.record
                                        let updatedRecord = RankoRecord(
                                            objectID: rec.objectID,
                                            ItemName: newName,
                                            ItemDescription: newDesc,
                                            ItemCategory: "",
                                            ItemImage: rec.ItemImage
                                        )
                                        let updatedItem = RankoItem(
                                            id: item.id,
                                            rank: item.rank,
                                            votes: item.votes,
                                            record: updatedRecord
                                        )
                                        // callback to parent
                                        onSave!(updatedItem)
                                    }
                                }
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 70)
                    }
                    Spacer()
                }
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
        .onAppear {
            loadListFromFirebase()
        }
        .sheet(isPresented: $showAddItemsSheet) {
            FilterChipPickerView(
                selectedRankoItems: $selectedRankoItems
            )
        }
        .sheet(isPresented: $showEditDetailsSheet) {
            DefaultListEditDetails(
                rankoName: rankoName,
                description: description,
                isPrivate: isPrivate,
                category: category
            ) { newName, newDescription, newPrivate, newCategory in
                possiblyEdited = true
                rankoName    = newName
                description  = newDescription
                isPrivate    = newPrivate
                category     = newCategory
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            DefaultListReRank(
                items: selectedRankoItems,
                onSave: { newOrder in
                    selectedRankoItems = newOrder
                    possiblyEdited = true
                }
            )
        }
        .sheet(isPresented: $showExitSheet) {
            DefaultListPersonalExit(
                onSave: {
                    updateListInAlgolia(
                        listID: listID,
                        newName: rankoName,
                        newDescription: description,
                        newCategory: category!.name,
                        isPrivate: isPrivate
                    ) { success in
                        if success {
                            print("🎉 Fields updated in Algolia")
                        } else {
                            print("⚠️ Failed to update fields")
                        }
                    }
                    updateListInFirebase()
                    dismiss()
                },
                onLeave: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()   // dismiss DefaultListView without saving
                    }
                },
                onDelete: {
                    showTabBar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        showDeleteAlert = true
                    }
                }
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
                        showTabBar = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            showTabBar = true
                        }
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
                if let idx = selectedRankoItems.firstIndex(where: { $0.id == updated.id }) {
                    selectedRankoItems[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showTabBar) {
            VStack {
                HStack(spacing: 0) {
                    ForEach(DefaultListPersonalTab.visibleCases, id: \.rawValue) { tab in
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
                                possiblyEdited = true
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
    }
    
    private func loadListFromFirebase() {
        let db = Database.database().reference()
        let listRef = db.child("RankoData").child(listID)

        listRef.observeSingleEvent(of: .value, with: { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("⚠️ No data at RankoData/\(listID)")
                return
            }

            // map top-level
            let rankoName   = data["RankoName"]        as? String ?? ""
            let description = data["RankoDescription"] as? String ?? ""
            let isPrivate   = data["RankoPrivacy"]     as? Bool   ?? false

            // push to UI on main
            DispatchQueue.main.async {
                self.rankoName   = rankoName
                self.description = description
                self.isPrivate   = isPrivate
            }

            // --- CATEGORY LOOKUP ---
            // Prefer an ID if present; otherwise fall back to the old name field.
            let catID   = (data["RankoCategoryID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let catName = (data["RankoCategory"]   as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let id = catID, !id.isEmpty {
                fetchCategoryByID(id) { cat in
                    DispatchQueue.main.async {
                        if let cat {
                            // adapt to your model:
                            // if you still have `self.category` (SampleCategoryChip?), construct it here.
                            // Else store resolved bits:
                            self.categoryID   = cat.id
                            self.categoryName = cat.name
                            self.categoryIcon = cat.icon
                        } else {
                            // fallback if id missing in DB
                            self.categoryID   = id
                            self.categoryName = catName ?? id
                            self.categoryIcon = nil
                        }
                    }
                }
            } else if let name = catName, !name.isEmpty {
                fetchCategoryByName(name) { cat in
                    DispatchQueue.main.async {
                        if let cat {
                            self.categoryID   = cat.id
                            self.categoryName = cat.name
                            self.categoryIcon = cat.icon
                        } else {
                            // still show something
                            self.categoryID   = ""
                            self.categoryName = name
                            self.categoryIcon = nil
                        }
                    }
                }
            } else {
                print("⚠️ No category field present on RankoData/\(listID)")
            }

            // --- ITEMS ---
            if let itemsDict = data["RankoItems"] as? [String: [String: Any]] {
                var loaded: [RankoItem] = []

                for (_, itemData) in itemsDict {
                    guard
                        let id    = itemData["ItemID"]          as? String,
                        let name  = itemData["ItemName"]        as? String,
                        let desc  = itemData["ItemDescription"] as? String,
                        let image = itemData["ItemImage"]       as? String,
                        let rank  = itemData["ItemRank"]        as? Int,
                        let votes = itemData["ItemVotes"]       as? Int
                    else { continue }

                    let record = RankoRecord(
                        objectID: id,
                        ItemName: name,
                        ItemDescription: desc,
                        ItemCategory: "",   // populate if you store per-item cats
                        ItemImage: image
                    )

                    loaded.append(RankoItem(id: id, rank: rank, votes: votes, record: record))
                }

                DispatchQueue.main.async {
                    self.selectedRankoItems = loaded.sorted { $0.rank < $1.rank }
                }
            }

        }, withCancel: { error in
            print("❌ Firebase load error:", error.localizedDescription)
        })
    }
    
    
    
    private func fetchCategoryByID(_ id: String, completion: @escaping (SampleCategoryChip?) -> Void) {
        let ref = Database.database().reference()
            .child("AppData").child("CategoryData").child(id) // <- correct path

        ref.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any] else {
                completion(nil); return
            }
            let cd = SampleCategoryChip(
                id: id,
                name: dict["name"] as? String ?? id,
                icon: (dict["icon"] as? String)!
            )
            completion(cd)
        }
    }

    private func fetchCategoryByName(_ name: String, completion: @escaping (SampleCategoryChip?) -> Void) {
        // scan CategoryData once; if your DB is large, consider caching
        let ref = Database.database().reference()
            .child("AppData").child("CategoryData")

        ref.observeSingleEvent(of: .value) { snap in
            guard let all = snap.value as? [String: [String: Any]] else {
                completion(nil); return
            }
            // case-insensitive match on "name"
            if let (id, dict) = all.first(where: { (_, v) in
                (v["name"] as? String)?.caseInsensitiveCompare(name) == .orderedSame
            }) {
                let cd = SampleCategoryChip(
                    id: id,
                    name: (dict["name"] as? String) ?? name,
                    icon: (dict["icon"] as? String)!
                )
                completion(cd)
            } else {
                completion(nil)
            }
        }
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
    private func updateListInFirebase() {
        guard let category = category else { return }
        
        let db = Database.database().reference()
        
        // ✅ Prepare the top-level fields to update
        let listUpdates: [String: Any] = [
            "RankoName": rankoName,
            "RankoDescription": description,
            "RankoPrivacy": isPrivate,
            "RankoCategory": category.name
        ]
        
        let listRef = db.child("RankoData").child(listID)
        
        // ✅ Update list fields
        listRef.updateChildValues(listUpdates) { error, _ in
            if let err = error {
                print("❌ Failed to update list fields: \(err.localizedDescription)")
            } else {
                print("✅ List fields updated successfully")
            }
        }
        
        // ✅ Prepare all RankoItems
        var itemsUpdate: [String: Any] = [:]
        for item in selectedRankoItems {
            itemsUpdate[item.id] = [
                "ItemID": item.id,
                "ItemName": item.record.ItemName,
                "ItemDescription": item.record.ItemDescription,
                "ItemImage": item.record.ItemImage,
                "ItemRank": item.rank,
                "ItemVotes": item.votes
            ]
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

enum DefaultListPersonalTab: String, CaseIterable {
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
    
    static var visibleCases: [DefaultListPersonalTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}

struct DefaultListPersonalExit: View {
    @Environment(\.dismiss) var dismiss
    
    var onSave: () -> Void
    var onLeave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                HStack {
                    Button {
                        print("Save Tapped")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        onSave()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Save")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0x42ADFF))
                    .buttonStyle(.glassProminent)
                    Button {
                        print("Don't Save Tapped")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        onLeave()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Don't Save")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .foregroundColor(Color(hex: 0xFFFFFF))
                    .tint(Color(hex: 0xFE8C34))
                    .buttonStyle(.glassProminent)
                }
                Button {
                    print("Delete Tapped")
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    onDelete()
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                        Text("Delete")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .foregroundColor(Color(hex: 0xFFFFFF))
                .tint(Color(hex: 0xE93B3D))
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 40)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                        print("Cancel Exit Tapped")
                    }
                }
            }
        }
        .presentationBackground(Color.white)
        .presentationDetents([.height(300)])
        .ignoresSafeArea()
    }
}

struct DefaultListPersonal_Previews: PreviewProvider {
    // Create 10 sample RankoItem instances representing top destinations
    static var sampleItems: [RankoItem] = [
        RankoItem(
            id: UUID().uuidString,
            rank: 1,
            votes: 0,
            record: RankoRecord(
                objectID: "1",
                ItemName: "Paris",
                ItemDescription: "The City of Light",
                ItemCategory: "",
                ItemImage:"https://res.klook.com/image/upload/c_fill,w_750,h_750/q_80/w_80,x_15,y_15,g_south_west,l_Klook_water_br_trans_yhcmh3/activities/wrgwlkhnjekv8h5tjbn4.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 2,
            votes: 0,
            record: RankoRecord(
                objectID: "2",
                ItemName: "New York",
                ItemDescription: "The Big Apple",
                ItemCategory: "",
                ItemImage:"https://hips.hearstapps.com/hmg-prod/images/manhattan-skyline-with-empire-state-building-royalty-free-image-960609922-1557777571.jpg?crop=0.66635xw:1xh;center,top&resize=640:*"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3,
            votes: 0,
            record: RankoRecord(
                objectID: "3",
                ItemName: "Tokyo",
                ItemDescription: "Land of the Rising Sun",
                ItemCategory: "",
                ItemImage:"https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/04/10/13/tokyo-main.jpg?width=1200&height=1200&fit=crop"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 4,
            votes: 0,
            record: RankoRecord(
                objectID: "4",
                ItemName: "Rome",
                ItemDescription: "a city steeped in history, culture, and artistic treasures, often referred to as the Eternal City",
                ItemCategory: "",
                ItemImage:"https://i.guim.co.uk/img/media/03303b5f042b72c03541fcd7f3777180f61a01a5/0_2310_4912_2947/master/4912.jpg?width=1200&height=1200&quality=85&auto=format&fit=crop&s=19cf880f7508ea310bdb136057d78240"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 5,
            votes: 0,
            record: RankoRecord(
                objectID: "5",
                ItemName: "Sydney",
                ItemDescription: "Harbour City",
                ItemCategory: "",
                ItemImage:"https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/93/a7/be/sydney-opera-house.jpg?w=500&h=500&s=1"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 6,
            votes: 0,
            record: RankoRecord(
                objectID: "6",
                ItemName: "Barcelona",
                ItemDescription: "Gaudí’s Masterpiece City",
                ItemCategory: "",
                ItemImage:"https://lp-cms-production.imgix.net/2023-08/iStock-1297827939.jpg?fit=crop&ar=1%3A1&w=1200&auto=format&q=75"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 7,
            votes: 0,
            record: RankoRecord(
                objectID: "7",
                ItemName: "Cape Town",
                ItemDescription: "Mother City of South Africa",
                ItemCategory: "",
                ItemImage:"https://imageresizer.static9.net.au/0sx9mhfU8tYDs_T-ftiFBrWR_as=/0x0:1307x735/1200x1200/https%3A%2F%2Fprod.static9.net.au%2Ffs%2F15af5183-fb21-49d9-a22c-d9f4813ccbea"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 8,
            votes: 0,
            record: RankoRecord(
                objectID: "8",
                ItemName: "Rio de Janeiro",
                ItemDescription: "Marvelous City",
                ItemCategory: "",
                ItemImage:"https://whc.unesco.org/uploads/thumbs/site_1100_0004-750-750-20120625114004.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 9,
            votes: 0,
            record: RankoRecord(
                objectID: "9",
                ItemName: "Reykjavik",
                ItemDescription: "Land of Fire and Ice",
                ItemCategory: "",
                ItemImage:"https://media.gq-magazine.co.uk/photos/5d138e07d7a7017355bb9bf3/1:1/w_1280,h_1280,c_limit/reykjavik-gq-22jun18_istock_b.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 10,
            votes: 0,
            record: RankoRecord(
                objectID: "10",
                ItemName: "Istanbul",
                ItemDescription: "Where East Meets West",
                ItemCategory: "",
                ItemImage:"https://images.contentstack.io/v3/assets/blt06f605a34f1194ff/blt289d3aab2da77bc9/6777f31f93a84b03b5a37ef2/BCC-2023-EXPLORER-Istanbul-Fun-things-to-do-in-Istanbul-HEADER_MOBILE.jpg?format=webp&auto=avif&quality=60&crop=1%3A1&width=425"
            )
        )
    ]

    static var previews: some View {
        DefaultListView(
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: SampleCategoryChip(id: "", name: "Countries", icon: "globe.europe.africa.fill"),
            selectedRankoItems: sampleItems
        ) { updatedItem in
            // no-op in preview
        }
         // Optional: wrap in a NavigationView or set a fixed frame for better preview layout
        .previewLayout(.sizeThatFits)
    }
}

