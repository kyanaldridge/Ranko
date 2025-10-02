//
//  Algolia.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 31/5/2025.
//

import SwiftUI
import InstantSearchSwiftUI
import InstantSearchCore

typealias AClient    = AlgoliaSearchClient.SearchClient
typealias AIndex     = AlgoliaSearchClient.Index
typealias AIndexName = AlgoliaSearchClient.IndexName
typealias AQuery     = AlgoliaSearchClient.Query
typealias AJSON      = AlgoliaSearchClient.JSON

class AlgoliaAddRecords<T: Decodable> {
    // MARK: - Editable Variables -
    private let AlgoliaIndex: String
    private let AlgoliaFilters: String?
    private let AlgoliaQuery: String?
    private let AlgoliaHitsPerPage: Int
    
    // MARK: - Important Variables -
    private var client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID), apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
    private let index: AIndex


    init(
        AlgoliaIndex: String,
        AlgoliaFilters: String? = nil,
        AlgoliaQuery: String = "",
        AlgoliaHitsPerPage: Int = 20
    ) {
        self.AlgoliaIndex = AlgoliaIndex
        self.AlgoliaFilters = AlgoliaFilters
        self.AlgoliaQuery = AlgoliaQuery
        self.AlgoliaHitsPerPage = AlgoliaHitsPerPage

        self.client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                   apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        self.index = client.index(withName: IndexName(rawValue: AlgoliaIndex))
    }

    // MARK: - Fetch & Decode
    func fetchData(completion: @escaping (Result<[T], Error>) -> Void) {
        var query = Query(AlgoliaQuery)
        query.hitsPerPage = AlgoliaHitsPerPage
        if let filters = AlgoliaFilters {
            query.filters = filters
        }

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                do {
                    let objects: [T] = try response.hits.compactMap { hit in
                        let data = try JSONEncoder().encode(hit.object)
                        return try JSONDecoder().decode(T.self, from: data)
                    }
                    completion(.success(objects))
                } catch {
                    print("❌ Decoding failed: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func search(query: String, offset: Int, length: Int, completion: @escaping ([T], Int) -> Void) {
        var algoliaQuery = Query(query)
        algoliaQuery.offset = offset
        algoliaQuery.length = length
        algoliaQuery.analytics = false
        if let filters = AlgoliaFilters {
            algoliaQuery.filters = filters
        }

        index.search(query: algoliaQuery) { result in
            switch result {
            case .success(let response):
                do {
                    let objects: [T] = try response.hits.compactMap { hit in
                        let data = try JSONEncoder().encode(hit.object)
                        return try JSONDecoder().decode(T.self, from: data)
                    }
                    completion(objects, response.nbHits!) // ← total hits count
                } catch {
                    print("❌ Decoding failed: \(error)")
                    completion([], 0)
                }
            case .failure(let error):
                print("❌ Search error: \(error)")
                completion([], 0)
            }
        }
    }
}




// MARK: - AddItemView with Page Buttons
// MARK: - AddItemView with Pagination + Layout Modes
struct AddItemView: View {
    let filterChip: FilterChip
    let existingCount: Int

    @State private var algoliaAddRecords: AlgoliaAddRecords<RankoRecord>
    @State private var pageHits: [RankoRecord] = []
    @State private var searchQuery = ""
    @State private var selectedItems: [RankoItem] = []
    @State private var timedOut = false
    @Namespace private var underlineNamespace

    // Pagination
    @State private var currentPage = 0
    private let pageSize = 50
    @State private var totalHits: Int = 0

    // Loading flags
    @State private var isInitialLoading = true
    @State private var isPageLoading = false

    // Layout Mode: default list, large grid, compact list
    private enum ViewMode: String, CaseIterable {
        case biggerList, defaultList, largeGrid
    }
    @AppStorage("view_mode") private var viewMode: ViewMode = .defaultList

    var onSelectionComplete: ([RankoItem]) -> Void
    @Environment(\.dismiss) private var dismiss

    init(filterChip: FilterChip, existingCount: Int, onSelectionComplete: @escaping ([RankoItem]) -> Void) {
        self.filterChip = filterChip
        self.existingCount = existingCount
        self._algoliaAddRecords = State(wrappedValue: AlgoliaAddRecords(
            AlgoliaIndex: filterChip.nameIndex,
            AlgoliaFilters: filterChip.filter
        ))
        self.onSelectionComplete = onSelectionComplete
    }

    var body: some View {
        VStack(spacing: 7) {
            // 1) SEARCH BAR AT THE TOP
            searchBar

            // 2) VIEW MODE BUTTONS
            viewModeButtons
                .padding(.horizontal, 10)

            // 3) RESULTS AREA (fills all extra vertical space)
            Group {
                if isInitialLoading || isPageLoading {
                    // show skeleton rows
                    skeletonRowsView
                } else {
                    // show actual results based on selected layout
                    resultsSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 4) PAGINATION BAR (fixed height, just above “Add Items”)
            
            paginationSection()

            // 5) “Add Items” BUTTON at bottom
            doneButton
        }
        .background(Color.white)
        .onAppear { loadInitialPage() }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        CustomSearchBar(
            text: $searchQuery,
            preText: "Search Items",
            isEditing: .constant(true),
            onSubmit: {
                // Reset to first page and show skeleton
                currentPage = 0
                timedOut = false
                isPageLoading = true

                // Trigger the search immediately with offset=0, length=pageSize
                algoliaAddRecords.search(query: searchQuery, offset: 0, length: pageSize) { results, hits in
                    DispatchQueue.main.async {
                        self.pageHits = results
                        self.totalHits = hits
                        self.isPageLoading = false
                    }
                }

                // Hide skeleton after 2.5s (by which time results should have arrived)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isPageLoading = false
                }
            }
        )
        .padding([.top, .leading, .trailing])
    }

    // MARK: - View Mode Buttons
    private var viewModeButtons: some View {
        HStack(spacing: 12) {
            // Default List Button
            Button(action: { viewMode = .defaultList }) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewMode == .defaultList ? .blue : .gray)
                        .padding(.bottom, 2)
                    if viewMode == .defaultList {
                        // Blue glowing underline when selected
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }

            // Large Grid Button
            Button(action: { viewMode = .largeGrid }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title3)
                        .foregroundColor(viewMode == .largeGrid ? .blue : .gray)
                        .padding(.bottom, 2)
                    if viewMode == .largeGrid {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }

            // Compact List Button
            Button(action: { viewMode = .biggerList }) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.title3)
                        .foregroundColor(viewMode == .biggerList ? .blue : .gray)
                        .padding(.bottom, 2)
                    if viewMode == .biggerList {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 2)
                            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 30, height: 2)
                    }
                }
            }

            Spacer()

            Text("\(totalHits) results")
                .fontWeight(.medium)
                .font(.caption)
                .foregroundColor(.black)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        )
        .padding(.top, 12)
    }

    // MARK: - Results Section (switch based on layout)
    @ViewBuilder
    private var resultsSection: some View {
        switch viewMode {
        case .defaultList:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) {
                        // Invisible anchor for scrolling to top on page change
                        Color.clear
                            .frame(height: 0)
                            .id("top-compact")

                        if pageHits.isEmpty {
                            noResultsView
                        } else {
                            ForEach(pageHits, id: \.objectID) { item in
                                compactListRow(item)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: currentPage) { _, _ in
                    withAnimation {
                        proxy.scrollTo("top-compact", anchor: .top)
                    }
                }
            }

        case .largeGrid:
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 12
                ) {
                    ForEach(pageHits, id: \.objectID) { item in
                        largeGridItem(item)
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .biggerList:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 7) {
                        // Invisible anchor for scrolling to top on page change
                        Color.clear
                            .frame(height: 0)
                            .id("top-list")

                        if pageHits.isEmpty {
                            noResultsView
                        } else {
                            ForEach(pageHits, id: \.objectID) { item in
                                defaultListRow(item)
                            }
                        }
                    }
                    .padding(.vertical, 7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: currentPage) { _, _ in
                    withAnimation {
                        proxy.scrollTo("top-list", anchor: .top)
                    }
                }
            }
            
        }
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Text("No Results Found, Sorry 😢")
                .padding(.top, 70)
                .font(.headline)
                .fontWeight(.bold)

            Button {
                // …whatever you do for Suggest Data
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("SUGGEST DATA")
                        .fontWeight(.bold)
                        .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding([.leading, .bottom, .trailing], 50)

            Text("\(filterChip.name)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Default List Row
    @ViewBuilder
    private func defaultListRow(_ item: RankoRecord) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.ItemImage)) { phase in
                switch phase {
                case .empty:
                    SkeletonView(Circle())
                        .frame(width: 60, height: 60)
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading) {
                Text(item.ItemName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(item.ItemDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.leading, 8)

            Spacer()

            let selectedItem = selectedItems.first { $0.record.objectID == item.objectID }
            Image(systemName: selectedItem != nil ? "\(selectedItem!.rank).circle.fill" : "circle")
                .foregroundColor(selectedItem != nil ? .blue : .gray)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding(.horizontal, 10)
        .onTapGesture { toggleSelection(for: item) }
    }

    // MARK: - Large Grid Item
    @ViewBuilder
    private func largeGridItem(_ item: RankoRecord) -> some View {
        let isSelected = selectedItems.contains { $0.record.objectID == item.objectID }
        
        VStack(alignment: .leading, spacing: 6) {
            // 1) Square image container
            ZStack {
                AsyncImage(url: URL(string: item.ItemImage)) { phase in
                    switch phase {
                    case .empty:
                        // Placeholder skeleton
                        SkeletonView(RoundedRectangle(cornerRadius: 8))
                            .scaledToFill()
                        
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                        
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            // 2) Make that entire ZStack a square by forcing 1:1 aspect ratio,
            //    and let it expand to fill its column’s width.
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()
            
            // 3) Text labels below the square image
            Text(item.ItemName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.top, 4)
            
            Text(item.ItemDescription)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.4) : Color(.systemBackground))
                .shadow(color: isSelected ? .blue : .gray,
                        radius: isSelected ? 4 : 4)
        )
        .onTapGesture { toggleSelection(for: item) }
    }

    // MARK: - Compact List Row
    @ViewBuilder
    private func compactListRow(_ item: RankoRecord) -> some View {
        HStack(spacing: 8) {
            AsyncImage(url: URL(string: item.ItemImage)) { phase in
                switch phase {
                case .empty:
                    SkeletonView(Circle())
                        .frame(width: 40, height: 40)
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ItemName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(item.ItemDescription)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            let selectedItem = selectedItems.first { $0.record.objectID == item.objectID }
            Image(systemName: selectedItem != nil ? "\(selectedItem!.rank).circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(selectedItem != nil ? .blue : .gray)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground))
                .shadow(radius: 1)
        )
        .padding(.horizontal, 6)
        .onTapGesture { toggleSelection(for: item) }
    }

    // MARK: - Pagination Section (uses offset & length)
    private func paginationSection() -> some View {
        // Extract totalHits from stats text (e.g. "249 results" → 249)]
        let totalPages = (totalHits + pageSize - 1) / pageSize

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(0..<totalPages, id: \.self) { idx in
                    Button("\(idx + 1)") {
                        currentPage = idx
                        isPageLoading = true

                        // Compute offset = pageIndex * pageSize
                        algoliaAddRecords.search(query: searchQuery, offset: idx * pageSize, length: pageSize) { results, hits in
                            DispatchQueue.main.async {
                                self.pageHits = results
                                self.totalHits = hits
                                self.isPageLoading = false
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPageLoading = false
                        }
                    }
                    .font(.caption2)
                    .frame(width: 24, height: 24)
                    .background(currentPage == idx ? Color.blue : Color.white)
                    .foregroundColor(currentPage == idx ? Color.white : Color.black)
                    .cornerRadius(3)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 30)
    }

    // MARK: - Skeleton Rows View
    private var skeletonRowsView: some View {
        ScrollView {
            VStack(spacing: 7) {
                ForEach(0..<12, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonView(Circle())
                            .frame(width: 60, height: 60)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonView(RoundedRectangle(cornerRadius: 5))
                                .frame(height: 15)
                            SkeletonView(RoundedRectangle(cornerRadius: 5))
                                .frame(height: 15)
                                .padding(.trailing, 50)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 2)
                    )
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 7)
        }
    }

    // MARK: - Done Button
    private var doneButton: some View {
        Button {
            onSelectionComplete(selectedItems)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Add Items")
                    .fontWeight(.bold)
                    .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding([.leading, .bottom, .trailing])
    }

    // MARK: - Load Initial Page
    private func loadInitialPage() {
        isInitialLoading = true
        currentPage = 0

        algoliaAddRecords.search(query: "", offset: 0, length: pageSize) { results, hits in
            DispatchQueue.main.async {
                self.pageHits = results
                self.totalHits = hits
                self.isInitialLoading = false
            }
        }
    }

    // MARK: - Toggle Selection Logic (unchanged)
    private func toggleSelection(for record: RankoRecord) {
        if let idx = selectedItems.firstIndex(where: { $0.record.objectID == record.objectID }) {
            // Remove and re-rank remaining
            selectedItems.remove(at: idx)
            for i in selectedItems.indices {
                selectedItems[i].rank = existingCount + i + 1
            }
        } else {
            // Add at end
            let newRank = existingCount + selectedItems.count + 1
            let newItem = RankoItem(
                id: randomString(length: 12),
                rank: newRank,
                votes: 0,
                record: record,
                playCount: 0
            )
            selectedItems.append(newItem)
        }
    }
}


// MARK: - Preview Provider (unchanged)
struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemView(
            filterChip: FilterChip(
                id: .init(),
                name: "Artists & Bands",
                icon: "music.microphone",
                synonyms: "",
                nameIndex: "Music-Artists-Albums",
                filter: "ItemCategory:Artist",
                children: [],
                order: 0
            ),
            existingCount: 0,
            onSelectionComplete: { _ in }
        )
    }
}


// MARK: - SuggestData View (unchanged)
struct SuggestData: View {
    @State private var filterChip: FilterChip
    @State private var searchQuery: String
    @State private var suggestion: String = ""

    var body: some View {
        Text("Suggest Data for \(filterChip.name)")
            .font(.headline)
            .fontWeight(.bold)
        HStack {
            Text("Suggestion").foregroundColor(.secondary)
            Text("*").foregroundColor(.red)
        }
            .font(.caption)
            .fontWeight(.bold)
            .padding(.leading, 6)
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(.gray)
                .padding(.trailing, 1)
            TextField("\(searchQuery)", text: $suggestion)
                .onChange(of: suggestion) { _, newValue in
                    if newValue.count > 100 {
                        suggestion = String(newValue.prefix(100))
                    }
                }
                .autocorrectionDisabled(true)
                .foregroundStyle(.gray)
                .fontWeight(.bold)
            Spacer()
            Text("\(suggestion.count)/100")
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
}
