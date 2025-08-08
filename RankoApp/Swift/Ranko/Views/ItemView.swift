//
//  ItemView.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 3/6/2025.
//

import SwiftUI
import UIKit

// MARK: - Detail sheet for a single item
struct ItemDetailView: View {
    let items: [RankoItem]
    let initialItem: RankoItem  // the item to center on initially
    let listID: String
    let onSave: (RankoItem) -> Void
    
    // Infinite carousel state
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[RankoItem]] = []
    @State private var autoScrollEnabled = false
    @State private var showEditSheet = false
    @State private var backgroundColor: Color = .white
    @State private var currentCenteredIndex: Int = 0
    @State private var selectedType: String = ItemDetailView.types.first!
    
    // Animation / layout constants
    private let pageWidth: CGFloat = 250
    private let pageHeight: CGFloat = 350
    private let spacing: CGFloat = 60
    private let animationDuration: CGFloat = 0.3
    private let secondsPerSlide: CGFloat = 1.0
    @Namespace private var tabNamespace
    private let carouselAnimation: Animation = .default
    
    @State private var backgroundUIImage: UIImage? = nil
    
    var body: some View {
        let flatItems = itemsArray.flatMap { $0 }
        let widthDiff = UIScreen.main.bounds.width - pageWidth
        
        NavigationView {
            ZStack {
                GeometryReader { geo in
                    ZStack {
                        if let bgImage = backgroundUIImage {
                            Image(uiImage: bgImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: 35)
                                .ignoresSafeArea()
                        } else {
                            Color.gray.opacity(0.15)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .ignoresSafeArea()
                        }
                    }
                }

                VStack(spacing: 20) {
                    ScrollView(.horizontal) {
                        HStack(spacing: spacing) {
                            ForEach(0..<flatItems.count, id: \.self) { idx in
                                let item = flatItems[idx]
                                VStack(spacing: 12) {
                                    VStack {
                                        ZStack(alignment: .bottom) {
                                            AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView().frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                        .frame(
                                                            width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth,
                                                            height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .onAppear {
                                                            if idx % items.count == currentCenteredIndex {
                                                                Task {
                                                                    if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                                                        extractAndEnhanceColor(from: uiImage)
                                                                        backgroundUIImage = uiImage
                                                                    } else {
                                                                        backgroundUIImage = nil
                                                                    }
                                                                }
                                                            }
                                                        }
                                                case .failure:
                                                    Color.gray.frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }

                                            VStack(spacing: 8) {
                                                Text(item.record.ItemName)
                                                    .font(.caption).fontWeight(.bold)
                                                    .multilineTextAlignment(.center)
                                                    .textCase(.uppercase)

                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        ForEach(ItemDetailView.types, id: \.self) { type in
                                                            Group {
                                                                if type == "Camera" {
                                                                    Image(systemName: "camera")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                } else {
                                                                    Text(type)
                                                                        .font(.system(size: 10, weight: .bold))
                                                                }
                                                            }
                                                            .padding(.vertical, 7)
                                                            .foregroundColor(selectedType == type ? .orange : .gray.opacity(0.35))
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                withAnimation(.snappy) {
                                                                    selectedType = type
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                if selectedType == "Camera" {
                                                    
                                                } else {
                                                    Divider()
                                                }
                                                

                                                tabContent(for: item)
                                            }
                                            .padding()
                                            .frame(width: pageWidth)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                                            )
                                            .offset(y: selectedType == "Camera" ? 120 : 90)
                                        }
                                        .frame(width: pageWidth, height: pageHeight)
                                        .padding(.bottom, 30)
                                    }
                                }
                                .shadow(color: .black.opacity(0.2), radius: 15)
                                .frame(width: pageWidth, height: pageHeight)
                                .scrollTransition { content, phase in
                                    content.scaleEffect(y: phase.isIdentity ? 1 : 0.7)
                                }
                            }
                        }.scrollTargetLayout()
                            .padding(.bottom, 60)
                    }
                    
                    .contentMargins(widthDiff / 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: pageHeight * 1.3)
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollIndicators(.hidden)
                    .onAppear { setupCarousel() }
                    .onChange(of: scrollPosition) { newPos, pos in
                        guard let pos = pos else { return }
                        currentCenteredIndex = pos % items.count
                        handleWrap(at: pos)
                        scheduleAutoScroll(from: pos)
                        Task {
                            let item = items[currentCenteredIndex]
                            if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                extractAndEnhanceColor(from: uiImage)
                            }
                        }
                    }
                    
                    
                    HStack(spacing: 10) {
                        ForEach(0..<items.count, id: \.self) { i in
                            let isSelected = i == currentCenteredIndex
                            let item = items[i]
                            let rankColor: Color = {
                                switch item.rank {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12, height: isSelected ? 30 : 12)
                                    .animation(.easeInOut(duration: 0.1), value: currentCenteredIndex)
                                
                                if isSelected {
                                    if item.rank > 3 {
                                        Text("\(item.rank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                            .transition(.opacity.combined(with: .scale))
                                            .animation(.bouncy(duration: 1), value: currentCenteredIndex)
                                    } else {
                                        Text("\(item.rank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                    
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    scrollPosition = i + items.count
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
            .onAppear(perform: {
                
            })
            .sheet(isPresented: $showEditSheet) {
                // Determine which item is centered
                let centerIdx = (scrollPosition ?? 0) % items.count
                let currentItem = items.sorted { $0.rank < $1.rank }[centerIdx]
                EditItemView(
                    item: currentItem,
                    listID: listID
                ) { newName, newDesc in
                    // build updated record & item
                    let rec = currentItem.record
                    let updatedRecord = RankoRecord(
                        objectID: rec.objectID,
                        ItemName: newName,
                        ItemDescription: newDesc,
                        ItemCategory: "",
                        ItemImage: rec.ItemImage
                    )
                    let updatedItem = RankoItem(
                        id: currentItem.id,
                        rank: currentItem.rank,
                        votes: currentItem.votes,
                        record: updatedRecord
                    )
                    // callback to parent
                    onSave(updatedItem)
                }
            }
            
            // edit sheet integration remains unchanged
        }
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.automatic)
    }
    
    @ViewBuilder
    private func tabContent(for item: RankoItem) -> some View {
        switch selectedType {
        case "Description":
            Text(item.record.ItemDescription)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        case "Comments":
            Text("Comments section coming soon...").font(.caption2).foregroundColor(.blue).padding(.horizontal)
        case "Trivia":
            Text("Fun facts or trivia here!").font(.caption2).foregroundColor(.purple).padding(.horizontal)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Carousel Setup
    private func extractColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let uiColors = try uiImage.extractColors(numberOfColors: 1)
                if let prominent = uiColors.first {
                    let newColor = Color(prominent)
                    DispatchQueue.main.async {
                        withAnimation {
                            backgroundColor = newColor
                        }
                    }
                }
            } catch {
                print("Color extraction failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractAndEnhanceColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let colors = try uiImage.extractColors(numberOfColors: 1)
                if let dominant = colors.first {
                    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                    dominant.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    
                    // Boost saturation and brightness
                    let vibrant = UIColor(
                        hue: hue,
                        saturation: min(1.0, saturation * 1.5 + 0.2),
                        brightness: min(1.0, brightness * 1.5 + 0.1),
                        alpha: 1.0
                    )
                    
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            backgroundColor = Color(vibrant)
                        }
                    }
                }
            } catch {
                print("Failed to extract colors: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUIImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func setupCarousel() {
        let sorted = items.sorted { $0.rank < $1.rank }
        itemsArray = [sorted, sorted, sorted]
        // find the index of the initial item in the sorted array
        let initialIndex = sorted.firstIndex(where: { $0.id == initialItem.id }) ?? 0
        // center on the middle copy plus that offset
        scrollPosition = sorted.count + initialIndex
    }
    
    private func handleWrap(at pos: Int) {
        let count = items.count
        if pos < count {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeLast()
                itemsArray.insert(items.sorted { $0.rank < $1.rank }, at: 0)
                scrollPosition = pos + count
            }
        } else if pos >= count * 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeFirst()
                itemsArray.append(items.sorted { $0.rank < $1.rank })
                scrollPosition = pos - count
            }
        }
    }
    
    private func toggleAutoScroll() {
        let wasOn = autoScrollEnabled
        autoScrollEnabled.toggle()
        if !wasOn, let pos = scrollPosition {
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
            })
        }
    }
    
    private func scheduleAutoScroll(from pos: Int) {
        guard autoScrollEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsPerSlide) {
            withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
        }
    }
    
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
            } else if rank == 2 {
                Image(systemName: "2.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
            } else if rank == 3 {
                Image(systemName: "3.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
            } else {
                Text("\(rank)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(5)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }
}

extension ItemDetailView {
    static let types: [String] = ["Camera", "Description", "Comments", "Trivia"]
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = CGSize(width: 200, height: 200)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        }
    }
}

struct EditItemView: View {
    @Environment(\.presentationMode) private var presentationMode
    let item: RankoItem
    let listID: String
    let onSave: (String, String) -> Void

    @State private var editedName: String
    @State private var editedDescription: String
    @State private var activeAction: EditItemAction? = nil
    
    // MARK: – Toast
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    init(item: RankoItem, listID: String, onSave: @escaping (String, String) -> Void) {
        self.item = item
        self.listID = listID
        self.onSave = onSave
        _editedName = State(initialValue: item.itemName)
        _editedDescription = State(initialValue: item.itemDescription)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    VStack {
                        AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: 200, height: 200)
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 140, height: 140)
                                        .foregroundColor(.gray)
                                }
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: 200, height: 200)
                                    Image(systemName: "xmark.octagon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 140, height: 140)
                                        .foregroundColor(.gray)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)
                    HStack {
                        Text("Item Name").foregroundColor(.secondary)
                        Text("*").foregroundColor(.red)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.leading, 6)
                    HStack {
                        Image(systemName: "textformat.size.larger")
                            .foregroundColor(.gray)
                            .padding(.trailing, 1)
                        TextField("Apple", text: $editedName)
                            .onChange(of: editedName) { _, newValue in
                                if newValue.count > 50 {
                                    editedName = String(newValue.prefix(50))
                                }
                            }
                            .autocorrectionDisabled(true)
                            .foregroundStyle(.gray)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(editedName.count)/50")
                            .font(.caption2)
                            .fontWeight(.light)
                            .padding(.top, 15)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.bottom, 15)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundColor(.gray)
                            .padding(.trailing, 1)
                        TextField("a red or green juicy fruit", text: $editedDescription)
                            .onChange(of: editedDescription) { _, newValue in
                                if newValue.count > 100 {
                                    editedDescription = String(newValue.prefix(100))
                                }
                            }
                            .autocorrectionDisabled(true)
                            .foregroundStyle(.gray)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(editedDescription.count)/100")
                            .font(.caption2)
                            .fontWeight(.light)
                            .padding(.top, 15)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(Color.gray.opacity(0.08))
                            .allowsHitTesting(false)
                    )
                }
                Spacer(minLength: 20)
                
                bottomBar
                    .edgesIgnoringSafeArea(.bottom)

                // MARK: — Toast Overlay
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.8))
                            )
                            .transition(
                                .move(edge: .bottom)
                                .combined(with: .opacity)
                            )
                            .padding(.bottom, 80)
                    }
                    .animation(.easeInOut(duration: 0.25), value: showToast)
                }
            }
            .sheet(item: $activeAction, content: sheetContent)
            .presentationDetents([.fraction(0.75), .large])
        }
        .padding(.top, 25)
        .padding(15)
    }
    // MARK: — Bottom Bar Overlay
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(EditItemAction.allCases) { action in
                        if action == .save {
                            pressAndHoldButton(
                                action: action,
                                symbolName: buttonSymbols[action.rawValue] ?? "",
                                onPerform: {
                                    onSave(editedName, editedDescription)
                                    presentationMode.wrappedValue.dismiss()
                                },
                                onTapToast: {
                                    // Error haptic when they only tap
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    showTemporaryToast("Hold down button to Save")
                                }
                            )
                        }
                        else if action == .discard {
                            pressAndHoldButton(
                                action: action,
                                symbolName: buttonSymbols[action.rawValue] ?? "",
                                onPerform: {
                                    presentationMode.wrappedValue.dismiss()
                                },
                                onTapToast: {
                                    // Error haptic when they only tap
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    showTemporaryToast("Hold down button to Discard Changes")
                                }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 17)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 8)
            )
        }
    }
    
    private func showTemporaryToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    @ViewBuilder
    private func sheetContent(for action: EditItemAction) -> some View {
        switch action {
        case .save:
            EmptyView() // never present a sheet for Publish
        case .discard:
            EmptyView() // never present a sheet for Delete
        }
    }
    
    
    @ViewBuilder
    private func pressAndHoldButton(
        action: EditItemAction,
        symbolName: String,
        onPerform: @escaping () -> Void,
        onTapToast: @escaping () -> Void
    ) -> some View {
        ZStack {
            // ─────────
            // 1) Button Content
            VStack(spacing: 0) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .black, design: .default))
                    .frame(height: 20)
                    .padding(.bottom, 6)

                Text(action.rawValue)
                    .font(.system(size: 9, weight: .black, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(minWidth: 20)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white)
            .cornerRadius(12)
            // Short tap = show toast + error haptic
            .onTapGesture {
                onTapToast()
            }
            // Long press (≥1s) = success haptic + perform action
            .onLongPressGesture(
                minimumDuration: 1.0,
                perform: {
                    onPerform()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    enum EditItemAction: String, Identifiable, CaseIterable {
        var id: String { self.rawValue }
        case save     = "Save"
        case discard  = "Discard"
    }

    var buttonSymbols: [String: String] {
        [
            "Save":      "square.and.arrow.up",
            "Discard":   "trash"
        ]
    }
}

// MARK: - Detail sheet for a single item
struct SpecItemDetailView: View {
    let item: RankoItem

    var body: some View {
        VStack(spacing: 16) {
            // Image at top
            AsyncImage(url: URL(string: item.itemImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: 250)
            .background(Color.gray.opacity(0.2))
            .clipped()

            // Name
            Text(item.itemName)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text(item.itemDescription)
                .font(.body)
                .padding(.horizontal)

            // Rank
            Text("Rank: \(item.rank)")
                .font(.headline)
                .padding(.bottom)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Provider (unchanged)
struct ItemView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleRecord = RankoRecord(
            objectID: "IYEGY7767sSS",
            ItemName: "Apple",
            ItemDescription: "a red fruit",
            ItemCategory: "",
            ItemImage: "https://img.freepik.com/free-psd/close-up-delicious-apple_23-2151868338.jpg"
        )
        let sampleItem = RankoItem(
            id: "IYEGY7767sSS",
            rank: 3,
            votes: 42,
            record: sampleRecord
        )

        ItemDetailView(
            items: [sampleItem],
            initialItem: sampleItem,
            listID: "sampleListID"
        ) { updatedItem in
            // no-op in preview
        }
    }
}



// MARK: - Preview Provider (unchanged)
struct SpectateItemView_Previews: PreviewProvider {
    static var previews: some View {
        SpecItemDetailView(item: RankoItem(id: "IYEGY7767sSS", rank: 3, votes: 42, record: RankoRecord(objectID: "IYEGY7767sSS", ItemName: "Apple", ItemDescription: "a red fruit", ItemCategory: "", ItemImage: "https://img.freepik.com/free-psd/close-up-delicious-apple_23-2151868338.jpg")))
    }
}

fileprivate enum Colors: String, CaseIterable, Identifiable {
    case red
    case blue
    case orange
    case purple
    
    var id: UUID { UUID() }
    
    var color: Color {
        switch self {
        case .red:
            Color.red
        case .blue:
            Color.blue
        case .orange:
            Color.orange
        case .purple:
            Color.purple
        }
    }
}



struct ImageCarousel: View {
    
    private let colors: [Colors] = Colors.allCases
    
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[Colors]] = []
    @State private var autoScrollEnabled: Bool = false
    private let pageWidth: CGFloat = 250
    private let pageHeight: CGFloat = 350
    private let animationDuration: CGFloat = 0.3
    private let secondsPerSlide: CGFloat = 1.0
    private let animation: Animation = .default

    var body: some View {
        let itemsTemp = itemsArray.flatMap { $0.map { $0 } }
        let widthDifference = UIScreen.main.bounds.width - pageWidth
        
        VStack(spacing: 20) {
            Button(action: {
                let isEnabled = autoScrollEnabled
                autoScrollEnabled.toggle()
                // going from false to true
                if !isEnabled {
                    guard let scrollPosition = scrollPosition else {return}
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                        withAnimation(animation) {
                            self.scrollPosition = scrollPosition + 1
                        }
                    })
                }
            }, label: {
                Text(autoScrollEnabled ? "Stop" : "Start")
                    .padding()
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black))
            })
                
            ScrollView(.horizontal) {
                HStack(spacing: 25) {
                        ForEach(0..<itemsTemp.count, id: \.self) { index in
                            let item = itemsTemp[index]

                        Text(item.rawValue)
                            .foregroundStyle(.black)
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: pageWidth, height: 360)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(item.color)
                            )
                            .scrollTransition{ content, phase in
                                content
                                    .scaleEffect(y: phase.isIdentity ? 1 : 0.7)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(widthDifference/2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: pageHeight * 1.3)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollIndicators(.hidden)
            .onAppear {
                self.itemsArray = [colors, colors, colors]
                // start at the first item of the second colors array
                scrollPosition = colors.count
            }
            .onChange(of: scrollPosition) {
                guard let scrollPosition = scrollPosition else {return}
                print(scrollPosition)
                
                let itemCount = colors.count
                // last item of the first colors Array
                if scrollPosition / itemCount == 0 && scrollPosition % itemCount == itemCount - 1  {
                    print("last item of the first colors")
                    // append colors array before the first and remove the curren last color array
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        itemsArray.removeLast()
                        itemsArray.insert(colors, at: 0)
                        self.scrollPosition = scrollPosition + colors.count
                    }
                    return
                }
                
                // first item of the last colors Array
                if scrollPosition / itemCount == 2 && scrollPosition % itemCount == 0  {
                    print("first item of the last colors")
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        itemsArray.removeFirst()
                        itemsArray.append(colors)
                        self.scrollPosition = scrollPosition - colors.count
                    }

                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + secondsPerSlide, execute: {
                    if autoScrollEnabled {
                        withAnimation(animation) {
                            self.scrollPosition = scrollPosition + 1
                        }
                    }
                })
            }

            HStack {
                ForEach(0..<colors.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(animation) {
                            scrollPosition = index + colors.count
                        }
                    }, label: {
                        Circle()
                            .fill(Color.gray.opacity(
                                (index == (scrollPosition ?? 0) % colors.count) ? 0.8 : 0.3
                            ))
                            .frame(width: 15)
                    })
                }
            }
            
        }
    }
}

#Preview {
    ImageCarousel()
}




extension UIImage {
    
    /// Extracts the most prominent and unique colors from the image.
    ///
    /// - Parameter numberOfColors: The number of prominent colors to extract (default is 4).
    /// - Returns: An array of UIColors representing the prominent colors.
    func extractColors(numberOfColors: Int = 4) throws -> [UIColor] {
        // Ensure the image has a CGImage
        guard let _ = self.cgImage else {
            throw NSError(domain: "Invalid image", code: 0, userInfo: nil)
        }
        
        let size = CGSize(width: 200, height: 200 * self.size.height / self.size.width)
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            throw NSError(domain: "Failed to resize image", code: 0, userInfo: nil)
        }
        UIGraphicsEndImageContext()
        
        guard let inputCGImage = resizedImage.cgImage else {
            throw NSError(domain: "Invalid resized image", code: 0, userInfo: nil)
        }
        
        let width = inputCGImage.width
        let height = inputCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let data = calloc(height * width, MemoryLayout<UInt32>.size) else {
            throw NSError(domain: "Failed to allocate memory", code: 0, userInfo: nil)
        }
        
        defer { free(data) }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(data: data, width: width, height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            throw NSError(domain: "Failed to create CGContext", code: 0, userInfo: nil)
        }
        
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        var pixelData = [PixelData]()
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((width * y) + x) * bytesPerPixel
                let r = pixelBuffer[offset]
                let g = pixelBuffer[offset + 1]
                let b = pixelBuffer[offset + 2]
                pixelData.append(PixelData(red: Double(r), green: Double(g), blue: Double(b)))
            }
        }
        
        let clusters = kMeansCluster(pixels: pixelData, k: numberOfColors)
        
        let colors = clusters.map { cluster -> UIColor in
            UIColor(red: CGFloat(cluster.center.red / 255.0),
                    green: CGFloat(cluster.center.green / 255.0),
                    blue: CGFloat(cluster.center.blue / 255.0),
                    alpha: 1.0)
        }
        
        return colors
    }
    
    private struct PixelData {
        let red: Double
        let green: Double
        let blue: Double
    }
    
    private struct Cluster {
        var center: PixelData
        var points: [PixelData]
    }
    
    private func kMeansCluster(pixels: [PixelData], k: Int, maxIterations: Int = 10) -> [Cluster] {
        var clusters = [Cluster]()
        for _ in 0..<k {
            if let randomPixel = pixels.randomElement() {
                clusters.append(Cluster(center: randomPixel, points: []))
            }
        }
        
        for _ in 0..<maxIterations {
            for clusterIndex in 0..<clusters.count {
                clusters[clusterIndex].points.removeAll()
            }
            
            for pixel in pixels {
                var minDistance = Double.greatestFiniteMagnitude
                var closestClusterIndex = 0
                for (index, cluster) in clusters.enumerated() {
                    let distance = euclideanDistance(pixel1: pixel, pixel2: cluster.center)
                    if distance < minDistance {
                        minDistance = distance
                        closestClusterIndex = index
                    }
                }
                clusters[closestClusterIndex].points.append(pixel)
            }
            
            for clusterIndex in 0..<clusters.count {
                let cluster = clusters[clusterIndex]
                if cluster.points.isEmpty { continue }
                let sum = cluster.points.reduce(PixelData(red: 0, green: 0, blue: 0)) { (result, pixel) -> PixelData in
                    return PixelData(red: result.red + pixel.red, green: result.green + pixel.green, blue: result.blue + pixel.blue)
                }
                let count = Double(cluster.points.count)
                clusters[clusterIndex].center = PixelData(red: sum.red / count, green: sum.green / count, blue: sum.blue / count)
            }
        }
        
        return clusters
    }
    
    private func euclideanDistance(pixel1: PixelData, pixel2: PixelData) -> Double {
        let dr = pixel1.red - pixel2.red
        let dg = pixel1.green - pixel2.green
        let db = pixel1.blue - pixel2.blue
        return sqrt(dr * dr + dg * dg + db * db)
    }
}


struct ColorPaletteView: View {
    let colors: [UIColor]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<colors.count, id: \.self) { index in
                    let uiColor = colors[index]
                    let color = Color(uiColor)
                    let hex = uiColor.toHexString()
                    
                    VStack {
                        Rectangle()
                            .fill(color)
                            .frame(height: 60)
                            .cornerRadius(12)
                        
                        Text(hex)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
        }
    }
}

extension UIColor {
    func toHexString() -> String {
        var rFloat: CGFloat = 0
        var gFloat: CGFloat = 0
        var bFloat: CGFloat = 0
        var aFloat: CGFloat = 0
        
        self.getRed(&rFloat, green: &gFloat, blue: &bFloat, alpha: &aFloat)
        
        let rInt = Int(rFloat * 255)
        let gInt = Int(gFloat * 255)
        let bInt = Int(bFloat * 255)
        
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
}

struct ProminentColorsView: View {
    @State private var colors: [UIColor] = []
    @State private var errorMessage: String?
    private let image =  UIImage(named: "SignInBG")!
    
    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(16)
                .padding(.horizontal)
            
            if !colors.isEmpty {
                ColorPaletteView(colors: colors)
            }
            
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }
        }
        .task {
            do {
                colors = try image.extractColors(numberOfColors: 1)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProminentColorsView()
}


// MARK: - Detail sheet for a single item
struct ItemDetailViewSpectate: View {
    @Environment(\.dismiss) var dismiss
    
    let items: [RankoItem]
    let initialItem: RankoItem  // the item to center on initially
    let listID: String
    
    // Infinite carousel state
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[RankoItem]] = []
    @State private var autoScrollEnabled = false
    @State private var showEditSheet = false
    @State private var backgroundColor: Color = .white
    @State private var currentCenteredIndex: Int = 0
    @State private var selectedType: String = ItemDetailView.types.first!
    
    // Animation / layout constants
    private let pageWidth: CGFloat = 250
    private let pageHeight: CGFloat = 350
    private let spacing: CGFloat = 60
    private let animationDuration: CGFloat = 0.3
    private let secondsPerSlide: CGFloat = 1.0
    @Namespace private var tabNamespace
    private let carouselAnimation: Animation = .default
    
    var body: some View {
        let flatItems = itemsArray.flatMap { $0 }
        let widthDiff = UIScreen.main.bounds.width - pageWidth
        
        NavigationView {
            ZStack {
                //backgroundColor.ignoresSafeArea().animation(.easeInOut(duration: 0.4), value: backgroundColor)
                Color.gray
                    .opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ScrollView(.horizontal) {
                        HStack(spacing: spacing) {
                            ForEach(0..<flatItems.count, id: \.self) { idx in
                                let item = flatItems[idx]
                                VStack(spacing: 12) {
                                    VStack {
                                        ZStack(alignment: .bottom) {
                                            AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView().frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                        .frame(
                                                            width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth,
                                                            height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .onAppear {
                                                            if idx % items.count == currentCenteredIndex {
                                                                Task {
                                                                    if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                                                        extractAndEnhanceColor(from: uiImage)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                case .failure:
                                                    Color.gray.frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }

                                            VStack(spacing: 8) {
                                                Text(item.record.ItemName)
                                                    .font(.caption).fontWeight(.bold)
                                                    .multilineTextAlignment(.center)
                                                    .textCase(.uppercase)

                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        ForEach(ItemDetailView.types, id: \.self) { type in
                                                            Group {
                                                                if type == "Camera" {
                                                                    Image(systemName: "camera")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                } else {
                                                                    Text(type)
                                                                        .font(.system(size: 10, weight: .bold))
                                                                }
                                                            }
                                                            .padding(.vertical, 7)
                                                            .foregroundColor(selectedType == type ? .orange : .gray.opacity(0.35))
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                withAnimation(.snappy) {
                                                                    selectedType = type
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                if selectedType == "Camera" {
                                                    
                                                } else {
                                                    Divider()
                                                }
                                                

                                                tabContent(for: item)
                                            }
                                            .padding()
                                            .frame(width: pageWidth)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                                            )
                                            .offset(y: selectedType == "Camera" ? 120 : 90)
                                        }
                                        .frame(width: pageWidth, height: pageHeight)
                                        .padding(.bottom, 30)
                                    }
                                }
                                .shadow(color: .black.opacity(0.2), radius: 15)
                                .frame(width: pageWidth, height: pageHeight)
                                .scrollTransition { content, phase in
                                    content.scaleEffect(y: phase.isIdentity ? 1 : 0.7)
                                }
                            }
                        }.scrollTargetLayout()
                            .padding(.bottom, 60)
                    }
                    
                    .contentMargins(widthDiff / 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: pageHeight * 1.3)
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollIndicators(.hidden)
                    .onAppear { setupCarousel() }
                    .onChange(of: scrollPosition) { newPos, pos in
                        guard let pos = pos else { return }
                        currentCenteredIndex = pos % items.count
                        handleWrap(at: pos)
                        scheduleAutoScroll(from: pos)
                        Task {
                            let item = items[currentCenteredIndex]
                            if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                extractAndEnhanceColor(from: uiImage)
                            }
                        }
                    }
                    
                    
                    HStack(spacing: 10) {
                        ForEach(0..<items.count, id: \.self) { i in
                            let isSelected = i == currentCenteredIndex
                            let item = items[i]
                            let rankColor: Color = {
                                switch item.rank {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12, height: isSelected ? 30 : 12)
                                    .animation(.easeInOut(duration: 0.1), value: currentCenteredIndex)
                                
                                if isSelected {
                                    if item.rank > 3 {
                                        Text("\(item.rank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                            .transition(.opacity.combined(with: .scale))
                                            .animation(.bouncy(duration: 1), value: currentCenteredIndex)
                                    } else {
                                        Text("\(item.rank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                    
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    scrollPosition = i + items.count
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "door.left.hand.open")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func tabContent(for item: RankoItem) -> some View {
        switch selectedType {
        case "Description":
            Text(item.record.ItemDescription)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        case "Comments":
            Text("Comments section coming soon...").font(.caption2).foregroundColor(.blue).padding(.horizontal)
        case "Trivia":
            Text("Fun facts or trivia here!").font(.caption2).foregroundColor(.purple).padding(.horizontal)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Carousel Setup
    private func extractColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let uiColors = try uiImage.extractColors(numberOfColors: 1)
                if let prominent = uiColors.first {
                    let newColor = Color(prominent)
                    DispatchQueue.main.async {
                        withAnimation {
                            backgroundColor = newColor
                        }
                    }
                }
            } catch {
                print("Color extraction failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractAndEnhanceColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let colors = try uiImage.extractColors(numberOfColors: 1)
                if let dominant = colors.first {
                    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                    dominant.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    
                    // Boost saturation and brightness
                    let vibrant = UIColor(
                        hue: hue,
                        saturation: min(1.0, saturation * 1.5 + 0.2),
                        brightness: min(1.0, brightness * 1.5 + 0.1),
                        alpha: 1.0
                    )
                    
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            backgroundColor = Color(vibrant)
                        }
                    }
                }
            } catch {
                print("Failed to extract colors: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUIImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func setupCarousel() {
        let sorted = items.sorted { $0.rank < $1.rank }
        itemsArray = [sorted, sorted, sorted]
        // find the index of the initial item in the sorted array
        let initialIndex = sorted.firstIndex(where: { $0.id == initialItem.id }) ?? 0
        // center on the middle copy plus that offset
        scrollPosition = sorted.count + initialIndex
    }
    
    private func handleWrap(at pos: Int) {
        let count = items.count
        if pos < count {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeLast()
                itemsArray.insert(items.sorted { $0.rank < $1.rank }, at: 0)
                scrollPosition = pos + count
            }
        } else if pos >= count * 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeFirst()
                itemsArray.append(items.sorted { $0.rank < $1.rank })
                scrollPosition = pos - count
            }
        }
    }
    
    private func toggleAutoScroll() {
        let wasOn = autoScrollEnabled
        autoScrollEnabled.toggle()
        if !wasOn, let pos = scrollPosition {
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
            })
        }
    }
    
    private func scheduleAutoScroll(from pos: Int) {
        guard autoScrollEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsPerSlide) {
            withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
        }
    }
    
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
            } else if rank == 2 {
                Image(systemName: "2.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
            } else if rank == 3 {
                Image(systemName: "3.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
            } else {
                Text("\(rank)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(5)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }
}

struct GroupItemDetailView: View {
    let items: [RankoItem]
    let rowIndex: Int
    let numberOfRows: Int
    let initialItem: RankoItem
    let listID: String
    let onSave: (RankoItem) -> Void
    
    // Infinite carousel state
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[RankoItem]] = []
    @State private var autoScrollEnabled = false
    @State private var showEditSheet = false
    @State private var backgroundColor: Color = .white
    @State private var currentCenteredIndex: Int = 0
    @State private var selectedType: String = ItemDetailView.types.first!
    
    // Animation / layout constants
    private let pageWidth: CGFloat = 250
    private let pageHeight: CGFloat = 350
    private let spacing: CGFloat = 60
    private let animationDuration: CGFloat = 0.3
    private let secondsPerSlide: CGFloat = 1.0
    @Namespace private var tabNamespace
    private let carouselAnimation: Animation = .default
    
    var body: some View {
        let flatItems = itemsArray.flatMap { $0 }
        let widthDiff = UIScreen.main.bounds.width - pageWidth
        
        NavigationView {
            ZStack {
                //backgroundColor.ignoresSafeArea().animation(.easeInOut(duration: 0.4), value: backgroundColor)
                Color.gray
                    .opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ScrollView(.horizontal) {
                        HStack(spacing: spacing) {
                            ForEach(0..<flatItems.count, id: \.self) { idx in
                                let item = flatItems[idx]
                                VStack(spacing: 12) {
                                    VStack {
                                        ZStack(alignment: .bottom) {
                                            AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView().frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                        .frame(
                                                            width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth,
                                                            height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .onAppear {
                                                            if idx % items.count == currentCenteredIndex {
                                                                Task {
                                                                    if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                                                        extractAndEnhanceColor(from: uiImage)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                case .failure:
                                                    Color.gray.frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }

                                            VStack(spacing: 8) {
                                                Text(item.record.ItemName)
                                                    .font(.caption).fontWeight(.bold)
                                                    .multilineTextAlignment(.center)
                                                    .textCase(.uppercase)

                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        ForEach(ItemDetailView.types, id: \.self) { type in
                                                            Group {
                                                                if type == "Camera" {
                                                                    Image(systemName: "camera")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                } else {
                                                                    Text(type)
                                                                        .font(.system(size: 10, weight: .bold))
                                                                }
                                                            }
                                                            .padding(.vertical, 7)
                                                            .foregroundColor(selectedType == type ? .orange : .gray.opacity(0.35))
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                withAnimation(.snappy) {
                                                                    selectedType = type
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                if selectedType == "Camera" {
                                                    
                                                } else {
                                                    Divider()
                                                }
                                                

                                                tabContent(for: item)
                                            }
                                            .padding()
                                            .frame(width: pageWidth)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                                            )
                                            .offset(y: selectedType == "Camera" ? 120 : 90)
                                        }
                                        .frame(width: pageWidth, height: pageHeight)
                                        .padding(.bottom, 30)
                                    }
                                }
                                .shadow(color: .black.opacity(0.2), radius: 15)
                                .frame(width: pageWidth, height: pageHeight)
                                .scrollTransition { content, phase in
                                    content.scaleEffect(y: phase.isIdentity ? 1 : 0.7)
                                }
                            }
                        }.scrollTargetLayout()
                            .padding(.bottom, 60)
                    }
                    
                    .contentMargins(widthDiff / 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: pageHeight * 1.3)
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollIndicators(.hidden)
                    .onAppear { setupCarousel() }
                    .onChange(of: scrollPosition) { newPos, pos in
                        guard let pos = pos else { return }
                        currentCenteredIndex = pos % items.count
                        handleWrap(at: pos)
                        scheduleAutoScroll(from: pos)
                        Task {
                            let item = items[currentCenteredIndex]
                            if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                extractAndEnhanceColor(from: uiImage)
                            }
                        }
                    }
                    
                    HStack(spacing: 10) {
                        ForEach(0..<numberOfRows, id: \.self) { i in
                            // highlight whenever this is the tapped‐row
                            let isSelected = (i == rowIndex)
                            let displayRow = i + 1
                            let rankColor: Color = {
                                switch displayRow {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()

                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12,
                                           height: isSelected ? 30 : 12)

                                Text("\(displayRow)")
                                    .font(.caption.bold())
                                    .foregroundColor(isSelected
                                        ? (displayRow <= 3 ? .white : .black)
                                                     : .clear)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    HStack(spacing: 10) {
                        ForEach(0..<items.count, id: \.self) { i in
                            let isSelected = i == currentCenteredIndex
                            let item = items[i]
                            let actualRank = (item.rank) - (rowIndex * 1000) - 1000
                            let rankColor: Color = {
                                switch actualRank {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12, height: isSelected ? 30 : 12)
                                    .animation(.easeInOut(duration: 0.1), value: currentCenteredIndex)
                                
                                if isSelected {
                                    if actualRank > 3 {
                                        Text("\(actualRank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                            .transition(.opacity.combined(with: .scale))
                                            .animation(.bouncy(duration: 1), value: currentCenteredIndex)
                                    } else {
                                        Text("\(actualRank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                    
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    scrollPosition = i + items.count
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                // Determine which item is centered
                let centerIdx = (scrollPosition ?? 0) % items.count
                let currentItem = items.sorted { $0.rank < $1.rank }[centerIdx]
                EditItemView(
                    item: currentItem,
                    listID: listID
                ) { newName, newDesc in
                    // build updated record & item
                    let rec = currentItem.record
                    let updatedRecord = RankoRecord(
                        objectID: rec.objectID,
                        ItemName: newName,
                        ItemDescription: newDesc,
                        ItemCategory: "",
                        ItemImage: rec.ItemImage
                    )
                    let updatedItem = RankoItem(
                        id: currentItem.id,
                        rank: currentItem.rank,
                        votes: currentItem.votes,
                        record: updatedRecord
                    )
                    // callback to parent
                    onSave(updatedItem)
                }
            }
            // edit sheet integration remains unchanged
        }
    }
    
    @ViewBuilder
    private func tabContent(for item: RankoItem) -> some View {
        switch selectedType {
        case "Description":
            Text(item.record.ItemDescription)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        case "Comments":
            Text("Comments section coming soon...").font(.caption2).foregroundColor(.blue).padding(.horizontal)
        case "Trivia":
            Text("Fun facts or trivia here!").font(.caption2).foregroundColor(.purple).padding(.horizontal)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Carousel Setup
    private func extractColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let uiColors = try uiImage.extractColors(numberOfColors: 1)
                if let prominent = uiColors.first {
                    let newColor = Color(prominent)
                    DispatchQueue.main.async {
                        withAnimation {
                            backgroundColor = newColor
                        }
                    }
                }
            } catch {
                print("Color extraction failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractAndEnhanceColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let colors = try uiImage.extractColors(numberOfColors: 1)
                if let dominant = colors.first {
                    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                    dominant.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    
                    // Boost saturation and brightness
                    let vibrant = UIColor(
                        hue: hue,
                        saturation: min(1.0, saturation * 1.5 + 0.2),
                        brightness: min(1.0, brightness * 1.5 + 0.1),
                        alpha: 1.0
                    )
                    
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            backgroundColor = Color(vibrant)
                        }
                    }
                }
            } catch {
                print("Failed to extract colors: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUIImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func setupCarousel() {
        let sorted = items.sorted { $0.rank < $1.rank }
        itemsArray = [sorted, sorted, sorted]
        // find the index of the initial item in the sorted array
        let initialIndex = sorted.firstIndex(where: { $0.id == initialItem.id }) ?? 0
        // center on the middle copy plus that offset
        scrollPosition = sorted.count + initialIndex
    }
    
    private func handleWrap(at pos: Int) {
        let count = items.count
        if pos < count {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeLast()
                itemsArray.insert(items.sorted { $0.rank < $1.rank }, at: 0)
                scrollPosition = pos + count
            }
        } else if pos >= count * 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeFirst()
                itemsArray.append(items.sorted { $0.rank < $1.rank })
                scrollPosition = pos - count
            }
        }
    }
    
    private func toggleAutoScroll() {
        let wasOn = autoScrollEnabled
        autoScrollEnabled.toggle()
        if !wasOn, let pos = scrollPosition {
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
            })
        }
    }
    
    private func scheduleAutoScroll(from pos: Int) {
        guard autoScrollEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsPerSlide) {
            withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
        }
    }
    
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
            } else if rank == 2 {
                Image(systemName: "2.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
            } else if rank == 3 {
                Image(systemName: "3.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
            } else {
                Text("\(rank)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(5)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }
}

struct GroupItemDetailViewSpectate: View {
    let items: [RankoItem]
    let rowIndex: Int
    let numberOfRows: Int
    let initialItem: RankoItem
    let listID: String
    let onSave: (RankoItem) -> Void
    
    // Infinite carousel state
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[RankoItem]] = []
    @State private var autoScrollEnabled = false
    @State private var showEditSheet = false
    @State private var backgroundColor: Color = .white
    @State private var currentCenteredIndex: Int = 0
    @State private var selectedType: String = ItemDetailView.types.first!
    
    // Animation / layout constants
    private let pageWidth: CGFloat = 250
    private let pageHeight: CGFloat = 350
    private let spacing: CGFloat = 60
    private let animationDuration: CGFloat = 0.3
    private let secondsPerSlide: CGFloat = 1.0
    @Namespace private var tabNamespace
    private let carouselAnimation: Animation = .default
    
    var body: some View {
        let flatItems = itemsArray.flatMap { $0 }
        let widthDiff = UIScreen.main.bounds.width - pageWidth
        
        NavigationView {
            ZStack {
                //backgroundColor.ignoresSafeArea().animation(.easeInOut(duration: 0.4), value: backgroundColor)
                Color.gray
                    .opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ScrollView(.horizontal) {
                        HStack(spacing: spacing) {
                            ForEach(0..<flatItems.count, id: \.self) { idx in
                                let item = flatItems[idx]
                                VStack(spacing: 12) {
                                    VStack {
                                        ZStack(alignment: .bottom) {
                                            AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView().frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                        .frame(
                                                            width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth,
                                                            height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth
                                                        )
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .onAppear {
                                                            if idx % items.count == currentCenteredIndex {
                                                                Task {
                                                                    if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                                                        extractAndEnhanceColor(from: uiImage)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                case .failure:
                                                    Color.gray.frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }

                                            VStack(spacing: 8) {
                                                Text(item.record.ItemName)
                                                    .font(.caption).fontWeight(.bold)
                                                    .multilineTextAlignment(.center)
                                                    .textCase(.uppercase)

                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        ForEach(ItemDetailView.types, id: \.self) { type in
                                                            Group {
                                                                if type == "Camera" {
                                                                    Image(systemName: "camera")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                } else {
                                                                    Text(type)
                                                                        .font(.system(size: 10, weight: .bold))
                                                                }
                                                            }
                                                            .padding(.vertical, 7)
                                                            .foregroundColor(selectedType == type ? .orange : .gray.opacity(0.35))
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                withAnimation(.snappy) {
                                                                    selectedType = type
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                if selectedType == "Camera" {
                                                    
                                                } else {
                                                    Divider()
                                                }
                                                

                                                tabContent(for: item)
                                            }
                                            .padding()
                                            .frame(width: pageWidth)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                                            )
                                            .offset(y: selectedType == "Camera" ? 120 : 90)
                                        }
                                        .frame(width: pageWidth, height: pageHeight)
                                        .padding(.bottom, 30)
                                    }
                                }
                                .shadow(color: .black.opacity(0.2), radius: 15)
                                .frame(width: pageWidth, height: pageHeight)
                                .scrollTransition { content, phase in
                                    content.scaleEffect(y: phase.isIdentity ? 1 : 0.7)
                                }
                            }
                        }.scrollTargetLayout()
                            .padding(.bottom, 60)
                    }
                    
                    .contentMargins(widthDiff / 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: pageHeight * 1.3)
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollIndicators(.hidden)
                    .onAppear { setupCarousel() }
                    .onChange(of: scrollPosition) { newPos, pos in
                        guard let pos = pos else { return }
                        currentCenteredIndex = pos % items.count
                        handleWrap(at: pos)
                        scheduleAutoScroll(from: pos)
                        Task {
                            let item = items[currentCenteredIndex]
                            if let uiImage = try? await loadUIImage(from: item.record.ItemImage) {
                                extractAndEnhanceColor(from: uiImage)
                            }
                        }
                    }
                    
                    HStack(spacing: 10) {
                        ForEach(0..<numberOfRows, id: \.self) { i in
                            // highlight whenever this is the tapped‐row
                            let isSelected = (i == rowIndex)
                            let displayRow = i + 1
                            let rankColor: Color = {
                                switch displayRow {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()

                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12,
                                           height: isSelected ? 30 : 12)

                                Text("\(displayRow)")
                                    .font(.caption.bold())
                                    .foregroundColor(isSelected
                                        ? (displayRow <= 3 ? .white : .black)
                                                     : .clear)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    HStack(spacing: 10) {
                        ForEach(0..<items.count, id: \.self) { i in
                            let isSelected = i == currentCenteredIndex
                            let item = items[i]
                            let actualRank = (item.rank) - (rowIndex * 1000) - 1000
                            let rankColor: Color = {
                                switch actualRank {
                                case 1: return Color(red: 1, green: 0.65, blue: 0)
                                case 2: return Color(red: 0.635, green: 0.7, blue: 0.698)
                                case 3: return Color(red: 0.56, green: 0.33, blue: 0)
                                default: return .white.opacity(0.8)
                                }
                            }()
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? rankColor : Color.white.opacity(0.3))
                                    .frame(width: isSelected ? 30 : 12, height: isSelected ? 30 : 12)
                                    .animation(.easeInOut(duration: 0.1), value: currentCenteredIndex)
                                
                                if isSelected {
                                    if actualRank > 3 {
                                        Text("\(actualRank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                            .transition(.opacity.combined(with: .scale))
                                            .animation(.bouncy(duration: 1), value: currentCenteredIndex)
                                    } else {
                                        Text("\(actualRank)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                    
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    scrollPosition = i + items.count
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    @ViewBuilder
    private func tabContent(for item: RankoItem) -> some View {
        switch selectedType {
        case "Description":
            Text(item.record.ItemDescription)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        case "Comments":
            Text("Comments section coming soon...").font(.caption2).foregroundColor(.blue).padding(.horizontal)
        case "Trivia":
            Text("Fun facts or trivia here!").font(.caption2).foregroundColor(.purple).padding(.horizontal)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Carousel Setup
    private func extractColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let uiColors = try uiImage.extractColors(numberOfColors: 1)
                if let prominent = uiColors.first {
                    let newColor = Color(prominent)
                    DispatchQueue.main.async {
                        withAnimation {
                            backgroundColor = newColor
                        }
                    }
                }
            } catch {
                print("Color extraction failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractAndEnhanceColor(from uiImage: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let colors = try uiImage.extractColors(numberOfColors: 1)
                if let dominant = colors.first {
                    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                    dominant.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    
                    // Boost saturation and brightness
                    let vibrant = UIColor(
                        hue: hue,
                        saturation: min(1.0, saturation * 1.5 + 0.2),
                        brightness: min(1.0, brightness * 1.5 + 0.1),
                        alpha: 1.0
                    )
                    
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            backgroundColor = Color(vibrant)
                        }
                    }
                }
            } catch {
                print("Failed to extract colors: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUIImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func setupCarousel() {
        let sorted = items.sorted { $0.rank < $1.rank }
        itemsArray = [sorted, sorted, sorted]
        // find the index of the initial item in the sorted array
        let initialIndex = sorted.firstIndex(where: { $0.id == initialItem.id }) ?? 0
        // center on the middle copy plus that offset
        scrollPosition = sorted.count + initialIndex
    }
    
    private func handleWrap(at pos: Int) {
        let count = items.count
        if pos < count {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeLast()
                itemsArray.insert(items.sorted { $0.rank < $1.rank }, at: 0)
                scrollPosition = pos + count
            }
        } else if pos >= count * 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                itemsArray.removeFirst()
                itemsArray.append(items.sorted { $0.rank < $1.rank })
                scrollPosition = pos - count
            }
        }
    }
    
    private func toggleAutoScroll() {
        let wasOn = autoScrollEnabled
        autoScrollEnabled.toggle()
        if !wasOn, let pos = scrollPosition {
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
            })
        }
    }
    
    private func scheduleAutoScroll(from pos: Int) {
        guard autoScrollEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsPerSlide) {
            withAnimation(carouselAnimation) { scrollPosition = pos + 1 }
        }
    }
    
    @ViewBuilder
    private func badgeView(for rank: Int) -> some View {
        Group {
            if rank == 1 {
                Image(systemName: "1.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 1, green: 0.65, blue: 0))
            } else if rank == 2 {
                Image(systemName: "2.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698))
            } else if rank == 3 {
                Image(systemName: "3.circle.fill")
                    .font(.largeTitle)
                    .padding(3)
                    .foregroundColor(Color(red: 0.56, green: 0.33, blue: 0))
            } else {
                Text("\(rank)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .padding(5)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }
}
