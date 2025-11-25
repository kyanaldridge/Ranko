//  AddSampleItems_Firestore.swift
//  RankoApp
//
//  Clean Firestore-backed rewrite of AddSampleItems.swift
//  - Removes hardcoded CATEGORIES / SUBCATEGORIES
//  - Loads categories & subcategories dynamically from Firestore (AppData/Filters)
//  - Replaces legacy Realtime Database step with Firestore queries
//  - Keeps your multi-step flow (Buttons / Algolia / Firestore)
//
//  Notes
//  -----
//  • The schema is inferred from your export file and is flexible:
//      filters: {
//         <categoryKey>: {
//            name, symbol, color, keywords: []
//            subcategories: {
//               <subKey>: {
//                  name, symbol, availability
//                  steps: { "1": { type, path, hitsPerPage, searchBar, selectable, ... }, ... }
//               }
//            }
//         }
//      }
//  • Adjust FIRESTORE_FILTERS_PATH if your doc path differs.
//  • For Algolia steps, wire in your existing Algolia list view inside AlgoliaStepView.
//
//  Created by ChatGPT (clean refactor)

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import Foundation

enum FirestoreProvider {
    // one Firebase app, two logical databases
    static let projectID         = "ranko-kyan"
    static let filtersDatabaseID = "ranko"    // ← categories/subcategories
    static let itemsDatabaseID   = "library"  // ← item searches

    // configure once
    private static func ensureConfigured() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }

    // factory that works with/without multi-DB API
    private static func makeDB(databaseID: String) -> Firestore {
        ensureConfigured()
        #if FIRESTORE_HAS_MULTI_DB
        let db = Firestore.firestore(app: FirebaseApp.app()!, database: databaseID)
        #else
        // old SDK fallback: both will point to the default database
        // (you’ll still be able to ship; we’ll log so you notice)
        let db = Firestore.firestore(app: FirebaseApp.app()!)
        print("⚠️ Firestore multi-DB not available. Using default DB for '\(databaseID)'. Update FirebaseFirestore & add FIRESTORE_HAS_MULTI_DB.")
        #endif
        var s = db.settings
        s.isPersistenceEnabled = true
        db.settings = s
        return db
    }

    // expose both
    static let dbFilters: Firestore = makeDB(databaseID: filtersDatabaseID)
    static let dbItems:   Firestore = makeDB(databaseID: itemsDatabaseID)
}

enum FirestoreInspector {
    static func dumpFilters(label: String = "DEBUG DUMP") async {
        let db = FirestoreProvider.dbFilters

        print("\n\n==================== \(label) ====================")
        if let app = FirebaseApp.app() {
            print("AppID: \(app.name) | ProjectID: \(app.options.projectID ?? "(nil)") | DBs → filters=\(FirestoreProvider.filtersDatabaseID), items=\(FirestoreProvider.itemsDatabaseID)")
        } else {
            print("FirebaseApp not configured!")
        }
        print("Root collection = 'filters'\n")

        do {
            let filtersSnap = try await db.collection("filters").getDocuments()
            print("filters.count =", filtersSnap.documents.count)
            if filtersSnap.documents.isEmpty {
                print("‼️ The 'filters' collection has 0 documents (rules? wrong project/db?).")
            }

            for catDoc in filtersSnap.documents {
                print("\n-----------------------------------------------")
                print("category docID:", catDoc.documentID)
                pretty(catDoc.data(), prefix: "  ")

                // subcategories
                let subsRef = catDoc.reference.collection("subcategories")
                let subsSnap = try await subsRef.getDocuments()
                print("  subcategories.count =", subsSnap.documents.count)

                for subDoc in subsSnap.documents {
                    print("  ├─ subcategory docID:", subDoc.documentID)
                    pretty(subDoc.data(), prefix: "  │  ")

                    // steps as subcollection
                    let stepsRef = subDoc.reference.collection("steps")
                    let stepsSnap = try await stepsRef.getDocuments()
                    if !stepsSnap.isEmpty {
                        print("  │  steps (subcollection).count =", stepsSnap.documents.count)
                        for s in stepsSnap.documents.sorted(by: { (Int($0.documentID) ?? 999999) < (Int($1.documentID) ?? 999999) }) {
                            print("  │  ├─ step docID:", s.documentID)
                            pretty(s.data(), prefix: "  │  │  ")
                        }
                    } else if let stepsMap = subDoc.data()["steps"] as? [String: Any] {
                        // steps as map field
                        print("  │  steps (map field).keys =", Array(stepsMap.keys).sorted())
                        pretty(stepsMap, prefix: "  │  ")
                    } else {
                        print("  │  (no steps found)")
                    }
                }
            }
            print("\n==================== END DUMP ====================\n")
        } catch {
            let ns = error as NSError
            print("❌ dump error:", ns.domain, ns.code, ns.localizedDescription)
            if ns.domain == FirestoreErrorDomain,
               let code = FirestoreErrorCode.Code(rawValue: ns.code) {
              print("   FirestoreErrorCode =", code)
            }
            print("\n==================== END DUMP (ERROR) ====================\n")
        }
    }

    private static func pretty(_ dict: [String: Any], prefix: String = "") {
        // best-effort JSON pretty print so nested maps are readable
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys, .prettyPrinted]),
           var s = String(data: data, encoding: .utf8) {
            // indent each line
            s = s.split(separator: "\n", omittingEmptySubsequences: false)
                 .map { prefix + String($0) }
                 .joined(separator: "\n")
            print(s)
        } else {
            print(prefix + String(describing: dict))
        }
    }
}

// MARK: - Runtime filter groups

struct FilterGroupOption: Hashable, Codable {
    let name: String
    let field: String
    let value: String
    let color: String?
    let order: Int?
}

struct FilterGroup: Hashable, Codable {
    let groupName: String
    let order: Int
    let type: String // currently only "selectStrings"
    let filters: [FilterGroupOption]
}

// Separate function to keep the “#if” clean.
@inline(__always)
private func _firestoreDatabaseInitAvailable() -> Bool {
    // If your SDK has Firestore.firestore(app:database:), this will compile.
    // If not, we return false via the #else branch.
    #if compiler(>=5.7)
    // create a dummy closure to ensure we don’t attempt to *call* it on old SDKs
    typealias Maker = (FirebaseApp, String) -> Firestore
    let _ : Maker = Firestore.firestore(app:database:)
    return true
    #else
    return false
    #endif
}

// MARK: - Configuration
private enum FirestoreConfig {
    static let filtersCollection = "filters"   // ← collection, not a doc
    static let subcategoriesCollection = "subcategories"
    static let stepsCollection = "steps"       // if you store steps as docs
}

// MARK: - Helpers
private extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("0x") { s.removeFirst(2) }
        if s.hasPrefix("#") { s.removeFirst(1) }
        guard let v = UInt(s, radix: 16) else { return nil }
        self = Color(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

private func nestedValue(_ dict: [String: Any], keyPath: String) -> Any? {
    var current: Any? = dict
    for key in keyPath.split(separator: ".").map(String.init) {
        guard let d = current as? [String: Any] else { return nil }
        current = d[key]
    }
    return current
}

private func stringify(_ v: Any?) -> String? {
    switch v {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    case let b as Bool: return b ? "true" : "false"
    case let a as [Any]: return a.compactMap { stringify($0) }.joined(separator: ", ")
    default: return nil
    }
}

// MARK: - Debug helpers for Firestore Filters
private func debugDescribeFilters(_ filters: [FirestoreFilter]) -> String {
    if filters.isEmpty { return "(none)" }
    let rows = filters.map { f in
        let g = f.group != nil ? " group=\(f.group!)" : ""
        let val: String = {
            if let arr = f.values, !arr.isEmpty { return "[" + arr.map { $0.pretty }.joined(separator: ", ") + "]" }
            if let v = f.value { return v.pretty }
            return "(nil)"
        }()
        return "• \(f.field) \(f.op.rawValue) \(val)\(g)"
    }
    // also show inferred OR groups
    let groups = Dictionary(grouping: filters.compactMap { $0.group != nil ? $0 : nil }, by: { $0.group! })
        .map { k, v in "    OR group \(k): " + v.map { "\($0.field) \($0.op.rawValue)" }.joined(separator: "  OR  ") }
        .sorted()
    return (rows + (groups.isEmpty ? [] : ["--", "OR sets:"] + groups)).joined(separator: "\n\t")
}

private func debugValidateFilterPlan(_ filters: [FirestoreFilter]) {
    guard !filters.isEmpty else { return }
    let disj = filters.filter { $0.op == .in || $0.op == .arrayContainsAny }
    if disj.count > 1 {
        print("⚠️ [FS] Firestore only allows one of (in / arrayContainsAny) per query. Found: \(disj.map { $0.op.rawValue }.joined(separator: ", "))")
    }
    let notInCount = filters.filter { $0.op == .notIn }.count
    if notInCount > 1 { print("⚠️ [FS] Firestore allows only one notIn per query. Found: \(notInCount)") }
    let grouped = Dictionary(grouping: filters.compactMap { $0.group != nil ? $0 : nil }, by: { $0.group! })
    for (g, arr) in grouped { print("ℹ️ [FS] OR group \(g) has \(arr.count) conditions.") }
}

// MARK: - Models
struct AppCategory: Identifiable, Hashable {
    var id: String { key }           // 👈
    let key, name, symbol: String
    let color: Color
    let keywords: [String]
    let index: Int
}

struct AppSubcategory: Identifiable, Hashable {
    var id: String { key }           // 👈
    let key, name, symbol: String
    let color: Color
    let availability: Bool
    let steps: [SubcategoryDestinationConfig]
    let index: Int
}

struct SubcategoryStepButton: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let icon: String
    let step: Int? // optional explicit jump target (1-based)
}

enum StepViewType: String, Codable { case algolia = "Algolia", firebase = "Firebase", buttons = "Buttons", none = "" }

enum FirebaseKeyMode: String, Codable { case key = "key", value = "value", none = "" }

struct SortField: Hashable, Codable {
    let field: String
    let sort: String // "asc" | "desc"
    let name: String?   // 👈 add
}


struct SubcategoryDestinationConfig: Identifiable, Hashable {
    let id = UUID()
    
    let stepKey: String?
    // What to render
    let viewType: StepViewType
    
    // Algolia (kept for parity)
    let algoliaAppId: String
    let algoliaAppKey: String
    let algoliaIndex: String
    let algoliaFilters: String
    let algoliaGetField: String
    
    // Firestore
    let firebaseIdPath: String            // e.g. "music/(artist_id)/albums"
    let firebaseKeyFieldValue: FirebaseKeyMode
    let firebaseField: String
    let firebasePreSuf: String
    let firebaseSearchPath: String
    let firebaseFilters: [FirestoreFilter]
    let sortFields: [SortField]
    
    // Shared UI
    let hitsPerPage: Int
    let searchBar: Bool
    let selectable: Bool
    let itemName: String                  // templated string e.g. "(name) — (release_date)"
    let itemDescription: String           // templated
    let itemImage: String                 // templated
    /// Optional raw image dimensions coming from Firestore (e.g. imageDimensions map)
    let imageHeight: Double?
    let imageWidth: Double?
    let buttons: [SubcategoryStepButton]
    
    let nextStep: Int?
    let variables: [String:String]
    let databaseID: String?
    let filterGroups: [FilterGroup]   // 👈 NEW
}

struct StepRow: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let desc: String?
    let imageURL: String?
    let imageWidth: Double?
    let imageHeight: Double?
    
    init(
        id: String,
        name: String,
        desc: String?,
        imageURL: String?,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.desc = desc
        self.imageURL = imageURL
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

// MARK: - Firestore Repository
final class FiltersRepository: ObservableObject {
    @Published var categories: [AppCategory] = []
    @Published var subcategoriesByCategoryName: [String: [AppSubcategory]] = [:]
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var debugLog: [String] = []

    let db = FirestoreProvider.dbFilters

    private func debug(_ s: String) {
        DispatchQueue.main.async { self.debugLog.append(s) }
    }

    // MARK: load all categories + subcategories (+steps)
    @MainActor
    func load() async {
        isLoading = true
        error = nil
        debugLog.removeAll()
        defer { isLoading = false }

        do {
            let snap = try await db.collection("filters").getDocuments()
            debug("filters.count = \(snap.documents.count)")
            if snap.documents.isEmpty { debug("‼️ 0 docs in 'filters' — check rules/project/database id") }

            var cats: [AppCategory] = []
            var map: [String: [AppSubcategory]] = [:]

            try await withThrowingTaskGroup(of: (String, AppCategory, [AppSubcategory]).self) { group in
                for doc in snap.documents {
                    group.addTask { [db] in
                        let (cat, subs) = try await self.buildCategoryAndSubcats(from: doc, db: db)
                        return (cat.name, cat, subs)
                    }
                }
                for try await (catName, cat, subs) in group {
                    cats.append(cat)
                    map[catName] = subs.sorted {
                        if $0.index != $1.index { return $0.index < $1.index }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    debug("→ \(catName): subcategories=\(subs.count)")
                }
            }

            cats.sort {
                if $0.index != $1.index { return $0.index < $1.index }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            for (catName, subs) in map {
                map[catName] = subs.sorted {
                    if $0.index != $1.index { return $0.index < $1.index }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
            let subTotal = map.values.reduce(0) { $0 + $1.count }
            debug("parsed categories: \(cats.count), total subcategories: \(subTotal)")

            categories = cats
            subcategoriesByCategoryName = map
        } catch {
            self.error = error.localizedDescription
            categories = []
            subcategoriesByCategoryName = [:]
        }
    }

    // MARK: helpers
    private func colorFrom(_ raw: Any?) -> Color {
        if let s = raw as? String, let c = Color(hexString: s) { return c }
        if let n = raw as? NSNumber {
            let u = UInt(truncating: n)
            return Color(.sRGB,
                         red:   Double((u >> 16) & 0xFF) / 255.0,
                         green: Double((u >>  8) & 0xFF) / 255.0,
                         blue:  Double( u        & 0xFF) / 255.0,
                         opacity: 1.0)
        }
        return .white
    }

    private func asStringArray(_ v: Any?) -> [String] {
        if let arr = v as? [String] { return arr }
        if let s = v as? String {
            return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }

    // MARK: builders
    private func buildCategoryAndSubcats(from doc: QueryDocumentSnapshot, db: Firestore) async throws -> (AppCategory, [AppSubcategory]) {
        let data = doc.data()
        let key = doc.documentID

        let name     = (data["name"] as? String) ?? key.capitalized
        let symbol   = (data["symbol"] as? String) ?? "square.grid.2x2.fill"
        let color    = colorFrom(data["color"])
        let keywords = asStringArray(data["keywords"])
        let index    = (data["index"] as? Int) ?? 0

        let appCat = AppCategory(key: key, name: name, symbol: symbol, color: color, keywords: keywords, index: index)

        let subSnap = try await db.collection(FirestoreConfig.filtersCollection)
            .document(doc.documentID)
            .collection(FirestoreConfig.subcategoriesCollection)
            .getDocuments()

        var subs: [AppSubcategory] = []
        subs.reserveCapacity(subSnap.documents.count)

        try await withThrowingTaskGroup(of: AppSubcategory?.self) { group in
            for sdoc in subSnap.documents {
                group.addTask { [db] in
                    try await self.buildSubcategory(from: sdoc, parentColor: color, db: db)
                }
            }
            for try await maybe in group {
                if let sc = maybe { subs.append(sc) }
            }
        }

        return (appCat, subs)
    }

    private func buildSubcategory(from sdoc: QueryDocumentSnapshot, parentColor: Color, db: Firestore) async throws -> AppSubcategory {
        let subKey = sdoc.documentID
        let sub    = sdoc.data()

        let subName       = (sub["name"] as? String) ?? subKey.capitalized
        let subSymbol     = (sub["symbol"] as? String) ?? "square"
        let availability  = (sub["availability"] as? Bool) ?? true
        let tint          = (sub["color"] != nil) ? colorFrom(sub["color"]) : parentColor

        let steps = try await loadSteps(for: sdoc, existingMap: sub["steps"] as? [String: Any], db: db)
        let index = (sub["index"] as? Int) ?? Int.max

        return AppSubcategory(
            key: subKey,
            name: subName,
            symbol: subSymbol,
            color: tint,
            availability: availability,
            steps: steps,
            index: index
        )
    }

    // Prefer subcollection "steps"; fall back to "steps" map
    private func loadSteps(for sdoc: QueryDocumentSnapshot, existingMap: [String: Any]?, db: Firestore) async throws -> [SubcategoryDestinationConfig] {
        let stepsColl = db.collection(FirestoreConfig.filtersCollection)
            .document(sdoc.reference.parent.parent!.documentID)
            .collection(FirestoreConfig.subcategoriesCollection)
            .document(sdoc.documentID)
            .collection(FirestoreConfig.stepsCollection)

        let stepsSnap = try await stepsColl.getDocuments()
        if !stepsSnap.isEmpty {
            let ordered = stepsSnap.documents.sorted {
                (Int($0.documentID) ?? .max) < (Int($1.documentID) ?? .max)
            }
            return parseStepsFromDocs(ordered)
        }

        if let map = existingMap { return parseSteps(map) }
        return []
    }

    // MARK: step parsers
    private func parseStepsFromDocs(_ docs: [QueryDocumentSnapshot]) -> [SubcategoryDestinationConfig] {
        docs.map { d in
            let dict = d.data()
            return buildStep(from: dict, stepKey: d.documentID)
        }
    }

    private func parseSteps(_ raw: [String: Any]?) -> [SubcategoryDestinationConfig] {
        guard let raw else { return [] }
        let ordered = raw.compactMap { (k, v) -> (Int, [String: Any])? in
            guard let i = Int(k), let d = v as? [String: Any] else { return nil }
            return (i, d)
        }.sorted { $0.0 < $1.0 }


        return ordered.map { (num, d) in buildStep(from: d, stepKey: String(num)) }
    }

    // unified builder so both parsers stay in sync
    private func buildStep(from dict: [String: Any], stepKey: String? = nil) -> SubcategoryDestinationConfig {
        let type = StepViewType(rawValue: (dict["type"] as? String) ?? "") ?? .none

        let sortFields: [SortField] = ((dict["sortFields"] as? [[String: Any]]) ?? [])
            .compactMap { m in
                guard let field = m["field"] as? String else { return nil }
                let sort = (m["sort"] as? String) ?? "asc"
                let name = (m["name"] as? String)
                return SortField(field: field, sort: sort, name: name)
            }

        let buttons: [SubcategoryStepButton] = ((dict["buttons"] as? [[String: Any]]) ?? [])
            .map { btn in
                SubcategoryStepButton(
                    id:   (btn["id"]   as? String) ?? (btn["name"] as? String) ?? UUID().uuidString,
                    name: (btn["name"] as? String) ?? "Pick",
                    icon: (btn["image"] as? String) ?? "chevron.right",
                    step: btn["step"] as? Int
                )
            }
        
        let firebaseFilters: [FirestoreFilter] =
        ((dict["firebaseFilter"] as? [[String: Any]]) ?? []).compactMap { m in
            guard
                let field = m["field"] as? String,
                let typeStr = (m["type"] as? String) ?? (m["op"] as? String),
                let op = FirestoreFilterOp(rawValue: typeStr)
            else { return nil }
            
            let raw = m["value"] // may be scalar or array
            let group = (m["group"] as? NSNumber)?.intValue
            return FirestoreFilter.make(field: field, op: op, raw: raw, group: group)
        }
        
        if !firebaseFilters.isEmpty {
            print("\n🧪 [FS] Parsed firebaseFilter(s):\n\t\(debugDescribeFilters(firebaseFilters))")
        }
        debugValidateFilterPlan(firebaseFilters)

        // NEW: variables + nextStep
        let nextStep  = dict["nextStep"] as? Int
        let variables = (dict["variables"] as? [String:String]) ?? [:]
        
        // Optional imageDimensions map
        var imageHeight: Double? = nil
        var imageWidth: Double? = nil
        if let dims = dict["imageDimensions"] as? [String: Any] {
            if let h = dims["height"] as? NSNumber {
                imageHeight = h.doubleValue
            } else if let hInt = dims["height"] as? Int {
                imageHeight = Double(hInt)
            }
            if let w = dims["width"] as? NSNumber {
                imageWidth = w.doubleValue
            } else if let wInt = dims["width"] as? Int {
                imageWidth = Double(wInt)
            }
        }
        
        let filterGroups: [FilterGroup] = ((dict["filterGroups"] as? [[String: Any]]) ?? []).compactMap { g in
            guard let name = g["groupName"] as? String else { return nil }
            let order = (g["order"] as? Int) ?? 0
            let type  = (g["type"]  as? String) ?? "selectStrings"

            let options: [FilterGroupOption] = ((g["filters"] as? [[String: Any]]) ?? []).compactMap { f in
                guard let n = f["name"] as? String,
                      let field = f["field"] as? String
                else { return nil }
                let value = (f["value"] as? String) ?? n
                let color = f["color"] as? String
                let ord   = f["order"] as? Int
                return FilterGroupOption(name: n, field: field, value: value, color: color, order: ord)
            }.sorted { (a, b) in (a.order ?? Int.max) < (b.order ?? Int.max) }

            return FilterGroup(groupName: name, order: order, type: type, filters: options)
        }.sorted { $0.order < $1.order }

        return SubcategoryDestinationConfig(
            stepKey: stepKey,
            viewType: type,
            // Algolia
            algoliaAppId:  (dict["appID"]  as? String) ?? "",
            algoliaAppKey: (dict["appKey"] as? String) ?? "",
            algoliaIndex:  (dict["index"]  as? String) ?? "",
            algoliaFilters:(dict["filters"] as? String) ?? "",
            algoliaGetField: (dict["getField"] as? String) ?? (dict["AlgoliaGetField"] as? String) ?? "objectID",
            // Firestore
            firebaseIdPath: (dict["path"] as? String) ?? (dict["FirebaseIdPath"] as? String) ?? "",
            firebaseKeyFieldValue: FirebaseKeyMode(rawValue: (dict["FirebaseKeyFieldValue"] as? String) ?? "") ?? .none,
            firebaseField: (dict["FirebaseField"] as? String) ?? "",
            firebasePreSuf: (dict["FirebasePreSuf"] as? String) ?? "",
            firebaseSearchPath: (dict["FirebaseSearchPath"] as? String) ?? "",
            firebaseFilters: firebaseFilters,
            sortFields: sortFields,
            // UI
            hitsPerPage:   (dict["hitsPerPage"] as? Int) ?? (dict["HitsPerPage"] as? Int) ?? 25,
            searchBar:     (dict["searchBar"]   as? Bool) ?? (dict["SearchBar"]   as? Bool) ?? true,
            selectable:    (dict["selectable"]  as? Bool) ?? (dict["Selectable"]  as? Bool) ?? true,
            itemName:      (dict["nameField"]        as? String) ?? (dict["ItemName"]        as? String) ?? "(name)",
            itemDescription:(dict["descriptionField"]as? String) ?? (dict["ItemDescription"] as? String) ?? "",
            itemImage:     (dict["imageField"]       as? String) ?? (dict["ItemImage"]       as? String) ?? "",
            imageHeight:   imageHeight,
            imageWidth:    imageWidth,
            buttons: buttons,
            // NEW
            nextStep: nextStep,
            variables: variables,
            databaseID: (dict["databaseID"] as? String)?.lowercased(),
            filterGroups: filterGroups
        )
    }
}

// MARK: - Image dimension helpers

private func scaledImageSize(originalWidth: Double?, originalHeight: Double?, maxDimension: CGFloat) -> CGSize {
    guard
        let ow = originalWidth, let oh = originalHeight,
        ow > 0, oh > 0
    else {
        return CGSize(width: maxDimension, height: maxDimension)
    }
    
    let w = CGFloat(ow)
    let h = CGFloat(oh)
    
    if w >= h {
        let ratio = h / w
        return CGSize(width: maxDimension, height: maxDimension * ratio)
    } else {
        let ratio = w / h
        return CGSize(width: maxDimension * ratio, height: maxDimension)
    }
}

struct RankoRecord: Codable, Identifiable, Equatable, Hashable {
    let objectID: String
    let ItemName: String
    let ItemDescription: String
    let ItemCategory: String
    let ItemImage: String

    /// Optional raw image dimensions for this record (if known)
    let ImageHeight: Double?
    let ImageWidth: Double?

    // ⬇️ make media fields optional so decoding won’t require them
    let ItemGIF: String?
    let ItemVideo: String?
    let ItemAudio: String?

    // Custom initializers
    init(
        objectID: String,
        ItemName: String,
        ItemDescription: String,
        ItemCategory: String,
        ItemImage: String,
        ItemGIF: String? = nil,
        ItemVideo: String? = nil,
        ItemAudio: String? = nil
    ) {
        self.objectID = objectID
        self.ItemName = ItemName
        self.ItemDescription = ItemDescription
        self.ItemCategory = ItemCategory
        self.ItemImage = ItemImage
        self.ImageHeight = nil
        self.ImageWidth = nil
        self.ItemGIF = ItemGIF
        self.ItemVideo = ItemVideo
        self.ItemAudio = ItemAudio
    }

    init(
        objectID: String,
        ItemName: String,
        ItemDescription: String,
        ItemCategory: String,
        ItemImage: String,
        ImageHeight: Double?,
        ImageWidth: Double?,
        ItemGIF: String?,
        ItemVideo: String?,
        ItemAudio: String?
    ) {
        self.objectID = objectID
        self.ItemName = ItemName
        self.ItemDescription = ItemDescription
        self.ItemCategory = ItemCategory
        self.ItemImage = ItemImage
        self.ImageHeight = ImageHeight
        self.ImageWidth = ImageWidth
        self.ItemGIF = ItemGIF
        self.ItemVideo = ItemVideo
        self.ItemAudio = ItemAudio
    }

    var id: String { objectID }
}

struct RankoItem: Identifiable, Codable, Equatable, Hashable {
    let id: String            // ← will hold our random 12-char code
    var rank: Int             // ← selection order
    var votes: Int
    let record: RankoRecord
    /// Convenience accessors for image dimensions coming from the record
    var imageHeight: Double? { record.ImageHeight }
    var imageWidth: Double?  { record.ImageWidth }
    var itemName: String { record.ItemName }
    var itemDescription: String { record.ItemDescription }
    var itemImage: String { record.ItemImage }
    var itemGIF: String   { record.ItemGIF   ?? "" }
    var itemVideo: String { record.ItemVideo ?? "" }
    var itemAudio: String { record.ItemAudio ?? "" }
    var playCount: Int
}

// MARK: - Selection Basket
final class SelectionBasket: ObservableObject {
    @Published var selectedGeneric: [StepRow] = []

    func toggleGeneric(_ item: StepRow) {
        if let idx = selectedGeneric.firstIndex(where: { $0.id == item.id }) {
            selectedGeneric.remove(at: idx)
        } else {
            selectedGeneric.append(item)
        }
    }

    func isGenericSelected(_ id: String) -> Bool { selectedGeneric.contains(where: { $0.id == id }) }
    func clear() { selectedGeneric.removeAll() }
    func moveGeneric(from source: IndexSet, to destination: Int) { selectedGeneric.move(fromOffsets: source, toOffset: destination) }
}

// MARK: - Categories Screen
struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repo = FiltersRepository()
    @ObservedObject var basket: SelectionBasket

    @Namespace private var ns

    // Removed tab state, replaced with showBrowseFullScreen
    @State private var showBrowseFullScreen = false
    @State private var search = ""
    @State private var expandedKey: String? = nil
    @State private var editMode = false
    @State private var selectedIDs = Set<String>()

    private let columns = 2
    private let spacing: CGFloat = 12

    private var filtered: [AppCategory] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return repo.categories }
        return repo.categories.filter { $0.name.lowercased().contains(q) || $0.keywords.contains(where: { $0.lowercased().contains(q) }) }
    }

    private var rows: [[AppCategory]] { filtered.chunked(into: columns) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if repo.isLoading {
                        VStack {
                            Spacer()
                            ThreeRectanglesAnimation(
                                rectangleWidth: 40,
                                rectangleMaxHeight: 130,
                                rectangleSpacing: 7,
                                rectangleCornerRadius: 6,
                                animationDuration: 0.7
                            )
                            .frame(height: 170)
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                    } else if let err = repo.error {
                        errorView(err)
                    } else {
                        basketContent
                    }
                }

                // Floating "+" button to open browse full-screen
                if !editMode {
                    HStack {
                        Spacer()
                        Button {
                            showBrowseFullScreen = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .black))
                                .opacity(0.78)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.glassProminent)
                        .contentShape(Rectangle())
                        .tint(Color(hex: 0xFF0819))
                        .padding(.bottom, 12)
                        
                        Spacer()
                    }
                }
            }
            .toolbar { basketToolbar }
            .task {
                if repo.categories.isEmpty && !repo.isLoading {
                    await repo.load()
                }
            }
            .fullScreenCover(isPresented: $showBrowseFullScreen) {
                NavigationStack {
                    browseContent
                        .toolbar { browseToolbar }
                }
            }
            .toolbarTitleDisplayMode(.large)
            .navigationTitle("")
        }
        .tint(Color(hex: 0xFF0819))
    }

    private func errorView(_ err: String) -> some View {
        VStack(spacing: 12) {
            Text("failed to load categories").font(.headline)
            Text(err).font(.footnote).foregroundStyle(.secondary)
            Button("retry") { Task { await repo.load() } }
        }
    }

    private var basketContent: some View {
        List {
            Section {
                if basket.selectedGeneric.isEmpty {
                    EmptyBasketView(onBrowse: { showBrowseFullScreen = true })
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(basket.selectedGeneric) { r in
                        HStack(spacing: 12) {
                            let basketSize = scaledImageSize(originalWidth: r.imageWidth, originalHeight: r.imageHeight, maxDimension: 37)
                            
                            AsyncImage(url: URL(string: r.imageURL ?? "")) { $0.resizable() } placeholder: { Color.gray.opacity(0.15) }
                                .scaledToFill()
                                .frame(width: basketSize.width, height: basketSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name)
                                    .font(.custom("Nunito-Black", size: 15))
                                    .foregroundStyle(Color(hex: 0x000000))
                                if let d = r.desc, !d.isEmpty {
                                    Text(d)
                                        .font(.custom("Nunito-Black", size: 11))
                                        .foregroundStyle(Color(hex: 0x9E9E9E))
                                }
                            }
                            Spacer()
                            Image(systemName: !editMode ? "line.3.horizontal" : (selectedIDs.contains(r.id) ? "checkmark.circle.fill" : "circle"))
                                .font(.system(size: editMode ? 16 : 20, weight: .black))
                                .foregroundStyle(editMode ? Color(hex: 0x000000) : Color(hex: 0xC2C2C2))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editMode { selectedIDs.toggle(r.id) }
                        }
                    }
                    .onMove(perform: basket.moveGeneric)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0xFFFFFF))
                            .padding(2)
                    )
                    .listRowSpacing(5)
                    .listRowSeparator(.hidden)
                }
            } header: {
                if !basket.selectedGeneric.isEmpty {
                    Text("Selected Items")
                        .font(.custom("Nunito-Black", size: 20))
                        .foregroundStyle(Color(hex: 0x505050))
                }
            }
        }
    }

    private var browseContent: some View {
        VStack {
            HStack {
                Text("Select Category")
                    .font(.custom("Nunito-Black", size: 26))
                    .foregroundStyle(Color(hex: 0x505050))
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 10)
            SearchBar(text: $search)
            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(rows.indices, id: \.self) { i in
                        HStack(spacing: spacing) {
                            ForEach(rows[i]) { cat in
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        expandedKey = (expandedKey == cat.key) ? nil : cat.key
                                    }
                                } label: {
                                    CategoryTile(category: cat, isSelected: expandedKey == cat.key)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if let key = expandedKey, let cat = rows[i].first(where: { $0.key == key }) {
                            SubcategoryDisclosureRow(
                                parent: cat,
                                subcategories: repo.subcategoriesByCategoryName[cat.name] ?? [],
                                ns: ns,
                                onDismiss: { showBrowseFullScreen = false }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
            }
        }
    }

    @ToolbarContentBuilder
    private var basketToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(Color(hex: 0x000000))
            }
            .contentShape(Rectangle())
            .disabledWithOpacity(editMode)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                editMode = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(Color(hex: 0x000000))
                    .contentShape(Rectangle())
            }
            .disabledWithOpacity(editMode || basket.selectedGeneric.isEmpty)
            Button {
                if editMode {
                    withAnimation {
                        selectedIDs.removeAll()
                        editMode = false
                    }
                } else {
                    performAdd()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black))
            }
            .contentShape(Rectangle())
            .disabled(basket.selectedGeneric.isEmpty)
            .buttonStyle(.glassProminent)
        }
        
        if editMode {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button {
                    withAnimation {
                        var selected: [StepRow] = []
                        var unselected: [StepRow] = []
                        for item in basket.selectedGeneric {
                            if selectedIDs.contains(item.id) {
                                selected.append(item)
                            } else {
                                unselected.append(item)
                            }
                        }
                        basket.selectedGeneric = unselected + selected
                    }
                } label: {
                    Image(systemName: "platter.filled.top.and.arrow.up.iphone")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: selectedIDs.isEmpty ? 0xC8C8C8 : 0x000000))
                }
                .disabled(basket.selectedGeneric.isEmpty)
                Button {
                    withAnimation {
                        var selected: [StepRow] = []
                        var unselected: [StepRow] = []
                        for item in basket.selectedGeneric {
                            if selectedIDs.contains(item.id) {
                                selected.append(item)
                            } else {
                                unselected.append(item)
                            }
                        }
                        basket.selectedGeneric = selected + unselected
                    }
                } label: {
                    Image(systemName: "platter.filled.bottom.and.arrow.down.iphone")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: selectedIDs.isEmpty ? 0xC8C8C8 : 0x000000))
                }
                .disabled(basket.selectedGeneric.isEmpty)
                Spacer()
                Button {
                    performDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: selectedIDs.isEmpty ? 0xC8C8C8 : 0x000000))
                }
                .disabled(basket.selectedGeneric.isEmpty)
                Spacer()
                Button {
                    withAnimation {
                        selectedIDs = Set(basket.selectedGeneric.map { $0.id })
                    }
                } label: {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: 0x000000))
                }
                Button {
                    withAnimation {
                        selectedIDs.removeAll()
                    }
                } label: {
                    Image(systemName: "checklist.unchecked")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: selectedIDs.isEmpty ? 0xC8C8C8 : 0x000000))
                }
                .disabled(basket.selectedGeneric.isEmpty)
                Spacer()
            }
        }
        
//        ToolbarItem(placement: .topBarLeading) {
//            if editMode && !selectedIDs.isEmpty {
//                Button(role: .destructive) {
//                    performDelete()
//                } label: {
//                    Label("Delete", systemImage: "trash.fill")
//                }
//            } else if !editMode && !basket.selectedGeneric.isEmpty {
//                Button {
//                    withAnimation {
//                        editMode = true
//                    }
//                } label: {
//                    Image(systemName: "pencil")
//                        .font(.system(size: 14, weight: .black))
//                }
//            }
//        }
//        ToolbarItem(placement: .principal) {
//            Text(editMode ? (selectedIDs.isEmpty ? "Select items" : "\(selectedIDs.count) selected") : "Selected Items")
//                .font(.headline)
//        }
//        ToolbarItem(placement: .topBarTrailing) {
//            if editMode {
//                Button {
//                    selectedIDs.removeAll()
//                    editMode = false
//                } label: {
//                    Text("Done").font(.footnote.weight(.black))
//                }
//            } else {
//                if !basket.selectedGeneric.isEmpty {
//                    Button {
//                        performAdd()
//                    } label: {
//                        Image(systemName: "plus")
//                            .font(.system(size: 14, weight: .black))
//                    }
//                } else {
//                    Button { dismiss() } label: {
//                        Text("Cancel").font(.headline)
//                    }
//                }
//            }
//        }
    }
    
    @ToolbarContentBuilder
    private var browseToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showBrowseFullScreen = false
            } label: {
                Image(systemName: "chevron.backward")
                    .foregroundStyle(Color(hex: 0x000000))
                    .contentShape(Rectangle())
            }
        }
    }

    private func performAdd() {
        onAdd?(selectedIDs.isEmpty ? basket.selectedGeneric : basket.selectedGeneric.filter {
            selectedIDs.contains($0.id)
        })
        withAnimation {
            selectedIDs.removeAll()
            editMode = false
        }
    }
    
    private func performDelete() {
        let ids = selectedIDs
        basket.selectedGeneric.removeAll {
            ids.contains($0.id)
        }
        withAnimation {
            selectedIDs.removeAll()
            editMode = false
        }
    }

    // Injection point for your parent to receive items
    var onAdd: (([StepRow]) -> Void)? = nil
}

enum PageToken: Hashable {
    case number(Int)
    case ellipsis
}

func buildPageTokens(current: Int, last: Int) -> [PageToken] {
    guard last > 1 else { return [.number(1)] }
    var tokens: [PageToken] = []

    let cur = min(max(1, current), last)

    if last <= 8 {
        for p in 1...last { tokens.append(.number(p)) }
        return tokens
    }

    func pushRange(_ a: Int, _ b: Int) {
        guard a <= b else { return }
        for p in a...b { tokens.append(.number(p)) }
    }

    tokens.append(.number(1))

    if cur <= 4 {
        // 1, 2..6, …, last
        pushRange(2, min(6, last-1))
        if last > 7 { tokens.append(.ellipsis) }
        tokens.append(.number(last))
        return tokens
    }

    if cur >= last - 3 {
        // 1, …, last-5..last-1, last
        tokens.append(.ellipsis)
        pushRange(max(2, last-5), last-1)
        tokens.append(.number(last))
        return tokens
    }

    // middle
    tokens.append(.ellipsis)
    pushRange(cur-2, cur+2)
    tokens.append(.ellipsis)
    tokens.append(.number(last))
    return tokens
}

struct PagingBar: View {
    let tint: Color
    let lastPage: Int
    @Binding var currentPage: Int
    var onJump: (Int) -> Void

    var body: some View {
        if lastPage > 1 {
            HStack(spacing: 10) {
                ForEach(buildPageTokens(current: currentPage, last: lastPage), id: \.self) { tok in
                    switch tok {
                    case .ellipsis:
                        Text("…")
                            .font(.footnote.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    case .number(let p):
                        Button {
                            guard p != currentPage else { return }
                            currentPage = p
                            onJump(p)
                        } label: {
                            Text("\(p)")
                                .font(.custom("Nunito-Black", size: 10))
                                .frame(width: 18, height: 18)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .background(p == currentPage ? tint.opacity(0.3) : Color(hex: 0xCECECE).opacity(0.3))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(p)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Small Views
private struct EmptyBasketView: View {
    let onBrowse: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "basket")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("no items selected yet")
                .font(.custom("Nunito-Black", size: 15))
                .foregroundStyle(.secondary)
            Text("browse categories and add items")
                .font(.custom("Nunito-Black", size: 11))
                .foregroundStyle(.tertiary)
            Button(action: onBrowse) {
                Text("Browse Items")
                    .font(.custom("Nunito-Black", size: 16))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 15)
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct SearchBar: View {
    @Binding var text: String
    @State private var empty = true
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(hex: empty ? 0xC8C8C8 : 0x000000))
            TextField("Search categories…", text: $text)
                .font(.custom("Nunito-Black", size: 17))
                .textInputAutocapitalization(.never)
                .onChange(of: text) { _, v in withAnimation { empty = v.isEmpty } }
            if !empty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray) } }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
}

struct CategoryTile: View {
    @State private var isHighlighted: Bool = false
    let category: AppCategory
    let isSelected: Bool

    var body: some View {
        VStack {
            if isSelected {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 15)
            }
            HStack {
                Image(systemName: category.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(category.color)
                    .padding(14)

                Spacer(minLength: 0)

                Text(category.name)
                    .font(.custom("Nunito-Black", size: 17))
                    .foregroundColor(category.color)
                    .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0xFFFFFF))
                    .shadow(color: isSelected ? category.color : Color.black.opacity(0.2), radius: 3)
            }
        }
        .onChange(of: isSelected) { _, _ in
            withAnimation {
                isHighlighted = isSelected
            }
        }
    }
}

struct FlowingChips: Layout {
    var spacing: CGFloat = 8
    enum RowAlignment { case leading, center, trailing }
    var rowAlignment: RowAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        guard maxWidth.isFinite else {
            // fallback: single row natural size
            let totalWidth = subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } +
                             max(0, CGFloat(subviews.count - 1)) * spacing
            let maxHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return CGSize(width: totalWidth, height: maxHeight)
        }

        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentRowWidth > 0, currentRowWidth + spacing + size.width > maxWidth {
                // wrap
                totalHeight += currentRowHeight + spacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = 0
                currentRowHeight = 0
            }
            currentRowWidth = currentRowWidth == 0 ? size.width : (currentRowWidth + spacing + size.width)
            currentRowHeight = max(currentRowHeight, size.height)
        }

        // last row
        if currentRowHeight > 0 {
            totalHeight += currentRowHeight
            maxRowWidth = max(maxRowWidth, currentRowWidth)
        }

        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        guard maxWidth.isFinite, !subviews.isEmpty else {
            // simple top-left place
            var x = bounds.minX
            let y = bounds.minY
            for v in subviews {
                let s = v.sizeThatFits(.unspecified)
                v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            return
        }

        // 1) Build rows
        var rows: [[(index: Int, size: CGSize)]] = []
        var currentRow: [(Int, CGSize)] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            let nextWidth = currentRow.isEmpty ? s.width : (currentRowWidth + spacing + s.width)
            if !currentRow.isEmpty && nextWidth > maxWidth {
                rows.append(currentRow)
                currentRow = [(i, s)]
                currentRowWidth = s.width
                currentRowHeight = s.height
            } else {
                currentRow.append((i, s))
                currentRowWidth = nextWidth
                currentRowHeight = max(currentRowHeight, s.height)
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        // 2) Place rows with per-row horizontal alignment
        var y = bounds.minY
        for row in rows {
            // compute row width & height
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map { $0.size.height }.max() ?? 0

            let startX: CGFloat
            switch rowAlignment {
            case .leading:
                startX = bounds.minX
            case .center:
                startX = bounds.midX - rowWidth / 2.0
            case .trailing:
                startX = bounds.maxX - rowWidth
            }

            var x = startX
            for (idx, size) in row {
                subviews[idx].place(at: CGPoint(x: x, y: y),
                                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}


private struct SubcategoryDisclosureRow: View {
    let parent: AppCategory
    let subcategories: [AppSubcategory]
    let ns: Namespace.ID
    let onDismiss: () -> Void
    @EnvironmentObject private var basket: SelectionBasket

    var body: some View {
        FlowingChips(spacing: 8) {
            ForEach(subcategories) { sc in
                if sc.availability {
                    NavigationLink {
                        SubcategoryFlowHost(
                            subcategoryName: sc.name,
                            tint: sc.color,
                            steps: sc.steps,
                            onDismiss: onDismiss
                        )
                        .environmentObject(basket)
                    } label: {
                        Chip(icon: sc.symbol, title: sc.name)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(sc.color.opacity(0.7))
                } else {
                    Button { } label: {
                        Chip(icon: sc.symbol, title: sc.name)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.gray.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct Chip: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 13, weight: .black))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .foregroundColor(.white)
    }
}

// MARK: - Flow Host
private struct FlowContext {
    var collectedIDs: [String] = []
    var selectedButtonID: String? = nil
    var vars: [String:String] = [:]   // ← NEW
}

struct SubcategoryFlowHost: View {
    @Environment(\.dismiss) private var dismiss

    let subcategoryName: String
    let tint: Color
    let steps: [SubcategoryDestinationConfig]
    let onDismiss: () -> Void

    @State private var ctx = FlowContext()
    @State private var currentStep = 0
    @State private var stepHistory: [Int] = []
    @Namespace private var ns

    private var initialStepIndex: Int {
        steps.firstIndex(where: { $0.stepKey == "1" }) ?? 0
    }

    var body: some View {
        Group {
            if steps.indices.contains(currentStep) {
                stepView(index: currentStep)
            } else {
                VStack {
                    Spacer()
                    Text("No steps configured for this subcategory.")
                        .foregroundStyle(.secondary)
                        .font(.footnote.weight(.semibold))
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    if stepHistory.isEmpty {
                        dismiss()
                    } else {
                        goBack()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: 0x0000000))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glassProminent)
                .tint(Color(hex: 0xFFFFFF))
                //.disabledWithOpacity(stepHistory.isEmpty)
                Button {
                    dismiss()
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.backward.2")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: 0x0000000))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glassProminent)
                .tint(Color(hex: 0xFFFFFF))
            }
            ToolbarItem(placement: .principal) {
                Title(tint: tint, text: subcategoryName)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                    onDismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glassProminent)
                .tint(tint)
            }
        }
        .tint(tint)
        .onAppear { resetFlow() }
    }

    private func stepKey(_ i: Int) -> String { "\(subcategoryName)-step-\(i)" }

    @ViewBuilder
    private func stepView(index i: Int) -> some View {
        StepContentView(
            step: steps[i],
            tint: tint,
            ctx: $ctx,
            subcategoryName: subcategoryName,
            onAdvance: { newIDs in
                if let ids = newIDs, !ids.isEmpty { ctx.collectedIDs = ids; ctx.selectedButtonID = nil }
                go(to: i + 1)
            },
            onJumpTo: { jump in
                let key = String(jump)
                if let idx = steps.firstIndex(where: { $0.stepKey == key }) {
                    print("[NAV][FLOW] resolved logical step \(jump) → index \(idx) via stepKey='\(key)'")
                    go(to: idx)
                    return
                }

                let idx = jump - 1
                guard steps.indices.contains(idx) else {
                    print("[NAV][FLOW] ⚠️ requested step \(jump) (key '\(key)') but no stepKey match and idx \(idx) is out of range; steps.count=\(steps.count); ignoring")
                    return
                }
                print("[NAV][FLOW] ℹ️ no stepKey match for \(jump); falling back to positional idx=\(idx)")
                go(to: idx)
            },
            onDismiss: onDismiss
        )
        .id(steps[i].id) // 👈 forces a brand-new state per step
    }

    private func resetFlow() {
        stepHistory.removeAll()
        go(to: initialStepIndex, recordHistory: false)
    }

    private func goBack() {
        guard let prev = stepHistory.popLast() else { return }
        currentStep = prev
    }

    private func go(to idx: Int, recordHistory: Bool = true) {
        guard steps.indices.contains(idx) else { return }
        if recordHistory, idx != currentStep, steps.indices.contains(currentStep) {
            stepHistory.append(currentStep)
        }
        currentStep = idx
    }

    private struct Title: View { let tint: Color; let text: String; var body: some View { HStack(spacing: 8) { Image(systemName: "square.grid.2x2.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(tint); Text(text).font(.system(size: 16, weight: .black)).foregroundStyle(tint) } } }
}

// MARK: - Step Content Router
private struct StepContentView: View {
    @Environment(\.dismiss) private var dismiss
    
    let step: SubcategoryDestinationConfig
    let tint: Color
    @Binding var ctx: FlowContext
    let subcategoryName: String
    
    let onAdvance: (_ newIDs: [String]?) -> Void
    let onJumpTo: (_ stepIndexOneBased: Int) -> Void
    let onDismiss: () -> Void
    
    @State private var searchText = ""
    @State private var searchTextEmpty = true
    @State private var nonce = 0
    
    @State private var showSortSheet = false
    @State private var sortIndex: Int = 0
    @State private var sortDescending: Bool = false
    @State private var userSetPrimaryDir = false
    
    @State private var selectedFilterValues: [String: Set<String>] = [:] // field -> selected values
    @State private var runtimeFilters: [FirestoreFilter] = []
    @State private var selectedStringFilters: [String : Set<String>] = [:]
    private var hasActiveFilters: Bool {
        selectedFilterValues.values.contains { !$0.isEmpty }
    }
    
    init(
        step: SubcategoryDestinationConfig,
        tint: Color,
        ctx: Binding<FlowContext>,
        subcategoryName: String,
        onAdvance: @escaping (_ newIDs: [String]?) -> Void,
        onJumpTo: @escaping (_ stepIndexOneBased: Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.step = step
        self.tint = tint
        self._ctx = ctx
        self.subcategoryName = subcategoryName
        self.onAdvance = onAdvance
        self.onJumpTo = onJumpTo
        self.onDismiss = onDismiss
        
        let initialIndex = 0
        let initialDesc  = isDesc(step.sortFields.first?.sort)
        
        _sortIndex           = State(initialValue: initialIndex)
        _sortDescending      = State(initialValue: initialDesc)   // 👈 honors "desc"
        _userSetPrimaryDir   = State(initialValue: false)
    }
    
    var body: some View {
        ZStack {
            Group {
                switch step.viewType {
                case .buttons:
                    ButtonsStepView(step: step, tint: tint) { button in
                        ctx.selectedButtonID = button
                        if let target = step.buttons.first(where: { $0.id == button })?.step { onJumpTo(target) } else { onAdvance(nil) }
                    }
                case .algolia:
                    AlgoliaStepView(
                        step: step,
                        ctx: ctx,                 // pass full ctx now (not ctx.wrappedValue)
                        tint: tint,
                        searchText: $searchText,
                        submitNonce: nonce,
                        forwardIDs: { ids in if !step.selectable { onAdvance(ids) } },
                        onSetVars: { newVars in
                            // merge into context
                            for (k, v) in newVars { ctx.vars[k] = v }
                        },
                        onJump: { jump in onJumpTo(jump) }
                    )
                    .id("ALG|\(step.id)|\(ctx.vars.description)")
                case .firebase:
                    FirestoreStepView(
                        step: step,
                        tint: tint,
                        incomingIDs: ctx.collectedIDs,
                        vars: ctx.vars,
                        searchText: $searchText,
                        submitNonce: nonce,
                        sortIndex: sortIndex,
                        sortDescendingOverride: sortDescending,
                        forwardIDs: { ids in if !step.selectable { onAdvance(ids) } },
                        onSetVars: { newVars in for (k, v) in newVars { ctx.vars[k] = v } },
                        onJump: { jump in onJumpTo(jump) },
                        runtimeFilters: runtimeFilters,
                        selectedStringFilters: selectedStringFilters
                    )
                    // keep identity stable so filter chip taps don't remount FirestoreStepView
                    .id("FS|\(step.id)")
                case .none:
                    VStack { Spacer(); Text("no view configured for this step").foregroundStyle(.secondary); Spacer() }
                }
            }
        }
        .onChange(of: searchText) { oldText, newText in
            if oldText.isEmpty && !newText.isEmpty {
                withAnimation {
                    searchTextEmpty = false
                }
            } else if !oldText.isEmpty && newText.isEmpty {
                withAnimation {
                    searchTextEmpty = true
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if step.searchBar {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(searchTextEmpty ? Color(hex: 0x8A8A8D) : Color(hex: 0x000000))
                        TextField("Search \(subcategoryName)...", text: $searchText)
                            .font(.custom("Nunito-Black", size: 16))
                            .foregroundStyle(searchTextEmpty ? Color(hex: 0x8A8A8D) : Color(hex: 0x000000))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit { nonce += 1 }
                        
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray) }
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    
                    if !step.sortFields.isEmpty {
                        Button {
                            showSortSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20, weight: .black))
                                .padding(.vertical, 0)
                                .padding(.horizontal, -5)
                        }
                        .buttonStyle(.glassProminent)
                        .contentShape(Rectangle())
                        .tint(tint.opacity(0.7))
                        .accessibilityLabel("Sort & Filter")
                    }
                }
                .padding([.horizontal, .top])
            }
        }
        .sheet(isPresented: $showSortSheet) {
            SortSheet(
                sortFields: step.sortFields,
                sortIndex: $sortIndex,
                sortDescending: $sortDescending,
                userSetPrimaryDir: $userSetPrimaryDir,
                filterGroups: step.filterGroups,
                selectedFilterValues: $selectedFilterValues,
                onApply: {
                    // Build runtime Firestore filters from user selections.
                    // We walk each filterGroup so we can use group.type
                    // to decide between scalar vs array ops.
                    var newFilters: [FirestoreFilter] = []

                    for group in step.filterGroups {
                        // collect selected values per field for this group
                        var valuesByField: [String: [String]] = [:]

                        for opt in group.filters {
                            if let set = selectedFilterValues[opt.field],
                               set.contains(opt.value) {
                                valuesByField[opt.field, default: []].append(opt.value)
                            }
                        }

                        for (field, vals) in valuesByField {
                            guard !vals.isEmpty else { continue }

                            switch group.type {
                            case "selectStrings":
                                // scalars: 1 → isEqualTo, many → in
                                if vals.count == 1 {
                                    if let f = FirestoreFilter.make(
                                        field: field,
                                        op: .isEqualTo,
                                        raw: vals[0],
                                        group: nil
                                    ) {
                                        newFilters.append(f)
                                    }
                                } else {
                                    if let f = FirestoreFilter.make(
                                        field: field,
                                        op: .in,
                                        raw: vals,
                                        group: nil
                                    ) {
                                        newFilters.append(f)
                                    }
                                }

                            case "selectArrays":
                                // arrays: 1 → arrayContains, many → arrayContainsAny
                                if vals.count == 1 {
                                    if let f = FirestoreFilter.make(
                                        field: field,
                                        op: .arrayContains,
                                        raw: vals[0],
                                        group: nil
                                    ) {
                                        newFilters.append(f)
                                    }
                                } else {
                                    if let f = FirestoreFilter.make(
                                        field: field,
                                        op: .arrayContainsAny,
                                        raw: vals,
                                        group: nil
                                    ) {
                                        newFilters.append(f)
                                    }
                                }

                            default:
                                break
                            }
                        }
                    }

                    runtimeFilters = newFilters

                    // 🔒 If any filters are active, lock sort to default field + default direction
                    if selectedFilterValues.values.contains(where: { !$0.isEmpty }) {
                        sortIndex = 0
                        sortDescending = isDesc(step.sortFields.first?.sort)
                        userSetPrimaryDir = false
                    }

                    // re-run query with filters and (possibly) new sort
                    nonce += 1
                }
            )
        }
        .onChange(of: sortIndex) { _, newIdx in
            if step.sortFields.indices.contains(newIdx) {
                if !userSetPrimaryDir {
                    sortDescending = isDesc(step.sortFields[newIdx].sort)
                }
            }
        }
        .onChange(of: step.id) { _, _ in
            sortIndex = 0
            sortDescending = isDesc(step.sortFields.first?.sort)
            userSetPrimaryDir = false
        }
        .onChange(of: selectedFilterValues) { _, _ in
            if hasActiveFilters {
                // Force default sort (index 0, default direction from config)
                sortIndex = 0
                sortDescending = isDesc(step.sortFields.first?.sort)
                userSetPrimaryDir = false
            }
        }
    }
    private func isDesc(_ s: String?) -> Bool {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !s.isEmpty else { return false }
        return s == "desc" || s == "descending" || s.hasPrefix("desc")
    }
}

private struct SortSheet: View {
    let sortFields: [SortField]
    @Binding var sortIndex: Int
    @Binding var sortDescending: Bool
    @Binding var userSetPrimaryDir: Bool
    @State private var selectedChips: Set<ChipSelection> = []
    @State private var runtimeFilters: [FirestoreFilter] = []

    let filterGroups: [FilterGroup]
    @Binding var selectedFilterValues: [String: Set<String>]

    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Track expanded filter groups for "show more"
    @State private var expandedGroups: Set<String> = []
    
    // Lock sort while any filters are active
    private var hasActiveFilters: Bool {
        selectedFilterValues.values.contains { !$0.isEmpty }
    }
    private func isDescLocal(_ s: String?) -> Bool {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !s.isEmpty else { return false }
        return s == "desc" || s == "descending" || s.hasPrefix("desc")
    }

    // default sort = first sort field + its configured direction
    private var isDefaultSort: Bool {
        guard let first = sortFields.first else { return true }
        return sortIndex == 0 && sortDescending == isDescLocal(first.sort)
    }

    private func resetSort() {
        guard let first = sortFields.first else { return }
        sortIndex = 0
        sortDescending = isDescLocal(first.sort)
        userSetPrimaryDir = false
    }

    private func resetFilters() {
        selectedFilterValues.removeAll()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Sort section
                        if !sortFields.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text("Sort")
                                        .font(.custom("Nunito-Black", size: 20))

                                    Spacer()
                                    
                                    if !isDefaultSort {
                                        Button {
                                            resetSort()
                                        } label: {
                                            Text("reset sort")
                                                .font(.custom("Nunito-Black", size: 12))
                                                .foregroundColor(Color(hex: 0xFF0819))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    HStack(spacing: 10) {
                                        // Ascending icon
                                        Button {
                                            guard !hasActiveFilters else { return }
                                            sortDescending = false
                                            userSetPrimaryDir = true
                                        } label: {
                                            Image(systemName: "chevron.up.square.fill")
                                                .font(.system(size: 18, weight: .black))
                                                .foregroundColor(hasActiveFilters
                                                                ? Color(hex: 0xC8C8C8)
                                                                : (sortDescending ? Color(hex: 0xC8C8C8) : Color(hex: 0xFF0819)))
                                        }
                                        .contentShape(Rectangle())
                                        .buttonStyle(.plain)

                                        // Descending icon
                                        Button {
                                            guard !hasActiveFilters else { return }
                                            sortDescending = true
                                            userSetPrimaryDir = true
                                        } label: {
                                            Image(systemName: "chevron.down.square.fill")
                                                .font(.system(size: 18, weight: .black))
                                                .foregroundColor(hasActiveFilters
                                                                ? Color(hex: 0xC8C8C8)
                                                                : (sortDescending ? Color(hex: 0xFF0819) : Color(hex: 0xC8C8C8)))
                                        }
                                        .contentShape(Rectangle())
                                        .buttonStyle(.plain)
                                    }
                                    .opacity(hasActiveFilters ? 0.5 : 1.0)
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Sort by:")
                                            .font(.custom("Nunito-Black", size: 14))
                                            .foregroundStyle(Color(hex: 0x505050))

                                        Spacer()

                                        Menu {
                                            Picker("Sort field", selection: $sortIndex) {
                                                ForEach(sortFields.indices, id: \.self) { i in
                                                    Text(sortFields[i].name ?? sortFields[i].field)
                                                        .tag(i)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                let idx = sortFields.indices.contains(sortIndex) ? sortIndex : 0
                                                Text(sortFields[idx].name ?? sortFields[idx].field)
                                                    .font(.custom("Nunito-Black", size: 14))
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12, weight: .black))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .contentShape(Rectangle())
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                                            )
                                        }
                                        .disabled(hasActiveFilters)
                                        .opacity(hasActiveFilters ? 0.5 : 1.0)
                                    }
                                    
                                    if hasActiveFilters {
                                        Text("sorting is locked to the default while filters are active")
                                            .font(.custom("Nunito-Black", size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                                )
                            }
                        }
                        
                        // MARK: - Filter section
                        if !filterGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Filter")
                                        .font(.custom("Nunito-Black", size: 20))
                                    
                                    Spacer()
                                    
                                    if hasActiveFilters {
                                        Button {
                                            resetFilters()
                                        } label: {
                                            Text("reset filters")
                                                .font(.custom("Nunito-Black", size: 12))
                                                .foregroundColor(Color(hex: 0xFF0819))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                ForEach(filterGroups, id: \.self) { group in
                                    filterGroupView(group)
                                }
                                if !isDefaultSort {
                                    Text("filters are disabled while custom sort is active")
                                        .font(.custom("Nunito-Black", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onApply()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .black))
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.glassProminent)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.glassProminent)
                    .tint(Color(hex: 0xFFFFFF))
                    .foregroundStyle(Color(hex: 0x000000))
                }
            }
        }
        .tint(Color(hex: 0xFF0819))
        .font(.custom("Nunito-Black", size: 15))
        .presentationDetents([.medium, .large])
        .onChange(of: selectedFilterValues) { _, _ in
            if hasActiveFilters {
                // Force default sort = first item
                sortIndex = 0
                sortDescending = isDescLocal(sortFields.first?.sort)
                userSetPrimaryDir = false
            }
        }
    }
    
    // If any option in a group is selected, that group becomes the active one.
    private var activeGroupName: String? {
        for g in filterGroups {
            for opt in g.filters {
                if let set = selectedFilterValues[opt.field], !set.isEmpty {
                    return g.groupName
                }
            }
        }
        return nil
    }
    
    @ViewBuilder
    private func filterGroupView(_ group: FilterGroup) -> some View {
        // If any option in a group is selected, that group becomes the active one.
        let groupIsActive = isDefaultSort && ((activeGroupName == nil) || (activeGroupName == group.groupName))
        let isExpanded = expandedGroups.contains(group.groupName)
        
        VStack(alignment: .leading, spacing: 8) {
            Text(group.groupName)
                .font(.custom("Nunito-Black", size: 13))
                .foregroundStyle(Color(hex: 0x505050))
            
            let allOptions = group.filters
            let maxVisible = isExpanded ? allOptions.count : min(allOptions.count, 10)
            let visibleOptions = Array(allOptions.prefix(maxVisible))
            let showMoreNeeded = allOptions.count > 10

            FlexibleView(spacing: 8, alignment: .leading) {
                ForEach(visibleOptions, id: \.self) { opt in
                    let isSelected = selectedFilterValues[opt.field, default: []].contains(opt.value)

                    Button {
                        withAnimation {
                            var set = selectedFilterValues[opt.field, default: []]
                            if isSelected {
                                set.remove(opt.value)
                            } else {
                                set.insert(opt.value)
                            }
                            selectedFilterValues[opt.field] = set
                        }
                    } label: {
                        Text(opt.name)
                            .font(.custom("Nunito-Black", size: 13))
                            .foregroundColor(isSelected ? Color(hex: 0xFFFFFF) : Color(hex: 0x505050))
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color(hex: 0x505050) : Color(hex: 0xFFFFFF))
                                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!groupIsActive)
                    .opacity(groupIsActive ? 1.0 : 0.45)
                }
                
                if showMoreNeeded {
                    Button {
                        withAnimation {
                            if isExpanded {
                                expandedGroups.remove(group.groupName)
                            } else {
                                expandedGroups.insert(group.groupName)
                            }
                        }
                    } label: {
                        Text(isExpanded ? "show less" : "show more")
                            .font(.custom("Nunito-Black", size: 12))
                            .foregroundColor(Color(hex: 0xFF0819))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!groupIsActive)
                    .opacity(groupIsActive ? 1.0 : 0.45)
                }
            }
        }
        .frame(minHeight: CGFloat(28 * min(3, max(1, group.filters.count))))
    }
}

private struct ButtonsStepView: View {
    let step: SubcategoryDestinationConfig
    let tint: Color
    let onPick: (String) -> Void
    
    var body: some View {
        ScrollView { LazyVStack(spacing: 10) { ForEach(step.buttons) { b in Button { onPick(b.id) } label: { HStack { Image(systemName: b.icon); Text(b.name).font(.system(size: 15, weight: .black)); Spacer(); Image(systemName: "chevron.forward").foregroundStyle(.secondary) }.padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white).shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)) }.tint(tint) } }.padding() }
    }
}

private func resolveTemplate(_ template: String?, with hit: AlgoliaItemHit) -> String? {
    guard let template, !template.isEmpty else { return nil }
    var out = template
    let regex = try! NSRegularExpression(pattern: #"\(([^)]+)\)"#)
    let ns = out as NSString
    // collect matches first so offsets don't shift while replacing
    let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length))
    var replacements: [(NSRange, String)] = []
    for m in matches.reversed() { // reverse so ranges remain valid
        let key = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        let val = stringify(nestedValue(hit.raw, keyPath: key)) ?? ""
        replacements.append((m.range, val))
    }
    // apply
    for (range, val) in replacements {
        out = (out as NSString).replacingCharacters(in: range, with: val)
    }
    // trim any double-spaces that may result from empty vals
    return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func nested(_ dict: [String: Any], keyPath: String) -> Any? {
    var cur: Any? = dict
    for k in keyPath.split(separator: ".").map(String.init) {
        if let d = cur as? [String: Any] {
            cur = d[k]
        } else {
            return nil
        }
    }
    return cur
}

private func resolveAsterisk(_ template: String, with ctx: FlowContext) -> String {
    guard template.contains("*"), let token = firstContextToken(ctx), !token.isEmpty else { return template }
    return template.replacingOccurrences(of: "*", with: token)
}

private func firstContextToken(_ ctx: FlowContext) -> String? {
    // ✅ prefer the value collected from the most recent step (e.g., ItemName from step3)
    if let first = ctx.collectedIDs.first, !first.isEmpty { return first }
    return ctx.selectedButtonID
}

// MARK: - AlgoliaStepView
private struct AlgoliaStepView: View {
    let step: SubcategoryDestinationConfig
    let ctx: FlowContext
    let tint: Color
    @Binding var searchText: String
    let submitNonce: Int
    let forwardIDs: ([String]) -> Void
    let onSetVars: (([String:String]) -> Void)?
    let onJump: ((Int) -> Void)?
    @State private var isLoading = false
    private let animationDuration = 0.8

    @EnvironmentObject private var basket: SelectionBasket

    @State private var page = 1
    @State private var total = 0
    @State private var rows: [StepRow] = []
    @State private var hits: [AlgoliaItemHit] = []   // keep raw hits for token extraction
    @State private var hasFetched = false
    @State private var client: AlgoliaAddRecords<AlgoliaItemHit>?

    // local selection state for checkmarks
    @State private var selectedRowIDs: Set<String> = []

    // 🔎 debug state
    @State private var lastIndex: String = ""
    @State private var lastFilters: String = ""
    @State private var lastQuery: String = ""
    @State private var lastErr: String?

    private var resolvedIndex: String {
        interpolateVars(step.algoliaIndex, with: ctx.vars)
    }
    private var resolvedFilters: String {
        interpolateVars(step.algoliaFilters, with: ctx.vars).trimmingCharacters(in: .whitespaces)
    }

    private func token(from hit: AlgoliaItemHit, using field: String) -> String {
        let key = field.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty || key == "objectID" { return hit.objectID }
        if let v = hit.string(for: key) { return v }                 // supports "a.b.c"
        if key.caseInsensitiveCompare("ItemName") == .orderedSame {
            return hit.name ?? hit.objectID
        }
        if key.caseInsensitiveCompare("name") == .orderedSame {
            return hit.name ?? hit.objectID
        }
        return hit.objectID
    }
    
    private var lastPage: Int {
        max(1, Int(ceil(Double(total) / Double(step.hitsPerPage))))
    }

    @State private var showDebug: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // 🧰 inline debug banner (tap to hide if you want)
                    if showDebug {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEBUG — Algolia").font(.caption).bold()
                            Text("index: \(lastIndex)").font(.caption2)
                            Text("filters: \(lastFilters.isEmpty ? "(none)" : lastFilters)").font(.caption2)
                            Text("query: \(lastQuery.isEmpty ? "(empty)" : lastQuery)").font(.caption2)
                            if let e = lastErr {
                                Text("error: \(e)").font(.caption2).foregroundStyle(.red)
                            } else {
                                Text("hits: \(total)").font(.caption2)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }
                    
                    if isLoading {  // ✅ show loader while fetching
                        ThreeRectanglesAnimation(
                            rectangleWidth: 40,
                            rectangleMaxHeight: 130,
                            rectangleSpacing: 7,
                            rectangleCornerRadius: 6,
                            animationDuration: animationDuration
                        )
                        .frame(height: 170)
                        .padding(.top, 32)
                    } else if !hasFetched {
                        // first render before any search kicked off
                        Text("search the \(resolvedIndex) index…").padding(.top, 40)
                    } else if rows.isEmpty {
                        Text("No results").padding(.top, 40)
                    } else {
                        List(Array(rows.enumerated()), id: \.1.id) { (i, r) in
                            rowContent(rows[i], isSelected: selectedRowIDs.contains(r.id))
                                .onTapGesture {
                                    if step.selectable { togglePick(at: i) }
                                    else { openNext(at: i) }
                                }
                        }
                        .listStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    PagingBar(tint: tint, lastPage: lastPage, currentPage: $page) { p in
                        runSearch(trigger: "pager -> \(p)")
                    }
                }
            }
        }
        .onAppear {
            buildClient()
            runSearch(trigger: "onAppear")
        }
        .task(id: submitNonce) {
            page = 1
            runSearch(trigger: "onSubmit")
        }
        .id(resolvedIndex + "|" + resolvedFilters + "|" + (ctx.selectedButtonID ?? ctx.collectedIDs.first ?? ""))
    }

    @ViewBuilder
    private func rowContent(_ r: StepRow, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: r.imageURL ?? "")) { imagePhase in
                switch imagePhase {
                case .empty:  SkeletonView(Circle()).frame(width: 44, height: 44)
                case .success(let img): img.resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure: Image(systemName: "photo").frame(width: 44, height: 44)
                @unknown default: EmptyView()
                }
            }
            VStack(alignment: .leading) {
                Text(r.name).font(.custom("Nunito-Black", size: 15))
                if let d = r.desc, !d.isEmpty {
                    Text(d).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: step.selectable
                  ? (isSelected ? "checkmark.circle.fill" : "plus.circle")
                  : "chevron.forward")
            .foregroundStyle(step.selectable ? tint : .secondary)
            .transition(.scale.combined(with: .opacity))
        }
        .contentShape(Rectangle())
    }
    
    private func captureVariables(from hit: AlgoliaItemHit) -> [String:String] {
        guard !step.variables.isEmpty else { return [:] }
        var out: [String:String] = [:]
        for (varName, fieldKey) in step.variables {
            let v: String
            if fieldKey == "objectID" || fieldKey == "id" {
                v = hit.objectID
            } else if let s = hit.string(for: fieldKey) {
                v = s
            } else {
                v = ""  // empty if missing
            }
            out[varName] = v
        }
        return out
    }

    private func togglePick(at index: Int) {
        let r = rows[index]
        if selectedRowIDs.contains(r.id) {
            selectedRowIDs.remove(r.id)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
            basket.toggleGeneric(r)
        } else {
            selectedRowIDs.insert(r.id)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { }
            basket.toggleGeneric(r)
        }
    }

    private func openNext(at index: Int) {
        guard index < hits.count else { return }
        let hit = hits[index]

        // 1) stash variables per mapping
        let newVars = captureVariables(from: hit)
        if !newVars.isEmpty {
            // mutate parent flow context via a closure
            // We’ll pass a setter from StepContentView (below)
            onSetVars?(newVars)
        }

        // Prepare merged vars for interpolation
        let mergedVars = ctx.vars.merging(newVars) { _, rhs in rhs }

        // 2) Try to resolve a nextStep (int or string template)
        if let j = resolveNextStep(step: step, docVars: mergedVars, payload: hit.raw) {
            print("[NAV][ALG] redirect found → step=\(j) | index=\(index) | objectID=\(hit.objectID) | mergedVars=\(mergedVars)")
            onJump?(j)
            print("[NAV][ALG] redirecting now → step=\(j)")
            return
        }

        // 3) legacy behavior: forward IDs if selectable == false
        let value = token(from: hit, using: step.algoliaGetField)
        forwardIDs([value])
    }
    
    // Helper to resolve nextStep (int or string template) from step config
    private func resolveNextStep(step: SubcategoryDestinationConfig, docVars: [String:String], payload: [String:Any]?) -> Int? {
        // 0) Prefer an explicit next_step coming from the CLICKED DOCUMENT (payload) or captured vars
        if let s = docVars["next_step"], !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let n = Int(trimmed) {
                print("[NAV][RESOLVER] next_step from docVars → \(trimmed) → INT=\(n)")
                return n
            } else {
                print("[NAV][RESOLVER] next_step from docVars not an int → '\(trimmed)' (ignored)")
            }
        }
        if let p = payload, let raw = p["next_step"] {
            let text: String = {
                switch raw {
                case let v as Int:    return String(v)
                case let v as String: return v
                case let v as NSNumber:
                    if CFNumberIsFloatType(v) { return String(v.intValue) }
                    return v.stringValue
                default: return String(describing: raw)
                }
            }().trimmingCharacters(in: .whitespacesAndNewlines)
            if let n = Int(text) {
                print("[NAV][RESOLVER] next_step from payload → \(text) → INT=\(n)")
                return n
            } else {
                print("[NAV][RESOLVER] next_step present in payload but not an int → '\(text)' (ignored)")
            }
        }

        // 1) If step config provides a STRING template for nextStep (e.g. "`next_step`" or "(next_step)") → resolve it
        let mirror = Mirror(reflecting: step)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label == "next_step" || label == "nextstepstring" || label == "nextsteptemplate" { // common aliases if present
                if let s = child.value as? String {
                    let withVars = interpolateVars(s, with: docVars)
                    print("[NAV][RESOLVER] step.nextStep STRING detected → raw='\(s)' | withVars='\(withVars)'")
                    let rendered: String
                    if let payload { rendered = renderTemplate(withVars, with: payload) } else { rendered = withVars }
                    let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("[NAV][RESOLVER] step.nextStep STRING rendered with payload → rendered='\(rendered)' | trimmed='\(trimmed)'")
                    if let n = Int(trimmed) {
                        print("[NAV][RESOLVER] step.nextStep STRING parsed INT → \(n)")
                        return n
                    }
                }
            }
        }
        
        // 2) Finally, use an INT property on the step config (e.g. nextStep: Int?)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label == "nextstep" || label == "next_step" { // accept either spelling
                if let n = child.value as? Int { print("[NAV][RESOLVER] step.nextStep INT detected → \(n)"); return n }
                if let s = child.value as? String, let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { print("[NAV][RESOLVER] step.nextStep STRING->INT (untemplated) → \(n)"); return n }
            }
        }

        print("[NAV][RESOLVER] no redirect resolved")
        return nil
    }

    private func runSearch(trigger: String) {
        hasFetched = true
        lastErr = nil
        guard let client else { return }

        isLoading = true
        lastQuery = searchText
        let offset = (max(1, page) - 1) * step.hitsPerPage

        print("🔎 [ALG] \(trigger) → index=\(resolvedIndex) | filters=\(resolvedFilters.isEmpty ? "(none)" : resolvedFilters) | query=\(searchText.isEmpty ? "(empty)" : "'\(searchText)'") | offset=\(offset) | length=\(step.hitsPerPage)")

        client.search(query: searchText, offset: offset, length: step.hitsPerPage) { newHits, nb in
            DispatchQueue.main.async {
                self.total = nb
                self.hits  = newHits

                self.rows = newHits.map { h in
                    // render with both `field` and (field) support
                    let name = {
                        let t = step.itemName
                        let s = renderTemplate(t, with: h.raw)
                        return s.isEmpty ? (h.name ?? "Unknown") : s
                    }()

                    let desc = {
                        let t = step.itemDescription
                        let s = renderTemplate(t, with: h.raw)
                        return s.isEmpty ? h.description : s
                    }()

                    let img = {
                        let t = step.itemImage
                        let s = renderTemplate(t, with: h.raw)
                        return s.isEmpty ? h.image : s
                    }()

                    return StepRow(id: h.objectID, name: name, desc: desc, imageURL: img)
                }

                self.isLoading = false

                if let first = newHits.first {
                    print("✅ [ALG] got \(nb) hits (showing \(self.rows.count)). sample:")
                    let sampleName = {
                        let s = renderTemplate(step.itemName, with: first.raw)
                        return s.isEmpty ? (first.name ?? "nil") : s
                    }()
                    let sampleDesc = {
                        let s = renderTemplate(step.itemDescription, with: first.raw)
                        return s.isEmpty ? (first.description ?? "nil") : s
                    }()
                    let sampleImg  = {
                        let s = renderTemplate(step.itemImage, with: first.raw)
                        return s.isEmpty ? (first.image ?? "nil") : s
                    }()
                    print("    objectID=\(first.objectID)")
                    print("    name=\(sampleName) desc=\(sampleDesc) image=\(sampleImg)")
                } else if !resolvedFilters.isEmpty {
                    print("⚠️ [ALG] zero hits")
                }
            }
        }
    }

    private func buildClient() {
        lastIndex = resolvedIndex
        lastFilters = resolvedFilters

        // Step overrides → fallback to Secrets if blank or labeled
        var appID  = step.algoliaAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        var apiKey = step.algoliaAppKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) known label → map to secrets
        let labelToSecrets: [String: (String, String)] = [
            "geographyAlgoliaAppID": (Secrets.geographyAlgoliaAppID, Secrets.geographyAlgoliaAPIKey),
            "geographyalgoliaappid": (Secrets.geographyAlgoliaAppID, Secrets.geographyAlgoliaAPIKey),
            "ALGOLIA_APP_ID":        (Secrets.algoliaAppID,        Secrets.algoliaAPIKey),
            "algolia_app_id":        (Secrets.algoliaAppID,        Secrets.algoliaAPIKey),
            // add other category labels here if you use them
        ]
        if let pair = labelToSecrets[appID] {
            appID  = pair.0
            apiKey = pair.1
        }

        // 2) blank → global secrets
        if appID.isEmpty  { appID  = Secrets.algoliaAppID }
        if apiKey.isEmpty { apiKey = Secrets.algoliaAPIKey }

        // 3) pattern check → if it still doesn't look like a real AppID, try index-based secrets then global
        let looksReal = appID.range(of: #"^[A-Z0-9]{8,}$"#, options: .regularExpression) != nil
        if !looksReal {
            // optional: per-index secrets
            let secretsByIndex: [String: (String, String)] = [
                "Geography": (Secrets.geographyAlgoliaAppID, Secrets.geographyAlgoliaAPIKey),
                // "Music": (...), etc if you have category-specific apps
            ]
            if let pair = secretsByIndex[resolvedIndex] {
                appID  = pair.0
                apiKey = pair.1
            } else {
                // final fallback
                appID  = Secrets.algoliaAppID
                apiKey = Secrets.algoliaAPIKey
            }
            print("⚠️ [ALG] suspicious appID in step; using fallback for index '\(resolvedIndex)'")
        }

        client = AlgoliaAddRecords<AlgoliaItemHit>(
            AlgoliaAppID: appID,
            AlgoliaAPIKey: apiKey,
            AlgoliaIndex: resolvedIndex,
            AlgoliaFilters: resolvedFilters.isEmpty ? nil : resolvedFilters,
            AlgoliaQuery: "",
            AlgoliaHitsPerPage: step.hitsPerPage
        )

        print("🔧 [ALG] buildClient → appID=\(appID), index=\(resolvedIndex), filters=\(resolvedFilters.isEmpty ? "(none)" : resolvedFilters), hpp=\(step.hitsPerPage)")
    }
}

private extension Encodable {
    func asDict() -> [String: Any] {
        // quick & safe: JSON round-trip → [String: Any]
        guard
            let data = try? JSONEncoder().encode(self),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }
}


// Replaces tokens from the provided vars only (no document context here)
// Supports backticks:  `token`
// and parentheses:     (token)
// Overload with fallback resolver for dynamic tokens
private func interpolateVars(
        _ template: String,
        with vars: [String:String],
        fallback: ((String) -> String?)? = nil
) -> String {
    guard !template.isEmpty else { return template }
    var out = template
    
    // 1) Backticks: `token`
    do {
        let regex = try NSRegularExpression(pattern: #"`([A-Za-z0-9_]+)`"#)
        let ns = out as NSString
        let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let key = ns.substring(with: m.range(at: 1))
            if let val = vars[key] ?? fallback?(key) {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            } else if key == "filter_field", let val = vars["filter_field"] ?? vars["field"] {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            } else if key == "filter_id", let val = vars["filter_id"] ?? vars["id"] {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            }
        }
    } catch {
        print("[FS] regex(backticks) failed: \(error)")
    }
    
    // 2) Parentheses: (token)
    do {
        let regex = try NSRegularExpression(pattern: #"\(([A-Za-z0-9_]+)\)"#)
        let ns = out as NSString
        let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let key = ns.substring(with: m.range(at: 1))
            if let val = vars[key] ?? fallback?(key) {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            } else if key == "filter_field", let val = vars["filter_field"] ?? vars["field"] {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            } else if key == "filter_id", let val = vars["filter_id"] ?? vars["id"] {
                out = (out as NSString).replacingCharacters(in: m.range, with: val)
            }
        }
    } catch {
        print("[FS] regex(parentheses) failed: \(error)")
    }
    
    return out
}

// Convenience overload (keeps old call sites compiling)
private func interpolateVars(_ template: String, with vars: [String:String]) -> String {
    return interpolateVars(template, with: vars, fallback: nil)
}

private func renderTemplate(_ template: String, with ctx: [String: Any]) -> String {
    // supports both `field` and (field)
    let patterns = [
        #"`([A-Za-z0-9_]+)`"#,
        #"\(([A-Za-z0-9_]+)\)"#
    ]
    var output = template

    for pat in patterns {
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        // replace from end to start to keep ranges valid
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: (output as NSString).length)).reversed()
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let keyRange = m.range(at: 1)
            let key = (output as NSString).substring(with: keyRange)
            let raw = ctx[key]

            // stringify nicely
            let text: String = {
                switch raw {
                case let v as String: return v
                case let v as NSNumber:
                    // avoid 12.0 for ints
                    if CFNumberIsFloatType(v) {
                        // trim trailing .0
                        let s = String(describing: v)
                        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
                    } else { return v.stringValue }
                case let v as [Any]: return v.map { "\($0)" }.joined(separator: ", ")
                case let v as [String: Any]:
                    // shallow JSON for objects
                    if let data = try? JSONSerialization.data(withJSONObject: v),
                       let s = String(data: data, encoding: .utf8) { return s }
                    return "\(v)"
                case .none: return ""
                default: return "\(raw!)"
                }
            }()

            output = (output as NSString).replacingCharacters(in: m.range, with: text)
        }
    }

    // collapse double spaces that can appear after empty fields
    return output.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
}


public struct AnyDecodable: Decodable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = NSNull()
        } else if let b = try? c.decode(Bool.self) {
            self.value = b
        } else if let i = try? c.decode(Int.self) {
            self.value = i
        } else if let d = try? c.decode(Double.self) {
            self.value = d
        } else if let s = try? c.decode(String.self) {
            self.value = s
        } else if let arr = try? c.decode([AnyDecodable].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? c.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            // fallback raw data
            self.value = try c.decode(String.self)
        }
    }
}

private func asString(_ v: Any?) -> String? {
    switch v {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    case let a as [Any]: return a.compactMap { asString($0) }.joined(separator: ", ")
    default: return nil
    }
}
private func firstString(in hit: [String: Any], keys: [String]) -> String? {
    for k in keys {
        if let s = asString(nestedValue(hit, keyPath: k)), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
    }
    return nil
}
private func normalizeImageURL(_ url: String?) -> String? {
    guard let u = url, !u.isEmpty else { return nil }
    if u.hasPrefix("http://") || u.hasPrefix("https://") { return u }
    if u.hasPrefix("//") { return "https:\(u)" }
    if u.hasPrefix("/")  { return "https://your.cdn.host\(u)" } // tweak if needed
    return u
}

public struct AlgoliaItemHit: Identifiable, Decodable {
    // raw payload for token/template extraction
    public let raw: [String: Any]

    // core fields used by UI
    public let id: String
    public var objectID: String { id } // 👈 alias to satisfy callers expecting `objectID`

    public let name: String?
    public let description: String?
    public let image: String?
    public let other: String?

    public init(from decoder: Decoder) throws {
        // decode the whole object into [String: Any]
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyDecodable].self).mapValues { $0.value }
        self.raw = dict

        // id / objectID
        let idVal = firstString(in: dict, keys: ["objectID","id","objectId","key","slug","uuid"]) ?? UUID().uuidString
        self.id = idVal

        // reasonable defaults (step templates can override later when you render)
        self.name = firstString(in: dict, keys: ["name","title","Name","ItemName"])

        self.description = firstString(
            in: dict,
            keys: ["description","desc","subtitle","blurb","summary","ItemDescription"]
        )

        self.image = normalizeImageURL(
            firstString(in: dict, keys: [
                "image","images","thumbnail","thumb","artwork",
                "cover","cover.url","poster_path","poster.url","ItemImage"
            ])
        )

        self.other = firstString(
            in: dict,
            keys: ["type","category","kind","ItemCategory","ItemCategories.Continent"]
        )
    }

    // convenience key-path accessor for token(...)
    public func string(for keyPath: String) -> String? {
        asString(nestedValue(raw, keyPath: keyPath))
    }
}

enum FirestoreFilterOp: String, Codable {
    case isEqualTo                 = "isEqualTo"
    case isNotEqualTo              = "isNotEqualTo"
    case isLessThan                = "isLessThan"
    case isLessThanOrEqualTo       = "isLessThanOrEqualTo"
    case isGreaterThan             = "isGreaterThan"
    case isGreaterThanOrEqualTo    = "isGreaterThanOrEqualTo"
    // legacy/alias spellings (keep for backward-compat with older configs)
    case isGreaterOrEqualTo        = "isGreaterOrEqualTo"
    case arrayContains             = "arrayContains"
    case arrayContainsAny          = "arrayContainsAny"
    case `in`                      = "in"
    case notIn                     = "notIn"
}

enum FSValue: Hashable, Codable, CustomStringConvertible {
    case string(String), int(Int), double(Double), bool(Bool)

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let i = try? c.decode(Int.self)    { self = .int(i); return }
        if let x = try? c.decode(Double.self) { self = .double(x); return }
        if let b = try? c.decode(Bool.self)   { self = .bool(b); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .string(try c.decode(String.self))
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }
    var description: String { pretty }
    var pretty: String {
        switch self {
        case .int(let v): return String(v)
        case .double(let v):
            var s = String(v)
            if s.hasSuffix(".0") { s.removeLast(2) }
            return s
        case .bool(let v): return v ? "true" : "false"
        case .string(let v):
            if v.contains(" ") || v.contains(":") || v.contains(",") { return "\"\(v)\"" }
            return v
        }
    }
}

struct FirestoreFilter: Hashable, Codable {
    let field: String
    let op: FirestoreFilterOp
    let value: FSValue?        // scalar ops
    let values: [FSValue]?     // array ops: in/notIn/arrayContainsAny
    let group: Int?            // same group id = OR together

    var isArrayOp: Bool { op == .in || op == .notIn || op == .arrayContainsAny }
    var isDisjunction: Bool { op == .in || op == .arrayContainsAny }

    // Factory used by parser that accepts raw Any from JSON
    static func make(field: String, op: FirestoreFilterOp, raw: Any?, group: Int?) -> FirestoreFilter? {
        func toFS(_ any: Any) -> FSValue? {
            switch any {
            case let v as String: return .string(v)
            case let v as NSNumber:
                if CFNumberIsFloatType(v) { return .double(v.doubleValue) }
                return .int(v.intValue)
            case let v as Bool: return .bool(v)
            default: return nil
            }
        }
        if op == .in || op == .notIn || op == .arrayContainsAny {
            let arr: [FSValue] = {
                if let a = raw as? [Any] { return a.compactMap { toFS($0) } }
                if let single = raw { return [toFS(single)].compactMap { $0 } }
                return []
            }()
            return FirestoreFilter(field: field, op: op, value: nil, values: arr, group: group)
        } else {
            let v: FSValue? = {
                if let any = raw { return toFS(any) }
                return nil
            }()
            return FirestoreFilter(field: field, op: op, value: v, values: nil, group: group)
        }
    }
}

// tiny helper so we can do FirestoreFilterOp(rawValue: "in") case-insensitively
protocol CaseInsensitiveRepresentable {
    init?(rawValue: String)
}
extension CaseInsensitiveRepresentable where Self: RawRepresentable, Self.RawValue == String {
    init?(rawValue: String) {
        let lower = rawValue.lowercased()
        if let match = (Mirror(reflecting: Self.self).children
            .compactMap { $0.label }
            .compactMap { Self(rawValue: $0) }
            .first(where: { String(describing: $0).lowercased().contains(lower) })) {
            self = match
        } else {
            return nil
        }
    }
}



// MARK: - Firestore Step (RTDB → FS)
private struct FirestoreStepView: View {
    let step: SubcategoryDestinationConfig
    let tint: Color
    let incomingIDs: [String]
    let vars: [String:String]
    @Binding var searchText: String
    let submitNonce: Int
    let sortIndex: Int
    let sortDescendingOverride: Bool
    let forwardIDs: ([String]) -> Void
    let onSetVars: (([String:String]) -> Void)?
    @State private var rowPayloads: [[String: Any]] = []   // parallel to rows by index
    let onJump: ((Int) -> Void)?
    let runtimeFilters: [FirestoreFilter]
    let selectedStringFilters: [String : Set<String>]

    @EnvironmentObject private var basket: SelectionBasket

    @State private var isLoading = true
    @State private var hasFetched = false
    @State private var rows: [StepRow] = []
    @State private var selectedIDs: Set<String> = []
    
    @State private var totalCount: Int = 0
    @State private var currentPage: Int = 1
    @State private var cursors: [Int: DocumentSnapshot] = [:]   // page -> lastDoc snapshot (page 1 has none)
    @State private var queryIdentity: String = ""               // to know when to reset cursors

    private var lastPage: Int {
        guard step.hitsPerPage > 0 else { return 1 }
        return max(1, Int(ceil(Double(totalCount) / Double(step.hitsPerPage))))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                else if hasFetched && rows.isEmpty {
                    Spacer()
                    Text("no results")
                    Spacer()
                }
                else {
                    List(rows) { r in
                        let picked = selectedIDs.contains(r.id)
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: r.imageURL ?? "")) { $0.resizable() } placeholder: { Color.gray.opacity(0.15) }
                                .scaledToFill().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name)
                                .font(.custom("Nunito-Black", size: 15))
                                if let d = r.desc, !d.isEmpty { Text(d).font(.custom("Nunito-Black", size: 11)).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Image(systemName: step.selectable
                                  ? (picked ? "checkmark.circle.fill" : "plus.circle")
                                  : "chevron.forward")
                            .foregroundStyle(step.selectable ? tint : .secondary)
                            .transition(.scale.combined(with: .opacity))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(r) }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                PagingBar(tint: tint, lastPage: lastPage, currentPage: $currentPage) { p in
                    currentPage = p
                    Task { await load() }
                }
            }
        }
        .onAppear {
            Task { await load() }
        }
        .onChange(of: submitNonce) { _, _ in
            currentPage = 1
            cursors.removeAll()
            Task { await load() }
        }
    }
    
    private func makeSelectStringFilters(_ selected: [String: Set<String>]) -> [FirestoreFilter] {
        guard !selected.isEmpty else { return [] }

        // avoid clashing with step filter groups
        let baseGroup = (step.firebaseFilters.compactMap { $0.group }.max() ?? 0) + 10

        var out: [FirestoreFilter] = []
        var offset = 0

        for (field, values) in selected {
            guard !values.isEmpty else { continue }
            let groupID = baseGroup + offset
            offset += 1

            for value in values.sorted() {
                if let f = FirestoreFilter.make(field: field, op: .isEqualTo, raw: value, group: groupID) {
                    out.append(f)
                }
            }
        }

        print("🧪 [FS] chip OR groups:\n\t\(debugDescribeFilters(out))")
        return out
    }
    
    private func resolveValue(_ v: FSValue, vars: [String:String], incomingIDs: [String]) -> Any {
        switch v {
        case .int(let i):    return i
        case .double(let d): return d
        case .bool(let b):   return b
        case .string(let s):
            // interpolate flow vars and incomingIDs
            let withVars = interpolateVars(s, with: vars)
            let withIDs  = substituteIncomingIDs(withVars, vars: vars)
            if let i = Int(withIDs)    { return i }
            if let d = Double(withIDs) { return d }
            if withIDs == "true"       { return true }
            if withIDs == "false"      { return false }
            return withIDs
        }
    }
    
    private func applyFirebaseFilters(_ base: Query, filters: [FirestoreFilter]) -> Query {
        guard !filters.isEmpty else { return base }
        
        let desc = debugDescribeFilters(filters)
        print("[FS] vars=\(vars)")
        print("[FS] incomingIDs=\(incomingIDs)")
        print("[FS] applying filters: \(desc)")
        print("[FS] filters(after interpolateVars): \(desc)")
        // Build a composed Filter using groups (same group => OR; no group => AND)
        if let root = buildFilterTree(filters, vars: vars, incomingIDs: incomingIDs) {
            return base.whereFilter(root)
        }
        return base
    }
    
    private func buildFilterTree(
        _ filters: [FirestoreFilter],
        vars: [String:String],
        incomingIDs: [String]
    ) -> Filter? {
        guard !filters.isEmpty else { return nil }

        // Firestore limitation: only one of (in|not-in|array-contains-any) per query.
        // we'll enforce it softly and drop extras with a warning.
        var usedDisjunction: FirestoreFilterOp?

        // split by group (nil = ungrouped)
        let grouped = Dictionary(grouping: filters, by: { $0.group })

        // turn a single FirestoreFilter into a Filter.whereField(...)
        func predicate(from f: FirestoreFilter) -> Filter? {
            // enforce disjunction restriction
            if f.isArrayOp {
                if let u = usedDisjunction, u != f.op {
                    print("⚠️ Firestore allows only one of (in/not-in/array-contains-any) per query. Skipping \(f.op).")
                    return nil
                }
                usedDisjunction = f.op
            }

            // ✅ interpolate backtick tokens in the *field name*, using fallback for filter_id only
            let fieldName = interpolateVars(f.field, with: vars) { key in
                if key == "filter_id" { return incomingIDs.first }
                // Allow `filter_field` to be sourced from previously saved vars
                if key == "filter_field" { return vars["filter_field"] }
                return nil
            }
            if fieldName.contains("`") {
                print("⚠️ [FS] unresolved field token in filter: field='\(fieldName)'. vars=\(vars)")
            }

            switch f.op {
            case .isEqualTo:
                if let v = f.value {
                    let rv: Any
                    switch v {
                    case .string(let s):
                        rv = resolveStringLiteral(s, vars: vars, incomingIDs: incomingIDs)   // keep "1" as "1"
                    default:
                        rv = resolveValue(v, vars: vars, incomingIDs: incomingIDs)
                    }
                    print("[FS] where \(fieldName) \(f.op.rawValue) \(String(describing: rv))")
                    return Filter.whereField(fieldName, isEqualTo: rv)
                }
            case .isNotEqualTo:
                if let v = f.value { return Filter.whereField(fieldName, isNotEqualTo: resolveValue(v, vars: vars, incomingIDs: incomingIDs)) }
            case .isLessThan:
                if let v = f.value { return Filter.whereField(fieldName, isLessThan: resolveValue(v, vars: vars, incomingIDs: incomingIDs)) }
            case .isLessThanOrEqualTo:
                if let v = f.value { return Filter.whereField(fieldName, isLessThanOrEqualTo: resolveValue(v, vars: vars, incomingIDs: incomingIDs)) }
            case .isGreaterThan:
                if let v = f.value { return Filter.whereField(fieldName, isGreaterThan: resolveValue(v, vars: vars, incomingIDs: incomingIDs)) }
            case .isGreaterThanOrEqualTo, .isGreaterOrEqualTo:
                if let v = f.value { return Filter.whereField(fieldName, isGreaterOrEqualTo: resolveValue(v, vars: vars, incomingIDs: incomingIDs)) }
            case .arrayContains:
                if let v = f.value {
                    let rv: Any
                    switch v {
                    case .string(let s): rv = resolveStringLiteral(s, vars: vars, incomingIDs: incomingIDs)
                    default:             rv = resolveValue(v, vars: vars, incomingIDs: incomingIDs)
                    }
                    print("[FS] where \(fieldName) arrayContains \(String(describing: rv))")
                    return Filter.whereField(fieldName, arrayContains: rv)
                }
            case .arrayContainsAny:
                if let arr = f.values, !arr.isEmpty {
                    let resolved: [Any] = arr.map { v in
                        switch v {
                        case .string(let s): return resolveStringLiteral(s, vars: vars, incomingIDs: incomingIDs)
                        default:             return resolveValue(v, vars: vars, incomingIDs: incomingIDs)
                        }
                    }
                    let list = resolved.map { String(describing: $0) }.joined(separator: ", ")
                    print("[FS] where \(fieldName) \(f.op.rawValue) [\(list)]")
                    return Filter.whereField(fieldName, arrayContainsAny: resolved)
                }
            case .in:
                if let arr = f.values, !arr.isEmpty {
                    let resolved: [Any] = arr.map { v in
                        switch v {
                        case .string(let s): return resolveStringLiteral(s, vars: vars, incomingIDs: incomingIDs)
                        default:             return resolveValue(v, vars: vars, incomingIDs: incomingIDs)
                        }
                    }
                    let list = resolved.map { String(describing: $0) }.joined(separator: ", ")
                    print("[FS] where \(fieldName) \(f.op.rawValue) [\(list)]")
                    return Filter.whereField(fieldName, in: resolved)
                }
            case .notIn:
                if let arr = f.values, !arr.isEmpty {
                    let resolved: [Any] = arr.map { v in
                        switch v {
                        case .string(let s): return resolveStringLiteral(s, vars: vars, incomingIDs: incomingIDs)
                        default:             return resolveValue(v, vars: vars, incomingIDs: incomingIDs)
                        }
                    }
                    let list = resolved.map { String(describing: $0) }.joined(separator: ", ")
                    print("[FS] where \(fieldName) \(f.op.rawValue) [\(list)]")
                    return Filter.whereField(fieldName, notIn: resolved)
                }
            }
            return nil
        }

        // build per-group filters
        var andBuckets: [Filter] = []

        for (maybeGroup, members) in grouped {
            // turn members into Filter predicates
            let preds = members.compactMap(predicate(from:))
            guard !preds.isEmpty else { continue }

            if let _ = maybeGroup {
                // OR this group
                if preds.count == 1 {
                    andBuckets.append(preds[0])        // single predicate → no need to orFilter
                } else {
                    andBuckets.append(Filter.orFilter(preds))
                }
            } else {
                // ungrouped → AND as standalone terms
                andBuckets.append(contentsOf: preds)
            }
        }

        guard !andBuckets.isEmpty else { return nil }
        return (andBuckets.count == 1) ? andBuckets[0] : Filter.andFilter(andBuckets)
    }
    
    private func resolveStringLiteral(_ s: String, vars: [String:String], incomingIDs: [String]) -> String {
        let withVars = interpolateVars(s, with: vars)
        let withIDs  = substituteIncomingIDs(withVars, vars: vars)
        return withIDs
    }
    
    private func debugResolvedValue(_ v: FSValue?) -> String {
        guard let v else { return "(nil)" }
        switch v {
        case .int(let i):    return String(i)
        case .double(let d):
            var s = String(d); if s.hasSuffix(".0") { s.removeLast(2) }
            return s
        case .bool(let b):   return b ? "true" : "false"
        case .string(let s):
            let withVars = interpolateVars(s, with: vars)
            let withIDs  = substituteIncomingIDs(withVars, vars: vars)
            return withIDs
        }
    }

    private func debugDescribeFilters(_ filters: [FirestoreFilter]) -> String {
        if filters.isEmpty { return "(none)" }
        return filters.map { f in
            let fieldName = interpolateVars(f.field, with: vars)
            if let vs = f.values, !vs.isEmpty {
                let arr = vs.map { debugResolvedValue($0) }.joined(separator: ", ")
                return "\(fieldName) \(f.op.rawValue) [\(arr)] group=\(f.group?.description ?? "-")"
            } else {
                return "\(fieldName) \(f.op.rawValue) \(debugResolvedValue(f.value)) group=\(f.group?.description ?? "-")"
            }
        }.joined(separator: " | ")
    }
    
    private func makeIdentityString() -> String {
        // Resolve the final Firestore path deterministically
        let rawPath   = step.firebaseIdPath
        let afterVars = interpolateVars(rawPath, with: vars)
        let finalPath = substituteIncomingIDs(afterVars, vars: vars)

        // Stable signature of filters with already configured values
        let combinedFilters = step.firebaseFilters + runtimeFilters
        let filterSig = combinedFilters
            .map { f in
                let fField = interpolateVars(f.field, with: vars)
                return "\(fField)|\(f.op.rawValue)|\(f.value.map({"\($0)"} ) ?? "-")|\((f.values ?? []).map({"\($0)"}).joined(separator: ","))|\(f.group.map(String.init) ?? "-")"
            }
            .joined(separator: ";")
        
        // Exclude paging so identity stays the same across pages
        return [
            "path=\(finalPath)",
            "f=\(filterSig)",
            "q=\(searchText.lowercased())",
            "p=\(sortIndex)",
            "d=\(sortDescendingOverride ? "1" : "0")"
        ].joined(separator: "|")
    }

    private func fetchCount(_ q: Query) async throws -> Int {
        let snap = try await q.count.getAggregation(source: .server)
        return snap.count.intValue
    }

    private func pageQuery(_ base: Query, page: Int) -> Query {
        print("[FS] pageQuery page=\(page) limit=\(step.hitsPerPage)")

        var q = base
        if page > 1, let snap = cursors[page - 1] {
            q = q.start(afterDocument: snap)
        }
        return q.limit(to: step.hitsPerPage)
    }

    private func onTap(_ r: StepRow) {
        // always emit the picked ID so the next step can resolve its path (e.g. (album_id))
        let pickedID = r.id
        
        if let idx = rows.firstIndex(where: { $0.id == r.id }), idx < rowPayloads.count {
            let payload = rowPayloads[idx]
            let newVars = captureVariables(from: payload, docID: pickedID)
            if !newVars.isEmpty { onSetVars?(newVars) }
            
            // Merge flow vars with fresh capture from this row
            var mergedVars = vars.merging(newVars) { _, rhs in rhs }

            // Determine whether this step should consider redirects
            let payloadHasNext = (payload["next_step"] != nil)
            let stepHasLocalNext = stepProvidesLocalNext(step)

            // If this step is selectable and has NO local redirect signal,
            // ignore any **inherited** next_step lingering in flow vars.
            if step.selectable && !payloadHasNext && !stepHasLocalNext {
                if let inherited = mergedVars.removeValue(forKey: "next_step") {
                    print("[NAV][RESOLVER] ignoring inherited next_step='\(inherited)' (selectable && no local next-step)")
                }
            }
            
            // Only attempt redirect if either the clicked payload carries next_step
            // or the step itself declares a next-step (string template or int)
            if payloadHasNext || stepHasLocalNext {
                if let jump = resolveNextStep(step: step, docVars: mergedVars, payload: payload) {
                    print("[NAV][FS] redirect found → step=\(jump) | docID=\(pickedID) | mergedVars=\(mergedVars)")
                    print("[NAV][FS] redirecting now → step=\(jump)")
                    onJump?(jump)
                    return
                }
            }
        }
        
        // fall back to selectable behavior if no redirect happened
        if step.selectable {
            if selectedIDs.contains(pickedID) {
                selectedIDs.remove(pickedID)
                basket.toggleGeneric(r)           // remove from basket
            } else {
                selectedIDs.insert(pickedID)
                basket.toggleGeneric(r)           // add to basket
            }
            return
        }

        forwardIDs([pickedID])
    }
    
    // Helper to resolve nextStep (int or string template) from step config
    private func resolveNextStep(step: SubcategoryDestinationConfig, docVars: [String:String], payload: [String:Any]?) -> Int? {
        if docVars["next_step"] == nil { print("[NAV][RESOLVER] docVars has no next_step (after sanitization)") }
        // 0) Prefer an explicit next_step coming from the CLICKED DOCUMENT (payload) or captured vars
        if let s = docVars["next_step"], !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let n = Int(trimmed) {
                print("[NAV][RESOLVER] next_step from docVars → \(trimmed) → INT=\(n)")
                return n
            } else {
                print("[NAV][RESOLVER] next_step from docVars not an int → '\(trimmed)' (ignored)")
            }
        }
        if let p = payload, let raw = p["next_step"] {
            let text: String = {
                switch raw {
                case let v as Int:    return String(v)
                case let v as String: return v
                case let v as NSNumber:
                    if CFNumberIsFloatType(v) { return String(v.intValue) }
                    return v.stringValue
                default: return String(describing: raw)
                }
            }().trimmingCharacters(in: .whitespacesAndNewlines)
            if let n = Int(text) {
                print("[NAV][RESOLVER] next_step from payload → \(text) → INT=\(n)")
                return n
            } else {
                print("[NAV][RESOLVER] next_step present in payload but not an int → '\(text)' (ignored)")
            }
        }

        // 1) If step config provides a STRING template for nextStep (e.g. "`next_step`" or "(next_step)") → resolve it
        let mirror = Mirror(reflecting: step)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label == "next_step" || label == "nextstepstring" || label == "nextsteptemplate" { // common aliases if present
                if let s = child.value as? String {
                    let withVars = interpolateVars(s, with: docVars)
                    print("[NAV][RESOLVER] step.nextStep STRING detected → raw='\(s)' | withVars='\(withVars)'")
                    let rendered: String
                    if let payload { rendered = renderTemplate(withVars, with: payload) } else { rendered = withVars }
                    let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("[NAV][RESOLVER] step.nextStep STRING rendered with payload → rendered='\(rendered)' | trimmed='\(trimmed)'")
                    if let n = Int(trimmed) {
                        print("[NAV][RESOLVER] step.nextStep STRING parsed INT → \(n)")
                        return n
                    }
                }
            }
        }
        
        // 2) Finally, use an INT property on the step config (e.g. nextStep: Int?)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label == "nextstep" || label == "next_step" { // accept either spelling
                if let n = child.value as? Int { print("[NAV][RESOLVER] step.nextStep INT detected → \(n)"); return n }
                if let s = child.value as? String, let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { print("[NAV][RESOLVER] step.nextStep STRING->INT (untemplated) → \(n)"); return n }
            }
        }

        print("[NAV][RESOLVER] no redirect resolved")
        return nil
    }
    
    // Helper to check if a step config provides any local next_step (int or string)
    private func stepProvidesLocalNext(_ step: SubcategoryDestinationConfig) -> Bool {
        // explicit int nextStep on the step config
        let mirror = Mirror(reflecting: step)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label == "nextstep" || label == "next_step" {
                if child.value is Int { return true }
                if let s = child.value as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            }
            // accept common aliases used in configs
            if label == "nextstepstring" || label == "nextsteptemplate" {
                if let s = child.value as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            }
        }
        return false
    }

    private func addSelected() {
        let picked = rows.filter { selectedIDs.contains($0.id) }
        for p in picked { basket.toggleGeneric(p) }
    }
    
    private func applyChosenSorts(to base: Query) -> Query {
        print("[FS] applying sorts…")
        var q = base
        guard !step.sortFields.isEmpty else { return q }

        // primary
        let pIdx = min(max(0, sortIndex), step.sortFields.count - 1)
        let p = step.sortFields[pIdx]
        let pField = interpolateVars(p.field, with: vars)
        q = q.order(by: pField, descending: sortDescendingOverride)
        print("[FS] sort₁ → \(pField) \(sortDescendingOverride ? "desc":"asc") (idx=\(pIdx))")
        
        return q
    }

    // Data
    private func load() async {
        isLoading = true; defer { isLoading = false; hasFetched = true }
        do {
            let db = FirestoreProvider.dbItems
            // build final path & base query
            let rawPath   = step.firebaseIdPath
            let afterVars = interpolateVars(rawPath, with: vars)
            let finalPath = substituteIncomingIDs(afterVars, vars: vars)

            print("[FS] PATH raw='\(rawPath)' → vars='\(afterVars)' → final='\(finalPath)'")
            print("[FS] hitsPerPage=\(step.hitsPerPage) currentPage=\(currentPage) search='\(searchText)'")
            
            // 🧪 Print active runtime filters at load start
            if !runtimeFilters.isEmpty {
                print("🧪 [FS] runtimeFilters active → \(debugDescribeFilters(runtimeFilters))")
            } else {
                print("🧪 [FS] runtimeFilters active → (none)")
            }

            let parts = finalPath.split(separator: "/").map(String.init)
            print("[FS] PATH parts=\(parts)")
            guard !parts.isEmpty else { rows = []; return }

            let (parent, lastKey) = walkToParent(db: db, parts: parts)

            // resolve COLLECTION ref
            let collectionRef: CollectionReference
            if let docRef = parent as? DocumentReference {
                // Case: ".../someDoc/<lastKey>"  → subcollection under a doc
                collectionRef = docRef.collection(lastKey)
            } else if let collRef = parent as? CollectionReference {
                // Case: ".../<aCollection>"      → already the collection
                collectionRef = collRef
            } else if let dbRef = parent as? Firestore {
                // ✅ NEW: single-segment root collection like "movies_shows"
                collectionRef = dbRef.collection(lastKey)
            } else {
                rows = []
                return
            }

            // Build the SAME base query for count, cursor walk, and fetch
            var base: Query = collectionRef

            // Apply server-side filters (groups: OR within group, AND across groups)
            let chipFilters = makeSelectStringFilters(selectedStringFilters)
            let combinedFilters = step.firebaseFilters + runtimeFilters + chipFilters
            base = applyFirebaseFilters(base, filters: combinedFilters)
            
            if !runtimeFilters.isEmpty {
                print("🧪 [FS] Runtime filters:\n\t\(debugDescribeFilters(runtimeFilters))")
            } else {
                print("🧪 [FS] Runtime filters: (none)")
            }
            if !step.firebaseFilters.isEmpty {
                print("🧪 [FS] Step filters:\n\t\(debugDescribeFilters(step.firebaseFilters))")
            } else {
                print("🧪 [FS] Step filters: (none)")
            }
            print("🧪 [FS] Using combined filters:\n\t\(debugDescribeFilters(combinedFilters))")

            // Apply chosen sorts
            base = applyChosenSorts(to: base)

            // If searching, collect deterministically across pages and bypass naive clientFilter
            let trimmedQ = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedQ.isEmpty {
                let (slice, total) = try await collectFilteredPage(base: base)
                // Update identity & count so paging bar is correct while searching
                let identity = makeIdentityString()
                if identity != queryIdentity {
                    queryIdentity = identity
                    cursors.removeAll()
                }
                totalCount = total
                rows = slice
                return
            }
            
            // Identity MUST reflect filters + sorts
            let identity = makeIdentityString()

            // if identity changed → reset cursors + page + recount
            if identity != queryIdentity {
                queryIdentity = identity
                cursors.removeAll()
                // only force-reset when non-paging inputs changed the query
                if currentPage != 1 {
                    currentPage = 1
                }
                totalCount = try await fetchCount(base)
            }

            // ensure current page within bounds
            if currentPage > lastPage { currentPage = lastPage }

            // if we need to jump to a page we don't have a cursor for, walk forward
            if currentPage > 1, cursors[currentPage - 1] == nil {
                // find the nearest known lower page to start from
                let knownLower = (cursors.keys + [1]).filter { $0 < currentPage }.max() ?? 1
                var cur = knownLower
                var lastSnap: DocumentSnapshot? = (knownLower == 1 ? nil : cursors[knownLower])
                while cur < currentPage {
                    var q = base
                    if let s = lastSnap { q = q.start(afterDocument: s) }
                    let snap = try await q.limit(to: step.hitsPerPage).getDocuments()
                    guard let tail = snap.documents.last else { break }
                    // we just fetched page `cur` → store its last doc
                    cursors[cur] = tail
                    lastSnap = tail
                    cur += 1
                }
            }
            
            // Page fetch (FILTERED + SORTED)
            let pageQ = pageQuery(base, page: currentPage)
            let snap = try await pageQ.getDocuments()

            // Maintain cursor for next page
            if let tail = snap.documents.last {
                cursors[currentPage] = tail
            }

            // map rows
            var newPayloads: [[String: Any]] = []
            let mapped: [StepRow] = snap.documents.map { d in
                let data = d.data()
                newPayloads.append(data)
                let name = resolve(step.itemName, data) ?? (data["name"] as? String) ?? d.documentID
                let desc = resolve(step.itemDescription, data)
                let img  = resolveImage(step.itemImage, data)
                return StepRow(id: d.documentID, name: name, desc: desc, imageURL: img)
            }
            self.rowPayloads = newPayloads

            // apply client-side search against rendered name/desc; keep page size
            let filtered = clientFilter(mapped)
            rows = filtered

        } catch {
            let ns = error as NSError
            print("[FS] load error: \(ns.domain) \(ns.code) \(ns.localizedDescription)")
            rows = []
        }
    }
    
    private func captureVariables(from data: [String: Any], docID: String) -> [String:String] {
        guard !step.variables.isEmpty else { return [:] }
        var out: [String:String] = [:]
        for (varName, fieldKey) in step.variables {
            let v: String
            if fieldKey == "objectID" || fieldKey == "id" || fieldKey == "__name__" {
                v = docID
            } else if let s = asString(nestedValue(data, keyPath: fieldKey)) {
                v = s
            } else {
                v = ""
            }
            out[varName] = v
        }
        return out
    }
    
    private func walkToParent(db: Firestore, parts: [String]) -> (parent: Any, lastKey: String) {
        precondition(!parts.isEmpty)
        var ref: Any = db
        var i = 0

        // walk all but the last segment
        while i < parts.count - 1 {
            let seg = parts[i]

            if let f = ref as? Firestore {
                print("[FS] step \(i): Firestore → collection('\(seg)')")
                ref = f.collection(seg)
            } else if let c = ref as? CollectionReference {
                print("[FS] step \(i): Collection('\(c.path)') → document('\(seg)')")
                ref = c.document(seg)                   // ← use current segment, not i+1
            } else if let d = ref as? DocumentReference {
                print("[FS] step \(i): Document('\(d.path)') → collection('\(seg)')")
                ref = d.collection(seg)
            } else {
                fatalError("unexpected ref type while walking")
            }
            i += 1
        }

        let last = parts.last!
        print("[FS] parent resolved. lastKey='\(last)'")
        return (ref, last)
    }
    
    private func clientFilter(_ input: [StepRow]) -> [StepRow] {
        let pageSize = max(1, step.hitsPerPage)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return Array(input.prefix(pageSize))
        }
        let filtered = input.filter { r in
            if r.name.lowercased().contains(q) { return true }
            if let d = r.desc?.lowercased(), d.contains(q) { return true }
            return false
        }
        return Array(filtered.prefix(pageSize))
    }
    
    
    /// Collects enough pages server-side to apply client-side filtering deterministically for the current page.
    /// Returns (rowsForCurrentPage, totalFilteredCount).
    private func collectFilteredPage(base: Query) async throws -> ([StepRow], Int) {
        let pageSize = max(1, step.hitsPerPage)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            // no search → just take current page from server
            let pageQ = pageQuery(base, page: currentPage)
            let snap = try await pageQ.getDocuments()
            let mapped: [StepRow] = snap.documents.map { d in
                let data = d.data()
                let name = resolve(step.itemName, data) ?? (data["name"] as? String) ?? d.documentID
                let desc = resolve(step.itemDescription, data)
                let img  = resolveImage(step.itemImage, data)
                return StepRow(id: d.documentID, name: name, desc: desc, imageURL: img)
            }
            return (mapped, try await fetchCount(base))
        }

        // When searching, we must scan forward pages and filter client-side
        var gathered: [StepRow] = []
        var filtered: [StepRow] = []
        var totalFiltered = 0

        // Determine where to start: if we have the last doc of page-1, begin after it
        var lastSnap: DocumentSnapshot? = (currentPage > 1 ? cursors[currentPage - 1] : nil)
        var keepGoing = true

        while keepGoing {
            var qy = base
            if let s = lastSnap { qy = qy.start(afterDocument: s) }
            let snap = try await qy.limit(to: step.hitsPerPage).getDocuments()
            if snap.documents.isEmpty { break }

            // Map rows for this server page
            let mapped: [StepRow] = snap.documents.map { d in
                let data = d.data()
                let name = resolve(step.itemName, data) ?? (data["name"] as? String) ?? d.documentID
                let desc = resolve(step.itemDescription, data)
                let img  = resolveImage(step.itemImage, data)
                return StepRow(id: d.documentID, name: name, desc: desc, imageURL: img)
            }
            gathered.append(contentsOf: mapped)

            // Filter newly gathered rows and append
            let newlyFiltered = mapped.filter { r in
                if r.name.lowercased().contains(q) { return true }
                if let d = r.desc?.lowercased(), d.contains(q) { return true }
                return false
            }
            totalFiltered += newlyFiltered.count
            filtered.append(contentsOf: newlyFiltered)

            // Update cursor state for the page we just processed
            if let tail = snap.documents.last {
                if lastSnap == nil && currentPage == 1 { cursors[1] = tail }
                lastSnap = tail
            }

            // Stop when we have enough to materialize the current UI page
            let need = currentPage * pageSize
            keepGoing = filtered.count < need

            // Also break if we've hit the end
            if snap.documents.count < step.hitsPerPage { break }
        }

        // Slice the filtered list to the current page window
        let start = max(0, (currentPage - 1) * pageSize)
        let end   = min(filtered.count, start + pageSize)
        let pageSlice = (start < end) ? Array(filtered[start..<end]) : []

        return (pageSlice, totalFiltered)
    }

    private func resolve(_ template: String, _ dict: [String: Any]) -> String? {
        guard !template.isEmpty else { return nil }
        // 1) replace backticks ONLY when provided in `vars`
        let withVars = interpolateVars(template, with: vars)
        // 2) now resolve remaining `...` and (...) from the Firestore document payload
        let rendered = renderTemplate(withVars, with: dict)  // supports both `field` and (field)
        let trimmed  = rendered.replacingOccurrences(of: "  ", with: " ")
                               .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolveImage(_ template: String, _ dict: [String: Any]) -> String? {
        guard !template.isEmpty else { return dict["image"] as? String }
        return resolve(template, dict)
    }

    // Build Firestore query from a path like "music/(artist_id)/albums"
    
    private func buildQuery() throws -> Query {
        let db = FirestoreProvider.dbItems
        let pathWithVars = interpolateVars(step.firebaseIdPath, with: vars) { key in
            if key == "filter_id" { return incomingIDs.first }
            if key == "filter_field" { return vars["filter_field"] }
            return nil
        }
        let substituted = substituteIncomingIDs(pathWithVars, vars: vars)
        guard !substituted.isEmpty else { throw NSError(domain: "FirestoreStepView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty Firestore path"]) }

        let parts = substituted.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { throw NSError(domain: "FirestoreStepView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid path"]) }

        print("[FS][buildQuery] basePath='\(substituted)' parts=\(parts)")

        var ref: Any = db
        var i = 0
        while i < parts.count {
            let p = parts[i]
            if ref is Firestore {
                ref = (ref as! Firestore).collection(p)
            } else if ref is CollectionReference {
                if i + 1 < parts.count {
                    ref = (ref as! CollectionReference).document(parts[i + 1])
                    i += 1
                }
            } else if ref is DocumentReference {
                ref = (ref as! DocumentReference).collection(p)
            }
            i += 1
        }

        guard let collectionRef = (ref as? CollectionReference) else {
            // fallback kept just in case
            if let d = ref as? DocumentReference {
                var q: Query = d.collection("_items")
                // apply chosen sort if available
                if !step.sortFields.isEmpty {
                    let idx = min(max(0, sortIndex), step.sortFields.count - 1)
                    let chosen = step.sortFields[idx]
                    let fieldName = interpolateVars(chosen.field, with: vars)
                    print("[FS][buildQuery] final sort₁=\(fieldName) dir=\(sortDescendingOverride ? "desc":"asc")")
                }
                return q.limit(to: max(1, step.hitsPerPage))
            }
            throw NSError(domain: "FirestoreStepView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Path did not end on a collection"])
        }

        var query: Query = collectionRef
        query = applyFirebaseFilters(query, filters: step.firebaseFilters)
        query = applyChosenSorts(to: query)
        query = query.limit(to: max(1, step.hitsPerPage))
        if !step.sortFields.isEmpty {
            let idx = min(max(0, sortIndex), step.sortFields.count - 1)
            let chosen = step.sortFields[idx]
            let fieldName = interpolateVars(chosen.field, with: vars)
            query = query.order(by: fieldName, descending: sortDescendingOverride)
        }
        return query.limit(to: max(1, step.hitsPerPage))
    }
    
    private func rowsFromMapField(
        docRef: DocumentReference,
        fieldKey: String,
        nameTpl: String,
        descTpl: String,
        imgTpl: String
    ) async throws -> [StepRow] {
        let snap = try await docRef.getDocument()
        guard snap.exists, let dict = snap.data(),
              let map = dict[fieldKey] as? [String: Any] else {
            return []
        }

        var out: [StepRow] = []
        out.reserveCapacity(map.count)

        // each entry becomes a pseudo-document
        for (key, val) in map {
            let v = (val as? [String: Any]) ?? [:]
            let name = resolve(nameTpl, v) ?? (v["name"] as? String) ?? key
            let desc = resolve(descTpl, v)
            let img  = resolveImage(imgTpl, v)
            out.append(StepRow(id: key, name: name, desc: desc, imageURL: img))
        }
        return out
    }

    
    private func substituteIncomingTokens(_ template: String) -> String {
        var out = template
        let regex = try! NSRegularExpression(pattern: #"\(([^)]+)\)"#)
        let ns = out as NSString
        let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()

        for m in matches {
            let key = ns.substring(with: m.range(at: 1))
            let fromVars = vars[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fromIDs  = incomingIDs.first?.trimmingCharacters(in: .whitespacesAndNewlines)

            let replacement: String
            if let v = fromVars, !v.isEmpty {
                replacement = v
                print("[FS] token '\(key)' → using vars value '\(v)'")
            } else if let id = fromIDs, !id.isEmpty {
                replacement = id
                print("[FS] token '\(key)' → using incomingIDs '\(id)'")
            } else {
                // keep original so we notice the problem instead of injecting "-"
                replacement = "(\(key))"
                print("[FS] token '\(key)' → no value found; leaving as-is")
            }

            out = (out as NSString).replacingCharacters(in: m.range, with: replacement)
        }
        return out
    }

    
    private func substituteIncomingIDs(_ template: String, vars: [String:String]) -> String {
        var out = template
        let regex = try! NSRegularExpression(pattern: #"\(([A-Za-z0-9_]+)\)"#)
        let ns = out as NSString
        for m in regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
            let key  = ns.substring(with: m.range(at: 1))
            let repl = vars[key] ?? incomingIDs.first ?? "-"
            print("[FS] token '\(key)' → using \(vars[key] != nil ? "vars value" : "incomingIDs") '\(repl)'")
            out = (out as NSString).replacingCharacters(in: m.range, with: repl)
        }
        return out
    }

    private func substitute(_ template: String) -> String {
        // Replace * and any (token) with first incomingID for now.
        var out = template
        if out.contains("*") { out = out.replacingOccurrences(of: "*", with: incomingIDs.first ?? "-") }
        let regex = try! NSRegularExpression(pattern: #"\(([^)]+)\)"#)
        let ns = out as NSString
        for m in regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
            out = (out as NSString).replacingCharacters(in: m.range, with: incomingIDs.first ?? "-")
        }
        return out
    }
}

struct ChipSelection: Hashable {
    let field: String   // e.g. "rarity"
    let value: String   // e.g. "common"
}

// MARK: - Utilities
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var idx = 0
        while idx < count {
            let end = Swift.min(idx + size, count)
            result.append(Array(self[idx..<end]))
            idx = end
        }
        return result
    }
}

private extension Set where Element == String {
    mutating func toggle(_ value: String) { if contains(value) { remove(value) } else { insert(value) } }
}


struct AddItemsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRankoItems: [RankoItem]

    // A fresh basket for the picker
    @StateObject private var basket = SelectionBasket()

    var body: some View {
        NavigationStack {
            CategoriesView(basket: basket) { picked in
                append(picked)
                dismiss()
            }
            .environmentObject(basket)
        }
    }

    private func append(_ picked: [StepRow]) {
        // Append *after* the last existing rank, preserving order
        var nextRank = (selectedRankoItems.map { $0.rank }.max() ?? 0) + 1

        for r in picked {
            let rec = RankoRecord(
                objectID: r.id,
                ItemName: r.name,
                ItemDescription: r.desc ?? "",
                ItemCategory: "",
                ItemImage: r.imageURL ?? placeholderItemURL,
                ItemGIF: nil,
                ItemVideo: nil,
                ItemAudio: nil
            )
            let newItem = RankoItem(
                id: UUID().uuidString,
                rank: nextRank,
                votes: 0,
                record: rec,
                playCount: 0
            )
            selectedRankoItems.append(newItem)
            nextRank += 1
        }
    }
}

private let placeholderItemURL =
  "https://firebasestorage.googleapis.com/v0/b/ranko-kyan.firebasestorage.app/o/placeholderImages%2FitemPlaceholder.png?alt=media&token="
