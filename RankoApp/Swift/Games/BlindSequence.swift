//
//  BlindSequence.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 20/5/2025.
//

import SwiftUI
import FirebaseAnalytics
import Firebase
import Combine

struct BlindSequence: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var user_data = UserInformation.shared
    
    enum Mode { case mainMenu, freeSetup, playing, gameOver }
    enum GameType { case free, challenge }

    @State private var mode: Mode = .mainMenu
    @State private var gameType: GameType = .free
    @State private var didWin: Bool = false

    // letter setup
    @State private var isLetterActive = false
    @State private var isLetterReady = false

    // Board state
    @State private var currentBoxCount: Int = 0
    @State private var boxes: [String] = []
    @State private var pool: [Character] = []
    @State private var currentLetter: Character? = nil
    @State private var showingRandomizing = false
    @State private var animateRotation = false
    @State private var boxShakeValues: [CGFloat] = []

    // Challenge stats
    @State private var lives = 3
    private let maxLives = 5
    @State private var score = 0
    @State private var sessionScore = 0
    @State private var freePlayScore = 0
    @State private var newLifeAnimation: Bool = false

    // Timer
    @State private var startTime = Date()
    @State private var elapsedTime: TimeInterval = 0
    @State private var isPaused = false     // ← new
    @State private var lostLifeIndex: Int? = nil
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // freeSetup
    @State private var freeBoxCount: Double = 6
    @State private var animateLeftSymbol: Bool = false
    @State private var animateRightSymbol: Bool = false
    
    @State private var showSettings = false
    @State private var showLeaderboard = false
    @State private var opacityViewNo: Double = 0
    
    // app storage shi
    @AppStorage("totalBlindSequenceGamesPlayed") private var totalGamesPlayed = 0
    @AppStorage("BlindSequenceHighScore") private var highScore = 0
    @AppStorage("BlindSequenceHighScoreTime") private var highScoreTime: Double = .infinity
    @AppStorage("BS_MaxUnlockedLevel") private var maxUnlockedLevel: Int = 1   // progress
    @AppStorage("BS_SelectedLevel") private var selectedLevel: Int = 1         // last picked
    @State private var currentLevel: Int? = nil                                 // active level while playing (free)
    @State private var isNewHighScore = false

    var body: some View {
        ZStack {
            Group {
                switch mode {
                case .mainMenu:   mainMenuView
                case .freeSetup:  freeSetupView
                case .playing:    gameView
                case .gameOver:   gameView.overlay(overlayView)
                }
            }
            .onReceive(timer) { _ in
                // only tick when playing & not paused
                guard mode == .playing, gameType == .challenge, !isPaused else { return }
                elapsedTime = Date().timeIntervalSince(startTime)
            }
            .animation(.easeInOut, value: mode)
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "BlindSequence",
                AnalyticsParameterScreenClass: "BlindSequence"
            ])
        }
        .background(Color(.systemGroupedBackground))
    }
    
    var mainMenuView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF76000), Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00), Color(hex: 0x800100)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .black, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.horizontal, 1)
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0xC03700))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal, 30)
                Spacer()
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("B")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("L")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("I")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("N")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("D")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                }
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("S")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("Q")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("U")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("N")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("C")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x8E0F00))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("E")
                                .font(.custom("Nunito-Black", size: 26))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        )
                }
                Spacer()
                HStack(spacing: 6) {
                    Button { showLeaderboard = true } label: {
                        Image(systemName: "trophy.fill")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    .sheet(isPresented: $showLeaderboard) {
                        BlindSequenceLeaderboard()
                            .presentationDragIndicator(.visible)
                            .presentationDetents([.medium, .large])
                    }
                    
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 6)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    .sheet(isPresented: $showSettings) {
                        BlindSequenceSettings(
                            totalGamesPlayed: $totalGamesPlayed,
                            highScore: $highScore,
                            highScoreTime: $highScoreTime
                        )
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.medium])
                    }
                    
                    Button {
                        gameType = .challenge
                        startChallenge()
                    } label: {
                        Spacer()
                        Text("Challenge")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity)
                        Spacer()
                        VStack(spacing: -5) {
                            Text("SCORE")
                                .font(.custom("Nunito-Black", size: 10))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("\(highScore)")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding(.trailing, 10)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal)
                
                HStack(spacing: 6) {
                    Button {} label: {
                        HStack {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("Themes")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                        }
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                    
                    Button {
                        gameType = .free
                        mode = .freeSetup
                        freePlayScore = 0
                    } label: {
                        Spacer()
                        Text("Classic")
                            .font(.custom("Nunito-Black", size: 24))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity)
                        Spacer()
                        VStack(spacing: -5) {
                            Text("LEVEL")
                                .font(.custom("Nunito-Black", size: 10))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("\(maxUnlockedLevel)")
                                .font(.custom("Nunito-Black", size: 24))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding(.trailing, 10)
                    }
                    .tint(Color(hex: 0x8E0F00))
                    .buttonStyle(.glassProminent)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.horizontal)
                Spacer()
                Spacer()
                Spacer()
            }
        }
        
        
    }
    
    // MARK: - Free Play Setup
    var freeSetupView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF76000), Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00), Color(hex: 0x800100)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Select A Level")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                // 4-column grid of 1...24
                let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(1...24, id: \.self) { level in
                        let isUnlocked = level <= maxUnlockedLevel
                        Button {
                            if isUnlocked { selectedLevel = level }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isUnlocked
                                          ? (selectedLevel == level ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
                                          : Color.black.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedLevel == level && isUnlocked ? Color.white.opacity(0.8) : Color.white.opacity(0.25), lineWidth: 2)
                                    )
                                    .frame(height: 56)
                                
                                HStack(spacing: 8) {
                                    if isUnlocked {
                                        Text("\(level)")
                                            .font(.system(size: 20, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 18, weight: .black))
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(level)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .disabled(!isUnlocked)
                    }
                }
                .padding(.horizontal)
                
                Button(action: {
                    // start selected level in FREE mode
                    let count = boxCount(for: selectedLevel)
                    currentLevel = selectedLevel
                    freePlayScore = 0
                    gameType = .free
                    startGame(boxCount: count)
                }) {
                    Text("Start Level \(selectedLevel)")
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: 0xFFFFFF))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .environment(\.colorScheme, .dark)
                
                Spacer()
                
                HStack {
                    Button {
                        mode = .mainMenu
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 40)
        }
    }
    
    private func unlockNextLevelIfNeeded() {
        guard gameType == .free, didWin, let lvl = currentLevel else { return }
        if lvl == maxUnlockedLevel && lvl < 24 {
            maxUnlockedLevel = lvl + 1
        }
    }
    
    var layoutForCount: [Int: [Int]] = [
        1: [1],
        2: [2],
        3: [3],
        4: [4],
        5: [2, 3],
        6: [3, 3],
        7: [3, 4],
        8: [4, 4],
        9: [4, 5],
        10: [5, 5],
        11: [3, 4, 4],
        12: [4, 4, 4],
        13: [4, 5, 4],
        14: [4, 5, 5],
        15: [5, 5, 5],
        16: [4, 4, 4, 4],
        17: [4, 4, 4, 5],
        18: [4, 4, 5, 5],
        19: [4, 5, 5, 5],
        20: [5, 5, 5, 5],
        21: [4, 4, 4, 4, 5],
        22: [4, 4, 4, 5, 5],
        23: [4, 4, 5, 5, 5],
        24: [4, 5, 5, 5, 5],
        25: [5, 5, 5, 5, 5]
    ]
    
    // MARK: - Game Board
    @available(iOS 26.0, *)
    @ViewBuilder
    var gameView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0xF76000),
                        Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00),
                        Color(hex: 0x800100)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundColor((gameType == .free) ? .clear : Color(hex: 0xFFFFFF))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill((gameType == .free) ? .clear : Color(hex: 0x650E02))
                            )

                    Spacer()
                    
                    VStack(spacing: 20) {
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: 0x8E0F00))
                            .frame(width: 160, height: 160)
                            .overlay(
                                Text(showingRandomizing ? "?" : String(currentLetter ?? " "))
                                    .font(.custom("Nunito-Black", size: 90))
                                    .foregroundColor(Color(hex: 0xFFFFFF))
                                    .rotationEffect(.degrees(animateRotation ? 360 : 0))
                                    .animation(
                                        showingRandomizing
                                        ? .linear(duration: 0.7).repeatCount(1, autoreverses: false)
                                        : .default,
                                        value: animateRotation
                                    )
                            )
                        
                        ZStack {
                            if gameType == .free {
                                HStack(spacing: 15) {
                                    Text("\(freePlayScore)/\(currentBoxCount)")
                                        .font(.custom("Nunito-Black", size: 15))
                                        .foregroundColor(Color(hex: 0xFFFFFF))

                                    ProgressView(value: Float(freePlayScore), total: Float(currentBoxCount))
                                        .animation(.easeInOut(duration: 0.5), value: freePlayScore)
                                        .tint(Color(hex: 0xBF3600))
                                        .background(Color(hex: 0x696969))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: 0x650E02))
                                    )
                            }
                            if gameType == .challenge {
                                HStack {
                                    Spacer()
                                    Text("\(Int(elapsedTime))s")
                                        .font(.custom("Nunito-Black", size: 15))
                                        .foregroundColor(Color(hex: 0xFFFFFF))
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color(hex: 0x650E02))
                                        )
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                }
                            }
                            if gameType == .challenge {
                                HStack {
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    Spacer()
                                    HStack(spacing: 6) {
                                        ForEach(0..<maxLives, id: \.self) { index in
                                            HeartView(index: index,
                                                      lives: lives,
                                                      lostLifeIndex: lostLifeIndex,
                                                      newLifeAnimation: newLifeAnimation)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(hex: 0x650E02))
                                    )
                                    Spacer()
                                }
                            }
                        }
                        
                        // 🔽🔽🔽 replaced grid logic starts here
                        let count = max(0, Int(currentBoxCount))
                        let pattern = layoutForCount[count] ?? defaultPattern(for: count)
                        
                        VStack(spacing: 10) {
                            ForEach(0..<pattern.count, id: \.self) { row in
                                let rowCount = pattern[row]
                                let gridItems = Array(
                                    repeating: GridItem(.flexible(), spacing: 10),
                                    count: rowCount
                                )
                                
                                LazyVGrid(columns: gridItems, alignment: .center, spacing: 10) {
                                    let start = pattern.prefix(row).reduce(0, +)
                                    let end = min(start + rowCount, count)
                                    ForEach(start..<end, id: \.self) { idx in
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(hex: 0x8E0F00))
                                            .frame(minWidth: 65, minHeight: 65)
                                            .overlay(
                                                Text(boxes.indices.contains(idx) ? boxes[idx] : "")
                                                    .font(.custom("Nunito-Black", size: 38))
                                                    .foregroundColor(Color(hex: 0xFFFFFF))
                                            )
                                            .accessibilityLabel("box \(idx + 1)")
                                            .onTapGesture { placeLetter(at: idx) }
                                            .modifier(ShakeEffect(travelDistance: 10, shakesPerUnit: 3, animatableData: boxShakeValues.indices.contains(idx) ? boxShakeValues[idx] : 0))
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                    Spacer()
                    Spacer()

                    HStack {
                        Spacer()
                        Button {
                                if gameType == .challenge {
                                    startChallenge()
                                } else if gameType == .free {
                                    restartRound()
                                    freePlayScore = 0
                                    score = 0
                                }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20, weight: .black, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.glass)

                        Spacer()
                        Button {
                            score = 0
                            freePlayScore = 0
                            mode = .mainMenu
                        } label: {
                            Image(systemName: "house.fill")
                                .font(.system(size: 24, weight: .black, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)

                        Spacer()
                        Button {} label: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 18, weight: .regular, design: .default))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        Spacer()
                    }
                    .padding(.vertical, -10)
                    .padding(.horizontal, 10)
                }
                .padding()
            }
        }
    }
    
    // fallback layout if not customized above
    // tweak this to your taste (e.g., prefer rows of 4, then remainder)
    private func defaultPattern(for n: Int) -> [Int] {
        guard n > 0 else { return [] }
        if n <= 4 { return [n] }
        if n == 5 { return [2, 3] }
        if n == 6 { return [3, 3] }

        // generic: fill rows of 5 until done (change 5 to whatever you like)
        let perRow = 5
        var res: [Int] = []
        var remaining = n
        while remaining > 0 {
            let take = min(perRow, remaining)
            res.append(take)
            remaining -= take
        }
        return res
    }
    
    // MARK: - Overlay Panel
    var overlayView: some View {
        ZStack {
            // now covers the full screen
            Color.black.opacity(opacityViewNo)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isNewHighScore ? "New High Score!" : (didWin ? "Well Done!" : "Game Over"))
                    .font(.custom("Nunito-Black", size: 28))
                    .foregroundColor(Color(hex: 0xFFFFFF))

                if gameType == .challenge {
                    HStack {
                        VStack {
                            Text("Score")
                                .font(.custom("Nunito-Black", size: 22))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("\(score)")
                                .font(.custom("Nunito-Black", size: 27))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: 0x650E02))
                            )
                        VStack {
                            Text("Time")
                                .font(.custom("Nunito-Black", size: 22))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                            Text("\(Int(elapsedTime))")
                                .font(.custom("Nunito-Black", size: 27))
                                .foregroundColor(Color(hex: 0xFFFFFF))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: 0x650E02))
                            )
                    }
                }
                
                

                HStack(spacing: 8) {
                    Button(action: {
                        if didWin {
                            score = 0
                            mode = .mainMenu
                            freePlayScore = 0
                        } else {
                            score = 0
                            mode = .mainMenu
                            freePlayScore = 0
                        }
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .environment(\.colorScheme, .dark)
                    
                    Button(action: {
                        if didWin {
                            nextRound()
                        } else {
                            if gameType == .challenge {
                                startChallenge()
                            } else {
                                restartRound()
                                score = 0
                                freePlayScore = 0
                            }
                        }
                    }) {
                        Text(didWin ? "Next Round" : "Restart")
                            .font(.custom("Nunito-Black", size: 26))
                            .foregroundColor(Color(hex: 0xFFFFFF))
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .environment(\.colorScheme, .dark)
                }
            }
            .padding(30)
            .background(LinearGradient(
                colors: [
                    Color(hex: 0xD84A00), Color(hex: 0xBB3300), Color(hex: 0x9E1C00)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea().opacity(0.9))
            .cornerRadius(12)
            .padding(40)
        }
        // pause/resume timer correctly
        .onAppear {
            isPaused = true
            opacityViewNo = 0
            withAnimation(.easeInOut(duration: 0.3)) {
                opacityViewNo = 0.6
            }
        }
        .onDisappear { isPaused = false }
    }
    
    private func boxCount(for level: Int) -> Int {
        // level 1 = 2 boxes, level 24 = 25 boxes (cap if you want lower)
        return min(level + 1, 25)
    }
    
    // MARK: - Helpers
    private func canFit(_ letter: Character) -> Bool {
        for idx in 0..<currentBoxCount {
            if boxes[idx].isEmpty {
                let lower = boxes[0..<idx].compactMap { $0.first }.last
                let upper = boxes[(idx+1)..<currentBoxCount].compactMap { $0.first }.first
                if (lower == nil || lower! < letter) && (upper == nil || letter < upper!) {
                    return true
                }
            }
        }
        return false
    }
    
    private func canPlace(_ letter: Character, at idx: Int) -> Bool {
        let lower = boxes[0..<idx].compactMap { $0.first }.last
        let upper = boxes[(idx+1)..<currentBoxCount].compactMap { $0.first }.first
        return (lower == nil || lower! < letter) && (upper == nil || letter < upper!)
    }
    
    private func nextRound() {
        mode = .playing
        didWin = false
        freePlayScore = 0
        
        if gameType == .free {
            // advance to next level if unlocked
            if let lvl = currentLevel {
                let next = min(lvl + 1, 24)
                currentLevel = next
                selectedLevel = next
                let count = boxCount(for: next)
                currentBoxCount = count
                boxes = Array(repeating: "", count: count)
                boxShakeValues = Array(repeating: 0, count: currentBoxCount)
            }
        } else {
            // existing challenge behavior
            currentBoxCount += 1
            boxes = Array(repeating: "", count: currentBoxCount)
            boxShakeValues = Array(repeating: 0, count: currentBoxCount)
        }
        
        pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        currentLetter = nil
        showingRandomizing = false
        animateRotation = false

        // Add this line to regenerate a life (but not exceed max)
        if gameType == .challenge {
            lives = min(lives + 1, maxLives)
        }

        // shift startTime so elapsedTime continues where it left off
        startTime = Date().addingTimeInterval(-elapsedTime)

        generateLetter()
    }

    
    private func restartRound() {
        isNewHighScore = false
        mode = .playing
        didWin = false
        score = 0
        
        boxes = Array(repeating: "", count: currentBoxCount)
        boxShakeValues = Array(repeating: 0, count: currentBoxCount)
        pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        currentLetter = nil
        showingRandomizing = false
        animateRotation = false
        
        // shift startTime so elapsedTime continues where it left off
        startTime = Date().addingTimeInterval(-elapsedTime)
        
        generateLetter()
    }
    
    // MARK: - Game Logic
    private func startGame(boxCount: Int) {
        // only used when you first start or restart from menu
        isNewHighScore = false
        sessionScore = 0
        currentBoxCount = boxCount
        boxes = Array(repeating: "", count: boxCount)
        boxShakeValues = Array(repeating: 0, count: boxCount)
        pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        currentLetter = nil
        showingRandomizing = false
        animateRotation = false
        
        if gameType == .free {
            // infer currentLevel from the chosen box count
            let lvl = max(1, min(24, boxCount - 1))
            currentLevel = lvl
        }
        
        if gameType == .challenge {
            lives = 3
            score = 0
            elapsedTime = 0
            startTime = Date()
        }
        didWin = false
        mode = .playing
        isPaused = false
        generateLetter()
    }
    
    private func startChallenge() {
        sessionScore = 0
        totalGamesPlayed += 1
        gameType = .challenge
        startGame(boxCount: 2)
        
        Analytics.logEvent("game", parameters: [
            "gamePlayed": "BlindSequence",
        ])
    }
    
    private func generateLetter() {
        guard mode == .playing else { return }

        // End the round if board is full
        if !boxes.contains("") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                didWin = (gameType == .free || (gameType == .challenge && currentBoxCount < 20))
                mode = .gameOver
                unlockNextLevelIfNeeded()
            }
            return
        }

        isLetterReady = false
        showingRandomizing = true
        animateRotation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showingRandomizing = false
            animateRotation = false

            guard let letter = pool.randomElement() else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    didWin = false
                    mode = .gameOver
                }
                return
            }

            currentLetter = letter
            isLetterReady = true // ✅ NOW user can interact

            // Auto-fail if letter can’t be placed
            if !canFit(letter) {
                loseLife()
            }
        }
    }
    
    private func placeLetter(at idx: Int) {
        guard let letter = currentLetter, isLetterReady else { return }
        
        if boxes[idx].isEmpty && canPlace(letter, at: idx) {
            boxes[idx] = String(letter)
            pool.removeAll { $0 == letter }
            if gameType == .challenge {
                score += 1
                sessionScore += 1 // ✅ add to session
            } else if gameType == .free {
                freePlayScore += 1
            }
            isLetterReady = false
            generateLetter()
        } else if boxes[idx].isEmpty {
            if boxShakeValues.indices.contains(idx) {
                withAnimation(.default) {
                    boxShakeValues[idx] += 1   // increment to drive ShakeEffect
                }
            }
        }
    }
    
    // MARK: – Life loss (challenge only)
    private func loseLife() {
        guard gameType == .challenge else {
            // free-play fail
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                didWin = false
                mode = .gameOver
                if sessionScore > highScore {
                    highScore = sessionScore
                    highScoreTime = elapsedTime
                    isNewHighScore = true
                } else if sessionScore == highScore && elapsedTime < highScoreTime {
                    highScoreTime = elapsedTime
                    isNewHighScore = true
                } else {
                    isNewHighScore = false
                }
            }
            return
        }

        // Remove the bad letter so it can't be drawn again immediately
        if let letter = currentLetter {
            pool.removeAll { $0 == letter }
        }

        // trigger heart pop animation on the heart being lost
        lostLifeIndex = lives - 1
        withAnimation {
            lives -= 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if lives <= 0 {
                if sessionScore > highScore {
                    highScore = sessionScore
                    highScoreTime = elapsedTime
                    isNewHighScore = true
                    updateLeaderboardIfNeeded()
                } else if sessionScore == highScore && elapsedTime < highScoreTime {
                    highScoreTime = elapsedTime
                    isNewHighScore = true
                    updateLeaderboardIfNeeded()
                } else {
                    isNewHighScore = false
                }

                didWin = false
                mode = .gameOver
            } else {
                generateLetter()
            }
            lostLifeIndex = nil
        }
    }
    
    private func updateLeaderboardIfNeeded() {
        let userID = user_data.userID
        let userName = user_data.username
        let userImage = user_data.userProfilePicturePath

        guard !userID.isEmpty, !userName.isEmpty, !userImage.isEmpty else {
            print("🚫 Missing user data for leaderboard update.")
            return
        }

        let dbRef = Database.database().reference()
            .child("GameData")
            .child("Leaderboard")
            .child("BlindSequence")
            .child(userID)

        let leaderboardData: [String: Any] = [
            "username": userName,
            "image": userImage,
            "score": sessionScore,
            "time": Int(elapsedTime * 1000)
        ]

        dbRef.setValue(leaderboardData) { error, _ in
            if let error = error {
                print("❌ Failed to update leaderboard: \(error.localizedDescription)")
            } else {
                print("✅ Leaderboard updated successfully.")
            }
        }
    }
    
    // 1) A little model for each falling letter
    struct FallingLetter {
        let letter: String = String(UnicodeScalar(Int.random(in: 65...90))!) // A–Z
        let xPosition: Double = Double.random(in: 0...1)
        let speed: Double = Double.random(in: 30...100) // points per second
        let fontSize: Double = Double.random(in: 24...48)
        let startOffset: Double = Double.random(in: -300...0)
    }

    // 2) A square button style for corners
    struct CornerButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color(hex: 0xDC8536).opacity(0.7),
                        radius: configuration.isPressed ? 1 : 4,
                        x: 0, y: 2)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
        }
    }
    
    struct HeartView: View {
        let index: Int
        let lives: Int
        let lostLifeIndex: Int?
        let newLifeAnimation: Bool

        @State private var animatePulse = false
        @State private var heartColor: Color = .gray

        var isActive: Bool {
            index < lives
        }

        var body: some View {
            Image(systemName: "heart.fill")
                .foregroundColor(heartColor)
                .scaleEffect(animatePulse ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: animatePulse)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        heartColor = isActive ? .red : .gray
                    }
                    if isActive {
                        animatePulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animatePulse = false
                        }
                    }
                }
                .onChange(of: lives) { oldLives, newLives in
                    let wasActive = index < newLives
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(index)) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            heartColor = wasActive ? .red : .gray
                            animatePulse = wasActive
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animatePulse = false
                        }
                    }
                }
        }
    }
}


// MARK: - Button Style
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.7))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

#Preview {
    BlindSequence()
        .environmentObject(ProfileImageService())
}

struct DailyChallengeCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 30))
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("DAILY CHALLENGE")
                .font(.caption2)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text(Date(), formatter: DateFormatter.shortMonthDay)
                .font(.headline)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("Coming Soon...")
                .font(.footnote)
                .foregroundColor(Color(hex: 0xFFEBBC))
        }
        .frame(width: 140, height: 160)
        .background(LinearGradient(colors: [Color(hex: 0xD46C18), Color(hex: 0xE0851D)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(20)
    }
}

extension DateFormatter {
    static let shortMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d" // e.g., "June 16"
        return formatter
    }()
}

struct ThemeCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 25))
                .foregroundColor(Color(hex: 0xFFEBBC))
                .padding(.bottom, 3)
            Text("THEME")
                .font(.caption2)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("September")
                .font(.headline)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Button {
                
            } label: {
                Text("Pick Theme")
                    .font(.caption)
                    .fontWeight(.bold)
            }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color(hex: 0xFFEBBC))
                .foregroundColor(Color(hex: 0x87400F))
                .cornerRadius(12)
        }
        .frame(width: 140, height: 160)
        .background(LinearGradient(colors: [Color(hex: 0xD46C18), Color(hex: 0xE0851D)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(20)
    }
}

struct EventCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 30))
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("EVENTS")
                .font(.caption2)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("September")
                .font(.headline)
                .foregroundColor(Color(hex: 0xFFEBBC))
            Text("Coming Soon...")
                .font(.footnote)
                .foregroundColor(Color(hex: 0xFFEBBC))
        }
        .frame(width: 140, height: 160)
        .background(LinearGradient(colors: [Color(hex: 0xD46C18), Color(hex: 0xE0851D)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(20)
    }
}

struct GoalBox: View {
    var title: String
    var subtitle: String
    var bg: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(bg)
    }
}

struct BlindSequenceSettings: View {
    @Binding var totalGamesPlayed: Int
    @Binding var highScore: Int
    @Binding var highScoreTime: Double
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("unlocked_Medal_AppIcon") private var unlockedMedal: Bool = false
    @AppStorage("unlocked_Trophy_AppIcon") private var unlockedTrophy: Bool = false
    @AppStorage("unlocked_Crown_AppIcon") private var unlockedCrown: Bool = false
    @AppStorage("unlocked_Star_AppIcon") private var unlockedStar: Bool = false

    @State private var showConfirmReset = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Settings")
                .font(.largeTitle).bold()
                .padding(.top)

            Button(action: {
                showConfirmReset = true
                unlockedMedal = false
                unlockedTrophy = false
                unlockedCrown = false
                unlockedStar = false
            }) {
                Text("Reset Stats")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(40)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .alert("Are you sure?", isPresented: $showConfirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                totalGamesPlayed = 0
                highScore = 0
                highScoreTime = .infinity
            }
        } message: {
            Text("This will erase all gameplay records.")
        }
        .accentColor(.yellow)
    }
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let image: String
    let score: Int
    let time: Int // in milliseconds

    var formattedTime: String {
        String(format: "%.3fs", Double(time) / 1000)
    }
}

struct BlindSequenceLeaderboard: View {
    @State private var leaderboard: [LeaderboardEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆 Blind Sequence")
                .font(.title).bold()
                .padding(.top)

            Text("Leaderboard")
                .font(.title2)
                .foregroundColor(.blue.opacity(0.8))

            Divider()

            if isLoading {
                ProgressView("Loading Leaderboard...")
                    .padding(.top, 40)
            } else if leaderboard.isEmpty {
                Text("No leaderboard entries yet.")
                    .foregroundColor(.gray)
                    .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(leaderboard.enumerated()), id: \.1.id) { index, entry in
                            HStack(spacing: 16) {
                                // Rank badge
                                Text(rankBadge(for: index))
                                    .font(.title2).bold()
                                    .frame(width: 30)

                                // Image
                                AsyncImage(url: URL(string: entry.image)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue.opacity(0.5), lineWidth: 2))

                                // Name and score
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.username)
                                        .fontWeight(.semibold)

                                    HStack {
                                        Text("Score: \(entry.score)")
                                        Text("•")
                                        Text(entry.formattedTime)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear(perform: fetchLeaderboard)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func rankBadge(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(index + 1)"
        }
    }

    private func fetchLeaderboard() {
        let dbRef = Database.database().reference()
            .child("GameData")
            .child("Leaderboard")
            .child("BlindSequence")

        dbRef.observeSingleEvent(of: .value) { snapshot in
            var entries: [LeaderboardEntry] = []

            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any],
                   let username = data["username"] as? String,
                   let image = data["image"] as? String,
                   let score = data["score"] as? Int,
                   let time = data["time"] as? Int {
                    
                    let entry = LeaderboardEntry(
                        id: snap.key,
                        username: username,
                        image: image,
                        score: score,
                        time: time
                    )
                    entries.append(entry)
                }
            }

            // Sort by highest score, then by lowest time
            leaderboard = entries.sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                } else {
                    return $0.time < $1.time
                }
            }

            isLoading = false
        }
    }
}

struct NonogramConceptGameView_Previews: PreviewProvider {
    static var previews: some View {
        NonogramConceptGameView()
    }
}

struct NonogramConceptGameView: View {
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background Image with Gradient Masking
                GeometryReader { proxy in
                    let size = proxy.size
                    Image("BlindSequence_Background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .overlay {
                            Group {
                                if #available(iOS 26, *) {
                                    VStack {
                                        HStack {
                                            Button {
                                                
                                            } label: {
                                                Image(systemName: "arrow.counterclockwise")
                                                    .padding(5)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.glass)
                                            
                                            Spacer()
                                            
                                            Button {
                                                
                                            } label: {
                                                Image(systemName: "house")
                                                    .padding(5)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.semibold)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.glass)
                                        }
                                        Spacer()
                                    }
                                    .padding(25)
                                    .opacity(0.7)
                                } else {
                                    VStack {
                                        HStack {
                                            Button {
                                                
                                            } label: {
                                                Image(systemName: "arrow.counterclockwise")
                                                    .padding(5)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                                    .font(.title3)
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                
                                            } label: {
                                                Image(systemName: "house")
                                                    .padding(5)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                                    .font(.title3)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(25)
                                    .opacity(0.7)
                                }
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }
    }
}

