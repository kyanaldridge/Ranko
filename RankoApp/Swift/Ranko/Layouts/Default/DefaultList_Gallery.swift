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

}

#Preview {
    VStack {
        Spacer()
        DefaultListIndividualGallery(
            listData: RankoList(
                id: "",
                listName: "Top 10 Albums of the 1970s to 2010s",
                listDescription: "my fav albums",
                type: "default",
                category: "Albums",
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
        Spacer()
    }
    .background(
        RoundedRectangle(cornerRadius: 25)
            .fill(
                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFF5E2), Color(hex: 0xFFF5E2)]),
                               startPoint: .top,
                               endPoint: .bottom
                              )
            )
    )
    .ignoresSafeArea()
}
