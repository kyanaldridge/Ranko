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
    @State private var freeBoxCount: Double = 5
    @State private var animateLeftSymbol: Bool = false
    @State private var animateRightSymbol: Bool = false
    
    @State private var showSettings = false
    @State private var showLeaderboard = false
    
    // app storage shi
    @AppStorage("totalBlindSequenceGamesPlayed") private var totalGamesPlayed = 0
    @AppStorage("BlindSequenceHighScore") private var highScore = 0
    @AppStorage("BlindSequenceHighScoreTime") private var highScoreTime: Double = .infinity
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
            // Background Layer
            GeometryReader { proxy in
                let size = proxy.size
                Image("BlindSequence_Background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .colorMultiply(Color(hex: 0xFFA500))
                    .brightness(0.5)
            }
            .ignoresSafeArea()
            VStack(spacing: 20) {
                // Time and Icons
                HStack {
                    HStack(spacing: 20) {
                        Button(action: { showLeaderboard = true }) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(Color(hex: 0xD9741C))
                        }
                        .sheet(isPresented: $showLeaderboard) {
                            BlindSequenceLeaderboard()
                                .presentationDragIndicator(.visible)
                                .presentationDetents([.medium, .large])
                        }
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(Color(hex: 0xD9741C))
                        }
                        .sheet(isPresented: $showSettings) {
                            BlindSequenceSettings(
                                totalGamesPlayed: $totalGamesPlayed,
                                highScore: $highScore,
                                highScoreTime: $highScoreTime
                            )
                            .presentationDragIndicator(.visible)
                            .presentationDetents([.medium])
                        }
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: 0xD9741C))
                    }
                }
                .font(.title2)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                Text("Blind Sequence")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .overlay(
                        LinearGradient(
                            colors: [Color(hex: 0xd36918), Color(hex: 0xdf831e)],
                            startPoint: .top,
                            endPoint: .bottom)
                    )
                    .mask(
                        Text("Blind Sequence")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .textCase(.uppercase)
                    )
                    .padding()
                
                // Horizontal Scroll of Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        DailyChallengeCard()
                        ThemeCard()
                        EventCard()
                    }
                    .padding(.horizontal)
                }
                
                // Goals
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Challenges")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: 0xAC5F19))
                        .padding(.horizontal)
                    
                    HStack(spacing: 0) {
                        Text("Coming Soon...")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: 0x873F0F))
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: 0xFFEBBC))
                            .shadow(color: Color(hex: 0x873F0F).opacity(0.2), radius: 3)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    
                    ProgressView(value: 0.45)
                        .accentColor(.blue)
                        .padding(.horizontal)
                }
                
                
                Spacer()
                
                VStack {
                    // New Game Button
                    Button(action: {
                        gameType = .challenge
                        startChallenge()
                    }) {
                        Text("New Game")
                            .font(.system(size: 16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .foregroundColor(Color(hex: 0x873F0F))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                    .padding(.bottom, 8)
                    
                    Button(action: {
                        gameType = .free
                        mode = .freeSetup
                        freePlayScore = 0
                    }) {
                        Text("Free Play")
                            .font(.system(size: 16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .foregroundColor(Color(hex: 0x873F0F))
                    .tint(LinearGradient(gradient: Gradient(colors: [Color(hex: 0xFFFBF1), Color(hex: 0xFEF4E7)]),
                                         startPoint: .top,
                                         endPoint: .bottom
                                        ))
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 60)
                
                Spacer()
                
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Records")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: 0xAC5F19))
                        .padding(.horizontal)
                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Games Played: \(totalGamesPlayed)")
//                            .font(.system(size: 16, weight: .bold, design: .rounded))
//                            .foregroundColor(Color(hex: 0x873F0F))
//                        Text("High Score: \(highScore)")
//                            .font(.system(size: 16, weight: .bold, design: .rounded))
//                            .foregroundColor(Color(hex: 0x873F0F))
//                        if highScore > 0 {
//                            Text("Time to High Score: \(Int(highScoreTime))s")
//                                .font(.system(size: 16, weight: .bold, design: .rounded))
//                                .foregroundColor(Color(hex: 0x873F0F))
//                        }
//                    }
//                    .font(.system(size: 14, weight: .bold))
//                    .padding()
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .background(
//                        RoundedRectangle(cornerRadius: 16)
//                            .fill(Color(hex: 0xFFEBBC))
//                            .shadow(color: Color(hex: 0x873F0F).opacity(0.2), radius: 3)
//                    )
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack {
                            VStack {
                                Text("\(totalGamesPlayed)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: 0x873F0F))
                                    .lineLimit(1)
                                    .allowsTightening(true)
                                Text("Games Played")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: 0x873F0F))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0xFFEBBC))
                                    .shadow(color: Color(hex: 0x873F0F).opacity(0.2), radius: 3)
                            )
                            VStack {
                                Text("\(highScore)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: 0x873F0F))
                                    .lineLimit(1)
                                    .allowsTightening(true)
                                Text("High Score")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: 0x873F0F))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0xFFEBBC))
                                    .shadow(color: Color(hex: 0x873F0F).opacity(0.2), radius: 3)
                            )
                            if highScore > 0 {
                                VStack {
                                    Text("\(Int(highScoreTime))s")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: 0x873F0F))
                                        .lineLimit(1)
                                        .allowsTightening(true)
                                    Text("Time To Beat")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: 0x873F0F))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(hex: 0xFFEBBC))
                                        .shadow(color: Color(hex: 0x873F0F).opacity(0.2), radius: 3)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
        }
        
        
    }

    
    // MARK: - Free Play Setup
    var freeSetupView: some View {
        VStack(spacing: 20) {
            Text("Select number of boxes (Max 20)")
                .font(.headline)
            VStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 90, height: 30)
                    .overlay(
                        Text("\(Int(freeBoxCount)) Boxes")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                    .cornerRadius(5)
                HStack {
                    Image(systemName: "rectangle.grid.1x2.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue.opacity(0.7))
                        .bold()
                        .symbolEffect(.wiggle, options: animateLeftSymbol ? .repeating : .nonRepeating, value: freeBoxCount)
                    Slider(value: $freeBoxCount, in: 2...20)
                        .padding(.horizontal, 15)
                        .accentColor(.blue.opacity(0.7))
                    Image(systemName: "rectangle.grid.3x3.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue.opacity(0.7))
                        .bold()
                        .symbolEffect(.wiggle, options: animateRightSymbol ? .repeating : .nonRepeating, value: freeBoxCount)
                }
            }
            Button(action: {
                startGame(boxCount: Int(freeBoxCount))
                freePlayScore = 0
            }) {
                Text("Start")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(40)
                    .padding(.horizontal)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Game Board
    @available(iOS 26.0, *)
    @ViewBuilder
    var gameView: some View {
        NavigationStack {
            ZStack {
                // Background Layer
                GeometryReader { proxy in
                    let size = proxy.size
                    Image("BlindSequence_Background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .colorMultiply(Color(hex: 0xFFA500))
                        .brightness(0.5)
                }
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Top Toolbar Buttons
                    HStack {
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
                                .font(.title2)
                                .foregroundColor(Color(hex: 0x884110))
                                .padding(4)
                                .fontWeight(.semibold)
                        }
                        .padding(10)
                        .buttonStyle(.glass)
                        .shadow(color: Color(hex: 0xE18938).opacity(0.8), radius: 3)
                        

                        Spacer()

                        Button {
                            score = 0
                            freePlayScore = 0
                            mode = .mainMenu
                        } label: {
                            Image(systemName: "house.fill")
                                .font(.title2)
                                .foregroundColor(Color(hex: 0x884110))
                                .padding(4)
                                .fontWeight(.semibold)
                        }
                        .padding(10)
                        .glassEffect()
                        .shadow(color: Color(hex: 0xE18938).opacity(0.8), radius: 3)
                    }
                    .padding(.horizontal)

                    // Glass Letter Box (Square)
                    
                    Text(showingRandomizing ? "?" : String(currentLetter ?? " "))
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(Color(hex: 0x884110))
                        .rotationEffect(.degrees(animateRotation ? 360 : 0))
                        .animation(
                            showingRandomizing
                            ? .linear(duration: 0.7).repeatCount(1, autoreverses: false)
                            : .default,
                            value: animateRotation
                        )
                        .frame(width: 150, height: 150)
                        .glassEffect(in: .rect(cornerRadius: 16))

                    // Status (Score, Lives, Timer)
                    HStack {
                        if gameType == .challenge {
                            Text("\(score)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            HStack(spacing: 12) {
                                ForEach(0..<maxLives, id: \.self) { index in
                                    HeartView(index: index,
                                              lives: lives,
                                              lostLifeIndex: lostLifeIndex,
                                              newLifeAnimation: newLifeAnimation)
                                }
                            }

                            Spacer()

                            Text("\(Int(elapsedTime))s")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else if gameType == .free {
                            Text("\(freePlayScore)/\(currentBoxCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            ProgressView(value: Float(freePlayScore), total: Float(currentBoxCount))
                                .animation(.easeInOut(duration: 0.5), value: freePlayScore)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.7))
                    )
                    .padding(.horizontal)

                    // Boxes Grid
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: min(currentBoxCount, 5))
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<currentBoxCount, id: \.self) { idx in
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.clear.opacity(0.7), lineWidth: 2)
                                    .glassEffect(.regular.interactive())
                                    .frame(width: 70, height: 70)

                                Text(boxes.indices.contains(idx) ? boxes[idx] : "")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: 0x884110))
                                    .bold()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { placeLetter(at: idx) }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 40)
                .onAppear(perform: generateLetter)
            }
        }
    }
    
    // MARK: - Overlay Panel
    var overlayView: some View {
        ZStack {
            // now covers the full screen
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text(isNewHighScore ? "New High Score!" : (didWin ? "Well Done!" : "Game Over"))
                    .font(.largeTitle).bold()
                    .foregroundColor(isNewHighScore ? .purple : (didWin ? .green : .red))

                if gameType == .challenge {
                    Text("Score: \(score)")
                    Text("Time: \(Int(elapsedTime))s")
                }

                VStack(spacing: 15) {
                    Button(didWin ? "Next Round" : "Restart") {
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
                    }
                    .buttonStyle(PrimaryButton())
                    
                    Button(didWin ? "Main Menu" : "Main Menu") {
                        if didWin {
                            score = 0
                            mode = .mainMenu
                            freePlayScore = 0
                        } else {
                            score = 0
                            mode = .mainMenu
                            freePlayScore = 0
                        }
                    }
                    .buttonStyle(PrimaryButton())
                }
            }
            .padding(30)
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .padding(40)
        }
        // pause/resume timer correctly
        .onAppear { isPaused = true }
        .onDisappear { isPaused = false }
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
        
        currentBoxCount += 1
        boxes = Array(repeating: "", count: currentBoxCount)
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
        pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        currentLetter = nil
        showingRandomizing = false
        animateRotation = false
        
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
            loseLife()
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

