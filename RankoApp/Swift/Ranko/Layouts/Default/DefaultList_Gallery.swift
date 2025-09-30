//
//  DefaultList_Gallery.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI
import Firebase
import AlgoliaSearchClient

// MARK: - UserDefaultLists
struct DefaultListIndividualGallery: View {
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
                    .font(.custom("Nunito-Black", size: 16))
                    .foregroundColor(Color(hex: 0x514343))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    FeaturedCategoryBadge(name: listData.categoryName, icon: listData.categoryIcon, colour: listData.categoryColour)
                    Text("• \(timeAgo(from: String(listData.dateTime)))")
                        .font(.custom("Nunito-Black", size: 9))
                        .foregroundColor(Color(hex: 0x514343))
                }
            }
            Spacer()
            if type == "featured" {
                Button {
                    onUnpin?()
                } label: {
                    Image(systemName: "pin.fill")
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundColor(Color(hex: 0x514343))
                        .padding(.trailing, 6)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        // white background
        .background(.clear)
        .padding(.vertical, 1)
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
                .overlay(Circle().stroke(Color(hex: 0xFFFFFF), lineWidth: 2))
                .background(Circle().fill(Color(hex: 0xFFFFFF)))
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

}

#Preview {
    VStack {
        Spacer()
        Button {} label: {
            DefaultListIndividualGallery(
                listData: RankoList(
                    id: "",
                    listName: "Top 10 Albums of the 1970s to 2010s",
                    listDescription: "my fav albums",
                    type: "default",
                    categoryName: "Albums",
                    categoryIcon: "circle.circle",
                    categoryColour: 0xFFFFFF,
                    isPrivate: "false",
                    userCreator: "",
                    dateTime: "20230718094500",
                    items: [
                        RankoItem(id: "", rank: 5, votes: 23, record:
                                    RankoRecord(
                                        objectID: "",
                                        ItemName: "Madvillainy",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/5/5e/Madvillainy_cover.png"
                                    )
                                 ),
                        RankoItem(id: "", rank: 4, votes: 19, record:
                                    RankoRecord(
                                        objectID: "",
                                        ItemName: "Wish You Were Here",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://www.emp.co.uk/dw/image/v2/BBQV_PRD/on/demandware.static/-/Sites-master-emp/default/dw74154f22/images/4/0/6/0/406025.jpg?sw=1000&sh=800&sm=fit&sfrm=png"
                                    )
                                 ),
                        RankoItem(id: "", rank: 3, votes: 26, record:
                                    RankoRecord(
                                        objectID: "",
                                        ItemName: "In Rainbows",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://m.media-amazon.com/images/I/A1MwaIeBpwL._UF894,1000_QL80_.jpg"
                                    )
                                 ),
                        RankoItem(id: "", rank: 2, votes: 26, record:
                                    RankoRecord(
                                        objectID: "",
                                        ItemName: "OK Computer",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/thumb/b/ba/Radioheadokcomputer.png/250px-Radioheadokcomputer.png"
                                    )
                                 ),
                        RankoItem(id: "", rank: 1, votes: 26, record:
                                    RankoRecord(
                                        objectID: "",
                                        ItemName: "To Pimp a Butterfly",
                                        ItemDescription: "",
                                        ItemCategory: "",
                                        ItemImage: "https://upload.wikimedia.org/wikipedia/en/f/f6/Kendrick_Lamar_-_To_Pimp_a_Butterfly.png"
                                    )
                                 )
                    ]
                ), type: "", onUnpin: {}
            )
        }
        .foregroundColor(Color(hex: 0xFF9864))
        .tint(Color(hex: 0xFFFFFF))
        .buttonStyle(.glassProminent)
        Spacer()
    }
    .environmentObject(ProfileImageService())
    .background(Color(hex: 0xFFFFFF))
    .ignoresSafeArea()
}
