//
////  AddSampleItems.swift
////  RankoApp
////
////  Created by Kyan Aldridge on 21/10/2025.
////
//
//
//import SwiftUI
//import UIKit
//import FirebaseCore
//import FirebaseDatabase
//import AlgoliaSearchClient
//import Foundation
//
//private func nestedValue(_ dict: [String: Any], keyPath: String) -> Any? {
//    var cur: Any? = dict
//    for k in keyPath.split(separator: ".").map(String.init) {
//        guard let d = cur as? [String: Any] else { return nil }
//        cur = d[k]
//    }
//    return cur
//}
//
//private func stringify(_ v: Any?) -> String? {
//    switch v {
//    case let s as String: return s
//    case let n as NSNumber:
//        // show integers without decimals
//        if CFNumberGetType(n) == .intType || CFNumberGetType(n) == .sInt64Type || CFNumberGetType(n) == .longType {
//            return String(n.intValue)
//        } else {
//            return String(describing: n)
//        }
//    case let b as Bool: return b ? "true" : "false"
//    case let a as [Any]: return a.compactMap { stringify($0) }.joined(separator: ", ")
//    default: return nil
//    }
//}
//
///// Replaces occurrences of `(field)` with the field value from `hit.raw`.
///// Example: "(runtime) mins" → "152 mins"
//private func resolveTemplate(_ template: String?, with hit: AlgoliaItemHit) -> String? {
//    guard let template, !template.isEmpty else { return nil }
//    var out = template
//    let regex = try! NSRegularExpression(pattern: #"\(([^)]+)\)"#)
//    let ns = out as NSString
//    // collect matches first so offsets don't shift while replacing
//    let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length))
//    var replacements: [(NSRange, String)] = []
//    for m in matches.reversed() { // reverse so ranges remain valid
//        let key = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
//        let val = stringify(nestedValue(hit.raw, keyPath: key)) ?? ""
//        replacements.append((m.range, val))
//    }
//    // apply
//    for (range, val) in replacements {
//        out = (out as NSString).replacingCharacters(in: range, with: val)
//    }
//    // trim any double-spaces that may result from empty vals
//    return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
//}
//
//
//public struct AnyDecodable: Decodable {
//    public let value: Any
//
//    public init(from decoder: Decoder) throws {
//        let c = try decoder.singleValueContainer()
//        if c.decodeNil() {
//            self.value = NSNull()
//        } else if let b = try? c.decode(Bool.self) {
//            self.value = b
//        } else if let i = try? c.decode(Int.self) {
//            self.value = i
//        } else if let d = try? c.decode(Double.self) {
//            self.value = d
//        } else if let s = try? c.decode(String.self) {
//            self.value = s
//        } else if let arr = try? c.decode([AnyDecodable].self) {
//            self.value = arr.map { $0.value }
//        } else if let dict = try? c.decode([String: AnyDecodable].self) {
//            self.value = dict.mapValues { $0.value }
//        } else {
//            // fallback raw data
//            self.value = try c.decode(String.self)
//        }
//    }
//}
//
//private func asString(_ v: Any?) -> String? {
//    switch v {
//    case let s as String: return s
//    case let n as NSNumber: return n.stringValue
//    case let a as [Any]: return a.compactMap { asString($0) }.joined(separator: ", ")
//    default: return nil
//    }
//}
//private func firstString(in hit: [String: Any], keys: [String]) -> String? {
//    for k in keys {
//        if let s = asString(nestedValue(hit, keyPath: k)), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
//            return s
//        }
//    }
//    return nil
//}
//private func normalizeImageURL(_ url: String?) -> String? {
//    guard let u = url, !u.isEmpty else { return nil }
//    if u.hasPrefix("http://") || u.hasPrefix("https://") { return u }
//    if u.hasPrefix("//") { return "https:\(u)" }
//    if u.hasPrefix("/")  { return "https://your.cdn.host\(u)" } // tweak if needed
//    return u
//}
//
//// MARK: - AlgoliaItemHit
//public struct AlgoliaItemHit: Identifiable, Decodable {
//    // raw payload for token/template extraction
//    public let raw: [String: Any]
//
//    // core fields used by UI
//    public let id: String
//    public var objectID: String { id } // 👈 alias to satisfy callers expecting `objectID`
//
//    public let name: String?
//    public let description: String?
//    public let image: String?
//    public let other: String?
//
//    public init(from decoder: Decoder) throws {
//        // decode the whole object into [String: Any]
//        let container = try decoder.singleValueContainer()
//        let dict = try container.decode([String: AnyDecodable].self).mapValues { $0.value }
//        self.raw = dict
//
//        // id / objectID
//        let idVal = firstString(in: dict, keys: ["objectID","id","objectId","key","slug","uuid"]) ?? UUID().uuidString
//        self.id = idVal
//
//        // reasonable defaults (step templates can override later when you render)
//        self.name = firstString(in: dict, keys: ["name","title","Name","ItemName"])
//
//        self.description = firstString(
//            in: dict,
//            keys: ["description","desc","subtitle","blurb","summary","ItemDescription"]
//        )
//
//        self.image = normalizeImageURL(
//            firstString(in: dict, keys: [
//                "image","images","thumbnail","thumb","artwork",
//                "cover","cover.url","poster_path","poster.url","ItemImage"
//            ])
//        )
//
//        self.other = firstString(
//            in: dict,
//            keys: ["type","category","kind","ItemCategory","ItemCategories.Continent"]
//        )
//    }
//
//    // convenience key-path accessor for token(...)
//    public func string(for keyPath: String) -> String? {
//        asString(nestedValue(raw, keyPath: keyPath))
//    }
//}
//
//public protocol StepTemplating {
//    var ItemName: String? { get }
//    var ItemDescription: String? { get }
//    var ItemImage: String? { get }
//}
//
//// MARK: - Tiny helpers
//private func nested(_ dict: [String: Any], keyPath: String) -> Any? {
//    var cur: Any? = dict
//    for k in keyPath.split(separator: ".").map(String.init) {
//        if let d = cur as? [String: Any] {
//            cur = d[k]
//        } else {
//            return nil
//        }
//    }
//    return cur
//}
//
///// Replace tokens like "(field)" with values from hit (supports "a.b.c")
//private func resolveTemplate(_ template: String, from hit: [String: Any]) -> String {
//    guard !template.isEmpty else { return template }
//    var out = template
//    let pattern = #"\(([A-Za-z0-9_.]+)\)"#
//    let regex = try! NSRegularExpression(pattern: pattern)
//    let matches = regex.matches(in: template, range: NSRange(location: 0, length: template.utf16.count))
//    for m in matches.reversed() {
//        guard m.numberOfRanges >= 2,
//              let keyRange = Range(m.range(at: 1), in: template),
//              let whole = Range(m.range(at: 0), in: out) else { continue }
//        let key = String(template[keyRange])
//        let raw = nested(hit, keyPath: key)
//        let rep = stringify(raw) ?? ""
//        out.replaceSubrange(whole, with: rep)
//    }
//    return out
//}
//
//extension StepViewType {
//    static var openLibraryCaseAdded: Bool { true } // marker no-op
//}
//
//// MARK: - Debug helpers
//private extension StepViewType {
//    var debugName: String {
//        switch self {
//        case .algolia: return "Algolia"
//        case .firebase: return "Firebase"
//        case .buttons:  return "Buttons"
//        case .openLibrary: return "OpenLibrary"
//        case .none:     return "(none)"
//        }
//    }
//}
//
//private func dumpConfig(_ cfg: SubcategoryDestinationConfig, idx: Int, ctx: FlowContext) {
//    // Resolve *, if present
//    let resolvedIndex   = resolveAsterisk(cfg.algoliaIndex,   with: ctx)
//    let resolvedFilters = resolveAsterisk(cfg.algoliaFilters, with: ctx)
//    let resolvedIdPath  = resolveAsterisk(cfg.firebaseIdPath, with: ctx)
//    let resolvedSearch  = resolveAsterisk(cfg.firebaseSearchPath, with: ctx)
//
//    print("""
//    ─────────────────────────────────────────────────────────
//    🧭 STEP \(idx + 1)
//      • viewType: \(cfg.viewType.debugName)
//      • selectable: \(cfg.selectable)
//      • hitsPerPage: \(cfg.hitsPerPage)
//      • searchBar: \(cfg.searchBar)
//
//    ⚙️  Algolia
//      • algoliaIndex: '\(cfg.algoliaIndex)'   → resolved: '\(resolvedIndex)'
//      • algoliaFilters: '\(cfg.algoliaFilters)' → resolved: '\(resolvedFilters)'
//      • algoliaGetField: '\(cfg.algoliaGetField)'
//
//    🔥 Firebase
//      • firebaseIdPath: '\(cfg.firebaseIdPath)' → resolved: '\(resolvedIdPath)'
//      • firebaseKeyFieldValue: '\(cfg.firebaseKeyFieldValue.rawValue)'
//      • firebaseField: '\(cfg.firebaseField)'
//      • firebasePreSuf: '\(cfg.firebasePreSuf)'
//      • firebaseSearchPath: '\(cfg.firebaseSearchPath)' → resolved: '\(resolvedSearch)'
//
//    🖼️  Rendering
//      • itemName: '\(cfg.itemName)'
//      • itemDescription: '\(cfg.itemDescription)'
//      • itemImage: '\(cfg.itemImage)'
//
//    🧮 Buttons (\(cfg.buttons.count)):
//      \(cfg.buttons.map { "    - \($0.id): \($0.name)" }.joined(separator: "\n"))
//
//    ─────────────────────────────────────────────────────────
//    """)
//}
//
//// MARK: - Placeholder resolution for "*"
//private func firstContextToken(_ ctx: FlowContext) -> String? {
//    // ✅ prefer the value collected from the most recent step (e.g., ItemName from step3)
//    if let first = ctx.collectedIDs.first, !first.isEmpty { return first }
//    return ctx.selectedButtonID
//}
//
//private func resolveAsterisk(_ template: String, with ctx: FlowContext) -> String {
//    guard template.contains("*"), let token = firstContextToken(ctx), !token.isEmpty else { return template }
//    return template.replacingOccurrences(of: "*", with: token)
//}
//
//private extension Dictionary where Key == String, Value == Any {
//    subscript(safe key: String) -> Any? {
//        self[key].flatMap { ($0 is NSNull) ? nil : $0 }
//    }
//}
//
//// A dynamic Algolia hit that captures ALL fields into `raw`
//private struct AlgoliaDynamicHit: Decodable {
//    let raw: [String: Any]
//    init(from decoder: Decoder) throws {
//        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
//        var dict: [String: Any] = [:]
//        for k in c.allKeys {
//            if let v = try? c.decode(AnyDecodable.self, forKey: k) {
//                dict[k.stringValue] = v.value
//            }
//        }
//        self.raw = dict
//    }
//
//    private struct DynamicCodingKey: CodingKey {
//        var stringValue: String
//        init?(stringValue: String) { self.stringValue = stringValue }
//        var intValue: Int? { nil }
//        init?(intValue: Int) { nil }
//    }
//}
//
//// MARK: - Category Model
//struct AppCategory: Identifiable {
//    let id = UUID()
//    let name: String
//    let symbol: String
//    let bg: Color
//    let keywords: [String]
//}
//
//// MARK: - Categories Data (unchanged except your hex colors)
//private let CATEGORIES: [AppCategory] = [
//    .init(name: "Music", symbol: "music.note", bg: Color(hex: 0xF04136),
//          keywords: ["songs","albums","artists","spotify","playlists","tracks","genres","concerts","rankings"]),
//    .init(name: "Sport", symbol: "sportscourt.fill", bg: Color(hex: 0x3EB54F),
//          keywords: ["atheletes","people","clubs","teams","leagues","trophies","coaches","referees","managers"]),
//    .init(name: "Food & Drink", symbol: "fork.knife", bg: Color(hex: 0x5460AE),
//          keywords: ["restaurants","recipes","cuisine","drinks","coffee","bars","snacks","meals"]),
//    .init(name: "Animals", symbol: "pawprint.fill", bg: Color(hex: 0xF78F1D),
//          keywords: ["pets","wildlife","breeds","dogs","cats","zoo","habitats"]),
//    .init(name: "Geography", symbol: "globe.americas.fill", bg: Color(hex: 0x1CA975),
//          keywords: ["countries","cities","maps","landmarks","flags","capitals"]),
//    .init(name: "People", symbol: "person.3.fill", bg: Color(hex: 0x8F4E88),
//          keywords: ["celebrities","historical","influencers","leaders","creators"]),
//    .init(name: "Films & Series", symbol: "film.fill", bg: Color(hex: 0x256EB7),
//          keywords: ["movies","tv","directors","actors","episodes","franchises"]),
//    .init(name: "Books", symbol: "text.book.closed.fill", bg: Color(hex: 0x007BC2),
//          keywords: ["novels","authors","genres","series","literature"]),
//    .init(name: "Gaming", symbol: "gamecontroller.fill", bg: Color(hex: 0xFFBA10),
//          keywords: ["games","platforms","studios","genres","esports"]),
//    .init(name: "History", symbol: "building.columns.fill", bg: Color(hex: 0x009B96),
//          keywords: ["civilizations","artifacts","archives","biographies"]),
//    .init(name: "Plants", symbol: "leaf.fill", bg: Color(hex: 0x7CC148),
//          keywords: ["botany","flowers","trees","gardening","herbs"]),
//    .init(name: "Science", symbol: "atom", bg: Color(hex: 0xDBDB22),
//          keywords: ["physics","chemistry","biology","space","experiments"]),
//    .init(name: "Vehicles", symbol: "car.fill", bg: Color(hex: 0x6A51A1),
//          keywords: ["cars","bikes","planes","trains","boats","specs"]),
//    .init(name: "Brands", symbol: "tag.fill", bg: Color(hex: 0x0485CF),
//          keywords: ["companies","logos","fashion","tech","retail"]),
//    .init(name: "Miscellaneous", symbol: "square.grid.2x2.fill", bg: Color(hex: 0xCD4755),
//          keywords: ["random","other","mixed","uncategorized"])
//]
//
//
//@inline(__always)
//private func DB() -> DatabaseReference {
//    // If you need a specific DB URL, use:
//    // Database.database(url: "https://ranko-kyan-21f73-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
//    return Database.database().reference()
//}
//
///// Reads a snapshot once and returns its value as `[String: Any]` or `nil`.
//private func readDict(_ path: String, completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
//    DB().child(path).observeSingleEvent(of: .value) { snap in
//        if !snap.exists() { completion(.success(nil)); return }
//        completion(.success(snap.value as? [String: Any]))
//    } withCancel: { error in
//        completion(.failure(error))
//    }
//}
//
///// Reads a snapshot once and returns its value as `[Any]` or `nil`.
//private func readArray(_ path: String, completion: @escaping (Result<[Any]?, Error>) -> Void) {
//    DB().child(path).observeSingleEvent(of: .value) { snap in
//        if !snap.exists() { completion(.success(nil)); return }
//        completion(.success(snap.value as? [Any]))
//    } withCancel: { error in
//        completion(.failure(error))
//    }
//}
//
//// MARK: - Selection Basket
//final class SelectionBasket: ObservableObject {
//    @Published var selectedGeneric: [StepRow] = []
//
//    // GENERIC toggles
//    func toggleGeneric(_ item: StepRow) {
//        if let idx = selectedGeneric.firstIndex(where: { $0.id == item.id }) {
//            selectedGeneric.remove(at: idx)
//        } else {
//            selectedGeneric.append(item)
//        }
//    }
//
//    func isGenericSelected(_ id: String) -> Bool {
//        selectedGeneric.contains(where: { $0.id == id })
//    }
//    
//    func clear() {
//        selectedGeneric.removeAll()
//    }
//    
//    func moveGeneric(from source: IndexSet, to destination: Int) {
//        selectedGeneric.move(fromOffsets: source, toOffset: destination)
//    }
//}
//
//// MARK: - Small array chunker
//private extension Array {
//    func chunked(into size: Int) -> [[Element]] {
//        guard size > 0 else { return [self] }
//        var result: [[Element]] = []
//        result.reserveCapacity((count + size - 1) / size)
//        var idx = 0
//        while idx < count {
//            let end = Swift.min(idx + size, count)
//            result.append(Array(self[idx..<end]))
//            idx = end
//        }
//        return result
//    }
//}
//
//struct CategoriesView: View {
//    @Environment(\.dismiss) private var dismiss
//    
//    @Namespace private var ns
//    @State private var searchText: String = ""
//    @State private var expandedCategoryID: UUID? = nil
//    @ObservedObject var basket: SelectionBasket
//    @State private var selectedTab = 1  // 0 = basket, 1 = search
//    @State private var editMode = false
//
//    var onAddItems: (([StepRow]) -> Void)? = nil
//    @State private var selectedIDs = Set<String>()
//
//    private let columns = 2
//    private let tileSpacing: CGFloat = 12
//
//    private var filtered: [AppCategory] {
//        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//        guard !q.isEmpty else { return CATEGORIES }
//        return CATEGORIES.filter { cat in
//            cat.name.lowercased().contains(q) ||
//            cat.keywords.contains(where: { $0.lowercased().contains(q) })
//        }
//    }
//
//    private var rows: [[AppCategory]] {
//        filtered.chunked(into: columns)
//    }
//
//    var body: some View {
//        NavigationStack {
//            TabView(selection: $selectedTab) {
//                Tab("", systemImage: "plus.circle.fill", value: 0, role: .search) {
//                    basketTabContent()
//                }
//                .badge(basket.selectedGeneric.count)
//
//                // Search / Categories tab
//                Tab("Categories", systemImage: "square.grid.2x2.fill", value: 1) {
//                    searchTabContent()
//                }
//            }
//            .tint(Color(hex: 0xFD806F))
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                // when on Basket tab
//                if selectedTab == 0 {
//                    // leading
//                    ToolbarItem(placement: .topBarLeading) {
//                        if editMode && !selectedIDs.isEmpty {
//                            Button(role: .destructive) { performDelete() } label: {
//                                Label("Delete", systemImage: "trash.fill")
//                                    .foregroundColor(.red)
//                            }
//                        } else if !editMode && !basket.selectedGeneric.isEmpty {
//                            Button {
//                                editMode = true
//                            } label: {
//                                HStack(spacing: 6) {
//                                    Text("Edit Items").font(.custom("Nunito-Black", size: 12))
//                                }
//                            }
//                        }
//                    }
//
//                    // title
//                    ToolbarItem(placement: .principal) {
//                        Text(editMode
//                             ? (selectedIDs.isEmpty ? "Select items" : "\(selectedIDs.count) selected")
//                             : "Selected Items")
//                        .font(.custom("Nunito-Black", size: 16))
//                    }
//
//                    // trailing
//                    ToolbarItem(placement: .topBarTrailing) {
//                        if editMode {
//                            Button {
//                                // Done (exit edit, clear selection)
//                                selectedIDs.removeAll()
//                                editMode = false
//                            } label: { Text("Done").font(.custom("Nunito-Black", size: 12)) }
//                            .disabled(selectedIDs.isEmpty == false && false) // keep enabled
//                        } else {
//                            if !basket.selectedGeneric.isEmpty {
//                                Button { performAdd() } label: {
//                                    HStack(spacing: 6) {
//                                        Text("Add to Ranko").font(.custom("Nunito-Black", size: 12))
//                                    }
//                                }
//                            } else {
//                                Button { dismiss() } label: {
//                                    HStack(spacing: 6) {
//                                        Text("Cancel")
//                                            .font(.custom("Nunito-Black", size: 14))
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//                if selectedTab == 1 {
//                    ToolbarItem(placement: .principal) {
//                        Text("Select Category")
//                        .font(.custom("Nunito-Black", size: 16))
//                    }
//                    ToolbarItem(placement: .topBarLeading) {
//                        Button { dismiss() } label: {
//                            HStack(spacing: 6) {
//                                Image(systemName: "escape")
//                                    .font(.system(size: 16, weight: .black))
//                                    .foregroundStyle(Color.red)
//                            }
//                        }
//                    }
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Button { selectedTab = 0 } label: {
//                            HStack(spacing: 6) {
//                                Text("View Items")
//                                    .font(.custom("Nunito-Black", size: 12))
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        .environmentObject(basket)
//    }
//    
//    @ViewBuilder
//    private func basketTabContent() -> some View {
//        List {
//            if basket.selectedGeneric.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "basket")
//                        .font(.system(size: 48))
//                        .foregroundStyle(.secondary)
//                    Text("No items selected yet")
//                        .font(.custom("Nunito-Black", size: 16))
//                        .foregroundStyle(.secondary)
//                    Text("Browse categories and add items to get started")
//                        .font(.caption)
//                        .foregroundStyle(.tertiary)
//                        .multilineTextAlignment(.center)
//                    Button {
//                        selectedTab = 1            // switch to searchTabContent
//                        // optional niceties:
//                        // searchText = ""
//                        // expandedCategoryID = nil
//                    } label: {
//                        Text("Browse Items")
//                            .font(.custom("Nunito-Black", size: 16))
//                            .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.glassProminent)
//                    .controlSize(.large)
//                    .accessibilityLabel("Browse Items")
//                    .padding(.top, 15)
//                    .padding(.horizontal, 30)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 60)
//                .listRowBackground(Color.clear)
//            } else {
//
//                // GENERIC
//                if !basket.selectedGeneric.isEmpty {
//                    Section("selected") {
//                        ForEach(basket.selectedGeneric, id: \.id) { r in
//                            HStack(spacing: 12) {
//                                AsyncImage(url: URL(string: r.imageURL ?? "")) { phase in
//                                    switch phase {
//                                    case .empty: SkeletonView(Circle()).frame(width: 34, height: 34)
//                                    case .success(let img): img.resizable().scaledToFill().frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 6))
//                                    case .failure: Image(systemName: "photo").frame(width: 34, height: 34)
//                                    @unknown default: EmptyView()
//                                    }
//                                }
//                                VStack(alignment: .leading, spacing: 2) {
//                                        Text(r.name).font(.custom("Nunito-Black", size: 14))
//                                        if let d = r.desc, !d.isEmpty {
//                                            Text(d).font(.caption).foregroundStyle(.secondary)
//                                        }
//                                    }
//                                    Spacer()
//
//                                    // show checkmarks only in edit mode
//                                    if editMode {
//                                        Image(systemName: selectedIDs.contains(r.id) ? "checkmark.circle.fill" : "circle")
//                                            .foregroundStyle(.accent)
//                                            .transition(.scale.combined(with: .opacity))
//                                    }
//                                }
//                                .contentShape(Rectangle())
//                                .onTapGesture {
//                                    guard editMode else { return }
//                                    if selectedIDs.contains(r.id) {
//                                        selectedIDs.remove(r.id)
//                                    } else {
//                                        selectedIDs.insert(r.id)      // 👈 Set.insert, not append
//                                    }
//                                }
//                        }
//                        .onMove(perform: basket.moveGeneric)
//                    }
//                }
//            }
//        }
//        .scrollIndicators(.hidden)
//        .listStyle(.insetGrouped)
//    }
//    
//    @ViewBuilder
//    private func searchTabContent() -> some View {
//        ScrollView {
//            LazyVStack(spacing: tileSpacing) {
//                ForEach(rows.indices, id: \.self) { rowIndex in
//                    HStack(spacing: tileSpacing) {
//                        ForEach(rows[rowIndex]) { cat in
//                            Button {
//                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
//                                    expandedCategoryID = (expandedCategoryID == cat.id) ? nil : cat.id
//                                }
//                            } label: {
//                                CategoryTile(category: cat, isSelected: expandedCategoryID == cat.id)
//                                    .matchedTransitionSource(id: cat.id, in: ns)
//                            }
//                            .buttonStyle(.plain)
//                            .accessibilityLabel(Text(cat.name))
//                        }
//                    }
//                    
//                    if let expanded = expandedCategoryID,
//                       let expandedCat = rows[rowIndex].first(where: { $0.id == expanded }) {
//                        SubcategoryDisclosureRow(
//                            parent: expandedCat,
//                            subcategories: subcategories(for: expandedCat),
//                            ns: ns,
//                            onDismiss: {
//                                selectedTab = 0
//                            }
//                        )
//                        .transition(.asymmetric(
//                            insertion: .move(edge: .top).combined(with: .opacity),
//                            removal: .move(edge: .top).combined(with: .opacity)
//                        ))
//                    }
//                }
//            }
//            .padding(16)
//        }
//    }
//
//    private func subcategories(for category: AppCategory) -> [AppSubcategory] {
//        (SUBCATEGORIES[category.name] ?? []).map { sc in
//            AppSubcategory(
//                name: sc.name,
//                symbol: sc.symbol,
//                bg: category.bg,
//                availability: sc.availability,
//                step1: sc.step1,
//                step2: sc.step2,
//                step3: sc.step3,
//                step4: sc.step4,
//                step5: sc.step5,
//                step6: sc.step6,
//                step7: sc.step7,
//                step8: sc.step8,
//                step9: sc.step9,
//                step10: sc.step10,
//                step11: sc.step11,
//                step12: sc.step12,
//                step13: sc.step13,
//                step14: sc.step14,
//                step15: sc.step15,
//                buttonRoutes: sc.buttonRoutes
//            )
//        }
//    }
//    
//    private func selectedGenericRows() -> [StepRow] {
//        basket.selectedGeneric.filter { selectedIDs.contains($0.id) }
//    }
//
//    private func performAdd() {
//        // if some are selected, add only those; otherwise add all
//        let payload = selectedIDs.isEmpty ? basket.selectedGeneric : selectedGenericRows()
//        onAddItems?(payload)
//        // optional: clear selection + exit edit
//        selectedIDs.removeAll()
//        editMode = false
//    }
//
//    private func performDelete() {
//        guard !selectedIDs.isEmpty else { return }
//        let ids = selectedIDs
//        basket.selectedGeneric.removeAll { ids.contains($0.id) }
//        selectedIDs.removeAll()
//        editMode = false
//        // keep editMode = true so user can keep selecting, or set to false if you prefer
//    }
//
//}
//
//
//// MARK: - Tile
//struct CategoryTile: View {
//    @State private var isHighlighted: Bool = false
//    let category: AppCategory
//    let isSelected: Bool
//
//    var body: some View {
//        VStack {
//            if isSelected {
//                Rectangle()
//                    .fill(.clear)
//                    .frame(height: 15)
//            }
//            HStack {
//                Image(systemName: category.symbol)
//                    .font(.system(size: 19, weight: .semibold))
//                    .foregroundColor(category.bg)
//                    .padding(14)
//                
//                Spacer(minLength: 0)
//                
//                Text(category.name)
//                    .font(.custom("Nunito-Black", size: 17))
//                    .foregroundColor(category.bg)
//                    .padding(14)
//            }
//            .background {
//                RoundedRectangle(cornerRadius: 20, style: .continuous)
//                    .fill(Color(hex: 0xFFFFFF))
//                    .shadow(color: isSelected ? category.bg : Color.black.opacity(0.2), radius: 3)
//            }
//        }
//        .onChange(of: isSelected) { _, _ in
//            withAnimation {
//                isHighlighted = isSelected
//            }
//        }
//    }
//}
//
//// MARK: - Inline disclosure row showing a 4-column grid of subcats
//private struct SubcategoryDisclosureRow: View {
//    let parent: AppCategory
//    let subcategories: [AppSubcategory]
//    let ns: Namespace.ID
//    let onDismiss: () -> Void
//    
//    @State private var isExpanded = true
//    @EnvironmentObject private var basket: SelectionBasket
//    
//    var body: some View {
//        SubcategoryFlexibleView(spacing: 8, rowAlignment: .center) {
//            ForEach(subcategories) { sc in
//                if sc.availability {
//                    NavigationLink {
//                        SubcategoryFlowHost(
//                            subcategoryName: sc.name,
//                            tint: sc.bg,
//                            steps: sc.steps,
//                            buttonRoutes: sc.buttonRoutes,
//                            onDismiss: { onDismiss() }
//                        )
//                        .environmentObject(basket)
//                        .navigationTransition(.zoom(sourceID: sc.id, in: ns))
//                    } label: {
//                        HStack(spacing: 10) {
//                            Image(systemName: sc.symbol)
//                                .font(.system(size: 12, weight: .semibold))
//                            Text(sc.name)
//                                .font(.custom("Nunito-Black", size: 13))
//                        }
//                        .padding(.horizontal, 10)
//                        .frame(height: 28)
//                        .matchedTransitionSource(id: sc.id, in: ns)
//                    }
//                    .foregroundColor(Color(hex: 0xFFFFFF))
//                    .tint(sc.availability ? sc.bg.opacity(0.7) : Color.gray.opacity(0.6))
//                    .buttonStyle(.glassProminent)
//                    .fixedSize(horizontal: true, vertical: false)   // << important for centering
//                } else {
//                    Button { } label: {
//                        HStack(spacing: 10) {
//                            Image(systemName: sc.symbol)
//                                .font(.system(size: 12, weight: .semibold))
//                            Text(sc.name)
//                                .font(.custom("Nunito-Black", size: 13))
//                        }
//                        .padding(.horizontal, 10)
//                        .frame(height: 28)
//                        .matchedTransitionSource(id: sc.id, in: ns)
//                    }
//                    .foregroundColor(Color(hex: 0xFFFFFF))
//                    .tint(sc.availability ? sc.bg.opacity(0.7) : Color.gray.opacity(0.6))
//                    .buttonStyle(.glassProminent)
//                    .fixedSize(horizontal: true, vertical: false)   // << important for centering
//                }
//            }
//        }
//        .padding(.horizontal, 2)
//        .onAppear {
//            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
//                isExpanded = true
//            }
//        }
//    }
//}
//
//struct SubcategoryFlexibleView: Layout {
//    var spacing: CGFloat = 8
//    enum RowAlignment { case leading, center, trailing }
//    var rowAlignment: RowAlignment = .center
//
//    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
//        let maxWidth = proposal.width ?? .infinity
//        guard maxWidth.isFinite else {
//            // fallback: single row natural size
//            let totalWidth = subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } +
//                             max(0, CGFloat(subviews.count - 1)) * spacing
//            let maxHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
//            return CGSize(width: totalWidth, height: maxHeight)
//        }
//
//        var currentRowWidth: CGFloat = 0
//        var currentRowHeight: CGFloat = 0
//        var totalHeight: CGFloat = 0
//        var maxRowWidth: CGFloat = 0
//
//        for view in subviews {
//            let size = view.sizeThatFits(.unspecified)
//            if currentRowWidth > 0, currentRowWidth + spacing + size.width > maxWidth {
//                // wrap
//                totalHeight += currentRowHeight + spacing
//                maxRowWidth = max(maxRowWidth, currentRowWidth)
//                currentRowWidth = 0
//                currentRowHeight = 0
//            }
//            currentRowWidth = currentRowWidth == 0 ? size.width : (currentRowWidth + spacing + size.width)
//            currentRowHeight = max(currentRowHeight, size.height)
//        }
//
//        // last row
//        if currentRowHeight > 0 {
//            totalHeight += currentRowHeight
//            maxRowWidth = max(maxRowWidth, currentRowWidth)
//        }
//
//        return CGSize(width: maxWidth, height: totalHeight)
//    }
//
//    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//        let maxWidth = bounds.width
//        guard maxWidth.isFinite, !subviews.isEmpty else {
//            // simple top-left place
//            var x = bounds.minX
//            let y = bounds.minY
//            for v in subviews {
//                let s = v.sizeThatFits(.unspecified)
//                v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
//                x += s.width + spacing
//            }
//            return
//        }
//
//        // 1) Build rows
//        var rows: [[(index: Int, size: CGSize)]] = []
//        var currentRow: [(Int, CGSize)] = []
//        var currentRowWidth: CGFloat = 0
//        var currentRowHeight: CGFloat = 0
//
//        for (i, v) in subviews.enumerated() {
//            let s = v.sizeThatFits(.unspecified)
//            let nextWidth = currentRow.isEmpty ? s.width : (currentRowWidth + spacing + s.width)
//            if !currentRow.isEmpty && nextWidth > maxWidth {
//                rows.append(currentRow)
//                currentRow = [(i, s)]
//                currentRowWidth = s.width
//                currentRowHeight = s.height
//            } else {
//                currentRow.append((i, s))
//                currentRowWidth = nextWidth
//                currentRowHeight = max(currentRowHeight, s.height)
//            }
//        }
//        if !currentRow.isEmpty { rows.append(currentRow) }
//
//        // 2) Place rows with per-row horizontal alignment
//        var y = bounds.minY
//        for row in rows {
//            // compute row width & height
//            let rowWidth = row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
//            let rowHeight = row.map { $0.size.height }.max() ?? 0
//
//            let startX: CGFloat
//            switch rowAlignment {
//            case .leading:
//                startX = bounds.minX
//            case .center:
//                startX = bounds.midX - rowWidth / 2.0
//            case .trailing:
//                startX = bounds.maxX - rowWidth
//            }
//
//            var x = startX
//            for (idx, size) in row {
//                subviews[idx].place(at: CGPoint(x: x, y: y),
//                                    proposal: ProposedViewSize(size))
//                x += size.width + spacing
//            }
//            y += rowHeight + spacing
//        }
//    }
//}
//
//// MARK: - Subcategory tile (icon + name on the same line)
//private struct SubcategoryTile: View {
//    let sub: AppSubcategory
//
//    var body: some View {
//        HStack(spacing: 10) {
//            Image(systemName: sub.symbol)
//                .font(.system(size: 16, weight: .semibold))
//                .foregroundColor(sub.bg)
//
//            Text(sub.name)
//                .font(.custom("Nunito-Black", size: 12))
//                .foregroundColor(sub.bg)
//
//            Spacer(minLength: 0)
//        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, -5)
//        .frame(height: 44)
//        .background(
//            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                .fill(Color.white)
//                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 14, style: .continuous)
//                        .stroke(sub.bg, lineWidth: 2)
//                )
//        )
//        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//    }
//}
//
//// MARK: - Shared destination; title is customized by subcategory (icon + name + tint)
//private struct SubcategoryDestinationView: View {
//    let subcategory: AppSubcategory
//
//    var body: some View {
//        // blank content for now
//        Color(.systemGroupedBackground)
//            .ignoresSafeArea()
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    HStack(spacing: 8) {
//                        Image(systemName: subcategory.symbol)
//                            .font(.system(size: 16, weight: .semibold))
//                            .foregroundStyle(subcategory.bg)
//                        Text(subcategory.name)
//                            .font(.custom("Nunito-Black", size: 16))
//                            .foregroundStyle(subcategory.bg)
//                    }
//                }
//            }
//            .tint(subcategory.bg)
//    }
//}
//
//struct SubcategoryDestinationButton: Identifiable, Hashable {
//    let id: String
//    let name: String
//    let icon: String
//}
//
//// We keep it stringly-typed to match your templating "(field)" patterns
//enum StepViewType: String, Codable {
//    case algolia = "Algolia"
//    case firebase = "Firebase"
//    case buttons = "Buttons"
//    case openLibrary = "OpenLibrary"
//    case none = ""
//}
//
//enum FirebaseKeyMode: String, Codable {
//    case key = "key"
//    case value = "value"
//    case none = ""
//}
//
//struct SubcategoryDestinationConfig: Identifiable, Hashable {
//    let id = UUID()
//    let viewType: StepViewType
//
//    // Algolia
//    let algoliaAppId: String
//    let algoliaAppKey: String
//    let algoliaIndex: String
//    let algoliaFilters: String
//    let algoliaGetField: String
//
//    // Firebase
//    let firebaseIdPath: String
//    let firebaseKeyFieldValue: FirebaseKeyMode
//    let firebaseField: String
//    let firebasePreSuf: String
//    let firebaseSearchPath: String
//
//    // Shared
//    let hitsPerPage: Int
//    let searchBar: Bool
//    let selectable: Bool
//    let itemName: String
//    let itemDescription: String
//    let itemImage: String
//    let buttons: [SubcategoryDestinationButton]
//
//    init(
//        ViewType: String,
//        AlgoliaAppID: String,
//        AlgoliaAppKey: String,
//        AlgoliaIndex: String,
//        AlgoliaFilters: String,
//        AlgoliaGetField: String,
//        FirebaseIdPath: String,
//        FirebaseKeyFieldValue: String,
//        FirebaseField: String,
//        FirebasePreSuf: String,
//        FirebaseSearchPath: String,
//        HitsPerPage: Int,
//        SearchBar: Bool,
//        Selectable: Bool,
//        ItemName: String,
//        ItemDescription: String,
//        ItemImage: String,
//        Buttons: [SubcategoryDestinationButton]
//    ) {
//        self.viewType = StepViewType(rawValue: ViewType) ?? .none
//        self.algoliaAppId = AlgoliaAppID
//        self.algoliaAppKey = AlgoliaAppKey
//        self.algoliaIndex = AlgoliaIndex
//        self.algoliaFilters = AlgoliaFilters
//        self.algoliaGetField = AlgoliaGetField
//        self.firebaseIdPath = FirebaseIdPath
//        self.firebaseKeyFieldValue = FirebaseKeyMode(rawValue: FirebaseKeyFieldValue) ?? .none
//        self.firebaseField = FirebaseField
//        self.firebasePreSuf = FirebasePreSuf
//        self.firebaseSearchPath = FirebaseSearchPath
//        self.hitsPerPage = HitsPerPage
//        self.searchBar = SearchBar
//        self.selectable = Selectable
//        self.itemName = ItemName
//        self.itemDescription = ItemDescription
//        self.itemImage = ItemImage
//        self.buttons = Buttons
//    }
//}
//
//// Subcategory now holds up to 7 step configs
//struct AppSubcategory: Identifiable, Hashable {
//    let id = UUID()
//    let name: String
//    let symbol: String
//    let bg: Color
//    let availability: Bool
//    let step1: SubcategoryDestinationConfig?
//    let step2: SubcategoryDestinationConfig?
//    let step3: SubcategoryDestinationConfig?
//    let step4: SubcategoryDestinationConfig?
//    let step5: SubcategoryDestinationConfig?
//    let step6: SubcategoryDestinationConfig?
//    let step7: SubcategoryDestinationConfig?
//    let step8: SubcategoryDestinationConfig?
//    let step9: SubcategoryDestinationConfig?
//    let step10: SubcategoryDestinationConfig?
//    let step11: SubcategoryDestinationConfig?
//    let step12: SubcategoryDestinationConfig?
//    let step13: SubcategoryDestinationConfig?
//    let step14: SubcategoryDestinationConfig?
//    let step15: SubcategoryDestinationConfig?
//
//    // NEW: buttonID -> 1-based step index to jump to (e.g., 2, 3, 4…)
//    let buttonRoutes: [String: Int]?  // optional
//
//    var steps: [SubcategoryDestinationConfig] {
//        [step1, step2, step3, step4, step5, step6, step7, step8, step9, step10, step11, step12, step13, step14, step15].compactMap { $0 }
//    }
//}
//
//// MARK: - Flow Context passed between steps
//private struct FlowContext {
//    var collectedIDs: [String] = []       // from AlgoliaGetField or Firebase IdPath collection
//    var selectedButtonID: String? = nil   // from Buttons step
//}
//
//// MARK: - Generic Flow Host for a Subcategory (renders step N)
//struct SubcategoryFlowHost: View {
//    let subcategoryName: String
//    let tint: Color
//    let steps: [SubcategoryDestinationConfig]
//    let buttonRoutes: [String: Int]?
//
//    @State private var ctx = FlowContext()
//    @State private var currentStep = 0
//    @State private var path: [Int] = []
//    @Namespace private var nsSteps
//    
//    let onDismiss: () -> Void
//
//    private func stepKey(_ idx: Int) -> String { "\(subcategoryName)-step-\(idx)" }
//
//    // Centralized navigation + debug
//    private func go(to idx: Int, reason: String) {
//        guard steps.indices.contains(idx) else { return }
//        if path.isEmpty {
//            currentStep = idx
//        } else {
//            if steps[idx].selectable == false {
//                path.append(idx)
//            } else {
//                path[path.count - 1] = idx
//            }
//            currentStep = idx
//        }
//    }
//
//    var body: some View {
//        stepView(for: currentStep)
//            .matchedTransitionSource(id: stepKey(currentStep), in: nsSteps)
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    HStack(spacing: 8) {
//                        Image(systemName: "square.grid.2x2.fill")
//                            .font(.system(size: 15, weight: .semibold))
//                            .foregroundStyle(tint)
//                        Text(subcategoryName)
//                            .font(.custom("Nunito-Black", size: 16))
//                            .foregroundStyle(tint)
//                    }
//                }
//            }
//            .tint(tint)
//            .navigationDestination(for: Int.self) { idx in
//                stepView(for: idx)
//                    .matchedTransitionSource(id: stepKey(idx), in: nsSteps)
//            }
//            .onAppear {
//                path = []
//                currentStep = 0
//            }
//            .onChange(of: path) { _, newPath in
//                // Reading only; go() already logged on mutations
//                currentStep = newPath.last ?? currentStep
//            }
//    }
//
//    @ViewBuilder
//    private func stepView(for idx: Int) -> some View {
//        StepContentView(
//            step: steps[idx],
//            tint: tint,
//            ctx: $ctx,
//            buttonRoutes: buttonRoutes,
//            onAdvance: { newIDs in
//                if let ids = newIDs, !ids.isEmpty {
//                    ctx.collectedIDs = ids
//                    ctx.selectedButtonID = nil
//                }
//                let next = idx + 1
//                guard steps.indices.contains(next) else { return }
//                go(to: next, reason: "onAdvance from step \(idx + 1)")
//            },
//            onJumpTo: { stepIndexOneBased in
//                let target = max(1, stepIndexOneBased) - 1
//                guard steps.indices.contains(target) else { return }
//                go(to: target, reason: "onJumpTo via button route from step \(idx + 1)")
//            },
//            onDismiss: {
//                onDismiss()
//            }
//        )
//    }
//}
//
//// MARK: - Step Content
//private struct StepContentView: View {
//    @Environment(\.dismiss) private var dismiss
//    let step: SubcategoryDestinationConfig
//    let tint: Color
//    @Binding var ctx: FlowContext
//    let buttonRoutes: [String: Int]?            // NEW
//    let onAdvance: (_ newIDs: [String]?) -> Void
//    let onJumpTo: (_ stepIndexOneBased: Int) -> Void  // NEW
//    let onDismiss: () -> Void
//    @State private var searchTextEmpty: Bool = true
//
//    @State private var searchText: String = ""
//    @State private var searchSubmitNonce: Int = 0   // 👈 add this
//
//    var body: some View {
//        ZStack {
//            Group {
//                switch step.viewType {
//                case .buttons:
//                    ButtonsStepView(step: step, tint: tint) { buttonID in
//                        // remember the choice
//                        ctx.selectedButtonID = buttonID
//                        // if a route exists for this button, jump there; else go next
//                        if let route = buttonRoutes?[buttonID] {
//                            onJumpTo(route)
//                        } else {
//                            onAdvance(nil)
//                        }
//                    }
//                    
//                case .algolia:
//                    AlgoliaStepView(
//                        step: step,
//                        ctx: $ctx.wrappedValue,
//                        tint: tint,
//                        searchText: $searchText,
//                        submitNonce: searchSubmitNonce
//                    ) { ids in
//                        if !step.selectable { onAdvance(ids) }
//                    }
//                    // 👇 force a fresh Algolia view when the config or context token changes
//                    .id("ALG|\(step.id)|\((ctx.selectedButtonID ?? ctx.collectedIDs.first) ?? "-")")
//                    
//                case .firebase:
//                    FirebaseStepView(
//                        step: step,
//                        tint: tint,
//                        incomingIDs: ctx.collectedIDs,
//                        submitNonce: searchSubmitNonce
//                    ) { ids in
//                        if !step.selectable { onAdvance(ids) }
//                    }
//                    // 👇 force a fresh Firebase view when the config or seed IDs change
//                    .id("FB|\(step.id)|\(ctx.collectedIDs.first ?? "-")")
//                    
//                case .openLibrary:
//                    OpenLibraryStepView(
//                        step: step,
//                        tint: tint,
//                        ctx: $ctx,
//                        searchText: $searchText,
//                        submitNonce: searchSubmitNonce
//                    ) { ids in
//                        if !step.selectable { onAdvance(ids) }
//                    } onJumpTo: { target in
//                        onJumpTo(target)
//                    }
//                    // keep view identity stable per mode & seed
//                    .id("OL|\(step.id)|\((ctx.selectedButtonID ?? ctx.collectedIDs.first) ?? "-")")
//                    
//                case .none:
//                    VStack { Spacer(); Text("No view configured for this step.")
//                        .foregroundStyle(.secondary).padding(); Spacer() }
//                }
//            }
//            VStack {
//                Spacer(minLength: 0)
//                Button {
//                    onDismiss()
//                    dismiss()
//                } label: {
//                    Text("View Items")
//                        .font(.custom("Nunito-Black", size: 20))
//                        .padding(.horizontal, 6)
//                }
//                .buttonStyle(.glassProminent)
//                .tint(Color(.red))
//                .controlSize(.large)
//            }
//            .padding(.bottom, 15)
//        }
//        .onChange(of: searchText) { oldText, newText in
//            if oldText.isEmpty && !newText.isEmpty {
//                withAnimation {
//                    searchTextEmpty = false
//                }
//            } else if !oldText.isEmpty && newText.isEmpty {
//                withAnimation {
//                    searchTextEmpty = true
//                }
//            }
//        }
//        .safeAreaInset(edge: .top) {
//            if step.searchBar {
//                HStack { Image(systemName: "magnifyingglass")
//                    TextField("Search…", text: $searchText)
//                        .textInputAutocapitalization(.never)
//                        .font(.custom("Nunito-Black", size: 14))
//                        .disableAutocorrection(true)
//                        .submitLabel(.search)
//                        .onSubmit {
//                            searchSubmitNonce += 1
//                        }
//                    Spacer(minLength: 0)
//                    if !searchTextEmpty {
//                        Button {
//                            searchText = ""
//                        } label: {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundStyle(Color.gray)
//                        }
//                    }
//                }
//                .padding(10)
//                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
//                .padding([.horizontal, .top])
//            }
//        }
//    }
//}
//
//private struct ButtonsStepView: View {
//    let step: SubcategoryDestinationConfig
//    let tint: Color
//    let onPick: (String) -> Void
//
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 10) {
//                ForEach(step.buttons) { b in
//                    Button {
//                        onPick(b.id)
//                    } label: {
//                        HStack {
//                            Image(systemName: b.icon)
//                            Text(b.name).font(.custom("Nunito-Black", size: 15))
//                            Spacer()
//                            Image(systemName: "chevron.forward").foregroundStyle(.secondary)
//                        }
//                        .padding(12)
//                        .background(
//                            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                                .fill(Color.white)
//                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
//                        )
//                    }
//                    .tint(tint)
//                }
//            }
//            .padding()
//        }
//    }
//}
//
//// Simple row model to render
//struct StepRow: Codable, Identifiable, Hashable {
//    let id: String
//    let name: String
//    let desc: String?
//    let imageURL: String?
//}
//
//private func renderTemplate(_ template: String, with dict: [String: Any]) -> String {
//    // replaces "(field)" with dict[field] if present; leaves literal text otherwise
//    var out = template
//    // crude parse: find all (...) groups
//    let regex = try? NSRegularExpression(pattern: #"\(([^)]+)\)"#)
//    let ns = NSString(string: template)
//    var offset = 0
//    regex?.matches(in: template, range: NSRange(location: 0, length: ns.length)).forEach { m in
//        if m.numberOfRanges >= 2 {
//            let r = m.range(at: 1)
//            let key = ns.substring(with: r)
//            let fullRange = NSRange(location: m.range.location + offset, length: m.range.length)
//            let replacement: String
//            if let v = dict[key] {
//                replacement = "\(v)"
//            } else {
//                replacement = "" // missing field -> blank
//            }
//            out = (out as NSString).replacingCharacters(in: fullRange, with: replacement)
//            offset += replacement.count - m.range.length
//        }
//    }
//    return out
//}
//
//private struct FirebaseItemHit: Identifiable, Hashable, Equatable {
//    let id: String
//    var name: String?
//    var description: String?
//    var image: String?
//    let raw: [String: Any]
//
//    init(id: String,
//         dict: [String: Any],
//         nameKeys: [String] = ["name","ItemName","title","Name"],
//         descKeys: [String] = ["description","ItemDescription","desc"],
//         imageKeys: [String] = ["image","images","ItemImage","cover"]) {
//
//        self.id = id
//        self.raw = dict
//
//        func val(_ keys: [String]) -> String? {
//            for k in keys {
//                if let v = dict[k] { return "\(v)" }
//            }
//            return nil
//        }
//        self.name = val(nameKeys)
//        self.description = val(descKeys)
//        self.image = val(imageKeys)
//    }
//
//    // MARK: Equatable
//    static func == (lhs: FirebaseItemHit, rhs: FirebaseItemHit) -> Bool {
//        // Treat hits as the same item if their IDs match.
//        return lhs.id == rhs.id
//    }
//
//    // MARK: Hashable
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
//}
//
//// MARK: - Generic Algolia step (typed fallback for Music)
//private struct AlgoliaStepView: View {
//    let step: SubcategoryDestinationConfig
//    let ctx: FlowContext
//    let tint: Color
//    @Binding var searchText: String
//    let submitNonce: Int
//    let forwardIDs: ([String]) -> Void
//    @State private var isLoading = false
//    private let animationDuration = 0.8
//    
//    @EnvironmentObject private var basket: SelectionBasket
//    
//    @State private var page = 0
//    @State private var total = 0
//    @State private var rows: [StepRow] = []
//    @State private var hits: [AlgoliaItemHit] = []   // keep raw hits for token extraction
//    @State private var hasFetched = false
//    @State private var client: AlgoliaAddRecords<AlgoliaItemHit>?
//    
//    // local selection state for checkmarks
//    @State private var selectedRowIDs: Set<String> = []
//    
//    // 🔎 debug state
//    @State private var lastIndex: String = ""
//    @State private var lastFilters: String = ""
//    @State private var lastQuery: String = ""
//    @State private var lastErr: String?
//    
//    private var resolvedIndex: String { resolveAsterisk(step.algoliaIndex, with: ctx) }
//    private var resolvedFilters: String {
//        resolveAsterisk(step.algoliaFilters, with: ctx).trimmingCharacters(in: .whitespaces)
//    }
//    
//    private func token(from hit: AlgoliaItemHit, using field: String) -> String {
//        let key = field.trimmingCharacters(in: .whitespacesAndNewlines)
//        if key.isEmpty || key == "objectID" { return hit.objectID }
//        if let v = hit.string(for: key) { return v }                 // supports "a.b.c"
//        if key.caseInsensitiveCompare("ItemName") == .orderedSame {
//            return hit.name ?? hit.objectID
//        }
//        if key.caseInsensitiveCompare("name") == .orderedSame {
//            return hit.name ?? hit.objectID
//        }
//        return hit.objectID
//    }
//    
//    @State private var showDebug: Bool = true
//    
//    var body: some View {
//        ZStack {
//            VStack(spacing: 0) {
//                // 🧰 inline debug banner (tap to hide if you want)
//                if showDebug {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("DEBUG — Algolia").font(.caption).bold()
//                        Text("index: \(lastIndex)").font(.caption2)
//                        Text("filters: \(lastFilters.isEmpty ? "(none)" : lastFilters)").font(.caption2)
//                        Text("query: \(lastQuery.isEmpty ? "(empty)" : lastQuery)").font(.caption2)
//                        if let e = lastErr {
//                            Text("error: \(e)").font(.caption2).foregroundStyle(.red)
//                        } else {
//                            Text("hits: \(total)").font(.caption2)
//                        }
//                    }
//                    .padding(8)
//                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
//                    .padding(.horizontal)
//                    .padding(.top, 6)
//                }
//                
//                if isLoading {  // ✅ show loader while fetching
//                    ThreeRectanglesAnimation(
//                        rectangleWidth: 40,
//                        rectangleMaxHeight: 130,
//                        rectangleSpacing: 7,
//                        rectangleCornerRadius: 6,
//                        animationDuration: animationDuration
//                    )
//                    .frame(height: 170)
//                    .padding(.top, 32)
//                } else if !hasFetched {
//                    // first render before any search kicked off
//                    Text("search the \(resolvedIndex) index…").padding(.top, 40)
//                } else if rows.isEmpty {
//                    Text("No results").padding(.top, 40)
//                } else {
//                    List(Array(rows.enumerated()), id: \.1.id) { (i, r) in
//                        rowContent(rows[i], isSelected: selectedRowIDs.contains(r.id))
//                            .onTapGesture {
//                                if step.selectable { togglePick(at: i) }
//                                else { openNext(at: i) }
//                            }
//                    }
//                    .listStyle(.plain)
//                }
//                Spacer(minLength: 0)
//            }
//        }
//        .onAppear { buildClient(); runSearch(trigger: "onAppear") }
//        .task(id: submitNonce) {
//            page = 0
//            runSearch(trigger: "onSubmit")
//        }
//        .id(resolvedIndex + "|" + resolvedFilters + "|" + (ctx.selectedButtonID ?? ctx.collectedIDs.first ?? ""))
//    }
//    
//    @ViewBuilder
//    private func rowContent(_ r: StepRow, isSelected: Bool) -> some View {
//        HStack(spacing: 12) {
//            AsyncImage(url: URL(string: r.imageURL ?? "")) { imagePhase in
//                switch imagePhase {
//                case .empty:  SkeletonView(Circle()).frame(width: 44, height: 44)
//                case .success(let img): img.resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
//                case .failure: Image(systemName: "photo").frame(width: 44, height: 44)
//                @unknown default: EmptyView()
//                }
//            }
//            VStack(alignment: .leading) {
//                Text(r.name).font(.custom("Nunito-Black", size: 15))
//                if let d = r.desc, !d.isEmpty {
//                    Text(d).font(.caption).foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//            Image(systemName: step.selectable
//                  ? (isSelected ? "checkmark.circle.fill" : "plus.circle")
//                  : "chevron.forward")
//            .foregroundStyle(step.selectable ? tint : .secondary)
//            .transition(.scale.combined(with: .opacity))
//        }
//        .contentShape(Rectangle())
//    }
//    
//    private func togglePick(at index: Int) {
//        let r = rows[index]
//        if selectedRowIDs.contains(r.id) {
//            selectedRowIDs.remove(r.id)
//            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
//            basket.toggleGeneric(r)
//        } else {
//            selectedRowIDs.insert(r.id)
//            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
//            basket.toggleGeneric(r)
//        }
//    }
//    
//    private func openNext(at index: Int) {
//        guard index < hits.count else { return }
//        let hit = hits[index]
//        let value = token(from: hit, using: step.algoliaGetField)
//        forwardIDs([value]) // parent will push next step (and keep your zoom transition)
//    }
//    
//    private func runSearch(trigger: String) {
//        hasFetched = true
//        lastErr = nil
//        guard let client else { print("❗️[ALG] \(trigger): no client"); return }
//        
//        isLoading = true                          // ✅ start
//        lastQuery = searchText
//        let offset = page * step.hitsPerPage
//        
//        print("🔎 [ALG] \(trigger) → index=\(resolvedIndex) | filters=\(resolvedFilters.isEmpty ? "(none)" : resolvedFilters) | query=\(searchText.isEmpty ? "(empty)" : "'\(searchText)'") | offset=\(offset) | length=\(step.hitsPerPage)")
//        
//        client.search(query: searchText, offset: offset, length: step.hitsPerPage) { newHits, nb in
//            DispatchQueue.main.async {
//                self.total = nb
//                self.hits  = newHits
//
//                self.rows = newHits.map { h in
//                    // prefer step templates; fall back to hit defaults
//                    let name = resolveTemplate(step.itemName, with: h) ?? h.name ?? "Unknown"
//                    let desc = resolveTemplate(step.itemDescription, with: h) ?? h.description
//                    let img  = resolveTemplate(step.itemImage, with: h) ?? h.image
//
//                    return StepRow(id: h.objectID, name: name, desc: desc, imageURL: img)
//                }
//
//                self.isLoading = false
//
//                if let first = newHits.first {
//                    print("✅ [ALG] got \(nb) hits (showing \(self.rows.count)). sample:")
//                    let sampleName = resolveTemplate(step.itemName, with: first) ?? first.name ?? "nil"
//                    let sampleDesc = resolveTemplate(step.itemDescription, with: first) ?? first.description ?? "nil"
//                    let sampleImg  = resolveTemplate(step.itemImage, with: first) ?? first.image ?? "nil"
//                    print("    objectID=\(first.objectID)")
//                    print("    name=\(sampleName) desc=\(sampleDesc) image=\(sampleImg)")
//                } else if !resolvedFilters.isEmpty {
//                    print("⚠️ [ALG] zero hits. if filtering, confirm faceting & field names (ItemCategory, ItemCategories.Continent). try quoting values: ItemCategory:'Country'")
//                }
//            }
//        }
//    }
//    
//    private func buildClient() {
//        lastIndex = resolvedIndex
//        lastFilters = resolvedFilters
//
//        // step overrides → fallback to Secrets if blank
//        var appID  = step.algoliaAppId.trimmingCharacters(in: .whitespacesAndNewlines)
//        var apiKey = step.algoliaAppKey.trimmingCharacters(in: .whitespacesAndNewlines)
//        if appID.isEmpty  { appID  = Secrets.algoliaAppID }
//        if apiKey.isEmpty { apiKey = Secrets.algoliaAPIKey }
//
//        // sanity check: real Algolia AppIDs are usually 10+ uppercase/digits
//        if appID.range(of: #"^[A-Z0-9]{8,}$"#, options: .regularExpression) == nil {
//            print("⚠️ [ALG] suspicious appID '\(appID)'. Did you pass a label (e.g. 'algolia_geography_id') instead of the real AppID?")
//        }
//
//        client = AlgoliaAddRecords<AlgoliaItemHit>(
//            AlgoliaAppID: appID,
//            AlgoliaAPIKey: apiKey,
//            AlgoliaIndex: resolvedIndex,
//            AlgoliaFilters: resolvedFilters.isEmpty ? nil : resolvedFilters,
//            AlgoliaQuery: "",
//            AlgoliaHitsPerPage: step.hitsPerPage
//        )
//
//        print("🔧 [ALG] buildClient → appID=\(appID), index=\(resolvedIndex), filters=\(resolvedFilters.isEmpty ? "(none)" : resolvedFilters), hpp=\(step.hitsPerPage)")
//    }
//}
//
//private struct FirebaseStepView: View {
//    let step: SubcategoryDestinationConfig
//    let tint: Color
//    let incomingIDs: [String]
//    let submitNonce: Int
//    let forwardIDs: ([String]) -> Void
//
//    @EnvironmentObject private var basket: SelectionBasket
//
//    @State private var page = 0
//    @State private var allIDs: [String] = []
//    @State private var rows: [StepRow] = []
//    @State private var total = 0
//    @State private var selectedRowIDs: Set<String> = []
//    
//    @State private var isLoading = true
//    @State private var hasFetched = false
//    private let animationDuration = 0.8
//
//    var body: some View {
//        VStack(spacing: 6) {
//            if isLoading {
//                ThreeRectanglesAnimation(
//                    rectangleWidth: 40,
//                    rectangleMaxHeight: 130,
//                    rectangleSpacing: 7,
//                    rectangleCornerRadius: 6,
//                    animationDuration: animationDuration
//                )
//                .frame(height: 170)
//                .padding(.top, 32)
//                .task { await buildIDsAndLoad() }   // kick off on first show
//            } else if hasFetched && (total == 0 || rows.isEmpty) {
//                // ✅ finished but nothing to show
//                Text("No Results").padding(.top, 40)
//            } else {
//                List(rows) { r in
//                    if step.selectable {
//                        rowContent(r, isSelected: selectedRowIDs.contains(r.id))
//                            .onTapGesture { togglePick(r) }
//                    } else {
//                        NavigationLink { Color.clear.frame(height: 1) } label: {
//                            rowContent(r, isSelected: false)
//                        }
//                        .simultaneousGesture(TapGesture().onEnded {
//                            print("➡️ [FB] tapped \(r.name) (\(r.id)) → forwarding IDs")
//                            forwardIDs([r.id])
//                        })
//                    }
//                }
//                .listStyle(.plain)
//                
//                if total > 0 {                 // ✅ hide pager when nothing to page
//                    Pager(total: total, pageSize: step.hitsPerPage, current: $page) {
//                        Task { await loadPage() }
//                    }
//                    .padding(.bottom, 6)
//                }
//            }
//            Spacer(minLength: 0)
//        }
//        .id("FB|\(step.id)|\(incomingIDs.first ?? "-")")
//        .onAppear {
//            // only kick off if first time; subsequent changes handled by onChange
//            if !hasFetched { Task { await buildIDsAndLoad() } }
//        }
//        .onChange(of: incomingIDs) { _, _ in Task { await buildIDsAndLoad() } }
//    }
//
//    // MARK: 🔎 DEBUG-ENHANCED FETCHING
//    private func buildIDsAndLoad() async {
//        isLoading = true                          // ✅ start
//        defer { isLoading = false; hasFetched = true }  // ✅ always end
//        
//        print("""
//            ─────────────── [FB] buildIDsAndLoad ───────────────
//            🔹 step: \(step.id)
//            🔹 idPath(raw): \(step.firebaseIdPath)
//            🔹 incomingIDs: \(incomingIDs)
//            """)
//        var ids: [String] = []
//        if !step.firebaseIdPath.isEmpty {
//            ids = await collectIDsFromIdPath(step.firebaseIdPath, seedIDs: incomingIDs)
//        } else {
//            ids = incomingIDs
//        }
//        
//        allIDs = ids
//        total = ids.count
//        print("✅ [FB] collected \(ids.count) IDs → \(ids.prefix(5))\(ids.count > 5 ? "…" : "")")
//        
//        // nothing to page → rows cleared; "No Results" will show
//        guard total > 0 else {
//            rows = []
//            return
//        }
//        
//        await loadPage()
//    }
//
//    private func loadPage() async {
//        isLoading = true                           // ✅ start page load
//        defer { isLoading = false; hasFetched = true } // ✅ done
//        
//        print("""
//            ─────────────── [FB] loadPage ───────────────
//            🔹 firebaseSearchPath(raw): \(step.firebaseSearchPath)
//            🔹 totalIDs: \(allIDs.count)
//            🔹 currentPage: \(page + 1)
//            """)
//        if step.firebaseSearchPath.contains("*") {
//            let pageIDs = paginateIDs(allIDs, page: page, size: step.hitsPerPage)
//            let paths = buildSearchPaths(for: pageIDs)
//            let fetched = await loadNodes(paths: paths)
//            rows = fetched
//            print("✅ [FB] loaded \(fetched.count) nodes from FirebaseSearchPath\n")
//        } else {
//            let fetched = await loadNodes(paths: [step.firebaseSearchPath])
//            rows = fetched
//            print("✅ [FB] loaded \(fetched.count) nodes from single node path\n")
//        }
//    }
//
//    private func togglePick(_ r: StepRow) {
//        if selectedRowIDs.contains(r.id) {
//            selectedRowIDs.remove(r.id)
//            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
//            basket.toggleGeneric(r)
//        } else {
//            selectedRowIDs.insert(r.id)
//            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
//            basket.toggleGeneric(r)
//        }
//    }
//
//    private func applyPreSuf(_ raw: String) -> String {
//        let up = step.firebasePreSuf.uppercased()
//        if up.contains("AFTER ' - '"), let range = raw.range(of: " - ") {
//            return String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
//        }
//        return raw
//    }
//
//    private func replaceAsterisk(in path: String, with id: String) -> String {
//        path.replacingOccurrences(of: "*", with: id)
//    }
//
//    private func collectIDsFromIdPath(_ idPath: String, seedIDs: [String]) async -> [String] {
//        let paths: [String] = idPath.contains("*")
//            ? seedIDs.map { replaceAsterisk(in: idPath, with: $0) }
//            : [idPath]
//
//        var out: [String] = []
//
//        await withTaskGroup(of: [String].self) { group in
//            for p in paths {
//                group.addTask {
//                    // Try DICT first
//                    return await withCheckedContinuation { cont in
//                        print("🔍 [FB] reading idPath: \(p)")
//                        readDict(p) { res in
//                            switch res {
//                            case .failure(let e):
//                                print("❌ [FB] idPath error @\(p): \(e.localizedDescription)")
//                                cont.resume(returning: [])
//                            case .success(let dictOpt):
//                                if let dict = dictOpt {
//                                    // DICT shape
//                                    var ids: [String] = []
//                                    switch step.firebaseKeyFieldValue {
//                                    case .key:
//                                        ids = dict.keys.map { applyPreSuf($0) }
//
//                                    case .value:
//                                        let field = step.firebaseField.trimmingCharacters(in: .whitespacesAndNewlines)
//                                        if field.isEmpty {
//                                            // Values are primitives; preserve numeric key order
//                                            let ordered = dict.sorted { (l, r) in
//                                                if let li = Int(l.key), let ri = Int(r.key) { return li < ri }
//                                                return l.key < r.key
//                                            }
//                                            ids = ordered.compactMap { _, v in
//                                                let s = "\(v)"; return s.isEmpty ? nil : applyPreSuf(s)
//                                            }
//                                        } else {
//                                            // Values are dicts; pull the field
//                                            let ordered = dict.sorted { (l, r) in
//                                                if let li = Int(l.key), let ri = Int(r.key) { return li < ri }
//                                                return l.key < r.key
//                                            }
//                                            ids = ordered.compactMap { _, v in
//                                                guard let d = v as? [String: Any], let val = d[field] else { return nil }
//                                                return applyPreSuf("\(val)")
//                                            }
//                                        }
//
//                                    case .none:
//                                        ids = []
//                                    }
//                                    print("✅ [FB] collected \(ids.count) IDs (DICT) from \(p)")
//                                    cont.resume(returning: ids)
//                                } else {
//                                    // No dict → try ARRAY
//                                    readArray(p) { arrRes in
//                                        switch arrRes {
//                                        case .failure(let e2):
//                                            print("❌ [FB] idPath array error @\(p): \(e2.localizedDescription)")
//                                            cont.resume(returning: [])
//                                        case .success(let arrOpt):
//                                            guard let arr = arrOpt else {
//                                                print("⚠️ [FB] idPath \(p) → no data (neither dict nor array)")
//                                                cont.resume(returning: [])
//                                                return
//                                            }
//                                            // ARRAY shape: [null, "id1", "id2", ...]
//                                            // Keep order, skip null/missing
//                                            var ids: [String] = []
//                                            ids.reserveCapacity(arr.count)
//                                            for (idx, v) in arr.enumerated() {
//                                                guard !(v is NSNull) else { continue }
//                                                let s = "\(v)"
//                                                guard !s.isEmpty else { continue }
//                                                ids.append(applyPreSuf(s))
//                                            }
//                                            print("✅ [FB] collected \(ids.count) IDs (ARRAY) from \(p) (first up to 5): \(ids.prefix(5))")
//                                            cont.resume(returning: ids)
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            for await ids in group { out.append(contentsOf: ids) }
//        }
//
//        // de-dupe, keep order
//        var seen = Set<String>()
//        return out.filter { seen.insert($0).inserted }
//    }
//
//    private func buildSearchPaths(for pageIDs: [String]) -> [String] {
//        step.firebaseSearchPath.contains("*")
//            ? pageIDs.map { replaceAsterisk(in: step.firebaseSearchPath, with: $0) }
//            : [step.firebaseSearchPath]
//    }
//
//    private func toRow(id: String, dict: [String: Any]) -> StepRow {
//        let name = renderTemplate(step.itemName, with: dict)
//        let desc = step.itemDescription.isEmpty ? nil : renderTemplate(step.itemDescription, with: dict)
//        let img  = step.itemImage.isEmpty ? nil : renderTemplate(step.itemImage, with: dict)
//        return StepRow(id: id, name: name, desc: desc, imageURL: img)
//    }
//
//    private func loadNodes(paths: [String]) async -> [StepRow] {
//        var out: [StepRow] = []
//        await withTaskGroup(of: [StepRow].self) { group in
//            for p in paths {
//                group.addTask {
//                    print("🔍 [FB] reading searchPath: \(p)")
//                    return await withCheckedContinuation { cont in
//                        readDict(p) { res in
//                            switch res {
//                            case .failure(let e):
//                                print("❌ [FB] searchPath error @\(p): \(e.localizedDescription)")
//                                cont.resume(returning: [])
//                            case .success(let dictOpt):
//                                guard let dict = dictOpt else {
//                                    print("⚠️ [FB] no data @\(p)")
//                                    cont.resume(returning: [])
//                                    return
//                                }
//                                let row = toRow(id: dict["id"] as? String ?? dict["objectID"] as? String ?? p, dict: dict)
//                                cont.resume(returning: [row])
//                            }
//                        }
//                    }
//                }
//            }
//            for await r in group { out.append(contentsOf: r) }
//        }
//        return out
//    }
//    
//    // MARK: - Row view
//    @ViewBuilder
//    private func rowContent(_ r: StepRow, isSelected: Bool) -> some View {
//        HStack(spacing: 12) {
//            AsyncImage(url: URL(string: r.imageURL ?? "")) { phase in
//                switch phase {
//                case .empty: SkeletonView(Circle()).frame(width: 44, height: 44)
//                case .success(let img): img.resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
//                case .failure: Image(systemName: "photo").frame(width: 44, height: 44)
//                @unknown default: EmptyView()
//                }
//            }
//            VStack(alignment: .leading, spacing: 2) {
//                Text(r.name).font(.custom("Nunito-Black", size: 15))
//                if let d = r.desc, !d.isEmpty {
//                    Text(d).font(.caption).foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//            Image(systemName: step.selectable
//                  ? (isSelected ? "checkmark.circle.fill" : "plus.circle")
//                  : "chevron.forward")
//            .foregroundStyle(step.selectable ? tint : .secondary)
//            .transition(.scale.combined(with: .opacity))
//        }
//        .contentShape(Rectangle())
//    }
//
//    private func paginateIDs(_ ids: [String], page: Int, size: Int) -> [String] {
//        let start = page * size
//        guard start < ids.count else { return [] }
//        let end = min(start + size, ids.count)
//        return Array(ids[start..<end])
//    }
//}
//
//
//private struct OpenLibraryStepView: View {
//    let step: SubcategoryDestinationConfig
//    let tint: Color
//    @Binding var ctx: FlowContext
//    @Binding var searchText: String
//    let submitNonce: Int
//    let onAdvance: ([String]) -> Void
//    let onJumpTo: (Int) -> Void
//
//    @EnvironmentObject private var basket: SelectionBasket
//
//    @State private var isLoading = false
//    @State private var hasFetched = false
//    @State private var total = 0
//    @State private var page = 0
//    @State private var rows: [StepRow] = []
//    @State private var selectedRowIDs: Set<String> = []
//
//    // we’ll piggyback `AlgoliaIndex` to choose mode: "BooksSearch", "AuthorsSearch", "AuthorWorks"
//    private var mode: String { step.algoliaIndex.isEmpty ? "BooksSearch" : step.algoliaIndex }
//
//    var body: some View {
//        VStack(spacing: 6) {
//            if isLoading {
//                ThreeRectanglesAnimation(
//                    rectangleWidth: 40,
//                    rectangleMaxHeight: 130,
//                    rectangleSpacing: 7,
//                    rectangleCornerRadius: 6,
//                    animationDuration: 0.8
//                )
//                .frame(height: 170)
//                .padding(.top, 32)
//            } else if hasFetched && rows.isEmpty {
//                Text("\(step.algoliaGetField)")
//                    .font(.custom("Nunito-Black", size: 14))
//                    .padding(.top, 40)
//            } else {
//                List(rows) { r in
//                    rowContent(r, isSelected: selectedRowIDs.contains(r.id))
//                        .onTapGesture {
//                            if step.selectable {
//                                togglePick(r)
//                            } else {
//                                // non-selectable → forward token(s) to next step
//                                onAdvance([r.id])
//                            }
//                        }
//                }
//                .listStyle(.plain)
//
//                if total > 0 {
//                    Pager(total: total, pageSize: step.hitsPerPage, current: $page) {
//                        Task { await runFetch(trigger: "pager") }
//                    }
//                    .padding(.bottom, 6)
//                }
//            }
//            Spacer(minLength: 0)
//        }
//        .task(id: submitNonce) {
//            page = 0
//            await runFetch(trigger: "submit")
//        }
//        .onAppear {
//            Task { await runFetch(trigger: "appear") }
//        }
//    }
//
//    @ViewBuilder
//    private func rowContent(_ r: StepRow, isSelected: Bool) -> some View {
//        HStack(spacing: 12) {
//            AsyncImage(url: URL(string: r.imageURL ?? "")) { phase in
//                switch phase {
//                case .empty:  SkeletonView(Circle()).frame(width: 44, height: 44)
//                case .success(let img): img.resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8)).background(Image("ItemPlaceholder").resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8)))
//                case .failure: Image("ItemPlaceholder").resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
//                @unknown default: Image("ItemPlaceholder").resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
//                }
//            }
//            VStack(alignment: .leading, spacing: 2) {
//                Text(r.name).font(.custom("Nunito-Black", size: 15))
//                if let d = r.desc, !d.isEmpty {
//                    Text(d).font(.caption).foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//            Image(systemName: step.selectable
//                  ? (isSelected ? "checkmark.circle.fill" : "plus.circle")
//                  : "chevron.forward")
//            .foregroundStyle(step.selectable ? tint : .secondary)
//            .transition(.scale.combined(with: .opacity))
//        }
//        .contentShape(Rectangle())
//    }
//
//    private func togglePick(_ r: StepRow) {
//        if selectedRowIDs.contains(r.id) {
//            selectedRowIDs.remove(r.id)
//            basket.toggleGeneric(r)
//        } else {
//            selectedRowIDs.insert(r.id)
//            basket.toggleGeneric(r)
//        }
//    }
//
//    // MARK: Fetch
//    private func currentURL() -> URL? {
//        // sanitize input; OpenLibrary expects + for spaces; keep simple here
//        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
//        let encoded = q.replacingOccurrences(of: " ", with: "+")
//        let limit = max(1, step.hitsPerPage)
//        let offset = page * limit
//
//        switch mode {
//        case "BooksSearch":
//            // /search.json?q=...&page=1&limit=15 uses page not offset; derive page from offset/limit
//            let p = (offset / limit) + 1
//            return URL(string: "https://openlibrary.org/search.json?q=\(encoded)&page=\(p)&limit=\(limit)&sort=rating")
//
//        case "AuthorsSearch":
//            // authors endpoint
//            let p = (offset / limit) + 1
//            return URL(string: "https://openlibrary.org/search/authors.json?q=\(encoded)&page=\(p)&limit=\(limit)&work_count,desc")
//
//        case "AuthorWorks":
//            // needs an author key from ctx.collectedIDs/selectedButtonID
//            guard let authorKey = ctx.collectedIDs.first ?? ctx.selectedButtonID, !authorKey.isEmpty else { return nil }
//            // works uses offset, not page
//            return URL(string: "https://openlibrary.org/authors/\(authorKey)/works.json?limit=\(limit)&offset=\(offset)&sort=rating")
//
//        default:
//            // fallback to BooksSearch
//            let p = (offset / limit) + 1
//            return URL(string: "https://openlibrary.org/search.json?q=\(encoded)&page=\(p)&limit=\(limit)&sort=rating")
//        }
//    }
//
//    private func coverURLFromID(_ id: Int?) -> String? {
//        guard let id, id > 0 else { return nil }
//        return "https://covers.openlibrary.org/b/id/\(id)-L.jpg"
//    }
//
//    private func authorPhotoURL(_ authorKey: String) -> String {
//        "https://covers.openlibrary.org/a/olid/\(authorKey)-L.jpg"
//    }
//
//    private func runFetch(trigger: String) async {
//        hasFetched = true
//        isLoading = true
//        defer { isLoading = false }
//
//        guard let url = currentURL() else {
//            rows = []
//            total = 0
//            return
//        }
//
//        do {
//            let (data, _) = try await URLSession.shared.data(from: url)
//            // decode loosely
//            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
//
//            switch mode {
//            case "BooksSearch":
//                let docs = (json["docs"] as? [[String: Any]]) ?? []
//                total = (json["numFound"] as? Int) ?? docs.count
//                rows = docs.map { d in
//                    let title = (d["title"] as? String) ?? "Unknown"
//                    let authors = (d["author_name"] as? [String])?.joined(separator: ", ")
//                    let coverI = d["cover_i"] as? Int
//                    let image = coverURLFromID(coverI)
//                    // id: prefer work key if present, else title
//                    let workKey = (d["key"] as? String) ?? title
//                    return StepRow(id: workKey, name: title, desc: authors, imageURL: image)
//                }
//
//            case "AuthorsSearch":
//                let docs = (json["docs"] as? [[String: Any]]) ?? []
//                total = (json["numFound"] as? Int) ?? docs.count
//                rows = docs.map { d in
//                    let name = (d["name"] as? String) ?? "Unknown"
//                    let key  = (d["key"] as? String) ?? name // e.g. "OL23919A"
//                    let top  = (d["top_work"] as? String)
//                    let img  = authorPhotoURL(key)
//                    return StepRow(id: key, name: name, desc: top, imageURL: img)
//                }
//
//            case "AuthorWorks":
//                let size = (json["size"] as? Int) ?? 0
//                total = size
//                let entries = (json["entries"] as? [[String: Any]]) ?? []
//                rows = entries.map { e in
//                    let title = (e["title"] as? String) ?? "Untitled"
//                    let key = (e["key"] as? String) ?? UUID().uuidString // "/works/OLxxxxW"
//                    return StepRow(id: key, name: title, desc: nil, imageURL: nil)
//                }
//
//            default:
//                rows = []
//                total = 0
//            }
//        } catch {
//            rows = []
//            total = 0
//            print("❌ [OL] \(error.localizedDescription)")
//        }
//    }
//}
//
//
//private struct Pager: View {
//    let total: Int
//    let pageSize: Int
//    @Binding var current: Int
//    var onSelect: () -> Void
//
//    var body: some View {
//        let totalPages = max(1, (total + pageSize - 1) / pageSize)
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 6) {
//                ForEach(0..<totalPages, id: \.self) { idx in
//                    Button {
//                        current = idx
//                        onSelect()
//                    } label: {
//                        Text("\(idx + 1)")
//                            .font(.caption2)
//                            .frame(width: 26, height: 26)
//                            .background(idx == current ? Color.blue : Color.white)
//                            .foregroundColor(idx == current ? .white : .black)
//                            .cornerRadius(4)
//                    }
//                }
//            }
//            .padding(.horizontal, 10)
//        }
//        .frame(height: 32)
//    }
//}
//
//// MARK: - Subcategory data per category (NEW)
//private let SUBCATEGORIES: [String: [AppSubcategory]] = [
//    "Music": [
//        .init(
//            name: "Artists",
//            symbol: "person.crop.square",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Music",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "objectID",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(followers) Spotify Followers",
//                ItemImage: "(images)",
//                Buttons: []
//            ),
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//            // buttonRoutes: nil  // (optional if your struct gives this a default)
//        ),
//        .init(
//            name: "Albums",
//            symbol: "square.stack",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Music",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "objectID",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: false,
//                ItemName: "(name)",
//                ItemDescription: "(popularity) Popularity",
//                ItemImage: "(images)",
//                Buttons: []
//            ),
//            step2: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "ItemData/Music/Artists/*/discography/albums",
//                FirebaseKeyFieldValue: "key",
//                FirebaseField: "",
//                FirebasePreSuf: "AFTER ' - '",
//                FirebaseSearchPath: "ItemData/Music/Albums/*",
//                HitsPerPage: 50,
//                SearchBar: false,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(artists)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Tracks",
//            symbol: "music.note.list",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Music",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "objectID",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 25,
//                SearchBar: true,
//                Selectable: false, // collect artistID -> feed buttons -> feed firebase
//                ItemName: "(name)",
//                ItemDescription: "(followers) Spotify Followers",
//                ItemImage: "(images)",
//                Buttons: []
//            ),
//            step2: SubcategoryDestinationConfig(
//                ViewType: "Buttons",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: [
//                    .init(id: "albumTracks",  name: "Search for Album Tracks", icon: "person.fill"),
//                    .init(id: "singleTracks", name: "Search for Singles",      icon: "music.note.list"),
//                    .init(id: "allTracks",    name: "Search All Tracks",       icon: "music.quarternote.3")
//                ]
//            ),
//            step3: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "ItemData/Music/Artists/*/discography/tracks",
//                FirebaseKeyFieldValue: "key",
//                FirebaseField: "",
//                FirebasePreSuf: "AFTER ' - '",
//                FirebaseSearchPath: "ItemData/Music/Tracks/*",
//                HitsPerPage: 50,
//                SearchBar: false,
//                Selectable: true, // just pass album IDs forward to step4
//                ItemName: "(name)",
//                ItemDescription: "(artists)",
//                ItemImage: "(album_cover)",
//                Buttons: []
//            ),
//            step4: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "ItemData/Music/Artists/*/discography/singles",
//                FirebaseKeyFieldValue: "key",
//                FirebaseField: "",
//                FirebasePreSuf: "AFTER ' - '",
//                FirebaseSearchPath: "ItemData/Music/Tracks/*",
//                HitsPerPage: 50,
//                SearchBar: false,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(artists)",
//                ItemImage: "(album_cover)",
//                Buttons: []
//            ),
//            step5: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "ItemData/Music/Artists/*/discography/albums",
//                FirebaseKeyFieldValue: "key",
//                FirebaseField: "",
//                FirebasePreSuf: "AFTER ' - '",
//                FirebaseSearchPath: "ItemData/Music/Albums/*",
//                HitsPerPage: 50,
//                SearchBar: false,
//                Selectable: false, // just pass album IDs forward to step4
//                ItemName: "(name)",
//                ItemDescription: "(artists)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            step6: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "ItemData/Music/Albums/*/tracks",
//                FirebaseKeyFieldValue: "value",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "ItemData/Music/Tracks/*",
//                HitsPerPage: 50,
//                SearchBar: false,
//                Selectable: true, // just pass album IDs forward to step4
//                ItemName: "(name)",
//                ItemDescription: "Artists: (artists)",
//                ItemImage: "(album_cover)",
//                Buttons: []
//            ),
//            step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: [ "albumTracks": 5, "singleTracks": 4, "allTracks": 3]
//        ),
//        .init(
//            name: "Genres",
//            symbol: "square.stack.3d.up.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Sport": [
//        .init(
//            name: "Athletes",
//            symbol: "figure.run",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        
//        .init(
//            name: "Leagues & Tournaments",
//            symbol: "trophy.fill",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Sport",
//                AlgoliaFilters: "ItemCategory:'League' AND Sport:'Football'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 25,
//                SearchBar: true,
//                Selectable: true, // collect artistID -> feed buttons -> feed firebase
//                ItemName: "(ItemName)",
//                ItemDescription: "(country)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        
//        .init(
//            name: "Clubs/Teams",
//            symbol: "shield.lefthalf.filled",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Sport",
//                AlgoliaFilters: "ItemCategory:'Club' AND Sport:'Football'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 25,
//                SearchBar: true,
//                Selectable: true, // collect artistID -> feed buttons -> feed firebase
//                ItemName: "(ItemName)",
//                ItemDescription: "(country)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//    
//        .init(
//            name: "Stadiums",
//            symbol: "sportscourt.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//    
//        .init(
//            name: "Commentators",
//            symbol: "headset",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//    
//        .init(
//            name: "Gym",
//            symbol: "dumbbell.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//    
//        .init(
//            name: "Coaches & Managers",
//            symbol: "megaphone.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Food & Drink": [
//        .init(
//            name: "Food",
//            symbol: "fork.knife",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Firebase",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "ItemData/Information/Food_Drink",
//                HitsPerPage: 25,
//                SearchBar: true,
//                Selectable: false, // collect artistID -> feed buttons -> feed firebase
//                ItemName: "(name)",
//                ItemDescription: "(filter)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Beverages",
//            symbol: "drop.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Animals": [
//        .init(
//            name: "All Species",
//            symbol: "pawprint.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Dog Breeds",
//            symbol: "dog.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Cat Breeds",
//            symbol: "cat.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//
//    "Geography": [
//        .init(
//            name: "Countries",
//            symbol: "globe.europe.africa.fill",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Buttons",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: [
//                    .init(id: "AllCountries", name: "All Countries",   icon: "flag.fill"),
//                    .init(id: "ByContinent",  name: "Search By Continent", icon: "globe.americas.fill")
//                ]
//            ),
//            // Step 2 (All Countries)
//            step2: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Country",
//                AlgoliaGetField: "objectID",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            // Step 3 (Choose Continent → collect ItemName)
//            step3: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Continent",
//                AlgoliaGetField: "name", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: false,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            // Step 4 (Countries filtered by chosen continent; '*' replaced with collected ItemName)
//            step4: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Country AND description:'*'",
//                AlgoliaGetField: "objectID",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil,
//            // Branch step 2 based on the button picked in step 1:
//            buttonRoutes: [ "AllCountries": 2, "ByContinent": 3 ]
//        ),
//        .init(
//            name: "Continents",
//            symbol: "globe",
//            bg: .clear,
//            availability: true,
//            // Step 3 (Choose Continent → collect ItemName)
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Continent",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ),
//            // Step 4 (Countries filtered by chosen continent; '*' replaced with collected ItemName)
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Cities",
//            symbol: "building.fill",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Buttons",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 0,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: [
//                    .init(id: "AllCities", name: "Search All Cities",   icon: "building.2.fill"),
//                    .init(id: "ByCountries",  name: "Search Cities By Country", icon: "globe.americas.fill"),
//                    .init(id: "ByContinent",  name: "Search Cities By Continent", icon: "globe")
//                ]
//            ), step2: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:City",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step3: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Country",
//                AlgoliaGetField: "name", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: false,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step4: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:City AND description:*",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step5: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:Continent",
//                AlgoliaGetField: "name", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: false,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step6: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.geographyAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.geographyAlgoliaAPIKey)",
//                AlgoliaIndex: "Geography",
//                AlgoliaFilters: "category:City AND continent:*",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(description)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: [ "AllCities": 2, "ByCountries": 3, "ByContinent": 5 ]
//        ),
//        .init(
//            name: "Landmarks",
//            symbol: "building.columns.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "People": [
//        .init(
//            name: "All People",
//            symbol: "person.2.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Films & Series": [
//        .init(
//            name: "All Films & Series",
//            symbol: "popcorn.fill",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.entertainmentAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.entertainmentAlgoliaAPIKey)",
//                AlgoliaIndex: "Films_Shows",
//                AlgoliaFilters: "",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(category)",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Films",
//            symbol: "video.fill",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.entertainmentAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.entertainmentAlgoliaAPIKey)",
//                AlgoliaIndex: "Films_Shows",
//                AlgoliaFilters: "category:Film",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(runtime) mins",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Series",
//            symbol: "tv",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "\(Secrets.entertainmentAlgoliaAppID)",
//                AlgoliaAppKey: "\(Secrets.entertainmentAlgoliaAPIKey)",
//                AlgoliaIndex: "Films_Shows",
//                AlgoliaFilters: "category:Show",
//                AlgoliaGetField: "", // collect this for next filter
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 20,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(name)",
//                ItemDescription: "(number_of_seasons) Season/s",
//                ItemImage: "(image)",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Books": [
//        .init(
//            name: "Books",
//            symbol: "book.closed.fill",
//            bg: .clear,
//            availability: true,
//
//            // STEP 1: Buttons
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Buttons",
//                AlgoliaAppID: "", AlgoliaAppKey: "",
//                AlgoliaIndex: "", AlgoliaFilters: "", AlgoliaGetField: "",
//                FirebaseIdPath: "", FirebaseKeyFieldValue: "", FirebaseField: "", FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 15,
//                SearchBar: false,
//                Selectable: false,
//                ItemName: "", ItemDescription: "", ItemImage: "",
//                Buttons: [
//                    .init(id: "1", name: "Search by Book Name, ISBN ++", icon: "text.magnifyingglass"),
//                    .init(id: "2", name: "Search Author's Books",        icon: "person.text.rectangle")
//                ]
//            ),
//
//            // STEP 2: OpenLibrary Books search (triggered by button id "1")
//            step2: SubcategoryDestinationConfig(
//                ViewType: "OpenLibrary",
//                AlgoliaAppID: "", AlgoliaAppKey: "",
//                AlgoliaIndex: "BooksSearch", // <- mode selector
//                AlgoliaFilters: "", AlgoliaGetField: "Search from 20 Million OpenLibrary Books by Title, Author, ISBN, OCLC, LCCN & OLID",
//                FirebaseIdPath: "", FirebaseKeyFieldValue: "", FirebaseField: "", FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 15,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "(title)",                                  // used only if you template; OpenLibraryStepView maps directly
//                ItemDescription: "(author_name)",                     // authors joined by ", "
//                ItemImage: "https://covers.openlibrary.org/b/id/(cover_i)-L.jpg",
//                Buttons: []
//            ),
//
//            // STEP 3: OpenLibrary Authors search (triggered by button id "2")
//            step3: SubcategoryDestinationConfig(
//                ViewType: "OpenLibrary",
//                AlgoliaAppID: "", AlgoliaAppKey: "",
//                AlgoliaIndex: "AuthorsSearch", // <- mode selector
//                AlgoliaFilters: "", AlgoliaGetField: "Search from 20 Million OpenLibrary Books by Author in OpenLibrary",
//                FirebaseIdPath: "", FirebaseKeyFieldValue: "", FirebaseField: "", FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 15,
//                SearchBar: true,
//                Selectable: false, // selecting an author should push to their works step
//                ItemName: "(name)",
//                ItemDescription: "(top_work)",
//                ItemImage: "https://covers.openlibrary.org/a/olid/(key)-L.jpg",
//                Buttons: []
//            ),
//
//            // STEP 4: OpenLibrary Author works (non-selectable → forwards works’ keys)
//            step4: SubcategoryDestinationConfig(
//                ViewType: "OpenLibrary",
//                AlgoliaAppID: "", AlgoliaAppKey: "",
//                AlgoliaIndex: "AuthorWorks", // <- mode selector
//                AlgoliaFilters: "", AlgoliaGetField: "This Author has No Novels or Non-Fiction Works in OpenLibrary",
//                FirebaseIdPath: "", FirebaseKeyFieldValue: "", FirebaseField: "", FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 15,
//                SearchBar: true,
//                Selectable: true, // allow picking works into basket
//                ItemName: "(title)",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ),
//
//            // rest of steps unused
//            step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil,
//            step11: nil, step12: nil, step13: nil, step14: nil, step15: nil,
//
//            // Button routes: "1" → step2, "2" → step3
//            buttonRoutes: ["1": 2, "2": 3]
//        ),
//        .init(
//            name: "Authors",
//            symbol: "person.crop.square.fill",
//            bg: .clear,
//            availability: true,
//
//            // STEP 1: OpenLibrary Authors search
//            step1: SubcategoryDestinationConfig(
//                ViewType: "OpenLibrary",
//                AlgoliaAppID: "", AlgoliaAppKey: "",
//                AlgoliaIndex: "AuthorsSearch",
//                AlgoliaFilters: "", AlgoliaGetField: "Search from Over 500,000 Authors on OpenLibrary",
//                FirebaseIdPath: "", FirebaseKeyFieldValue: "", FirebaseField: "", FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 15,
//                SearchBar: true,
//                Selectable: true, // tap → goes to works
//                ItemName: "(name)",
//                ItemDescription: "(top_work)",
//                ItemImage: "https://covers.openlibrary.org/a/olid/(key)-L.jpg",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Gaming": [
//        .init(
//            name: "All Games",
//            symbol: "gamecontroller.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Clash Royale",
//            symbol: "figure.archery",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "History": [
//        .init(
//            name: "Wars",
//            symbol: "burst.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Landmarks",
//            symbol: "building.columns.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Plants": [
//        .init(
//            name: "Trees",
//            symbol: "tree.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Flowers",
//            symbol: "microbe.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Science": [
//        .init(
//            name: "Elements",
//            symbol: "atom",
//            bg: .clear,
//            availability: false,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Science",
//                AlgoliaFilters: "ItemCategory:'Element'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Planets",
//            symbol: "circle.hexagonpath.fill",
//            bg: .clear,
//            availability: false,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Science",
//                AlgoliaFilters: "ItemCategory:'Planet'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ), step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Vehicles": [
//        .init(
//            name: "Cars",
//            symbol: "car.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Planes",
//            symbol: "airplane",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Brands": [
//        .init(
//            name: "Fast Food",
//            symbol: "takeoutbag.and.cup.and.straw.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Technology",
//            symbol: "cpu.fill",
//            bg: .clear,
//            availability: false,
//            step1: nil, step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ],
//    
//    "Miscellaneous": [
//        .init(
//            name: "Programming Languages",
//            symbol: "curlybraces",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Other",
//                AlgoliaFilters: "ItemCategory:'Programming Language'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ),
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Alphabet",
//            symbol: "abc",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Other",
//                AlgoliaFilters: "ItemCategory:'Letter'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ),
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Numbers",
//            symbol: "textformat.123",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Other",
//                AlgoliaFilters: "ItemCategory:'Number'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ),
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        ),
//        .init(
//            name: "Roman Numerals",
//            symbol: "xmark",
//            bg: .clear,
//            availability: true,
//            step1: SubcategoryDestinationConfig(
//                ViewType: "Algolia",
//                AlgoliaAppID: "",
//                AlgoliaAppKey: "",
//                AlgoliaIndex: "Other",
//                AlgoliaFilters: "ItemCategory:'Roman Numeral'",
//                AlgoliaGetField: "",
//                FirebaseIdPath: "",
//                FirebaseKeyFieldValue: "",
//                FirebaseField: "",
//                FirebasePreSuf: "",
//                FirebaseSearchPath: "",
//                HitsPerPage: 50,
//                SearchBar: true,
//                Selectable: true,
//                ItemName: "",
//                ItemDescription: "",
//                ItemImage: "",
//                Buttons: []
//            ),
//            step2: nil, step3: nil, step4: nil, step5: nil, step6: nil, step7: nil, step8: nil, step9: nil, step10: nil, step11: nil, step12: nil, step13: nil, step14: nil, step15: nil, buttonRoutes: nil
//        )
//    ]
//]
//
//struct AddItemsPickerSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @Binding var selectedRankoItems: [RankoItem]
//
//    // A fresh basket for the picker
//    @StateObject private var basket = SelectionBasket()
//
//    var body: some View {
//        NavigationStack {
//            CategoriesView(basket: basket) { picked in
//                append(picked)
//                dismiss()
//            }
//            .environmentObject(basket)
//        }
//    }
//
//    private func append(_ picked: [StepRow]) {
//        // Append *after* the last existing rank, preserving order
//        var nextRank = (selectedRankoItems.map { $0.rank }.max() ?? 0) + 1
//
//        for r in picked {
//            let rec = RankoRecord(
//                objectID: r.id,
//                ItemName: r.name,
//                ItemDescription: r.desc ?? "",
//                ItemCategory: "",
//                ItemImage: r.imageURL ?? placeholderItemURL,
//                ItemGIF: nil,
//                ItemVideo: nil,
//                ItemAudio: nil
//            )
//            let newItem = RankoItem(
//                id: UUID().uuidString,
//                rank: nextRank,
//                votes: 0,
//                record: rec,
//                playCount: 0
//            )
//            selectedRankoItems.append(newItem)
//            nextRank += 1
//        }
//    }
//}
//
//private let placeholderItemURL =
//  "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//// If you have control, actually add this in the enum definition:
//// case openLibrary
//
//// MARK: - 2) SubcategoryDestinationConfig extension (optional hint)
//// If you want to explicitly drive the initial OpenLibrary mode from config,
//// add an optional hint to your config type.
//// struct SubcategoryDestinationConfig { ... add: let openLibraryModeHint: String? }
//// Supported values: "books", "authors", "authorWorks"
//
//// MARK: - 3) OpenLibrary data models
//struct OLBookHit: Decodable, Identifiable {
//    // From /search.json docs[] entries
//    let key: String?            // e.g. "/works/OL27479W"
//    let title: String?
//    let author_name: [String]?
//    let cover_i: Int?
//    var id: String { key ?? UUID().uuidString }
//}
//
//struct OLBookSearchResponse: Decodable {
//    let numFound: Int?
//    let docs: [OLBookHit]?
//}
//
//struct OLAuthorHit: Decodable, Identifiable {
//    // From /search/authors.json docs[] entries
//    let key: String             // e.g. "OL23919A"
//    let name: String?
//    let top_work: String?
//    var id: String { key }
//}
//
//struct OLAuthorSearchResponse: Decodable {
//    let numFound: Int?
//    let docs: [OLAuthorHit]?
//}
//
//struct OLAuthorWorksResponse: Decodable {
//    let size: Int?          // total number of works
//    let entries: [OLWork]?
//}
//
//struct OLWork: Decodable, Identifiable {
//    let key: String         // e.g. "/works/OL40370366W"
//    let title: String?
//    var id: String { key }
//}
//
//// MARK: - 4) OpenLibrary client
//enum OpenLibraryMode: Equatable, Hashable {
//    case booksSearch                    // /search.json?q=...&page=1&limit=15
//    case authorsSearch                  // /search/authors.json?q=...&page=1&limit=15
//    case authorWorks(authorKey: String, authorName: String) // /authors/{key}/works.json?limit=100&offset=0
//}
//
//struct OpenLibraryClient {
//    static func searchBooks(query: String, page: Int, limit: Int) async throws -> OLBookSearchResponse {
//        let q = query.isEmpty ? "" : query.replacingOccurrences(of: " ", with: "+")
//        let url = URL(string: "https://openlibrary.org/search.json?q=\(q)&page=\(page)&limit=\(limit)&sort=rating")!
//        let (data, _) = try await URLSession.shared.data(from: url)
//        return try JSONDecoder().decode(OLBookSearchResponse.self, from: data)
//    }
//
//    static func searchAuthors(query: String, page: Int, limit: Int) async throws -> OLAuthorSearchResponse {
//        let q = query.isEmpty ? "" : query.replacingOccurrences(of: " ", with: "%20")
//        let url = URL(string: "https://openlibrary.org/search/authors.json?q=\(q)&page=\(page)&limit=\(limit)&work_count,desc")!
//        let (data, _) = try await URLSession.shared.data(from: url)
//        return try JSONDecoder().decode(OLAuthorSearchResponse.self, from: data)
//    }
//
//    static func authorWorks(authorKey: String, offset: Int, limit: Int) async throws -> OLAuthorWorksResponse {
//        let url = URL(string: "https://openlibrary.org/authors/\(authorKey)/works.json?limit=\(limit)&offset=\(offset)&sort=rating")!
//        let (data, _) = try await URLSession.shared.data(from: url)
//        return try JSONDecoder().decode(OLAuthorWorksResponse.self, from: data)
//    }
//}
//
//// MARK: - 5) Helpers for images & formatting
//func openLibraryCoverURL(cover_i: Int?, size: String = "L") -> URL? {
//    guard let id = cover_i else { return nil }
//    return URL(string: "https://covers.openlibrary.org/b/id/\(id)-\(size).jpg")
//}
//
//func openLibraryAuthorPhotoURL(authorKey: String, size: String = "L") -> URL? {
//    URL(string: "https://covers.openlibrary.org/a/olid/\(authorKey)-\(size).jpg")
//}
//
//func authorsJoined(_ names: [String]?) -> String {
//    (names ?? []).joined(separator: ", ")
//}
//
//// MARK: - 7) Row / List subviews
//private struct BookRow: View {
//    let hit: OLBookHit
//    var body: some View {
//        HStack(alignment: .top, spacing: 12) {
//            AsyncImage(url: openLibraryCoverURL(cover_i: hit.cover_i)) { img in
//                img.resizable().scaledToFill()
//            } placeholder: { Color.gray.opacity(0.2) }
//            .frame(width: 64, height: 64)
//            .clipShape(RoundedRectangle(cornerRadius: 12))
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text(hit.title ?? "(Untitled)")
//                    .font(.headline)
//                let a = authorsJoined(hit.author_name)
//                if !a.isEmpty {
//                    Text(a).font(.subheadline).foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//        }
//    }
//}
//
//private struct AuthorRow: View {
//    let author: OLAuthorHit
//    var body: some View {
//        HStack(spacing: 12) {
//            AsyncImage(url: openLibraryAuthorPhotoURL(authorKey: author.key)) { img in
//                img.resizable().scaledToFill()
//            } placeholder: { Color.gray.opacity(0.2) }
//            .frame(width: 64, height: 64)
//            .clipShape(RoundedRectangle(cornerRadius: 12))
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text(author.name ?? "(Unknown author)")
//                    .font(.headline)
//                if let top = author.top_work, !top.isEmpty {
//                    Text(top).font(.subheadline).foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//        }
//    }
//}
//
//private struct AuthorWorksList: View {
//    let works: [OLWork]
//    var body: some View {
//        List(works) { w in
//            Text(w.title ?? "(Untitled work)")
//        }
//        .listStyle(.plain)
//    }
//}
//
//private struct PagingBar: View {
//    @Binding var page: Int
//    let totalHits: Int
//    let perPage: Int
//    let onJump: (Int) -> Void
//
//    private var pageCount: Int {
//        guard perPage > 0, totalHits > 0 else { return 0 }
//        return Int(ceil(Double(totalHits) / Double(perPage)))
//    }
//
//    var body: some View {
//        if pageCount > 1 {
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 8) {
//                    ForEach(1...pageCount, id: \.self) { p in
//                        Button(action: { page = p; onJump(p) }) {
//                            Text("\(p)")
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 6)
//                                .background(p == page ? Color.secondary.opacity(0.2) : Color.clear)
//                                .clipShape(Capsule())
//                        }
//                    }
//                }.padding(8)
//            }
//        }
//    }
//}
//
//// MARK: - 8) AuthorWorksView (offset-based pagination 100 per page)
//struct AuthorWorksView: View, Identifiable {
//    let id = UUID()
//    let authorKey: String
//    let authorName: String
//
//    @State private var works: [OLWork] = []
//    @State private var total: Int = 0
//    @State private var offset: Int = 0
//    @State private var isLoading = false
//    @State private var errorText: String? = nil
//
//    private let limit = 15
//
//    var body: some View {
//        VStack(spacing: 0) {
//            if isLoading { ProgressView().padding() }
//            if let errorText { Text(errorText).foregroundStyle(.red).padding() }
//
//            List(works) { w in
//                Text(w.title ?? "(Untitled work)")
//            }
//            .listStyle(.plain)
//
//            if total > works.count {
//                Button(action: loadMore) {
//                    HStack { Spacer(); Text("Load more"); Spacer() }
//                }
//                .padding()
//            }
//        }
//        .navigationTitle(authorName)
//        .onAppear { Task { await fetch(initial: true) } }
//    }
//
//    private func fetch(initial: Bool) async {
//        if isLoading { return }
//        isLoading = true
//        errorText = nil
//        defer { isLoading = false }
//        do {
//            let resp = try await OpenLibraryClient.authorWorks(authorKey: authorKey, offset: offset, limit: limit)
//            let chunk = resp.entries ?? []
//            self.total = resp.size ?? max(total, works.count + chunk.count)
//            if initial { self.works = chunk } else { self.works += chunk }
//        } catch {
//            self.errorText = error.localizedDescription
//        }
//    }
//
//    private func loadMore() {
//        offset += limit
//        Task { await fetch(initial: false) }
//    }
//}
//
//// MARK: - 9) Buttons step for Books step1
//struct BooksButtonsStepView: View {
//    let onPick: (Int) -> Void
//
//    var body: some View {
//        List {
//            Button {
//                onPick(1)
//            } label: {
//                VStack(alignment: .leading, spacing: 6) {
//                    Text("Search by Book Name, ISBN ++")
//                        .font(.headline)
//                    Text("Type Book Name, ISBN, or Author's Name in the Search Bar")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                }
//            }
//
//            Button {
//                onPick(2)
//            } label: {
//                VStack(alignment: .leading, spacing: 6) {
//                    Text("Search Author's Books")
//                        .font(.headline)
//                    Text("Find an author, then view all works")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                }
//            }
//        }
//        .listStyle(.insetGrouped)
//        .navigationTitle("Books")
//    }
//}
//
//// MARK: - 10) Integration hooks in your step router
//// In your SubcategoryDestinationView where you switch on step.viewType, add a case:
////    case .openLibrary: buildOpenLibrary(step: step, ctx: ctx, stepIndex: idx)
//
//// Example helper for deciding the initial OpenLibraryMode
//func decideOLModeForBooks(stepIndex: Int, selectedButtonID: String?) -> OpenLibraryMode {
//    // Books step1 = buttons, step2 = open library
//    // If button id 1 → book search; id 2 → author search
//    if stepIndex == 2 {
//        if selectedButtonID == "2" { return .authorsSearch }
//        return .booksSearch
//    }
//    return .booksSearch
//}
//
//func decideOLModeForAuthors(stepIndex: Int) -> OpenLibraryMode {
//    // Authors subcategory: step1 = open library authors
//    return .authorsSearch
//}
