//
//  CreateNewRanko.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Main CreateNewRanko View

struct CreateNewRanko: View {
    @Environment(\.dismiss) var dismiss

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

    // Computed property to check if the form is valid.
    var isValid: Bool {
        (!rankoName.isEmpty && (selectedCategoryChip != nil)) && selectedLayout != nil
    }
    
    var body: some View {
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
            .modifier(ShakeEffect(animatableData: rankoNameShake))
            
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
                    .modifier(ShakeEffect(animatableData: categoryShake))
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
            .modifier(ShakeEffect(animatableData: layoutShake))
            .padding(.horizontal, 0)
            .padding(.bottom, 5)
            
            // MARK: - Bottom Buttons
#if !targetEnvironment(simulator)
            VStack {
                HStack(spacing: 12) {
                    Button {
                        let layout = selectedLayout
                        // Sample data for testing
                        rankoName = "Top 10 Snacks"
                        description = "My all-time favorite snacks ranked."
                        selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                        selectedLayout = LayoutTemplate(name: "Default List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                    } label: {
                        Text("Default Sample")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        let layout = selectedLayout
                        // Sample data for testing
                        rankoName = "Top 10 Snacks"
                        description = "My all-time favorite snacks ranked."
                        selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                        selectedLayout = LayoutTemplate(name: "Group List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                    } label: {
                        Text("Group Sample")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
                }
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
#endif
            
#if targetEnvironment(simulator)
            VStack {
                HStack(spacing: 12) {
                    Button {
                        let layout = selectedLayout
                        // Sample data for testing
                        rankoName = "Top 10 Snacks"
                        description = "My all-time favorite snacks ranked."
                        selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                        selectedLayout = LayoutTemplate(name: "Default List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                    } label: {
                        Text("Default Sample")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        let layout = selectedLayout
                        // Sample data for testing
                        rankoName = "Top 10 Snacks"
                        description = "My all-time favorite snacks ranked."
                        selectedCategoryChip = CategoryChip(name: "Food", icon: "fork.knife", category: "", synonym: "") // Replace with actual valid CategoryChip
                        selectedLayout = LayoutTemplate(name: "Group List", description: "", imageName: "", category: "", disabled: false)// Replace with actual valid LayoutTemplate
                    } label: {
                        Text("Group Sample")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 8))
                }
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
#endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
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
