//
//  TierList_EditDetails.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI

struct TierListEditDetails: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: – Original values
    private let oldRankoName: String
    private let oldDescription: String
    private let oldPrivate: Bool
    private let oldCategory: SampleCategoryChip?
    
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
    
    // MARK: – onSave closure
    private let onSave: (String, String, Bool, SampleCategoryChip?) -> Void
    
    // Custom initializer to seed @State and capture originals + onSave
    init(
        rankoName: String,
        description: String = "",
        isPrivate: Bool,
        category: SampleCategoryChip?,
        onSave: @escaping (String, String, Bool, SampleCategoryChip?) -> Void
    ) {
        self.oldRankoName   = rankoName
        self.oldDescription = description
        self.oldPrivate     = isPrivate
        self.oldCategory    = category
        self.onSave         = onSave
        
        _rankoName    = State(initialValue: rankoName)
        _description  = State(initialValue: description)
        _isPrivate    = State(initialValue: isPrivate)
        _selectedCategoryChip = State(initialValue: category)
    }
    
    
    var body: some View {
        VStack(spacing: 16) {
            // MARK: – Ranko Name Field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Ranko Name").foregroundColor(.secondary)
                    Text("*").foregroundColor(.red)
                }
                .font(.caption2).bold()
                HStack {
                    Image(systemName: "trophy.fill").foregroundColor(.gray)
                    TextField("", text: $rankoName)
                        .placeholder("Top 15 Countries", when: rankoName.isEmpty)
                        .onChange(of: rankoName) {
                            if rankoName.count > 50 {
                                rankoName = String(rankoName.prefix(50))
                            }
                        }
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(rankoName.count)/50")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.08)))
            }
            .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: rankoNameShake))
            
            // MARK: – Description Field (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Description, if any")
                    .font(.caption2).foregroundColor(.secondary).bold()
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundColor(.gray)
                    TextField("", text: $description)
                        .placeholder("Description", when: description.isEmpty)
                        .onChange(of: description) {
                            if description.count > 100 {
                                description = String(description.prefix(100))
                            }
                        }
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(description.count)/100")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.08)))
            }
            
            // MARK: – Category & Privacy Toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Category").foregroundColor(.secondary)
                        Text("*").foregroundColor(.red)
                    }
                    .font(.caption2).bold()
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            if let categoryChip = selectedCategoryChip {
                                Image(systemName: categoryChip.icon)
                                Text(categoryChip.name).bold()
                            } else {
                                Image(systemName: "square.grid.2x2.fill")
                                Text("Select Category").bold()
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(8)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill((categoryChipIconColors[selectedCategoryChip?.name ?? ""] ?? .gray)))
                    }
                    .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: categoryShake))
                }
                Spacer()
                Toggle(isOn: $isPrivate) {
                    Text("Private")
                        .font(.caption2).foregroundColor(.secondary).bold()
                }
                .tint(.orange)
                .padding(.top, 6)
            }
            
            // MARK: - Bottom Buttons
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                HStack(spacing: 12) {
                    // Save Details
                    Button {
                        guard isValid else {
                            if rankoName.isEmpty {
                                withAnimation { rankoNameShake += 1 }
                            }
                            if selectedCategoryChip == nil {
                                withAnimation { categoryShake += 1 }
                            }
                            return
                        }
                        // propagate changes back…
                        onSave(rankoName, description, isPrivate, selectedCategoryChip)
                        dismiss()
                    } label: {
                        Text("Save Details")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                    .frame(width: totalWidth * 0.70)
                    .opacity(isValid ? 1 : 0.6)
                    .disabled(!isValid)
                    
                    // Cancel
                    Button {
                        revertAndDismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 8))
                    .frame(width: totalWidth * 0.28)
                }
                .frame(width: totalWidth)
            }
            .frame(height: 50)
            Spacer()
        }
        .padding(16)
//        .sheet(isPresented: $showCategoryPicker) {
//            CategoryPickerView(
//                categoryChipsByCategory: categoryChipsByCategory,
//                selectedCategoryChip: $selectedCategoryChip,
//                isPresented: $showCategoryPicker
//            )
//        }
    }
    
    private func revertAndDismiss() {
        rankoName    = oldRankoName
        description  = oldDescription
        isPrivate    = oldPrivate
        selectedCategoryChip = oldCategory
        dismiss()
    }
}


