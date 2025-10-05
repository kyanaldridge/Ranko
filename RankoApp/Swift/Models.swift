//
//  Models.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import AlgoliaSearchClient
import Combine

struct RankoUserInformation: Codable { // Used in Introduction Survey
    let objectID: String
    let userDetails: RankoUserDetails
    let userProfilePicture: RankoUserProfilePicture
    let userStats: RankoUserStats
}

struct RankoUserDetails: Codable {
    let UserID: String
    let UserName: String
    let UserDescription: String
    let UserPrivacy: String
    let UserInterests: String
    let UserJoined: String
    let UserYear: Int
    let UserFoundUs: String
    let UserSignInMethod: String
}

struct RankoUserProfilePicture: Codable {
    let UserProfilePicturePath: String
    let UserProfilePictureModified: String
    let UserProfilePictureFile: String
}

struct RankoUserStats: Codable {
    let UserRankoCount: Int
    let UserFollowerCount: Int
    let UserFollowingCount: Int
}

final class UserInformation: ObservableObject { // App Wide User Variables
    static let shared = UserInformation()
    
    // MARK: - All User Information -
    
    // MARK: - UserDetails
    @AppStorage("user_id") var userID: String = ""
    @AppStorage("user_name") var username: String = ""
    @AppStorage("user_description") var userDescription: String = ""
    @AppStorage("user_privacy") var userPrivacy: String = ""
    @AppStorage("user_interests") var userInterests: String = ""
    @AppStorage("user_joined") var userJoined: String = ""
    @AppStorage("user_year") var userYear: Int = 0
    @AppStorage("user_found_us") var userFoundUs: String = ""
    @AppStorage("user_login_service") var userLoginService: String = ""
    
    // MARK: - UserProfilePicture
    @AppStorage("user_profile_picture_file") var userProfilePictureFile: String = ""
    @AppStorage("user_profile_picture_path") var userProfilePicturePath: String = ""
    @AppStorage("user_profile_picture_modified") var userProfilePictureModified: String = ""
    
    // MARK: - UserStats
    @AppStorage("user_stats_followers") var userStatsFollowers: Int = 0
    @AppStorage("user_stats_following") var userStatsFollowing: Int = 0
    @AppStorage("user_stats_rankos") var userStatsRankos: Int = 0
    
    @AppStorage("log_Status") var logStatus: Bool = false
    @AppStorage("user_ranko_categories") var userRankoCategories: String = ""
    
    // MARK: - NOTIFICATIONS -
    @AppStorage("user_notification_rankoLikes") var notificationRankoLikes: Bool = true
    @AppStorage("user_notification_rankoClones") var notificationRankoClones: Bool = true
    @AppStorage("user_notification_personalRecommendations") var notificationPersonalizedRecommendations: Bool = true
    @AppStorage("user_notification_weeklyProgress") var notificationWeeklyProgress: Bool = true
    @AppStorage("user_notification_appUpdate") var notificationAppUpdateAvailable: Bool = true
    @AppStorage("user_notification_friendRequests") var notificationFriendRequests: Bool = true
    @AppStorage("user_notification_sharedRankos") var notificationSharedRankos: Bool = true
    @AppStorage("user_notification_friendsNewRankos") var notificationFriendsNewRankos: Bool = true
    @AppStorage("user_notification_trendingRankos") var notificationTrendingRankos: Bool = true
    @AppStorage("user_notification_miniGameEvents") var notificationMiniGameEvents: Bool = true
    
    // MARK: - PREFERENCES -
    @AppStorage("user_preferences_autocorrectDisabled") var preferencesAutocorrectDisabled: Bool = true
    @AppStorage("user_preferences_haptics") var preferencesHaptics: Bool = true
    @AppStorage("user_preferences_hapticIntensity") var preferencesHapticIntensity: Int = 2
    
    // MARK: - PRIVACY -
    @AppStorage("user_privacy_privateAccount") var privacyPrivateAccount: Bool = false
    @AppStorage("user_privacy_allowFriendRequests") var privacyAllowFriendRequests: Bool = false
    @AppStorage("user_privacy_displayFeaturedLists") var privacyDisplayFeaturedLists: Bool = false
    @AppStorage("user_privacy_displayUsername") var privacyDisplayUsername: Bool = false
    @AppStorage("user_privacy_displayBio") var privacyDisplayBio: Bool = false
    @AppStorage("user_privacy_displayProfilePicture") var privacyDisplayProfilePicture: Bool = false
    @AppStorage("user_privacy_allowClones") var privacyAllowClones: Bool = false
    
    @AppStorage("device_height") var deviceHeight: Int = 0
    @AppStorage("device_width") var deviceWidth: Int = 0
    @AppStorage("device_keyboardHeight") var deviceKeyboardHeight: Int = 250
    
    @AppStorage("platinum_user") var platinumUser: Bool = false
    @AppStorage("platinum_plan") var platinumPlan: String?
    @AppStorage("platinum_id") var platinumID: Int = 0
    @AppStorage("platinum_purchaseDate") var platinumPurchaseDate: Date = Date()
    @AppStorage("platinum_expiryDate") var platinumExpireDate: Date?
    @AppStorage("platinum_price") var platinumPrice: Double?
    
    @AppStorage("user_privacy_customiserAppIcon") var customiserAppIcon: String = "Nunito"
    @AppStorage("user_privacy_customiserTheme") var customiserTheme: String = "Default"
    @AppStorage("user_privacy_customiserFont") var customiserFont: String = "Default"
    
    @AppStorage("game_blindSequence_gamesPlayed") var blindSequenceGamesPlayed: Int = 0
    @AppStorage("game_blindSequence_highScore") var blindSequenceHighScore: Int = 0
    @AppStorage("game_blindSequence_highScoreTime") var blindSequenceHighScoreTime: Double = .infinity
    @AppStorage("game_blindSequence_gamesPlayed") var blindSequenceMaxLevelUnlocked: Int = 1
    @AppStorage("game_blindSequence_gamesPlayed") var blindSequenceSelectedLevel: Int = 1
    
    @Published var ProfilePicture: UIImage? = loadCachedProfileImage()
    
    private init() {}
}



// MARK: -- Ranko Models
struct RankoList: Identifiable, Codable {
    let id: String
    let listName: String
    let listDescription: String   // from "RankoDescription"
    let type: String
    let categoryName: String
    let categoryIcon: String
    let categoryColour: UInt
    let isPrivate: String          // e.g. "Private" / "Public"
    let userCreator: String          // from "RankoDateTime" e.g. "2024-04-06-17-42"
    let timeCreated: String       // from "RankoUserID"
    let timeUpdated: String
    var items: [RankoItem]
}

struct RankoCategoryInfo: Codable, Hashable {
    let name: String
    let icon: String
    let colour: UInt
}

struct RankoRecord: Codable, Identifiable, Equatable, Hashable {
    let objectID: String
    let ItemName: String
    let ItemDescription: String
    let ItemCategory: String
    let ItemImage: String

    // ⬇️ make media fields optional so decoding won’t require them
    let ItemGIF: String?
    let ItemVideo: String?
    let ItemAudio: String?

    var id: String { objectID }
}

struct RankoItem: Identifiable, Codable, Equatable, Hashable {
    let id: String            // ← will hold our random 12-char code
    var rank: Int             // ← selection order
    var votes: Int
    let record: RankoRecord
    var itemName: String { record.ItemName }
    var itemDescription: String { record.ItemDescription }
    var itemImage: String { record.ItemImage }
    var itemGIF: String   { record.ItemGIF   ?? "" }
    var itemVideo: String { record.ItemVideo ?? "" }
    var itemAudio: String { record.ItemAudio ?? "" }
    var playCount: Int
}

struct RankoUser: Identifiable, Codable {
    let id: String
    let userName: String
    let userDescription: String
    let userProfilePicture: String
}


struct RankoListAlgolia: Codable {
    let objectID: String
    let RankoName: String
    let RankoDescription: String
    let RankoType: String
    let RankoPrivacy: Bool
    let RankoStatus: String
    let RankoCategory: String
    let RankoUserID: String
    let RankoCreated: String
    let RankoUpdated: String
    
    let RankoLikes: Int
    let RankoComments: Int
    let RankoVotes: Int
}

struct ClonedRankoList: Codable {
    let listName: String
    let listDescription: String
    let type: String
    let category: String
    let isPrivate: String
    var items: [RankoItem]
}

// MARK: - Global Functions

func getProfileImagePath() -> URL {
    @StateObject var user_data = UserInformation.shared
    let filename = "cached_profile_image.jpg"
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
}

func loadCachedProfileImage() -> UIImage? {
    let path = getProfileImagePath()
    guard FileManager.default.fileExists(atPath: path.path),
          let data = try? Data(contentsOf: path),
          let image = UIImage(data: data) else {
        return nil
    }
    return image
}

// MARK: - SAMPLE ALGOLIA LOADER -
class AlgoliaLoader<T: Decodable> {
    
    // MARK: - Editable Variables -
    private let AlgoliaIndex: String
    private let AlgoliaFilters: String?
    private let AlgoliaQuery: String?
    private let AlgoliaHitsPerPage: Int
    
    // MARK: - Important Variables -
    private var client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID), apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
    private let index: AIndex


    init(
        AlgoliaIndex: String,
        AlgoliaFilters: String? = nil,
        AlgoliaQuery: String = "",
        AlgoliaHitsPerPage: Int = 20
    ) {
        self.AlgoliaIndex = AlgoliaIndex
        self.AlgoliaFilters = AlgoliaFilters
        self.AlgoliaQuery = AlgoliaQuery
        self.AlgoliaHitsPerPage = AlgoliaHitsPerPage

        self.client = SearchClient(appID: ApplicationID(rawValue: Secrets.algoliaAppID),
                                   apiKey: APIKey(rawValue: Secrets.algoliaAPIKey))
        self.index = client.index(withName: IndexName(rawValue: AlgoliaIndex))
    }

    // MARK: - Fetch & Decode
    func fetchData(completion: @escaping (Result<[T], Error>) -> Void) {
        var query = Query(AlgoliaQuery)
        query.hitsPerPage = AlgoliaHitsPerPage
        if let filters = AlgoliaFilters {
            query.filters = filters
        }

        index.search(query: query) { result in
            switch result {
            case .success(let response):
                do {
                    let objects: [T] = try response.hits.compactMap { hit in
                        let data = try JSONEncoder().encode(hit.object)
                        return try JSONDecoder().decode(T.self, from: data)
                    }
                    completion(.success(objects))
                } catch {
                    print("❌ Decoding failed: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
