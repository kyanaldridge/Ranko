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

    "1001": Color(hex: 0x680000),     // Blood Red
    "1002": Color(hex: 0x9F0606),     // Penn Red
    "1003": Color(hex: 0xC90F0F),     // Engineering Orange
    "1004": Color(hex: 0xF21818),     // Red
    "1005": Color(hex: 0xF63413),     // Scarlet
    "1006": Color(hex: 0xF9500D),     // Tangelo
    "1007": Color(hex: 0xFC6C08),     // Pumpkin
    "1008": Color(hex: 0xFE7A05),     // Safety Orange
    "1009": Color(hex: 0xFFA503),     // Orange
    "1010": Color(hex: 0xFFBA02),     // Selective Yellow
    "1011": Color(hex: 0xFFCF00),     // Jonquil
    "1012": Color(hex: 0xDFD701),     // Citrine
    "1013": Color(hex: 0xBEDF01),     // Pear
    "1014": Color(hex: 0xACCA01),     // Yellow Green
    "1015": Color(hex: 0x9AB501),     // Apple Green Light
    "1016": Color(hex: 0x769801),     // Apple Green Dark
    "1017": Color(hex: 0x5B8200),     // Avocado
    "1018": Color(hex: 0x459440),     // Forest Green
    "1019": Color(hex: 0x3A9D60),     // Shamrock Green
    "1020": Color(hex: 0x2FA580),     // Jungle Green
    "1021": Color(hex: 0x24AEA0),     // Keppel
    "1022": Color(hex: 0x19B7C0),     // Verdigris
    "1023": Color(hex: 0x03C8FF),     // Vivid Sky Blue
    "1024": Color(hex: 0x03B0E2),     // Process Cyan
    "1025": Color(hex: 0x0394C0),     // Blue Green
    "1026": Color(hex: 0x03789E),     // Cerulean
    "1027": Color(hex: 0x035F80),     // Lapis Lazuli
    "1028": Color(hex: 0x03539C),     // Polynesian Blue
    "1029": Color(hex: 0x0248B1),     // Cobalt Blue
    "1030": Color(hex: 0x0243BE),     // Violet Blue
    "1031": Color(hex: 0x013DCA),     // Persian Blue
    "1032": Color(hex: 0x0031E2),     // Palatinate Blue
    "1033": Color(hex: 0x1025C7),     // Medium Blue
    "1034": Color(hex: 0x1F19AC),     // Zaffre
    "1035": Color(hex: 0x2E0D91),     // Ultramarine
    "1036": Color(hex: 0x360784),     // Persian Indigo
    "1037": Color(hex: 0x3D0076),     // Indigo
    "1038": Color(hex: 0x4D007C),     // Light Indigo
    "1039": Color(hex: 0x5C0082),     // Lightest Indigo
    "1040": Color(hex: 0x7B008E),     // Purple
    "1041": Color(hex: 0xA000A0),     // Mauveine
    "1042": Color(hex: 0xC800B8),     // Steel Pink
    "1043": Color(hex: 0xF000D0),     // Hot Magenta
    "1044": Color(hex: 0xB60077),     // Red Violet
    "1045": Color(hex: 0xA20059),     // Murrey
    "1046": Color(hex: 0x8F003B),     // Claret
    "1047": Color(hex: 0x7B001E),     // Burgundy
   
    "Music": Color(hex: 0xA30000),
    "Sports": Color(hex: 0xE60001),
    "Food & Drink": Color(hex: 0xFB6901),
    "Nature": Color(hex: 0xFFA600),
    "Entertainment": Color(hex: 0xFFC700),
    "Humanities": Color(hex: 0x77C300),
    "Science": Color(hex: 0x4FA800),
    "People": Color(hex: 0x148000),
    "Brands": Color(hex: 0x00BA8F),
    "Hobbies & Activities": Color(hex: 0x009EF2),
    "Technology & Math": Color(hex: 0x0152D6),
    "Art & Design": Color(hex: 0x4A00C4),
    "Vehicles": Color(hex: 0x7000C4),
    "Culture": Color(hex: 0xC400C2),
    "Occupation": Color(hex: 0xF200AB),
    "Random": Color(hex: 0xFF0070),
    
//    "Music": Color(hex: 0xE60001),
//    "Sports": Color(hex: 0xE60001),
//    "Food & Drink": Color(hex: 0xE60001),
//    "Nature": Color(red: 1, green: 0.65, blue: 0),
//    "Entertainment": Color(red: 1, green: 0.78, blue: 0),
//    "Humanities": Color(red: 0.62, green: 0.87, blue: 0),
//   "Science": Color(red: 0.29, green: 0.77, blue: 0),
//   "People": Color(red: 0, green: 0.45, blue: 0),
//   "Brands": Color(red: 0, green: 0.73, blue: 0.56),
//   "Hobbies & Activities": Color(red: 0, green: 0.62, blue: 0.95),
//   "Technology & Math": Color(red: 0, green: 0.32, blue: 0.84),
//   "Art & Design": Color(red: 0.29, green: 0, blue: 0.77),
//   "Vehicles": Color(red: 0.44, green: 0, blue: 0.77),
//   "Culture": Color(red: 0.77, green: 0, blue: 0.76),
//   "Occupation": Color(red: 0.95, green: 0, blue: 0.67),
//   "Random": Color(red: 1, green: 0, blue: 0.44),
   
   "Artists & Bands": Color(red: 1, green: 0.35, blue: 0),
   "Songs": Color(red: 1, green: 0.72, blue: 0),
   "Albums": Color(red: 0.62, green: 0.87, blue: 0),
   "Instruments": Color(red: 0.29, green: 0.77, blue: 0),
   "Festivals": Color(red: 0, green: 0.35, blue: 0),
   "Band Members": Color(red: 0, green: 0.75, blue: 0.77),
   "Record Labels": Color(red: 0, green: 0.62, blue: 0.95),
   "Genres": Color(red: 0.44, green: 0, blue: 0.77),
   
   "Sport": Color(red: 1, green: 0, blue: 0),
   "Athletes": Color(red: 0.2, green: 0, blue: 1),
   "Leagues & Tournaments": Color(red: 1, green: 0.72, blue: 0),
   "Clubs & Teams": Color(red: 0.62, green: 0.87, blue: 0),
   "Football": Color(red: 0, green: 0, blue: 0),
   "Basketball": Color(red: 1, green: 0.2, blue: 0),
   "Australian Football": Color(red: 1, green: 0, blue: 0),
   "American Football": Color(red: 0.51, green: 0, blue: 0),
   "Tennis": Color(red: 0.62, green: 0.87, blue: 0),
   "Motorsport": Color(red: 1, green: 0.72, blue: 0),
   "Olympics": Color(red: 0.29, green: 0.77, blue: 0),
   "Stadiums & Venues": Color(red: 0.44, green: 0, blue: 0.77),
   "F1 Constructors": Color(red: 0, green: 0.62, blue: 0.95),
   "Coaches & Managers": Color(red: 0.95, green: 0, blue: 0.67),
   "Commentators": Color(red: 0, green: 0.45, blue: 0),
   "Rivalries": Color(red: 1, green: 0.72, blue: 0),
   "Mascots": Color(red: 0, green: 0.32, blue: 0.84),
   "Gym Machines": Color(red: 0.29, green: 0, blue: 0.77),
   "Gym Exercises": Color(red: 1, green: 0, blue: 0.44),
   
   "Food": Color(red: 0.29, green: 0.77, blue: 0),
   "Drinks": Color(red: 0, green: 0.73, blue: 1),
   "Fruit": Color(red: 0, green: 0.62, blue: 0.95),
   "Vegetables": Color(red: 0, green: 0.62, blue: 0.95),           
   "Pizza": Color(red: 0, green: 0.62, blue: 0.95),           
   "Fast Food Chains": Color(red: 0, green: 0.62, blue: 0.95),           
   "Eggs": Color(red: 0, green: 0.62, blue: 0.95),           
   "Chocolate": Color(red: 0, green: 0.62, blue: 0.95),           
   "Cheese": Color(red: 0, green: 0.62, blue: 0.95),           
   "Dairy": Color(red: 0, green: 0.62, blue: 0.95),           
   "Pasta": Color(red: 0, green: 0.62, blue: 0.95),           
   "Soft Drinks": Color(red: 0, green: 0.62, blue: 0.95),           
   "Alcohol": Color(red: 0, green: 0.62, blue: 0.95),           
   "Breakfast Cereals": Color(red: 0, green: 0.62, blue: 0.95),           
   "Ice Cream": Color(red: 0, green: 0.62, blue: 0.95),           
   "Cocktails": Color(red: 0, green: 0.62, blue: 0.95),           
   "Sandwiches": Color(red: 0, green: 0.62, blue: 0.95),           
   "Desserts": Color(red: 0, green: 0.62, blue: 0.95),           
   "Spices": Color(red: 0, green: 0.62, blue: 0.95),           
   "Coffees": Color(red: 0, green: 0.62, blue: 0.95),           
   "Cuisines": Color(red: 0, green: 0.62, blue: 0.95),           
   
   "Animals": Color(red: 0, green: 0.62, blue: 0.95),           
   "Plants": Color(red: 0, green: 0.62, blue: 0.95),           
   "Mammals": Color(red: 0, green: 0.62, blue: 0.95),           
   "Birds": Color(red: 0, green: 0.62, blue: 0.95),           
   "Dogs": Color(red: 0, green: 0.62, blue: 0.95),           
   "Flowers": Color(red: 0, green: 0.62, blue: 0.95),           
   "Trees": Color(red: 0, green: 0.62, blue: 0.95),           
   "Fish": Color(red: 0, green: 0.62, blue: 0.95),           
   "Reptiles": Color(red: 0, green: 0.62, blue: 0.95),           
   "Cats": Color(red: 0, green: 0.62, blue: 0.95),           
   "Bugs": Color(red: 0, green: 0.62, blue: 0.95),           
   "Famous Animals": Color(red: 0, green: 0.62, blue: 0.95),           
   
   "Celebrities": Color(red: 0, green: 0.62, blue: 0.95),           
   "Movies": Color(red: 0, green: 0.62, blue: 0.95),           
   "Social Media": Color(red: 0, green: 0.62, blue: 0.95),           
   "Books": Color(red: 0, green: 0.62, blue: 0.95),           
   "Authors": Color(red: 0, green: 0.62, blue: 0.95),           
   "Quotes": Color(red: 0, green: 0.62, blue: 0.95),           
   "Streaming Services": Color(red: 0, green: 0.62, blue: 0.95),           
   "TV Shows": Color(red: 0, green: 0.62, blue: 0.95),           
   "Gaming": Color(red: 0, green: 0.62, blue: 0.95),           
   "Board Games": Color(red: 0, green: 0.62, blue: 0.95),           
   "Card Games": Color(red: 0, green: 0.62, blue: 0.95),           
   "Comedians": Color(red: 0, green: 0.62, blue: 0.95),           
   "Memes": Color(red: 0, green: 0.62, blue: 0.95),           
   
   "Countries": Color(red: 0, green: 0.62, blue: 0.95),           
   "Politicians": Color(red: 0, green: 0.62, blue: 0.95),           
   "Landmarks": Color(red: 0, green: 0.62, blue: 0.95),           
   "Cities": Color(red: 0, green: 0.62, blue: 0.95),           
   
   "Models": Color(red: 0, green: 0.62, blue: 0.95),           
   "Numbers": Color(red: 0, green: 0.62, blue: 0.95),           
   "Letters": Color(red: 0, green: 0.62, blue: 0.95),           
   "Shapes": Color(red: 0, green: 0.62, blue: 0.95),           
   "Statues": Color(red: 0, green: 0.62, blue: 0.95),           
   "Planets": Color(red: 0, green: 0.62, blue: 0.95),           
   "Relationships": Color(red: 0, green: 0.62, blue: 0.95),           
   "Emotions": Color(red: 0, green: 0.62, blue: 0.95),           
   "Red Flags": Color(red: 0.0, green: 0.0, blue: 0.0),
   
]

// Initial filter chips (editable order via order)
var defaultFilterChips: [FilterChip] = [
//    FilterChip(name: "1001", icon: "music.note", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 1),
//    FilterChip(name: "1002", icon: "figure.archery", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 2),
//    FilterChip(name: "1003", icon: "fork.knife", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 3),
//    FilterChip(name: "1004", icon: "leaf.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 4),
//    FilterChip(name: "1005", icon: "star.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 5),
//    FilterChip(name: "1006", icon: "building.columns.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 6),
//    FilterChip(name: "1007", icon: "atom", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 7),
//    FilterChip(name: "1008", icon: "figure.arms.open", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 8),
//    FilterChip(name: "1009", icon: "shield.righthalf.filled", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 9),
//    FilterChip(name: "1010", icon: "figure.fishing", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 10),
//    FilterChip(name: "1011", icon: "laptopcomputer.and.iphone", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 11),
//    FilterChip(name: "1012", icon: "paintbrush.pointed.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 12),
//    FilterChip(name: "1013", icon: "car.side.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 13),
//    FilterChip(name: "1014", icon: "theatermask.and.paintbrush.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 14),
//    FilterChip(name: "1015", icon: "briefcase.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 15),
//    FilterChip(name: "1016", icon: "dice.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 16),
//    FilterChip(name: "1017", icon: "music.note", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 17),
//    FilterChip(name: "1018", icon: "figure.archery", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 18),
//    FilterChip(name: "1019", icon: "fork.knife", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 19),
//    FilterChip(name: "1020", icon: "leaf.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 20),
//    FilterChip(name: "1021", icon: "star.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 21),
//    FilterChip(name: "1022", icon: "building.columns.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 22),
//    FilterChip(name: "1023", icon: "atom", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 23),
//    FilterChip(name: "1024", icon: "figure.arms.open", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 24),
//    FilterChip(name: "1025", icon: "shield.righthalf.filled", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 25),
//    FilterChip(name: "1026", icon: "figure.fishing", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 26),
//    FilterChip(name: "1027", icon: "laptopcomputer.and.iphone", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 27),
//    FilterChip(name: "1028", icon: "paintbrush.pointed.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 28),
//    FilterChip(name: "1029", icon: "car.side.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 29),
//    FilterChip(name: "1030", icon: "theatermask.and.paintbrush.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 30),
//    FilterChip(name: "1031", icon: "briefcase.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 31),
//    FilterChip(name: "1032", icon: "dice.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 32),
//    FilterChip(name: "1033", icon: "music.note", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 33),
//    FilterChip(name: "1034", icon: "figure.archery", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 34),
//    FilterChip(name: "1035", icon: "fork.knife", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 35),
//    FilterChip(name: "1036", icon: "leaf.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 36),
//    FilterChip(name: "1037", icon: "star.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 37),
//    FilterChip(name: "1038", icon: "building.columns.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 38),
//    FilterChip(name: "1039", icon: "atom", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 39),
//    FilterChip(name: "1040", icon: "figure.arms.open", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 40),
//    FilterChip(name: "1041", icon: "shield.righthalf.filled", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 41),
//    FilterChip(name: "1042", icon: "figure.fishing", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 42),
//    FilterChip(name: "1043", icon: "laptopcomputer.and.iphone", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 43),
//    FilterChip(name: "1044", icon: "paintbrush.pointed.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 44),
//    FilterChip(name: "1045", icon: "car.side.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 45),
//    FilterChip(name: "1046", icon: "theatermask.and.paintbrush.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 46),
//    FilterChip(name: "1047", icon: "briefcase.fill", synonyms: "", nameIndex: "", filter: "", children: [], available: true, order: 47),
    
    
    
    
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
                        name: "Footballers",
                        icon: "figure.indoor.soccer",
                        synonyms: "football, soccer, footy, association football, fútbol",
                        nameIndex: "Sports-Athletes",
                        filter: "ItemCategory:Soccer",
                        children: [],
                        available: true,
                        order: 1
                    ),
                    FilterChip(
                        name: "Basketballers",
                        icon: "figure.basketball",
                        synonyms: "basketball, hoops, NBA, court ball, b-ball",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 2
                    ),
                    FilterChip(
                        name: "Tennis Players",
                        icon: "figure.tennis",
                        synonyms: "tennis, racquet sport, Wimbledon, Grand Slam, deuce",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 3
                    ),
                    FilterChip(
                        name: "American Footballers",
                        icon: "figure.american.football",
                        synonyms: "American football, gridiron, NFL, pigskin, football",
                        nameIndex: "Sports-Athletes",
                        filter: "",
                        children: [],
                        available: false,
                        order: 4
                    ),
                    FilterChip(
                        name: "Australian Footballers",
                        icon: "figure.australian.football",
                        synonyms: "Australian rules football, AFL, footy, Aussie rules, league",
                        nameIndex: "Sports-Athletes",
                        filter: "ItemCategory:'Australian Rules Football'",
                        children: [],
                        available: true,
                        order: 5
                    ),
                    FilterChip(
                        name: "Motorsport Drivers",
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
                        filter: "ItemCategory:Club AND ItemCategories.Sport:'American Football'",
                        children: [],
                        available: true,
                        order: 3
                    ),
                    FilterChip(
                        name: "Australian Football",
                        icon: "australian.football.fill",
                        synonyms: "Australian rules football, AFL, footy, Aussie rules, league",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:'Australian Rules Football'",
                        children: [],
                        available: true,
                        order: 4
                    ),
                    FilterChip(
                        name: "F1 Constructors",
                        icon: "steeringwheel",
                        synonyms: "F1 constructors, racing teams, Formula 1, motorsport, teams",
                        nameIndex: "Sport",
                        filter: "ItemCategory:Club AND ItemCategories.Sport:'Formula 1'",
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
                        filter: "ItemCategory:'Fast Food Chain'",
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
                        filter: "ItemCategory:'Breakfast Cereal'",
                        children: [],
                        available: true,
                        order: 9
                    ),
                    FilterChip(
                        name: "Ice Cream",
                        icon: "snowflake",
                        synonyms: "ice cream, gelato, sorbet, frozen dessert, treats",
                        nameIndex: "Food",
                        filter: "ItemCategory:'Ice Cream Flavour'",
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
                        filter: "ItemDescription:'Canis Lupus'",
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
                        filter: "ItemDescription:'Felis Catus'",
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
                filter: "ItemCategory:Planet OR ItemCategory:'Dwarf Planet'", //CHANGED
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
        available: true,
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
        available: true,
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
        available: true,
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
        available: true,
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
        available: true,
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
        available: true,
        order: 13
    ),

    // MARK: – Random
    FilterChip(
        name: "Random",
        icon: "dice.fill",
        synonyms: "miscellaneous, varied, assorted, odds & ends, hodgepodge",
        nameIndex: "",
        filter: "",
        children: [],
        available: true,
        order: 14
    )
]
// MARK: - FilterChip Button View
struct FilterChipButtonViewHorizontal: View {
    let chip: FilterChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let isDisabled = !chip.available

        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: chip.icon)
                    .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                    .padding(.trailing, 4)
                Text(chip.name)
                    .font(.body)
                    .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                    .fontWeight(.bold)
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .fontWeight(.black)
                        .padding(.leading, 8)
                }
            }
            .padding(8)
            .background(isDisabled ? .gray : (filterChipIconColors[chip.name] ?? .blue))
            .cornerRadius(8)
            .shadow(color: .gray.opacity(0.6), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

struct FilterChipButtonViewVertical: View {
    let chip: FilterChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let isDisabled = !chip.available

        Button(action: action) {
            if isSelected {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        Image(systemName: chip.icon)
                            .font(.system(size: 20, weight: .black, design: .default))
                            .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                            .frame(width: 20, height: 20)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 25)
                        Text(chip.name)
                            .font(.custom("Nunito-Black", size: 14))
                            .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                            .padding(.horizontal, 8)
                    }
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black, design: .default))
                        .foregroundColor(.white)
                        .fontWeight(.black)
                }
                .padding(8)
                .background(isDisabled ? .gray : (filterChipIconColors[chip.name] ?? .blue))
                .brightness(-0.10)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.6), radius: 3, x: 0, y: 2)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: chip.icon)
                        .font(.system(size: 20, weight: .black, design: .default))
                        .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                        .frame(width: 20, height: 20)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                    Text(chip.name)
                        .font(.custom("Nunito-Black", size: 14))
                        .foregroundColor(isDisabled ? .white.opacity(0.8) : .white)
                        .padding(.horizontal, 8)
                }
                .padding(8)
                .background(isDisabled ? .gray : (filterChipIconColors[chip.name] ?? .blue))
                .brightness(-0.10)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.6), radius: 3, x: 0, y: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}


// MARK: - FilterChip Picker View
struct FilterChipPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedRankoItems: [RankoItem]
    @State private var chipStack: [FilterChip] = []
    @State private var currentChips: [FilterChip] = defaultFilterChips.sorted { $0.order < $1.order }
    @State private var addItemsOpen: Bool = false
    @State private var isDisabled: Bool = true
    
    var isDisabledVariable: Bool {
        guard let last = chipStack.last else { return true } // no chip -> disabled
        return !last.children.isEmpty || (last.available == false)
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Selected chips row
                if !chipStack.isEmpty {
                    ZStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chipStack) { chip in
                                    FilterChipButtonViewVertical(chip: chip, isSelected: true) {
                                        backTo(chip)
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                        HStack {
                            Rectangle()
                                .fill(Color(hex: 0xFFFFFF))
                                .blur(radius: 2)
                                .frame(width: 25, height: 60)
                                .offset(x: -17)
                            Spacer()
                            Rectangle()
                                .fill(Color(hex: 0xFFFFFF))
                                .blur(radius: 2)
                                .frame(width: 25, height: 60)
                                .offset(x: 17)
                        }
                    }
                }
                
                // Current chips flow
                ScrollView {
                    FlowLayout(spacing: 8) {
                        ForEach(currentChips.sorted(by: { $0.order < $1.order })) { chip in
                            FilterChipButtonViewVertical(chip: chip, isSelected: false) {
                                chipTapped(chip)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .onChange(of: isDisabledVariable) { _, newValue in
                withAnimation(.easeInOut) {
                    isDisabled = newValue
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ZStack {
                        Button { } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .black, design: .default))
                        }
                        .disabled(isDisabled)
                        
                        if !isDisabled {
                            Button {
                                if let last = chipStack.last, last.children.isEmpty, last.available {
                                    let path = chipStack.map(\..name).dropLast()
                                    print("Path: \(path)")
                                    print("Last Chip Selected: \(last.name)")
                                    print("Set Index: \(last.nameIndex)")
                                    print("Set Filters: \(last.filter)")
                                    addItemsOpen.toggle()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black, design: .default))
                            }
                            .tint(Color(hex: 0x01991D))
                            .buttonStyle(.glassProminent)
                        }
                    }
                }
                ToolbarItemGroup(placement: .principal) {
                    Text("Add Items")
                        .font(.custom("Nunito-Black", size: 26))
                        .foregroundColor(Color(hex: 0x000000))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black, design: .default))
                    }
                    .tint(Color(hex: 0xD10000))
                    .buttonStyle(.glassProminent)
                }
            }
            .toolbarBackground(Color(hex:0xFFFFFF))
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing:0) {
                    Text("Pick Categories to Filter Items (until 'Done' button is enabled)")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .zIndex(1)
                    Rectangle()
                        .fill(Color(hex: 0xFFFFFF))
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .blur(radius: 4)
                        .offset(y: -10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .animation(.default, value: chipStack)
        .animation(.default, value: currentChips)
        .presentationBackground(Color(hex: 0xFFFFFF))
        .fullScreenCover(isPresented: $addItemsOpen) {
            if let last = chipStack.last, last.children.isEmpty {
                AddItemView(filterChip: last, existingCount: selectedRankoItems.count) { newItems in
                    // newItems is now [RankoItem]
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

