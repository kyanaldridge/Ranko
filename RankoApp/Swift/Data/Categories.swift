//
//  CategoryChips.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI

// MARK: - CategoryChip Button View

struct CategoryChipButtonView: View {
    let categoryChip: CategoryChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: categoryChip.icon)
                    .foregroundColor(isSelected ? .white : categoryChipIconColors[categoryChip.name])
                Text(categoryChip.name)
                    .foregroundColor(isSelected ? .white : .black)
                    .font(.caption)
            }
            .padding(8)
            .background(isSelected ? categoryChipIconColors[categoryChip.name] : Color.white)
            .cornerRadius(8)
            .shadow(color: .gray.opacity(0.5), radius: isSelected ? 6 : 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Model

struct CategoryChip: Hashable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let icon: String
    let category: String
    let synonym: String
}

// Global mapping for icon colors.
let categoryChipIconColors: [String: Color] = [
    "Music": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Artists & Bands": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Songs": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Albums": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Instruments": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Festivals": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Band Members": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Record Labels": Color(red: 1.0, green: 0.0, blue: 0.0),
    "Genres": Color(red: 1.0, green: 0.0, blue: 0.0),
    
    "Sport": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Sports": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Athletes": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Leagues & Tournaments": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Clubs & Teams": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Football": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Basketball": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Australian Football": Color(red: 1.0, green: 0.27, blue: 0.0),
    "American Football": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Motorsport": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Olympics": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Stadiums & Venues": Color(red: 1.0, green: 0.27, blue: 0.0),
    "F1 Constructors": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Coaches & Managers": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Commentators": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Rivalries": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Mascots": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Gym Machines": Color(red: 1.0, green: 0.27, blue: 0.0),
    "Gym Exercises": Color(red: 1.0, green: 0.27, blue: 0.0),
    
    "Food": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Drinks": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Fruit": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Vegetables": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Pizza": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Fast Food Chains": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Eggs": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Chocolate": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Cheese": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Dairy": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Pasta": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Soft Drinks": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Alcohol": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Breakfast Cereals": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Ice Cream": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Cocktails": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Sandwiches": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Desserts": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Spices": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Coffees": Color(red: 1.0, green: 0.65, blue: 0.0),
    "Cuisines": Color(red: 1.0, green: 0.65, blue: 0.0),
    
    "Animals": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Plants": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Mammals": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Birds": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Dogs": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Flowers": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Trees": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Fish": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Reptiles": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Cats": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Bugs": Color(red: 1.0, green: 0.75, blue: 0.0),
    "Famous Animals": Color(red: 1.0, green: 0.75, blue: 0.0),
    
    "Celebrities": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Movies": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Social Media": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Books": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Authors": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Quotes": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Streaming Services": Color(red: 0.86, green: 0.44, blue: 0.84),
    "TV Shows": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Gaming": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Board Games": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Card Games": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Comedians": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Memes": Color(red: 0.86, green: 0.44, blue: 0.84),
    
    "Countries": Color(red: 0.60, green: 0.80, blue: 0.20),
    "Politicians": Color(red: 0.60, green: 0.80, blue: 0.20),
    "Landmarks": Color(red: 0.60, green: 0.80, blue: 0.20),
    "Cities": Color(red: 0.60, green: 0.80, blue: 0.20),
    
    "Models": .green,
    "Numbers": Color(red: 0.25, green: 0.88, blue: 0.82),
    "Letters": .blue,
    "Shapes": Color(red: 0.0, green: 0.0, blue: 1.0),
    "Statues": Color(red: 0.54, green: 0.17, blue: 0.89),
    "Planets": Color(red: 0.50, green: 0.0, blue: 0.50),
    "Relationships": Color(red: 0.86, green: 0.44, blue: 0.84),
    "Science": .blue,
    "Emotions": Color(red: 1.0, green: 0.75, blue: 0.80),
    "Red Flags": Color(red: 1.0, green: 0.08, blue: 0.58)
]

let flatCategoryChipMap: [String: CategoryChip] = categoryChipsByCategory
    .flatMap { $0.value } // Flatten all [CategoryChip]
    .reduce(into: [:]) { result, chip in
        result[chip.name] = chip
    }

let categoryChipsByCategory: [String: [CategoryChip]] = [
    "Music": [
        CategoryChip(name: "Music", icon: "music.note", category: "Music", synonym: "songs tunes melodies compositions rhythms"),
        CategoryChip(name: "Artists & Bands", icon: "music.microphone", category: "Music", synonym: "singers celebrities musicians groups ensembles"),
        CategoryChip(name: "Songs", icon: "music.quarternote.3", category: "Music", synonym: "tracks tunes melodies pieces anthems"),
        CategoryChip(name: "Albums", icon: "record.circle", category: "Music", synonym: "LPs mixtapes records compilations"),
        CategoryChip(name: "Instruments", icon: "guitars.fill", category: "Music", synonym: "guitars pianos drums violins synthesizers"),
        CategoryChip(name: "Festivals", icon: "hifispeaker.2.fill", category: "Music", synonym: "concerts fairs events celebrations"),
        CategoryChip(name: "Band Members", icon: "person.3.fill", category: "Music", synonym: "vocalists musicians performers crew"),
        CategoryChip(name: "Record Labels", icon: "tag.fill", category: "Music", synonym: "labels companies imprints publishers"),
        CategoryChip(name: "Genres", icon: "music.quarternote.3", category: "Music", synonym: "styles categories types subgenres")
    ],
    "Sports": [
        CategoryChip(name: "Sport", icon: "figure.walk", category: "Sports", synonym: "athletics games recreation exercise"),
        CategoryChip(name: "Sports", icon: "figure.archery", category: "Sports", synonym: "games athletics competitions events"),
        CategoryChip(name: "Athletes", icon: "figure.run", category: "Sports", synonym: "players competitors sportsmen sportswomen"),
        CategoryChip(name: "Leagues & Tournaments", icon: "trophy.fill", category: "Sports", synonym: "competitions cups championships contests"),
        CategoryChip(name: "Clubs & Teams", icon: "shield.lefthalf.filled", category: "Sports", synonym: "squads groups organizations units"),
        CategoryChip(name: "Football", icon: "soccerball", category: "Sports", synonym: "soccer gridiron rugby futsal"),
        CategoryChip(name: "Basketball", icon: "basketball.fill", category: "Sports", synonym: "hoops bball court net"),
        CategoryChip(name: "Australian Football", icon: "australian.football.fill", category: "Sports", synonym: "footy AFL Aussie football"),
        CategoryChip(name: "American Football", icon: "american.football.fill", category: "Sports", synonym: "gridiron NFL pigskin touchdown"),
        CategoryChip(name: "Motorsport", icon: "steeringwheel", category: "Sports", synonym: "racing circuits speed rally"),
        CategoryChip(name: "Olympics", icon: "flag.fill", category: "Sports", synonym: "games olympiad international sports events"),
        CategoryChip(name: "Stadiums & Venues", icon: "sportscourt.fill", category: "Sports", synonym: "arenas fields complexes grounds"),
        CategoryChip(name: "F1 Constructors", icon: "wrench.and.screwdriver.fill", category: "Sports", synonym: "teams formula-one constructors racing"),
        CategoryChip(name: "Coaches & Managers", icon: "megaphone.fill", category: "Sports", synonym: "trainers mentors leaders directors"),
        CategoryChip(name: "Commentators", icon: "headset", category: "Sports", synonym: "announcers reporters broadcasters analysts"),
        CategoryChip(name: "Rivalries", icon: "oar.2.crossed", category: "Sports", synonym: "feuds competitions matchups conflicts"),
        CategoryChip(name: "Mascots", icon: "figure.dance", category: "Sports", synonym: "characters symbols icons representatives"),
        CategoryChip(name: "Gym Machines", icon: "figure.indoor.cycle", category: "Sports", synonym: "equipment apparatus devices machines"),
        CategoryChip(name: "Gym Exercises", icon: "figure.hand.cycling", category: "Sports", synonym: "workouts training routines drills")
    ],
    "Food & Drink": [
        CategoryChip(name: "Food", icon: "fork.knife", category: "Food & Drink", synonym: "cuisine meals edibles dishes"),
        CategoryChip(name: "Drinks", icon: "waterbottle.fill", category: "Food & Drink", synonym: "beverages cocktails juices sodas"),
        CategoryChip(name: "Fruit", icon: "applelogo", category: "Food & Drink", synonym: "apples oranges bananas berries"),
        CategoryChip(name: "Vegetables", icon: "carrot.fill", category: "Food & Drink", synonym: "greens veggies produce legumes"),
        CategoryChip(name: "Pizza", icon: "triangle.lefthalf.filled", category: "Food & Drink", synonym: "pie slices Italian flatbread calzones"),
        CategoryChip(name: "Fast Food Chains", icon: "takeoutbag.and.cup.and.straw.fill", category: "Food & Drink", synonym: "burgers fries shakes subs"),
        CategoryChip(name: "Eggs", icon: "frying.pan.fill", category: "Food & Drink", synonym: "ovum omelets scramble quiche"),
        CategoryChip(name: "Chocolate", icon: "square.grid.3x3.square", category: "Food & Drink", synonym: "cocoa sweets treats bars"),
        CategoryChip(name: "Cheese", icon: "drop.triangle.fill", category: "Food & Drink", synonym: "dairy curds cheddar gouda"),
        CategoryChip(name: "Dairy", icon: "waterbottle.fill", category: "Food & Drink", synonym: "milk products cream butter"),
        CategoryChip(name: "Pasta", icon: "water.waves", category: "Food & Drink", synonym: "noodles spaghetti linguine fettuccine"),
        CategoryChip(name: "Soft Drinks", icon: "bubbles.and.sparkles.fill", category: "Food & Drink", synonym: "sodas pop beverages colas"),
        CategoryChip(name: "Alcohol", icon: "flame.fill", category: "Food & Drink", synonym: "spirits liquor brews cocktails"),
        CategoryChip(name: "Breakfast Cereals", icon: "rectangle.portrait.righthalf.inset.filled", category: "Food & Drink", synonym: "granola oats muesli flakes"),
        CategoryChip(name: "Ice Cream", icon: "snowflake", category: "Food & Drink", synonym: "gelato frozen yogurt sherbet custard"),
        CategoryChip(name: "Cocktails", icon: "beach.umbrella.fill", category: "Food & Drink", synonym: "mixed drinks libations martinis mojitos"),
        CategoryChip(name: "Sandwiches", icon: "square.3.layers.3d.top.filled", category: "Food & Drink", synonym: "subs burgers wraps paninis"),
        CategoryChip(name: "Desserts", icon: "birthday.cake.fill", category: "Food & Drink", synonym: "sweets treats pastries confections"),
        CategoryChip(name: "Spices", icon: "thermometer.sun.fill", category: "Food & Drink", synonym: "herbs seasonings flavorings condiments"),
        CategoryChip(name: "Coffees", icon: "cup.and.saucer.fill", category: "Food & Drink", synonym: "espresso latte cappuccino mocha brew"),
        CategoryChip(name: "Cuisines", icon: "globe", category: "Food & Drink", synonym: "dishes cooking fare gastronomies meals")
    ],
    "Nature": [
        CategoryChip(name: "Animals", icon: "pawprint.fill", category: "Nature", synonym: "creatures fauna wildlife species"),
        CategoryChip(name: "Plants", icon: "leaf.fill", category: "Nature", synonym: "flora vegetation herbs shrubs"),
        CategoryChip(name: "Mammals", icon: "hare.fill", category: "Nature", synonym: "placentals marsupials primates carnivores"),
        CategoryChip(name: "Birds", icon: "bird.fill", category: "Nature", synonym: "avians fowls songbirds raptors"),
        CategoryChip(name: "Dogs", icon: "dog.fill", category: "Nature", synonym: "canines pooches mutts hounds"),
        CategoryChip(name: "Flowers", icon: "microbe.fill", category: "Nature", synonym: "blooms petals blossoms flora"),
        CategoryChip(name: "Trees", icon: "tree.fill", category: "Nature", synonym: "oaks maples pines birches"),
        CategoryChip(name: "Fish", icon: "fish.fill", category: "Nature", synonym: "aquatic swimmers marine finned"),
        CategoryChip(name: "Reptiles", icon: "lizard.fill", category: "Nature", synonym: "snakes lizards turtles crocodiles"),
        CategoryChip(name: "Cats", icon: "cat.fill", category: "Nature", synonym: "felines kitties pussycats panthers"),
        CategoryChip(name: "Bugs", icon: "ladybug.fill", category: "Nature", synonym: "insects arthropods critters pests"),
        CategoryChip(name: "Famous Animals", icon: "star.fill", category: "Nature", synonym: "legendary iconic wildlife stars")
    ],
    "Entertainment": [
        CategoryChip(name: "Celebrities", icon: "star.fill", category: "Entertainment", synonym: "stars icons luminaries VIPs"),
        CategoryChip(name: "Movies", icon: "movieclapper", category: "Entertainment", synonym: "films flicks features shorts"),
        CategoryChip(name: "Social Media", icon: "message.fill", category: "Entertainment", synonym: "networks platforms online communities"),
        CategoryChip(name: "Books", icon: "books.vertical.fill", category: "Entertainment", synonym: "novels literature tomes texts"),
        CategoryChip(name: "Authors", icon: "book.fill", category: "Entertainment", synonym: "writers novelists wordsmiths scribes"),
        CategoryChip(name: "Quotes", icon: "quote.opening", category: "Entertainment", synonym: "sayings aphorisms maxims proverbs"),
        CategoryChip(name: "Streaming Services", icon: "play.rectangle.fill", category: "Entertainment", synonym: "platforms services portals channels"),
        CategoryChip(name: "TV Shows", icon: "tv.fill", category: "Entertainment", synonym: "series broadcasts programs episodes"),
        CategoryChip(name: "Gaming", icon: "gamecontroller.fill", category: "Entertainment", synonym: "videogames esports interactive recreation"),
        CategoryChip(name: "Board Games", icon: "dice.fill", category: "Entertainment", synonym: "tabletop classics strategy party"),
        CategoryChip(name: "Card Games", icon: "suit.club.fill", category: "Entertainment", synonym: "poker bridge rummy blackjack"),
        CategoryChip(name: "Comedians", icon: "music.microphone", category: "Entertainment", synonym: "humorists comics stand-ups jesters"),
        CategoryChip(name: "Memes", icon: "camera.fill", category: "Entertainment", synonym: "viral jokes internet gags")
    ],
    "Humanities": [
        CategoryChip(name: "Countries", icon: "globe.europe.africa.fill", category: "Humanities", synonym: "nations states lands territories"),
        CategoryChip(name: "Politicians", icon: "megaphone.fill", category: "Humanities", synonym: "leaders statesmen officials lawmakers"),
        CategoryChip(name: "Landmarks", icon: "building.columns.fill", category: "Humanities", synonym: "monuments icons sites attractions"),
        CategoryChip(name: "Cities", icon: "building.2.fill", category: "Humanities", synonym: "metropolises urban centers towns municipalities")
    ],
    "Other": [
        CategoryChip(name: "Models", icon: "camera.fill", category: "Other", synonym: "figures prototypes replicas designs"),
        CategoryChip(name: "Numbers", icon: "1.square.fill", category: "Other", synonym: "digits figures numerals statistics"),
        CategoryChip(name: "Letters", icon: "a.square.fill", category: "Other", synonym: "characters alphabets glyphs script"),
        CategoryChip(name: "Shapes", icon: "triangle.fill", category: "Other", synonym: "forms figures outlines geometries"),
        CategoryChip(name: "Statues", icon: "figure.stand", category: "Other", synonym: "sculptures monuments effigies carvings"),
        CategoryChip(name: "Planets", icon: "circles.hexagonpath.fill", category: "Other", synonym: "worlds celestial bodies orbs spheres"),
        CategoryChip(name: "Relationships", icon: "heart.fill", category: "Other", synonym: "bonds connections associations links"),
        CategoryChip(name: "Science", icon: "atom", category: "Other", synonym: "planets, chemistry, biology, physics, astronomy"),
        CategoryChip(name: "Emotions", icon: "face.smiling", category: "Other", synonym: "feelings sentiments moods passions"),
        CategoryChip(name: "Red Flags", icon: "flag.fill", category: "Other", synonym: "warningSigns alerts cautionSignals indicators")
    ]
]

// MARK: - FlowLayout for ....

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0, currentRowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0, totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth {
                totalWidth = max(totalWidth, currentRowWidth)
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, currentRowWidth)
        totalHeight += currentRowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}



// MARK: - Category Picker View with Search



struct CategoryPickerView: View {
    let categoryChipsByCategory: [String: [CategoryChip]]
    @Binding var selectedCategoryChip: CategoryChip?
    @Binding var isPresented: Bool
    @State private var localSelection: CategoryChip? = nil
    
    // New search state.
    @State private var searchText: String = ""
    
    // Filtered and sorted categories based on search text.
    var sortedCategories: [(key: String, value: [CategoryChip])] {
        let categories = categoryChipsByCategory.compactMap { (category, categoryChips) -> (String, [CategoryChip])? in
            // If search text is empty then use the full list.
            if searchText.isEmpty {
                return (category, categoryChips)
            } else {
                // Filter categoryChips whose name or category contains the search text.
                let filtered = categoryChips.filter {
                    ($0.name.lowercased().contains(searchText.lowercased()) ||
                    $0.category.lowercased().contains(searchText.lowercased()) ||
                    $0.synonym.lowercased().contains(searchText.lowercased()))
                }
                return filtered.isEmpty ? nil : (category, filtered)
            }
        }
        return categories.sorted { (lhs: (key: String, value: [CategoryChip]), rhs: (key: String, value: [CategoryChip])) -> Bool in
            return lhs.key < rhs.key
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.gray
                    .opacity(0.1)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Insert the custom search bar at the top.
                    CustomSearchBar(text: $searchText, preText: "Eg. Landmarks, Books, Mammals")
                        .autocorrectionDisabled(true)
                        .padding(.bottom, 20)
                    
                    ScrollView {
                        // Use a VStack that takes the full available width with left alignment.
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(sortedCategories, id: \.key) { category, categoryChips in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(category)
                                        .font(.headline)
                                        .padding(.horizontal)
                                        .fontWeight(.bold)
                                    // Ensure the flow layout is left-aligned.
                                    FlowLayout(spacing: 8) {
                                        ForEach(categoryChips) { categoryChip in
                                            CategoryChipButtonView(categoryChip: categoryChip, isSelected: localSelection == categoryChip) {
                                                localSelection = categoryChip
                                            }
                                            .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                        .padding(.bottom, 80) // Leave space for the bottom controls.
                    }
                    .padding(.top, -10)
                }
                
                // Blurred background behind the Done button.
                Rectangle()
                    .blur(radius: 20)
                    .foregroundColor(.white)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(height: 80)
                
                Button {
                    if let selection = localSelection {
                        selectedCategoryChip = selection
                        isPresented = false
                    }
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(localSelection != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(localSelection == nil)
                .padding(.bottom)
            }
            .navigationTitle("Select Category")
            // Remove the .searchable modifier.
            .background(Color.white.ignoresSafeArea())
        }
    }
}

// MARK: – Category badge helper
struct FeaturedCategoryBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: FilterChip.icon(named: text, in: defaultFilterChips) ?? "circle.fill")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(categoryChipIconColors[text])
            Text(text)
                .font(.custom("Nunito-ExtraBold", size: 11))
                .foregroundColor(categoryChipIconColors[text])
        }
        .font(.caption)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(categoryChipIconColors[text] ?? .black)
                .opacity(0.15)
        )
    }
}
// MARK: – Category badge helper
struct HomeCategoryBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: FilterChip.icon(named: text, in: defaultFilterChips) ?? "circle.fill")
                .foregroundColor(categoryChipIconColors[text])
            Text(text)
                .bold()
                .foregroundColor(categoryChipIconColors[text])
        }
        .font(.caption)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(categoryChipIconColors[text] ?? .blue)
                .opacity(0.2)
        )
    }
}

struct HomeCategoryBadge1: View {
    let text: String
    var body: some View {
        Circle()
            .foregroundColor(categoryChipIconColors[text]?.opacity(0.6))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: FilterChip.icon(named: text, in: defaultFilterChips) ?? "circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 16, maxHeight: 16)
                    .fontWeight(.black)
                    .foregroundColor(Color(hex: 0xFFFFFF))
            )
            
    }
}
