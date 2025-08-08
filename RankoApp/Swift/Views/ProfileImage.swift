//
//  ProfileImage.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 9/5/2025.
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(photoLibrary: .shared())
        cfg.filter = .images
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else { return }

            provider.loadObject(ofClass: UIImage.self) { img, _ in
                DispatchQueue.main.async {
                    self.parent.image = img as? UIImage
                }
            }
        }
    }
}

struct ProfilePictureEditor: View {
    let originalImage: UIImage?
    let onSave: (UIImage?) -> Void
    let onCancel: () -> Void
    
    @State private var workingImage: UIImage?
    @State private var imageForCropping: UIImage?
    @State private var showImageCropper = false
    @State private var showPhotoPicker  = false
    @State private var showNewImageSheet  = false
    @State private var showCamera  = false
    @State private var recentImages: [UIImage] = []

    var body: some View {
        ZStack {
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 10) {
                    // Preview
                    if let img = workingImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(width: 300, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.clear)
                                    .stroke(Color(hex: 0x857467), lineWidth: 3)
                                    .shadow(color: Color(hex: 0x857467).opacity(0.3), radius: 6, x: 0, y: 0)
                            )
                            .padding(.bottom, 25)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 300, height: 300)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32, weight: .black, design: .default))
                                    .foregroundColor(.gray)
                            )
                            .padding(.bottom, 25)
                    }
                    
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Button {
                            if imageForCropping == nil {
                                imageForCropping = originalImage
                            } else {
                                imageForCropping = workingImage
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showImageCropper = true
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crop.rotate")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.leading, 13)
                                Text("Edit Image")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.vertical, 13)
                                    .padding(.trailing, 13)
                            }
                        }
                        .foregroundColor(Color(hex: 0xFF9864))
                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                             startPoint: .top,
                                             endPoint: .bottom
                                            ))
                        .buttonStyle(.glassProminent)
                        
                        Button { showNewImageSheet = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.app.fill")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.leading, 13)
                                Text("New Image")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: 0x857467))
                                    .padding(.vertical, 13)
                                    .padding(.trailing, 13)
                            }
                        }
                        .foregroundColor(Color(hex: 0xFF9864))
                        .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                             startPoint: .top,
                                             endPoint: .bottom
                                            ))
                        .buttonStyle(.glassProminent)
                        Spacer(minLength: 0)
                    }
                    
                    Spacer()
                }
                .padding(.top, 60)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") {
                            onSave(workingImage)
                        }
                    }
                    ToolbarItemGroup(placement: .principal) {
                        Text("Edit Profile Picture")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: 0x857467))
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") {
                            onCancel()
                        }
                    }
                }
            }
        }
        // Photo library picker
        .sheet(isPresented: $showPhotoPicker, onDismiss: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showImageCropper = true } }) {
            ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
        }
        // Cropper
        .fullScreenCover(isPresented: $showImageCropper) {
            SwiftyCropView(
                imageToCrop: imageForCropping!,
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
                onCancel: { showImageCropper = false },
                onComplete: { cropped in
                    workingImage = cropped
                    imageForCropping = nil
                    showImageCropper = false
                }
            )
        }
        .onAppear {
            workingImage = originalImage
            imageForCropping = workingImage
            loadRecentPhotos()
        }
        .sheet(isPresented: $showNewImageSheet) {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text("Photos")
                            .font(.system(size: 14, weight: .bold, design: .default))
                        Spacer()
                        Button {
                            showNewImageSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showPhotoPicker = true
                            }
                        } label: {
                            Text("Show Photo Library")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(Color(hex: 0x0288FE))
                        }
                        
                    }
                    .padding(.horizontal, 25)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { showCamera = true } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "camera")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                            Button {  } label: {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color(hex: 0xF3F3F3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 18, weight: .regular, design: .default))
                                                .foregroundColor(Color(hex: 0x5C5C5C)))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(Color(hex: 0xEFEFF0))
                        .padding(.horizontal, 25)
                    
                    Button {
                        showNewImageSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPhotoPicker = true
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 20) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(Color(hex: 0x080808))
                            Text("Photo Library")
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .foregroundColor(Color(hex: 0x080808))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    Button {} label: {
                        HStack(alignment: .center, spacing: 20) {
                            Image(systemName: "folder")
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(Color(hex: 0x080808))
                            Text("Files")
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .foregroundColor(Color(hex: 0x080808))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 25)
                    
                }
                .padding(.top, 25)
            }
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: 0xFFFFFF))
            .presentationContentInteraction(.resizes)
        }
    }

    private func loadRecentPhotos() {
        // TODO: fetch last 10 UIImages from Photo library
    }
}




struct ProfilePictureEditor1: View {
    @State private var showPhotoPicker = false
    @State private var showImageCropper: Bool = false
    @State private var selectedImage: UIImage?
    @FocusState private var textFieldFocused: Bool
    @State private var imageForCropping: UIImage?
    
    var body: some View {
        VStack {
            Spacer()
            Group {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    ProgressView()
                }
            }
            .scaledToFit()
            .padding()
            Spacer()
            
            GroupBox {
                VStack(spacing: 15) {
                    Button {
                        showPhotoPicker.toggle()
                    } label: {
                        Text("Pick Profile Picture")
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPhotoPicker) {
          ImagePicker(image: $imageForCropping, isPresented: $showPhotoPicker)
        }
        .onChange(of: imageForCropping) { _, new in
          if new != nil { showImageCropper = true }
        }

        .fullScreenCover(isPresented: $showImageCropper) {
          SwiftyCropView(
            imageToCrop: imageForCropping!,
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
                print("Operation cancelled")
            }
          ) { cropped in
            // save final result
            selectedImage   = cropped
            // clear the intermediate so we don't reopen
            imageForCropping = nil
          }
        }
    }
}




struct ProfilePictureEditor2: View {
    let originalImage: UIImage?
    let onSave: (UIImage?) -> Void
    let onCancel: () -> Void

    @State private var workingImage: UIImage? = nil
    @State private var showCropper = false
    @State private var showPicker  = false
    @State private var showCamera  = false
    @State private var recentImages: [UIImage] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Preview
                if let img = workingImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                }

                // Crop / New Image buttons
                HStack(spacing: 20) {
                    Button { showCropper = true }
                      label: { Label("Crop Image", systemImage: "crop") }
                    Button { showCamera = true }
                      label: { Label("New Image", systemImage: "camera") }
                }
                .font(.headline)

                // Recent photos carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "camera")
                                            .font(.title)
                                            .foregroundColor(.gray))
                        }
                        ForEach(recentImages, id: \.self) { img in
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { workingImage = img }
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Photo Library & Files
                HStack(spacing: 20) {
                    Button("Show Photo Library") { showPicker = true }
                    Button("Show Files") { /* TODO */ }
                }
                .font(.body)

                Spacer()
            }
            .padding()
            .navigationBarTitle("Edit Profile Picture", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onCancel() },
                trailing: Button("Save") { onSave(workingImage) }
            )
        }
        // Photo library picker
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $workingImage, isPresented: $showPicker)
        }
        // Camera capture
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(image: $workingImage, isPresented: $showCamera)
        }
        // Cropper
        .fullScreenCover(isPresented: $showCropper) {
            if let toCrop = workingImage {
                SwiftyCropView(
                    imageToCrop: toCrop,
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
                    onCancel: { showCropper = false },
                    onComplete: { cropped in
                        workingImage = cropped
                        showCropper = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            workingImage = originalImage
            loadRecentPhotos()
        }
    }

    private func loadRecentPhotos() {
        // TODO: fetch last 10 UIImages from Photo library
    }
}

enum MaskShape: CaseIterable {
    case circle, square, rectangle
}

struct SwiftyCropView: View {
    private let imageToCrop: UIImage
    private let maskShape: MaskShape
    private let configuration: SwiftyCropConfiguration
    private let onCancel: (() -> Void)?
    private let onComplete: (UIImage?) -> Void

    init(
        imageToCrop: UIImage,
        maskShape: MaskShape,
        configuration: SwiftyCropConfiguration = SwiftyCropConfiguration(),
        onCancel: (() -> Void)? = nil,
        onComplete: @escaping (UIImage?) -> Void
    ) {
        self.imageToCrop = imageToCrop
        self.maskShape = maskShape
        self.configuration = configuration
        self.onCancel = onCancel
        self.onComplete = onComplete
    }

    var body: some View {
        CropView(
            image: imageToCrop,
            maskShape: maskShape,
            configuration: configuration,
            onCancel: onCancel,
            onComplete: onComplete
        )
    }
}

class CropViewModel: ObservableObject {
    private let maskRadius: CGFloat
    private let maxMagnificationScale: CGFloat // The maximum allowed scale factor for image magnification.
    private let maskShape: MaskShape // The shape of the mask used for cropping.
    private let rectAspectRatio: CGFloat // The aspect ratio for rectangular masks.
    
    var imageSizeInView: CGSize = .zero // The size of the image as displayed in the view.
    @Published var maskSize: CGSize = .zero // The size of the mask used for cropping. This is updated based on the mask shape and available space.
    @Published var scale: CGFloat = 1.0 // The current scale factor of the image.
    @Published var lastScale: CGFloat = 1.0 // The previous scale factor of the image.
    @Published var offset: CGSize = .zero // The current offset of the image.
    @Published var lastOffset: CGSize = .zero // The previous offset of the image.
    @Published var angle: Angle = Angle(degrees: 0) // The current rotation angle of the image.
    @Published var lastAngle: Angle = Angle(degrees: 0) // The previous rotation angle of the image.
    
    init(
        maskRadius: CGFloat,
        maxMagnificationScale: CGFloat,
        maskShape: MaskShape,
        rectAspectRatio: CGFloat
    ) {
        self.maskRadius = maskRadius
        self.maxMagnificationScale = maxMagnificationScale
        self.maskShape = maskShape
        self.rectAspectRatio = rectAspectRatio
    }
    
    /**
     Updates the mask size based on the given size and mask shape.
     - Parameter size: The size to base the mask size calculations on.
     */
    private func updateMaskSize(for size: CGSize) {
        switch maskShape {
        case .circle, .square:
            let diameter = min(maskRadius * 2, min(size.width, size.height))
            maskSize = CGSize(width: diameter, height: diameter)
        case .rectangle:
            let maxWidth = min(size.width, maskRadius * 2)
            let maxHeight = min(size.height, maskRadius * 2)
            if maxWidth / maxHeight > rectAspectRatio {
                maskSize = CGSize(width: maxHeight * rectAspectRatio, height: maxHeight)
            } else {
                maskSize = CGSize(width: maxWidth, height: maxWidth / rectAspectRatio)
            }
        }
    }
    
    /**
     Updates the mask dimensions based on the size of the image in the view.
     - Parameter imageSizeInView: The size of the image as displayed in the view.
     */
    func updateMaskDimensions(for imageSizeInView: CGSize) {
        self.imageSizeInView = imageSizeInView
        updateMaskSize(for: imageSizeInView)
    }
    
    /**
     Calculates the maximum allowed offset for dragging the image.
     - Returns: A CGPoint representing the maximum x and y offsets.
     */
    func calculateDragGestureMax() -> CGPoint {
        let xLimit = max(0, ((imageSizeInView.width / 2) * scale) - (maskSize.width / 2))
        let yLimit = max(0, ((imageSizeInView.height / 2) * scale) - (maskSize.height / 2))
        return CGPoint(x: xLimit, y: yLimit)
    }
    
    /**
     Calculates the minimum and maximum allowed scale values for image magnification.
     - Returns: A tuple containing the minimum and maximum scale values.
     */
    func calculateMagnificationGestureMaxValues() -> (CGFloat, CGFloat) {
        let minScale = max(maskSize.width / imageSizeInView.width, maskSize.height / imageSizeInView.height)
        return (minScale, maxMagnificationScale)
    }
    
    /**
     Crops the given image to a rectangle based on the current mask size and position.
     - Parameter image: The UIImage to crop.
     - Returns: A cropped UIImage, or nil if cropping fails.
     */
    func cropToRectangle(_ image: UIImage) -> UIImage? {
        guard let orientedImage = image.correctlyOriented else { return nil }
        
        let cropRect = calculateCropRect(orientedImage)
        
        guard let cgImage = orientedImage.cgImage,
              let result = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Crops the given image to a square based on the current mask size and position.
     - Parameter image: The UIImage to crop.
     - Returns: A cropped UIImage, or nil if cropping fails.
     */
    func cropToSquare(_ image: UIImage) -> UIImage? {
        guard let orientedImage = image.correctlyOriented else { return nil }
        
        let cropRect = calculateCropRect(orientedImage)
        
        guard let cgImage = orientedImage.cgImage,
              let result = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Crops the given image to a circle based on the current mask size and position.
     - Parameter image: The UIImage to crop.
     - Returns: A cropped UIImage, or nil if cropping fails.
     */
    func cropToCircle(_ image: UIImage) -> UIImage? {
        guard let orientedImage = image.correctlyOriented else { return nil }
        
        let cropRect = calculateCropRect(orientedImage)
        
        let imageRendererFormat = orientedImage.imageRendererFormat
        imageRendererFormat.opaque = false
        
        let circleCroppedImage = UIGraphicsImageRenderer(
            size: cropRect.size,
            format: imageRendererFormat).image { _ in
                let drawRect = CGRect(origin: .zero, size: cropRect.size)
                UIBezierPath(ovalIn: drawRect).addClip()
                let drawImageRect = CGRect(
                    origin: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y),
                    size: orientedImage.size
                )
                orientedImage.draw(in: drawImageRect)
            }
        
        return circleCroppedImage
    }
    
    /**
     Rotates the given image by the specified angle.
     - Parameter image: The UIImage to rotate.
     - Parameter angle: The Angle to rotate the image by.
     - Returns: A rotated UIImage, or nil if rotation fails.
     */
    func rotate(_ image: UIImage, _ angle: Angle) -> UIImage? {
        guard let orientedImage = image.correctlyOriented,
              let cgImage = orientedImage.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter.straightenFilter(image: ciImage, radians: angle.radians),
              let output = filter.outputImage else { return nil }
        
        let context = CIContext()
        guard let result = context.createCGImage(output, from: output.extent) else { return nil }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Calculates the rectangle to use for cropping the image based on the current mask size, scale, and offset.
     - Parameter orientedImage: The correctly oriented UIImage to calculate the crop rect for.
     - Returns: A CGRect representing the area to crop from the original image.
     */
    private func calculateCropRect(_ orientedImage: UIImage) -> CGRect {
        let factor = min(
            (orientedImage.size.width / imageSizeInView.width),
            (orientedImage.size.height / imageSizeInView.height)
        )
        let centerInOriginalImage = CGPoint(
            x: orientedImage.size.width / 2,
            y: orientedImage.size.height / 2
        )
        
        let cropSizeInOriginalImage = CGSize(
            width: (maskSize.width * factor) / scale,
            height: (maskSize.height * factor) / scale
        )
        
        let offsetX = offset.width * factor / scale
        let offsetY = offset.height * factor / scale
        
        let cropRectX = (centerInOriginalImage.x - cropSizeInOriginalImage.width / 2) - offsetX
        let cropRectY = (centerInOriginalImage.y - cropSizeInOriginalImage.height / 2) - offsetY
        
        return CGRect(
            origin: CGPoint(x: cropRectX, y: cropRectY),
            size: cropSizeInOriginalImage
        )
    }
}

private extension UIImage {
    /**
     A UIImage instance with corrected orientation.
     If the instance's orientation is already `.up`, it simply returns the original.
     - Returns: An optional UIImage that represents the correctly oriented image.
     */
    var correctlyOriented: UIImage? {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}

private extension CIFilter {
    /**
     Creates the straighten filter.
     - Parameters:
     - inputImage: The CIImage to use as an input image
     - radians: An angle in radians
     - Returns: A generated CIFilter.
     */
    static func straightenFilter(image: CIImage, radians: Double) -> CIFilter? {
        let angle: Double = radians != 0 ? -radians : 0
        guard let filter = CIFilter(name: "CIStraightenFilter") else {
            return nil
        }
        filter.setDefaults()
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(angle, forKey: kCIInputAngleKey)
        return filter
    }
}

struct CropView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: CropViewModel
  
  @State private var isCropping: Bool = false
  
  private let image: UIImage
  private let maskShape: MaskShape
  private let configuration: SwiftyCropConfiguration
  private let onCancel: (() -> Void)?
  private let onComplete: (UIImage?) -> Void
  private let localizableTableName: String
  
  init(
    image: UIImage,
    maskShape: MaskShape,
    configuration: SwiftyCropConfiguration,
    onCancel: (() -> Void)? = nil,
    onComplete: @escaping (UIImage?) -> Void
  ) {
    self.image = image
    self.maskShape = maskShape
    self.configuration = configuration
    self.onCancel = onCancel
    self.onComplete = onComplete
    _viewModel = StateObject(
      wrappedValue: CropViewModel(
        maskRadius: configuration.maskRadius,
        maxMagnificationScale: configuration.maxMagnificationScale,
        maskShape: maskShape,
        rectAspectRatio: configuration.rectAspectRatio
      )
    )
    localizableTableName = "Localizable"
  }
  
  // MARK: - Body
  var body: some View {
#if compiler(>=6.2) // Use this to prevent compiling of unavailable iOS 26 APIs
    if configuration.usesLiquidGlassDesign,
       #available(iOS 26, visionOS 26.0, *) {
      buildLiquidGlassBody(configuration: configuration)
    } else {
      buildLegacyBody(configuration: configuration)
    }
#else
    buildLegacyBody(configuration: configuration)
#endif
  }
  
  @available(iOS 26, visionOS 26.0, *)
  private func buildLiquidGlassBody(configuration: SwiftyCropConfiguration) -> some View {
    ZStack {
      VStack {
        ToolbarView(
          viewModel: viewModel,
          configuration: configuration,
          dismiss: {
            onCancel?()
            dismiss()
          }
        ) {
          await MainActor.run {
            isCropping = true
          }
          let result = cropImage()
          await MainActor.run {
            onComplete(result)
            dismiss()
            isCropping = false
          }
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .zIndex(1)
        
        Spacer()
        
        cropImageView
        
        Spacer()
      }
      .background(configuration.colors.background)
      
      if isCropping {
        ProgressLayer(configuration: configuration, localizableTableName: localizableTableName)
      }
    }
  }
  
  private func buildLegacyBody(configuration: SwiftyCropConfiguration) -> some View {
    ZStack {
      VStack {
        Legacy_InteractionInstructionsView(configuration: configuration, localizableTableName: localizableTableName)
          .padding(.top, 50)
          .zIndex(1)
        
        if configuration.rotateImageWithButtons {
          Legacy_RotateButtonsView(viewModel: viewModel, configuration: configuration)
        }
        
        Spacer()
        
        cropImageView
        
        Spacer()
        
        Legacy_ButtonsView(
          configuration: configuration,
          localizableTableName: localizableTableName,
          dismiss: {
            onCancel?()
            dismiss()
          }
        ) {
          await MainActor.run {
            isCropping = true
          }
          let result = cropImage()
          await MainActor.run {
            onComplete(result)
            dismiss()
            isCropping = false
          }
        }
      }
      .background(configuration.colors.background)
      
      if isCropping {
        Legacy_ProgressLayer(configuration: configuration, localizableTableName: localizableTableName)
      }
    }
  }
  
  // MARK: - Gestures
  private var magnificationGesture: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        let sensitivity: CGFloat = 0.1 * configuration.zoomSensitivity
        let scaledValue = (value.magnitude - 1) * sensitivity + 1
        
        let maxScaleValues = viewModel.calculateMagnificationGestureMaxValues()
        viewModel.scale = min(max(scaledValue * viewModel.lastScale, maxScaleValues.0), maxScaleValues.1)
        
        updateOffset()
      }
      .onEnded { _ in
        viewModel.lastScale = viewModel.scale
        viewModel.lastOffset = viewModel.offset
      }
  }
  
  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        let maxOffsetPoint = viewModel.calculateDragGestureMax()
        let newX = min(
          max(value.translation.width + viewModel.lastOffset.width, -maxOffsetPoint.x),
          maxOffsetPoint.x
        )
        let newY = min(
          max(value.translation.height + viewModel.lastOffset.height, -maxOffsetPoint.y),
          maxOffsetPoint.y
        )
        viewModel.offset = CGSize(width: newX, height: newY)
      }
      .onEnded { _ in
        viewModel.lastOffset = viewModel.offset
      }
  }
  
  private var rotationGesture: some Gesture {
    RotationGesture()
      .onChanged { value in
        viewModel.angle = viewModel.lastAngle + value
      }
      .onEnded { _ in
        viewModel.lastAngle = viewModel.angle
      }
  }
  
  // MARK: - UI Components
  private var cropImageView: some View {
    ZStack {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .rotationEffect(viewModel.angle)
        .scaleEffect(viewModel.scale)
        .offset(viewModel.offset)
        .opacity(0.5)
        .overlay(
          GeometryReader { geometry in
            Color.clear
              .onAppear {
                viewModel.updateMaskDimensions(for: geometry.size)
              }
          }
        )
      
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .rotationEffect(viewModel.angle)
        .scaleEffect(viewModel.scale)
        .offset(viewModel.offset)
        .mask(
          MaskShapeView(maskShape: maskShape)
            .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .simultaneousGesture(magnificationGesture)
    .simultaneousGesture(dragGesture)
    .simultaneousGesture(configuration.rotateImage ? rotationGesture : nil)
  }
  
  // MARK: - Helpers
  private func updateOffset() {
    let maxOffsetPoint = viewModel.calculateDragGestureMax()
    let newX = min(max(viewModel.offset.width, -maxOffsetPoint.x), maxOffsetPoint.x)
    let newY = min(max(viewModel.offset.height, -maxOffsetPoint.y), maxOffsetPoint.y)
    viewModel.offset = CGSize(width: newX, height: newY)
    viewModel.lastOffset = viewModel.offset
  }
  
  private func cropImage() -> UIImage? {
    var editedImage: UIImage = image
    if configuration.rotateImage || configuration.rotateImageWithButtons {
      if let rotatedImage: UIImage = viewModel.rotate(
        editedImage,
        viewModel.lastAngle
      ) {
        editedImage = rotatedImage
      }
    }
    if configuration.cropImageCircular && maskShape == .circle {
      return viewModel.cropToCircle(editedImage)
    } else if maskShape == .rectangle {
      return viewModel.cropToRectangle(editedImage)
    } else {
      return viewModel.cropToSquare(editedImage)
    }
  }
  
  // MARK: - Mask Shape View
  private struct MaskShapeView: View {
    let maskShape: MaskShape
    
    var body: some View {
      Group {
        switch maskShape {
        case .circle:
          Circle()
        case .square, .rectangle:
          Rectangle()
        }
      }
    }
  }
}

struct SwiftyCropConfiguration {
  let maxMagnificationScale: CGFloat
  let maskRadius: CGFloat
  let cropImageCircular: Bool
  let rotateImage: Bool
  let rotateImageWithButtons: Bool
  let usesLiquidGlassDesign: Bool
  let zoomSensitivity: CGFloat
  let rectAspectRatio: CGFloat
  let texts: Texts
  let fonts: Fonts
  let colors: Colors
  
  /// Creates a new instance of `Texts` that are used in the cropping view.
  /// - Note: The new LiquidGlass design does not use texts anymore but icon buttons. Setting this when Liquid Glass is enabled will not have any effect.
  ///
  /// - Parameters:
  ///   - cancelButton: The text for the cancel button. Defaults to `nil`, using localized values from the app.
  ///   - interactionInstructions: The text for the interaction instructions. Defaults to `nil`, using localized values from the app.
  ///   - saveButton: The text for the save button. Defaults to `nil`, using localized values from the app.
  ///   - progressLayerText: The text for the progress view indicating that cropping occurs. Defaults to `nil`, using localized values from the app.
  struct Texts {
    init(
      // We cannot use the localized values here because module access is not given in init
      cancelButton: String? = nil,
      interactionInstructions: String? = nil,
      saveButton: String? = nil,
      progressLayerText: String? = nil
    ) {
      self.cancelButton = cancelButton
      self.interactionInstructions = interactionInstructions
      self.saveButton = saveButton
      self.progressLayerText = progressLayerText
    }
    
    let cancelButton: String?
    let interactionInstructions: String?
    let saveButton: String?
        let progressLayerText: String?
  }
  
  /// Creates a new instance of `Fonts` that are used in the cropping view texts.
  /// - Note: The new LiquidGlass design does not use texts anymore but icon buttons. Setting this when Liquid Glass is enabled will not have any effect.
  ///
  /// - Parameters:
  ///   - cancelButton: The font for the cancel button text. Defaults to `nil`, using default values.
  ///   - interactionInstruction: The font for the interaction instruction text. Defaults to `nil`, using default values.
  ///   - saveButton: The font for the save button text. Defaults to `nil`, using default values.
  struct Fonts {
    init(
      cancelButton: Font? = nil,
      interactionInstructions: Font? = nil,
      saveButton: Font? = nil
    ) {
      self.cancelButton = cancelButton
      self.interactionInstructions = interactionInstructions ?? .system(size: 16, weight: .regular)
      self.saveButton = saveButton
    }
    
    let cancelButton: Font?
    let interactionInstructions: Font
    let saveButton: Font?
  }
  
  /// Creates a new instance of `Colors` that are used in the cropping view.
  /// - Note: Certain properties have different effects whether Liquid Glass is enabled or not.
  ///
  /// - Parameters:
  ///   - cancelButton: The color for the cancel button text. If Liquid Glass is enabled, will be the color of the icon. Defaults to `.white`.
  ///   - cancelButtonBackground: If Liquid Glass is enabled, will be the background color of the button. Otherwise has no effect. Defaults to `.clear`.
  ///   - interactionInstructions: The color for the interaction instructions text. Defaults to `.white`.
  ///   - rotateButton: The color for the rotate button text. If Liquid Glass is enabled, will be the color of the icon. Defaults to `.white`.
  ///   - rotateButtonBackground: If Liquid Glass is enabled, will be the background color of the button. Otherwise has no effect. Defaults to `.clear`.
  ///   - resetRotationButton: The color for the reset rotation button text. If Liquid Glass is enabled, will be the color of the icon. Defaults to `.white`.
  ///   - resetRotationButtonBackground: If Liquid Glass is enabled, will be the background color of the button. Otherwise has no effect. Defaults to `.clear`.
  ///   - saveButton: The color for the save button text. If Liquid Glass is enabled, will be the color of the icon. Defaults to `.white`.
  ///   - saveButtonBackground: If Liquid Glass is enabled, will be the background color of the button. Otherwise has no effect. Defaults to `.yellow`.
  ///   - background: The background color of the entire cropping view. Defaults to `.black`.
  struct Colors {
    init(
      cancelButton: Color = .white,
      cancelButtonBackground: Color = .clear,
      interactionInstructions: Color = .white,
      rotateButton: Color = .white,
      rotateButtonBackground: Color = .clear,
      resetRotationButton: Color = .white,
      resetRotationButtonBackground: Color = .clear,
      saveButton: Color = .white,
      saveButtonBackground: Color = .yellow,
      background: Color = .black
    ) {
      self.cancelButton = cancelButton
      self.cancelButtonBackground = cancelButtonBackground
      self.interactionInstructions = interactionInstructions
      self.rotateButton = rotateButton
      self.rotateButtonBackground = rotateButtonBackground
      self.resetRotationButton = resetRotationButton
      self.resetRotationButtonBackground = resetRotationButtonBackground
      self.saveButton = saveButton
      self.saveButtonBackground = saveButtonBackground
      self.background = background
    }
    
    let cancelButton: Color
    let cancelButtonBackground: Color
    let interactionInstructions: Color
    let rotateButton: Color
    let rotateButtonBackground: Color
    let resetRotationButton: Color
    let resetRotationButtonBackground: Color
    let saveButton: Color
    let saveButtonBackground: Color
    let background: Color
  }
  
  /// Creates a new instance of `SwiftyCropConfiguration`.
  ///
  /// - Parameters:
  ///   - maxMagnificationScale: The maximum scale factor that the image can be magnified while cropping. Defaults to `4.0`.
  ///
  ///   - maskRadius: The radius of the mask used for cropping. Defaults to `130`.
  ///
  ///   - cropImageCircular: Option to enable circular crop. Defaults to `false`.
  ///
  ///   - rotateImage: Option to rotate image. Defaults to `false`.
  ///
  ///   - rotateImageWithButtons: Option to show rotation buttons. Defaults to `false`.
  ///
  ///   - usesLiquidGlassDesign: (Beta) apply the all new liquid glass design. Defaults to `false`. This might be changed in the future.
  ///
  ///   - zoomSensitivity: Sensitivity when zooming. Default is `1.0`. Decrease to increase sensitivity.
  ///
  ///   - rectAspectRatio: The aspect ratio to use when a `.rectangle` mask shape is used. Defaults to `4:3`.
  ///
  ///   - texts: `Texts` object when using custom texts for the cropping view.
  ///
  ///   - fonts: `Fonts` object when using custom fonts for the cropping view. Defaults to system.
  ///
  ///   - colors: `Colors` object when using custom colors for the cropping view.
  init(
    maxMagnificationScale: CGFloat = 4.0,
    maskRadius: CGFloat = 130,
    cropImageCircular: Bool = false,
    rotateImage: Bool = false,
    rotateImageWithButtons: Bool = false,
    usesLiquidGlassDesign: Bool = false,
    zoomSensitivity: CGFloat = 1,
    rectAspectRatio: CGFloat = 4/3,
    texts: Texts = Texts(),
    fonts: Fonts = Fonts(),
    colors: Colors = Colors()
  ) {
    self.maxMagnificationScale = maxMagnificationScale
    self.maskRadius = maskRadius
    self.cropImageCircular = cropImageCircular
    self.rotateImage = rotateImage
    self.rotateImageWithButtons = rotateImageWithButtons
    self.usesLiquidGlassDesign = usesLiquidGlassDesign
    self.zoomSensitivity = zoomSensitivity
    self.rectAspectRatio = rectAspectRatio
    self.texts = texts
    self.fonts = fonts
    self.colors = colors
  }
}

struct ToolbarView: View {
  @ObservedObject var viewModel: CropViewModel
  let configuration: SwiftyCropConfiguration
  let dismiss: () -> Void
  let onComplete: () async -> Void
  @State private var isCropping = false
  
  var body: some View {
#if compiler(>=6.2) // Use this to prevent compiling of unavailable iOS 26 APIs
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .foregroundStyle(configuration.colors.cancelButton)
        
          .fontWeight(.semibold)
      }
      .padding()
#if !os(visionOS)
      .glassEffect(.regular.tint(configuration.colors.cancelButtonBackground))
#endif

      Spacer()
      
      if configuration.rotateImageWithButtons {
        Button {
          // The reset button should only reset by the amount needed, prevents rotating the image back multiple times if it was rotated multiple times
          let numberOfFullCircles = Int(viewModel.angle.degrees / 360)
          let newValue = Double(numberOfFullCircles * 360)
          withAnimation {
            viewModel.angle = Angle(degrees: newValue)
            viewModel.lastAngle = viewModel.angle
          }
        } label: {
          Image(systemName: "arrow.uturn.backward.circle")
            .foregroundStyle(configuration.colors.resetRotationButton)
            .fontWeight(.semibold)
        }
        .padding()
#if !os(visionOS)
        .glassEffect(.regular.tint(configuration.colors.resetRotationButtonBackground))
#endif
        .opacity(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0 ? 0.7 : 1)
        .disabled(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0)
        
        HStack {
          Button {
            withAnimation {
              viewModel.angle.degrees -= 90
              viewModel.lastAngle = viewModel.angle
            }
          } label: {
            Image(systemName: "rotate.left")
              .foregroundStyle(configuration.colors.rotateButton)
              .fontWeight(.semibold)
          }
          .padding()
          
          Button {
            withAnimation {
              viewModel.angle.degrees += 90
              viewModel.lastAngle = viewModel.angle
            }
          } label: {
            Image(systemName: "rotate.right")
              .foregroundStyle(configuration.colors.rotateButton)
              .fontWeight(.semibold)
          }
          .padding()
        }
#if !os(visionOS)
        .glassEffect(.regular.tint(configuration.colors.rotateButtonBackground))
#endif
      }
      
      Spacer()
      
      Button {
        Task {
          isCropping = true
          defer { isCropping = false }
          await onComplete()
        }
      } label: {
        Image(systemName: "checkmark")
          .fontWeight(.semibold)
          .foregroundStyle(configuration.colors.saveButton)
      }
      .padding()
      .disabled(isCropping)
#if !os(visionOS)
      .glassEffect(.regular.tint(configuration.colors.saveButtonBackground))
#endif
    }
    .frame(maxWidth: .infinity)
#else
    VStack {
      Text("iOS 26 is not supported. Adjust the simulator or your Xcode version.")
    }
    .border(.red)
#endif
  }
}

struct ProgressLayer: View {
  let configuration: SwiftyCropConfiguration
  let localizableTableName: String
  @State private var showAlert = true
  
  var body: some View {
#if compiler(>=6.2) // Use this to prevent compiling of unavailable iOS 26 APIs
    ZStack {
      configuration.colors.background.opacity(0.4)
        .ignoresSafeArea()
      
      VStack(alignment: .center, spacing: 20) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: configuration.colors.interactionInstructions))
          .scaleEffect(1.2)
        
        Text(
          configuration.texts.progressLayerText ??
          NSLocalizedString("processing_label", tableName: localizableTableName, bundle: .main, comment: "")
        )
        .font(.body)
        .foregroundColor(configuration.colors.interactionInstructions)
      }
      .padding(25)
#if !os(visionOS)
      .glassEffect(
        .regular.tint(configuration.colors.background.opacity(0.8)),
        in: .rect(cornerRadius: 12)
      )
#endif
      .padding(.vertical, 5)
      .padding(.horizontal, 20)
    }
    .transition(.opacity)
#else
    VStack {
      Text("iOS 26 is not supported. Adjust the simulator or your Xcode version.")
    }
    .border(.red)
#endif
  }
}

struct Legacy_ButtonsView: View {
    let configuration: SwiftyCropConfiguration
    let localizableTableName: String
    let dismiss: () -> Void
    let onComplete: () async -> Void
    @State private var isCropping = false
  
  var body: some View {
      HStack {
          Button {
              dismiss()
          } label: {
              Text(
                  configuration.texts.cancelButton ??
                  NSLocalizedString("cancel_button", tableName: localizableTableName, bundle: .main, comment: "")
              )
              .padding()
              .font(configuration.fonts.cancelButton)
              .foregroundColor(configuration.colors.cancelButton)
          }
          .padding()
          .disabled(isCropping)
          
          Spacer()
          
          Button {
              Task {
                  isCropping = true
                  await onComplete()
                  isCropping = false
              }
          } label: {
              Text(
                  configuration.texts.saveButton ??
                  NSLocalizedString("save_button", tableName: localizableTableName, bundle: .main, comment: "")
              )
              .padding()
              .font(configuration.fonts.saveButton)
              .foregroundColor(configuration.colors.saveButton)
          }
          .padding()
          .disabled(isCropping)
      }
      .frame(maxWidth: .infinity, alignment: .bottom)
  }
}

struct Legacy_InteractionInstructionsView: View {
  let configuration: SwiftyCropConfiguration
  let localizableTableName: String
  
  var body: some View {
    Text(
      configuration.texts.interactionInstructions ??
      NSLocalizedString("interaction_instructions", tableName: localizableTableName, bundle: .main, comment: "")
    )
    .font(configuration.fonts.interactionInstructions)
    .foregroundColor(configuration.colors.interactionInstructions)
  }
}

struct Legacy_ProgressLayer: View {
  let configuration: SwiftyCropConfiguration
  let localizableTableName: String
  
  var body: some View {
    ZStack {
      configuration.colors.background.opacity(0.4)
        .ignoresSafeArea()
      
      VStack(alignment: .center, spacing: 5) {
        
        Spacer(minLength: 35)
        
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: configuration.colors.interactionInstructions))
          .scaleEffect(1.2)
        
        Spacer()
        
        Text(
          configuration.texts.progressLayerText ??
          NSLocalizedString("processing_label", tableName: localizableTableName, bundle: .main, comment: "")
        )
        .font(.body)
        .foregroundColor(configuration.colors.interactionInstructions)
        .padding(.bottom, 12)
        
      }
      .frame(width: 120, height: 110)
      .background(configuration.colors.background.opacity(0.8))
      .cornerRadius(12)
      .padding(.vertical, 5)
      .padding(.horizontal, 15)
    }
    .transition(.opacity)
  }
}

struct Legacy_RotateButtonsView: View {
    @ObservedObject var viewModel: CropViewModel
    let configuration: SwiftyCropConfiguration
    
    var body: some View {
        HStack {
            Button {
                withAnimation {
                    viewModel.angle.degrees -= 90
                    viewModel.lastAngle = viewModel.angle
                }
            } label: {
                Image(systemName: "rotate.left")
                    .foregroundStyle(configuration.colors.rotateButton)
                    .padding()
            }
            .padding()
            
            Spacer()
            
            Button {
                // The reset button should only reset by the amount needed, prevents rotating the image back multiple times if it was rotated multiple times
                let numberOfFullCircles = Int(viewModel.angle.degrees / 360)
                let newValue = Double(numberOfFullCircles * 360)
                withAnimation {
                    viewModel.angle = Angle(degrees: newValue)
                    viewModel.lastAngle = viewModel.angle
                }
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(configuration.colors.resetRotationButton)
                    .opacity(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0 ? 0.3 : 1)
                    .padding()
            }
            .padding()
            .disabled(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0)
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.angle.degrees += 90
                    viewModel.lastAngle = viewModel.angle
                }
            } label: {
                Image(systemName: "rotate.right")
                    .foregroundStyle(configuration.colors.rotateButton)
                    .padding()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}
