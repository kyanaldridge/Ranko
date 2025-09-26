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
import Firebase
import FirebaseAuth
import FirebaseStorage
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
    @State private var listUUID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: SampleCategoryChip?
    
    // to revert to old values
    @State private var originalRankoName: String
    @State private var originalDescription: String
    @State private var originalIsPrivate: Bool
    @State private var originalCategory: SampleCategoryChip?

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

    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: SampleCategoryChip?,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName)
        _originalDescription = State(initialValue: description)
        _originalIsPrivate = State(initialValue: isPrivate)
        _originalCategory = State(initialValue: category)
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
                                                        listID: listUUID
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
                                                            startPublishAndDismiss()
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
                startPublishAndDismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(publishError ?? "Something went wrong.")
        }
        .refreshable {
            refreshItemImages()
        }
        .sheet(isPresented: $showAddItemsSheet) {
            FilterChipPickerView(selectedRankoItems: $selectedRankoItems)
                .presentationDetents([.height(480)])
                .interactiveDismissDisabled(true)
                .navigationTransition(
                    .zoom(sourceID: "sampleButton", in: transition)
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
            EditItemView(item: item, listID: listUUID) { newName, newDesc in
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
                onSave(updatedItem)
            }
        }
        .onAppear {
            refreshItemImages()
        }
    }
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    // Item Helpers
    private func delete(_ item: RankoItem) {
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

    private func publishRanko() async throws {
        // run both saves concurrently; finish only when both do
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await saveRankedListToAlgoliaAsync() }
            group.addTask { try await saveRankedListToFirebaseAsync() }
            try await group.waitForAll()
        }
    }

    // MARK: - Algolia (async)

    private func saveRankedListToAlgoliaAsync() async throws {
        guard let category = category else { throw PublishErr.missingCategory }

        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else { throw PublishErr.invalidUserID }

        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)

        let listRecord = RankoListAlgolia(
            objectID:         listUUID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoStatus:      "active",
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
            RankoDateTime:    rankoDateTime,
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
        guard let category = category else { throw PublishErr.missingCategory }

        let db = Database.database().reference()
        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else { throw PublishErr.invalidUserID }

        // Items payload
        var rankoItemsDict: [String: Any] = [:]
        for item in selectedRankoItems {
            let itemID = UUID().uuidString
            rankoItemsDict[itemID] = [
                "ItemID":          itemID,
                "ItemRank":        item.rank,
                "ItemName":        item.itemName,
                "ItemDescription": item.itemDescription,
                "ItemImage":       item.itemImage,
                "ItemVotes":       0
            ]
        }

        // timestamps
        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyyMMddHHmmss"
        let rankoDateTime = aedtFormatter.string(from: now)

        // list node
        let listDataForFirebase: [String: Any] = [
            "RankoID":          listUUID,
            "RankoName":        rankoName,
            "RankoDescription": description,
            "RankoType":        "default",
            "RankoPrivacy":     isPrivate,
            "RankoStatus":      "active",
            "RankoCategory":    category.name,
            "RankoUserID":      safeUID,
            "RankoItems":       rankoItemsDict,
            "RankoDateTime":    rankoDateTime,
        ]

        // write both nodes concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await setValueAsync(
                    db.child("RankoData").child(listUUID),
                    value: listDataForFirebase
                )
            }
            group.addTask {
                try await setValueAsync(
                    db.child("UserData").child(safeUID)
                      .child("UserRankos").child("UserActiveRankos").child(listUUID),
                    value: category.name
                )
            }
            try await group.waitForAll()
        }
    }

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


struct DefaultListView4: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var user_data = UserInformation.shared
    @Environment(\.tabViewBottomAccessoryPlacement) var placement

    // Init properties
    @State private var listUUID: String = UUID().uuidString
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var category: SampleCategoryChip?
    
    // to revert to old values
    @State private var originalRankoName: String
    @State private var originalDescription: String
    @State private var originalIsPrivate: Bool
    @State private var originalCategory: SampleCategoryChip?

    // Sheet states
    @State var showEditItemSheet = false
    @State var showAddItemsSheet = false
    @State var showEditDetailsSheet = false
    @State var showReorderSheet = false
    @State var showExitSheet = false
    
    // Item states
    @State private var selectedRankoItems: [RankoItem]
    @State private var selectedItem: RankoItem? = nil
    @State private var itemToEdit: RankoItem? = nil
    @State private var onSave: (RankoItem) -> Void
    
    @State private var imageReloadToken = UUID()
    
    @State private var selectedTab: TabType = .empty
    @State private var isPresentingSheet = false
    @State private var shouldShowTutorial: Bool = false
    
    enum TabType: Hashable {
        case addItems, editDetails, reRank, exit, empty
    }

    init(
        rankoName: String,
        description: String,
        isPrivate: Bool,
        category: SampleCategoryChip?,
        selectedRankoItems: [RankoItem] = [],
        onSave: @escaping (RankoItem) -> Void
    ) {
        _rankoName   = State(initialValue: rankoName)
        _description = State(initialValue: description)
        _isPrivate   = State(initialValue: isPrivate)
        _category    = State(initialValue: category)
        _selectedRankoItems = State(initialValue: selectedRankoItems)
        _onSave = State(initialValue: onSave)

        _originalRankoName = State(initialValue: rankoName)
        _originalDescription = State(initialValue: description)
        _originalIsPrivate = State(initialValue: isPrivate)
        _originalCategory = State(initialValue: category)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // all tabs reuse the SAME content view
            rankoView
                .tabItem { Label("", systemImage: "plus.square.fill.on.square.fill") }
                .tabItem {
                    Image(systemName: "plus.square.fill.on.square.fill")
                }
                .tag(TabType.addItems)
            
            rankoView
                .tabItem { Label("", systemImage: "pencil") }
                .tabItem {
                    Image(systemName: "pencil")
                }
                .tag(TabType.editDetails)
            
            rankoView
                .tag(TabType.empty)
            
            rankoView
                .tabItem { Label("", systemImage: "rectangle.arrowtriangle.2.outward") }
                .tabItem {
                    Image(systemName: "rectangle.arrowtriangle.2.outward")
                }
                .tag(TabType.reRank)
            
            rankoView
                .tabItem { Label("", systemImage: "trash") }
                .tabItem {
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                }
                .tag(TabType.exit)
        }
//        .tabViewBottomAccessory {
//            if shouldShowTutorial {
//                RankoCoachAccessory {
//                    withAnimation { shouldShowTutorial = false }
//                }
//                .transition(.move(edge: .bottom).combined(with: .opacity))
//            } else {
//                HStack {
//                    Button {
//                        
//                    } label: {
//                        HStack {
//                            Text("Save Ranko")
//                                .font(.custom("Nunito-Black", size: 17))
//                                .foregroundStyle(Color(hex: 0xFFFFFF))
//                                .padding(.horizontal, 20)
//                                .padding(.vertical, 7)
//                        }
//                        .background(Color(hex: 0xC34F01))
//                        .mask(Capsule())
//                    }
//                    .buttonStyle(.glassProminent)
//                    
//                    Button {} label: {
//                        HStack {
//                            Image(systemName: "questionmark")
//                                .font(.system(size: 12, weight: .black, design: .default))
//                                .foregroundStyle(Color(hex: 0xFFFFFF))
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 9)
//                        }
//                        .background(Color(hex: 0xC34F01))
//                        .mask(Circle())
//                    }
//                    .buttonStyle(.glassProminent)
//                }
//            }
//        }
//        
        .tabViewBottomAccessory(content: DefaultListAccessory.init)
        .tabBarMinimizeBehavior(.onScrollDown)
        // ensure we start from a neutral tab that is NOT shown in the bar
        .onAppear {
            selectedTab = .empty
            if selectedRankoItems.count == 0 {
                shouldShowTutorial = true
            } else {
                shouldShowTutorial = false
            }
        }
        .onChange(of: selectedRankoItems.count) {
            if selectedRankoItems.count == 0 {
                shouldShowTutorial = true
            } else {
                shouldShowTutorial = false
            }
        }
        // when the user switches tabs, pop the matching sheet, then reset back to .empty
        .onChange(of: selectedTab) { oldValue, newValue in
            guard !isPresentingSheet else { return }
            switch newValue {
            case .addItems:
                present { showAddItemsSheet = true }
            case .editDetails:
                present { showEditDetailsSheet = true }
            case .reRank:
                present { showReorderSheet = true }
            case .exit:
                present { showExitSheet = true }
            case .empty:
                break
            }
        }
        .sheet(isPresented: $showAddItemsSheet, onDismiss: resetTrigger) {
            FilterChipPickerView(selectedRankoItems: $selectedRankoItems)
                .presentationDetents([.height(480)])
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showEditDetailsSheet, onDismiss: resetTrigger) {
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
        }
        .fullScreenCover(isPresented: $showReorderSheet, onDismiss: resetTrigger) {
            DefaultListReRank(items: selectedRankoItems) { newOrder in
                selectedRankoItems = newOrder
            }
        }
        .sheet(isPresented: $showExitSheet, onDismiss: resetTrigger) {
            DefaultListExit(
                onSave: {
                    saveRankedListToAlgolia()
                    saveRankedListToFirebase()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
                },
                onDelete: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
                }
            )
        }
        
        // SINGLE edit sheet bound to the selected item (no per-row sheets)
        .sheet(item: $itemToEdit, onDismiss: resetTrigger) { item in
            EditItemView(item: item, listID: listUUID) { newName, newDesc in
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
                onSave(updatedItem)
            }
        }
        .onAppear {
            refreshItemImages()
        }
    }
    
    @ViewBuilder
    var rankoView: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x514343), Color(hex: 0x000000)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Color(hex: 0xFFFFFF)
                .ignoresSafeArea()
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
                                                    listID: listUUID
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
                                .padding(.bottom, 100)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }
            
        }
        .refreshable {
            refreshItemImages()
        }
//        .sheet(isPresented: $showTabBar) {
//            VStack {
//                HStack(spacing: 0) {
//                    ForEach(DefaultListTab.visibleCases, id: \.rawValue) { tab in
//                        VStack(spacing: 6) {
//                            Image(systemName: tab.symbolImage)
//                                .font(.title3)
//                                .symbolVariant(.fill)
//                                .frame(height: 28)
//
//                            Text(tab.rawValue)
//                                .font(.caption2)
//                                .fontWeight(.semibold)
//                        }
//                        .foregroundStyle(Color(hex: 0x925610))
//                        .frame(maxWidth: .infinity)
//                        .contentShape(.rect)
//                        .onTapGesture {
//                            activeTab = tab
//                            switch tab {
//                            case .addItems:
//                                showAddItemsSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .editDetails:
//                                showEditDetailsSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .reRank:
//                                showReorderSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .exit:
//                                showExitSheet = true
//                                withAnimation(.easeInOut(duration: 0.2)) {
//                                    tabBarPresent = false
//                                }
//                            case .empty:
//                                dismiss()
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 20)
//            }
//            .interactiveDismissDisabled(true)
//            .presentationDetents([.height(80)])
//            .presentationBackground((Color(hex: 0xfff9ee)))
//            .presentationBackgroundInteraction(.enabled)
//            .onAppear {
//                tabBarPresent = false      // Start from invisible
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                    withAnimation(.easeInOut(duration: 0.2)) {
//                        tabBarPresent = true
//                    }
//                }
//            }
//            .onDisappear {
//                withAnimation(.easeInOut(duration: 0.2)) {
//                    tabBarPresent = false
//                }
//            }
//        }
    }
    // MARK: - Sheet trigger helpers
    private func present(_ action: @escaping () -> Void) {
        isPresentingSheet = true
        // perform on next runloop to avoid selection race with TabView
        DispatchQueue.main.async {
            action()
            // reset selection so no tab stays highlighted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                selectedTab = .empty
            }
        }
    }

    private func resetTrigger() {
        // allow new triggers after a sheet closes
        isPresentingSheet = false
        selectedTab = .empty
    }
    private func refreshItemImages() {
        guard !selectedRankoItems.isEmpty else { return }
        imageReloadToken = UUID() // change identity → rows/images rebuild
    }
    
    // Item Helpers
    private func delete(_ item: RankoItem) {
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
    
    func saveRankedListToAlgolia() {
        guard let category = category else {
            print("❌ Cannot save: no category selected")
            return
        }

        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else {
            print("❌ Cannot save: invalid user ID")
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
            objectID:         listUUID,
            RankoName:        rankoName,
            RankoDescription: description,
            RankoType:        "default",
            RankoPrivacy:     isPrivate,
            RankoStatus:      "active",
            RankoCategory:    category.name,
            RankoUserID:      safeUID,
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
        let rawUID = Auth.auth().currentUser?.uid ?? user_data.userID
        let invalidSet = CharacterSet(charactersIn: ".#$[]")
        let safeUID = rawUID.components(separatedBy: invalidSet).joined()
        guard !safeUID.isEmpty else {
            print("❌ Cannot save: invalid user ID")
            return
        }
        
        // 2) Build your items payload
        var rankoItemsDict: [String: Any] = [:]
        for item in selectedRankoItems {
            let itemID = UUID().uuidString
            rankoItemsDict[itemID] = [
                "ItemID":          itemID,
                "ItemRank":        item.rank,
                "ItemName":        item.itemName,
                "ItemDescription": item.itemDescription,
                "ItemImage":       item.itemImage,
                "ItemVotes":       0
            ]
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
            "RankoID":              listUUID,
            "RankoName":            rankoName,
            "RankoDescription":     description,
            "RankoType":            "default",
            "RankoPrivacy":         isPrivate,
            "RankoStatus":          "active",
            "RankoCategory":        category.name,
            "RankoUserID":          safeUID,
            "RankoItems":           rankoItemsDict,
            "RankoDateTime":        rankoDateTime,
        ]
        
        // 5) Write the main list node
        db.child("RankoData")
            .child(listUUID)
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
            .child(listUUID)
            .setValue(category.name) { error, _ in
                if let err = error {
                    print("❌ Error saving list to user: \(err.localizedDescription)")
                } else {
                    print("✅ List saved successfully to user")
                }
            }
    }
}


/// Tab Enum
enum DefaultListTab: String, CaseIterable {
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
    
    static var visibleCases: [DefaultListTab] {
        return [.addItems, .editDetails, .reRank, .exit]
    }
}

struct DefaultListEditDetails: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: – Editable state
    @State private var rankoName: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var selectedCategoryChip: SampleCategoryChip?
    @State private var showCategoryPicker: Bool = false
    
    // MARK: – Validation & shake effects
    @State private var rankoNameShake: CGFloat = 0
    @State private var categoryShake: CGFloat = 0
    private var isValid: Bool {
        !rankoName.isEmpty && selectedCategoryChip != nil
    }
    
    private let onSave: (String, String, Bool, SampleCategoryChip?) -> Void
    
    init(
        rankoName: String,
        description: String = "",
        isPrivate: Bool,
        category: SampleCategoryChip?,
        onSave: @escaping (String, String, Bool, SampleCategoryChip?) -> Void
    ) {
        self.onSave              = onSave
        
        _rankoName    = State(initialValue: rankoName)
        _description  = State(initialValue: description)
        _isPrivate    = State(initialValue: isPrivate)
        _selectedCategoryChip = State(initialValue: category)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Ranko Name Field
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        Text("Ranko Name")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.leading, 6)
                        Text("*")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: 0x4C2C33))
                    }
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.trailing, 1)
                        TextField("Enter name", text: $rankoName, axis: .vertical)
                            .lineLimit(1...2)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .onChange(of: rankoName) { _, newValue in
                                if newValue.count > 30 {
                                    rankoName = String(newValue.prefix(30))
                                }
                            }
                        Spacer()
                        Text("\(rankoName.count)/30")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.top, 30)
                .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: rankoNameShake))
                
                // Description Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Color(hex: 0x857467))
                        .padding(.leading, 6)
                    HStack(alignment: .top) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.trailing, 1)
                        TextField("Enter Description", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .onChange(of: description) { _, newValue in
                                if newValue.count > 250 {
                                    description = String(newValue.prefix(250))
                                }
                            }
                        Spacer()
                        Text("\(description.count)/250")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.top, 10)
                
                // Category & Privacy Toggle
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            Text("Category")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(Color(hex: 0x857467))
                            Text("*")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: 0x4C2C33))
                        }
                        .padding(.leading, 6)
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                if let chip = selectedCategoryChip {
                                    Image(systemName: chip.icon)
                                    Text(chip.name).bold()
                                } else {
                                    Image(systemName: "square.grid.2x2.fill")
                                    Text("Select Category")
                                        .bold()
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .padding(8)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        (categoryChipIconColors[selectedCategoryChip?.name ?? ""] ?? .gray)
                                    )
                            )
                        }
                        .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: categoryShake))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.leading, 6)
                        Button {
                            withAnimation {
                                isPrivate.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPrivate ? "lock.fill" : "globe")
                                Text(isPrivate ? "Private" : "Public").bold()
                            }
                            .padding(8)
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isPrivate ? Color(hex: 0xFE8C34) : Color(hex: 0x42ADFF))
                            )
                        }
                        .contentTransition(.symbolEffect(.replace))
                    }
                }
                .padding(.bottom, 10)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(Color(hex: 0xA26A2A), in: RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        if isValid {
                            onSave(rankoName, description, isPrivate, selectedCategoryChip)
                            dismiss()
                        } else {
                            if rankoName.isEmpty {
                                withAnimation { rankoNameShake += 1 }
                            }
                            if selectedCategoryChip == nil {
                                withAnimation { categoryShake += 1 }
                            }
                        }
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x6D400F), in: RoundedRectangle(cornerRadius: 8))
                    .opacity(isValid ? 1 : 0.6)
                }
                
                Spacer(minLength: 0)
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Text("Edit Ranko Details")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: 0x857467))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .padding(.horizontal, 22)
        // Category picker sheet
//        .sheet(isPresented: $showCategoryPicker) {
//            CategoryPickerView(
//                categoryChipsByCategory: categoryChipsByCategory,
//                selectedCategoryChip: $selectedCategoryChip,
//                isPresented: $showCategoryPicker
//            )
//        }
        // Use exact height (clamped to a minimum) for our sheet
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(hex: 0xFFF5E1))
        .interactiveDismissDisabled(true)
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

struct DefaultListExit: View {
    @Environment(\.dismiss) var dismiss
    
    var onSave: () -> Void
    var onDelete: () -> Void   // NEW closure for delete

    var body: some View {
        VStack(spacing: 12) {
            Button {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onSave()        // run save in parent
                dismiss()       // dismiss ExitSheetView
            } label: {
                Text("Publish Ranko")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 12) {
                Button {
                    print("Cancel tapped")
                    dismiss() // just dismiss ExitSheetView
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                
                Button {
                    print("Delete tapped")
                    onDelete()      // trigger delete logic in parent
                    dismiss()       // close ExitSheetView
                } label: {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 30)
        .presentationBackground(Color.white)
        .presentationDetents([.height(160)])
        .interactiveDismissDisabled(true)
    }
}

struct DefaultListView_Previews: PreviewProvider {
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
        .colorScheme(.light)
        .accentColor(Color(hex: 0xC34F01))
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








