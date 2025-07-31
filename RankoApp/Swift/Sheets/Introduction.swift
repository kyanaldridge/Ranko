//
//  Introduction.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI
import FirebaseAuth
import Firebase
import AlgoliaSearchClient

extension View {
    func disabledWithOpacity(_ status: Bool) -> some View {
        self
            .disabled(status)
            .opacity(status ? 0.5 : 1)
    }
}

struct TrayConfig {
    var maxDetent: PresentationDetent
    var cornerRadius: CGFloat = 30
    var isInteractiveDismissDisabled: Bool = true
    /// Add Other Properties as per your needs
    var horizontalPadding: CGFloat = 15
    var bottomPadding: CGFloat = 15
}

extension View {
    @ViewBuilder
    func systemTrayView<Content: View>(
        _ show: Binding<Bool>,
        config: TrayConfig = .init(maxDetent: .fraction(0.99)),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .sheet(isPresented: show) {
                content()
                    .background(.background)
                    .clipShape(.rect(cornerRadius: config.cornerRadius))
                    .padding(.horizontal, config.horizontalPadding)
                    .padding(.bottom, config.bottomPadding)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    /// Presentation Configurations
                    .presentationDetents([config.maxDetent])
                    .presentationCornerRadius(0)
                    .presentationBackground(.clear)
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(config.isInteractiveDismissDisabled)
                    .background(RemoveSheetShadow())
            }
    }
}

enum CurrentView {
    case actions
    case likes
    case keypad
}

struct TrayView: View {
    @State private var currentView: CurrentView = .actions
    @State private var selectedAction: Action?
    @State private var selectedPeriod: Period?
    @State private var duration: String = ""
    @State private var selection: [String] = []
    @Binding var currentDetent: PresentationDetent
    @StateObject private var user_data = UserInformation.shared
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                switch currentView {
                case .actions: View1()
                        .transition(
                            .blurReplace(.upUp)
                        )
                case .likes: View4()
                        .transition(
                            .blurReplace(.downUp)
                        )
                case .keypad: View3()
                        .transition(.blurReplace(.upUp)
                        )
                    
                }
            }
            .compositingGroup()
            
            /// Continue Button
            Button {
                if currentView == .actions {
                    withAnimation(.bouncy) {
                        currentView = .likes
                    }
                } else if currentView == .likes {
                    withAnimation(.bouncy) {
                        currentView = .keypad
                    }
                } else if currentView == .keypad {
                    withAnimation(.bouncy) {
                        user_data.userYear = Int(duration) ?? 0
                        saveDetailsToDatabase()
                        dismiss()
                    }
                }
            } label: {
                if currentView == .keypad ? duration.isEmpty : false {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(.orange, in: .capsule)
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(.orange, in: .capsule)
                    }
                }
                .disabledWithOpacity(currentView == .actions ? selectedAction == nil : false)
                .disabledWithOpacity(currentView == .likes ? isPreferencesInvalid : false)
                .disabledWithOpacity(currentView == .keypad ? ((Int(duration) ?? 0)) != 0 && (duration.count != 4 || ((Int(duration) ?? 0) == 0)) : false)

                .padding(.top, 15)
            }
        .onChange(of: currentView) { oldValue, newValue in
            switch newValue {
            case .actions: currentDetent = .fraction(0.7)
            case .likes: currentDetent = .large
            case .keypad: currentDetent = .fraction(0.7)
            }
        }
        .padding(20)
    }
    
    func saveDetailsToDatabase() {
        
        let now = Date()
        let aedtFormatter = DateFormatter()
        aedtFormatter.locale = Locale(identifier: "en_US_POSIX")
        aedtFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        aedtFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let rankoDateTime = aedtFormatter.string(from: now)
        
        if Auth.auth().currentUser!.isAnonymous {
            user_data.username = "New User"
        } else {
            user_data.username = Auth.auth().currentUser!.displayName ?? "New User"
        }
        
        user_data.userProfilePicture = "default-profilePicture.jpg"

        // 1) Build Group List Codable Struct
        let listRecord = RankoUserInformation(
            objectID: Auth.auth().currentUser!.uid,
            UserName: user_data.username,
            UserDescription: "",
            UserYear: user_data.userYear,
            UserInterests: user_data.userInterests,
            UserProfilePicture: user_data.userProfilePicture,
            UserFoundUs: selectedAction!.title,
            UserJoined: rankoDateTime
        )
        
        let userData: [String: Any?] = [
            "UserName": user_data.username,
            "UserDescription": "",
            "UserYear": user_data.userYear,
            "UserInterests": user_data.userInterests,
            "UserProfilePicture": user_data.userProfilePicture,
            "UserFoundUs": selectedAction!.title,
            "UserJoined": rankoDateTime
        ]
        
        let db = Database.database().reference()
        db.child("UserData").child(Auth.auth().currentUser!.uid).setValue(userData)

        // 3) Upload to Algolia
        let group = DispatchGroup()
        
        let usersIndex = client.index(withName: "RankoUsers")

        group.enter()
        usersIndex.saveObject(listRecord) { result in
            switch result {
            case .success:
                print("✅ User information uploaded to Algolia")
            case .failure(let error):
                print("❌ Error uploading user information: \(error)")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            print("🎉 Upload to Algolia completed")
        }
    }
    
    /// View 1
    @ViewBuilder
    func View1() -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("How did you hear about us?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)
            
            /// Custom Checkbox Menu
            ForEach(actions) { action in
                let isSelected: Bool = selectedAction?.id == action.id
                
                HStack(spacing: 10) {
                    Image(systemName: action.image)
                        .font(.title)
                        .frame(width: 40)
                    
                    Text(action.title)
                        .fontWeight(.semibold)
                    
                    Spacer(minLength: 0)
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                        .font(.title)
                        .contentTransition(.symbolEffect)
                        .foregroundStyle(isSelected ? Color.orange : Color.gray.opacity(0.2))
                }
                .padding(.vertical, 6)
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.snappy) {
                        selectedAction = isSelected ? nil : action
                    }
                }
            }
        }
    }
    
    /// View 3
    @ViewBuilder
    func View3() -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Year of Birth")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 6) {
                Text(duration.isEmpty ? "0" : duration)
                    .font(.system(size: 60, weight: .black))
                    .contentTransition(.numericText())
                
                Text("Which year were you born in? Click skip if you don't need restrictions...")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 20)
            
            // Compute allowed digits based on the current input.
            let allowed: Set<String> = {
                if duration.count >= 4 { return Set() }  // No additional input allowed
                switch duration.count {
                case 0:
                    // Only allow 1 or 2 for years between 1908 and 2025.
                    return Set(["1", "2"])
                case 1:
                    // With a leading 1, force 9. With a leading 2, force 0.
                    if duration.first == "2" {
                        return Set(["0"])
                    } else if duration.first == "1" {
                        return Set(["9"])
                    }
                    return Set()
                case 2:
                    // If prefix is "19", then any digit is allowed.
                    // If prefix is "20", limit to 0, 1, or 2.
                    if duration.hasPrefix("19") {
                        return Set(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
                    } else if duration.hasPrefix("20") {
                        return Set(["0", "1", "2"])
                    }
                    return Set()
                case 3:
                    if duration.hasPrefix("19") {
                        // For 19xx years, if the first three digits are "190", only "8" or "9" can be entered next.
                        if duration == "190" {
                            return Set(["8", "9"])
                        } else {
                            // For "191", "192", etc., any digit is allowed.
                            return Set(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
                        }
                    } else if duration.hasPrefix("20") {
                        // For 20xx, if the three-digit prefix is "202", restrict the final digit to 0–5.
                        if duration == "202" {
                            return Set(["0", "1", "2", "3", "4", "5"])
                        } else {
                            return Set(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
                        }
                    }
                    return Set()
                default:
                    return Set()
                }
            }()
            
            /// Custom Keypad View
            LazyVGrid(columns: Array(repeating: GridItem(), count: 3), spacing: 15) {
                ForEach(keypadValues) { keyValue in
                    // The back key should always be enabled.
                    let isEnabled = keyValue.isBack || allowed.contains(keyValue.title)
                    
                    // For layout consistency, if the key's value is 0 and you want it as a spacer, handle accordingly.
                    if keyValue.value == 0 {
                        Spacer()
                    }
                    
                    Group {
                        if keyValue.isBack {
                            Image(systemName: keyValue.title)
                        } else {
                            Text(keyValue.title)
                        }
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    // Gray out the button if it's disabled.
                    .opacity(isEnabled ? 1.0 : 0.2)
                    .onTapGesture {
                        // Only allow the tap if the key is enabled.
                        guard isEnabled else { return }
                        withAnimation(.snappy) {
                            if keyValue.isBack {
                                if !duration.isEmpty {
                                    duration.removeLast()
                                }
                            } else {
                                duration.append(keyValue.title)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, -15)
        }
    }
    
    // 1) Helper to compute the number of selected preferences:
    private var selectedPreferencesCount: Int {
        user_data.userInterests
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    // 2) Compute whether the “Continue” button should be disabled:
    private var isPreferencesInvalid: Bool {
        let count = selectedPreferencesCount
        return count == 0 || count > 3
    }
    
    func View4() -> some View {
        
        // Define the tag-to-icon mapping locally (in the desired order).
        let localTagIconMapping: [String: String] = [
            "Sport": "figure.gymnastics",
            "Animals": "pawprint.fill",
            "Music": "music.note",
            "Food": "fork.knife",
            "Nature": "leaf.fill",
            "Geography": "globe.europe.africa.fill",
            "History": "building.columns.fill",
            "Science": "atom",
            "Gaming": "gamecontroller.fill",
            "Celebrities": "star.fill",
            "Art": "paintbrush.pointed.fill",
            "Cars": "car.side.roof.cargo.carrier.fill",
            "Football": "soccerball",
            "Fruit": "apple.logo",
            "Soda": "takeoutbag.and.cup.and.straw.fill",
            "Mammals": "hare.fill",
            "Flowers": "microbe.fill",
            "Movies": "movieclapper",
            "Instruments": "guitars.fill",
            "Politics": "person.bust.fill",
            "Basketball": "basketball.fill",
            "Vegetables": "carrot.fill",
            "Alcohol": "flame.fill",
            "Birds": "bird.fill",
            "Trees": "tree.fill",
            "Shows": "tv",
            "Festivals": "hifispeaker.2.fill",
            "Planets": "circles.hexagonpath.fill",
            "Tennis": "tennisball.fill",
            "Pizza": "triangle.lefthalf.filled",
            "Coffee": "cup.and.heat.waves.fill",
            "Dogs": "dog.fill",
            "Social Media": "message.fill",
            "Albums": "record.circle",
            "Actors": "theatermasks.fill",
            "Travel": "airplane",
            "Motorsport": "steeringwheel",
            "Eggs": "oval.portrait.fill",
            "Cats": "cat.fill",
            "Books": "books.vertical.fill",
            "Musicians": "music.microphone",
            "Australian Football": "australian.football.fill",
            "Fast Food": "takeoutbag.and.cup.and.straw.fill",
            "Fish": "fish.fill",
            "Board Games": "dice.fill",
            "Numbers": "1.square.fill",
            "Relationships": "heart.fill",
            "American Football": "american.football.fill",
            "Pasta": "water.waves",
            "Reptiles": "lizard.fill",
            "Card Games": "suit.club.fill",
            "Letters": "a.square.fill",
            "Baseball": "baseball.fill",
            "Ice Cream": "snowflake",
            "Bugs": "ladybug.fill",
            "Memes": "camera.fill",
            "Shapes": "triangle.fill",
            "Emotions": "face.smiling",
            "Ice Hockey": "figure.ice.hockey",
            "Statues": "figure.stand",
            "Gym": "figure.indoor.cycle",
            "Running": "figure.run"
        ]
        // Create the tags array in the exact order defined above.
        let tagGroup1 = [
            "Sport", "Animals", "Music", "Food", "Nature", "Geography", "History", "Science", "Gaming", "Celebrities"
        ]

        let tagGroup2 = [
            "Art", "Cars", "Football", "Fruit", "Soda", "Mammals", "Flowers", "Movies", "Instruments", "Politics"
        ]

        let tagGroup3 = [
            "Basketball", "Vegetables", "Alcohol", "Birds", "Trees", "Shows", "Festivals", "Planets", "Tennis", "Pizza"
        ]

        let tagGroup4 = [
            "Coffee", "Dogs", "Social Media", "Albums", "Actors", "Travel", "Motorsport", "Eggs", "Cats", "Books"
        ]

        let tagGroup5 = [
            "Musicians", "Australian Football", "Fast Food", "Fish", "Board Games", "Numbers", "Relationships",
            "American Football", "Pasta", "Reptiles"
        ]

        let tagGroup6 = [
            "Card Games", "Letters", "Baseball", "Ice Cream", "Bugs", "Memes", "Shapes", "Emotions",
            "Ice Hockey", "Statues", "Gym", "Running"
        ]

        let tags = tagGroup1 + tagGroup2 + tagGroup3 + tagGroup4 + tagGroup5 + tagGroup6
        
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferences (Pick 1-3)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 5)
                
                Text("Pick a few categories you are interested in:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Divider()
                    .foregroundColor(.gray)
                
                // 3) Use your FlexibleView layout to arrange chips in rows:
                FlexibleView(spacing: 8, alignment: .leading) {
                    ForEach(tags, id: \.self) { tag in
                        let isSelected = selection.contains(tag)
                        
                        ChipView(tag, isSelected: isSelected, mapping: localTagIconMapping)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isSelected {
                                        // Deselect if already selected
                                        selection.removeAll { $0 == tag }
                                    } else if selection.count < 3 {
                                        // Only allow a new selection if fewer than 3 are chosen
                                        selection.append(tag)
                                    }
                                }
                                // Always write back to user_data.userInterests in AppStorage
                                user_data.userInterests = selection.joined(separator: ", ")
                            }
                            .opacity(
                                // Dim it if it's not already selected and we've already picked 3
                                (!isSelected && selection.count >= 3) ? 0.4 : 1.0
                            )
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, -5)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                
                Spacer(minLength: 0)
            }
            .padding(15)
        }
        .navigationTitle("Chips Selection")
    }
}

fileprivate struct RemoveSheetShadow: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let shadowView = view.dropShadowView {
                shadowView.layer.shadowColor = UIColor.clear.cgColor
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

extension UIView {
    var dropShadowView: UIView? {
        if let superview, String(describing: type(of: superview)) == "UIDropShadowView" {
            return superview
        }
        
        return superview?.dropShadowView
    }
}

/// View 1 Mock Data
struct Action: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var image: String
    var title: String
}

let actions: [Action] = [
    .init(image: "message.fill", title: "Social Media"),
    .init(image: "person.2.fill", title: "People"),
    .init(image: "bubble.left.and.text.bubble.right.fill", title: "Forums"),
    .init(image: "storefront.fill", title: "App Store"),
    .init(image: "questionmark.app.fill", title: "Other"),
    .init(image: "face.smiling.fill", title: "No Idea"),
]

/// View 2 Mock Data
struct Period: Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var value: Int
}

let periods: [Period] = [
    .init(title: "1", value: 1),
    .init(title: "3", value: 3),
    .init(title: "5", value: 5),
    .init(title: "7", value: 7),
    .init(title: "9", value: 9),
    .init(title: "Custom", value: 0),
]

/// View 3 Mock Data
struct KeyPad: Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var value: Int
    var isBack: Bool = false
}

/// Custom keypad data ranges from 0 to 9 and includes a back button
let keypadValues: [KeyPad] = (1...9).compactMap({ .init(title: String("\($0)"), value: $0) }) + [
    .init(title: "0", value: 0),
    .init(title: "chevron.left", value: -1, isBack: true)
]

struct ChipsView<Content: View, Tag: Equatable>: View where Tag: Hashable {
    var spacing: CGFloat = 10
    var animation: Animation = .easeInOut(duration: 0.2)
    var tags: [Tag]
    @ViewBuilder var content: (Tag, Bool) -> Content
    var didChangeSelection: ([Tag]) -> ()
    
    @State private var selectedTags: [Tag] = []
    
    var body: some View {
        CustomChipLayout(spacing: spacing) {
            ForEach(tags, id: \.self) { tag in
                content(tag, selectedTags.contains(tag))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(animation) {
                            if selectedTags.contains(tag) {
                                selectedTags.removeAll { $0 == tag }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                        didChangeSelection(selectedTags)
                    }
            }
        }
    }
}

fileprivate struct CustomChipLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return .init(width: width, height: maxHeight(proposal: proposal, subviews: subviews))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        
        for subview in subviews {
            let fitSize = subview.sizeThatFits(proposal)
            
            if (origin.x + fitSize.width) > bounds.maxX {
                origin.x = bounds.minX
                origin.y += fitSize.height + spacing
                subview.place(at: origin, proposal: proposal)
                origin.x += fitSize.width + spacing
            } else {
                subview.place(at: origin, proposal: proposal)
                origin.x += fitSize.width + spacing
            }
        }
    }
    
    private func maxHeight(proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        var origin: CGPoint = .zero
        
        for subview in subviews {
            let fitSize = subview.sizeThatFits(proposal)
            if (origin.x + fitSize.width) > (proposal.width ?? 0) {
                origin.x = 0
                origin.y += fitSize.height + spacing
                origin.x += fitSize.width + spacing
            } else {
                origin.x += fitSize.width + spacing
            }
            if subview == subviews.last {
                origin.y += fitSize.height
            }
        }
        return origin.y
    }
}

@ViewBuilder
func ChipView(_ tag: String, isSelected: Bool, mapping: [String: String]) -> some View {
    HStack(spacing: 10) {
        if let iconName = mapping[tag] {
            Image(systemName: iconName)
                .foregroundStyle(isSelected ? .white : Color.primary)
        }
        
        Text(tag)
            .font(.callout)
            .foregroundStyle(isSelected ? .white : Color.primary)
        
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background {
        ZStack {
            Capsule()
                .fill(Color(.systemBackground))
                .opacity(isSelected ? 0 : 1)
                .shadow(radius: 2)
            Capsule()
                .fill(LinearGradient(gradient: Gradient(colors: [.orange]), startPoint: .leading, endPoint: .trailing))
                .opacity(isSelected ? 1 : 0)
                .shadow(radius: 2)
        }
    }
}

