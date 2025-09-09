//
//  CreateNewRanko.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI
import Combine
import FirebaseAnalytics

// MARK: - Main CreateNewRanko View
struct CreateNewRanko2: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var searchFocus: Bool
    @State private var rankoName: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Input Fields
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ranko Name").foregroundColor(.secondary)
                            Text("*").foregroundColor(.red)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 1)
                            TextField("Top 15 Countries", text: $rankoName)
                                .onChange(of: rankoName) { _, newValue in
                                    if newValue.count > 50 {
                                        rankoName = String(newValue.prefix(50))
                                    }
                                }
                                .autocorrectionDisabled(true)
                                .foregroundStyle(.gray)
                                .fontWeight(.semibold)
                                .focused($searchFocus)
                            Spacer()
                            Text("\(rankoName.count)/50")
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
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
            }
        }
        .presentationBackground(Color(hex: 0xFFFFFF))
    }
}

struct CreateNewRanko: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.keyboardHeight) var keyboardHeight
    @FocusState private var searchFocus: Bool
    @StateObject private var user_data = UserInformation.shared

    @State private var rankoName: String = ""
    @State private var text = ""

    @State private var sheetHeight: CGFloat = 450
    @State private var didLock = false
    @State private var didScheduleOpen = false

    // tweak these to your liking
    private let closeEps: CGFloat = 0.5       // treat ≤ this as "closed"
    private let openDetent: CGFloat = 140     // detent while keyboard is open
    private let closedPad: CGFloat = 80       // saved height + this when closed

    var body: some View {
        ScrollView {
            VStack {
                TextField("Hello World", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocus)

                Color.blue.opacity(0.5)
                    .frame(height: keyboardHeight > 0 ? keyboardHeight : CGFloat(user_data.deviceKeyboardHeight))
            }
            .ignoresSafeArea()
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard) // keeping this as requested
        .onAppear {
            searchFocus = true
            // start from saved height if available
            if user_data.deviceKeyboardHeight >= 280 {
                sheetHeight = CGFloat(user_data.deviceKeyboardHeight) + closedPad
            } else {
                sheetHeight = 450
            }
        }
        .onChange(of: keyboardHeight) { old, new in
            // ===== 1) if not locked yet, try to lock when we hit a whole number >= 280 =====
            if !didLock {
                guard new >= 280, new.isWhole() else { return }
                let whole = new.roundedInt
                didLock = true
                user_data.deviceKeyboardHeight = whole
                print("locked keyboard height →", whole)

                return
            }
            
            if didLock && new >= closeEps {
                sheetHeight = 80
            }

            // ===== 2) already locked: when keyboard closes (~0), move to saved+80 =====
            if new <= closeEps {
                let target = CGFloat(user_data.deviceKeyboardHeight) + closedPad
                // hop to next runloop & de-dupe to avoid "updates per frame" warning
                DispatchQueue.main.async {
                    withAnimation(.spring(duration: 0.5)) {
                        if abs(self.sheetHeight - target) > 0.5 {
                            self.sheetHeight = target
                        }
                    }
                }
            }
        }
        .transaction { trans in
            trans.disablesAnimations = false
            trans.animation = .easeInOut(duration: 1)
        }
        .presentationDetents([.height(sheetHeight)])
        .animation(.easeInOut(duration: 1), value: sheetHeight)
    }
}

// --- helpers you already had ---
private extension CGFloat {
    func isWhole(eps: CGFloat = 0.5) -> Bool { abs(self - self.rounded()) < eps }
    var roundedInt: Int { Int(self.rounded()) }
}


private struct KeyboardHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
extension EnvironmentValues {
    var keyboardHeight: CGFloat {
        get { self[KeyboardHeightEnvironmentKey.self] }
        set { self[KeyboardHeightEnvironmentKey.self] = newValue }
    }
}
struct KeyboardHeightEnvironmentValue: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .environment(\.keyboardHeight, keyboardHeight)
            .animation(.interpolatingSpring(mass: 3, stiffness: 1000, damping: 500, initialVelocity: 0),
                       value: keyboardHeight)
            .background {
                GeometryReader { keyboardProxy in
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: keyboardProxy.safeAreaInsets.bottom - proxy.safeAreaInsets.bottom) { _, newValue in
                                DispatchQueue.main.async {
                                    if keyboardHeight != newValue {
                                        keyboardHeight = newValue
                                    }
                                }
                            }
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
    }
}
public extension View {
    func keyboardHeightEnvironmentValue() -> some View {
        #if os(iOS)
        modifier(KeyboardHeightEnvironmentValue())
        #else
        environment(\.keyboardHeight, 0)
        #endif
    }
}


struct CreateNewRanko1: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var searchFocus: Bool
    
    // Input field state.
    @State private var rankoName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var categorySelected = false
    
    // Category/Tag picker state.
    @State private var showCategoryPicker: Bool = false
    @State private var selectedCategoryChip: CategoryChip? = nil
    
    // Layout picker state.
    @State private var showLayoutPicker: Bool = false
    @State private var selectedLayout: LayoutTemplate? = nil
    
    // Shake animation state variables.
    @State private var rankoNameShake: CGFloat = 0
    @State private var categoryShake: CGFloat = 0
    @State private var layoutShake: CGFloat = 0
    
    // Show list layouts
    @State private var showDefaultList: Bool = false
    @State private var showGroupList: Bool = false
    @State private var showTierList: Bool = false
    
    @State private var fullScreenListDestination: ListDestination?
    @State private var keyboardHeight: CGFloat = 0
    @State private var vStackHeightName: CGFloat = 0
    @State private var vStackHeightDescription: CGFloat = 0
    @State private var vStackHeightCategoryPrivacy: CGFloat = 0
    @State private var vStackHeightLayout: CGFloat = 0
    @State private var vStackHeightButtons: CGFloat = 0
    @State private var createNewRankoSheetHeight: CGFloat = 375.0
    private var vStackCombinedHeights: String {
        "\(vStackHeightName)-\(vStackHeightDescription)-\(vStackHeightCategoryPrivacy)-\(vStackHeightLayout)-\(vStackHeightButtons)"
    }
    
    // Computed property to check if the form is valid.
    var isValid: Bool {
        (!rankoName.isEmpty && (selectedCategoryChip != nil)) && selectedLayout != nil
    }
    
    var body: some View {
        ZStack(alignment: .centerFirstTextBaseline) {
            Color(hex: 0xFFFFFF)
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Input Fields
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ranko Name").foregroundColor(.secondary)
                            Text("*").foregroundColor(.red)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 1)
                            TextField("Top 15 Countries", text: $rankoName)
                                .onChange(of: rankoName) { _, newValue in
                                    if newValue.count > 50 {
                                        rankoName = String(newValue.prefix(50))
                                    }
                                }
                                .autocorrectionDisabled(true)
                                .foregroundStyle(.gray)
                                .fontWeight(.semibold)
                                .focused($searchFocus)
                                .onAppear() {
                                    searchFocus = true
                                }
                            Spacer()
                            Text("\(rankoName.count)/50")
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
                    .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: rankoNameShake))
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .ignoresSafeArea()
                                .onAppear {
                                    // Capture the height when the view appears
                                    vStackHeightName = geometry.size.height
                                }
                                .onChange(of: vStackHeightName) { _, h in
                                    print("RankoName VStack Height:", h)
                                    
                                }
                        }
                    )
                    .ignoresSafeArea()
                    
                    // Description Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description, if any")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                            .padding(.leading, 6)
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                                .foregroundColor(.gray)
                                .padding(.trailing, 3)
                            TextField("Description", text: $description)
                                .onChange(of: description) { _, newValue in
                                    if newValue.count > 100 {
                                        description = String(newValue.prefix(100))
                                    }
                                }
                                .foregroundStyle(.gray)
                                .autocorrectionDisabled(true)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(description.count)/100")
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
                    .padding(.horizontal, 24)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .ignoresSafeArea()
                                .onAppear {
                                    // Capture the height when the view appears
                                    vStackHeightDescription = geometry.size.height
                                }
                                .onChange(of: vStackHeightDescription) { _, h in
                                    print("Description VStack Height:", h)
                                    
                                }
                        }
                    )
                    .ignoresSafeArea()
                    
                    // MARK: - Category and Privacy Section
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Category").foregroundColor(.secondary)
                                Text("*").foregroundColor(.red)
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.leading, 6)
                            Button {
                                showCategoryPicker = true
                            } label: {
                                if let chip = selectedCategoryChip {
                                    HStack {
                                        Image(systemName: chip.icon)
                                            .foregroundColor(.white)
                                        Text(chip.name)
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                    .padding(8)
                                    .foregroundColor(isPrivate ? .orange : categoryChipIconColors[chip.name] ?? Color.gray)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                    )
                                } else {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.gray)
                                        Text("Select Category")
                                            .foregroundColor(.gray.opacity(0.6))
                                            .fontWeight(.bold)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                            .fontWeight(.bold)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                            }
                            .foregroundStyle(
                                categorySelected
                                ? Color.gray.opacity(0.08).gradient
                                : (selectedCategoryChip != nil
                                   ? (categoryChipIconColors[selectedCategoryChip!.name] ?? Color.gray).gradient
                                   : Color.gray.opacity(0.08).gradient)
                            )
                            .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: categoryShake))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Private")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                                .padding(.leading, 6)
                            Toggle(isOn: $isPrivate) {}
                                .tint(.orange)
                                .padding(.top, 6)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .layoutPriority(1)
                    }
                    .padding(.horizontal, 24)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .ignoresSafeArea()
                                .onAppear {
                                    // Capture the height when the view appears
                                    vStackHeightCategoryPrivacy = geometry.size.height
                                }
                                .onChange(of: vStackHeightCategoryPrivacy) { _, h in
                                    print("Category & Privacy VStack Height:", h)
                                    
                                }
                        }
                    )
                    .ignoresSafeArea()
                    
                    // MARK: - Layout Picker Section
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Layout").foregroundColor(.secondary)
                            Text("*").foregroundColor(.red)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                        Button {
                            showLayoutPicker = true
                        } label: {
                            HStack {
                                if let layout = selectedLayout {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .foregroundColor(.gray)
                                    Text(layout.name)
                                        .foregroundColor(.black.opacity(0.65))
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .foregroundColor(.gray)
                                    Text("Select Layout")
                                        .foregroundColor(.gray.opacity(0.6))
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.08))
                            )
                        }
                    }
                    .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: layoutShake))
                    .padding(.bottom, 5)
                    .padding(.horizontal, 24)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .ignoresSafeArea()
                                .onAppear {
                                    // Capture the height when the view appears
                                    vStackHeightLayout = geometry.size.height
                                }
                                .onChange(of: vStackHeightLayout) { _, h in
                                    print("Layout VStack Height:", h)
                                    
                                }
                        }
                    )
                    .ignoresSafeArea()
                    
                    // MARK: - Bottom Buttons
                    ZStack {
#if !targetEnvironment(simulator)
                        VStack {
                            HStack(spacing: 12) {
                                Button {
                                    let layout = selectedLayout
                                    
                                    if isValid {
                                        // Log analytics event
                                        Analytics.logEvent("ranko_published", parameters: [
                                            "ranko_name": rankoName,
                                            "is_private": isPrivate,
                                            "category": selectedCategoryChip?.name ?? "unknown",
                                            "layout": layout!.name,
                                        ])
                                        if layout?.name == "Default List" {
                                            print("Default List Opening...")
                                            fullScreenListDestination = .defaultList
                                        }
                                        if layout?.name == "Group List" {
                                            print("Group List Opening...")
                                            fullScreenListDestination = .groupList
                                        }
                                        if layout?.name == "Tier List" {
                                            print("Tier List Opening...")
                                            showTierList.toggle()
                                        }
                                    } else {
                                        if rankoName.isEmpty {
                                            withAnimation { rankoNameShake += 1 }
                                        }
                                        if selectedCategoryChip == nil {
                                            withAnimation { categoryShake += 1 }
                                        }
                                        if selectedLayout == nil {
                                            withAnimation { layoutShake += 1 }
                                        }
                                    }
                                } label: {
                                    Text("Create Ranko")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 1.2).onEnded(({ _ in
                                        if !isValid {
                                            let layout = selectedLayout
                                            // Sample data for testing
                                            rankoName = "Top 10 Snacks"
                                            description = "My all-time favorite snacks ranked."
                                            selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                                            selectedLayout = LayoutTemplate(name: "Default List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                                        }
                                    }))
                                )
                                .opacity(isValid ? 1 : 0.6)
                                
                                Button {
                                    print("Cancel tapped")
                                    dismiss()
                                } label: {
                                    Text("Cancel")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
#endif
                        
#if targetEnvironment(simulator)
                        VStack {
                            HStack(spacing: 12) {
                                Button {
                                    let layout = selectedLayout
                                    
                                    if isValid {
                                        // Log analytics event
                                        Analytics.logEvent("ranko_published", parameters: [
                                            "ranko_name": rankoName,
                                            "is_private": isPrivate,
                                            "category": selectedCategoryChip?.name ?? "unknown",
                                            "layout": layout!.name,
                                        ])
                                        if layout?.name == "Default List" {
                                            print("Default List Opening...")
                                            fullScreenListDestination = .defaultList
                                        }
                                        if layout?.name == "Group List" {
                                            print("Group List Opening...")
                                            fullScreenListDestination = .groupList
                                        }
                                        if layout?.name == "Tier List" {
                                            print("Tier List Opening...")
                                            showTierList.toggle()
                                        }
                                    } else {
                                        if rankoName.isEmpty {
                                            withAnimation { rankoNameShake += 1 }
                                        }
                                        if selectedCategoryChip == nil {
                                            withAnimation { categoryShake += 1 }
                                        }
                                        if selectedLayout == nil {
                                            withAnimation { layoutShake += 1 }
                                        }
                                    }
                                } label: {
                                    Text("Create Ranko")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 1.2).onEnded(({ _ in
                                        if !isValid {
                                            let layout = selectedLayout
                                            // Sample data for testing
                                            rankoName = "Top 10 Snacks"
                                            description = "My all-time favorite snacks ranked."
                                            selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                                            selectedLayout = LayoutTemplate(name: "Default List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                                        }
                                    }))
                                )
                                .opacity(isValid ? 1 : 0.6)
                                
                                Button {
                                    print("Cancel tapped")
                                    dismiss()
                                } label: {
                                    Text("Cancel")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
#endif
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .ignoresSafeArea()
                                .onAppear {
                                    // Capture the height when the view appears
                                    vStackHeightButtons = geometry.size.height
                                }
                                .onChange(of: vStackHeightButtons) { _, h in
                                    print("Buttons VStack Height:", h)
                                    
                                }
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // Present the Category Picker.
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(categoryChipsByCategory: categoryChipsByCategory,
                               selectedCategoryChip: $selectedCategoryChip,
                               isPresented: $showCategoryPicker)
        }
        // Present the Layout Picker.
        .sheet(isPresented: $showLayoutPicker) {
            LayoutPickerView(selectedLayout: $selectedLayout,
                             isPresented: $showLayoutPicker)
        }
        
        .fullScreenCover(item: $fullScreenListDestination, onDismiss: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() } }) { destination in
            switch destination {
            case .defaultList:
                DefaultListView(rankoName: rankoName, description: description, isPrivate: isPrivate, category: selectedCategoryChip, onSave: {_ in })
            case .groupList:
                GroupListView(rankoName: rankoName, description: description, isPrivate: isPrivate, category: selectedCategoryChip)
            }
        }
        .onChange(of: vStackHeightName) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewRankoSheetHeight = vStackHeightName + vStackHeightDescription + vStackHeightCategoryPrivacy + vStackHeightLayout + vStackHeightButtons + 64.0
                print("Height of CreateNewRanko Sheet: \(createNewRankoSheetHeight)")
            }
        }
        .onChange(of: vStackHeightDescription) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewRankoSheetHeight = vStackHeightName + vStackHeightDescription + vStackHeightCategoryPrivacy + vStackHeightLayout + vStackHeightButtons + 64.0
                print("Height of CreateNewRanko Sheet: \(createNewRankoSheetHeight)")
            }
        }
        .onChange(of: vStackHeightCategoryPrivacy) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewRankoSheetHeight = vStackHeightName + vStackHeightDescription + vStackHeightCategoryPrivacy + vStackHeightLayout + vStackHeightButtons + 64.0
                print("Height of CreateNewRanko Sheet: \(createNewRankoSheetHeight)")
            }
        }
        .onChange(of: vStackHeightLayout) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewRankoSheetHeight = vStackHeightName + vStackHeightDescription + vStackHeightCategoryPrivacy + vStackHeightLayout + vStackHeightButtons + 64.0
                print("Height of CreateNewRanko Sheet: \(createNewRankoSheetHeight)")
            }
        }
        .onChange(of: vStackHeightButtons) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewRankoSheetHeight = vStackHeightName + vStackHeightDescription + vStackHeightCategoryPrivacy + vStackHeightLayout + vStackHeightButtons + 64.0
                print("Height of CreateNewRanko Sheet: \(createNewRankoSheetHeight)")
            }
        }
        .presentationDetents([.height(createNewRankoSheetHeight)])
        .presentationBackground(Color.white)
        .interactiveDismissDisabled(true)
    }
}

enum ListDestination: Identifiable {
    case defaultList, groupList
    
    var id: Int {
        switch self {
        case .defaultList: return 0
        case .groupList: return 1
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ProfileImageService())
}

#Preview {
    ContentView2()
        .environmentObject(ProfileImageService())
}

struct ContentView2: View {
    @State private var showSheet = false
    @State private var currentDetent: PresentationDetent = .medium
    @State private var allDetents: Set<PresentationDetent> = [.medium, .large]

    var body: some View {
        Button("Open Controlled Sheet") {
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            ControlledSheetView(currentDetent: $currentDetent)
                .presentationDetents(allDetents, selection: $currentDetent)
                .presentationDragIndicator(.hidden) // hides the drag handle
        }
    }
}

struct ControlledSheetView: View {
    @Binding var currentDetent: PresentationDetent

    var body: some View {
        VStack(spacing: 20) {
            Text("Sheet Detent: \(detentName)")
                .font(.title2)
                .padding()

            Button("Set to Medium") {
                currentDetent = .medium
            }
            .buttonStyle(.borderedProminent)

            Button("Set to Large") {
                currentDetent = .large
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private var detentName: String {
        switch currentDetent {
        case .medium: return "Medium"
        case .large: return "Large"
        default: return "Unknown"
        }
    }
}
