//
//  Login.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import FirebaseAnalytics

final class PresenterBox: ObservableObject { weak var vc: UIViewController? }

struct ViewControllerResolver: UIViewControllerRepresentable {
    @ObservedObject var box: PresenterBox
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async { self.box.vc = vc }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor
func topViewController(_ root: UIViewController? = nil) -> UIViewController? {
    let rootVC = root ?? (UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController)

    if let nav = rootVC as? UINavigationController {
        return topViewController(nav.visibleViewController)
    }
    if let tab = rootVC as? UITabBarController {
        return topViewController(tab.selectedViewController)
    }
    if let presented = rootVC?.presentedViewController {
        return topViewController(presented)
    }
    return rootVC
}

// MARK: - Login View
struct Login: View {
    // View Properties
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var isLoading: Bool = false
    @State private var nonce: String?
    @Environment(\.colorScheme) private var scheme
    @StateObject private var presenterBox = PresenterBox()
    @StateObject private var user_data = UserInformation.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Image with Gradient Masking
            GeometryReader { proxy in
                let size = proxy.size
                Image("LogIn_Background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
            }
            .mask {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white,
                                .white,
                                .white,
                                .white,
                                .white.opacity(0.9),
                                .white.opacity(0.6),
                                .white.opacity(0.2),
                                .clear,
                                .clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            // Sign in Options
            VStack(alignment: .leading) {
                HStack {
                    Text("Welcome to Ranko")
                        .font(.title.bold())
                        .foregroundColor(.orange)
                }
                
                
                // Sign in with Apple Button
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    self.nonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        loginWithFirebase(authorization)
                    case .failure(let error):
                        showError(error.localizedDescription)
                    }
                }
                .overlay {
                    ZStack {
                        Capsule()
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.system(size: 20))
                            Text("Sign in with Apple")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(scheme == .dark ? .black : .white)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 45)
                .clipShape(Capsule())
                .padding(.top, 10)
                
                // Google Sign In Option Button
                GoogleSignInButton {
                    googleSignIn()
                }
                .padding(.top, 10)

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .alert(errorMessage, isPresented: $showAlert) { }
        .overlay {
            if isLoading {
                LoadingScreen()
            }
        }
    }
    
    // Loading Screen Overlay
    @ViewBuilder
    func LoadingScreen() -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            ProgressView()
                .frame(width: 45, height: 45)
                .background(.background, in: RoundedRectangle(cornerRadius: 5))
        }
    }
    
    // Presenting Error Messages
    func showError(_ message: String) {
        errorMessage = message
        showAlert.toggle()
        isLoading = false
    }
    
    // Login With Firebase using Apple Credential
    func loginWithFirebase(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            isLoading = true
            
            guard let nonce = nonce else {
                showError("Cannot process your request.")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                showError("Cannot process your request.")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                showError("Cannot process your request.")
                return
            }
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if let error = error {
                    showError(error.localizedDescription)
                    return
                }
                // On successful sign in, update the log status.
                user_data.userLoginService = "Apple"
                user_data.logStatus = true
                isLoading = false
                user_data.userID = Auth.auth().currentUser!.uid
                Analytics.logEvent(AnalyticsEventLogin, parameters: [
                    AnalyticsParameterMethod: "Apple"
                ])
            }
        }
    }
    
    // Login With Google
    @MainActor
    func googleSignIn() {
        guard let presenter = topViewController() else {
            showError("Unable to access root view controller.")
            return
        }
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error = error { showError(error.localizedDescription); return }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                showError("Missing Google user info."); return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, error in
                if let error = error { showError(error.localizedDescription); return }
                user_data.userLoginService = "Google"
                user_data.logStatus = true
                isLoading = false
                user_data.userID = Auth.auth().currentUser!.uid
            }
        }
    }
    
    // MARK: - Helpers
    struct GoogleSignInButton: View {
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Spacer()
                    Image("google_icon") // Add a Google "G" logo asset to your Assets.xcassets
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(.leading, 4)
                    
                    
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding()
                .frame(height: 45)
                .background(Color.white)
                .cornerRadius(50)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
            }
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    /// Generates a random nonce string.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    /// Returns the SHA256 hash of the input string.
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    Login()
        .environmentObject(ProfileImageService())
}



