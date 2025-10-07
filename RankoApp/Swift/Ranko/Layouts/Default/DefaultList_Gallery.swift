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
    let userID: String   // ⬅️ new

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
                Button { onUnpin?() } label: {
                    Image(systemName: "pin.fill")
                        .font(.custom("Nunito-Black", size: 12))
                        .foregroundColor(Color(hex: 0x514343))
                        .padding(.trailing, 6)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(.clear)
        .padding(.vertical, 1)
    }

    private var overlappingImages: some View {
        HStack(spacing: -12) {
            // we only ever save the top-3 by RANK to disk
            let top3 = Array(sortedItems.prefix(3))
            ForEach(Array(top3.enumerated()), id: \.offset) { (idx, item) in
                OfflineFirstThumb(
                    localURL: cachedImageURL(uid: userID, rankoID: listData.id, idx: idx + 1),
                    remoteString: item.itemImage // your existing remote value
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: 0xFFFFFF), lineWidth: 2))
                .background(Circle().fill(Color(hex: 0xFFFFFF)))
            }
        }
    }

    private func timeAgo(from dt: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "yyyyMMddHHmmss"
        guard let date = formatter.date(from: dt) else { return "" }
        let secondsAgo = Int(Date().timeIntervalSince(date))
        switch secondsAgo {
        case 0..<60: return "\(secondsAgo)s ago"
        case 60..<3600: return "\(secondsAgo / 60)m ago"
        case 3600..<86400: return "\(secondsAgo / 3600)h ago"
        case 86400..<604800: return "\(secondsAgo / 86400)d ago"
        case 604800..<31536000: return "\(secondsAgo / 604800)w ago"
        default: return "\(secondsAgo / 31536000)y ago"
        }
    }
}

/// A tiny helper view that prefers a local file if it exists; otherwise falls back to the remote URL.
private struct OfflineFirstThumb: View {
    let localURL: URL
    let remoteString: String

    var body: some View {
        if FileManager.default.fileExists(atPath: localURL.path),
           let ui = UIImage(contentsOfFile: localURL.path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: remoteString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    Color.gray.opacity(0.2)
                case .failure:
                    Color.gray.opacity(0.25)
                @unknown default:
                    Color.gray.opacity(0.25)
                }
            }
        } else {
            Color.gray.opacity(0.25)
        }
    }
}
