//
//  Navigation.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 3/7/2025.
//

import SwiftUI
import UIKit
import FirebaseAnalytics
import Combine
import FirebaseDatabase

// MARK: - Main Tab-based Navigation Layout
struct MainTabView: View {
    
    @State private var activeTab: TabModel = .explore
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .home:
                    HomeView()
                case .explore:
                    ExploreView()
                case .profile:
                    ProfileView()
                case .settings:
                    SettingsView()
                }  
            }
            .ignoresSafeArea(.all)
            CurvedTabBarView(activeTab: $activeTab)
                .keyboardHeightEnvironmentValue()
        }
    }
}




struct KeyboardDiagnosticsView: View {
    @StateObject private var kb = KeyboardMonitor()
    @State private var text: String = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Header stats
            VStack(spacing: 8) {
                Text("Keyboard Diagnostics")
                    .font(.system(size: 22, weight: .bold))
                HStack(spacing: 16) {
                    Stat("Visible", kb.isVisible ? "Yes" : "No")
                    Stat("Height", "\(Int(kb.height)) pt")
                    Stat("Anim", String(format: "%.2fs", kb.animationDuration))
                }
                .font(.system(.caption, design: .rounded))
                
                // Current frames (screen coordinates)
                Text("End Frame: \(rectString(kb.endFrame))")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                Text("Begin Frame: \(rectString(kb.beginFrame))")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            
            Divider()
            
            // Controls
            HStack {
                Button("Focus Text") { focused = true }
                Button("Dismiss")     { hideKeyboard() }
                Spacer()
                Button("Clear Log")   { kb.events.removeAll() }
            }
            .buttonStyle(.bordered)
            
            // Text box (to summon the keyboard)
            TextField("Type here…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .padding(.horizontal)
            
            // Event log
            List(kb.events.reversed()) { evt in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(evt.name).bold()
                        Spacer()
                        Text(evt.time, style: .time)
                            .foregroundStyle(.secondary)
                    }
                    Text("begin: \(rectString(evt.begin))  end: \(rectString(evt.end))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("duration: \(String(format: "%.2f", evt.duration))s  curve: \(evt.curve.rawValue)  local: \(evt.isLocal?.description ?? "-")")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            .listStyle(.plain)
        }
        .padding(.bottom, max(0, kb.height - kb.safeAreaBottomInset)) // keep content visible
        .animation(.easeInOut(duration: kb.animationDuration), value: kb.height)
        .navigationTitle("Keyboard Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func hideKeyboard() {
        focused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// Small stat pill
private func Stat(_ title: String, _ value: String) -> some View {
    VStack {
        Text(title).font(.caption2).foregroundStyle(.secondary)
        Text(value).font(.headline)
    }
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
}

// Format CGRect nicely
private func rectString(_ r: CGRect) -> String {
    "[x:\(Int(r.origin.x)) y:\(Int(r.origin.y)) w:\(Int(r.size.width)) h:\(Int(r.size.height))]"
}

// MARK: - Keyboard monitor

final class KeyboardMonitor: ObservableObject {
    // Published diagnostics
    @Published var height: CGFloat = 0
    @Published var beginFrame: CGRect = .zero
    @Published var endFrame: CGRect = .zero
    @Published var animationDuration: Double = 0.25
    @Published var isVisible: Bool = false
    @Published var events: [KBEvent] = []
    
    // Safe-area bottom inset (for padding calc)
    var safeAreaBottomInset: CGFloat {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
        #else
        return 0
        #endif
    }
    
    private var bag = Set<AnyCancellable>()
    
    init() {
        let names: [Notification.Name] = [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardDidShowNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification,
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardDidChangeFrameNotification
        ]
        
        let center = NotificationCenter.default
        names.forEach { name in
            center.publisher(for: name)
                .sink { [weak self] in self?.handle($0) }
                .store(in: &bag)
        }
    }
    
    private func handle(_ note: Notification) {
        let ui = note.userInfo ?? [:]
        
        let begin = (ui[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect) ?? .zero
        let end   = (ui[UIResponder.keyboardFrameEndUserInfoKey]   as? CGRect) ?? .zero
        let dur   = (ui[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (ui[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeInOut.rawValue
        let curve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeInOut
        let local = (ui[UIResponder.keyboardIsLocalUserInfoKey] as? Bool)
        
        // Calculate effective on-screen height (accounts for floating/undocked)
        let effectiveHeight = Self.effectiveHeight(from: end)
        
        // Update state on main queue
        DispatchQueue.main.async {
            self.beginFrame = begin
            self.endFrame = end
            self.animationDuration = dur
            self.height = effectiveHeight
            self.isVisible = effectiveHeight > 0.0
            
            let event = KBEvent(name: Self.friendlyName(note.name),
                                time: Date(),
                                begin: begin,
                                end: end,
                                duration: dur,
                                curve: curve,
                                isLocal: local)
            self.events.append(event)
            
            // Also print to Xcode console
            print("[KB] \(event.name)  height=\(Int(effectiveHeight))  begin=\(begin)  end=\(end) dur=\(String(format: "%.2f", dur)) curve=\(curve.rawValue) local=\(local?.description ?? "-")")
        }
    }
    
    private static func friendlyName(_ name: Notification.Name) -> String {
        switch name {
        case UIResponder.keyboardWillShowNotification:        return "keyboardWillShow"
        case UIResponder.keyboardDidShowNotification:         return "keyboardDidShow"
        case UIResponder.keyboardWillHideNotification:        return "keyboardWillHide"
        case UIResponder.keyboardDidHideNotification:         return "keyboardDidHide"
        case UIResponder.keyboardWillChangeFrameNotification: return "keyboardWillChangeFrame"
        case UIResponder.keyboardDidChangeFrameNotification:  return "keyboardDidChangeFrame"
        default: return name.rawValue
        }
    }
    
    private static func effectiveHeight(from end: CGRect) -> CGFloat {
        #if canImport(UIKit)
        let screen = UIScreen.main.bounds
        guard end.intersects(screen) else { return 0 }
        // when docked: height = screen.maxY - end.minY; when hidden: 0
        return max(0, screen.maxY - max(end.minY, 0))
        #else
        return end.height
        #endif
    }
}

// MARK: - Event model

struct KBEvent: Identifiable {
    let id = UUID()
    let name: String
    let time: Date
    let begin: CGRect
    let end: CGRect
    let duration: Double
    let curve: UIView.AnimationCurve
    let isLocal: Bool?
}

// MARK: - Preview

struct KeyboardDiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            KeyboardDiagnosticsView()
        }
        .preferredColorScheme(.dark)
    }
}


struct CurvedTabBarShape: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        let height: CGFloat = 37.0
        let depth: CGFloat = height * 1.2  // Increase depth here
        let path = UIBezierPath()
        let centerWidth = rect.width / 2
        
        path.move(to: CGPoint(x: 0, y: 0)) // start top left
        path.addLine(to: CGPoint(x: (centerWidth - height * 2), y: 0)) // start of curve
        
        // First half of the dip
        path.addCurve(
            to: CGPoint(x: centerWidth, y: depth), // deeper dip
            controlPoint1: CGPoint(x: (centerWidth - 30), y: 0),
            controlPoint2: CGPoint(x: centerWidth - 35, y: depth)
        )
        
        // Second half of the dip
        path.addCurve(
            to: CGPoint(x: (centerWidth + height * 2), y: 0),
            controlPoint1: CGPoint(x: centerWidth + 40, y: depth),
            controlPoint2: CGPoint(x: (centerWidth + 25), y: 0)
        )
        
        path.addLine(to: CGPoint(x: rect.width, y: 0)) // finish top edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height)) // down right
        path.addLine(to: CGPoint(x: 0, y: rect.height)) // down left
        path.close()

        return Path(path.cgPath)
    }
}

struct CreateRankoButtons: Identifiable {
    let id = UUID()
    let name: String
    let shakeVariable: String
    let icon: String
    let iconFrame: CGFloat
}

struct CurvedTabBarView: View {
    @StateObject private var user_data = UserInformation.shared
    @FocusState private var rankoNameFocus: Bool
    @FocusState private var descriptionFocus: Bool
    @Namespace private var transition
    let activeTab: Binding<TabModel>
    @State private var currentView: AnyView? = nil
    @State private var showCreateSheet = false
    @State private var showOverlay = false
    @State private var nextButtonString: String = "Start"
    @State private var currentTab: String = "Name"
    @State private var rankoName: String = ""
    @State private var rankoDescription: String = ""
    @State private var rankoPrivacy: Bool = false
    @State private var bottomSafeInset: CGFloat = 0
    @State private var windowRef: UIWindow?
    @State private var kbAnimDuration: Double = 0.3   // slow + smooth
    @State private var kbAnimCurve: UIView.AnimationCurve = .easeInOut
    @State private var animatedHeight: CGFloat = 0
    @StateObject private var repo = CategoryRepo()
    @State private var localSelection: SampleCategoryChip? = nil
    @State private var expandedParentID: String? = nil
    @State private var expandedSubID: String? = nil
    @State private var rankoNameShake: CGFloat = 0
    @State private var categoryShake: CGFloat = 0
    @State private var layoutShake: CGFloat = 0
    @State private var selectedPath: [String] = []
    
    let buttons: [CreateRankoButtons] = [
        .init(name: "Help", shakeVariable: "", icon: "questionmark", iconFrame: 14),
        .init(name: "Name", shakeVariable: "rankoNameShake", icon: "textformat", iconFrame: 20),
        .init(name: "Description", shakeVariable: "", icon: "text.word.spacing", iconFrame: 18),
        .init(name: "Category", shakeVariable: "categoryShake", icon: "tag.fill", iconFrame: 16),
        .init(name: "Privacy", shakeVariable: "", icon: "lock.fill", iconFrame: 16),
        .init(name: "Layout", shakeVariable: "layoutShake", icon: "square.grid.2x2.fill", iconFrame: 16),
    ]
    
    private func ancestorsPath(to id: String) -> [String] {
        var path: [String] = [id]
        var cur = id
        while let p = repo.parentByChild[cur] {
            path.append(p)
            cur = p
        }
        return path.reversed()
    }
    
    private func shakeValue(for varName: String) -> CGFloat {
        switch varName {
        case "rankoNameShake": return rankoNameShake
        case "categoryShake":  return categoryShake
        case "layoutShake":    return layoutShake
        default:               return 0
        }
    }

    // plug your palette here if you have one
    let categoryChipIconColors: [String: Color] = [:]

    private var displayedChips: [SampleCategoryChip] {
        var flat = repo.topLevelChips
        guard let pid = expandedParentID,
              let pIdx = flat.firstIndex(where: { $0.id == pid })
        else { return flat }

        // insert level-1 after parent
        let level1 = repo.subChips(for: pid, parentLevel: 0)
        flat.insert(contentsOf: level1, at: pIdx + 1)

        // insert level-2 after the expanded sub
        if let sid = expandedSubID,
           let sIdx = flat.firstIndex(where: { $0.id == sid }),
           repo.hasSubs(sid) {
            let level2 = repo.subChips(for: sid, parentLevel: 1)
            flat.insert(contentsOf: level2, at: sIdx + 1)
        }
        return flat
    }
    
    private func sheetHeightAboveKeyboard(for currentTab: String) -> CGFloat {
        switch currentTab {
        case "Help": return 140
        case "Name": return 158.2
        case "Description": return 192.6
        case "Category": return 300
        case "Privacy": return 125
        case "Layout": return 300
        default: return 125
        }
    }
    
    private var sheetHeightTarget: CGFloat {
        CGFloat(user_data.deviceKeyboardHeight) + bottomSafeInset
        + sheetHeightAboveKeyboard(for: currentTab)
    }

    var body: some View {
        ZStack {
            VStack {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            print("Height of Screen is: \(geometry.size.height)")
                            print("Width of Screen is: \(geometry.size.width)")
                            user_data.deviceHeight = Int(geometry.size.height)
                            user_data.deviceWidth = Int(geometry.size.width)
                        }
                        .fixedSize(horizontal: false, vertical: false)
                }
            }
            VStack {
                Spacer()
                
                ZStack {
                    CurvedTabBarShape()
                        .fill(.white)
                        .frame(height: 80)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                        )
                        .shadow(color: Color(hex: 0x000000).opacity(0.1), radius: 6)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .blur(radius: 14, opaque: false)
                                .offset(y: -26)
                        }
                    
                    HStack {
                        ForEach(TabModel.allCases, id: \.rawValue) { tab in
                            tabButton(icon: tab.rawValue, tab: tab)
                            if tab != TabModel.allCases.last {
                                if tab == TabModel.allCases[1] {
                                    Spacer().frame(width: 80)
                                } else {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    
                    Button {
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .heavy))
                        }
                        .frame(width: 30, height: 30)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 3)
                    }
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF9864), Color(hex: 0xFCB34D)]),
                                               startPoint: .top,
                                               endPoint: .bottom
                                              )
                            )
                    )
                    .tint(Color(hex: 0xFFB654))
                    .buttonStyle(.glassProminent)
                    .offset(y: -32)
                    
                    Button {
                        withAnimation {
                            showCreateSheet = true
                            rankoName = ""
                            rankoDescription = ""
                            localSelection = nil
                            expandedParentID = nil
                            expandedSubID = nil
                            currentTab = "Help"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .heavy))
                        }
                        .frame(width: 30, height: 30)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 3)
                    }
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFF9864), Color(hex: 0xFCB34D)]),
                                               startPoint: .top,
                                               endPoint: .bottom
                                              )
                            )
                    )
                    .tint(Color(hex: 0xFFB654))
                    .buttonStyle(.glassProminent)
                    .matchedTransitionSource(
                        id: "newRankoButton", in: transition
                    )
                    .mask(Circle())
                    .offset(y: -32)
                }
            }
            if showCreateSheet {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .transition(.opacity)
                    
                    // top bar overlay with Cancel
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showCreateSheet = false
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.custom("Nunito-Bold", size: 20))
                            }
                            .foregroundStyle(Color(hex: 0xFFFFFF))
                            .tint(Color(hex: 0x252A2F))
                            .buttonStyle(.glassProminent)
                            
                            Spacer()
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    
                    // SHEET
                    VStack(spacing: 0) {
                        // MARK: - Top Indicator - 30pt
                        ZStack {
                            HStack {
                                let fieldH: CGFloat = 40
                                let vInset: CGFloat = 8
                                let hInset: CGFloat = 20
                                let fontSize: CGFloat = max(14, (fieldH - 2*vInset) / 1.2)
                                VStack {
                                    Text("Cancel")
                                        .font(.custom("Nunito-Black", size: fontSize))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, hInset)
                                        .padding(.vertical, vInset)
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0x1B2024)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .frame(height: fieldH)
                                .onTapGesture {
                                    withAnimation {
                                        showCreateSheet = false
                                    }
                                }
                                Spacer(minLength: 0)
                                VStack {
                                    Text(nextButtonString)
                                        .font(.custom("Nunito-Black", size: fontSize))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, hInset)
                                        .padding(.vertical, vInset)
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0x1B2024)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .frame(height: fieldH)
                                .onTapGesture {
                                    if currentTab == "Help" {
                                        withAnimation {
                                            currentTab = "Name"
                                        }
                                    } else if currentTab == "Name" {
                                        if rankoName.isEmpty {
                                            print("FUCK NO, NAME IS EMPTY")
                                            withAnimation { rankoNameShake += 1 }
                                        } else {
                                            withAnimation {
                                                currentTab = "Description"
                                            }
                                        }
                                    } else if currentTab == "Description" {
                                        if rankoName.isEmpty {
                                            print("FUCK NO, NAME IS EMPTY")
                                            withAnimation { rankoNameShake += 1 }
                                        } else {
                                            withAnimation {
                                                currentTab = "Category"
                                            }
                                        }
                                    } else if currentTab == "Category" {
                                        if localSelection == nil && rankoName.isEmpty {
                                            print("FUCK NO, NAME & CATEGORY IS EMPTY")
                                            withAnimation {
                                                rankoNameShake += 1
                                                categoryShake += 1
                                            }
                                        } else if localSelection == nil {
                                            print("FUCK NO, CATEGORY IS EMPTY")
                                            withAnimation { categoryShake += 1 }
                                        } else if rankoName.isEmpty {
                                            print("FUCK NO, NAME IS EMPTY")
                                            withAnimation { rankoNameShake += 1 }
                                        } else {
                                            withAnimation {
                                                currentTab = "Privacy"
                                            }
                                        }
                                    } else if currentTab == "Privacy" {
                                        if localSelection == nil && rankoName.isEmpty {
                                            print("FUCK NO, NAME & CATEGORY IS EMPTY")
                                            withAnimation {
                                                rankoNameShake += 1
                                                categoryShake += 1
                                            }
                                        } else if localSelection == nil {
                                            print("FUCK NO, CATEGORY IS EMPTY")
                                            withAnimation { categoryShake += 1 }
                                        } else if rankoName.isEmpty {
                                            print("FUCK NO, NAME IS EMPTY")
                                            withAnimation { rankoNameShake += 1 }
                                        } else {
                                            withAnimation {
                                                currentTab = "Layout"
                                            }
                                        }
                                    } else if currentTab == "Layout" {
                                        
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                            .offset(y: -50)
                            
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray)
                                    .frame(width: 50, height: 2)
                                Spacer(minLength: 0)
                            }
                            .frame(height: 30)
                        }
                        .frame(height: 35)
                        
                        // MARK: - Padding - 10pt
                        Rectangle().fill(.clear).frame(height: 10)
                        
                        // MARK: - Buttons - 35pt
                        HStack(spacing: 35) {
                            ForEach(buttons) { button in
                                Button {
                                    print("\(button.name) is opened")
                                    currentTab = button.name
                                    rankoNameFocus   = (button.name == "Name")
                                    descriptionFocus = (button.name == "Description")
                                    animateSheetHeight()
                                } label: {
                                    Image(systemName: button.icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: button.iconFrame, height: button.iconFrame)
                                        .fontWeight(.black)
                                        .foregroundStyle(
                                            currentTab == button.name ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white)
                                                .opacity(currentTab == button.name ? 1 : 0)
                                                .frame(width: 30, height: 30)
                                        )
                                }
                                .buttonStyle(.plain)
                                .modifier(ShakeEffect(travelDistance: 4, shakesPerUnit: 3, animatableData: shakeValue(for: button.shakeVariable)))
                            }
                            Button {
                                print("Ranko is \(rankoPrivacy ? "Private" : "Public")")
                                withAnimation {
                                    rankoPrivacy.toggle()
                                }
                            } label: {
                                Image(systemName: rankoPrivacy ? "lock.fill" : "lock.open.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .fontWeight(.black)
                                    .foregroundStyle(Color(hex: 0xFFFFFF))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 35)
                        .padding(.horizontal)
                        
                        // MARK: - Padding - 20pt
                        Rectangle().fill(.clear).frame(height: 20)
                        
                        // MARK: - Content area swaps by tab
                        Group {
                            if currentTab == "Help" {
                                VStack {
                                    Spacer(minLength: 0)
                                    Text("Welcome to RankoCreate")
                                        .font(.custom("Nunito-Black", size: 21))
                                        .foregroundColor(.white)
                                    Spacer(minLength: 0)
                                    Text("Let's create your new Ranko. Before we get started, there's just a few things to set up")
                                        .font(.custom("Nunito-Bold", size: 16))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    Spacer(minLength: 0)
                                    Text("If the keyboard is obstructing your view at any time or any other issues, please hold the 'X' button to the left for 3 seconds")
                                        .font(.custom("Nunito-Bold", size: 16))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    Spacer(minLength: 0)
                                    Text("Click Get Started to begin")
                                        .font(.custom("Nunito-Bold", size: 16))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    Spacer(minLength: 0)
                                    Spacer(minLength: 0)
                                    VStack {
                                        Text("Get Started")
                                            .font(.custom("Nunito-Black", size: 28))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .glassEffect(.regular.interactive().tint(Color(hex: 0x1B2024)), in: RoundedRectangle(cornerRadius: 20))
                                            .frame(height: 40)
                                    }
                                    .onTapGesture {
                                        withAnimation {
                                            currentTab = "Name"
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 30)
                            }
                            if currentTab == "Name" {
                                // MARK: - Ranko Name Field - 43.2pt
                                
                                let fieldH: CGFloat = 43.2
                                let vInset: CGFloat = 12
                                let hInset: CGFloat = 14
                                let fontSize: CGFloat = max(14, (fieldH - 2*vInset) / 1.2)
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: 0x252A2F))
                                    
                                    TextField(
                                        "",
                                        text: $rankoName,
                                        prompt: Text("Enter Name: eg. 'Top 20 Countries I Want To Visit'")
                                            .foregroundStyle(Color(hex: 0xFFFFFF).opacity(0.5))
                                    )
                                    .font(.custom("Nunito-Bold", size: fontSize))
                                    .foregroundColor(.white)
                                    .padding(.leading, hInset)
                                    .focused($rankoNameFocus)
                                    .frame(maxHeight: .infinity)
                                    .textFieldStyle(.plain)
                                    .onSubmit { currentTab = "Description" }
                                    .lineLimit(1)
                                    .contentShape(Rectangle())
                                    .colorScheme(.dark)
                                }
                                .frame(height: fieldH)
                                .padding(.horizontal)
                                // nice appear/disappear
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                            } else if currentTab == "Description" {
                                // MARK: - Ranko Description Field - ((16 font * 1.2 row spacing) * 3 lines) + (10 vertical spacing * 2 top & bottom) = 77.6pt
                                
                                let fieldVInset: CGFloat = 10
                                let fieldHInset: CGFloat = 14
                                let fontSize: CGFloat    = 16
                                let lineHeight: CGFloat  = fontSize * 1.2
                                let minH: CGFloat        = 40
                                let maxH: CGFloat        = fieldVInset*2 + lineHeight*3  // room for 3 lines
                                
                                ZStack(alignment: .topLeading) {
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(hex: 0x252A2F))
                                            .onAppear {
                                                print("Height of Description Field: \(geo.size.height)")
                                            }
                                    }
                                    
                                    TextField(
                                        "",
                                        text: $rankoDescription,
                                        prompt: Text("Add a short description… (optional)")
                                            .foregroundStyle(Color(hex: 0xFFFFFF).opacity(0.5)), axis: .vertical
                                    )
                                    .font(.custom("Nunito-Bold", size: fontSize))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, fieldHInset)
                                    .padding(.vertical, fieldVInset)
                                    .focused($descriptionFocus)
                                    .textFieldStyle(.plain)
                                    .colorScheme(.dark)
                                    .multilineTextAlignment(.leading)
                                    .onSubmit {
                                        
                                    }
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                                .frame(minHeight: minH, maxHeight: maxH)
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                            } else if currentTab == "Category" {
                                ScrollView {
                                    if let err = repo.loadError {
                                        Text(err).foregroundColor(.red).font(.footnote)
                                    }

                                    FlowLayout(spacing: 8) {
                                        ForEach(displayedChips) { chip in
                                            let isSelected = selectedPath.contains(chip.id)
                                            SampleCategoryChipButtonView(
                                                categoryChip: chip,
                                                isSelected: isSelected,
                                                color: .accentColor
                                            ) {
                                                handleChipTap(chip)
                                            }
                                        }
                                    }
                                    .task { repo.loadOnce() }
                                    .padding(.horizontal, 16)
                                }
                            } else {
                                // other tabs (no purpose yet)
                                Spacer(minLength: 0)
                            }
                        }
                        
                        // MARK: - Padding - 20pt (keeps spacing consistent)
                        Rectangle().fill(.clear).frame(height: 20)
                        
                        Spacer()
                    }
                    .frame(
                        width: CGFloat(user_data.deviceWidth + 4),
                        height: animatedHeight
                    )
                    .onChange(of: currentTab) { oldTabName, newTabName in
                        animateSheetHeight()
                        print("From \(oldTabName) to \(newTabName)")
                        
                        if oldTabName == "Help" {
                            
                        } else if oldTabName == "Name" {
                            rankoNameFocus = false
                        } else if oldTabName == "Description" {
                            descriptionFocus = false
                        } else if oldTabName == "Category" {
                            
                        } else if oldTabName == "Privacy" {
                            
                        } else if oldTabName == "Layout" {
                            
                        }
                        
                        if newTabName == "Help" {
                            withAnimation {
                                nextButtonString = "Get Started"
                            }
                        } else if newTabName == "Name" {
                            rankoNameFocus = true
                            withAnimation {
                                nextButtonString = "Next"
                            }
                        } else if newTabName == "Description" {
                            descriptionFocus = true
                            if rankoDescription.isEmpty {
                                withAnimation {
                                    nextButtonString = "Skip"
                                }
                            } else {
                                withAnimation {
                                    nextButtonString = "Next"
                                }
                            }
                        } else if newTabName == "Category" {
                            withAnimation {
                                nextButtonString = "Next"
                            }
                        } else if newTabName == "Privacy" {
                            withAnimation {
                                nextButtonString = "Next"
                            }
                        } else if newTabName == "Layout" {
                            withAnimation {
                                nextButtonString = "Create"
                            }
                        }
                    }
                    .onAppear {
                        bottomSafeInset = KeyWindow.safeAreaBottom()
                        animatedHeight = sheetHeightTarget            // start at the correct height
                    }
                    .onChange(of: user_data.deviceKeyboardHeight) { _, _ in
                        bottomSafeInset = KeyWindow.safeAreaBottom()
                        animateSheetHeight()
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(hex: 0x1B2024))
                    )
                    // resolve actual window (unchanged)
                    .background(WindowReader { w in
                        windowRef = w
                    })
                    // keyboard listener (unchanged except your existing logic)
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                        guard let w = windowRef else { return }
                        let ui = note.userInfo ?? [:]

                        let end = (ui[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
                        let endInWindow = w.convert(end, from: nil)
                        let overlap = max(0, w.bounds.maxY - endInWindow.minY)
                        let effective = max(0, overlap - w.safeAreaInsets.bottom)

                        // update height state (no withAnimation here)
                        user_data.deviceKeyboardHeight = effective > 200 ? Int(effective) : user_data.deviceKeyboardHeight
                        // drive the sheet animation with your constant duration
                        animateSheetHeight()
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .edgesIgnoringSafeArea(.all)
    }
    
    private func handleChipTap(_ chip: SampleCategoryChip) {
        if let idx = selectedPath.firstIndex(of: chip.id) {
            // already selected → trim at this level (drop self + descendants)
            selectedPath = Array(selectedPath.prefix(idx))
        } else {
            // not selected → select full ancestor chain (keeps parents highlighted)
            selectedPath = ancestorsPath(to: chip.id)
        }

        // keep your old localSelection working for validations (nil means nothing picked)
        if let last = selectedPath.last {
            // level is pathDepth - 1
            localSelection = repo.chip(for: last, level: selectedPath.count - 1)
        } else {
            localSelection = nil
        }

        // (optional) keep your expansion logic exactly as before
        if repo.hasSubs(chip.id) {
            if chip.level == 0 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedParentID = (expandedParentID == chip.id) ? nil : chip.id
                    if expandedParentID == nil { expandedSubID = nil }
                }
            } else if chip.level == 1 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedSubID = (expandedSubID == chip.id) ? nil : chip.id
                }
            }
        }
    }
    
    private func animateSheetHeight(_ duration: Double? = nil) {
        withAnimation(.easeInOut(duration: duration ?? kbAnimDuration)) {
            animatedHeight = sheetHeightTarget
        }
    }

    private struct WindowReader: UIViewRepresentable {
        var onResolve: (UIWindow?) -> Void

        func makeUIView(context: Context) -> Probe {
            let v = Probe()
            v.onResolve = onResolve
            v.isUserInteractionEnabled = false
            v.backgroundColor = .clear
            return v
        }
        func updateUIView(_ uiView: Probe, context: Context) { }

        final class Probe: UIView {
            var onResolve: ((UIWindow?) -> Void)?
            override func didMoveToWindow() {
                super.didMoveToWindow()
                onResolve?(window)
            }
            override func layoutSubviews() {
                super.layoutSubviews()
                onResolve?(window)  // updates on rotation/resize
            }
        }
    }

    // MARK: - Curve → SwiftUI Animation

    private func swiftUIAnimation(from curve: UIView.AnimationCurve, duration: Double) -> Animation {
        switch curve {
        case .easeInOut: return .easeInOut(duration: duration)
        case .easeIn:    return .easeIn(duration: duration)
        case .easeOut:   return .easeOut(duration: duration)
        default:         return .linear(duration: duration)
        }
    }

    private func tabButton(icon: String, tab: TabModel) -> some View {
        Button(action: {
            activeTab.wrappedValue = tab
        }) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(activeTab.wrappedValue == tab ? Color(hex: 0xFFB654) : Color(hex: 0x857467))
                .frame(maxWidth: .infinity)
        }
    }
}

enum KeyWindow {
    static func safeAreaBottom() -> CGFloat {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return 0 }
        return window.safeAreaInsets.bottom
    }
}



struct SampleCategoryChip: Identifiable, Hashable {
    let id: String            // e.g. "music-music" or "music-artistsbands"
    var name: String
    var icon: String
    var synonyms: String?
    var level: Int = 0        // 0 = top-level, 1 = sub

    static func ==(lhs: SampleCategoryChip, rhs: SampleCategoryChip) -> Bool {
        lhs.id == rhs.id && lhs.level == rhs.level
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(level)
    }
}

// MARK: - Repo

final class CategoryRepo: ObservableObject {
    @Published var topLevelChips: [SampleCategoryChip] = []
    @Published var loadError: String? = nil

    // parent -> ordered children, child -> parent
    private(set) var subsByParent: [String: [String]] = [:]
    private(set) var parentByChild: [String: String] = [:]

    private var categoryDataRaw: [String: [String: Any]] = [:]
    private let db = Database.database().reference().child("AppData")

    // normalize DB id mismatches (per your JSON)
    private func alias(_ raw: String) -> String {
        switch raw {
        case "sport-sports":      return "sport-sport"
        case "people-musicians":  return "people-music-ans"
        default:                  return raw
        }
    }

    func loadOnce() {
        if !topLevelChips.isEmpty { return }
        let group = DispatchGroup()
        var rankoRaw: [String: [String: Any]] = [:]
        var firstError: String?

        group.enter()
        db.child("CategoryData").observeSingleEvent(of: .value) { snap in
            defer { group.leave() }
            guard let dict = snap.value as? [String: [String: Any]] else {
                firstError = "Failed to read AppData/CategoryData"; return
            }
            self.categoryDataRaw = dict
        }

        group.enter()
        db.child("CategoryRanko").observeSingleEvent(of: .value) { snap in
            defer { group.leave() }
            guard let dict = snap.value as? [String: [String: Any]] else {
                firstError = "Failed to read AppData/CategoryRanko"; return
            }
            rankoRaw = dict
        }

        group.notify(queue: .main) {
            if let err = firstError { self.loadError = err; return }
            self.parse(ranko: rankoRaw)
        }
    }

    private func parse(ranko: [String: [String: Any]]) {
        let orderedKeys = ranko.keys.sorted { (Int($0) ?? 9_999) < (Int($1) ?? 9_999) }

        var topList: [SampleCategoryChip] = []
        var subs: [String: [String]] = [:]
        var parents: [String: String] = [:]

        func collectSubs(parentID: String, subDict: [String: [String: Any]]) {
            let ord = subDict.keys.sorted { (Int($0) ?? 9_999) < (Int($1) ?? 9_999) }
            let children = ord.compactMap { k -> String? in
                guard let raw = subDict[k]?["id"] as? String else { return nil }
                return alias(raw)
            }
            if !children.isEmpty {
                subs[parentID] = children
                children.forEach { parents[$0] = parentID }
            }
            // recurse if any child has its own "sub"
            for k in ord {
                guard let child = subDict[k],
                      let childRaw = child["id"] as? String,
                      let deeper = child["sub"] as? [String: [String: Any]]
                else { continue }
                collectSubs(parentID: alias(childRaw), subDict: deeper)
            }
        }

        for k in orderedKeys {
            guard let entry = ranko[k], let rawId = entry["id"] as? String else { continue }
            let root = alias(rawId)
            topList.append(chip(for: root, level: 0))
            if let sub = entry["sub"] as? [String: [String: Any]] {
                collectSubs(parentID: root, subDict: sub)
            }
        }

        self.topLevelChips = topList
        self.subsByParent  = subs
        self.parentByChild = parents
    }

    func hasSubs(_ parentID: String) -> Bool { !(subsByParent[parentID] ?? []).isEmpty }

    // IMPORTANT: pass the parent's level so we set correct depth on children
    func subChips(for parentID: String, parentLevel: Int) -> [SampleCategoryChip] {
        (subsByParent[parentID] ?? []).map { chip(for: $0, level: parentLevel + 1) }
    }

    func chip(for id: String, level: Int) -> SampleCategoryChip {
        let d = categoryDataRaw[id]
        let name = (d?["name"] as? String) ?? id.split(separator: "-").last.map(String.init)?.replacingOccurrences(of: "_", with: " ").capitalized ?? id
        let icon = (d?["icon"] as? String) ?? "square.grid.2x2"
        let synonyms = d?["synonyms"] as? String
        return SampleCategoryChip(id: id, name: name, icon: icon, synonyms: synonyms, level: level)
    }
}

// MARK: - Chip Button (unchanged except small tweak for sub styling optional)

struct SampleCategoryChipButtonView: View {
    let categoryChip: SampleCategoryChip
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    private func bgOpacity(_ level: Int) -> Double {
        switch level { case 0: return 0.10; case 1: return 0.22; default: return 0.34 }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: safeSymbol(categoryChip.icon))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: 0x1B2024) : Color(hex: 0xFFFFFF))
                Text(categoryChip.name)
                    .font(.custom("Nunito-Black", size: 16))
                    .foregroundStyle(isSelected ? Color(hex: 0x1B2024) : Color(hex: 0xFFFFFF))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 1 : bgOpacity(categoryChip.level)))
            )
        }
        .buttonStyle(.plain)
    }

    private func safeSymbol(_ name: String) -> String {
        if UIImage(systemName: name) != nil { return name }
        let alias: [String: String] = ["movieclapper": "clapperboard.fill",
                                       "music-microphone": "music.mic",
                                       "quote.opening": "quote.bubble"]
        return alias[name].flatMap { UIImage(systemName: $0) != nil ? $0 : nil } ?? "square.grid.2x2"
    }
}

/// The custom tab bar with a matched geometry effect.
struct CustomTabBar: View {
    @State private var trayViewOpen: Bool
    // Use the same stored string for the tint.
    @AppStorage("app_colour") private var appColourString: String = ".orange"
    @StateObject private var user_data = UserInformation.shared
    var activeForeground: Color = .white

    @Binding var activeTab: TabModel
    @Namespace private var animation
    @State private var tabLocation: CGRect = .zero
    
    init(trayViewOpen: Bool = false, activeTab: Binding<TabModel>) {
        self._trayViewOpen = State(initialValue: trayViewOpen)
        self._activeTab   = activeTab
    }
    

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(TabModel.allCases, id: \.rawValue) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.rawValue)
                                .font(.title3)
                                .frame(width: 30, height: 30)
                            
                            if activeTab == tab {
                                Text(tab.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(activeTab == tab ? activeForeground : Color(hex: 0xFF9864))
                        .padding(.vertical, 2)
                        .padding(.leading, 10)
                        .padding(.trailing, 15)
                        .contentShape(Rectangle())
                        .background {
                            if activeTab == tab {
                                Capsule()
                                    .fill(Color.clear)
                                    .onGeometryChange(for: CGRect.self, of: {
                                        $0.frame(in: .named("TABBARVIEW"))
                                    }, action: { newValue in
                                        tabLocation = newValue
                                    })
                                    .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: 0xFF9864).gradient)
                    .frame(width: tabLocation.width, height: tabLocation.height)
                    .offset(x: tabLocation.minX)
            }
            .coordinateSpace(name: "TABBARVIEW")
            .padding(.horizontal, 5)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 5, y: 5)
                    .shadow(color: Color.black.opacity(0.06), radius: 5, x: -5, y: -5)
            )
            .zIndex(10)
            
            Button {
                trayViewOpen.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
                    .accentColor(.white)
                    .background(Color(hex: 0xFF9864).gradient)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 5)
            }
            .padding(.leading, 0)
        }
        .systemTrayView($trayViewOpen) {
            CreateNewRanko()
        }
        .padding(.bottom, 10)
        .animation(.smooth(duration: 0.3, extraBounce: 0), value: activeTab)
        .frame(maxWidth: .infinity)
    }
}

/// Tab identifiers and titles.
enum TabModel: String, CaseIterable {
    case home = "house.fill"
    case explore = "safari.fill"
    case profile = "person.fill"
    case settings = "gearshape.fill"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ProfileImageService())
}

// MARK: - Supporting Views & Models

/// A helper view to hide the tab bar on iOS 17 devices.
struct HideTabBar: UIViewRepresentable {
    init(result: @escaping () -> Void) {
        UITabBar.appearance().isHidden = true
        self.result = result
    }
    
    var result: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let tabController = view.tabController {
                UITabBar.appearance().isHidden = false
                tabController.tabBar.isHidden = true
                result()
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
}

extension UIView {
    var tabController: UITabBarController? {
        sequence(first: self, next: { $0.next })
            .first(where: { $0 is UITabBarController }) as? UITabBarController
    }
}



/// A custom view that morphs between symbols (requires KeyframeAnimator and CubicKeyframe implementations).
struct MorphingSymbolView: View {
    var symbol: String
    var config: Config
    
    @State private var trigger: Bool = false
    @State private var displayingSymbol: String = ""
    @State private var nextSymbol: String = ""
    
    var body: some View {
        Canvas { ctx, size in
            ctx.addFilter(.alphaThreshold(min: 0.4, color: config.foregroundColor))
            if let renderedImage = ctx.resolveSymbol(id: 0) {
                ctx.draw(renderedImage, at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            ImageView()
                .tag(0)
        }
        .onChange(of: symbol) { _, newValue in
            trigger.toggle()
            nextSymbol = newValue
        }
        .task {
            if displayingSymbol.isEmpty {
                displayingSymbol = symbol
            }
        }
    }
    
    @ViewBuilder
    func ImageView() -> some View {
        KeyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { radius in
            Image(systemName: displayingSymbol.isEmpty ? symbol : displayingSymbol)
                .font(config.font)
                .blur(radius: radius)
                .onChange(of: radius) { _, newValue in
                    if newValue.rounded() == config.radius {
                        withAnimation(config.symbolAnimation) {
                            displayingSymbol = nextSymbol
                        }
                    }
                }
        } keyframes: { _ in
            CubicKeyframe(config.radius, duration: config.keyFrameDuration)
            CubicKeyframe(0, duration: config.keyFrameDuration)
        }
    }
    
    struct Config {
        var font: Font
        var radius: CGFloat
        var foregroundColor: Color
        var keyFrameDuration: CGFloat = 0.4
        var symbolAnimation: Animation = .smooth(duration: 0.5, extraBounce: 0)
    }
}

