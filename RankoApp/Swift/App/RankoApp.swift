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

@MainActor
final class PurchaseController: ObservableObject {
    private var user_data = UserInformation.shared
    
    static let shared = PurchaseController()
    private var updatesTask: Task<Void, Never>? = nil

    @Published var isProUser: Bool = false
    @Published var activeProductID: String? = nil
    
    @Published var isEntitled: Bool = false
    @Published var autoRenews: Bool? = nil
    @Published var expiresOn: Date? = nil
    
    @Published var nextProductID: String? = nil   // the plan it will switch to
    @Published var renewalOn: Date? = nil         // when it will switch/renew
    @Published var data: String = "Fetching data..."

    private init() {}

    func startListening() {
        // avoid multiple listeners
        guard updatesTask == nil else { return }

        // 1) catch historical/unfinished transactions once at launch
        Task { await self.consumePendingTransactions() }

        // 2) long-lived listener for new purchases/renewals/refunds
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                switch result {
                case .verified(let tx):
                    print("📬 tx update: pid=\(tx.productID) group=\(tx.subscriptionGroupID ?? "nil") " +
                          "exp=\(String(describing: tx.expirationDate)) revoked=\(String(describing: tx.revocationDate))")
                case .unverified(_, let err):
                    print("📬 tx update UNVERIFIED:", err.localizedDescription)
                }
                await self?.refreshEntitlements()
                if case .verified(let tx) = result { await tx.finish() }
            }
        }
    }

    func stopListening() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // call after purchase button too, but the listener will also catch it
    
    func fetchData() async {
        guard let url = URL(string: "https://api.example.com/data") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decodedData = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.data = decodedData
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.data = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    func refreshEntitlements() async {
        self.isEntitled = false
        self.activeProductID = nil
        self.autoRenews = nil
        self.expiresOn = nil
        
        let targetGroup = "D546B9ED"
        let allowedPIDs: Set<String> = ["platinum_weekly","platinum_monthly","platinum_yearly"]
        
        do {
            print("🔄 refreshEntitlements() BEGIN @ \(Date())")
            print("🎫 Scanning currentEntitlements (filtered to group=\(targetGroup))")
            print(user_data.platinumUser)
            print(user_data.platinumPlan ?? "NO PLAN")
            print(user_data.platinumID == 0 ? "NO PLAN" : Int(user_data.platinumID))
            print(user_data.platinumPurchaseDate)
            print(user_data.platinumExpireDate ?? "NO PLAN")
            print(user_data.platinumPrice ?? "NO PLAN")
            
            var pid: String?
            var expiry: Date?
            
            // 1) Ground truth: verified, not expired, in your group AND ID list
            for await res in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let tx) = res else { continue }
                let grp = tx.subscriptionGroupID ?? "nil"
                print("  • CE VERIFIED pid=\(tx.productID) group=\(grp) exp=\(String(describing: tx.expirationDate)) revoked=\(String(describing: tx.revocationDate))")
                
                guard grp == targetGroup, allowedPIDs.contains(tx.productID) else { continue }
                
                let notRevoked = (tx.revocationDate == nil)
                let notExpired = (tx.expirationDate == nil) || (tx.expirationDate ?? Date() > Date())
                if notRevoked && notExpired {
                    pid = tx.productID
                    expiry = tx.expirationDate
                    break
                }
            }
            
            // 2) Enrich from status(for:) to get auto-renew
            if pid != nil {
                let statuses = try await Product.SubscriptionInfo.status(for: targetGroup)
                print("🧾 statuses.count = \(statuses.count) for group \(targetGroup)")
                if let s = statuses.first(where: { st in
                    switch st.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod: return true
                    default: return false
                    }
                }) {
                    if case .verified(let info) = s.renewalInfo {
                        print(s.renewalInfo)
                        autoRenews = info.willAutoRenew
                        let nextProduct = info.autoRenewPreference  // <-- what it will switch to next cycle
                        let renewalDate = info.renewalDate          // <-- when the switch/renewal happens
                        
                        print("🔁 renewal currentPID=\(info.currentProductID) " +
                              "autoRenewPref=\(nextProduct ?? "nil") " +
                              "willAutoRenew=\(info.willAutoRenew) " +
                              "renewalDate=\(String(describing: renewalDate))")

                        // 3) update local flags (your request)
                        user_data.platinumUser = true
                        if Int(info.originalTransactionID) > 0 {
                            user_data.platinumID = Int(info.originalTransactionID)
                        }
                        user_data.platinumPlan = info.currentProductID
                        user_data.platinumPurchaseDate = info.recentSubscriptionStartDate
                        user_data.platinumExpireDate = info.renewalDate == nil ? Date() : info.renewalDate
                        
                        func formattedDateString(from date: Date) -> String {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyyMMddHHmmss" // Define the desired format
                            return dateFormatter.string(from: date)
                        }

                        // 4) write to Firebase Realtime Database
                        let dict: [String: Any?] = [
                            "UserPlatinum": true,
                            "PlatinumID": Int(info.originalTransactionID),
                            "PlatinumPlan": "0",
                            "PlatinumPurchaseDate": formattedDateString(from: info.recentSubscriptionStartDate),
                            "PlatinumExpireDate": formattedDateString(from: info.renewalDate ?? Date()),
                            "PlatinumPrice": 0
                        ]

                        let clean = dict.compactMapValues { $0 } // drop nils
                        let ref = Database.database().reference()
                            .child("UserData")
                            .child(user_data.userID)
                            .child("PlatinumDetails")

                        do {
                            try await ref.updateChildValues(clean)   // ✅ async alternative
                            print("✅ RTDB PlatinumDetails updated")
                        } catch {
                            print("❌ RTDB write error:", error.localizedDescription)
                        }
                        
                        // keep pid aligned to the **current** plan for entitlement:
                        pid = info.currentProductID
                        
                        // OPTIONAL: store next plan & renewal date to show in UI
                        self.nextProductID = nextProduct
                        self.renewalOn = renewalDate
                    }
                }
            }

            // 3) Publish to UI
            self.isEntitled = (pid != nil)
            self.activeProductID = pid
            self.expiresOn = expiry

            self.isProUser = self.isEntitled
            if self.isEntitled { self.activeProductID = nil }

            // 🔁 keep RTDB in sync with reality
            if self.isEntitled, let pid = self.activeProductID {
                // still entitled — write the latest snapshot (Plan + Expire)
                let user = UserInformation.shared
                let ref = Database.database().reference()
                    .child("UserData").child(user.userID).child("PlatinumDetails")
                let dict: [String: Any?] = [
                    "UserPlatinum": true,
                    "PlatinumPlan": pid.isEmpty ? "" : pid,
                    "PlatinumExpireDate": "000000"
                        //expiry == nil ? "000000" : expiry
                ]
                try await ref.updateChildValues(dict.compactMapValues { $0 })
            } else {
            }

            print("✅ RESULT entitled=\(self.isEntitled) pid=\(pid ?? "nil") exp=\(String(describing: expiry)) auto=\(String(describing: autoRenews)) @ \(Date())")
        } catch {
            print("❌ refreshEntitlements error:", error.localizedDescription)
        }
    }
    
    @MainActor
    func recordPlatinum(from tx: StoreKit.Transaction, product: Product) async {

        // 1) core fields from Transaction
        let productID = tx.productID
        let transactionID = tx.id
        let purchaseDate = tx.purchaseDate
        let expireDate = tx.expirationDate
        
        print("1. id: \(tx.id)")
        print("2. advancedCommerceInfo:  \(String(describing: tx.advancedCommerceInfo))")
        print("3. appAccountToken:  \(String(describing: tx.appAccountToken))")
        print("4. appBundleID:  \(tx.appBundleID)")
        print("5. appTransactionID:  \(tx.appTransactionID)")
        print("6. currency:  \(String(describing: tx.currency))")
        print("7. debugDescription:  \(tx.debugDescription)")
        print("8. deviceVerification:  \(tx.deviceVerification)")
        print("9. deviceVerificationNonce:  \(tx.deviceVerificationNonce)")
        print("10. environment:  \(tx.environment)")
        print("11. expirationDate:  \(String(describing: tx.expirationDate))")
        print("12. hashValue:  \(tx.hashValue)")
        print("13. isUpgraded:  \(tx.isUpgraded)")
        print("14. jsonRepresentation:  \(tx.jsonRepresentation)")
        print("15. offer:  \(String(describing: tx.offer))")
        print("16. originalID:  \(tx.originalID)")
        print("17. originalPurchaseDate:  \(tx.originalPurchaseDate)")
        print("18. ownershipType:  \(tx.ownershipType)")
        print("19. price:  \(String(describing: tx.price))")
        print("20. productID:  \(tx.productID)")
        print("21. productType:  \(tx.productType)")
        print("22. purchaseDate:  \(tx.purchaseDate)")
        print("23. purchasedQuantity:  \(tx.purchasedQuantity)")
        print("24. reason:  \(tx.reason)")
        print("25. revocationDate:  \(String(describing: tx.revocationDate))")
        print("26. revocationReason:  \(String(describing: tx.revocationReason))")
        print("27. signedDate:  \(tx.signedDate)")
        print("28. storefront:  \(tx.storefront)")
        print("29. subscriptionGroupID:  \(String(describing: tx.subscriptionGroupID))")

        // 2) price in minor units (cents). Prefer Transaction (iOS 17.4+), else decode JWS, else fallback.
        let price = (tx.price! as NSDecimalNumber).doubleValue

        // 3) update local flags (your request)
        user_data.platinumUser = true
        if Int(tx.id) > 0 {
            user_data.platinumID = Int(tx.id)
        }
        user_data.platinumPlan = productID
        user_data.platinumPurchaseDate = purchaseDate
        user_data.platinumExpireDate = expireDate == nil ? Date() : expireDate
        user_data.platinumPrice = price
        
        func formattedDateString(from date: Date) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss" // Define the desired format
            return dateFormatter.string(from: date)
        }

        // 4) write to Firebase Realtime Database
        let dict: [String: Any?] = [
            "UserPlatinum": true,
            "PlatinumID": transactionID,
            "PlatinumPlan": productID.isEmpty ? "0" : productID,
            "PlatinumPurchaseDate": formattedDateString(from: purchaseDate),
            "PlatinumExpireDate": formattedDateString(from: expireDate ?? Date()),
            "PlatinumPrice": price
        ]

        let clean = dict.compactMapValues { $0 } // drop nils
        let ref = Database.database().reference()
            .child("UserData")
            .child(user_data.userID)
            .child("PlatinumDetails")

        do {
            try await ref.updateChildValues(clean)   // ✅ async alternative
            print("✅ RTDB PlatinumDetails updated")
        } catch {
            print("❌ RTDB write error:", error.localizedDescription)
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
            if let groupID = transaction.subscriptionGroupID, groupID == "D546B9ED" {
                await refreshEntitlements()
            }
            await transaction.finish()
        }
    }
    
    private func logStatuses(_ statuses: [Product.SubscriptionInfo.Status]) {
        print("🧾 Statuses count =", statuses.count)
        for (i, s) in statuses.enumerated() {
            let st: String = {
                switch s.state {
                case .subscribed: return "subscribed"
                case .inGracePeriod: return "inGracePeriod"
                case .inBillingRetryPeriod: return "inBillingRetry"
                case .expired: return "expired"
                case .revoked: return "revoked"
                default: return "other"
                }
            }()

            var txLine = "tx: none"
            if case .verified(let tx) = s.transaction {
                txLine = "tx: VERIFIED pid=\(tx.productID) exp=\(String(describing: tx.expirationDate)) revoked=\(String(describing: tx.revocationDate))"
            } else if case .unverified(_, let err) = s.transaction {
                txLine = "tx: UNVERIFIED err=\(err.localizedDescription)"
            }

            var riLine = "renewal: none"
            switch s.renewalInfo {
            case .verified(let info):
                riLine = "renewal: VERIFIED currentPID=\(info.currentProductID) willAutoRenew=\(info.willAutoRenew) autoPref=\(String(describing: info.autoRenewPreference))"
            case .unverified(_, let err):
                riLine = "renewal: UNVERIFIED err=\(err.localizedDescription)"
            }

            print("  [\(i)] state=\(st) • \(txLine) • \(riLine)")
        }
    }

    private func logCurrentEntitlements() async {
        print("🎫 CurrentEntitlements dump start")
        for await r in StoreKit.Transaction.currentEntitlements {
            switch r {
            case .verified(let tx):
                print("  CE: VERIFIED pid=\(tx.productID) type=\(tx.productType.rawValue) exp=\(String(describing: tx.expirationDate)) revoked=\(String(describing: tx.revocationDate))")
            case .unverified(_, let err):
                print("  CE: UNVERIFIED err=\(err.localizedDescription)")
            }
        }
        print("🎫 CurrentEntitlements dump end")
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
