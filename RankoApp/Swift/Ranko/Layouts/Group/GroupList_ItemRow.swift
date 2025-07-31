//
//  GroupList_ItemRow.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI

// MARK: – Row Subview for a Selected Item
struct GroupListItemRow: View {
    let item: AlgoliaRankoItem

    private var badge: some View {
        Group {
            switch item.rank {
            case 1: Image(systemName: "1.circle.fill").foregroundColor(Color(red: 1, green: 0.65, blue: 0)).font(.body).padding(3)
            case 2: Image(systemName: "2.circle.fill").foregroundColor(Color(red: 0.635, green: 0.7, blue: 0.698)).font(.body).padding(3)
            case 3: Image(systemName: "3.circle.fill").foregroundColor(Color(red: 0.56, green: 0.33, blue: 0)).font(.body).padding(3)
            default: Text("\(item.rank)").font(.caption).padding(5).fontWeight(.heavy)
            }
        }
        .background(Circle().fill(Color.white))
        .offset(x: 7, y: 7)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.itemImage)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 50, height: 50)
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 50, height: 50)
                            Image(systemName: "xmark.octagon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                badge
            }

            

            VStack(alignment: .leading) {
                Text(item.itemName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(item.itemDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding(.horizontal)
    }
}



