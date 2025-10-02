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
import StoreKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Provide GoogleSignIn with a configuration explicitly
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            assertionFailure("Missing Firebase clientID")
        }
        
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
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var imageService = ProfileImageService()
    @State private var showLaunchScreen = true  // State to control visibility of the launch screen
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ContentView is always in the background
                ContentView()

                // LaunchScreenView is shown initially, and will fade out
                if showLaunchScreen {
                    LaunchScreenView()
                        .onAppear {
                            startLaunchScreenAnimation()
                        }
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 1.0), value: opacity)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .environmentObject(imageService)
            .environmentObject(purchaseController)
            .task {
                // begin listening asap
                purchaseController.startListening()
                // also do an initial entitlement refresh for UI
                await purchaseController.refreshEntitlements()
            }
        }
    }

    // Function to start the launch screen animation
    private func startLaunchScreenAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // Start zoom-in and fade-out effect
            withAnimation(.easeInOut(duration: 1.0)) {
                scale = 1.5  // Zoom in by 1.5x
                opacity = 0  // Fade out the launch screen
            }
            
            // After the animation, hide the launch screen and show ContentView
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showLaunchScreen = false
            }
        }
    }
}

struct LaunchScreenView: View {
    @State private var scale: CGFloat = 1  // Initial scale for zoom-in effect
    @State private var opacity: Double = 1  // Initial opacity for fade-out effect
    @State private var showMainContent = false  // Flag to control when to show main content
    let animationDuration: Double = 0.9
    let delay: Double = 3  // Time before the zoom and fade effect starts

    var body: some View {
        ZStack {
            // The white background should fill the entire screen
            Color(hex: 0xFFF5E2)
                .ignoresSafeArea()
            
            // Your ThreeRectanglesAnimation
            ThreeRectanglesAnimation(
                rectangleWidth: 40,
                rectangleMaxHeight: 130,
                rectangleSpacing: 7,
                rectangleCornerRadius: 6,
                animationDuration: animationDuration
            )
            .frame(height: 170)
            .padding([.top, .horizontal])
            .padding(.bottom, 100)
            .onAppear {
                startAnimation()
            }
        }
    }

    // Function to start the animation
    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Zoom in and fade-out effect for the launch screen
            withAnimation(.easeInOut(duration: 1.0)) {
                scale = 3.5  // Zoom in
                opacity = 0  // Fade out the launch screen
            }
        }
    }
}

@MainActor
final class PurchaseController: ObservableObject {
    static let shared = PurchaseController()
    private var updatesTask: Task<Void, Never>? = nil

    @Published var isProUser: Bool = false
    @Published var activeProductID: String? = nil

    private init() {}

    func startListening() {
        // avoid multiple listeners
        guard updatesTask == nil else { return }

        // 1) catch historical/unfinished transactions once at launch
        Task { await self.consumePendingTransactions() }

        // 2) long-lived listener for new purchases/renewals/refunds
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(result)
            }
        }
    }

    func stopListening() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // call after purchase button too, but the listener will also catch it
    func refreshEntitlements() async {
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: "4205BB53")
            if let active = statuses.first(where: { $0.state == .subscribed }) {
                switch active.renewalInfo {
                case .verified(let info):
                    activeProductID = info.currentProductID
                    isProUser = true
                case .unverified:
                    activeProductID = nil
                    isProUser = true
                }
            } else {
                activeProductID = nil
                isProUser = false
            }

            // persist if you like
            UserDefaults.standard.set(isProUser ? 1 : 0, forKey: "isProUser")
            UserDefaults.standard.set(activeProductID, forKey: "activeProductID")
        } catch {
            print("refreshEntitlements error:", error.localizedDescription)
        }
    }

    // MARK: - Internals

    private func consumePendingTransactions() async {
        // iterate current entitlements and finish any un-finished transactions
        for await entitlement in Transaction.currentEntitlements {
            await handle(entitlement)
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .unverified(_, let error):
            print("❌ Unverified transaction:", error.localizedDescription)

        case .verified(let transaction):
            if let groupID = transaction.subscriptionGroupID, groupID == "4205BB53" {
                await refreshEntitlements()
            }
            await transaction.finish()
        }
    }
}
