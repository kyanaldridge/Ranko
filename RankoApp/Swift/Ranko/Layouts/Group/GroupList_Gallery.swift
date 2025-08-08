//
//  GroupList_Gallery.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI

// MARK: - UserGroupListView
struct GroupListGallery: View {
    let listPath: String
    var onSelect: (RankoList) -> Void
    
    @StateObject private var user_data = UserInformation.shared
    @State private var lists: [RankoList] = []
    @State private var selectedList: RankoList?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(lists) { list in
                    Button {
                        selectedList = list
                    } label: {
                        GroupListIndividualGallery(listData: list, type: "", onUnpin: {})
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            loadLists()
        }
        .sheet(item: $selectedList) { list in
            GroupListPersonal(listID: list.id)
        }
    }
    
    private func loadLists() {
//        let ref = Database.database().reference().child(listPath)
//        ref.observeSingleEvent(of: .value) { snapshot in
//            guard let dict = snapshot.value as? [String: Any] else {
//                print("DEBUG: loadLists snapshot not a dict")
//                return
//            }
//            for (listID, _) in dict {
//                print("DEBUG: loadLists found listID: \(listID)")
//                fetchListData(id: listID)
//            }
//        }
    }
    
    private func fetchListData(id: String) {
//        print("DEBUG: fetchListData id: \(id)")
//        let listRef = Database.database().reference()
//            .child("RankoListData")
//            .child(id)
//        listRef.observeSingleEvent(of: .value) { snap in
//            guard
//                let dict = snap.value as? [String: Any],
//                let rankoList = parseListData(dict: dict, id: id)
//            else {
//                print("DEBUG: fetchListData parse failed for id: \(id)")
//                return
//            }
//
//            DispatchQueue.main.async {
//                lists.append(rankoList)
//                print("DEBUG: lists appended id:\(rankoList.id) items:\(rankoList.items.count)")
//                lists.sort { $0.dateTime > $1.dateTime }
//                print("DEBUG: lists sorted by dateTime: \(lists.map { $0.dateTime })")
//            }
//        }
    }
    
    private func parseListData(dict: [String: Any], id: String) -> RankoList? {
        guard
            let listName    = dict["RankoName"]        as? String,
            let description = dict["RankoDescription"] as? String,
            let category    = dict["RankoCategory"]    as? String,
            let type        = dict["RankoType"]        as? String,
            let privacy     = dict["RankoPrivacy"]     as? Bool,
            let dateTime    = dict["RankoDateTime"]    as? String,
            let userCreator = dict["RankoUserID"]      as? String,
            let itemsDict   = dict["RankoItems"]       as? [String: Any]
        else {
            print("DEBUG: parseListData guard failed for list \(id)")
            return nil
        }
        
        let items: [RankoItem] = itemsDict.compactMap { _, value in
            guard
                let d     = value as? [String: Any],
                let iID   = d["ItemID"]     as? String,
                let name  = d["ItemName"]   as? String,
                let img   = d["ItemImage"]  as? String,
                let votes = d["ItemVotes"]  as? Int
            else {
                print("DEBUG: parseListData item guard failed for value: \(value)")
                return nil
            }
            let rawRank = d["ItemRank"]
            let rank: Int
            if let intRank = rawRank as? Int {
                rank = intRank
            } else if let strRank = rawRank as? String, let parsed = Int(strRank) {
                rank = parsed
            } else {
                print("DEBUG: parseListData couldn't parse rank for itemID: \(iID), raw: \(String(describing: rawRank))")
                return nil
            }
            print("DEBUG: parseListData itemID:\(iID) rank:\(rank) imgURL:\(img)")
            
            let record = RankoRecord(objectID: iID,
                                     ItemName: name,
                                     ItemDescription: "",
                                     ItemCategory: "",
                                     ItemImage: img)
            return RankoItem(id: iID, rank: rank, votes: votes, record: record)
        }
        print("DEBUG: parseListData returning \(items.count) items for list \(id)")
        
        let sorted = items.sorted { $0.rank < $1.rank }
        return RankoList(
            id:               id,
            listName:         listName,
            listDescription:  description,
            type:             type,
            category:         category,
            isPrivate:        privacy ? "Private" : "Public",
            userCreator:      userCreator,
            dateTime:         dateTime,
            items:            sorted
        )
    }
}






// MARK: - UserGroupLists
struct GroupListIndividualGallery: View {
    let listData: RankoList
    let type: String
    let onUnpin: (() -> Void)?
    
    private var sortedItems: [RankoItem] {
        listData.items.sorted { $0.rank < $1.rank }
    }

    var body: some View {
        HStack(spacing: 12) {
            overlappingImages
            VStack(alignment: .leading, spacing: 4) {
                Text(listData.listName)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Color(hex: 0x7E5F46))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    FeaturedCategoryBadge(text: listData.category)
                    Text("• \(timeAgo(from: String(listData.dateTime)))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: 0x7E5F46))
                }
            }
            Spacer()
            if type == "featured" {
                Button {
                    onUnpin?()
                } label: {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Color(hex: 0x7E5F46))
                        .padding(.trailing, 6)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        // white background
        .background(.clear)
        .padding(.vertical, 4)
    }

    private var overlappingImages: some View {
        HStack(spacing: -12) {
            ForEach(sortedItems.prefix(3)) { item in
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    if let img = phase.image {
                        img
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(LinearGradient(colors: [Color(hex: 0xFFFAEF), Color(hex: 0xFEF6EA)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
                .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xFFFAEF), Color(hex: 0xFEF6EA)], startPoint: .top, endPoint: .bottom)))
            }
        }
    }

    // replicate your existing timeAgo helper
    private func timeAgo(from dt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"

        guard let date = formatter.date(from: dt) else {
            print("Failed to parse date from string: \(dt)")
            return ""
        }

        let now = Date()
        let secondsAgo = Int(now.timeIntervalSince(date))

        switch secondsAgo {
        case 0..<60:
            return "\(secondsAgo)s ago"
        case 60..<3600:
            return "\(secondsAgo / 60)m ago"
        case 3600..<86400:
            return "\(secondsAgo / 3600)h ago"
        case 86400..<604800:
            return "\(secondsAgo / 86400)d ago"
        case 604800..<31536000:
            return "\(secondsAgo / 604800)w ago"
        default:
            return "\(secondsAgo / 31536000)y ago"
        }
    }
    
    @ViewBuilder
    private var overlappingImages2: some View {
        let firstThree = listData.items
            .sorted { $0.rank < $1.rank }
            .prefix(3)

        HStack(spacing: -12) {
            ForEach(Array(firstThree), id: \.id) { item in
                if let url = URL(string: item.itemImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        // placeholder is a mid-tone circle so you can see it on white
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .background(
                        Circle().fill(Color.white)
                    )
                } else {
                    // fall back if somehow the URL string was invalid
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .onAppear {
            print("DEBUG: overlappingImages for '\(listData.listName)' → ranks: \(firstThree.map { $0.rank })")
        }
    }

}



#Preview {
    GroupSelectedItemRow(item: RankoItem(id: "AU73T2-73GW6A-9873HG-JW4Q32", rank: 1, votes: 43, record: RankoRecord(objectID: "1234567890", ItemName: "Test Item", ItemDescription: "This is a test item", ItemCategory: "", ItemImage: "https://i.ytimg.com/vi/JrEVa5_k-_8/maxresdefault.jpg")))
}

