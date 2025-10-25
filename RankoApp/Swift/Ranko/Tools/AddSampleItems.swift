
//  AddSampleItems.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 21/10/2025.
//

import SwiftUI
import UIKit

// MARK: - Category Model
struct AppCategory: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let bg: Color
    let keywords: [String]
}

struct AppSubcategory: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let bg: Color
    let keywords: [String]
    let destination: AnyView
}

// MARK: - Subcategory color resolver
private func resolvedSubBG(parent: Color, subBG: Color) -> Color {
    // if you pass .clear for a subcategory bg, it will inherit the parent color.
    // otherwise we respect the custom sub color you provide.
    let isClear = subBG == Color.clear
    return isClear ? parent : subBG
}

// use this in your existing mapper (replace your previous `subcategories(for:)`)
private func subcategories(for category: AppCategory) -> [AppSubcategory] {
    (SUBCATEGORIES[category.name] ?? [])
        .map { sc in
            .init(
                name: sc.name,
                symbol: sc.symbol,
                // inherit or use override (e.g., Food vs Drink shades)
                bg: resolvedSubBG(parent: category.bg, subBG: sc.bg),
                keywords: sc.keywords,
                destination: sc.destination
            )
        }
}

// MARK: - Categories Data (unchanged except your hex colors)
private let CATEGORIES: [AppCategory] = [
    .init(name: "Music", symbol: "music.note", bg: Color(hex: 0xF04136),
          keywords: ["songs","albums","artists","spotify","playlists","tracks","genres","concerts","rankings"]),
    .init(name: "Sport", symbol: "sportscourt.fill", bg: Color(hex: 0x3EB54F),
          keywords: ["atheletes","people","clubs","teams","leagues","trophies","coaches","referees","managers"]),
    .init(name: "Food & Drink", symbol: "fork.knife", bg: Color(hex: 0x5460AE),
          keywords: ["restaurants","recipes","cuisine","drinks","coffee","bars","snacks","meals"]),
    .init(name: "Animals", symbol: "pawprint.fill", bg: Color(hex: 0xF78F1D),
          keywords: ["pets","wildlife","breeds","dogs","cats","zoo","habitats"]),
    .init(name: "Geography", symbol: "globe.americas.fill", bg: Color(hex: 0x1CA975),
          keywords: ["countries","cities","maps","landmarks","flags","capitals"]),
    .init(name: "People", symbol: "person.3.fill", bg: Color(hex: 0x8F4E88),
          keywords: ["celebrities","historical","influencers","leaders","creators"]),
    .init(name: "Films & Series", symbol: "film.fill", bg: Color(hex: 0x256EB7),
          keywords: ["movies","tv","directors","actors","episodes","franchises"]),
    .init(name: "Books", symbol: "text.book.closed.fill", bg: Color(hex: 0x007BC2),
          keywords: ["novels","authors","genres","series","literature"]),
    .init(name: "Gaming", symbol: "gamecontroller.fill", bg: Color(hex: 0xFFBA10),
          keywords: ["games","platforms","studios","genres","esports"]),
    .init(name: "History", symbol: "building.columns.fill", bg: Color(hex: 0x009B96),
          keywords: ["civilizations","artifacts","archives","biographies"]),
    .init(name: "Plants", symbol: "leaf.fill", bg: Color(hex: 0x7CC148),
          keywords: ["botany","flowers","trees","gardening","herbs"]),
    .init(name: "Science", symbol: "atom", bg: Color(hex: 0xDBDB22),
          keywords: ["physics","chemistry","biology","space","experiments"]),
    .init(name: "Vehicles", symbol: "car.fill", bg: Color(hex: 0x6A51A1),
          keywords: ["cars","bikes","planes","trains","boats","specs"]),
    .init(name: "Brands", symbol: "tag.fill", bg: Color(hex: 0x0485CF),
          keywords: ["companies","logos","fashion","tech","retail"]),
    .init(name: "Miscellaneous", symbol: "square.grid.2x2.fill", bg: Color(hex: 0xCD4755),
          keywords: ["random","other","mixed","uncategorized"])
]

// MARK: - Subcategory data per category
private let SUBCATEGORIES: [String: [AppSubcategory]] = [
    "Music": [
        .init(name: "Artists",     symbol: "person.crop.square", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Albums",      symbol: "square.stack",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Tracks",      symbol: "music.note.list",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Genres",      symbol: "guitars",             bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Playlists",   symbol: "music.note.list",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Concerts",    symbol: "ticket.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Instruments", symbol: "pianokeys",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Labels",      symbol: "tag.fill",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Charts",      symbol: "chart.bar.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Decades",     symbol: "clock.arrow.circlepath", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Awards",      symbol: "trophy.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Sport": [
        .init(name: "Athletes",  symbol: "figure.run",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Teams",     symbol: "sportscourt",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Leagues",   symbol: "trophy.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Fixtures",  symbol: "calendar",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Results",   symbol: "list.number",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Stadiums",  symbol: "building.columns", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Coaches & Managers",   symbol: "person.2.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Referees",  symbol: "figure.wave",     bg: .clear, keywords: [], destination: AnyView(EmptyView())), // sf-symbol alt? if missing, swap icon
        .init(name: "Records",   symbol: "rosette",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Trophies",  symbol: "trophy",           bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Food & Drink": [
        // — Food (darker)
        .init(name: "Cuisines",     symbol: "fork.knife.circle.fill", bg: Color(hex: 0x3D4886), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Dishes",       symbol: "takeoutbag.and.cup.and.straw.fill", bg: Color(hex: 0x354071), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Ingredients",  symbol: "leaf.fill",              bg: Color(hex: 0x3D4886), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Desserts",     symbol: "birthday.cake.fill",           bg: Color(hex: 0x5F6BC9), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Restaurants",  symbol: "fork.knife",             bg: Color(hex: 0x6B79C7), keywords: [], destination: AnyView(EmptyView())),
        // — Drinks (brighter)
        .init(name: "Beverages",    symbol: "cup.and.saucer.fill",    bg: Color(hex: 0x8090D9), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Coffee",       symbol: "cup.and.saucer",         bg: Color(hex: 0x94A4EA), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Tea",          symbol: "humidity.fill",            bg: Color(hex: 0x94A4EA), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Cocktails",    symbol: "wineglass.fill",         bg: Color(hex: 0xAEBBFF), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Beer",         symbol: "mug.fill",               bg: Color(hex: 0xAEBBFF), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Wine",         symbol: "wineglass",              bg: Color(hex: 0xAEBBFF), keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Bars",         symbol: "building.2.fill",        bg: Color(hex: 0x94A4EA), keywords: [], destination: AnyView(EmptyView()))
    ],
    "Animals": [
        .init(name: "Wild",        symbol: "pawprint.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Pets",        symbol: "house.fill",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Dog Breeds",  symbol: "dog.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())), // if missing, swap to paw/animal
        .init(name: "Cat Breeds",  symbol: "cat.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Birds",       symbol: "bird.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Reptiles",    symbol: "tortoise.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Marine",      symbol: "fish.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Insects",     symbol: "ant.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Habitats",    symbol: "leaf",              bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Conservation",symbol: "shield.lefthalf.filled", bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Geography": [
        .init(name: "Countries",   symbol: "globe.europe.africa.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Cities",      symbol: "building.2.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Flags",       symbol: "flag.fill",                bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Landmarks",   symbol: "mappin.and.ellipse",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Capitals",    symbol: "building.columns.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Mountains",   symbol: "mountain.2.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Rivers",      symbol: "water.waves",              bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Lakes",       symbol: "water.waves.and.arrow.down", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Regions",     symbol: "square.grid.2x2.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Parks",       symbol: "tree.fill",                bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "People": [
        .init(name: "Historical",  symbol: "book.closed.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Celebrities", symbol: "star.fill",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Athletes",    symbol: "figure.run",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Scientists",  symbol: "atom",                 bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Politicians", symbol: "person.2.wave.2.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Creators",    symbol: "paintpalette.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Influencers", symbol: "camera.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Entrepreneurs", symbol: "briefcase.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Writers",     symbol: "pencil.and.outline",   bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Musicians",   symbol: "music.note",           bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Films & Series": [
        .init(name: "Movies",     symbol: "film.fill",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "TV Shows",   symbol: "tv.fill",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Directors",  symbol: "person.crop.rectangle", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Actors",     symbol: "person.fill",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Franchises", symbol: "square.stack.3d.down.forward", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Genres",     symbol: "square.grid.2x2",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Studios",    symbol: "building.2.crop.circle", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Soundtracks",symbol: "music.quarternote.3", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Awards",     symbol: "rosette",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Episodes",   symbol: "list.bullet.rectangle.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Books": [
        .init(name: "Authors",     symbol: "person.fill",             bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Novels",      symbol: "book.fill",               bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Series",      symbol: "books.vertical.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Genres",      symbol: "square.grid.2x2",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Non-fiction", symbol: "text.book.closed.fill",   bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Poems",       symbol: "text.alignleft",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Award Winners", symbol: "rosette",               bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Publishers",  symbol: "building.columns",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Characters",  symbol: "theatermasks.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Classics",    symbol: "seal.fill",               bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Gaming": [
        .init(name: "Games",      symbol: "gamecontroller.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Platforms",  symbol: "desktopcomputer",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Studios",    symbol: "building.2.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Genres",     symbol: "square.grid.2x2",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Esports",    symbol: "sportscourt",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Characters", symbol: "person.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "DLC",        symbol: "puzzlepiece.extension", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Soundtracks",symbol: "music.note",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Achievements", symbol: "medal.fill",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Consoles",   symbol: "gamecontroller",      bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "History": [
        .init(name: "Civilizations", symbol: "building.columns.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Eras",          symbol: "hourglass",             bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Events",        symbol: "calendar",              bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Battles",       symbol: "shield.fill",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Leaders",       symbol: "crown.fill",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Inventions",    symbol: "lightbulb.fill",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Artifacts",     symbol: "scroll.fill",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Documents",     symbol: "doc.plaintext.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Empires",       symbol: "globe.asia.australia.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Revolutions",   symbol: "flame.fill",            bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Plants": [
        .init(name: "Flowers",     symbol: "microbe.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Trees",       symbol: "tree.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Herbs",       symbol: "leaf.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Succulents",  symbol: "leaf.circle.fill",bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Houseplants", symbol: "house.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Fruits",      symbol: "apple.logo",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Vegetables",  symbol: "carrot.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())), // custom sf-symbol? replace if needed
        .init(name: "Cacti",       symbol: "sun.min.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Medicinal",   symbol: "cross.case.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Carnivorous", symbol: "leaf.arrow.triangle.circlepath", bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Science": [
        .init(name: "Physics",     symbol: "atom",                 bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Chemistry",   symbol: "flask.fill",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Biology",     symbol: "figure.wave",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Astronomy",   symbol: "moon.stars.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Geology",     symbol: "mountain.2.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Mathematics", symbol: "sum",                  bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Technology",  symbol: "cpu",                  bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Experiments", symbol: "testtube.2",           bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Inventions",  symbol: "lightbulb",            bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Scientists",  symbol: "person.crop.rectangle",bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Vehicles": [
        .init(name: "Cars",        symbol: "car.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Motorcycles", symbol: "scooter",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Trucks",      symbol: "box.truck.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Bicycles",    symbol: "bicycle",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Trains",      symbol: "train.side.front.car", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Planes",      symbol: "airplane",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Boats",       symbol: "ferry.fill",     bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "EVs",         symbol: "bolt.car.fill",  bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Brands",      symbol: "tag.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Engines",     symbol: "gearshape.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Brands": [
        .init(name: "Fashion",   symbol: "tshirt.fill",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Tech",      symbol: "iphone.gen3",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Automotive",symbol: "car.side",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Food & Drink", symbol: "fork.knife",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Sportswear",symbol: "sportscourt.fill", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Retailers", symbol: "bag.fill",         bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Luxury",    symbol: "crown.fill",       bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Startups",  symbol: "bolt.fill",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Logos",     symbol: "seal",             bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Slogans",   symbol: "quote.bubble.fill",bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ],
    "Miscellaneous": [
        .init(name: "Memes",     symbol: "face.smiling.fill",   bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Trivia",    symbol: "questionmark.circle", bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Puzzles",   symbol: "puzzlepiece.fill",    bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Gadgets",   symbol: "headphones",          bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Toys",      symbol: "gamecontroller",      bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Hobbies",   symbol: "paintbrush.pointed",  bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Holidays",  symbol: "calendar.badge.clock",bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Colors",    symbol: "paintpalette.fill",   bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Emojis",    symbol: "face.smiling",        bg: .clear, keywords: [], destination: AnyView(EmptyView())),
        .init(name: "Random",    symbol: "shuffle",             bg: .clear, keywords: [], destination: AnyView(EmptyView()))
    ]
]

// MARK: - Root Categories View (iOS 18+ for .zoom)
struct CategoriesView: View {
    @Namespace private var ns
    @State private var searchText: String = ""
    @State private var expandedCategoryID: UUID? = nil       // which row should reveal subcategories

    private let columns = 2
    private let tileSpacing: CGFloat = 12
    private let numberOfItems = 28

    private var filtered: [AppCategory] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return CATEGORIES }
        return CATEGORIES.filter { cat in
            cat.name.lowercased().contains(q) ||
            cat.keywords.contains(where: { $0.lowercased().contains(q) })
        }
    }

    // chunk categories into rows of 3 so we can insert a disclosure section between specific rows
    private var rows: [[AppCategory]] {
        filtered.chunked(into: columns)
    }

    var body: some View {
        TabView {
            Tab("", systemImage: "plus.app.fill") {
            }
            .badge(numberOfItems)
            Tab("Search", systemImage: "square.grid.2x2.fill", role: .search) {
                NavigationStack {
                    ScrollView {
                        LazyVStack(spacing: tileSpacing) {
                            ForEach(rows.indices, id: \.self) { rowIndex in
                                HStack(spacing: tileSpacing) {
                                    ForEach(rows[rowIndex]) { cat in
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                // toggle expansion for this row
                                                expandedCategoryID = (expandedCategoryID == cat.id) ? nil : cat.id
                                            }
                                        } label: {
                                            CategoryTile(category: cat, isSelected: expandedCategoryID == cat.id)
                                                .matchedTransitionSource(id: cat.id, in: ns)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(Text(cat.name))
                                    }
                                }

                                // — Subcategory disclosure section appears *after* this row if a category in this row is expanded
                                if let expanded = expandedCategoryID,
                                   let expandedCat = rows[rowIndex].first(where: { $0.id == expanded }) {
                                    SubcategoryDisclosureRow(
                                        parent: expandedCat,
                                        subcategories: subcategories(for: expandedCat),
                                        ns: ns
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                                }
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HStack {
                                Text("Select Category")
                                    .font(.custom("Nunito-Black", size: 22))
                                    .foregroundStyle(Color(hex: 0x292A30))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 30)
                            .padding(.bottom, 1)
                        }
                    }
                    .searchable(text: $searchText,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search categories & keywords")
                }
                .font(.custom("Nunito-Black", size: 18))
            }
        }
        .tint(Color(hex: 0xFD806F))
    }

    private func subcategories(for category: AppCategory) -> [AppSubcategory] {
        // take configured subcats and force them to use the parent color
        (SUBCATEGORIES[category.name] ?? [])
            .map { sc in .init(name: sc.name, symbol: sc.symbol, bg: category.bg, keywords: sc.keywords, destination: sc.destination) }
    }
}

// MARK: - Inline disclosure row showing a 4-column grid of subcats
private struct SubcategoryDisclosureRow: View {
    let parent: AppCategory
    let subcategories: [AppSubcategory]
    let ns: Namespace.ID
    
    @State private var isExpanded = true
    
    var body: some View {
        SubcategoryFlexibleView(spacing: 8, rowAlignment: .center) {
            ForEach(subcategories) { sc in
                NavigationLink {
                    SubcategoryDestinationView(subcategory: sc)
                        .navigationTransition(.zoom(sourceID: sc.id, in: ns))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: sc.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(sc.name)
                            .font(.custom("Nunito-Black", size: 13))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .matchedTransitionSource(id: sc.id, in: ns)
                }
                .foregroundColor(Color(hex: 0xFFFFFF))
                .tint(sc.bg.opacity(0.7))
                .buttonStyle(.glassProminent)
                .fixedSize(horizontal: true, vertical: false)   // << important for centering
            }
        }
        .padding(.horizontal, 2)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isExpanded = true
            }
        }
    }
}

struct SubcategoryFlexibleView: Layout {
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

// MARK: - Subcategory tile (icon + name on the same line)
private struct SubcategoryTile: View {
    let sub: AppSubcategory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sub.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(sub.bg)

            Text(sub.name)
                .font(.custom("Nunito-Black", size: 12))
                .foregroundColor(sub.bg)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, -5)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(sub.bg, lineWidth: 2)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shared destination; title is customized by subcategory (icon + name + tint)
private struct SubcategoryDestinationView: View {
    let subcategory: AppSubcategory

    var body: some View {
        // blank content for now
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: subcategory.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(subcategory.bg)
                        Text(subcategory.name)
                            .font(.custom("Nunito-Black", size: 16))
                            .foregroundStyle(subcategory.bg)
                    }
                }
            }
            .tint(subcategory.bg)
    }
}

// MARK: - Small array chunker
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var idx = 0
        while idx < count {
            let end = Swift.min(idx + size, count)
            result.append(Array(self[idx..<end]))
            idx = end
        }
        return result
    }
}

// MARK: - Tile
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
                    .foregroundColor(category.bg)
                    .padding(14)
                
                Spacer(minLength: 0)
                
                Text(category.name)
                    .font(.custom("Nunito-Black", size: 17))
                    .foregroundColor(category.bg)
                    .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0xFFFFFF))
                    .shadow(color: isSelected ? category.bg : Color.black.opacity(0.2), radius: 3)
            }
        }
        .onChange(of: isSelected) { _, _ in
            withAnimation {
                isHighlighted = isSelected
            }
        }
    }
}
