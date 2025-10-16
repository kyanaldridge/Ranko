//
//  TierList_Gallery.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI

// MARK: - UserTierLists
struct TierListIndividualGallery: View {
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
                    Text("• \(timeAgo(from: String(listData.timeUpdated)))")
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

