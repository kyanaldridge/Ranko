//
//  Layout.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI

// MARK: - Global Mapping for Layouts

struct LayoutTemplate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String  // Use a system image name or your own asset name.
    let category: String
    let disabled: Bool     // ← new flag
}

// Update your array by adding a category for each layout.
let layoutTemplates: [LayoutTemplate] = [
    LayoutTemplate(name: "Podium Layout",   description: "Put Rankings on a Podium",      imageName: "PodiumLayout",   category: "Other",       disabled: true),
    LayoutTemplate(name: "Bracket Layout",  description: "Display Ranko in 1v1s",         imageName: "BracketLayout",  category: "Other",       disabled: true),
    LayoutTemplate(name: "Radar Layout",    description: "Statistical Overview",          imageName: "RadarLayout",    category: "Other",       disabled: true),
    LayoutTemplate(name: "Timeline Layout", description: "Show Best for Each Year",       imageName: "TimelineLayout", category: "Other",       disabled: true),
    LayoutTemplate(name: "Default List",    description: "Standard list layout",          imageName: "DefaultList",    category: "Popular",     disabled: false),
    LayoutTemplate(name: "Group List",      description: "Grouped items layout",          imageName: "GroupList",      category: "Popular",     disabled: false),
    LayoutTemplate(name: "Tier List",       description: "Rank items into tiers",         imageName: "TierList",       category: "Popular",     disabled: true),
    LayoutTemplate(name: "Football Lineup", description: "Set up a team formation",       imageName: "FootballLineup", category: "Sports",      disabled: true),
    LayoutTemplate(name: "World Map",       description: "Rank Countries",                imageName: "WorldMap",       category: "Geography",   disabled: true),
    LayoutTemplate(name: "Grid Layout",     description: "Display Ranko With No Words",   imageName: "GridLayout",     category: "Popular",     disabled: true),
    LayoutTemplate(name: "Sports Ladder",   description: "Show Off Ladder Predictions",   imageName: "SportsLadder",   category: "Sports",      disabled: true),
    LayoutTemplate(name: "To Do List",      description: "Show What You've Accomplished", imageName: "ToDoList",       category: "Popular",     disabled: true),
]

// MARK: - Layout Grid Cell (Detailed List Grid)

struct LayoutGridCell: View {
    let layout: LayoutTemplate
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // ─────────────────────────────────────────────
            //   your existing card
            // ─────────────────────────────────────────────
            VStack {
                Image(layout.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: UIScreen.main.bounds.width * 0.35)
                    .clipped()
                    .cornerRadius(10)
                VStack(alignment: .center, spacing: 4) {
                    Text(layout.name)
                        .font(.headline)
                    Text(layout.description)
                        .font(.caption2)
                        .fontWeight(.light)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 4)
            }
            .padding(15)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: isSelected ? Color.blue.opacity(0.5) : Color.gray,
                    radius: isSelected ? 6 : 4,
                    x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            // ─────────────────────────────────────────────
            //   overlay when disabled
            // ─────────────────────────────────────────────
            if layout.disabled {
                Color.white
                    .opacity(0.8)
                    .cornerRadius(10)
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                    Text("Coming Soon…")
                        .font(.caption)
                }
                .foregroundColor(.black)
            }
        }
    }
}

// MARK: - Layout Picker View

struct LayoutPickerView: View {
    @Binding var selectedLayout: LayoutTemplate?
    @Binding var isPresented: Bool

    @State private var searchText: String = ""
    // Use an Optional to represent no category initially.
    @State private var selectedCategory: String? = nil
    
    // Define your categories.
    let categories: [String] = ["Popular", "Sports", "Geography", "Other"]
    
    // A mapping from category names to SF Symbols.
    let categorySymbols: [String: String] = [
        "Popular": "flame.fill",
        "Sports": "sportscourt",
        "Geography": "map.fill",
        "Other": "square.grid.2x2"
    ]
    
    let categoryColors: [String: Color] = [
        "Popular": .red,
        "Sports": .blue,
        "Geography": .green,
        "Other": .gray
    ]
    
    // Filter the full list by the selected category (if any) and search text.
    var filteredLayouts: [LayoutTemplate] {
        layoutTemplates.filter { layout in
            let matchesCategory = selectedCategory == nil ? true : (layout.category == selectedCategory)
            let matchesSearch = searchText.isEmpty ? true : layout.name.lowercased().contains(searchText.lowercased())
            return matchesCategory && matchesSearch
        }
    }
    
    // Define the popular carousel layouts using a fixed list of names.
    var popularLayouts: [LayoutTemplate] {
        let popularNames = ["Default List", "Group List", "Tier List", "Grid Layout", "To Do List"]
        return layoutTemplates.filter { popularNames.contains($0.name) }
    }

    @Namespace var namespace

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // MARK: Search Bar
                CustomSearchBar(text: $searchText, preText: "Search Layouts")
                
                // MARK: Category Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                withAnimation(.snappy) {
                                    // Toggle selection on tap.
                                    if selectedCategory == category {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = category
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if let symbol = categorySymbols[category] {
                                        Image(systemName: symbol)
                                            .foregroundColor(selectedCategory == category ? Color.white : categoryColors[category])
                                    }
                                    Text(category)
                                }
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(selectedCategory == category ? Color.white : Color.black)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 15)
                                .background(selectedCategory == category ? categoryColors[category] : Color.white)
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                
                ScrollView {
                    // ─────────────────────────────────────────
                    //  Popular carousel (same lock overlay logic)
                    // ─────────────────────────────────────────
                    if searchText.isEmpty && selectedCategory == nil {
                        HStack {
                            Text("Popular Layouts")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top, 8)
                            Spacer()
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 3) {
                                ForEach(popularLayouts) { layout in
                                    Button(action: {
                                        guard !layout.disabled else { return }
                                        if selectedLayout?.id == layout.id {
                                            selectedLayout = nil
                                        } else {
                                            selectedLayout = layout
                                        }
                                    }) {
                                        ZStack {
                                            VStack {
                                                Image(layout.imageName)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: UIScreen.main.bounds.width * 0.25,
                                                           height: UIScreen.main.bounds.width * 0.25)
                                                    .clipped()
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(selectedLayout?.id == layout.id ? Color.blue : Color.clear, lineWidth: 2)
                                                    )
                                                    .shadow(radius: 4)
                                                Text(layout.name)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .padding(.top, 5)
                                            }
                                            // lock overlay
                                            if layout.disabled {
                                                Color.white.opacity(0.8)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                VStack {
                                                    Image(systemName: "lock.fill")
                                                        .font(.title2)
                                                    Text("Soon")
                                                        .font(.caption2)
                                                }
                                                .foregroundColor(.black)
                                            }
                                        }
                                        .padding(10)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(layout.disabled)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                
                    // ─────────────────────────────────────────
                    //  Detailed grid
                    // ─────────────────────────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredLayouts) { layout in
                            Button(action: {
                                guard !layout.disabled else { return }
                                if selectedLayout?.id == layout.id {
                                    selectedLayout = nil
                                } else {
                                    selectedLayout = layout
                                }
                            }) {
                                LayoutGridCell(layout: layout,
                                               isSelected: selectedLayout?.id == layout.id)
                            }
                            .buttonStyle(.plain)
                            .disabled(layout.disabled)
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }

                Spacer()
            }
            .navigationTitle("Select Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            // MARK: Done Button Always Visible
            .overlay(
                VStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Done")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedLayout == nil ? Color.gray : Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .disabled(selectedLayout == nil)
                }
            )
        }
        .padding(0)
    }
}
