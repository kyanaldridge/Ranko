//
//  RankoAppApp.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import Firebase
import FirebaseAppCheck
import GoogleSignIn
import GoogleSignInSwift

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Try restoring previous Google Sign-In
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                print("Restored sign-in: \(user.profile?.name ?? "")")
            } else if let error = error {
                print("Google restore error: \(error.localizedDescription)")
            }
        }
        
        return true
    }
}

@main
struct RankoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var imageService = ProfileImageService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // URL handling is now performed here instead of via deprecated UIApplicationDelegate methods.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .environmentObject(imageService)
        }
    }
}
