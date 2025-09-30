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

struct DefaultListSpectate: View {
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
    @State private var pendingPersonalImages: [String: UIImage] = [:]  // itemID -> image
    
    // MARK: - Init now only requires listID
    init(
        listID: String,
        rankoName: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        category: SampleCategoryChip? = nil,
        selectedRankoItems: [RankoItem] = []
    ) {
        self.listID = listID
        _rankoName = State(initialValue: rankoName ?? "")
        _description = State(initialValue: description ?? "")
        _isPrivate = State(initialValue: isPrivate ?? false)
        _category = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        
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
                            dismiss()
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
                                                        
                                                    }) {
                                                        Label("View Item", systemImage: "magnifyingglass")
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
                                                        case .save:   dismiss()
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
                                                dismiss()
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
        .refreshable {
            refreshItemImages()
        }
        .onAppear {
            loadListFromFirebase()
            refreshItemImages()
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
            .child(listID)

        func intFromAny(_ any: Any?) -> Int? {
            if let n = any as? NSNumber { return n.intValue }
            if let s = any as? String { return Int(s) }
            return nil
        }

        func parseColour(_ any: Any?) -> Int {
            if let n = any as? NSNumber { return n.intValue }
            if let s = any as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                // try decimal first
                if let dec = Int(trimmed) { return dec }
                // try hex forms: "#FFCC00", "0xFFCC00", "FFCC00"
                var hex = trimmed.lowercased()
                if hex.hasPrefix("#") { hex.removeFirst() }
                if hex.hasPrefix("0x") { hex.removeFirst(2) }
                if let hx = Int(hex, radix: 16) { return hx }
            }
            return 0xFFFFFF
        }

        ref.observeSingleEvent(of: .value) { snap in
            guard let dict = snap.value as? [String: Any] else { return }

            // Core fields
            guard
                let name = dict["RankoName"] as? String,
                let des  = dict["RankoDescription"] as? String,
//                let type = dict["RankoType"] as? String,
                let isPriv = dict["RankoPrivacy"] as? Bool
//                let userID = dict["RankoUserID"] as? String
            else { return }

            // RankoDateTime is now an object: { RankoCreated, RankoUpdated }
//            var dateTimeStr: String = ""
//            if let dt = dict["RankoDateTime"] as? [String: Any] {
                // prefer Updated, fall back to Created
//                let updated = dt["RankoUpdated"] as? String
//                let created = dt["RankoCreated"] as? String
//                dateTimeStr = updated ?? created ?? ""
//            } else if let s = dict["RankoDateTime"] as? String {
                // backwards-compat (old shape)
//                dateTimeStr = s
//            }

            // Category (nested object)
            var catName  = "Unknown"
            var catIcon  = "circle"
            var catColourInt = 0x446D7A
            if let cat = dict["RankoCategory"] as? [String: Any] {
                catName  = (cat["name"] as? String) ?? catName
                catIcon  = (cat["icon"] as? String) ?? catIcon
                catColourInt = parseColour(cat["colour"])
            } else if let catStr = dict["RankoCategory"] as? String {
                // backwards-compat if old lists stored just a name
                catName = catStr
            }

            // Items
            let itemsDict = dict["RankoItems"] as? [String: [String: Any]] ?? [:]
            let items: [RankoItem] = itemsDict.compactMap { itemID, item in
                guard
                    let itemName  = item["ItemName"] as? String,
                    let itemDesc  = item["ItemDescription"] as? String,
                    let itemImage = item["ItemImage"] as? String
                else { return nil }

                let rank  = intFromAny(item["ItemRank"])  ?? 0
                let votes = intFromAny(item["ItemVotes"]) ?? 0

                let record = RankoRecord(
                    objectID: itemID,
                    ItemName: itemName,
                    ItemDescription: itemDesc,
                    ItemCategory: "",          // fill if you ever store per-item category
                    ItemImage: itemImage
                )
                return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
            }

            // map to your local state types
            rankoName = name
            description = des
            isPrivate = isPriv
            categoryName = catName
            categoryIcon = catIcon

            // clamp colour to 24-bit and convert to UInt safely
            let masked = catColourInt & 0x00FFFFFF
            categoryColour = UInt(clamping: masked)

            selectedRankoItems = items.sorted { $0.rank < $1.rank }
            // if you also store/need type, user, date:
            // self.type = type
            // self.userCreator = userID
            // self.dateTime = dateTimeStr
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
            ItemImage: url
        )
    }
}

private extension RankoItem {
    func withRecord(_ newRecord: RankoRecord) -> RankoItem {
        RankoItem(
            id: id,
            rank: rank,
            votes: votes,
            record: newRecord
        )
    }
}
