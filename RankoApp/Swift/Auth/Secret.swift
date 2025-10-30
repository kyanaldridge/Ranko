//
//  Secret.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 4/7/2025.
//

import Foundation

enum Secrets {
    
    static var algoliaAppID: String {
        return getPlistValue(for: "ALGOLIA_APP_ID")
    }

    static var algoliaAPIKey: String {
        return getPlistValue(for: "ALGOLIA_API_KEY")
    }
    
    static var geographyAlgoliaAppID: String {
        return getPlistValue(for: "ALGOLIA_GEOGRAPHY_ID")
    }

    static var geographyAlgoliaAPIKey: String {
        return getPlistValue(for: "ALGOLIA_GEOGRAPHY_KEY")
    }
    
    static var firebaseToken: String {
        return getPlistValue(for: "FIREBASE_TOKEN")
    }
    
    static var spotifyClientID: String {
        return getPlistValue(for: "SPOTIFY_CLIENT_ID")
    }
    
    static var spotifySecret: String {
        return getPlistValue(for: "SPOTIFY_CLIENT_SECRET")
    }

    private static func getPlistValue(for key: String) -> String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[key] as? String else {
            fatalError("Missing \(key) in Secrets.plist")
        }
        return value
    }
}

