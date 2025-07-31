//
//  FilterChips.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 9/5/2025.
//

import SwiftUI
import InstantSearch
import InstantSearchSwiftUI
import AlgoliaSearchClient

// MARK: - FilterChip Model
struct FilterChip: Identifiable, Equatable, Codable {
    var id = UUID()
    let name: String
    let icon: String
    let synonyms: String
    let nameIndex: String
    let filter: String
    let children: [FilterChip]
    var available: Bool = true
    let order: Int
}

// Global color mapping for filter chips
let filterChipIconColors: [String: Color] = [
   
   "1001": Color(red: 0.51, green: 0, blue: 0),              // Maroon
   "1002": Color(red: 0.78, green: 0, blue: 0),              // Dark Red
   "1003": Color(red: 1, green: 0, blue: 0),                 // Red
   "1004": Color(red: 1, green: 0.2, blue: 0),               // Red-Orange
   "1005": Color(red: 1, green: 0.35, blue: 0),              // Orange
   "1006": Color(red: 1, green: 0.52, blue: 0),              // Lighter Orange
   "1007": Color(red: 1, green: 0.65, blue: 0),              // Orange-Yellow
   "1008": Color(red: 1, green: 0.72, blue: 0),              // Darker Yellow
   "1009": Color(red: 1, green: 0.78, blue: 0),              // Yellow
   "1010": Color(red: 0.62, green: 0.87, blue: 0),           // Lime
   "1011": Color(red: 0.29, green: 0.77, blue: 0),           // Green
   "1012": Color(red: 0, green: 0.45, blue: 0),              // Dark Green
   "1013": Color(red: 0, green: 0.35, blue: 0),              // Darker Green
   "1014": Color(red: 0, green: 0.73, blue: 0.56),           // Dark Turquoise
   "1015": Color(red: 0, green: 0.75, blue: 0.77),           // Turquoise
   "1016": Color(red: 0, green: 0.73, blue: 1),              // Light Blue
   "1017": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "1018": Color(red: 0, green: 0.38, blue: 1),              // Dark Blue
   "1019": Color(red: 0, green: 0.32, blue: 0.84),           // Deep Dark Blue
   "1020": Color(red: 0.2, green: 0, blue: 1),               // Purple-Blue
   "1021": Color(red: 0.29, green: 0, blue: 0.77),           // Dark Purple
   "1022": Color(red: 0.44, green: 0, blue: 0.77),           // Purple
   "1023": Color(red: 0.61, green: 0, blue: 0.77),           // Violet
   "1024": Color(red: 0.77, green: 0, blue: 0.76),           // Purple-Pink
   "1025": Color(red: 1, green: 0, blue: 0.98),              // Neon-Pink
   "1026": Color(red: 0.95, green: 0, blue: 0.67),           // Pink
   "1027": Color(red: 1, green: 0, blue: 0.44),              // Hot Pink
   "1028": Color(red: 0, green: 0, blue: 0),                 // Black
   "1029": Color(red: 1, green: 1, blue: 1),                 // White
   "1030": Color(red: 1, green: 0.65, blue: 0),              // Gold
   "1031": Color(red: 0.635, green: 0.7, blue: 0.698),       // Silver
   "1032": Color(red: 0.56, green: 0.33, blue: 0),           // Bronze
   
   "Music": Color(red: 1, green: 0, blue: 0),
   "Sports": Color(red: 1, green: 0.2, blue: 0),
   "Food & Drink":Color(red: 1, green: 0.35, blue: 0),
   "Nature": Color(red: 1, green: 0.65, blue: 0),
   "Entertainment": Color(red: 1, green: 0.78, blue: 0),
   "Humanities": Color(red: 0.62, green: 0.87, blue: 0),
   "Science":Color(red: 0.29, green: 0.77, blue: 0),
   "People":Color(red: 0, green: 0.45, blue: 0),
   "Brands":Color(red: 0, green: 0.73, blue: 0.56),
   "Hobbies & Activities":Color(red: 0, green: 0.62, blue: 0.95),
   "Technology":Color(red: 0, green: 0.32, blue: 0.84),
   "Art & Design":Color(red: 0.29, green: 0, blue: 0.77),
   "Vehicles":Color(red: 0.44, green: 0, blue: 0.77),
   "Culture":Color(red: 0.77, green: 0, blue: 0.76),
   "Occupation":Color(red: 0.95, green: 0, blue: 0.67),
   "Random": Color(red: 1, green: 0, blue: 0.44),
   
   "Artists & Bands": Color(red: 1, green: 0.35, blue: 0),
   "Songs": Color(red: 1, green: 0.72, blue: 0),
   "Albums": Color(red: 0.62, green: 0.87, blue: 0),
   "Instruments": Color(red: 0.29, green: 0.77, blue: 0),
   "Festivals":Color(red: 0, green: 0.35, blue: 0),
   "Band Members": Color(red: 0, green: 0.75, blue: 0.77),
   "Record Labels": Color(red: 0, green: 0.62, blue: 0.95),
   "Genres": Color(red: 0.44, green: 0, blue: 0.77),
   
   "Sport":Color(red: 1, green: 0, blue: 0),
   "Athletes":Color(red: 0.2, green: 0, blue: 1),
   "Leagues & Tournaments":Color(red: 1, green: 0.72, blue: 0),
   "Clubs & Teams":Color(red: 0.62, green: 0.87, blue: 0),
   "Football":Color(red: 0, green: 0, blue: 0),
   "Basketball":Color(red: 1, green: 0.2, blue: 0),
   "Australian Football":Color(red: 1, green: 0, blue: 0),
   "American Football":Color(red: 0.51, green: 0, blue: 0),
   "Tennis":Color(red: 0.62, green: 0.87, blue: 0),
   "Motorsport":Color(red: 1, green: 0.72, blue: 0),
   "Olympics":Color(red: 0.29, green: 0.77, blue: 0),
   "Stadiums & Venues":Color(red: 0.44, green: 0, blue: 0.77),
   "F1 Constructors":Color(red: 0, green: 0.62, blue: 0.95),
   "Coaches & Managers":Color(red: 0.95, green: 0, blue: 0.67),
   "Commentators":Color(red: 0, green: 0.45, blue: 0),
   "Rivalries":Color(red: 1, green: 0.72, blue: 0),
   "Mascots":Color(red: 0, green: 0.32, blue: 0.84),
   "Gym Machines":Color(red: 0.29, green: 0, blue: 0.77),
   "Gym Exercises":Color(red: 1, green: 0, blue: 0.44),
   
   "Food":Color(red: 0, green: 0.45, blue: 0),
   "Drinks":Color(red: 0.2, green: 0, blue: 1),
   "Fruit":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Vegetables": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Pizza":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Fast Food Chains": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Eggs": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Chocolate": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Cheese": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Dairy": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Pasta": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Soft Drinks": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Alcohol": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Breakfast Cereals": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Ice Cream": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Cocktails": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Sandwiches": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Desserts": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Spices": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Coffees": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Cuisines": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   
   "Animals":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Plants": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Mammals": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Birds": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Dogs": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Flowers": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Trees": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Fish": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Reptiles": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Cats": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Bugs": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Famous Animals": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   
   "Celebrities":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Movies": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Social Media": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Books": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Authors": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Quotes": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Streaming Services":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "TV Shows": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Gaming": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Board Games": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Card Games": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Comedians": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Memes": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   
   "Countries":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Politicians": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Landmarks": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Cities": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   
   "Models":Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Numbers": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Letters": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Shapes": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Statues": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Planets": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Relationships": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Emotions": Color(red: 0, green: 0.62, blue: 0.95),           // Blue
   "Red Flags": Color(red: 0.0, green: 0.0, blue: 0.0),
   
]

// Initial filter chips (editable order via order)
let defaultFilterChips: [FilterChip] = [
    FilterChip(
        name: "Music",
        icon: "music.note",
        synonyms: "songs, tracks, singles, compositions, tunes",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Artists & Bands",
                icon: "music.microphone",
                synonyms: "artists, bands, musicians, performers, acts",
                nameIndex: "Music-Artists-Albums",
                filter: "ItemCategory:Artist",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Songs",
                icon: "music.quarternote.3",
                synonyms: "songs, tracks, singles, hits, tunes",
                nameIndex: "Music-Tracks",
                filter: "ItemCategory:Track",
                children: [],
                available: true,
                order: 1
            ),
            FilterChip(
                name: "Albums",
                icon: "record.circle",
                synonyms: "albums, records, LPs, collections, discs",
                nameIndex: "Music-Artists-Albums",
                filter: "ItemCategory:Album",
                children: [],
                available: true,
                order: 2
            ),
            FilterChip(
                name: "Instruments",
                icon: "guitars.fill",
                synonyms: "instruments, gear, equipment, devices, tools",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 3
            ),
            FilterChip(
                name: "Festivals",
                icon: "hifispeaker.2.fill",
                synonyms: "festivals, concerts, events, carnivals, gatherings",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 4
            ),
            FilterChip(
                name: "Band Members",
                icon: "person.3.fill",
                synonyms: "members, musicians, artists, collaborators, contributors",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 5
            ),
            FilterChip(
                name: "Record Labels",
                icon: "tag.fill",
                synonyms: "labels, studios, companies, distributors, imprints",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 6
            ),
            FilterChip(
                name: "Genres",
                icon: "music.quarternote.3",
                synonyms: "genres, styles, categories, types, classifications",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 7
            )
        ],
        order: 0
    ),

    // MARK: – Sports
    FilterChip(
        name: "Sports",
        icon: "figure.archery",
        synonyms: "sports, games, athletics, competition, contests",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Sports",
                icon: "soccerball",
                synonyms: "sports, games, athletics, competition, events",
                nameIndex: "Sport",
                filter: "",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Athletes",
                icon: "figure.run",
                synonyms: "athletes, players, competitors, sportspeople, stars",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "All Athletes",
                        icon: "figure.run",
                        synonyms: "all athletes, full roster, everyone, complete list, competitors",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Football",
                        icon: "figure.indoor.soccer",
                        synonyms: "football, soccer, footy, association football, fútbol",
                        nameIndex: "Sports-Athletes",
                        filter: "ItemCategory:Soccer",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Basketball",
                        icon: "figure.basketball",
                        synonyms: "basketball, hoops, NBA, court ball, b-ball",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 2
                    ),
                    FilterChip(
                        name: "Tennis",
                        icon: "figure.tennis",
                        synonyms: "tennis, racquet sport, Wimbledon, Grand Slam, deuce",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 3
                    ),
                    FilterChip(
                        name: "American Football",
                        icon: "figure.american.football",
                        synonyms: "American football, gridiron, NFL, pigskin, football",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 4
                    ),
                    FilterChip(
                        name: "Australian Football",
                        icon: "figure.australian.football",
                        synonyms: "Australian rules football, AFL, footy, Aussie rules, league",
                        nameIndex: "Sports-Athletes",
                        filter: "ItemCategory:Australian Rules Football",
                        children: [],
                        available: true,
                        order: 5
                    ),
                    FilterChip(
                        name: "Motorsport",
                        icon: "steeringwheel",
                        synonyms: "motorsport, racing, F1, auto racing, motorsports",
                        nameIndex: "Sports-Athletes",
                        filter: "ItemCategory:Formula1",
                        children: [],
                        available: true,
                        order: 6
                    )
                ],
                available: true,
                order: 1
            ),
            FilterChip(
                name: "Leagues & Tournaments",
                icon: "trophy.fill",
                synonyms: "leagues, tournaments, competitions, championships, cups",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "All Leagues & Tournaments",
                        icon: "trophy.fill",
                        synonyms: "all leagues, all tournaments, seasons, championships, events",
                        nameIndex: "Sport",
                        filter: "ItemCategory:League",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Football",
                        icon: "soccerball",
                        synonyms: "football, soccer, footy, association football, fútbol",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 1
                    ),
                    FilterChip(
                        name: "Basketball",
                        icon: "basketball.fill",
                        synonyms: "basketball, hoops, NBA, court ball, b-ball",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 2
                    ),
                    FilterChip(
                        name: "Tennis",
                        icon: "tennisball.fill",
                        synonyms: "tennis, racquet sport, Wimbledon, Grand Slam, deuce",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 3
                    ),
                    FilterChip(
                        name: "American Football",
                        icon: "american.football.fill",
                        synonyms: "American football, gridiron, NFL, pigskin, football",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 4
                    ),
                    FilterChip(
                        name: "Australian Football",
                        icon: "australian.football.fill",
                        synonyms: "Australian rules football, AFL, footy, Aussie rules, league",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 5
                    ),
                    FilterChip(
                        name: "Motorsport",
                        icon: "steeringwheel",
                        synonyms: "motorsport, racing, F1, NASCAR, auto racing",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 6
                    )
                ],
                available: true,
                order: 2
            ),
            FilterChip(
                name: "Clubs & Teams",
                icon: "shield.lefthalf.filled",
                synonyms: "clubs, teams, organizations, franchises, squads",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "All Clubs & Teams",
                        icon: "shield.lefthalf.filled",
                        synonyms: "all clubs, all teams, organizations, franchises, squads",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Football",
                        icon: "soccerball",
                        synonyms: "football, soccer, footy, association football, fútbol",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:Football",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Basketball",
                        icon: "basketball.fill",
                        synonyms: "basketball, hoops, NBA, court ball, b-ball",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:Basketball",
                        children: [],
                        available: true,
                        order: 2
                    ),
                    FilterChip(
                        name: "American Football",
                        icon: "american.football.fill",
                        synonyms: "American football, gridiron, NFL, pigskin, football",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:American Football",
                        children: [],
                        available: true,
                        order: 3
                    ),
                    FilterChip(
                        name: "Australian Football",
                        icon: "australian.football.fill",
                        synonyms: "Australian rules football, AFL, footy, Aussie rules, league",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:Australian Rules Football",
                        children: [],
                        available: true,
                        order: 4
                    ),
                    FilterChip(
                        name: "F1 Constructors",
                        icon: "steeringwheel",
                        synonyms: "F1 constructors, racing teams, Formula 1, motorsport, teams",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:Formula 1",
                        children: [],
                        available: true,
                        order: 5
                    )
                ],
                available: true,
                order: 3
            ),
            FilterChip(
                name: "Stadiums & Venues",
                icon: "sportscourt.fill",
                synonyms: "stadiums, venues, arenas, fields, locations",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 4
            ),
            FilterChip(
                name: "Coaches & Managers",
                icon: "megaphone.fill",
                synonyms: "coaches, managers, trainers, mentors, instructors",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 5
            ),
            FilterChip(
                name: "Commentators",
                icon: "headset",
                synonyms: "commentators, announcers, broadcasters, analysts, hosts",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 6
            ),
            FilterChip(
                name: "Rivalries",
                icon: "oar.2.crossed",
                synonyms: "rivalries, feuds, matchups, competitions, duels",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 7
            ),
            FilterChip(
                name: "Mascots",
                icon: "figure.dance",
                synonyms: "mascots, symbols, emblems, characters, icons",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 8
            ),
            FilterChip(
                name: "Gym Machines",
                icon: "figure.indoor.cycle",
                synonyms: "machines, equipment, apparatus, gear, devices",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 9
            ),
            FilterChip(
                name: "Gym Exercises",
                icon: "figure.hand.cycling",
                synonyms: "exercises, workouts, routines, movements, drills",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 10
            )
        ],
        order: 1
    ),

    // MARK: – Food & Drink
    FilterChip(
        name: "Food & Drink",
        icon: "fork.knife",
        synonyms: "cuisine, beverages, meals, snacks, dining",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Food",
                icon: "fork.knife",
                synonyms: "food, cuisine, fare, dishes, meals",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "Fruit",
                        icon: "applelogo",
                        synonyms: "fruit, produce, berries, citrus, fruits",
                        nameIndex: "Food",
                        filter: "ItemCategory:Fruit",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Vegetables",
                        icon: "carrot.fill",
                        synonyms: "vegetables, veggies, greens, produce, plant foods",
                        nameIndex: "Food",
                        filter: "ItemCategory:Vegetable",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Pizza",
                        icon: "triangle.lefthalf.filled",
                        synonyms: "pizza, pies, slices, Italian food, pizzeria",
                        nameIndex: "Food",
                        filter: "ItemCategory:Pizza",
                        children: [],
                        available: true,
                        order: 2
                    ),
                    FilterChip(
                        name: "Fast Food Chains",
                        icon: "takeoutbag.and.cup.and.straw.fill",
                        synonyms: "fast food, chains, franchises, quick service, drive-thru",
                        nameIndex: "Logos",
                        filter: "ItemCategory:Fast Food Chain",
                        children: [],
                        available: true,
                        order: 3
                    ),
                    FilterChip(
                        name: "Eggs",
                        icon: "frying.pan.fill",
                        synonyms: "eggs, ova, breakfast, egg dishes, proteins",
                        nameIndex: "Food",
                        filter: "ItemCategory:Egg",
                        children: [],
                        available: true,
                        order: 4
                    ),
                    FilterChip(
                        name: "Chocolate",
                        icon: "square.grid.3x3.square",
                        synonyms: "chocolate, cocoa, candy, sweets, confections",
                        nameIndex: "Food",
                        filter: "ItemCategory:Chocolate",
                        children: [],
                        available: true,
                        order: 5
                    ),
                    FilterChip(
                        name: "Cheese",
                        icon: "drop.triangle.fill",
                        synonyms: "cheese, dairy, fromage, curd, cheese varieties",
                        nameIndex: "Food",
                        filter: "ItemCategory:Cheese",
                        children: [],
                        available: true,
                        order: 6
                    ),
                    FilterChip(
                        name: "Dairy",
                        icon: "waterbottle.fill",
                        synonyms: "dairy, milk products, cheese, butter, yogurt",
                        nameIndex: "Food",
                        filter: "ItemCategory:Dairy",
                        children: [],
                        available: true,
                        order: 7
                    ),
                    FilterChip(
                        name: "Pasta",
                        icon: "water.waves",
                        synonyms: "pasta, noodles, spaghetti, linguine, fettuccine",
                        nameIndex: "Food",
                        filter: "ItemCategory:Pasta",
                        children: [],
                        available: true,
                        order: 8
                    ),
                    FilterChip(
                        name: "Breakfast Cereals",
                        icon: "rectangle.portrait.righthalf.inset.filled",
                        synonyms: "cereal, breakfast cereals, grains, oats, granola",
                        nameIndex: "Food",
                        filter: "ItemCategory:Breakfast Cereal",
                        children: [],
                        available: true,
                        order: 9
                    ),
                    FilterChip(
                        name: "Ice Cream",
                        icon: "snowflake",
                        synonyms: "ice cream, gelato, sorbet, frozen dessert, treats",
                        nameIndex: "Food",
                        filter: "ItemCategory:Ice Cream Flavour",
                        children: [],
                        available: true,
                        order: 10
                    ),
                    FilterChip(
                        name: "Sandwiches",
                        icon: "square.3.layers.3d.top.filled",
                        synonyms: "sandwiches, subs, hoagies, toasties, rolls",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 11
                    ),
                    FilterChip(
                        name: "Desserts",
                        icon: "birthday.cake.fill",
                        synonyms: "desserts, sweets, pastries, cakes, treats",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 12
                    ),
                    FilterChip(
                        name: "Spices",
                        icon: "thermometer.sun.fill",
                        synonyms: "spices, seasonings, herbs, flavorings, condiments",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 13
                    ),
                    FilterChip(
                        name: "Cuisines",
                        icon: "globe",
                        synonyms: "cuisines, cooking styles, gastronomy, fare, regional food",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 14
                    )
                ],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Drinks",
                icon: "waterbottle.fill",
                synonyms: "drinks, beverages, refreshments, quenchers, libations",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "Soft Drinks",
                        icon: "bubbles.and.sparkles.fill",
                        synonyms: "soft drinks, sodas, pop, fizzy drinks, carbonated beverages",
                        nameIndex: "Food",
                        filter: "",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Alcohol",
                        icon: "flame.fill",
                        synonyms: "alcohol, spirits, booze, liquors, alcoholic beverages",
                        nameIndex: "",
                        filter: "",
                        children: [
                            FilterChip(
                                name: "All Alcohols",
                                icon: "beach.umbrella.fill",
                                synonyms: "spirits, liquors, alcohols, alcoholic drinks, beverages",
                                nameIndex: "Food",
                                filter: "ItemCategory:Cocktail OR ItemCategory:Alcohol",
                                children: [],
                                available: true,
                                order: 0
                            ),
                            FilterChip(
                                name: "Liquors & Liqueurs",
                                icon: "beach.umbrella.fill",
                                synonyms: "liquors, liqueurs, spirits, cordials, aperitifs",
                                nameIndex: "Food",
                                filter: "ItemDescription:Liqueur OR ItemDescription:Liquor",
                                children: [],
                                available: true,
                                order: 1
                            ),
                            FilterChip(
                                name: "Cocktails",
                                icon: "beach.umbrella.fill",
                                synonyms: "cocktails, mixed drinks, libations, concoctions, beverages",
                                nameIndex: "Food",
                                filter: "ItemCategory:Cocktail",
                                children: [],
                                available: true,
                                order: 2
                            ),
                            FilterChip(
                                name: "Premixes",
                                icon: "beach.umbrella.fill",
                                synonyms: "premixes, ready-made, pre-batched, mixed drinks, beverages",
                                nameIndex: "Food",
                                filter: "ItemDescription:Premix",
                                children: [],
                                available: true,
                                order: 3
                            )
                        ],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Coffees",
                        icon: "cup.and.saucer.fill",
                        synonyms: "coffee, espresso, lattes, cappuccinos, brews",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 2
                    )
                ],
                available: true,
                order: 1
            )
        ],
        order: 2
    ),

    // MARK: – Nature
    FilterChip(
        name: "Nature",
        icon: "leaf.fill",
        synonyms: "wildlife, environment, outdoors, ecology, earth",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Animals",
                icon: "pawprint.fill",
                synonyms: "animals, wildlife, creatures, fauna, beasts",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "Mammals",
                        icon: "hare.fill",
                        synonyms: "mammals, beasts, animals, vertebrates, warm-blooded",
                        nameIndex: "Animals",
                        filter: "ItemCategory:Mammal",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Birds",
                        icon: "bird.fill",
                        synonyms: "birds, avians, fowl, feathered, winged",
                        nameIndex: "Animals",
                        filter: "ItemCategory:Bird",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Dogs",
                        icon: "dog.fill",
                        synonyms: "dogs, canines, pups, hounds, pooches",
                        nameIndex: "Animals",
                        filter: "ItemDescription:Canis Lupus",
                        children: [],
                        available: true,
                        order: 2
                    ),
                    FilterChip(
                        name: "Fish",
                        icon: "fish.fill",
                        synonyms: "fish, aquatic, marine life, sea creatures, species",
                        nameIndex: "Animals",
                        filter: "ItemCategory:Fish",
                        children: [],
                        available: false,
                        order: 3
                    ),
                    FilterChip(
                        name: "Reptiles",
                        icon: "lizard.fill",
                        synonyms: "reptiles, scaly, cold-blooded, lizards, snakes",
                        nameIndex: "Animals",
                        filter: "ItemCategory:Reptile",
                        children: [],
                        available: false,
                        order: 4
                    ),
                    FilterChip(
                        name: "Cats",
                        icon: "cat.fill",
                        synonyms: "cats, felines, kitties, pussycats, whiskered",
                        nameIndex: "Animals",
                        filter: "ItemDescription:Felis Catus",
                        children: [],
                        available: true,
                        order: 5
                    ),
                    FilterChip(
                        name: "Bugs",
                        icon: "ladybug.fill",
                        synonyms: "bugs, insects, arthropods, critters, pests",
                        nameIndex: "Animals",
                        filter: "ItemCategory:Bug",
                        children: [],
                        available: false,
                        order: 6
                    ),
                    FilterChip(
                        name: "Famous Animals",
                        icon: "star.fill",
                        synonyms: "famous animals, star creatures, celebrities, icons, notable beasts",
                        nameIndex: "People",
                        filter: "ItemCategories.Subcategory:Animal",
                        children: [],
                        available: true,
                        order: 7
                    )
                ],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Plants",
                icon: "leaf.fill",
                synonyms: "plants, flora, greenery, vegetation, botany",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "Flowers",
                        icon: "microbe.fill",
                        synonyms: "flowers, blooms, blossoms, petals, flora",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 0
                    ),
                    FilterChip(
                        name: "Trees",
                        icon: "tree.fill",
                        synonyms: "trees, timber, woods, forestry, saplings",
                        nameIndex: "",
                        filter: "",
                        children: [],
                        available: false,
                        order: 1
                    )
                ],
                available: true,
                order: 1
            )
        ],
        order: 3
    ),

    // MARK: – Entertainment
    FilterChip(
        name: "Entertainment",
        icon: "star.fill",
        synonyms: "fun, leisure, media, amusement, recreation",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Celebrities",
                icon: "star.fill",
                synonyms: "celebrities, stars, icons, public figures, VIPs",
                nameIndex: "People",
                filter: "",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Movies",
                icon: "movieclapper",
                synonyms: "movies, films, cinema, flicks, motion pictures",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 1
            ),
            FilterChip(
                name: "Social Media",
                icon: "message.fill",
                synonyms: "social media, networks, platforms, online communities, feeds",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 2
            ),
            FilterChip(
                name: "Books",
                icon: "books.vertical.fill",
                synonyms: "books, novels, literature, texts, publications",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 3
            ),
            FilterChip(
                name: "Authors",
                icon: "book.fill",
                synonyms: "authors, writers, novelists, scribes, wordsmiths",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 4
            ),
            FilterChip(
                name: "Quotes",
                icon: "quote.opening",
                synonyms: "quotes, sayings, aphorisms, proverbs, citations",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 5
            ),
            FilterChip(
                name: "Streaming Services",
                icon: "play.rectangle.fill",
                synonyms: "streaming, OTT, platforms, providers, video services",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 6
            ),
            FilterChip(
                name: "TV Shows",
                icon: "tv.fill",
                synonyms: "TV shows, series, programs, broadcasts, sitcoms",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 7
            ),
            FilterChip(
                name: "Gaming",
                icon: "gamecontroller.fill",
                synonyms: "gaming, video games, esports, gameplay, consoles",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 8
            ),
            FilterChip(
                name: "Board Games",
                icon: "dice.fill",
                synonyms: "board games, tabletop, strategy, dice games, classics",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 9
            ),
            FilterChip(
                name: "Card Games",
                icon: "suit.club.fill",
                synonyms: "card games, playing cards, poker, blackjack, bridge",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 10
            ),
            FilterChip(
                name: "Comedians",
                icon: "music.microphone",
                synonyms: "comedians, comics, humorists, stand-ups, jokesters",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 11
            ),
            FilterChip(
                name: "Memes",
                icon: "camera.fill",
                synonyms: "memes, internet humor, viral images, jokes, online memes",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 12
            )
        ],
        order: 4
    ),

    // MARK: – Humanities
    FilterChip(
        name: "Humanities",
        icon: "building.columns.fill",
        synonyms: "culture, history, society, philosophy, arts",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Geography",
                icon: "globe.europe.africa.fill",
                synonyms: "geography, maps, regions, locations, places",
                nameIndex: "",
                filter: "",
                children: [
                    FilterChip(
                        name: "Countries",
                        icon: "globe.europe.africa.fill",
                        synonyms: "countries, nations, states, republics, territories",
                        nameIndex: "Geography",
                        filter: "ItemCategory:Country",
                        children: [],
                        available: true,
                        order: 0
                    ),
                    FilterChip(
                        name: "Continents",
                        icon: "globe",
                        synonyms: "continents, landmasses, regions, hemispheres, areas",
                        nameIndex: "Geography",
                        filter: "ItemCategory:Continent",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Landmarks",
                        icon: "building.columns.fill",
                        synonyms: "landmarks, monuments, sites, attractions, icons",
                        nameIndex: "Geography",
                        filter: "ItemCategory:Landmark",
                        children: [],
                        available: false,
                        order: 2
                    ),
                    FilterChip(
                        name: "Cities",
                        icon: "building.2.fill",
                        synonyms: "cities, metropolises, towns, municipalities, urban areas",
                        nameIndex: "Geography",
                        filter: "ItemCategory:City",
                        children: [],
                        available: true,
                        order: 3
                    )
                ],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Politicians",
                icon: "megaphone.fill",
                synonyms: "politicians, lawmakers, officials, legislators, statespeople",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 1
            ),
            FilterChip(
                name: "History",
                icon: "building.columns.fill",
                synonyms: "history, past, heritage, chronology, record",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 2
            )
        ],
        order: 5
    ),

    // MARK: – Science
    FilterChip(
        name: "Science",
        icon: "atom",
        synonyms: "research, discovery, technology, experiments, knowledge",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Planets",
                icon: "circles.hexagonpath.fill",
                synonyms: "planets, worlds, celestial bodies, orbs, spheres",
                nameIndex: "Science",
                filter: "ItemCategory:Planet AND ItemCategory:'Dwarf Planet'",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Elements",
                icon: "bubbles.and.sparkles.fill",
                synonyms: "elements, chemicals, atoms, compounds, substances",
                nameIndex: "Science",
                filter: "ItemCategory:Element",
                children: [],
                available: true,
                order: 1
            )
        ],
        order: 6
    ),

    // MARK: – People
    FilterChip(
        name: "People",
        icon: "figure.arms.open",
        synonyms: "individuals, persons, humans, figures, populace",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "All People",
                icon: "figure.stand.dress.line.vertical.figure",
                synonyms: "people, persons, individuals, humans, populace",
                nameIndex: "People",
                filter: "",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Celebrities",
                icon: "star.fill",
                synonyms: "celebrities, stars, icons, public figures, VIPs",
                nameIndex: "People",
                filter: "",
                children: [],
                available: true,
                order: 1
            ),
            FilterChip(
                name: "Content Creators",
                icon: "play.square.fill",
                synonyms: "creators, influencers, producers, streamers, bloggers",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:'Content Creator'",
                children: [],
                available: true,
                order: 2
            ),
            FilterChip(
                name: "Actors",
                icon: "movieclapper.fill",
                synonyms: "actors, performers, thespians, cast, artistes",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Media",
                children: [],
                available: true,
                order: 3
            ),
            FilterChip(
                name: "Musicians",
                icon: "music.microphone",
                synonyms: "musicians, artists, instrumentalists, singers, bands",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Music",
                children: [],
                available: true,
                order: 4
            ),
            FilterChip(
                name: "World Leaders",
                icon: "person.bust.fill",
                synonyms: "leaders, presidents, prime ministers, officials, heads of state",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:'World Leader'",
                children: [],
                available: true,
                order: 5
            ),
            FilterChip(
                name: "Models",
                icon: "camera.fill",
                synonyms: "models, mannequins, supermodels, figures, replicas",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Model",
                children: [],
                available: true,
                order: 6
            ),
            FilterChip(
                name: "Comedians",
                icon: "theatermasks.fill",
                synonyms: "comedians, comics, humorists, jokesters, stand-ups",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Comedian",
                children: [],
                available: true,
                order: 7
            ),
            FilterChip(
                name: "Entrepreneurs",
                icon: "banknote.fill",
                synonyms: "entrepreneurs, founders, business owners, innovators, startups",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Entrepreneur",
                children: [],
                available: true,
                order: 8
            ),
            FilterChip(
                name: "Chefs",
                icon: "frying.pan.fill",
                synonyms: "chefs, cooks, culinarians, sous-chefs, gastronome",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Chef",
                children: [],
                available: true,
                order: 9
            ),
            FilterChip(
                name: "Activists",
                icon: "megaphone.fill",
                synonyms: "activists, advocates, campaigners, protesters, reformers",
                nameIndex: "People",
                filter: "ItemCategories.Subcategory:Activist",
                children: [],
                available: true,
                order: 10
            )
        ],
        order: 6
    ),

    // MARK: – Brands
    FilterChip(
        name: "Brands",
        icon: "shield.righthalf.filled",
        synonyms: "labels, companies, trademarks, logos, manufacturers",
        nameIndex: "Logos",
        filter: "",
        children: [],
        available: false,
        order: 7
    ),

    // MARK: – Hobbies & Activities
    FilterChip(
        name: "Hobbies & Activities",
        icon: "figure.fishing",
        synonyms: "pastimes, interests, pursuits, leisure, crafts",
        nameIndex: "",
        filter: "",
        children: [],
        available: false,
        order: 8
    ),

    // MARK: – Technology & Math
    FilterChip(
        name: "Technology & Math",
        icon: "laptopcomputer.and.iphone",
        synonyms: "technology, mathematics, computing, engineering, science",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Programming Language",
                icon: "apple.terminal.fill",
                synonyms: "programming languages, code, syntax, compilers, languages",
                nameIndex: "Other",
                filter: "ItemCategory: 'Programming Language'",
                children: [],
                available: true,
                order: 10
            ),
            FilterChip(
                name: "Letters",
                icon: "a.circle.fill",
                synonyms: "letters, alphabets, characters, glyphs, symbols",
                nameIndex: "Other",
                filter: "ItemCategory:Letter",
                children: [],
                available: true,
                order: 10
            ),
            FilterChip(
                name: "Numbers",
                icon: "8.circle.fill",
                synonyms: "numbers, digits, numerals, figures, counts",
                nameIndex: "Other",
                filter: "ItemCategory:Number",
                children: [],
                available: true,
                order: 10
            ),
            FilterChip(
                name: "Roman Numerals",
                icon: "circle.fill.ar",
                synonyms: "Roman numerals, Latin numerals, ancient numbers, numerics, glyphs",
                nameIndex: "Other",
                filter: "ItemCategory:'Roman Numeral'",
                children: [],
                available: true,
                order: 10
            )
        ],
        order: 9
    ),

    // MARK: – Art & Design
    FilterChip(
        name: "Art & Design",
        icon: "paintbrush.pointed.fill",
        synonyms: "art, design, creativity, graphics, illustration",
        nameIndex: "",
        filter: "",
        children: [],
        available: false,
        order: 10
    ),

    // MARK: – Vehicles
    FilterChip(
        name: "Vehicles",
        icon: "car.side.fill",
        synonyms: "cars, transport, automobiles, vehicles, machines",
        nameIndex: "",
        filter: "",
        children: [],
        available: false,
        order: 11
    ),

    // MARK: – Culture
    FilterChip(
        name: "Culture",
        icon: "theatermask.and.paintbrush.fill",
        synonyms: "traditions, customs, lifestyle, heritage, society",
        nameIndex: "",
        filter: "",
        children: [],
        available: false,
        order: 12
    ),

    // MARK: – Occupation
    FilterChip(
        name: "Occupation",
        icon: "briefcase.fill",
        synonyms: "jobs, careers, professions, vocations, work",
        nameIndex: "",
        filter: "",
        children: [],
        available: false,
        order: 13
    ),

    // MARK: – Random
    FilterChip(
        name: "Random",
        icon: "dice.fill",
        synonyms: "miscellaneous, varied, assorted, odds & ends, hodgepodge",
        nameIndex: "",
        filter: "",
        children: [
            FilterChip(
                name: "Models",
                icon: "camera.fill",
                synonyms: "models, mannequins, replicas, prototypes, figures",
                nameIndex: "",
                filter: "",
                children: [],
                available: true,
                order: 0
            ),
            FilterChip(
                name: "Numbers",
                icon: "1.square.fill",
                synonyms: "numbers, digits, numerals, figures, counts",
                nameIndex: "Other",
                filter: "ItemCategory:Number",
                children: [],
                available: true,
                order: 1
            ),
            FilterChip(
                name: "Letters",
                icon: "a.square.fill",
                synonyms: "letters, alphabets, characters, glyphs, symbols",
                nameIndex: "Other",
                filter: "ItemCategory:Letter",
                children: [],
                available: true,
                order: 2
            ),
            FilterChip(
                name: "Shapes",
                icon: "triangle.fill",
                synonyms: "shapes, forms, figures, outlines, geometries",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 3
            ),
            FilterChip(
                name: "Statues",
                icon: "figure.stand",
                synonyms: "statues, sculptures, monuments, effigies, figures",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 4
            ),
            FilterChip(
                name: "Relationships",
                icon: "heart.fill",
                synonyms: "relationships, connections, bonds, associations, ties",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 5
            ),
            FilterChip(
                name: "Emotions",
                icon: "face.smiling",
                synonyms: "emotions, feelings, sentiments, moods, affects",
                nameIndex: "",
                filter: "",
                children: [],
                available: false,
                order: 6
            )
        ],
        order: 14
    )
]
// MARK: - FilterChip Button View
struct FilterChipButtonView: View {
    let chip: FilterChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let isDisabled = !chip.available

        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: chip.icon)
                    .foregroundColor(isDisabled ? .gray : (isSelected ? .white : (filterChipIconColors[chip.name] ?? .black)))
                    .padding(.trailing, 4)
                Text(chip.name)
                    .font(.body)
                    .foregroundColor(isDisabled ? .gray : (isSelected ? .white : (filterChipIconColors[chip.name] ?? .black)))
                    .fontWeight(.bold)
            }
            .padding(8)
            .background(isSelected ? (filterChipIconColors[chip.name] ?? .blue) : Color.white)
            .cornerRadius(8)
            .shadow(color: .gray.opacity(0.5), radius: isSelected ? 6 : 3)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}


// MARK: - FilterChip Picker View
struct FilterChipPickerView: View {
    @State private var addItemsOpen: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedRankoItems: [AlgoliaRankoItem]

    @State private var chipStack: [FilterChip] = []
    @State private var currentChips: [FilterChip] = defaultFilterChips.sorted { $0.order < $1.order }

    var body: some View {
        VStack {
            // Selected chips row
            if !chipStack.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chipStack) { chip in
                            FilterChipButtonView(chip: chip, isSelected: true) {
                                backTo(chip)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                .padding(.top, 15)
            }
            
            // Current chips flow
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(currentChips.sorted(by: { $0.order < $1.order })) { chip in
                        FilterChipButtonView(chip: chip, isSelected: false) {
                            chipTapped(chip)
                        }
                        .transition(.opacity)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5)
            
            Spacer()
            
            // Done Button
            Button(action: {
                if let last = chipStack.last, last.children.isEmpty, last.available {
                    let path = chipStack.map(\..name).dropLast()
                    print("Path: \(path)")
                    print("Last Chip Selected: \(last.name)")
                    print("Set Index: \(last.nameIndex)")
                    print("Set Filters: \(last.filter)")
                    addItemsOpen.toggle()
                }
            }) {
                Text((chipStack.last?.available == false) ? "Coming Soon..." : "Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor((chipStack.last?.available == false) ? .gray : .white)
                    .background((chipStack.last?.children.isEmpty ?? false) && (chipStack.last?.available ?? false) ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!(chipStack.last?.children.isEmpty ?? false) || (chipStack.last?.available == false))
            .padding(.horizontal)
            .padding(.bottom)
        }
        .animation(.default, value: chipStack)
        .animation(.default, value: currentChips)
        .systemTrayView($addItemsOpen) {
            if let last = chipStack.last, last.children.isEmpty {
                AddItemView(filterChip: last, existingCount: selectedRankoItems.count) { newItems in
                    // newItems is now [AlgoliaRankoItem]
                    selectedRankoItems.append(contentsOf: newItems)
                    selectedRankoItems.sort { $0.rank < $1.rank }
                    dismiss()
                }
            } else {
                // fallback if nothing selected yet
                AddItemView(filterChip: defaultFilterChips.first!, existingCount: selectedRankoItems.count) { newItems in
                    selectedRankoItems.append(contentsOf: newItems)
                    selectedRankoItems.sort { $0.rank < $1.rank }
                    dismiss()
                }
            }
        }
        .presentationDragIndicator(.automatic)
    }

   private func chipTapped(_ chip: FilterChip) {
       withAnimation {
           // Always push new level on tap
           chipStack.append(chip)
           currentChips = chip.children.sorted { $0.order < $1.order }
       }
   }

   private func backTo(_ chip: FilterChip) {
       guard let index = chipStack.firstIndex(of: chip) else { return }
       withAnimation {
           if index == 0 {
               // tapped root: reset
               chipStack.removeAll()
               currentChips = defaultFilterChips.sorted { $0.order < $1.order }
           } else if index == chipStack.count - 1 {
               // tapped last: go up one level
               chipStack.removeLast()
               if let parent = chipStack.last {
                   currentChips = parent.children.sorted { $0.order < $1.order }
               } else {
                   currentChips = defaultFilterChips.sorted { $0.order < $1.order }
               }
           } else {
               // tapped ancestor: jump to that level
               chipStack = Array(chipStack.prefix(upTo: index + 1))
               currentChips = chip.children.sorted { $0.order < $1.order }
           }
       }
   }
}

extension FilterChip {
    /// Recursively searches "chips" (and all their children) for one whose "name" matches.
    static func icon(named target: String, in chips: [FilterChip]) -> String? {
        for chip in chips {
            if chip.name.caseInsensitiveCompare(target) == .orderedSame {
                return chip.icon
            }
            // descend:
            if let found = icon(named: target, in: chip.children) {
                return found
            }
        }
        return nil
    }
}
