//
//  ItemView.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 3/6/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase

// MARK: - Detail sheet for a single item
struct ItemDetailView: View {
    let items: [RankoItem]
    let initialItem: RankoItem  // the item to center on initially
    let rankoID: String
    let onSave: (RankoItem) -> Void
    
    // Infinite carousel state
    @State private var scrollPosition: Int?
    @State private var itemsArray: [[RankoItem]] = []
    @State private var autoScrollEnabled = false
    @State private var showEditSheet = false
    @State private var backgroundColor: Color = .white
    @State private var currentCenteredIndex: Int = 0
    @State private var selectedType: String = ItemDetailView.types.first!
    @State private var hapticFeedback: Bool = false
    
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
        GeometryReader { geo in
            let widthDiff = geo.size.width - pageWidth
            
            NavigationView {
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
                                                case .failure:
                                                    Color.gray.frame(width: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth, height: selectedType == "Camera" ? pageWidth * 1.2 : pageWidth)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            
                                            VStack(spacing: 8) {
                                                Text(item.record.ItemName)
                                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color(hex: 0x857467))
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
                                                            .foregroundColor(selectedType == type ? Color(hex: 0x857467) : .gray.opacity(0.35))
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
                    }
                    
                    if let pos = scrollPosition {
                        Image(systemName: "\((pos % items.count) + 1).circle.fill")
                            .font(.system(size: 25, weight: .regular, design: .default))
                            .foregroundColor(Color(hex: 0x857467))
                            .padding(.top, 40)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(currentCenteredIndex) },
                            set: { newValue in
                                let newIndex = Int(newValue.rounded())
                                currentCenteredIndex = newIndex
                                withAnimation {
                                    scrollPosition = newIndex + items.count // keep middle copy in focus
                                }
                            }
                        ),
                        in: 0...Double(items.count - 1),
                        step: 1
                    )
                    .sensoryFeedback(.increase, trigger: scrollPosition)
                    .padding(.horizontal, 50)
                    .accentColor(Color(hex: 0x857467))
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
                        rankoID: rankoID
                    ) { newName, newDesc in
                        // build updated record & item
                        let rec = currentItem.record
                        let updatedRecord = RankoRecord(
                            objectID: rec.objectID,
                            ItemName: newName,
                            ItemDescription: newDesc,
                            ItemCategory: "",
                            ItemImage: rec.ItemImage,
                            ItemGIF: rec.ItemGIF,
                            ItemVideo: rec.ItemVideo,
                            ItemAudio: rec.ItemVideo
                        )
                        let updatedItem = RankoItem(
                            id: currentItem.id,
                            rank: currentItem.rank,
                            votes: currentItem.votes,
                            record: updatedRecord,
                            playCount: currentItem.playCount
                        )
                        // callback to parent
                        onSave(updatedItem)
                    }
                }
                
                // edit sheet integration remains unchanged
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @Environment(\.dismiss) private var dismiss
    @FocusState private var itemNameFocused: Bool

    // inbound
    let item: RankoItem
    let rankoID: String
    let onSave: (String, String) -> Void   // NOTE: this only returns name/desc; ItemImage is written directly to RTDB here

    // editable fields
    @State private var editedName: String
    @State private var editedDescription: String

    // image state
    @State private var localPreview: UIImage? = nil          // cropped preview
    @State private var imageForCropping: UIImage? = nil
    @State private var showPicker = false
    @State private var showCropper = false
    @State private var newUploadedPath: String? = nil        // "rankoPersonalImages/{rankoID}/{itemID}.jpg"
    @State private var newUploadedURL: String? = nil         // deterministic download URL string (no token)
    @State private var didUploadThisSession = false

    // locks + errors
    @State private var isUploading = false
    @State private var isUpdatingDB = false
    @State private var errorMessage: String? = nil
    @State private var showConfirmAttach = false

    init(item: RankoItem, rankoID: String, onSave: @escaping (String, String) -> Void) {
        self.item = item
        self.rankoID = rankoID
        self.onSave = onSave
        _editedName = State(initialValue: item.itemName)
        _editedDescription = State(initialValue: item.itemDescription)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // IMAGE
                    VStack {
                        
                        if let img = localPreview {
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.06))
                                    .frame(width: 240, height: 240)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Button {
                                    showPicker = true
                                    print("Replacing Local Image...")
                                } label: {
                                    HStack {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 20, weight: .black, design: .default))
                                    }
                                    .frame(width: 32, height: 38)
                                }
                                .tint(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .buttonStyle(.glassProminent)
                                .padding(.horizontal, 8)
                                .background(Circle().stroke(Color.white, lineWidth: 14))
                                .offset(x: 15, y: 15)
                                .disabled(isUploading || isUpdatingDB)
                            }
                        } else {
                            AsyncImage(url: URL(string: item.record.ItemImage)) { phase in
                                switch phase {
                                case .empty:
                                    ZStack(alignment: .bottomTrailing) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.06))
                                            .frame(width: 240, height: 240)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                            )
                                        ProgressView().frame(width: 240, height: 240)
                                        Button {
                                            showPicker = true
                                            print("Replacing Empty Image...")
                                        } label: {
                                            HStack {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 20, weight: .black, design: .default))
                                            }
                                            .frame(width: 32, height: 38)
                                        }
                                        .tint(
                                            LinearGradient(
                                                colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                        .padding(.horizontal, 8)
                                        .background(Circle().stroke(Color.white, lineWidth: 14))
                                        .offset(x: 15, y: 15)
                                        .disabled(isUploading || isUpdatingDB)
                                    }
                                case .success(let image):
                                    ZStack(alignment: .bottomTrailing) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.06))
                                            .frame(width: 240, height: 240)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                            )
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 240, height: 240)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        Button {
                                            showPicker = true
                                            print("Replacing Async Image...")
                                        } label: {
                                            HStack {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 20, weight: .black, design: .default))
                                            }
                                            .frame(width: 32, height: 38)
                                        }
                                        .tint(
                                            LinearGradient(
                                                colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                        .padding(.horizontal, 8)
                                        .background(Circle().stroke(Color.white, lineWidth: 14))
                                        .offset(x: 15, y: 15)
                                        .disabled(isUploading || isUpdatingDB)
                                    }
                                case .failure:
                                    ZStack(alignment: .bottomTrailing) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.06))
                                            .frame(width: 240, height: 240)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                            )
                                        Image(systemName: "photo")
                                            .font(.system(size: 48, weight: .black))
                                            .opacity(0.35)
                                        Button {
                                            showPicker = true
                                            print("Replacing Failed Image...")
                                        } label: {
                                            HStack {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 20, weight: .black, design: .default))
                                            }
                                            .frame(width: 32, height: 38)
                                        }
                                        .tint(
                                            LinearGradient(
                                                colors: [Color(hex: 0xFFC155), Color(hex: 0xFF924E)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .buttonStyle(.glassProminent)
                                        .padding(.horizontal, 8)
                                        .background(Circle().stroke(Color.white, lineWidth: 14))
                                        .offset(x: 15, y: 15)
                                        .disabled(isUploading || isUpdatingDB)
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 240, height: 240)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    // NAME
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Item Name".uppercased())
                                .foregroundColor(.secondary)
                                .font(.custom("Nunito-Black", size: 12))
                            Text("*").foregroundColor(.red).font(.custom("Nunito-Black", size: 12))
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "textformat.size.larger").foregroundColor(.gray)
                            TextField("Name *", text: $editedName)
                                .autocorrectionDisabled(true)
                                .font(.custom("Nunito-Regular", size: 18))
                                .foregroundStyle(Color.secondary)
                                .focused($itemNameFocused)
                                .onChange(of: editedName) { _, v in
                                    if v.count > 50 { editedName = String(v.prefix(50)) }
                                }
                            Spacer()
                            Text("\(editedName.count)/50")
                                .font(.custom("Nunito-Regular", size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .onAppear { itemNameFocused = true }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                    }

                    // DESCRIPTION
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description".uppercased())
                            .foregroundColor(.secondary)
                            .font(.custom("Nunito-Black", size: 12))
                        HStack(spacing: 6) {
                            Image(systemName: "textformat.size.smaller").foregroundColor(.gray)
                            TextField("Description (optional)", text: $editedDescription, axis: .vertical)
                                .autocorrectionDisabled(true)
                                .font(.custom("Nunito-Regular", size: 18))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1...3)
                                .onChange(of: editedDescription) { _, v in
                                    if v.count > 100 { editedDescription = String(v.prefix(100)) }
                                    let draftDescription = editedDescription
                                    if draftDescription.range(of: "\n") != nil {
                                        hideKeyboard()
                                        editedDescription = draftDescription.replacingOccurrences(of: "\n", with: "")
                                    }
                                }
                            Spacer()
                            Text("\(editedDescription.count)/100")
                                .font(.custom("Nunito-Regular", size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await handleCancel() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .disabled(isUploading || isUpdatingDB)
                }
                ToolbarItem(placement: .principal) {
                    Text("Edit Item")
                        .font(.custom("Nunito-Black", size: 18))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // if a new image was uploaded this session, confirm permanent attach
                        if newUploadedURL != nil {
                            showConfirmAttach = true
                        } else {
                            Task { await commitNameDescOnlyAndDismiss() }
                        }
                    } label: {
                        if isUploading || isUpdatingDB {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .disabled(isUploading || isUpdatingDB || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isUploading || isUpdatingDB)
            .disabled(isUploading || isUpdatingDB)
            .alert("Upload error", isPresented: .init(
                get: { errorMessage != nil && isUploading },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "unknown error")
            }
            .alert("Update failed", isPresented: .init(
                get: { errorMessage != nil && isUpdatingDB },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "unknown error")
            }
            .confirmationDialog(
                "Save image to this item?",
                isPresented: $showConfirmAttach,
                titleVisibility: .visible
            ) {
                Button("Yes, attach image", role: .none) {
                    Task { await finalizeAttachAndDismiss() }
                }
                Button("No, keep old image", role: .cancel) {
                    Task { await commitNameDescOnlyAndDismiss() }
                }
            } message: {
                Text("this will permanently set the item's photo to the one you just uploaded.")
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(image: $imageForCropping, isPresented: $showPicker)
            }
            .fullScreenCover(isPresented: $showCropper) {
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
                            showCropper = false
                        },
                        onComplete: { cropped in
                            imageForCropping = nil
                            showCropper = false
                            if let c = cropped { Task { await uploadCropped(c) } }
                        }
                    )
                }
            }
            .onChange(of: imageForCropping) { _, v in
                if v != nil { showCropper = true }
            }
        }
        .presentationDetents([.height(560), .large])
        .presentationBackground(Color(hex: 0xFFFFFF))
    }

    // MARK: - Upload

    private func pathForItem(_ rankoID: String, _ itemID: String) -> String {
        "rankoPersonalImages/\(rankoID)/\(itemID).jpg"
    }

    private func deterministicURL(for rankoID: String, _ itemID: String) -> String {
        "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/rankoPersonalImages%2F\(rankoID)%2F\(itemID).jpg?alt=media&token="
    }

    private func makeJPEGMetadata() -> StorageMetadata {
        let md = StorageMetadata()
        md.contentType = "image/jpeg"
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Australia/Sydney")
        fmt.dateFormat = "yyyyMMddHHmmss"
        md.customMetadata = [
            "rankoID": rankoID,
            "itemID": item.id,
            "userID": Auth.auth().currentUser?.uid ?? "",
            "uploadedAt": fmt.string(from: now)
        ]
        return md
    }

    private func uploadCropped(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            errorMessage = "couldn't encode image"
            return
        }
        withAnimation {
            isUploading = true
        }
        errorMessage = nil

        let path = pathForItem(rankoID, item.id)
        let ref = Storage.storage().reference().child(path)

        do {
            _ = try await ref.putDataAsync(data, metadata: makeJPEGMetadata())
            // success — set preview + remember path/URL
            await MainActor.run {
                localPreview = image
                newUploadedPath = path
                newUploadedURL = deterministicURL(for: rankoID, item.id)
                didUploadThisSession = true
                withAnimation {
                    isUploading = false
                }
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    isUploading = false
                }
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    // MARK: - Save / Cancel flows

    private func handleCancel() async {
        // if we uploaded a new file in this session but user cancels, try to delete it
        if didUploadThisSession, let path = newUploadedPath {
            await deleteStorageObject(at: path)
        }
        dismiss()
    }

    /// Save ONLY name/desc and exit (keeps the old image)
    private func commitNameDescOnlyAndDismiss() async {
        await MainActor.run {
            isUpdatingDB = true
            errorMessage = nil
        }

        // non-throwing local update back to parent
        onSave(editedName, editedDescription)

        await MainActor.run {
            isUpdatingDB = false
            dismiss()
        }
    }

    /// Save name/desc AND attach new image URL to RTDB, then exit
    private func finalizeAttachAndDismiss() async {
        guard let finalURL = newUploadedURL else {
            await commitNameDescOnlyAndDismiss()
            return
        }

        await MainActor.run {
            isUpdatingDB = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in isUpdatingDB = false }
        }

        do {
            // 1) write ItemImage directly to RTDB
            let ref = Database.database().reference()
                .child("RankoData").child(rankoID)
                .child("RankoItems").child(item.id)
                .child("ItemImage")
            try await setValueAsync(ref, value: finalURL)

            // 2) hand name/desc back to parent
            onSave(editedName, editedDescription)

            // 3) done
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    // MARK: - Small async helpers

    private func setValueAsync(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { err, _ in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
    }

    private func deleteStorageObject(at path: String) async {
        let ref = Storage.storage().reference().child(path)
        _ = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.delete { _ in cont.resume() }
        }
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

// MARK: - Detail sheet for a single item
struct ItemDetailViewSpectate: View {
    @Environment(\.dismiss) var dismiss
    
    let items: [RankoItem]
    let initialItem: RankoItem  // the item to center on initially
    let rankoID: String
    
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
        GeometryReader { geo in
            let widthDiff = geo.size.width - pageWidth
            
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

struct TierItemDetailView: View {
    let items: [RankoItem]
    let rowIndex: Int
    let numberOfRows: Int
    let initialItem: RankoItem
    let rankoID: String
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
        GeometryReader { geo in
            let widthDiff = geo.size.width - pageWidth
            
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
                        rankoID: rankoID
                    ) { newName, newDesc in
                        // build updated record & item
                        let rec = currentItem.record
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
                            id: currentItem.id,
                            rank: currentItem.rank,
                            votes: currentItem.votes,
                            record: updatedRecord,
                            playCount: currentItem.playCount
                        )
                        // callback to parent
                        onSave(updatedItem)
                    }
                }
                // edit sheet integration remains unchanged
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

struct TierItemDetailViewSpectate: View {
    let items: [RankoItem]
    let rowIndex: Int
    let numberOfRows: Int
    let initialItem: RankoItem
    let rankoID: String
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
        GeometryReader { geo in
            let widthDiff = geo.size.width - pageWidth
            
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
