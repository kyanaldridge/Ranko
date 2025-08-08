//
//  DefaultList_ShareImage.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 10/6/2025.
//

import SwiftUI

struct DefaultListShareImage: View {
    let rankoName: String
    let items: [RankoItem]

    @State private var snapshotImage: UIImage?
    @State private var imageCache: [String: UIImage] = [:]
    @State private var isPreloading = true
    @Environment(\.dismiss) private var dismiss

    /// Top 10 sorted
    private var top10: [RankoItem] {
        Array(items.sorted { $0.rank < $1.rank }.prefix(12))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview or Snapshot
                Group {
                    if let img = snapshotImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                            .shadow(radius: 8)
                    } else {
                        PodiumRankoCard(
                            title: rankoName,
                            items: top10,
                            imageCache: imageCache
                        )
                    }
                }

                // Generate Button
                Button(action: {
                    snapshotImage = PodiumRankoCard(
                        title: rankoName,
                        items: top10,
                        imageCache: imageCache
                    ).snapshot()
                }) {
                    Text(isPreloading ? "Loading images…" : "Generate Image")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPreloading)

                // Save Button
                if snapshotImage != nil {
                    Button("Save to Photos") {
                        UIImageWriteToSavedPhotosAlbum(snapshotImage!, nil, nil, nil)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear(perform: preloadImages)
    }

    private func preloadImages() {
        let group = DispatchGroup()
        for item in top10 {
            guard let url = URL(string: item.itemImage) else { continue }
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let ui = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageCache[item.id] = ui
                    }
                }
                group.leave()
            }.resume()
        }
        group.notify(queue: .main) {
            isPreloading = false
        }
    }
}


/// A card that shows Top 3 on a podium + 4–10 in a grid below
struct PodiumRankoCard: View {
    let title: String
    let items: [RankoItem]        // expects up to 10
    let imageCache: [String: UIImage]

    private var podiumItems: [RankoItem] {
        items.filter { $0.rank <= 3 }.sorted { $0.rank < $1.rank }
    }
    private var nextItems: [RankoItem] {
        items.filter { $0.rank > 3 }.sorted { $0.rank < $1.rank }
    }

    // custom sizes for the podium
    private func size(for rank: Int) -> CGFloat {
        switch rank {
        case 1: return 120
        case 2: return 100
        case 3: return  80
        default: return  60
        }
    }

    // medal symbols
    private func medalSymbol(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.largeTitle)
                .bold()

            // ─── Podium for top 3 ───
            HStack(alignment: .bottom, spacing: 24) {
                ForEach(podiumItems) { item in
                    VStack(spacing: 8) {
                        // image
                        if let ui = imageCache[item.id] {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Color.gray
                                .frame(width: size(for: item.rank),
                                       height: size(for: item.rank))
                                .cornerRadius(8)
                        }

                        // rank medal + name
                        Text(medalSymbol(for: item.rank))
                            .font(.title)
                        Text(item.itemName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            // ─── Grid for 4th–10th ───
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                ForEach(nextItems) { item in
                    VStack(spacing: 6) {
                        HStack {
                            Text(medalSymbol(for: item.rank))
                            Spacer()
                        }
                        if let ui = imageCache[item.id] {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .frame(height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Color.gray
                                .frame(height: 60)
                                .cornerRadius(6)
                        }
                        Text(item.itemName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.bottom, 60)
    }
}
