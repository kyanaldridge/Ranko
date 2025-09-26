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
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    @AppStorage("group_view_mode") private var groupViewMode: GroupViewMode = .defaultList

    // Init properties
    @State private var listUUID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: SampleCategoryChip?
    
    // to revert to old values
    @State private var originalRankoName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalIsPrivate: Bool = false
    @State private var originalCategory: SampleCategoryChip? = nil
    @State private var onSave: (RankoItem) -> Void = { _ in }  // or delete if unused

    // Sheet states
    @State var showEditItemSheet = false
    @State var showAddItemsSheet = false
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
    @State private var selectedItem: RankoItem? = nil
    @State private var selectedDetailItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    
    @State private var imageReloadToken = UUID()
    
    @State private var isPresentingSheet = false
    @State private var isExpanded = false
    @Namespace private var namespace
    @Namespace private var transition
    
    @State private var progressLoading: Bool = false       // ← shows the loader
    @State private var publishError: String? = nil         // ← error messaging
    @State private var showEmbeddedStickyPoolSheet = false
    
    // MARK: - ITEM VARIABLES
    @State private var unGroupedItems: [RankoItem] = []
    @State private var groupedItems: [[RankoItem]]
    
    // MARK: - OTHER VARIABLES (INC. TOAST)
    @State private var hoveredRow: Int? = nil
    
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
        _originalRankoName   = State(initialValue: rankoName)
        _originalDescription = State(initialValue: description)
        _originalIsPrivate   = State(initialValue: isPrivate)
        _originalCategory    = State(initialValue: category)
        _onSave              = State(initialValue: { _ in })
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
    
    private enum GroupViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x514343), Color(hex: 0x000000)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 6) {
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
                    
                    ZStack(alignment: .bottom) {
                        
                        ScrollView {
                            VStack {
                                ScrollView {
                                    VStack(spacing: 7) {
                                        switch groupViewMode {
                                        case .defaultList:
                                            ScrollView(.vertical, showsIndicators: false) {
                                                VStack(spacing: 12) {
                                                    ForEach(groupedItems.indices, id: \.self) { i in
                                                        GroupRowView(
                                                            rowIndex:       i,
                                                            items:          groupedItems[i],
                                                            itemRows:       $groupedItems,
                                                            unGroupedItems: $unGroupedItems,
                                                            hoveredRow:     $hoveredRow,
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
                                                            rowIndex:       i,
                                                            items:          groupedItems[i],
                                                            itemRows:       $groupedItems,
                                                            unGroupedItems: $unGroupedItems,
                                                            hoveredRow:     $hoveredRow,
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
                                                            rowIndex:       i,
                                                            items:          groupedItems[i],
                                                            itemRows:       $groupedItems,
                                                            unGroupedItems: $unGroupedItems,
                                                            hoveredRow:     $hoveredRow,
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
                                                            //startPublishAndDismiss()
                                                        } else if progressOnDel >= threshold {
                                                            // commit Delete (your current action = dismiss)
                                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                                exitButtonTranslation = .zero
                                                                saveButtonHovered = false
                                                                deleteButtonHovered = false
                                                                exitButtonTapped = false
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
                                                    //startPublishAndDismiss()  // ← NEW
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
        .interactiveDismissDisabled(progressLoading) // block pull-to-dismiss on sheets while saving
        .disabled(progressLoading)                   // block interactions while saving
        .alert("Couldn't publish", isPresented: .init(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("Retry") {
                //startPublishAndDismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(publishError ?? "Something went wrong.")
        }
        .sheet(isPresented: $showAddItemsSheet, onDismiss: {
            // When FilterChipPickerView closes, trigger the embeddedStickyPoolView sheet
            showEmbeddedStickyPoolSheet = true
        }) {
            FilterChipPickerView(
                selectedRankoItems: $unGroupedItems
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
            }
            .navigationTransition(
                .zoom(sourceID: "editButton", in: transition)
            )
        }
        
        // SINGLE edit sheet bound to the selected item (no per-row sheets)
        .sheet(item: $selectedDetailItem) { tappedItem in
            let rowIndex = groupedItems.firstIndex { row in
                row.contains { $0.id == tappedItem.id }
            } ?? 0

            GroupItemDetailView(
                items: groupedItems[rowIndex],
                rowIndex: rowIndex,
                numberOfRows: (groupedItems.count),
                initialItem: tappedItem,
                listID:  listUUID
            ) { updatedItem in
                if let idx = groupedItems[rowIndex]
                                .firstIndex(where: { $0.id == updatedItem.id }) {
                    groupedItems[rowIndex][idx] = updatedItem
                }
            }
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
    }
    
//    @MainActor
//    private func startPublishAndDismiss() {
//        guard category != nil else {
//            publishError = "Please pick a category before saving."
//            return
//        }
//        progressLoading = true
//        Task {
//            do {
//                try await publishRanko()
//                progressLoading = false
//                dismiss()
//            } catch {
//                progressLoading = false
//                publishError = error.localizedDescription
//            }
//        }
//    }
//
//    private func publishRanko() async throws {
//        // run both saves concurrently; finish only when both do
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            group.addTask { try await saveRankedListToAlgoliaAsync() }
//            group.addTask { try await saveRankedListToFirebaseAsync() }
//            try await group.waitForAll()
//        }
//    }
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
        let items: [RankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    let enumeratedItems = Array(items.enumerated())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(enumeratedItems, id: \.1.id) { pair in
                                let (_, item) = pair
                                GroupSelectedItemRow(
                                    item:       item
                                )
                                .onDrag  { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView2: View {
        let rowIndex: Int
        let items: [RankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    // items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                GroupSelectedItemRow2(item: item)
                                    .onDrag { NSItemProvider(object: item.id as NSString) }
                                    .onTapGesture {
                                        selectedDetailItem = item  // TRIGGER SHEET
                                    }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                  .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView3: View {
        let rowIndex: Int
        let items: [RankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    
                    .padding(.top, 10)
                    
                    // items
                    FlowLayout2(spacing: 6) {
                        ForEach(items) { item in
                            GroupSelectedItemRow3(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture {
                                    selectedDetailItem = item  // TRIGGER SHEET
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.leading, .bottom, .trailing], 8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
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

    // MARK: - Algolia (async)

//    private func saveRankedListToAlgoliaAsync() async throws {
//        guard let category = category else { throw PublishErr.missingCategory }
//
//        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
//        let invalidSet = CharacterSet(charactersIn: ".#$[]")
//        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
//        guard !safeUID.isEmpty else { throw PublishErr.invalidUserID }
//
//        let now = Date()
//        let aedtFormatter = DateFormatter()
//        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
//        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
//        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
//        let rankoDateTime = aedtFormatter.string(from: now)
//
//        let listRecord = RankoListAlgolia(
//            objectID:         listUUID,
//            RankoName:        rankoName,
//            RankoDescription: description,
//            RankoType:        "default",
//            RankoPrivacy:     isPrivate,
//            RankoStatus:      "active",
//            RankoCategory:    category.name,
//            RankoUserID:      safeUID,
//            RankoDateTime:    rankoDateTime,
//            RankoLikes:       0,
//            RankoComments:    0,
//            RankoVotes:       0
//        )
//
//        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//            listsIndex.saveObject(listRecord) { result in
//                switch result {
//                case .success:
//                    cont.resume()
//                case .failure(let err):
//                    cont.resume(throwing: err)
//                }
//            }
//        }
//    }

    // MARK: - Firebase (async)

//    private func saveRankedListToFirebaseAsync() async throws {
//        guard let category = category else { throw PublishErr.missingCategory }
//
//        let db = Database.database().reference()
//        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
//        let invalidSet = CharacterSet(charactersIn: ".#$[]")
//        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
//        guard !safeUID.isEmpty else { throw PublishErr.invalidUserID }
//
//        // Items payload
//        var rankoItemsDict: [String: Any] = [:]
//        for item in selectedRankoItems {
//            let itemID = UUID().uuidString
//            rankoItemsDict[itemID] = [
//                "ItemID":          itemID,
//                "ItemRank":        item.rank,
//                "ItemName":        item.itemName,
//                "ItemDescription": item.itemDescription,
//                "ItemImage":       item.itemImage,
//                "ItemVotes":       0
//            ]
//        }
//
//        // timestamps
//        let now = Date()
//        let aedtFormatter = DateFormatter()
//        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
//        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
//        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
//        let rankoDateTime = aedtFormatter.string(from: now)
//
//        // list node
//        let listDataForFirebase: [String: Any] = [
//            "RankoID":          listUUID,
//            "RankoName":        rankoName,
//            "RankoDescription": description,
//            "RankoType":        "default",
//            "RankoPrivacy":     isPrivate,
//            "RankoStatus":      "active",
//            "RankoCategory":    category.name,
//            "RankoUserID":      safeUID,
//            "RankoItems":       rankoItemsDict,
//            "RankoDateTime":    rankoDateTime,
//        ]
//
//        // write both nodes concurrently
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            group.addTask {
//                try await setValueAsync(
//                    db.child("RankoData").child(listUUID),
//                    value: listDataForFirebase
//                )
//            }
//            group.addTask {
//                try await setValueAsync(
//                    db.child("UserData").child(safeUID)
//                      .child("UserRankos").child("UserActiveRankos").child(listUUID),
//                    value: category.name
//                )
//            }
//            try await group.waitForAll()
//        }
//    }

    // Wrap Firebase setValue into async/await
    private func setValueAsync(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
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
}


struct GroupListView2: View {
    
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
    
    // MARK: - BODY VIEW
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xFFF5E1).ignoresSafeArea()
            ScrollView {
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
                        
                    }
                    .padding(.leading, 20)
                    
                    Divider()
                    
                    switch groupViewMode {
                    case .defaultList:
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(groupedItems.indices, id: \.self) { i in
                                    GroupRowView(
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
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
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
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
                                        rowIndex:       i,
                                        items:          groupedItems[i],
                                        itemRows:       $groupedItems,
                                        unGroupedItems: $unGroupedItems,
                                        hoveredRow:     $hoveredRow,
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
        .sheet(isPresented: $showExitSheet) {
            DefaultListExit(
                onSave: {
                    saveRankedListToAlgolia()
                    saveRankedListToFirebase()
                    showTabBar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()
                    }
                },
                onDelete: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        dismiss()   // dismiss DefaultListView without saving
                    }   // dismiss DefaultListView without saving
                }
            )
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
            RankoDateTime:    rankoDateTime,
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
        let items: [RankoItem]
        
        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    let enumeratedItems = Array(items.enumerated())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(enumeratedItems, id: \.1.id) { pair in
                                let (_, item) = pair
                                GroupSelectedItemRow(
                                    item:       item
                                )
                                .onDrag  { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture { selectedDetailItem = item }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                        RowDropDelegate(
                            itemRows: $itemRows,
                            unGrouped: $unGroupedItems,
                            hoveredRow: $hoveredRow,
                            targetRow: rowIndex
                        )
            )
        }
        
        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                    .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView2: View {
        let rowIndex: Int
        let items: [RankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    // items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                GroupSelectedItemRow2(item: item)
                                    .onDrag { NSItemProvider(object: item.id as NSString) }
                                    .onTapGesture {
                                        selectedDetailItem = item  // TRIGGER SHEET
                                    }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
            if hoveredRow == rowIndex {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color(hex: 0x6D400F), lineWidth: 2)
                  .shadow(color: Color(hex: 0x6D400F).opacity(0.6), radius: 8)
            }
        }
    }
    
    struct GroupRowView3: View {
        let rowIndex: Int
        let items: [RankoItem]

        // NEW: bindings to the parent’s state
        @Binding var itemRows: [[RankoItem]]
        @Binding var unGroupedItems: [RankoItem]
        @Binding var hoveredRow: Int?
        @Binding var selectedDetailItem: RankoItem?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                // badge
                VStack(alignment: .center) {
                    ZStack {
                        Image(systemName: "\(rowIndex + 1).circle")
                            .foregroundColor(Color(hex: 0xFFFFFF)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                        
                        Group {
                            switch rowIndex {
                            case 0:
                                Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 1:
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            case 2:
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            default:
                                Image(systemName: "\(rowIndex + 1).circle.fill")
                                    .foregroundColor(Color(hex: 0x925611)).font(.system(size: 22, weight: .bold, design: .default)).padding(3)
                            }
                        }
                    }
                    
                    .padding(.top, 10)
                    
                    // items
                    FlowLayout2(spacing: 6) {
                        ForEach(items) { item in
                            GroupSelectedItemRow3(item: item)
                                .onDrag { NSItemProvider(object: item.id as NSString) }
                                .onTapGesture {
                                    selectedDetailItem = item  // TRIGGER SHEET
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.leading, .bottom, .trailing], 8)
                }
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFFE7B5))
            )
            .overlay(highlightOverlay)
            .animation(.easeInOut(duration: 0.25), value: hoveredRow)
            .onDrop(of: ["public.text"], delegate:
                RowDropDelegate(
                    itemRows: $itemRows,
                    unGrouped: $unGroupedItems,
                    hoveredRow: $hoveredRow,
                    targetRow: rowIndex
                )
            )
        }

        @ViewBuilder
        private var highlightOverlay: some View {
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
                    Color.gray.frame(width: 30, height: 30)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 30, height: 30)
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
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
                    Color.gray.frame(width: 30, height: 30)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Color.gray.frame(width: 30, height: 30)
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xFFF5E1))
                .stroke(Color(hex: 0xFFEBC2), lineWidth: 2)
                .shadow(color: Color(hex: 0xFFEBC2), radius: 12)
        )
    }
}

struct GroupListView_Previews: PreviewProvider {
    // Create 10 sample RankoItem instances representing top destinations
    static var sampleItems: [RankoItem] = [
        RankoItem(
            id: UUID().uuidString,
            rank: 1001,
            votes: 0,
            record: RankoRecord(
                objectID: "1",
                ItemName: "Paris",
                ItemDescription: "The City of Light",
                ItemCategory: "",
                ItemImage: "https://res.klook.com/image/upload/c_fill,w_750,h_750/q_80/w_80,x_15,y_15,g_south_west,l_Klook_water_br_trans_yhcmh3/activities/wrgwlkhnjekv8h5tjbn4.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 1002,
            votes: 0,
            record: RankoRecord(
                objectID: "2",
                ItemName: "New York",
                ItemDescription: "The Big Apple",
                ItemCategory: "",
                ItemImage: "https://hips.hearstapps.com/hmg-prod/images/manhattan-skyline-with-empire-state-building-royalty-free-image-960609922-1557777571.jpg?crop=0.66635xw:1xh;center,top&resize=640:*"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 2001,
            votes: 0,
            record: RankoRecord(
                objectID: "3",
                ItemName: "Tokyo",
                ItemDescription: "Land of the Rising Sun",
                ItemCategory: "",
                ItemImage: "https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/04/10/13/tokyo-main.jpg?width=1200&height=1200&fit=crop"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3001,
            votes: 0,
            record: RankoRecord(
                objectID: "4",
                ItemName: "Rome",
                ItemDescription: "a city steeped in history, culture, and artistic treasures, often referred to as the Eternal City",
                ItemCategory: "",
                ItemImage: "https://i.guim.co.uk/img/media/03303b5f042b72c03541fcd7f3777180f61a01a5/0_2310_4912_2947/master/4912.jpg?width=1200&height=1200&quality=85&auto=format&fit=crop&s=19cf880f7508ea310bdb136057d78240"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3002,
            votes: 0,
            record: RankoRecord(
                objectID: "5",
                ItemName: "Sydney",
                ItemDescription: "Harbour City",
                ItemCategory: "",
                ItemImage: "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/93/a7/be/sydney-opera-house.jpg?w=500&h=500&s=1"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3003,
            votes: 0,
            record: RankoRecord(
                objectID: "6",
                ItemName: "Barcelona",
                ItemDescription: "Gaudí’s Masterpiece City",
                ItemCategory: "",
                ItemImage: "https://lp-cms-production.imgix.net/2023-08/iStock-1297827939.jpg?fit=crop&ar=1%3A1&w=1200&auto=format&q=75"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 3004,
            votes: 0,
            record: RankoRecord(
                objectID: "7",
                ItemName: "Cape Town",
                ItemDescription: "Mother City of South Africa",
                ItemCategory: "",
                ItemImage: "https://imageresizer.static9.net.au/0sx9mhfU8tYDs_T-ftiFBrWR_as=/0x0:1307x735/1200x1200/https%3A%2F%2Fprod.static9.net.au%2Ffs%2F15af5183-fb21-49d9-a22c-d9f4813ccbea"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 4001,
            votes: 0,
            record: RankoRecord(
                objectID: "8",
                ItemName: "Rio de Janeiro",
                ItemDescription: "Marvelous City",
                ItemCategory: "",
                ItemImage: "https://whc.unesco.org/uploads/thumbs/site_1100_0004-750-750-20120625114004.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 5001,
            votes: 0,
            record: RankoRecord(
                objectID: "9",
                ItemName: "Reykjavik",
                ItemDescription: "Land of Fire and Ice",
                ItemCategory: "",
                ItemImage: "https://media.gq-magazine.co.uk/photos/5d138e07d7a7017355bb9bf3/1:1/w_1280,h_1280,c_limit/reykjavik-gq-22jun18_istock_b.jpg"
            )
        ),
        RankoItem(
            id: UUID().uuidString,
            rank: 5002,
            votes: 0,
            record: RankoRecord(
                objectID: "10",
                ItemName: "Istanbul",
                ItemDescription: "Where East Meets West",
                ItemCategory: "",
                ItemImage: "https://images.contentstack.io/v3/assets/blt06f605a34f1194ff/blt289d3aab2da77bc9/6777f31f93a84b03b5a37ef2/BCC-2023-EXPLORER-Istanbul-Fun-things-to-do-in-Istanbul-HEADER_MOBILE.jpg?format=webp&auto=avif&quality=60&crop=1%3A1&width=425"
            )
        )
    ]

    static var previews: some View {
        GroupListView(
            rankoName: "Top 10 Destinations",
            description: "Bucket-list travel spots around the world",
            isPrivate: false,
            category: SampleCategoryChip(id: "", name: "Countries", icon: "globe.europe.africa.fill"),
            groupedItems: sampleItems
        )
        .previewLayout(.sizeThatFits)
    }
}

















