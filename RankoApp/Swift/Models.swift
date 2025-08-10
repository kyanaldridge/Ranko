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
    let UserName: String
    let UserDescription: String
    let UserYear: Int
    let UserInterests: String
    let UserProfilePicture: String
    let UserFoundUs: String
    let UserJoined: String
}

final class UserInformation: ObservableObject { // App Wide User Variables
    static let shared = UserInformation()
    
    // MARK: - All User Information -
    @AppStorage("user_id") var userID: String = ""
    @AppStorage("user_name") var username: String = ""
    @AppStorage("user_description") var userDescription: String = ""
    @AppStorage("user_year") var userYear: Int = 0
    @AppStorage("user_interests") var userInterests: String = ""
    @AppStorage("user_profile_picture") var userProfilePicture: String = ""
    @AppStorage("user_profile_picture_modified") var userProfilePictureModified: String = ""
    @AppStorage("user_found_us") var userFoundUs: String = ""
    @AppStorage("user_joined") var userJoined: String = ""
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
    
    // ✅ Track login service (Apple or Google)
    @AppStorage("user_login_service") var userLoginService: String = "" // "Apple" or "Google"
    
    @Published var ProfilePicture: UIImage? = loadCachedProfileImage()
    
    private init() {}
}



// MARK: -- Ranko Models
struct RankoList: Identifiable, Codable {
    let id: String
    let listName: String
    let listDescription: String   // from "RankoDescription"
    let type: String
    let category: String          // from "RankoCategory"
    let isPrivate: String          // e.g. "Private" / "Public"
    let userCreator: String       // from "RankoUserID"
    let dateTime: String          // from "RankoDateTime" e.g. "2024-04-06-17-42"
    var items: [RankoItem]
}
struct RankoRecord: Codable, Identifiable {
    let objectID: String
    let ItemName: String
    let ItemDescription: String
    let ItemCategory: String
    let ItemImage: String
    
    var id: String { objectID }
}

struct RankoItem: Identifiable, Codable {
    let id: String            // ← will hold our random 12-char code
    var rank: Int             // ← selection order
    var votes: Int
    let record: RankoRecord
    var itemName: String { record.ItemName }
    var itemDescription: String { record.ItemDescription }
    var itemImage: String { record.ItemImage }
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
    let RankoDateTime: String
    
    let RankoLikes: Int
    let RankoComments: Int
    let RankoVotes: Int
}

// MARK: - Global Functions

func getProfileImagePath() -> URL {
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
    private let index: Index


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
