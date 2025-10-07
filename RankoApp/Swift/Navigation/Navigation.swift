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

extension String {
    var containsNoLetters: Bool {
        // Create a character set containing all letters (alphabetic characters)
        let letterCharacters = CharacterSet.letters

        // Invert the set to get a set containing all non-letter characters
        let nonLetterCharacters = letterCharacters.inverted

        // Check if the string contains any characters that are *not* letters
        // If it does, then it means it contains at least one non-letter character.
        // If it *doesn't* contain any non-letter characters, then it only contains letters.
        // We want to know if it contains *no* letters, so we check if the string
        // contains *only* characters from the nonLetterCharacters set.
        return CharacterSet(charactersIn: self).isSubset(of: nonLetterCharacters)
    }
}

struct CreateRankoButtons: Identifiable {
    let id = UUID()
    let name: String
    let shakeVariable: String
    let icon: String
    let iconFrame: CGFloat
    var enabled: Bool
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
    @State private var privacyVisible: Bool = true        // drive quick fade out/in
    @State private var privacyAnimKey = UUID()
    @State private var buttonsWidth: CGFloat = 0
    @State private var sheetWidth: CGFloat = 0
    @State private var tutorialMode: Bool = false
    @State private var tutorialIndex: Int = 0
    @State private var openRankoSheet: Bool = false
    @State private var nameTypingTask: Task<Void, Never>? = nil
    @State private var descriptionTypingTask: Task<Void, Never>? = nil
    @State private var savedRankoName: String? = nil
    @State private var savedRankoDescription: String? = nil
    @State private var savedSelectedPath: [String]? = nil
    @State private var savedSelectedLayoutName: String? = nil
    @State private var savedLocalSelectionID: String? = nil
    @State private var tutorialModeButtonsDisabled: Bool = false
    @State private var disableNextButton: Bool = false
    @State private var disableAllButtons: Bool = false
    
    private struct LayoutOption: Identifiable, Hashable {
        let id = UUID()
        let name: String          // "Default", "Tier", "Bracket", "Lineup"
        let shakeKey: String      // per-layout shake key
        let image: String         // asset name
        var enabled: Bool
    }

    @State private var selectedLayoutName: String? = nil

    // per-layout shake counters (works with your ShakeEffect)
    @State private var layoutShakes: [String: CGFloat] = [
        "Default": 0, "Tier": 0, "Bracket": 0, "Lineup": 0
    ]

    // Dictionary keyed by layout name, as requested
    @State private var layouts: [String: LayoutOption] = [
        "Default": LayoutOption(name: "Default", shakeKey: "Default", image: "Default", enabled: true),
        "Tier":    LayoutOption(name: "Tier",    shakeKey: "Tier",    image: "Tier",    enabled: true),
        "Bracket": LayoutOption(name: "Bracket", shakeKey: "Bracket", image: "Bracket", enabled: false),
        "Lineup":  LayoutOption(name: "Lineup",  shakeKey: "Lineup",  image: "Lineup",  enabled: false)
    ]

    private let layoutOrder = ["Default", "Tier", "Bracket", "Lineup"]
    
    private var layoutList: [LayoutOption] {
        layoutOrder.compactMap { layouts[$0] }
    }
    
    // If you need to toggle enabled state later:
    private func setLayoutEnabled(_ name: String, _ value: Bool) {
        if var opt = layouts[name] {
            opt.enabled = value
            layouts[name] = opt
        }
    }
    
    private func waitForChipsReadyAsync(maxWait: TimeInterval = 3.0) async {
        let start = Date()
        while repo.topLevelChips.isEmpty && Date().timeIntervalSince(start) < maxWait {
            try? await Task.sleep(nanoseconds: 80_000_000) // 0.08s poll
        }
    }
    
    @MainActor
    private func runCategoryTapSequenceAsync(
        for categoryID: String,
        initialDelay: TimeInterval = 0.25,   // slowed a bit
        stepDelay: TimeInterval = 0.45       // slowed a bit
    ) async {
        withAnimation { currentTab = "Category" }
        localSelection   = nil
        expandedParentID = nil
        expandedSubID    = nil
        selectedPath     = []

        repo.loadOnce()
        await waitForChipsReadyAsync()

        let steps = makeTapSequence(from: categoryID)

        // small kick-off pause so level-1 mounts before we tap
        try? await Task.sleep(nanoseconds: UInt64((0.10 + initialDelay) * 1_000_000_000))

        for id in steps {
            if Task.isCancelled { return }
            if let chip = chipByID(id) {
                withAnimation { handleChipTap(chip) }
            } else {
                print("⚠️ chip not found for id \(id)")
            }
            try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
        }
    }
    
    @MainActor
    private func runRandomAutofillAndFlowAsync() async {
        // lock UI + reset
        withAnimation {
            disableAllButtons = true
            currentTab = "Name"
            rankoName = ""
            rankoDescription = ""
            localSelection = nil
            expandedParentID = nil
            expandedSubID = nil
            selectedPath = []
        }

        // wait 0.2s before starting (as requested)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // pick sample
        let current = randomSamplePair()

        // 1) typewriter name (await until fully entered)
        await typewriterSetRankoNameAsync(current.name, perChar: 0.035, leadingDelay: 0.10)

        // 2) 0.4s pause
        try? await Task.sleep(nanoseconds: 400_000_000)

        // 3) run slower category tap sequence (await until done)
        await runCategoryTapSequenceAsync(for: current.category.id, initialDelay: 0.25, stepDelay: 0.45)

        // 4) 0.4s pause
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        withAnimation { currentTab = "Layout" }
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 5) pick layout with animation
        withAnimation { selectedLayoutName = "Tier" }

        // 6) 0.4s pause
        try? await Task.sleep(nanoseconds: 400_000_000)

        // 7) open ranko sheet and close create sheet
        openRankoSheet = true
        withAnimation { showCreateSheet = false }

        // unlock UI
        disableAllButtons = false
    }
    
    // Async forward typing you can await in a loop (keeps your existing sync version untouched)
    @MainActor
    private func typewriterSetRankoNameAsync(
        _ text: String,
        perChar: Double = 0.035,
        leadingDelay: Double = 0.10
    ) async {
        rankoName = ""
        try? await Task.sleep(nanoseconds: UInt64(leadingDelay * 1_000_000_000))
        for ch in text {
            if Task.isCancelled { return }
            withAnimation(.linear(duration: perChar)) {
                rankoName.append(ch)
            }
            try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
        }
    }

    // Async backspace (typewriter-in-reverse) until empty
    @MainActor
    private func typewriterBackspaceRankoNameAsync(
        perChar: Double = 0.035
    ) async {
        while !rankoName.isEmpty {
            if Task.isCancelled { return }
            rankoName.removeLast()
            try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
        }
    }

    // centralised cancel
    private func nameStopTyping() {
        nameTypingTask?.cancel()
        nameTypingTask = nil
    }

    // start the tutorial name demo loop (runs until tab changes or tutorialMode ends)
    private func startTutorialNameLoop() {
        nameStopTyping() // ensure only one loop
        nameTypingTask = Task { @MainActor in
            while tutorialMode && currentTab == "Name" && !Task.isCancelled {
                let pair = randomSamplePair()                 // uses your existing generator
                await typewriterSetRankoNameAsync(pair.name)  // type forward
                if Task.isCancelled || !tutorialMode || currentTab != "Name" { break }

                // wait 0.7s after completing the name
                try? await Task.sleep(nanoseconds: 700_000_000)

                // backspace to empty
                await typewriterBackspaceRankoNameAsync()
                if Task.isCancelled || !tutorialMode || currentTab != "Name" { break }
            }
        }
    }
    
    // Async forward typing you can await in a loop (keeps your existing sync version untouched)
    @MainActor
    private func typewriterSetDescriptionAsync(
        _ text: String,
        perChar: Double = 0.035,
        leadingDelay: Double = 0.10
    ) async {
        rankoDescription = ""
        try? await Task.sleep(nanoseconds: UInt64(leadingDelay * 1_000_000_000))
        for ch in text {
            if Task.isCancelled { return }
            withAnimation(.linear(duration: perChar)) {
                rankoDescription.append(ch)
            }
            try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
        }
    }

    // Async backspace (typewriter-in-reverse) until empty
    @MainActor
    private func typewriterBackspaceDescriptionAsync(
        perChar: Double = 0.035
    ) async {
        while !rankoDescription.isEmpty {
            if Task.isCancelled { return }
            rankoDescription.removeLast()
            try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
        }
    }
    
    private func descriptionStopTyping() {
        descriptionTypingTask?.cancel()
        descriptionTypingTask = nil
    }

    // start the tutorial name demo loop (runs until tab changes or tutorialMode ends)
    private func startTutorialDescriptionLoop() {
        descriptionStopTyping() // ensure only one loop
        descriptionTypingTask = Task { @MainActor in
            while tutorialMode && currentTab == "Description" && !Task.isCancelled {
                let pair = randomDescriptionPicker()                 // uses your existing generator
                await typewriterSetDescriptionAsync(pair)  // type forward
                if Task.isCancelled || !tutorialMode || currentTab != "Description" { break }

                // wait 0.7s after completing the name
                try? await Task.sleep(nanoseconds: 700_000_000)

                // backspace to empty
                await typewriterBackspaceDescriptionAsync()
                if Task.isCancelled || !tutorialMode || currentTab != "Description" { break }
            }
        }
    }
    
    // snapshot current inputs and clear working fields for the tutorial
    private func snapshotAndClearForTutorial() {
        // already backed up? don't double-overwrite
        if savedRankoName == nil && savedRankoDescription == nil && savedSelectedPath == nil && savedSelectedLayoutName == nil && savedLocalSelectionID == nil {
            savedRankoName          = rankoName
            savedRankoDescription   = rankoDescription
            savedSelectedPath       = selectedPath
            savedSelectedLayoutName = selectedLayoutName
            savedLocalSelectionID   = localSelection?.id
        }
        // clear live inputs while tutorial runs
        rankoName = ""
        rankoDescription = ""
        localSelection = nil
        expandedParentID = nil
        expandedSubID = nil
        selectedPath = []
        selectedLayoutName = nil
    }

    // restore inputs after tutorial ends
    private func restoreAfterTutorial() {
        if let n = savedRankoName { rankoName = n }
        if let d = savedRankoDescription { rankoDescription = d }
        if let l = savedSelectedLayoutName { selectedLayoutName = l }

        // try to rebuild localSelection from either saved id or last path component
        restoreCategorySelection(switchTabs: false, animate: false)

        // clear backups so a later tutorial run snapshots fresh values
        savedRankoName = nil
        savedRankoDescription = nil
        savedSelectedPath = nil
        savedSelectedLayoutName = nil
        savedLocalSelectionID = nil
    }
    
    private func restoreCategorySelection(switchTabs: Bool = false, animate: Bool = false) {
        // prefer the exact saved leaf id; fall back to the last element of the saved path
        guard let targetID = savedLocalSelectionID ?? savedSelectedPath?.last, !targetID.isEmpty else { return }

        repo.loadOnce()
        runWhenChipsReady {
            if animate {
                if switchTabs {
                    withAnimation { currentTab = "Category" }
                }
                // Reuse your existing runner (it uses makeTapSequence internally)
                runCategoryTapSequence(for: targetID) { /* no-op */ }
                return
            }

            // Instant restore (no UI switches)
            let steps = makeTapSequence(from: targetID)          // e.g. ["stem-stem","stem-science","stem-science-elements"]

            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPath = steps
                if let last = steps.last, let chip = chipByID(last) {
                    // level = depth-1; this matches how handleChipTap infers level
                    localSelection = repo.chip(for: chip.id, level: max(0, steps.count - 1))
                } else {
                    localSelection = nil
                }

                // keep the tree expanded to show the restored branch
                expandedParentID = steps.first
                expandedSubID    = steps.count >= 2 ? steps[1] : nil
            }
        }
    }

    /// One step = a description + a relative rect (0...1 in screen coords) + corner radius
    // MARK: - Spotlight model in ABSOLUTE POINTS (no ratios)
    private struct SpotlightStep: Equatable {
        var description: String
        var rect: CGRect
        var cornerRadius: CGFloat
    }

    // Easy-to-edit map: step -> spec
    // x/y are from the TOP-LEFT of the screen/container (in points).
    // width/height are literal points. No relation to screen size.
    private var tutorialSteps: [Int: SpotlightStep] {
        // convert once
        let screenW = CGFloat(user_data.deviceWidth)
        let screenH = CGFloat(user_data.deviceHeight)
        let kbdH    = CGFloat(user_data.deviceKeyboardHeight)
        
        let buttonsX = CGFloat((screenW - 279) / 2)
        let buttonsPrivacyY = CGFloat(screenH - bottomSafeInset - kbdH - 300 + 10 + 35 - 2) // SCREEN HEIGHT - BOTTOM SAFE INSET - KEYBOARD HEIGHT - HEIGHT ABOVE KEYBOARD + TOP INDICATOR + BUTTONS - PADDING
        
        let nameY = CGFloat(screenH - bottomSafeInset - kbdH - 300 + 10 + 35 + 10 + 43.2 - 2) // SCREEN HEIGHT - BOTTOM SAFE INSET - KEYBOARD HEIGHT - HEIGHT ABOVE KEYBOARD + TOP INDICATOR + BUTTONS + PADDING + NAME - PADDING
        let nameW = CGFloat(screenW - 28)
        
        let descriptionY = CGFloat(screenH - bottomSafeInset - kbdH - 300 + 10 + 35 + 10 + 40 - 2) // SCREEN HEIGHT - BOTTOM SAFE INSET - KEYBOARD HEIGHT - HEIGHT ABOVE KEYBOARD + TOP INDICATOR + BUTTONS + PADDING + NAME - PADDING
        let descriptionW = CGFloat(screenW - 20)
        
        let categoryY = CGFloat(screenH - bottomSafeInset - kbdH - 300 + 10 + 35 + 10 + 40 - 10) // SCREEN HEIGHT - BOTTOM SAFE INSET - KEYBOARD HEIGHT - HEIGHT ABOVE KEYBOARD + TOP INDICATOR + BUTTONS + PADDING + NAME - PADDING
        let categoryLayoutW = CGFloat(screenW - 20)
        
        let layoutY = CGFloat(screenH - bottomSafeInset - kbdH - 300 + 10 + 35 + 10 + 40 - 5) // SCREEN HEIGHT - BOTTOM SAFE INSET - KEYBOARD HEIGHT - HEIGHT ABOVE KEYBOARD + TOP INDICATOR + BUTTONS + PADDING + NAME - PADDING
        
        let privacyX = CGFloat(((screenW - 279) / 2) + 230)
        
        let finishX = CGFloat(screenW / 2)
        let finishY = CGFloat(screenH)
        
        return [
            0: .init(
                description: "this row lets you jump between Name, Description, Category and Layout.",
                rect: CGRect(x: buttonsX, y: buttonsPrivacyY, width: 279, height: 39),
                cornerRadius: 12
            ),
            1: .init(
                description: "give your ranko a clear, memorable name.",
                rect: CGRect(x: 14, y: nameY, width: nameW, height: 51.2),
                cornerRadius: 12
            ),
            2: .init(
                description: "add a short description for extra context (optional).",
                rect: CGRect(x: 10, y: descriptionY, width: descriptionW, height: 90),
                cornerRadius: 12
            ),
            3: .init(
                description: "pick a category. tap a chip to drill into subcategories.",
                rect: CGRect(x: 10, y: categoryY, width: categoryLayoutW, height: 300),
                cornerRadius: 12
            ),
            4: .init(
                description: "choose which Ranko layout you’d like to use, with many more coming soon.",
                rect: CGRect(x: 12, y: layoutY, width: categoryLayoutW, height: 220),
                cornerRadius: 16
            ),
            5: .init(
                description: "toggle privacy to hide your Ranko from the community and followers, then click CREATE once all filled out.",
                rect: CGRect(x: privacyX, y: buttonsPrivacyY, width: 50, height: 39),
                cornerRadius: 16
            ),
            6: .init(
                description: "any issues please contact me in the feedback page in Settings, to get started click FINISH.",
                rect: CGRect(x: finishX, y: finishY, width: 0, height: 0),
                cornerRadius: 16
            )
        ]
    }

    // MARK: - Helper now just rounds to WHOLE POINTS and clamps inside the container
    private func absRect(_ absoluteRect: CGRect, in containerSize: CGSize) -> CGRect {
        // round x, y, w, h to whole points
        var r = CGRect(
            x: absoluteRect.origin.x.rounded(),
            y: absoluteRect.origin.y.rounded(),
            width: absoluteRect.size.width.rounded(),
            height: absoluteRect.size.height.rounded()
        )

        // clamp size to container
        r.size.width = min(max(0, r.size.width), containerSize.width)
        r.size.height = min(max(0, r.size.height), containerSize.height)

        // clamp origin so the rect stays fully on-screen
        r.origin.x = min(max(0, r.origin.x), max(0, containerSize.width - r.size.width))
        r.origin.y = min(max(0, r.origin.y), max(0, containerSize.height - r.size.height))

        return r
    }
    
    @State private var buttons: [CreateRankoButtons] = [
        .init(name: "Help",        shakeVariable: "",               icon: "questionmark",        iconFrame: 14, enabled: true),
        .init(name: "Name",        shakeVariable: "rankoNameShake", icon: "textformat",          iconFrame: 20, enabled: true),
        .init(name: "Description", shakeVariable: "",               icon: "text.word.spacing",   iconFrame: 18, enabled: true),
        .init(name: "Category",    shakeVariable: "categoryShake",  icon: "tag.fill",            iconFrame: 16, enabled: false),
        .init(name: "Layout",      shakeVariable: "layoutShake",    icon: "square.grid.2x2.fill",iconFrame: 16, enabled: false)
    ]
    
    private func setEnabled(_ name: String, _ value: Bool) {
        if let i = buttons.firstIndex(where: { $0.name == name }) {
            buttons[i].enabled = value
        }
    }
    
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
        case "Help": return 300
        case "Name": return 158.2
        case "Description": return 192.6
        case "Category": return 300
        case "Layout": return 300
        default: return 125
        }
    }
    
    private var sheetHeightTarget: CGFloat {
        CGFloat(user_data.deviceKeyboardHeight) + bottomSafeInset
        + sheetHeightAboveKeyboard(for: currentTab)
    }
    
    private func togglePrivacyAnimated() {
        // haptic
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.prepare()

        // 1) fast fade out current icon + text
        withAnimation(.easeOut(duration: 0.08)) {
            privacyVisible = false
        }

        // 2) swap the state while invisible, then spring back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            rankoPrivacy.toggle()
            privacyAnimKey = UUID()                   // new identity → spring anim will re-run

            impact.impactOccurred(intensity: 1.0)     // haptic on reveal

            withAnimation(.interpolatingSpring(stiffness: 320, damping: 22)) {
                privacyVisible = true                 // springy fade-in
            }
        }
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
                        .shadow(color: Color(hex: 0xFFFFFF).opacity(0.5), radius: 6)
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
                            currentTab = "Name"
                            rankoNameFocus = true
                            rankoName = ""
                            rankoDescription = ""
                            localSelection = nil
                            expandedParentID = nil
                            expandedSubID = nil
                            selectedPath = []
                            nextButtonString = "Next"
                            disableNextButton = false
                            disableAllButtons = false
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
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)
                    
                    // top bar overlay with Cancel
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showCreateSheet = false
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.custom("Nunito-Regular", size: 20))
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
                        // MARK: - Top Indicator - 35pt
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
                                    if currentTab == "Help" {
                                        withAnimation {
                                            showCreateSheet = false
                                        }
                                    } else if currentTab == "Name" {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            withAnimation {
                                                showCreateSheet = false
                                            }
                                        }
                                        rankoNameFocus = false
                                    } else if currentTab == "Description" {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            withAnimation {
                                                showCreateSheet = false
                                            }
                                        }
                                        descriptionFocus = false
                                    } else if currentTab == "Category" {
                                        withAnimation {
                                            showCreateSheet = false
                                        }
                                    } else if currentTab == "Layout" {
                                        withAnimation {
                                            showCreateSheet = false
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                                
                                VStack {
                                    Text("Random")
                                        .font(.custom("Nunito-Black", size: fontSize))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, hInset)
                                        .padding(.vertical, vInset)
                                        .glassEffect(.regular.interactive().tint(Color(hex: 0x1B2024)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .frame(height: fieldH)
                                .onTapGesture {
                                    withAnimation {
                                        disableAllButtons = true
                                        currentTab = "Name"
                                        rankoName = ""
                                        rankoDescription = ""
                                        localSelection = nil
                                        expandedParentID = nil
                                        expandedSubID = nil
                                        selectedPath = []
                                    }
                                    Task { @MainActor in
                                        await runRandomAutofillAndFlowAsync()
                                    }
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 1.2).onEnded(({ _ in
                                        let current = randomSamplePair()
                                        rankoName = current.name
                                        rankoDescription = ""
                                        rankoPrivacy = false
                                        localSelection = current.category
                                        selectedLayoutName = "Tier"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            openRankoSheet = true
                                            withAnimation {
                                                showCreateSheet = false
                                            }
                                        }
                                    }))
                                )
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
                                                currentTab = "Layout"
                                            }
                                        }
                                    } else if currentTab == "Layout" {
                                        if localSelection == nil && rankoName.isEmpty && selectedLayoutName == nil {
                                            print("FUCK NO, NAME & CATEGORY & LAYOUT IS EMPTY")
                                            withAnimation {
                                                rankoNameShake += 1
                                                categoryShake += 1
                                                layoutShake += 1
                                            }
                                        } else if localSelection == nil && rankoName.isEmpty {
                                            print("FUCK NO, NAME & CATEGORY IS EMPTY")
                                            withAnimation {
                                                rankoNameShake += 1
                                                categoryShake += 1
                                            }
                                        } else if selectedLayoutName == nil && rankoName.isEmpty {
                                            print("FUCK NO, NAME & LAYOUT IS EMPTY")
                                            withAnimation {
                                                rankoNameShake += 1
                                                layoutShake += 1
                                            }
                                        } else if localSelection == nil && selectedLayoutName == nil {
                                            print("FUCK NO, CATEGORY & LAYOUT IS EMPTY")
                                            withAnimation {
                                                categoryShake += 1
                                                layoutShake += 1
                                            }
                                        } else if selectedLayoutName == nil {
                                            print("FUCK NO, LAYOUT IS EMPTY")
                                            withAnimation { layoutShake += 1 }
                                        } else if localSelection == nil {
                                            print("FUCK NO, CATEGORY IS EMPTY")
                                            withAnimation { categoryShake += 1 }
                                        } else if rankoName.isEmpty {
                                            print("FUCK NO, NAME IS EMPTY")
                                            withAnimation { rankoNameShake += 1 }
                                        } else {
                                            withAnimation {
                                                showCreateSheet = false
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                openRankoSheet = true
                                                withAnimation {
                                                    showCreateSheet = false
                                                }
                                            }
                                        }
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
                        HStack(spacing: 15) {
                            ForEach(buttons) { button in
                                let enabled: Bool = {
                                    switch button.name {
                                    case "Category": return !rankoName.isEmpty
                                    case "Layout":   return !rankoName.isEmpty && !selectedPath.isEmpty
                                    default:         return true
                                    }
                                }()
                                
                                Button {
                                    guard enabled else {
                                        // shake / feedback
                                        if (button.name == "Category" && rankoName.isEmpty) || (button.name == "Layout" && rankoName.isEmpty) {
                                            withAnimation {
                                                rankoNameShake += 1
                                            }
                                        }
                                        if button.name == "Layout"   && selectedPath.isEmpty {
                                            withAnimation {
                                                categoryShake += 1
                                            }
                                        }
                                        return
                                    }
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
                                            currentTab == button.name
                                            ? Color(hex: 0x000000)
                                            : (enabled ? Color(hex: 0xFFFFFF) : Color(hex: 0xFFFFFF).opacity(0.3))
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white)
                                                .opacity(currentTab == button.name ? 1 : 0)
                                                .frame(width: 30, height: 30)
                                        )
                                }
                                .frame(width: 30, height: 30)
                                .buttonStyle(.plain)
                                .modifier(ShakeEffect(travelDistance: 4, shakesPerUnit: 3, animatableData: shakeValue(for: button.shakeVariable)))
                            }
                            PrivacyLikeButton(isPrivate: $rankoPrivacy)
                                .frame(width: 30, height: 30)
                                .padding(.horizontal, 10)
                        }
                        .frame(height: 35)
                        // MARK: - Padding - 20pt
                        Rectangle().fill(.clear).frame(height: 20)
                        // MARK: - Content area swaps by tab
                        Group {
                            if currentTab == "Help" {}
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
                                    .font(.custom("Nunito-Regular", size: fontSize))
                                    .foregroundColor(.white)
                                    .submitLabel(.go)
                                    .padding(.leading, hInset)
                                    .focused($rankoNameFocus)
                                    .frame(maxHeight: .infinity)
                                    .textFieldStyle(.plain)
                                    .onSubmit {
                                        if rankoName.containsNoLetters || rankoName.count < 3 {
                                            withAnimation {
                                                rankoNameShake += 1
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                rankoNameFocus = true
                                            }
                                        } else {
                                            currentTab = "Description"
                                        }
                                    }
                                    .lineLimit(1)
                                    .contentShape(Rectangle())
                                    .colorScheme(.dark)
                                }
                                .frame(height: fieldH)
                                .padding(.horizontal, 20)
                                // nice appear/disappear
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .modifier(ShakeEffect(travelDistance: 4, shakesPerUnit: 3, animatableData: rankoNameShake))
                                
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
                                    .font(.custom("Nunito-Regular", size: fontSize))
                                    .foregroundColor(.white)
                                    .submitLabel(.go)
                                    .padding(.horizontal, fieldHInset)
                                    .padding(.vertical, fieldVInset)
                                    .focused($descriptionFocus)
                                    .textFieldStyle(.plain)
                                    .colorScheme(.dark)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                                .frame(minHeight: minH, maxHeight: maxH)
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                            } else if currentTab == "Category" {
                                // MARK: - Ranko Category Picker
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
                                                
                                                let impact = UIImpactFeedbackGenerator(style: .soft)
                                                impact.prepare()
                                                impact.impactOccurred(intensity: 1.0)
                                            }
                                        }
                                    }
                                    .task { repo.loadOnce() }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.horizontal, 10)
                                .onChange(of: localSelection) { _, _ in
                                    print("Change to Local Selection: \(String(describing: localSelection))")
                                }
                                .onChange(of: expandedParentID) { _, _ in
                                    print("Change to Expanded Parent ID: \(String(describing: expandedParentID))")
                                }
                                .onChange(of: expandedSubID) { _, _ in
                                    print("Change to Expanded Parent ID: \(String(describing: expandedSubID))")
                                }
                                .onChange(of: selectedPath) { _, _ in
                                    print("Change to Selected Path: \(selectedPath)")
                                }
                            } else if currentTab == "Layout" {
                                // MARK: - Ranko Layout Picker
                                // 2 columns, nice gap
                                let columns = [GridItem(.flexible(), spacing: 12),
                                               GridItem(.flexible(), spacing: 12)]
                                
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(layoutList) { opt in
                                        let isSelected = (selectedLayoutName == opt.name)
                                        let isEnabled  = opt.enabled
                                        
                                        Button {
                                            if isEnabled {
                                                // select + crisp haptic
                                                let impact = UIImpactFeedbackGenerator(style: .rigid)
                                                impact.prepare()
                                                impact.impactOccurred(intensity: 1.0)
                                                
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                    selectedLayoutName = opt.name
                                                }
                                            } else {
                                                // disabled → shake + error haptic
                                                let notif = UINotificationFeedbackGenerator()
                                                notif.notificationOccurred(.error)
                                                withAnimation(.easeInOut(duration: 0.22)) {
                                                    layoutShakes[opt.shakeKey, default: 0] += 1
                                                }
                                            }
                                        } label: {
                                            ZStack(alignment: .bottom) {
                                                // Image square & resizable
                                                Image(opt.image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(maxWidth: .infinity)     // fill cell width
                                                    .clipped()
                                                    .overlay(
                                                        // White outline when selected & enabled
                                                        RoundedRectangle(cornerRadius: 25)
                                                            .stroke(isSelected && isEnabled ? .white : .white.opacity(0.25),
                                                                    lineWidth: isSelected && isEnabled ? 3 : 1)
                                                    )
                                                    .opacity(isEnabled ? 1.0 : 0.9)
                                            }
                                            .aspectRatio(1, contentMode: .fit)     // ← keeps each cell perfectly square
                                            .contentShape(RoundedRectangle(cornerRadius: 25))
                                        }
                                        .buttonStyle(.plain)
                                        .modifier(
                                            ShakeEffect(
                                                travelDistance: 6,
                                                shakesPerUnit: 3,
                                                animatableData: layoutShakes[opt.shakeKey, default: 0]
                                            )
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
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
                    .onChange(of: rankoName) { _, newName in
                        setEnabled("Category", !newName.isEmpty)
                    }
                    .onChange(of: selectedPath) { _, newPath in
                        setEnabled("Layout", !newPath.isEmpty)
                    }
                    .onChange(of: rankoDescription) {
                        if rankoDescription.isEmpty {
                            withAnimation {
                                nextButtonString = "Skip"
                            }
                        } else if rankoDescription.range(of: "\n") != nil {
                            if rankoName != "" {
                                descriptionFocus = false
                                withAnimation {
                                    currentTab = "Category"
                                    nextButtonString = "Next"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    rankoDescription = rankoDescription.replacingOccurrences(of: "\n", with: "")
                                }
                            } else {
                                rankoNameShake += 1
                                let impact = UIImpactFeedbackGenerator(style: .heavy)
                                impact.prepare()
                                impact.impactOccurred(intensity: 1.0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    rankoDescription = rankoDescription.replacingOccurrences(of: "\n", with: "")
                                }
                            }
                        } else {
                            withAnimation {
                                nextButtonString = "Next"
                            }
                        }
                    }
                    .onChange(of: currentTab) { oldTabName, newTabName in
                        if !tutorialMode {
                            animateSheetHeight()
                            print("From \(oldTabName) to \(newTabName)")
                            
                            if oldTabName == "Help" {
                                
                            } else if oldTabName == "Name" {
                                rankoNameFocus = false
                            } else if oldTabName == "Description" {
                                descriptionFocus = false
                            } else if oldTabName == "Category" {
                                
                            } else if oldTabName == "Layout" {
                                
                            }
                            
                            if newTabName == "Help" {
                                withAnimation {
                                    nextButtonString = "Get Started"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    tutorialIndex = 0   // or 1/2/3/4
                                    withAnimation { tutorialMode = true }
                                }
                            } else if newTabName == "Name" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    rankoNameFocus = true
                                }
                                withAnimation {
                                    nextButtonString = "Next"
                                }
                            } else if newTabName == "Description" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    descriptionFocus = true
                                }
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation {
                                        nextButtonString = "Next"
                                    }
                                }
                                withAnimation {
                                    nextButtonString = "Next"
                                }
                            } else if newTabName == "Layout" {
                                withAnimation {
                                    nextButtonString = "Create"
                                }
                            }
                        }
                    }
                    .onChange(of: tutorialMode) { _, isOn in
                        if isOn {
                            snapshotAndClearForTutorial()
                        } else {
                            restoreAfterTutorial()
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
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    .zIndex(2)
                    .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showCreateSheet)
                    
                    
                    if tutorialMode {
                        GeometryReader { geo in
                            let size = geo.size
                            let lastStepIndex = (tutorialSteps.keys.max() ?? 0)
                            let step = tutorialSteps[tutorialIndex] ?? tutorialSteps[0]!
                            // was: let rect = absRect(step.relRect, in: size)
                            let rect = absRect(step.rect, in: size)
                            let radius = step.cornerRadius
                            
                            ZStack(alignment: .bottom) {
                                // ---- Dim layer with a "hole" that animates position & size ----
                                ZStack {
                                    Color.black.opacity(0.93)
                                    // the cutout that punches through the black
                                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .blendMode(.destinationOut)
                                        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: tutorialIndex)
                                    
                                    // optional white outline to emphasize the spotlight
                                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                                        .stroke(.white.opacity(0.95), lineWidth: 2)
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .allowsHitTesting(false)
                                        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: tutorialIndex)
                                }
                                .compositingGroup()            // needed for destinationOut to work
                                .ignoresSafeArea()
                                .onAppear {
                                    print("Bottom Safe Inset: \(bottomSafeInset)")
                                    print("Animated Height: \(animatedHeight)")
                                    print("Device Height: \(user_data.deviceHeight)")
                                    print("Keyboard Height: \(user_data.deviceKeyboardHeight)")
                                }
                                // ---- Description + controls ----
                                VStack(spacing: 14) {
                                    // description bubble
                                    Text(step.description)
                                        .font(.custom("Nunito-Regular", size: 16))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.black.opacity(0.45))
                                        )
                                        .frame(maxWidth: min(size.width * 0.9, 520))
                                        .transition(.opacity.combined(with: .scale))
                                        .id(tutorialIndex)   // forces a smooth cross-fade per step
                                    
                                    HStack(spacing: 14) {
                                        Button {
                                            guard tutorialIndex > 0 else { return }
                                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                                tutorialIndex -= 1
                                            }
                                        } label: {
                                            Text("Previous")
                                                .font(.custom("Nunito-Black", size: 16))
                                                .padding(.horizontal, 18).padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(.white.opacity(0.16))
                                                )
                                                .foregroundStyle(.white)
                                                .opacity(tutorialModeButtonsDisabled ? 0.3 : 1)
                                        }
                                        .opacity(tutorialIndex == 0 ? 0.5 : 1)
                                        .disabled(tutorialIndex == 0 || tutorialModeButtonsDisabled)
                                        
                                        Button {
                                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                                if tutorialIndex < lastStepIndex {
                                                    tutorialIndex += 1
                                                } else {
                                                    withAnimation(.easeInOut(duration: 0.5)) {
                                                        currentTab = "Name"
                                                        tutorialMode = false
                                                        rankoNameFocus = true
                                                    }
                                                }
                                            }
                                        } label: {
                                            Text(tutorialIndex == lastStepIndex ? "Finish" : "Next")
                                                .font(.custom("Nunito-Black", size: 16))
                                                .padding(.horizontal, 18).padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(LinearGradient(colors: [Color(hex: 0xFF9864), Color(hex: 0xFCB34D)],
                                                                             startPoint: .top, endPoint: .bottom)
                                                        )
                                                )
                                                .foregroundStyle(.white)
                                                .opacity(tutorialModeButtonsDisabled ? 0.3 : 1)
                                        }
                                        .disabled(tutorialModeButtonsDisabled)
                                    }
                                    
                                    Button {
                                        nameStopTyping()
                                        descriptionStopTyping()
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            currentTab = "Name"
                                            rankoNameFocus = true
                                            tutorialMode = false
                                        }
                                    } label: {
                                        Text("Skip Tutorial")
                                            .font(.custom("Nunito-ExtraBold", size: 14))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .underline()
                                            .opacity(tutorialModeButtonsDisabled ? 0.3 : 1)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.bottom, bottomSafeInset + 20)
                                .padding(.horizontal, 16)
                            }
                            .onChange(of: tutorialIndex) { oldIndex, newIndex in
                                if newIndex == 1 {
                                    descriptionStopTyping()
                                    startTutorialNameLoop()
                                    withAnimation {
                                        currentTab = "Name"
                                        tutorialModeButtonsDisabled = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation {
                                            tutorialModeButtonsDisabled = false
                                        }
                                    }
                                } else if newIndex == 2 {
                                    nameStopTyping()
                                    startTutorialDescriptionLoop()
                                    withAnimation {
                                        currentTab = "Description"
                                        localSelection = nil
                                        expandedParentID = nil
                                        expandedSubID = nil
                                        selectedPath = []
                                        tutorialModeButtonsDisabled = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation {
                                            tutorialModeButtonsDisabled = false
                                        }
                                    }
                                } else if newIndex == 3 {
                                    descriptionStopTyping()
                                    withAnimation {
                                        currentTab = "Category"
                                        selectedLayoutName = nil
                                        tutorialModeButtonsDisabled = true
                                    }
                                    
                                    // make sure data is loaded before you tap
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                        if let stem = chipByID("stem-stem") {
                                            withAnimation {
                                                handleChipTap(stem)
                                            }
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                            if let science = chipByID("stem-science") {
                                                withAnimation {
                                                    handleChipTap(science)
                                                }
                                            }
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                if let elements = chipByID("stem-science-elements") {
                                                    withAnimation {
                                                        handleChipTap(elements)
                                                    }
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    withAnimation {
                                                        localSelection = nil
                                                        expandedParentID = nil
                                                        expandedSubID = nil
                                                        selectedPath = []
                                                        tutorialModeButtonsDisabled = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else if newIndex == 4 {
                                    withAnimation {
                                        currentTab = "Layout"
                                        localSelection = nil
                                        expandedParentID = nil
                                        expandedSubID = nil
                                        selectedPath = []
                                        tutorialModeButtonsDisabled = true
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            selectedLayoutName = "Default"
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                selectedLayoutName = "Tier"
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                    selectedLayoutName = nil
                                                }
                                                withAnimation {
                                                    tutorialModeButtonsDisabled = false
                                                }
                                            }
                                        }
                                    }
                                } else if newIndex == 5 {
                                    withAnimation {
                                        selectedLayoutName = nil
                                        tutorialModeButtonsDisabled = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        rankoPrivacy.toggle()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                            rankoPrivacy.toggle()
                                            withAnimation {
                                                tutorialModeButtonsDisabled = false
                                            }
                                        }
                                    }
                                } else if newIndex == 6 {
                                    withAnimation {
                                        currentTab = "Name"
                                        tutorialModeButtonsDisabled = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                        withAnimation {
                                            tutorialModeButtonsDisabled = false
                                        }
                                    }
                                }
                            }
                        }
                        .zIndex(3)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $openRankoSheet, onDismiss: {
            currentTab = "Name"
            rankoNameFocus = true
            tutorialMode = false
            localSelection = nil
            expandedParentID = nil
            expandedSubID = nil
            selectedPath = []
            selectedLayoutName = nil
        }) {
            if selectedLayoutName == "Default" {
                DefaultListView(
                    rankoName: rankoName,
                    description: rankoDescription,
                    isPrivate: rankoPrivacy,
                    // TODO: if you want to pass the selected category, map your SampleCategoryChip → CategoryChip here.
                    category: localSelection,
                    onSave: { _ in }
                )
            } else if selectedLayoutName == "Tier" {
                GroupListView(
                    rankoName: rankoName,
                    description: rankoDescription,
                    isPrivate: rankoPrivacy,
                    category: localSelection
                )
            }
        }
        .ignoresSafeArea(.keyboard)
        .edgesIgnoringSafeArea(.all)
    }
    
    private func runRandomAutofillAndFlow() {
        let current = randomSamplePair()
        let stepCount = makeTapSequence(from: current.category.id).count
        let nameLen   = current.name.count

        let rankoNameDelay     = Double(nameLen) * 0.035 + 0.6
        let rankoCategoryDelay = (Double(max(0, stepCount)) * 0.3) + 0.8

        withAnimation { currentTab = "Name" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            typewriterSetRankoName(current.name, perChar: 0.035)
            DispatchQueue.main.asyncAfter(deadline: .now() + rankoNameDelay) {
                withAnimation { currentTab = "Category" }

                print("Ranko Name Length: \(nameLen)")
                print("Step Count: \(stepCount)")
                print("Ranko Name Delay: \(rankoNameDelay)")
                print("Ranko Category Delay: \(rankoCategoryDelay)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    runCategoryTapSequence(for: current.category.id) {}
                    DispatchQueue.main.asyncAfter(deadline: .now() + rankoCategoryDelay) {
                        withAnimation { currentTab = "Layout" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { selectedLayoutName = "Tier" }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation { showCreateSheet = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    openRankoSheet = true
                                    withAnimation {
                                        showCreateSheet = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func typewriterSetRankoName(
        _ text: String,
        perChar: Double = 0.04,
        leadingDelay: Double = 0.10
    ) {
        nameTypingTask?.cancel()
        nameTypingTask = Task { @MainActor in
            // optional: show keyboard so the effect feels “in the field”
            rankoName = ""

            // small lead-in
            try? await Task.sleep(nanoseconds: UInt64(leadingDelay * 1_000_000_000))

            for ch in text {
                // bail if a new animation starts
                if Task.isCancelled { return }
                withAnimation(.linear(duration: perChar)) {
                    rankoName.append(ch)
                }
                try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
            }
        }
    }
       
    // MARK: - CATEGORY TAP CHAIN

    /// "food-dairy-milk" -> ["food-food","food-dairy","food-dairy-milk"]
    private func makeTapSequence(from categoryID: String) -> [String] {
        let parts = categoryID.split(separator: "-").map(String.init)
        guard let root = parts.first else { return [] }

        var seq: [String] = ["\(root)-\(root)"]
        if parts.count > 1 {
            var prefix = root
            for i in 1..<parts.count {
                prefix += "-\(parts[i])"
                seq.append(prefix)
            }
        }
        // de-dupe just in case
        var out: [String] = []
        for id in seq where out.last != id { out.append(id) }
        return out
    }

    /// Wait until top-level chips are loaded, then run `action` (max ~3s).
    private func runWhenChipsReady(maxTries: Int = 30, _ action: @escaping () -> Void) {
        func attempt(_ tries: Int) {
            if !repo.topLevelChips.isEmpty || tries <= 0 {
                action()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    attempt(tries - 1)
                }
            }
        }
        attempt(maxTries)
    }

    /// Ensures Category tab is visible, clears selection, waits for data, then taps each id with 0.3s gaps.
    private func runCategoryTapSequence(
        for categoryID: String,
        initialDelay: TimeInterval = 0.15,
        stepDelay: TimeInterval = 0.3,
        after: @escaping () -> Void = {}
    ) {
        withAnimation { currentTab = "Category" }
        localSelection   = nil
        expandedParentID = nil
        expandedSubID    = nil
        selectedPath     = []

        repo.loadOnce()

        runWhenChipsReady {
            let steps = makeTapSequence(from: categoryID)
            // kick slightly later to allow subchips to render after each parent tap
            for (i, id) in steps.enumerated() {
                let delay = 0.1 + initialDelay + stepDelay * Double(i)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if let chip = chipByID(id) {
                        withAnimation { handleChipTap(chip) }
                    } else {
                        print("⚠️ chip not found for id \(id)")
                    }
                }
            }
            let total = initialDelay + stepDelay * Double(max(0, steps.count - 1)) + 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + total, execute: after)
            print("\(categoryID) delay time: \(total)")
        }
    }
    
    struct PrivacyLikeButton: View {
        @Binding var isPrivate: Bool
        var onToggle: ((Bool) -> Void)? = nil

        var body: some View {
            Button {
                // haptic
                let impact = UIImpactFeedbackGenerator(style: .rigid)
                impact.prepare()

                withAnimation(.interpolatingSpring(stiffness: 170, damping: 15)) {
                    isPrivate.toggle()
                }

                onToggle?(isPrivate)
                impact.impactOccurred(intensity: 1.0)
            } label: {
                ZStack {
                    icon("lock.fill",      show: isPrivate)
                    icon("lock.open.fill", show: !isPrivate)
                }
            }
            .buttonStyle(.plain)
        }

        private func icon(_ name: String, show: Bool) -> some View {
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .fontWeight(.black)
                .foregroundStyle(Color(hex: 0xFFFFFF))
                .scaleEffect(show ? 1 : 0)
                .opacity(show ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 90, damping: 15), value: show)
        }
    }
    
    private func handleChipTap(_ chip: SampleCategoryChip) {
        // compute true ancestry from the repo (so we can infer the level reliably)
        let path = ancestorsPath(to: chip.id)
        let lvl  = max(0, path.count - 1)

        if let idx = selectedPath.firstIndex(of: chip.id) {
            // --- Already selected → UNSELECT this node and all deeper nodes ---
            // keep only ancestors strictly above this node
            selectedPath.removeSubrange(idx..<selectedPath.count)

            // update the "current" selection (nil if nothing left)
            if let last = selectedPath.last {
                localSelection = repo.chip(for: last, level: max(0, selectedPath.count - 1))
            } else {
                localSelection = nil
            }

            // OPTIONAL: collapse expanders that belong to the deselected branch
            withAnimation(.easeInOut(duration: 0.22)) {
                switch lvl {
                case 0:
                    // deselected a top-level → collapse everything
                    expandedParentID = nil
                    expandedSubID = nil
                case 1:
                    // deselected a level-1 node → collapse its level-2 expander
                    if expandedSubID == chip.id { expandedSubID = nil }
                    // keep parent expanded so siblings remain visible
                default:
                    // level-2 (or deeper) deselect → no expander changes needed
                    break
                }
            }
            return
        }

        // --- Not selected → SELECT full ancestor chain (keeps parents highlighted) ---
        selectedPath = path
        localSelection = repo.chip(for: chip.id, level: lvl)

        // ensure expanders reflect the path so the user sees what they tapped
        withAnimation(.easeInOut(duration: 0.22)) {
            if lvl == 0 {
                // toggle parent expansion
                expandedParentID = (expandedParentID == chip.id) ? nil : chip.id
                if expandedParentID == nil { expandedSubID = nil }
            } else if lvl == 1 {
                // ensure parent expanded, then toggle this level-1 node
                if let parent = path.first, expandedParentID != parent {
                    expandedParentID = parent
                }
                expandedSubID = (expandedSubID == chip.id) ? nil : chip.id
            } else {
                // level-2: make sure both ancestors are expanded
                if path.count >= 2 {
                    let parent0 = path[0]
                    let parent1 = path[1]
                    if expandedParentID != parent0 { expandedParentID = parent0 }
                    if expandedSubID != parent1   { expandedSubID = parent1 }
                }
            }
        }
    }
    
    private func chipByID(_ id: String) -> SampleCategoryChip? {
        // derive level from the chain length to be safe
        let path = ancestorsPath(to: id)
        return repo.chip(for: id, level: max(0, path.count - 1))
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

let sampleDescriptions: [String] = [
    "best aussie beaches for the surf, vibes & sunsets",
    "don't hate me for these picks…",
    "top albums this decade",
    "Album Review #27 - KAYTRANADA #2",
    "smartphones compared: camera, battery, price/perf",
    "mostly based off taste",
    "comfort foods tier list for nostalgia",
    "premier league wingers based off pace, assists, big games",
    "afl mids based off disposals, meters gained, clutch goals",
    "rainy-night movies - cozy vibes & zero jump scares",
    "cities to visit from live there to never visit again",
    "study hacks that work",
    "coffee orders from smooth flat white to ristretto",
    "apartment-friendly dogs mostly based off size, energy and noise",
    "bc i'm bored",
    "All cars I have owned",
    "my bookshelf"
]

let sampleNameCategoryPairs: [(name: String, category: SampleCategoryChip)] = [
    ("Most Rewatchable Comedies", SampleCategoryChip(id: "entertainment-entertainment", name: "Entertainment", icon: "star.fill", colour: "0xFFCF00", synonyms:  "fun, leisure, media, amusement, recreation")),
    ("Personal Favourite Underdog Finals", SampleCategoryChip(id: "sports-sports", name: "Sports", icon: "soccerball", colour: "0xFFCF00", synonyms:  "sports, games, athletics, competition, events")),
    ("Most Iconic Music Videos", SampleCategoryChip(id: "music-music", name: "Music", icon: "music.note", colour: "0xFFCF00", synonyms:  "songs, tracks, singles, compositions, tunes")),
    ("Most Majestic Fauna", SampleCategoryChip(id: "animals-animals", name: "Animals", icon: "pawprint.fill", colour: "0xFFCF00", synonyms:  "animals, wildlife, creatures, fauna, beasts")),
    ("My Favourite Comfort Food Dishes", SampleCategoryChip(id: "food-food", name: "Food", icon: "fork.knife", colour: "0xFFCF00", synonyms:  "food, cuisine, fare, dishes, meals")),
    ("Best Favourite Go-To Iced Drinks", SampleCategoryChip(id: "drinks-drinks", name: "Drinks", icon: "waterbottle.fill", colour: "0xFFCF00", synonyms:  "drinks, beverages, refreshments, quenchers, libations")),
    ("Top 10 Philosophy Reads", SampleCategoryChip(id: "humanities-humanities", name: "Humanities", icon: "building.columns.fill", colour: "0xFFCF00", synonyms:  "culture, history, society, philosophy, arts")),
    ("My Favourite Native Shrubs", SampleCategoryChip(id: "plants-plants", name: "Plants", icon: "leaf.fill", colour: "0xFFCF00", synonyms:  "plants, flora, greenery, vegetation, botany")),
    ("My Favourite Open Datasets & APIs", SampleCategoryChip(id: "stem-stem", name: "STEM", icon: "atom", colour: "0xFFCF00", synonyms:  "science, technology, engineering, mathematics")),
    ("Top 10 Visionaries", SampleCategoryChip(id: "people-people", name: "People", icon: "figure.arms.open", colour: "0xFFCF00", synonyms:  "individuals, persons, humans, figures, populace")),
    ("Most Efficient Way to Travel", SampleCategoryChip(id: "vehicles-vehicles", name: "Vehicles", icon: "car.side.fill", colour: "0xFFCF00", synonyms:  "cars, transport, automobiles, vehicles, machines")),
    ("Top 10 Brand Revivals", SampleCategoryChip(id: "brands-brands", name: "Brands", icon: "shield.righthalf.filled", colour: "0xFFCF00", synonyms:  "labels, companies, trademarks, logos, manufacturers")),
    ("My Favourite Party Games", SampleCategoryChip(id: "misc-misc", name: "Misc", icon: "dice.fill", colour: "0xFFCF00", synonyms:  "other, random, idk")),
    ("My Top Timber Pavilions", SampleCategoryChip(id: "other-other", name: "Other", icon: "questionmark", colour: "0xFFCF00", synonyms:  "other, I don't know, nothing, default")),
    ("Most Controversial Celebrities", SampleCategoryChip(id: "entertainment-celebrities", name: "Celebrities", icon: "star.fill", colour: "0xFFCF00", synonyms:  "celebrities, stars, icons, public figures, VIPs")),
    ("Top 20 Films of the 1990s", SampleCategoryChip(id: "entertainment-movies", name: "Movies", icon: "movieclapper", colour: "0xFFCF00", synonyms:  "movies, films, cinema, flicks, motion pictures")),
    ("The Sitcoms I'm Currently Binging", SampleCategoryChip(id: "entertainment-tvshows", name: "TV Shows", icon: "tv.fill", colour: "0xFFCF00", synonyms:  "TV shows, series, programs, broadcasts, sitcoms")),
    ("Top 10 James Patterson Novels", SampleCategoryChip(id: "entertainment-books", name: "Books", icon: "books.vertical.fill", colour: "0xFFCF00", synonyms:  "books, novels, literature, texts, publications")),
    ("Top 5 Streaming Services with the Best Films", SampleCategoryChip(id: "entertainment-streamingservices", name: "Streaming Services", icon: "play.rectangle.fill", colour: "0xFFCF00", synonyms:  "streaming, OTT, platforms, providers, video services")),
    ("My Most Used Social Media Platforms", SampleCategoryChip(id: "entertainment-socialmedia", name: "Social Media", icon: "message.fill", colour: "0xFFCF00", synonyms:  "social media, networks, platforms, online communities, feeds")),
    ("Top 10 Releases Last Year", SampleCategoryChip(id: "entertainment-gaming", name: "Gaming", icon: "gamecontroller.fill", colour: "0xFFCF00", synonyms:  "gaming, video games, esports, gameplay, consoles")),
    ("Absolute Must Play Board Games", SampleCategoryChip(id: "entertainment-boardgames", name: "Board Games", icon: "dice.fill", colour: "0xFFCF00", synonyms:  "board games, tabletop, strategy, dice games, classics")),
    ("Top 10 Card Games Everyone Should Know", SampleCategoryChip(id: "entertainment-cardgames", name: "Card Games", icon: "suit.club.fill", colour: "0xFFCF00", synonyms:  "card games, playing cards, poker, blackjack, bridge")),
    ("Top 50 Memes Since 2008", SampleCategoryChip(id: "entertainment-memes", name: "Memes", icon: "camera.fill", colour: "0xFFCF00", synonyms:  "memes, internet humor, viral images, jokes, online memes")),
    ("Top 10 Oil Paintings of All Time", SampleCategoryChip(id: "entertainment-artdesign", name: "Art & Design", icon: "paintbrush.pointed.fill", colour: "0xFFCF00", synonyms:  "art, design, creativity, graphics, illustration")),
    ("Best Quotes From Man's Search for Meaning", SampleCategoryChip(id: "entertainment-quotes", name: "Quotes", icon: "quote.opening", colour: "0xFFCF00", synonyms:  "quotes, sayings, aphorisms, proverbs, citations")),
    ("Top 30 Olympians of All Time", SampleCategoryChip(id: "sports-athletes", name: "Athletes", icon: "figure.run", colour: "0xFFCF00", synonyms:  "athletes, players, competitors, sportspeople, stars")),
    ("Most Competitive Leagues", SampleCategoryChip(id: "sports-leaguestournaments", name: "Leagues & Tournaments", icon: "trophy.fill", colour: "0xFFCF00", synonyms:  "leagues, tournaments, competitions, championships, cups")),
    ("Most Valuable Sporting Clubs", SampleCategoryChip(id: "sports-clubsteams", name: "Clubs/Teams", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "clubs, teams, organizations, franchises, squads")),
    ("Highest Capacity Stadiums", SampleCategoryChip(id: "sports-stadiums", name: "Stadiums", icon: "sportscourt.fill", colour: "0xFFCF00", synonyms:  "stadiums, venues, arenas, fields, locations")),
    ("Most Iconic Coaches and Managers", SampleCategoryChip(id: "sports-coachesmanagers", name: "Coaches & Managers", icon: "megaphone.fill", colour: "0xFFCF00", synonyms:  "coaches, managers, trainers, mentors, instructors")),
    ("Most Iconic Commentary of All Time", SampleCategoryChip(id: "sports-commentators", name: "Commentators", icon: "headset", colour: "0xFFCF00", synonyms:  "commentators, announcers, broadcasters, analysts, hosts")),
    ("Top 15 Most Intense Sporting Rivalries", SampleCategoryChip(id: "sports-rivalries", name: "Rivalries", icon: "oar.2.crossed", colour: "0xFFCF00", synonyms:  "rivalries, feuds, matchups, competitions, duels")),
    ("Favourite Club Mascots", SampleCategoryChip(id: "sports-mascots", name: "Mascots", icon: "figure.dance", colour: "0xFFCF00", synonyms:  "mascots, symbols, emblems, characters, icons")),
    ("Top 5 Most Underused Gym Equipment", SampleCategoryChip(id: "sports-gym", name: "Gym", icon: "dumbbell.fill", colour: "0xFFCF00", synonyms:  "gym, fitness, training, workouts, exercise")),
    ("Top 10 Most Influential Artists of the 2010s", SampleCategoryChip(id: "music-artists", name: "Artists", icon: "music.microphone", colour: "0xFFCF00", synonyms:  "artists, bands, musicians, performers, acts")),
    ("My Favourite Tracks for Night Drives", SampleCategoryChip(id: "music-songs", name: "Songs", icon: "music.quarternote.3", colour: "0xFFCF00", synonyms:  "songs, tracks, singles, hits, tunes")),
    ("Albums That Defined My Childhood", SampleCategoryChip(id: "music-albums", name: "Albums", icon: "record.circle", colour: "0xFFCF00", synonyms:  "albums, records, LPs, collections, discs")),
    ("My Top 5 Woodwind Instruments", SampleCategoryChip(id: "music-instruments", name: "Instruments", icon: "guitars.fill", colour: "0xFFCF00", synonyms:  "instruments, gear, equipment, devices, tools")),
    ("Most Stacked Lineups of All Time", SampleCategoryChip(id: "music-festivals", name: "Festivals", icon: "hifispeaker.2.fill", colour: "0xFFCF00", synonyms:  "festivals, concerts, events, carnivals, gatherings")),
    ("Ranking the Best Artists Under Cactus Jack", SampleCategoryChip(id: "music-recordlabels", name: "Record Labels", icon: "tag.fill", colour: "0xFFCF00", synonyms:  "labels, studios, companies, distributors, imprints")),
    ("Most Influential Music Genres of the 21st Century", SampleCategoryChip(id: "music-genres", name: "Genres", icon: "music.quarternote.3", colour: "0xFFCF00", synonyms:  "genres, styles, categories, types, classifications")),
    ("Top 15 Mammal Orders by Species Diversity", SampleCategoryChip(id: "animals-mammals", name: "Mammals", icon: "hare.fill", colour: "0xFFCF00", synonyms:  "mammals, beasts, animals, vertebrates, warm-blooded")),
    ("My Favourite Wild Birds", SampleCategoryChip(id: "animals-birds", name: "Birds", icon: "bird.fill", colour: "0xFFCF00", synonyms:  "birds, avians, fowl, feathered, winged")),
    ("Top 10 Reptiles to Keep as Pets", SampleCategoryChip(id: "animals-reptiles", name: "Reptiles", icon: "lizard.fill", colour: "0xFFCF00", synonyms:  "reptiles, scaly, cold-blooded, lizards, snakes")),
    ("Top 20 Reef Fish to Spot While Snorkeling", SampleCategoryChip(id: "animals-fish", name: "Fish", icon: "fish.fill", colour: "0xFFCF00", synonyms:  "fish, aquatic, marine life, sea creatures, species")),
    ("My Favourite Species of Frog", SampleCategoryChip(id: "animals-amphibians", name: "Amphibians", icon: "drop.fill", colour: "0xFFCF00", synonyms:  "amphibians, frogs, toads, salamanders, newts")),
    ("My Favourite Pollinating Bugs", SampleCategoryChip(id: "animals-invertebrates", name: "Invertebrates", icon: "ant.fill", colour: "0xFFCF00", synonyms:  "invertebrates, spineless, inverts, non-vertebrates, soft-bodied")),
    ("My Favourite Seasonal Fruits", SampleCategoryChip(id: "food-fruits", name: "Fruits", icon: "applelogo", colour: "0xFFCF00", synonyms:  "fruits, produce, fresh fruit, orchard, citrus")),
    ("Most Underrated Vegetables for Roasting", SampleCategoryChip(id: "food-vegetables", name: "Vegetables", icon: "carrot.fill", colour: "0xFFCF00", synonyms:  "vegetables, veg, greens, produce, veggies")),
    ("Best High-Protein Fast Food Items", SampleCategoryChip(id: "food-fastfood", name: "Fast Food", icon: "takeoutbag.and.cup.and.straw.fill", colour: "0xFFCF00", synonyms:  "fast food, takeaway, takeout, quick-service, QSR")),
    ("Absolute Must Snacks While Losing Weight", SampleCategoryChip(id: "food-snacks", name: "Snacks", icon: "popcorn.fill", colour: "0xFFCF00", synonyms:  "snacks, munchies, nibbles, treats, bites")),
    ("S-Tier Chocolate Bars", SampleCategoryChip(id: "food-chocolate", name: "Chocolate", icon: "square.grid.3x3.fill", colour: "0xFFCF00", synonyms:  "chocolate, cocoa, chocolate bars, confectionery, sweets")),
    ("Most Iconic Pasta Shapes", SampleCategoryChip(id: "food-pasta", name: "Pasta", icon: "scribble", colour: "0xFFCF00", synonyms:  "pasta, noodles, spaghetti, macaroni, penne")),
    ("Definitive Ranking of Dairy Staples", SampleCategoryChip(id: "food-dairy", name: "Dairy", icon: "drop.circle.fill", colour: "0xFFCF00", synonyms:  "dairy, milk products, dairy goods, dairy foods, lactose")),
    ("My Favourite Soft-Scramble Techniques", SampleCategoryChip(id: "food-eggs", name: "Eggs", icon: "oval.portrait.fill", colour: "0xFFCF00", synonyms:  "eggs, egg products, free-range, cage-free, omelettes")),
    ("Top 20 Breakfast Cereals by Crunch", SampleCategoryChip(id: "food-breakfastcereals", name: "Breakfast Cereals", icon: "sunrise.fill", colour: "0xFFCF00", synonyms:  "cereals, breakfast, muesli, granola, cornflakes")),
    ("Peak Ice Cream Flavours", SampleCategoryChip(id: "food-icecream", name: "Ice Cream", icon: "snowflake", colour: "0xFFCF00", synonyms:  "ice cream, gelato, sorbet, soft serve, frozen dessert")),
    ("Top 10 NYC Deli Classics", SampleCategoryChip(id: "food-sandwiches", name: "Sandwiches", icon: "square.split.diagonal.fill", colour: "0xFFCF00", synonyms:  "sandwiches, subs, rolls, wraps, toasties")),
    ("My Favourite Crumbles of All Time", SampleCategoryChip(id: "food-desserts", name: "Desserts", icon: "birthday.cake.fill", colour: "0xFFCF00", synonyms:  "desserts, sweets, puddings, pastries, confectionery")),
    ("Top 15 Street Foods Worldwide", SampleCategoryChip(id: "food-cuisines", name: "Cuisines", icon: "globe.europe.africa.fill", colour: "0xFFCF00", synonyms:  "cuisines, food styles, regional, international, ethnic foods")),
    ("My Favourite Citrus Sodas", SampleCategoryChip(id: "drinks-soda", name: "Soda", icon: "bubbles.and.sparkles.fill", colour: "0xFFCF00", synonyms:  "soft drinks, sodas, pop, fizzy drinks, carbonated beverages")),
    ("Top 15 Single Malts to Savour", SampleCategoryChip(id: "drinks-alcohol", name: "Alcohol", icon: "wineglass.fill", colour: "0xFFCF00", synonyms:  "alcohol, spirits, booze, liquors, alcoholic beverages")),
    ("My Favourite Light Roast Pour-Overs", SampleCategoryChip(id: "drinks-coffee", name: "Coffee", icon: "cup.and.saucer.fill", colour: "0xFFCF00", synonyms:  "coffee, espresso, lattes, cappuccinos, brews")),
    ("My Favourite Breakfast Blends", SampleCategoryChip(id: "drinks-tea", name: "Tea", icon: "leaf.fill", colour: "0xFFCF00", synonyms:  "tea, herbal, cup, drink, relax")),
    ("Most Underrated Mountain Ranges", SampleCategoryChip(id: "humanities-geography", name: "Geography", icon: "globe.europe.africa.fill", colour: "0xFFCF00", synonyms:  "geography, maps, regions, locations, places")),
    ("Top 25 Turning Points in History", SampleCategoryChip(id: "humanities-history", name: "History", icon: "building.columns.fill", colour: "0xFFCF00", synonyms:  "history, past, heritage, chronology, record")),
    ("Most Valuable Companies in 2025", SampleCategoryChip(id: "humanities-business", name: "Business", icon: "case.fill", colour: "0xFFCF00", synonyms:  "business, important, humaities, boss")),
    ("Top 10 Political Debates Since 2000", SampleCategoryChip(id: "humanities-politicians", name: "Politicians", icon: "megaphone.fill", colour: "0xFFCF00", synonyms:  "politicians, lawmakers, officials, legislators, statespeople")),
    ("My Favourire Fragrant Garden Blooms", SampleCategoryChip(id: "plants-flowers", name: "Flowers", icon: "camera.macro", colour: "0xFFCF00", synonyms:  "flowers, blooms, blossoms, petals, flora")),
    ("Top 10 Urban Shade Trees", SampleCategoryChip(id: "plants-trees", name: "Trees", icon: "tree.fill", colour: "0xFFCF00", synonyms:  "trees, timber, woods, forestry, saplings")),
    ("Top 5 Prime Numbers", SampleCategoryChip(id: "stem-numbers", name: "Numbers", icon: "123.rectangle.fill", colour: "0xFFCF00", synonyms:  "numbers, numerals, digits, figures, integers")),
    ("Top 15 Breakthroughs This Century", SampleCategoryChip(id: "stem-science", name: "Science", icon: "testtube.2", colour: "0xFFCF00", synonyms:  "science, research, experiments, laboratory, inquiry")),
    ("My Favourite Pair of Headphones", SampleCategoryChip(id: "stem-technology", name: "Technology", icon: "cpu", colour: "0xFFCF00", synonyms:  "technology, tech, computing, innovation, gadgets")),
    ("Top 20 Theorems To Know", SampleCategoryChip(id: "stem-mathematics", name: "Mathematics", icon: "x.squareroot", colour: "0xFFCF00", synonyms:  "mathematics, math, arithmetic, calculus, algebra")),
    ("Most Useless Programming Languages", SampleCategoryChip(id: "stem-programming", name: "Programming", icon: "chevron.left.forwardslash.chevron.right", colour: "0xFFCF00", synonyms:  "programming, coding, software, development, scripts")),
    ("All Letters Ranked for No Apparent Reason", SampleCategoryChip(id: "stem-alphabet", name: "Alphabet", icon: "textformat", colour: "0xFFCF00", synonyms:  "alphabet, letters, ABC, characters, glyphs")),
    ("My Favourite Clock Dials in Roman", SampleCategoryChip(id: "stem-romannumerals", name: "Roman Numerals", icon: "multiply", colour: "0xFFCF00", synonyms:  "Roman numerals, Latin numerals, classical numbers, I‑V‑X, notation")),
    ("Most Controversial Celebrities", SampleCategoryChip(id: "people-celebrities", name: "Celebrities", icon: "star.fill", colour: "0xFFCF00", synonyms:  "celebrities, stars, icons, public figures, VIPs")),
    ("My Childhood Favourite YouTube Creators", SampleCategoryChip(id: "people-contentcreators", name: "Content Creators", icon: "play.square.fill", colour: "0xFFCF00", synonyms:  "creators, influencers, producers, streamers, bloggers")),
    ("Top 10 Method Performers", SampleCategoryChip(id: "people-actors", name: "Actors", icon: "movieclapper.fill", colour: "0xFFCF00", synonyms:  "actors, performers, thespians, cast, artistes")),
    ("My Favourite Short Story Masters", SampleCategoryChip(id: "people-authors", name: "Authors", icon: "book.fill", colour: "0xFFCF00", synonyms:  "authors, writers, novelists, scribes, wordsmiths")),
    ("My Personal Top 10 Live Performances", SampleCategoryChip(id: "people-musicians", name: "Musicians", icon: "music.mic", colour: "0xFFCF00", synonyms:  "musicians, artists, instrumentalists, singers, bands")),
    ("Global Leaders Approval Rating", SampleCategoryChip(id: "people-worldleaders", name: "World Leaders", icon: "person.bust.fill", colour: "0xFFCF00", synonyms:  "leaders, presidents, prime ministers, officials, heads of state")),
    ("Top 10 Runway Icons Right Now", SampleCategoryChip(id: "people-models", name: "Models", icon: "camera.fill", colour: "0xFFCF00", synonyms:  "models, mannequins, supermodels, figures, replicas")),
    ("Top 10 Stand-Up Specials", SampleCategoryChip(id: "people-comedians", name: "Comedians", icon: "theatermasks.fill", colour: "0xFFCF00", synonyms:  "comedians, comics, humorists, jokesters, stand-ups")),
    ("Top 10 Startup Founders", SampleCategoryChip(id: "people-entrepreneurs", name: "Entrepreneurs", icon: "banknote.fill", colour: "0xFFCF00", synonyms:  "entrepreneurs, founders, business owners, innovators, startups")),
    ("My Favourite Chef's Signatures", SampleCategoryChip(id: "people-chefs", name: "Chefs", icon: "frying.pan.fill", colour: "0xFFCF00", synonyms:  "chefs, cooks, culinarians, sous-chefs, gastronome")),
    ("Most Impactful Voices for Abortion Rights", SampleCategoryChip(id: "people-activists", name: "Activists", icon: "megaphone.fill", colour: "0xFFCF00", synonyms:  "activists, advocates, campaigners, protesters, reformers")),
    ("Favourite Cars I've Personally Driven", SampleCategoryChip(id: "vehicles-cars", name: "Cars", icon: "car.fill", colour: "0xFFCF00", synonyms:  "cars, automobiles, autos, sedans, coupes")),
    ("Best Offshore Boat Under 80K", SampleCategoryChip(id: "vehicles-boats", name: "Boats", icon: "sailboat.fill", colour: "0xFFCF00", synonyms:  "boats, vessels, watercraft, ships, craft")),
    ("Most Iconic Fighter Jets", SampleCategoryChip(id: "vehicles-planes", name: "Planes", icon: "airplane", colour: "0xFFCF00", synonyms:  "planes, aircraft, airplanes, jets, aeroplanes")),
    ("My Favourite Scenic Rail Routes", SampleCategoryChip(id: "vehicles-trains", name: "Trains", icon: "tram.fill", colour: "0xFFCF00", synonyms:  "trains, rail, locomotives, carriages, railways")),
    ("Top 10 Ballon d'Or Contendors for This Year", SampleCategoryChip(id: "sports-athletes-footballers", name: "Footballers", icon: "figure.soccer", colour: "0xFFCF00", synonyms:  "footballers, soccer players, strikers, midfielders, goalkeepers")),
    ("My Favourite Clutch Shooters", SampleCategoryChip(id: "sports-athletes-basketballers", name: "Basketballers", icon: "figure.basketball", colour: "0xFFCF00", synonyms:  "basketballers, basketball players, hoopers, guards, forwards")),
    ("Most Reliable All-Rounders", SampleCategoryChip(id: "sports-athletes-cricketers", name: "Cricketers", icon: "figure.cricket", colour: "0xFFCF00", synonyms:  "cricketers, batsmen, bowlers, all-rounders, wicketkeepers")),
    ("Most Clutch Key Forwards This Season", SampleCategoryChip(id: "sports-athletes-australianfootballers", name: "Australian Footballers", icon: "figure.australian.football", colour: "0xFFCF00", synonyms:  "AFL players, footy players, midfielders, forwards, defenders")),
    ("Most Dominant Clay-Court Players", SampleCategoryChip(id: "sports-athletes-tennisplayers", name: "Tennis Players", icon: "figure.tennis", colour: "0xFFCF00", synonyms:  "tennis players, pros, servers, baseliners, doubles specialists")),
    ("Top 10 Dual-Threat QBs", SampleCategoryChip(id: "sports-athletes-americanfootballers", name: "American Footballers", icon: "figure.american.football", colour: "0xFFCF00", synonyms:  "football players, gridiron players, quarterbacks, receivers, linebackers")),
    ("Fastest Qualifying Laps in F1", SampleCategoryChip(id: "sports-athletes-motorsportdrivers", name: "Motorsport Drivers", icon: "steeringwheel", colour: "0xFFCF00", synonyms:  "drivers, racers, racecar drivers, pilots, competitors")),
    ("Most Feared Enforcers", SampleCategoryChip(id: "sports-athletes-hockeyplayers", name: "Hockey Players", icon: "figure.hockey", colour: "0xFFCF00", synonyms:  "hockey players, skaters, forwards, defensemen, goalies")),
    ("Most Reliable Pitchers", SampleCategoryChip(id: "sports-athletes-baseballers", name: "Baseballers", icon: "figure.baseball", colour: "0xFFCF00", synonyms:  "baseballers, baseball players, ballplayers, hitters, pitchers")),
    ("Top 5 Line-Break Merchants", SampleCategoryChip(id: "sports-athletes-rugbyplayers", name: "Rugby Players", icon: "figure.rugby", colour: "0xFFCF00", synonyms:  "rugby players, union players, league players, forwards, backs")),
    ("My Favourite Major Performances Since 2020", SampleCategoryChip(id: "sports-athletes-golfers", name: "Golfers", icon: "figure.golf", colour: "0xFFCF00", synonyms:  "golfers, players, pros, putters, drivers")),
    ("Most Devastating KO Artists", SampleCategoryChip(id: "sports-athletes-boxers", name: "Boxers", icon: "figure.boxing", colour: "0xFFCF00", synonyms:  "boxers, pugilists, fighters, contenders, champions")),
    ("Most Elite Grapplers in the UFC", SampleCategoryChip(id: "sports-athletes-mmafighters", name: "MMA Fighters", icon: "figure.martial.arts", colour: "0xFFCF00", synonyms:  "mixed martial artists, MMA fighters, cage fighters, strikers, grapplers")),
    ("Top 5 Youth Leagues", SampleCategoryChip(id: "sports-leaguestournaments-footballleagues", name: "Football Leagues", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "leagues, competitions, divisions, associations, tables")),
    ("Least Wanted Trophy's in England", SampleCategoryChip(id: "sports-leaguestournaments-footballcups", name: "Football Cups", icon: "trophy.fill", colour: "0xFFCF00", synonyms:  "cups, knockouts, tournaments, finals, silverware")),
    ("Best Leagues for Development", SampleCategoryChip(id: "sports-leaguestournaments-basketballleagues", name: "Basketball Leagues", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "leagues, conferences, divisions, associations, seasons")),
    ("Top 5 T20 Leagues in the World", SampleCategoryChip(id: "sports-leaguestournaments-cricketleagues", name: "Cricket Leagues", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "leagues, tournaments, T20, franchises, domestic")),
    ("Ranking All the Feeder Leagues to the AFL", SampleCategoryChip(id: "sports-leaguestournaments-australianfootballleagues", name: "Australian Football Leagues", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "leagues, AFL, state leagues, comps, seasons")),
    ("Ranking All Grand Slams from Experience", SampleCategoryChip(id: "sports-leaguestournaments-tennistournaments", name: "Tennis Tournaments", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "tournaments, slams, tours, ATP/WTA, events")),
    ("My Favourite College Conferences", SampleCategoryChip(id: "sports-leaguestournaments-americanfootballleagues", name: "American Football Leagues", icon: "checkerboard.shield", colour: "0xFFCF00", synonyms:  "leagues, NFL, conferences, divisions, seasons")),
    ("This Season's F1 Circuits Ranked", SampleCategoryChip(id: "sports-leaguestournaments-motorsporttracks", name: "Motorsport Tracks", icon: "flag.checkered.2.crossed", colour: "0xFFCF00", synonyms:  "circuits, tracks, speedways, raceways, venues")),
    ("Next Season's EPL Table Prediction", SampleCategoryChip(id: "sports-clubsteams-footballclubs", name: "Football Clubs", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "clubs, teams, sides, squads, franchises")),
    ("Next Season's NBA Table Prediction", SampleCategoryChip(id: "sports-clubsteams-basketballteams", name: "Basketball Teams", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "teams, clubs, franchises, rosters, squads")),
    ("Big 3 Predictions for Next Year", SampleCategoryChip(id: "sports-clubsteams-cricketteams", name: "Cricket Teams", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "teams, XI, franchises, squads, sides")),
    ("Next Season's AFL Ladder Prediction", SampleCategoryChip(id: "sports-clubsteams-australianfootballclubs", name: "Australian Football Clubs", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "clubs, teams, footy clubs, sides, outfits")),
    ("NFL Playoff Predictions", SampleCategoryChip(id: "sports-clubsteams-americanfootballclubs", name: "American Football Clubs", icon: "shield.lefthalf.filled", colour: "0xFFCF00", synonyms:  "teams, franchises, rosters, squads, clubs")),
    ("Most Dominant Constructors in MotoGP", SampleCategoryChip(id: "sports-clubsteams-motorsportconstructors", name: "Motorsport Constructors", icon: "wrench.and.screwdriver.fill", colour: "0xFFCF00", synonyms:  "constructors, teams, manufacturers, works teams, factories")),
    ("Most Underrated Machines for Chest & Triceps", SampleCategoryChip(id: "sports-gym-gymmachines", name: "Gym Machines", icon: "figure.hand.cycling", colour: "0xFFCF00", synonyms:  "exercises, workouts, routines, movements, drills")),
    ("My Top 5 Push-Pull Supersets", SampleCategoryChip(id: "sports-gym-gymexercises", name: "Gym Exercises", icon: "figure.indoor.cycle", colour: "0xFFCF00", synonyms:  "machines, equipment, apparatus, gear, devices")),
    ("Top 20 Dog Breeds Based Off Adorableness", SampleCategoryChip(id: "animals-mammals-dogs", name: "Dogs", icon: "dog.fill", colour: "0xFFCF00", synonyms:  "dogs, canines, hounds, pups, pooches")),
    ("Best Hypoallergenic Domestic Cat Breeds", SampleCategoryChip(id: "animals-mammals-cats", name: "Cats", icon: "cat.fill", colour: "0xFFCF00", synonyms:  "cats, felines, kitties, toms, moggies")),
    ("Most Elusive Carnivores", SampleCategoryChip(id: "animals-mammals-carnivores", name: "Carnivores", icon: "fork.knife", colour: "0xFFCF00", synonyms:  "carnivores, meat-eaters, predators, hunters, flesh-eaters")),
    ("Most Social Primate Troops", SampleCategoryChip(id: "animals-mammals-primates", name: "Primates", icon: "brain.head.profile", colour: "0xFFCF00", synonyms:  "primates, apes, monkeys, hominoids, simians")),
    ("Top 7 Rodents to Keep as Pets", SampleCategoryChip(id: "animals-mammals-rodents", name: "Rodents", icon: "pawprint.circle", colour: "0xFFCF00", synonyms:  "rodents, gnawers, murids, rats, mice")),
    ("Ranking Rabbits Based on Coat Colour and Feel", SampleCategoryChip(id: "animals-mammals-rabbitshares", name: "Rabbits & Hares", icon: "hare.fill", colour: "0xFFCF00", synonyms:  "rabbits, hares, lagomorphs, bunnies, coneys")),
    ("Top 10 Deadliest Marine Mammals", SampleCategoryChip(id: "animals-mammals-marinemammals", name: "Marine Mammals", icon: "water.waves", colour: "0xFFCF00", synonyms:  "marine mammals, cetaceans, pinnipeds, sea mammals, oceanic mammals")),
    ("All Marsupials in Australia Ranked", SampleCategoryChip(id: "animals-mammals-marsupials", name: "Marsupials", icon: "pawprint.circle.fill", colour: "0xFFCF00", synonyms:  "marsupials, pouched mammals, macropods, kangaroos, possums")),
    ("Most Majestic Deer Species", SampleCategoryChip(id: "animals-mammals-hoofedmammals", name: "Hoofed Mammals", icon: "shoeprints.fill", colour: "0xFFCF00", synonyms:  "hoofed mammals, ungulates, hoofstock, grazers, ruminants")),
    ("Most Unique Monotreme Traits", SampleCategoryChip(id: "animals-mammals-monotremes", name: "Monotremes", icon: "oval.portrait.fill", colour: "0xFFCF00", synonyms:  "monotremes, egg-laying mammals, platypuses, echidnas, prototherians")),
    ("My Favourite Melodic Warblers", SampleCategoryChip(id: "animals-birds-songbirds", name: "Songbirds", icon: "music.note", colour: "0xFFCF00", synonyms:  "songbirds, passerines, perching birds, oscines, warblers")),
    ("Favourite Owl Sounds", SampleCategoryChip(id: "animals-birds-birdsofprey", name: "Birds of Prey", icon: "binoculars.fill", colour: "0xFFCF00", synonyms:  "raptors, birds of prey, raptorial birds, eagles, hawks")),
    ("Ranking Aussie Parakeets", SampleCategoryChip(id: "animals-birds-parrots", name: "Parrots", icon: "leaf.fill", colour: "0xFFCF00", synonyms:  "parrots, psittacines, parakeets, macaws, cockatoos")),
    ("Most Elegant Ground-Doves", SampleCategoryChip(id: "animals-birds-pidgeonsdoves", name: "Pidgeons & Doves", icon: "envelope.fill", colour: "0xFFCF00", synonyms:  "pigeons, doves, columbids, rock doves, squabs")),
    ("Top 10 Pelagic Birds to Watch", SampleCategoryChip(id: "animals-birds-seabirds", name: "Seabirds", icon: "water.waves", colour: "0xFFCF00", synonyms:  "seabirds, marine birds, pelagic birds, oceanic birds, coastal birds")),
    ("Top 10 Ratites in the Wild", SampleCategoryChip(id: "animals-birds-flightlessbirds", name: "Flightless Birds", icon: "figure.walk", colour: "0xFFCF00", synonyms:  "flightless birds, ratites, ground birds, penguins, emus")),
    ("My Favourite Desert Lizards", SampleCategoryChip(id: "animals-reptiles-lizards", name: "Lizards", icon: "lizard.fill", colour: "0xFFCF00", synonyms:  "lizards, saurians, geckos, skinks, iguanas")),
    ("Most Venemous Snakes I Have Owned", SampleCategoryChip(id: "animals-reptiles-snakes", name: "Snakes", icon: "scribble.variable", colour: "0xFFCF00", synonyms:  "snakes, serpents, ophidians, boas, vipers")),
    ("My Favourite Species of Terrapin", SampleCategoryChip(id: "animals-reptiles-turtlestortoises", name: "Turtles & Tortoises", icon: "tortoise.fill", colour: "0xFFCF00", synonyms:  "turtles, tortoises, chelonians, terrapins, shelled reptiles")),
    ("Crocs & Gators I Don't Want To Face", SampleCategoryChip(id: "animals-reptiles-crocodilesalligators", name: "Crocodiles & Alligators", icon: "lizard", colour: "0xFFCF00", synonyms:  "crocodilians, crocs, gators, caimans, gharials")),
    ("My Favourite Indo-Pacific Reef Fish Species", SampleCategoryChip(id: "animals-fish-reeffish", name: "Reef Fish", icon: "fish.fill", colour: "0xFFCF00", synonyms:  "reef fish, coral fish, tropical fish, reef dwellers, reef species")),
    ("Most Misunderstood Shark Species", SampleCategoryChip(id: "animals-fish-sharks", name: "Sharks", icon: "exclamationmark.triangle.fill", colour: "0xFFCF00", synonyms:  "sharks, elasmobranchs, selachimorphs, apex predators, cartilaginous fish")),
    ("Most Graceful Blue-Spotted Rays", SampleCategoryChip(id: "animals-fish-raysskates", name: "Rays & Skates", icon: "line.diagonal.arrow", colour: "0xFFCF00", synonyms:  "rays, skates, batoids, stingrays, mantas")),
    ("Most Breath-Taking Whale Songs & Whistles", SampleCategoryChip(id: "animals-fish-whales", name: "Whales", icon: "wave.3.forward", colour: "0xFFCF00", synonyms:  "whales, cetaceans, baleen whales, toothed whales, leviathans")),
    ("My Favourite Tree Frogs", SampleCategoryChip(id: "animals-amphibians-frogstoads", name: "Frogs & Toads", icon: "camera.macro", colour: "0xFFCF00", synonyms:  "frogs, toads, anurans, hylids, bufonids")),
    ("My Favourite Newts and Efts", SampleCategoryChip(id: "animals-amphibians-salamanders", name: "Salamanders", icon: "flame.fill", colour: "0xFFCF00", synonyms:  "salamanders, newts, caudates, urodelans, amphibians")),
    ("Most Beautiful Butterfly Species", SampleCategoryChip(id: "animals-invertebrates-insects", name: "Insects", icon: "ant.fill", colour: "0xFFCF00", synonyms:  "insects, hexapods, bugs, beetles, arthropods")),
    ("Biggest & Scariest Tarantulas", SampleCategoryChip(id: "animals-invertebrates-arachnids", name: "Arachnids", icon: "staroflife.fill", colour: "0xFFCF00", synonyms:  "arachnids, spiders, scorpions, mites, ticks")),
    ("My Favourite Crab TikToks", SampleCategoryChip(id: "animals-invertebrates-crustaceans", name: "Crustaceans", icon: "fish.fill", colour: "0xFFCF00", synonyms:  "crustaceans, crabs, shrimp, lobsters, krill")),
    ("Most Chill Millipede Species", SampleCategoryChip(id: "animals-invertebrates-myriapods", name: "Myriapods", icon: "line.3.horizontal", colour: "0xFFCF00", synonyms:  "myriapods, centipedes, millipedes, arthropods, polydesmids")),
    ("Most Beautiful Mollusks", SampleCategoryChip(id: "animals-invertebrates-mollusks", name: "Mollusks", icon: "moon.fill", colour: "0xFFCF00", synonyms:  "mollusks, gastropods, bivalves, cephalopods, shellfish")),
    ("My Favourite Bait Worms", SampleCategoryChip(id: "animals-invertebrates-worms", name: "Worms", icon: "scribble", colour: "0xFFCF00", synonyms:  "worms, annelids, earthworms, nematodes, flatworms")),
    ("Ranking My Favourite Drive-Thrus", SampleCategoryChip(id: "food-fastfood-fastfoodchains", name: "Fast Food Chains", icon: "storefront.fill", colour: "0xFFCF00", synonyms:  "chains, QSR brands, franchises, outlets, restaurants")),
    ("Ranking Italian Regional Pizza Styles", SampleCategoryChip(id: "food-fastfood-pizza", name: "Pizza", icon: "cone.fill", colour: "0xFFCF00", synonyms:  "pizza, pies, slices, pizzeria, deep dish")),
    ("My Go-To Burgers on Friday Night", SampleCategoryChip(id: "food-fastfood-burgers", name: "Burgers", icon: "flame.fill", colour: "0xFFCF00", synonyms:  "burgers, hamburgers, cheeseburgers, patties, sliders")),
    ("Hands-Down Best Fried Chicken in the USA", SampleCategoryChip(id: "food-fastfood-friedchicken", name: "Fried Chicken", icon: "frying.pan.fill", colour: "0xFFCF00", synonyms:  "fried chicken, tenders, wings, drumsticks, crispy chicken")),
    ("Best Takeaway Styles of Fries & Hot Chips", SampleCategoryChip(id: "food-fastfood-fries", name: "Fries", icon: "takeoutbag.and.cup.and.straw.fill", colour: "0xFFCF00", synonyms:  "fries, chips, hot chips, french fries, wedges")),
    ("Top 10 Milks for Coffee", SampleCategoryChip(id: "food-dairy-milk", name: "Milk", icon: "drop.fill", colour: "0xFFCF00", synonyms:  "milk, whole milk, skim, dairy milk, lactose")),
    ("My Favourite Cheese Platters Cheeses", SampleCategoryChip(id: "food-dairy-cheese", name: "Cheese", icon: "triangle.fill", colour: "0xFFCF00", synonyms:  "cheese, cheddar, mozzarella, gouda, parmesan")),
    ("My Go-To Morning Yogurts", SampleCategoryChip(id: "food-dairy-yogurt", name: "Yogurt", icon: "cup.and.saucer.fill", colour: "0xFFCF00", synonyms:  "yogurt, yoghurt, cultured milk, greek yogurt, dairy snack")),
    ("My Top 10 Comfort Liquor", SampleCategoryChip(id: "drinks-alcohol-liquorsliqueurs", name: "Liquors & Liqueurs", icon: "flame.fill", colour: "0xFFCF00", synonyms:  "liquors, liqueurs, spirits, cordials, aperitifs")),
    ("Top 10 Classic Cocktails", SampleCategoryChip(id: "drinks-alcohol-cocktails", name: "Cocktails", icon: "beach.umbrella.fill", colour: "0xFFCF00", synonyms:  "cocktails, mixed drinks, libations, concoctions, beverages")),
    ("My Go-To Party Premixes", SampleCategoryChip(id: "drinks-alcohol-premixes", name: "Premixes", icon: "shuffle", colour: "0xFFCF00", synonyms:  "premixes, ready-made, pre-batched, mixed drinks, beverages")),
    ("Top 20 Countries for Solo Travel", SampleCategoryChip(id: "humanities-geography-countries", name: "Countries", icon: "globe.europe.africa.fill", colour: "0xFFCF00", synonyms:  "countries, nations, states, republics, territories")),
    ("Each Continent Ranked By Size", SampleCategoryChip(id: "humanities-geography-continents", name: "Continents", icon: "globe", colour: "0xFFCF00", synonyms:  "continents, landmasses, regions, hemispheres, areas")),
    ("My Favourite World Heritage Sites", SampleCategoryChip(id: "humanities-geography-landmarks", name: "Landmarks", icon: "building.columns.fill", colour: "0xFFCF00", synonyms:  "landmarks, monuments, sites, attractions, icons")),
    ("My Favourite Nightlife Capitals", SampleCategoryChip(id: "humanities-geography-cities", name: "Cities", icon: "building.2.fill", colour: "0xFFCF00", synonyms:  "cities, metropolises, towns, municipalities, urban areas")),
    ("Each Solar System Planet Ranked For No Reason", SampleCategoryChip(id: "stem-science-planets", name: "Planets", icon: "circle.hexagonpath.fill", colour: "0xFFCF00", synonyms:  "planets, worlds, solar system, orbits, celestial bodies")),
    ("My Favourite Noble Gases", SampleCategoryChip(id: "stem-science-elements", name: "Elements", icon: "atom", colour: "0xFFCF00", synonyms:  "elements, periodic table, chemical elements, atoms, substances")),
]

func randomSamplePair() -> (name: String, category: SampleCategoryChip) {
    sampleNameCategoryPairs.randomElement()!
}

func randomDescriptionPicker() -> String {
    sampleDescriptions.randomElement()!
}

// Handy lookup:
let sampleCategoryByName: [String: SampleCategoryChip] =
    Dictionary(uniqueKeysWithValues: sampleNameCategoryPairs.map { ($0.name, $0.category) })

func categoryForSampleName(_ name: String) -> SampleCategoryChip? {
    sampleCategoryByName[name]
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
    var colour: String
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
        default:                  return raw
        }
    }

    func loadOnce() {
        if !topLevelChips.isEmpty { return }
        let group = DispatchGroup()
        var rankoRaw: [String: [String: Any]] = [:]
        var firstError: String?

        group.enter()
        db.child("Ranko").child("CategoryData").child("Definitions").observeSingleEvent(of: .value) { snap in
            defer { group.leave() }
            guard let dict = snap.value as? [String: [String: Any]] else {
                firstError = "Failed to read AppData/Ranko/CategoryData/Defintions"; return
            }
            self.categoryDataRaw = dict
        }

        group.enter()
        db.child("Ranko").child("CategoryData").child("Hierarchy").observeSingleEvent(of: .value) { snap in
            defer { group.leave() }
            guard let dict = snap.value as? [String: [String: Any]] else {
                firstError = "Failed to read AppData/Ranko/CategoryData/Hierarchy"; return
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
        return SampleCategoryChip(id: id, name: name, icon: icon, colour: "0xFFCF00", synonyms:  synonyms, level: level)
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
                Image(systemName: categoryChip.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
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
}

/// The custom tab bar with a matched geometry effect.
struct CustomTabBar: View {
    @State private var trayViewOpen: Bool
    // Use the same stored string for the tint.
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
                    .shadow(color: Color.white.opacity(0.2), radius: 5, x: 5, y: 5)
                    .shadow(color: Color.white.opacity(0.1), radius: 5, x: -5, y: -5)
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

