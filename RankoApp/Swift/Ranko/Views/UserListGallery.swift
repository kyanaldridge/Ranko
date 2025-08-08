//
//  UserListGallery.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 2/7/2025.
//

import SwiftUI
import Firebase
import AlgoliaSearchClient

// MARK: - UserDefaultListView
//struct UserListGallery: View {
//    var onSelect: (RankoList) -> Void
//    @State private var isLoading = true
//    @State private var errorMessage: String?
//
//    @StateObject private var user_data = UserInformation.shared
//    @State private var lists: [RankoList] = []
//    @State private var selectedList: RankoList?
//
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 0) {
//                ForEach(lists) { list in
//                    Button { selectedList = list }
//                    label: { DefaultListIndividualGallery(listData: list) }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//        }
//        .onAppear {
//            loadAllData()
//        }
//        // when the user taps one, call the callback and dismiss
//        .sheet(item: $selectedList) { list in
//            if list.type == "default" {
//                DefaultListPersonal(listID: list.id){ updatedItem in }
//            } else if list.type == "group" {
//                GroupListPersonal(listID: list.id)
//            }
//        }
//    }
//    
//    private func loadAllData(attempt: Int = 1) {
//        isLoading = true
//        errorMessage = nil
//        
//        AlgoliaProfileView_Rankos.shared.fetchRankoLists(limit: 20) { result in
//            switch result {
//            case .success:
//                // Firebase call
//                let itemDataRef = Database.database().reference().child("ItemData")
//                itemDataRef.getData { error, snapshot in
//                    if error != nil {
//                        if attempt < 3 {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                loadAllData(attempt: attempt + 1)
//                            }
//                        } else {
//                            DispatchQueue.main.async {
//                                self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                                self.isLoading = false
//                            }
//                        }
//                        return
//                    }
//                    
//                    var itemDict: [String: [String: Any]] = [:]
//                    
//                    for child in snapshot?.children.allObjects as? [DataSnapshot] ?? [] {
//                        if let value = child.value as? [String: Any] {
//                            itemDict[child.key] = value
//                        }
//                    }
//                    
//                    if itemDict.isEmpty {
//                        DispatchQueue.main.async {
//                            self.errorMessage = "⚠️ No items found in Firebase."
//                            self.isLoading = false
//                        }
//                        return
//                    }
//                    
//                    // 🧠 Now fetch full list data again via Algolia JSON
//                    let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
//                                              apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
//                    let index = client.index(withName: "RankoLists")
//                    var query = Query("").set(\.hitsPerPage, to: 20)
//                    query.filters = "RankoUserID:\(user_data.userID)"
//                    
//                    index.search(query: query) { (result: Result<SearchResponse, Error>) in
//                        DispatchQueue.main.async {
//                            switch result {
//                            case .success(let response):
//                                let lists: [RankoList] = response.hits.compactMap { hit in
//                                    do {
//                                        let data = try JSONEncoder().encode(hit.object)
//                                        let record = try JSONDecoder().decode(RankoListAlgolia.self, from: data)
//                                        
//                                        let id = record.objectID
//                                        let items: [RankoItem] = (record.RankoItems ?? [:]).compactMap { (itemID, values) in
//                                            guard let firebaseItem = itemDict[itemID],
//                                                  let itemName = firebaseItem["ItemName"] as? String,
//                                                  let itemImage = firebaseItem["ItemImage"] as? String,
//                                                  let itemDescription = firebaseItem["ItemDescription"] as? String else {
//                                                return nil
//                                            }
//                                            
//                                            let rank = values["Rank"] ?? 0
//                                            let votes = values["Votes"] ?? 0
//                                            
//                                            let record = RankoRecord(
//                                                objectID: itemID,
//                                                ItemName: itemName,
//                                                ItemDescription: itemDescription,
//                                                ItemCategory: "",
//                                                ItemImage: itemImage
//                                            )
//                                            
//                                            return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
//                                        }
//                                        
//                                        return RankoList(
//                                            id: id,
//                                            listName: record.RankoName,
//                                            listDescription: record.RankoDescription,
//                                            type: record.RankoType,
//                                            category: record.RankoCategory,
//                                            isPrivate: record.RankoPrivacy ? "Private" : "Public",
//                                            userCreator: record.RankoUserID,
//                                            dateTime: record.RankoDateTime,
//                                            items: items
//                                        )
//                                        
//                                    } catch {
//                                        print("❌ decode error:", error)
//                                        return nil
//                                    }
//                                }
//                                
//                                self.lists = lists
//                                self.isLoading = false
//                                
//                            case .failure(let error):
//                                self.errorMessage = "❌ Algolia list error: \(error.localizedDescription)"
//                                self.isLoading = false
//                            }
//                        }
//                    }
//                }
//            case .failure(_):
//                if attempt < 3 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        loadAllData(attempt: attempt + 1)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                        self.isLoading = false
//                    }
//                }
//            }
//        }
//    }
//
//    // copy your existing parser from MyListsView
//    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
//        guard
//            let listName    = dict["RankoName"]        as? String,
//            let description = dict["RankoDescription"] as? String,
//            let category    = dict["RankoCategory"]    as? String,
//            let type        = dict["RankoType"]        as? String,
//            let privacy     = dict["RankoPrivacy"]     as? Bool,
//            let dateTime    = dict["RankoDateTime"]    as? String,
//            let userCreator = dict["RankoUserID"]      as? String,
//            let itemsDict   = dict["RankoItems"]       as? [String: Any]
//        else { return nil }
//
//        let items: [RankoItem] = itemsDict.compactMap { _, value in
//            guard
//                let d = value as? [String: Any],
//                let id = d["ItemID"]     as? String,
//                let name = d["ItemName"] as? String,
//                let img  = d["ItemImage"] as? String,
//                let votes = d["ItemVotes"] as? Int,
//                let rank = d["ItemRank"]  as? Int
//            else { return nil }
//            let record = RankoRecord(objectID: id,
//                                     ItemName: name,
//                                     ItemDescription: "",
//                                     ItemCategory: "",
//                                     ItemImage: img)
//            return RankoItem(id: id, rank: rank, votes: votes, record: record)
//        }
//        return RankoList(
//            id:               id,
//            listName:         listName,
//            listDescription:  description,
//            type:             type,
//            category:         category,
//            isPrivate:        privacy ? "Private" : "Public",
//            userCreator:      userCreator,
//            dateTime:         dateTime,
//            items:            items.sorted { $0.rank < $1.rank }
//        )
//    }
//}

//struct UserListGallery_PublicOnly: View {
//    var onSelect: (RankoList) -> Void
//    @State private var isLoading = true
//    @State private var errorMessage: String?
//
//    @StateObject private var user_data = UserInformation.shared
//    @State private var lists: [RankoList] = []
//    @State private var selectedList: RankoList?
//
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 0) {
//                ForEach(lists) { list in
//                    DefaultListIndividualGallery(listData: list)
//                        .onTapGesture {
//                            onSelect(list)
//                        }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//        }
//        .onAppear {
//            loadAllData()
//        }
//    }
//    
//    private func loadAllData(attempt: Int = 1) {
//        isLoading = true
//        errorMessage = nil
//        
//        AlgoliaProfileView_Featured.shared.fetchRankoLists(limit: 20) { result in
//            switch result {
//            case .success:
//                // Firebase call
//                let itemDataRef = Database.database().reference().child("ItemData")
//                itemDataRef.getData { error, snapshot in
//                    if error != nil {
//                        if attempt < 3 {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                loadAllData(attempt: attempt + 1)
//                            }
//                        } else {
//                            DispatchQueue.main.async {
//                                self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                                self.isLoading = false
//                            }
//                        }
//                        return
//                    }
//                    
//                    var itemDict: [String: [String: Any]] = [:]
//                    
//                    for child in snapshot?.children.allObjects as? [DataSnapshot] ?? [] {
//                        if let value = child.value as? [String: Any] {
//                            itemDict[child.key] = value
//                        }
//                    }
//                    
//                    if itemDict.isEmpty {
//                        DispatchQueue.main.async {
//                            self.errorMessage = "⚠️ No items found in Firebase."
//                            self.isLoading = false
//                        }
//                        return
//                    }
//                    
//                    // 🧠 Now fetch full list data again via Algolia JSON
//                    let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
//                                              apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
//                    let index = client.index(withName: "RankoLists")
//                    var query = Query("").set(\.hitsPerPage, to: 20)
//                    query.filters = "RankoUserID:\(user_data.userID) AND RankoPrivacy:false"
//                    
//                    index.search(query: query) { (result: Result<SearchResponse, Error>) in
//                        DispatchQueue.main.async {
//                            switch result {
//                            case .success(let response):
//                                let lists: [RankoList] = response.hits.compactMap { hit in
//                                    do {
//                                        let data = try JSONEncoder().encode(hit.object)
//                                        let record = try JSONDecoder().decode(RankoListAlgolia.self, from: data)
//                                        
//                                        let id = record.objectID
//                                        let items: [RankoItem] = (record.RankoItems ?? [:]).compactMap { (itemID, values) in
//                                            guard let firebaseItem = itemDict[itemID],
//                                                  let itemName = firebaseItem["ItemName"] as? String,
//                                                  let itemImage = firebaseItem["ItemImage"] as? String,
//                                                  let itemDescription = firebaseItem["ItemDescription"] as? String else {
//                                                return nil
//                                            }
//                                            
//                                            let rank = values["Rank"] ?? 0
//                                            let votes = values["Votes"] ?? 0
//                                            
//                                            let record = RankoRecord(
//                                                objectID: itemID,
//                                                ItemName: itemName,
//                                                ItemDescription: itemDescription,
//                                                ItemCategory: "",
//                                                ItemImage: itemImage
//                                            )
//                                            
//                                            return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
//                                        }
//                                        
//                                        return RankoList(
//                                            id: id,
//                                            listName: record.RankoName,
//                                            listDescription: record.RankoDescription,
//                                            type: record.RankoType,
//                                            category: record.RankoCategory,
//                                            isPrivate: record.RankoPrivacy ? "Private" : "Public",
//                                            userCreator: record.RankoUserID,
//                                            dateTime: record.RankoDateTime,
//                                            items: items
//                                        )
//                                        
//                                    } catch {
//                                        print("❌ decode error:", error)
//                                        return nil
//                                    }
//                                }
//                                
//                                self.lists = lists
//                                self.isLoading = false
//                                
//                            case .failure(let error):
//                                self.errorMessage = "❌ Algolia list error: \(error.localizedDescription)"
//                                self.isLoading = false
//                            }
//                        }
//                    }
//                }
//            case .failure(_):
//                if attempt < 3 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        loadAllData(attempt: attempt + 1)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                        self.isLoading = false
//                    }
//                }
//            }
//        }
//    }
//
//    // copy your existing parser from MyListsView
//    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
//        guard
//            let listName    = dict["RankoName"]        as? String,
//            let description = dict["RankoDescription"] as? String,
//            let category    = dict["RankoCategory"]    as? String,
//            let type        = dict["RankoType"]        as? String,
//            let privacy     = dict["RankoPrivacy"]     as? Bool,
//            let dateTime    = dict["RankoDateTime"]    as? String,
//            let userCreator = dict["RankoUserID"]      as? String,
//            let itemsDict   = dict["RankoItems"]       as? [String: Any]
//        else { return nil }
//
//        let items: [RankoItem] = itemsDict.compactMap { _, value in
//            guard
//                let d = value as? [String: Any],
//                let id = d["ItemID"]     as? String,
//                let name = d["ItemName"] as? String,
//                let img  = d["ItemImage"] as? String,
//                let votes = d["ItemVotes"] as? Int,
//                let rank = d["ItemRank"]  as? Int
//            else { return nil }
//            let record = RankoRecord(objectID: id,
//                                     ItemName: name,
//                                     ItemDescription: "",
//                                     ItemCategory: "",
//                                     ItemImage: img)
//            return RankoItem(id: id, rank: rank, votes: votes, record: record)
//        }
//        return RankoList(
//            id:               id,
//            listName:         listName,
//            listDescription:  description,
//            type:             type,
//            category:         category,
//            isPrivate:        privacy ? "Private" : "Public",
//            userCreator:      userCreator,
//            dateTime:         dateTime,
//            items:            items.sorted { $0.rank < $1.rank }
//        )
//    }
//}

//struct UserListGallery_Spectate: View {
//    var onSelect: (RankoList) -> Void
//    @State private var isLoading = true
//    @State private var errorMessage: String?
//    
//    @State var userID: String
//
//    @StateObject private var user_data = UserInformation.shared
//    @State private var lists: [RankoList] = []
//    @State private var selectedList: RankoList?
//
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 0) {
//                ForEach(lists) { list in
//                    Button { selectedList = list }
//                    label: { DefaultListIndividualGallery(listData: list) }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//        }
//        .onAppear {
//            loadAllData()
//        }
//        // when the user taps one, call the callback and dismiss
//        .sheet(item: $selectedList) { list in
//            if list.type == "default" {
//                DefaultListPersonal(listID: list.id){ updatedItem in }
//            } else if list.type == "group" {
//                GroupListPersonal(listID: list.id)
//            }
//        }
//    }
//    
//    private func loadAllData(attempt: Int = 1) {
//        isLoading = true
//        errorMessage = nil
//        
//        AlgoliaProfileView_Rankos.shared.fetchRankoLists(limit: 20) { result in
//            switch result {
//            case .success:
//                // Firebase call
//                let itemDataRef = Database.database().reference().child("ItemData")
//                itemDataRef.getData { error, snapshot in
//                    if error != nil {
//                        if attempt < 3 {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                loadAllData(attempt: attempt + 1)
//                            }
//                        } else {
//                            DispatchQueue.main.async {
//                                self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                                self.isLoading = false
//                            }
//                        }
//                        return
//                    }
//                    
//                    var itemDict: [String: [String: Any]] = [:]
//                    
//                    for child in snapshot?.children.allObjects as? [DataSnapshot] ?? [] {
//                        if let value = child.value as? [String: Any] {
//                            itemDict[child.key] = value
//                        }
//                    }
//                    
//                    if itemDict.isEmpty {
//                        DispatchQueue.main.async {
//                            self.errorMessage = "⚠️ No items found in Firebase."
//                            self.isLoading = false
//                        }
//                        return
//                    }
//                    
//                    // 🧠 Now fetch full list data again via Algolia JSON
//                    let client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
//                                              apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
//                    let index = client.index(withName: "RankoLists")
//                    var query = Query("").set(\.hitsPerPage, to: 20)
//                    query.filters = "RankoUserID:\(userID)"
//                    
//                    index.search(query: query) { (result: Result<SearchResponse, Error>) in
//                        DispatchQueue.main.async {
//                            switch result {
//                            case .success(let response):
//                                let lists: [RankoList] = response.hits.compactMap { hit in
//                                    do {
//                                        let data = try JSONEncoder().encode(hit.object)
//                                        let record = try JSONDecoder().decode(RankoListAlgolia.self, from: data)
//                                        
//                                        let id = record.objectID
//                                        let items: [RankoItem] = (record.RankoItems ?? [:]).compactMap { (itemID, values) in
//                                            guard let firebaseItem = itemDict[itemID],
//                                                  let itemName = firebaseItem["ItemName"] as? String,
//                                                  let itemImage = firebaseItem["ItemImage"] as? String,
//                                                  let itemDescription = firebaseItem["ItemDescription"] as? String else {
//                                                return nil
//                                            }
//                                            
//                                            let rank = values["Rank"] ?? 0
//                                            let votes = values["Votes"] ?? 0
//                                            
//                                            let record = RankoRecord(
//                                                objectID: itemID,
//                                                ItemName: itemName,
//                                                ItemDescription: itemDescription,
//                                                ItemCategory: "",
//                                                ItemImage: itemImage
//                                            )
//                                            
//                                            return RankoItem(id: itemID, rank: rank, votes: votes, record: record)
//                                        }
//                                        
//                                        return RankoList(
//                                            id: id,
//                                            listName: record.RankoName,
//                                            listDescription: record.RankoDescription,
//                                            type: record.RankoType,
//                                            category: record.RankoCategory,
//                                            isPrivate: record.RankoPrivacy ? "Private" : "Public",
//                                            userCreator: record.RankoUserID,
//                                            dateTime: record.RankoDateTime,
//                                            items: items
//                                        )
//                                        
//                                    } catch {
//                                        print("❌ decode error:", error)
//                                        return nil
//                                    }
//                                }
//                                
//                                self.lists = lists
//                                self.isLoading = false
//                                
//                            case .failure(let error):
//                                self.errorMessage = "❌ Algolia list error: \(error.localizedDescription)"
//                                self.isLoading = false
//                            }
//                        }
//                    }
//                }
//            case .failure(_):
//                if attempt < 3 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        loadAllData(attempt: attempt + 1)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        self.errorMessage = "❌ There was an error contacting the server, please refresh and try again"
//                        self.isLoading = false
//                    }
//                }
//            }
//        }
//    }
//
//    // copy your existing parser from MyListsView
//    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
//        guard
//            let listName    = dict["RankoName"]        as? String,
//            let description = dict["RankoDescription"] as? String,
//            let category    = dict["RankoCategory"]    as? String,
//            let type        = dict["RankoType"]        as? String,
//            let privacy     = dict["RankoPrivacy"]     as? Bool,
//            let dateTime    = dict["RankoDateTime"]    as? String,
//            let userCreator = dict["RankoUserID"]      as? String,
//            let itemsDict   = dict["RankoItems"]       as? [String: Any]
//        else { return nil }
//
//        let items: [RankoItem] = itemsDict.compactMap { _, value in
//            guard
//                let d = value as? [String: Any],
//                let id = d["ItemID"]     as? String,
//                let name = d["ItemName"] as? String,
//                let img  = d["ItemImage"] as? String,
//                let votes = d["ItemVotes"] as? Int,
//                let rank = d["ItemRank"]  as? Int
//            else { return nil }
//            let record = RankoRecord(objectID: id,
//                                     ItemName: name,
//                                     ItemDescription: "",
//                                     ItemCategory: "",
//                                     ItemImage: img)
//            return RankoItem(id: id, rank: rank, votes: votes, record: record)
//        }
//        return RankoList(
//            id:               id,
//            listName:         listName,
//            listDescription:  description,
//            type:             type,
//            category:         category,
//            isPrivate:        privacy ? "Private" : "Public",
//            userCreator:      userCreator,
//            dateTime:         dateTime,
//            items:            items.sorted { $0.rank < $1.rank }
//        )
//    }
//}
