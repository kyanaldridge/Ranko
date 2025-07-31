//
//  ContentView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import FirebaseAuth
import Firebase

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var user_data = UserInformation.shared

    var body: some View {
        if user_data.logStatus {
            MainTabView()
        } else {
            Login()
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}





#Preview {
    ContentView()
}
