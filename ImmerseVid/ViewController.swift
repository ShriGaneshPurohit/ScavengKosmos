//
//  ViewController.swift
//  ImmerseVid
//
//  Created by ShriGanesh K Purohit on 01/03/25.
//


import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import Combine

// MARK: - Game State
class GameState: ObservableObject {
    @Published var username: String = ""
    @Published var score: Int = 0
    @Published var timeRemaining: Int = 300
    @Published var foundItems: Set<String> = []
    @Published var currentItemToFind: String = ""
    @Published var currentHintIndex: Int = 0
    @Published var currentClue: String = "Find the first marker to begin"
    @Published var showFoundAnimation: Bool = false
    @Published var lastFoundItem: String = ""
    @Published var isGameActive: Bool = false
    @Published var gameWon: Bool = false
    @Published var showingEndGameAlert: Bool = false
    
    // Game data
    let videoMapping: [String: String] = [
        "clue_1": "clue_1",
        "clue_2": "clue_2",
        "clue_5": "clue_5",
        
    ]
    
    let itemPointValues: [String: Int] = [
        "clue_1": 20,
        "clue_2": 30,
        "clue_5": 50
    ]
    
    let clueHints: [ClueHint] = [
        ClueHint(itemName: "clue_1", hints: ["I stand tall, giving shade.","With green arms, I sway high", "With green arms, I sway high"]),
        ClueHint(itemName: "clue_2", hints: ["I hold stories, turn my pages.", "Words and wisdom, stacked in rows.", "Find me where knowledge flows."]),
        ClueHint(itemName: "clue_5", hints: ["Find the chest, claim your prize.", "Golden lock, secrets inside.", "Your journey ends where treasures hide."])
    ]
    
    let videoDimensions: [String: CGSize] = [
        "clue_1": CGSize(width: 768, height: 1280),
        "clue_2": CGSize(width: 768, height: 1280),
        "clue_5": CGSize(width: 768, height: 1280)
     
    ]
    
    // Ordered progression of items
    let gameItemsOrder: [String] = ["clue_1", "clue_2", "clue_5"]
    
    var timer: AnyCancellable?
    
    func startGame() {
        // Reset game state
        score = 0
        timeRemaining = 300
        foundItems.removeAll()
        currentHintIndex = 0
        showFoundAnimation = false
        isGameActive = true
        
        // Set the first item to find
        if !gameItemsOrder.isEmpty {
            currentItemToFind = gameItemsOrder[0]
            currentClue = "Find item: \(currentItemToFind)"
        }
        
        // Start timer
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isGameActive else { return }
                
                self.timeRemaining -= 1
                
                if self.timeRemaining <= 0 {
                    self.endGame(won: false)
                }
            }
    }
    
    func endGame(won: Bool) {
        isGameActive = false
        gameWon = won
        showingEndGameAlert = true
        timer?.cancel()
    }
    
    func canRecognizeItem(_ imageName: String) -> Bool {
        // First item is always recognizable
        if foundItems.isEmpty && imageName == gameItemsOrder[0] {
            return true
        }
        
        // Otherwise, must follow the progression
        let currentIndex = foundItems.count
        if currentIndex < gameItemsOrder.count {
            return imageName == gameItemsOrder[currentIndex]
        }
        
        return false
    }
    
    func getNextItemToFind() -> String? {
        let currentIndex = foundItems.count
        if currentIndex < gameItemsOrder.count {
            return gameItemsOrder[currentIndex]
        }
        return nil
    }
    
    func processFoundItem(_ itemName: String) {
        if !foundItems.contains(itemName) && canRecognizeItem(itemName) {
            foundItems.insert(itemName)
            lastFoundItem = itemName
            showFoundAnimation = true
            
            if let points = itemPointValues[itemName] {
                score += points
            }
            
            // Update progress
            if let nextItem = getNextItemToFind() {
                // Set next item to find
                currentItemToFind = nextItem
                currentClue = "Find item: \(nextItem)"
                currentHintIndex = 0
            } else {
                // All items found
                currentClue = "Great job! You've found everything!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.endGame(won: true)
                }
            }
            
            // Hide animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showFoundAnimation = false
            }
        }
    }
    
    func showNextHint() {
        if let clueHint = clueHints.first(where: { $0.itemName == currentItemToFind }) {
            if currentHintIndex < clueHint.hints.count {
                currentClue = clueHint.hints[currentHintIndex]
                currentHintIndex += 1
            } else {
                currentClue = "No more hints for this item!"
            }
        }
    }
}

// MARK: - Game Data Models
struct ClueHint: Identifiable {
    let id = UUID()
    let itemName: String
    let hints: [String]
}

// MARK: - AR View Representable
struct ARSceneView: UIViewRepresentable {
    @ObservedObject var gameState: GameState
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        sceneView.showsStatistics = true
        
        // Configure AR session
        let configuration = ARImageTrackingConfiguration()
        if let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "huntCluesImages", bundle: Bundle.main) {
            configuration.trackingImages = trackedImages
            configuration.maximumNumberOfTrackedImages = trackedImages.count
        }
        
        sceneView.session.run(configuration)
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Updates happen in coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARSceneView
        var players: [String: AVPlayer] = [:]
        
        init(_ parent: ARSceneView) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            let node = SCNNode()
            
            if let imageAnchor = anchor as? ARImageAnchor {
                let imageName = imageAnchor.referenceImage.name ?? ""
                
                // Check if this item should be recognized based on game progression
                if parent.gameState.canRecognizeItem(imageName) {
                    // Process found item
                    DispatchQueue.main.async {
                        self.parent.gameState.processFoundItem(imageName)
                    }
                    
                    // Create video node
                    if let videoFileName = parent.gameState.videoMapping[imageName],
                       let videoURL = Bundle.main.url(forResource: videoFileName, withExtension: "mp4") {
                        let player: AVPlayer
                        
                        if let existingPlayer = players[imageName] {
                            player = existingPlayer
                        } else {
                            player = AVPlayer(url: videoURL)
                            players[imageName] = player
                        }
                        
                        let videoNode = SKVideoNode(avPlayer: player)
                        
                        player.actionAtItemEnd = .none
                        
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                        
                        player.play()
                        
                        let videoSize = parent.gameState.videoDimensions[imageName] ?? CGSize(width: 1000, height: 1000)
                        
                        let videoScene = SKScene(size: videoSize)
                        videoNode.position = CGPoint(x: videoScene.size.width / 2, y: videoScene.size.height / 2)
                        videoNode.yScale = -1.0
                        videoScene.addChild(videoNode)
                        
                        let plane = SCNPlane(
                            width: imageAnchor.referenceImage.physicalSize.width,
                            height: imageAnchor.referenceImage.physicalSize.height
                        )
                        plane.firstMaterial?.diffuse.contents = videoScene
                        
                        let planeNode = SCNNode(geometry: plane)
                        planeNode.eulerAngles.x = -.pi / 2
                        node.addChildNode(planeNode)
                    }
                } else {
                    // Wrong sequence - provide feedback
                    DispatchQueue.main.async {
                        self.parent.gameState.currentClue = "You must find \(self.parent.gameState.currentItemToFind) first!"
                    }
                    
                    // Add a red overlay to indicate wrong item
                    let plane = SCNPlane(
                        width: imageAnchor.referenceImage.physicalSize.width,
                        height: imageAnchor.referenceImage.physicalSize.height
                    )
                    plane.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
                    
                    let planeNode = SCNNode(geometry: plane)
                    planeNode.eulerAngles.x = -.pi / 2
                    node.addChildNode(planeNode)
                }
            }
            
            return node
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let imageAnchor = anchor as? ARImageAnchor {
                    let imageName = imageAnchor.referenceImage.name ?? ""
                    if let player = players[imageName] {
                        if imageAnchor.isTracked {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
                }
            }
        }
    }
}



// MARK: - Game View
struct GameView: View {
    @ObservedObject var gameState: GameState
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // AR View
            ARSceneView(gameState: gameState)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay UI
            VStack {
                // Header with name, score and timer
                HStack {
                    Text("Player: \(gameState.username)")
                        .font(.headline)
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Score: \(gameState.score)")
                        .font(.headline)
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(formatTime(gameState.timeRemaining))
                        .font(.headline)
                        .padding(10)
                        .background(gameState.timeRemaining < 60 ? Color.red.opacity(0.8) : Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
                Spacer()
                
                // Current objective and progress
                HStack {
                    Text("Found: \(gameState.foundItems.count)/\(gameState.gameItemsOrder.count)")
                        .font(.headline)
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Current: \(gameState.currentItemToFind)")
                        .font(.headline)
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Clue box
                Text(gameState.currentClue)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        gameState.showNextHint()
                    }) {
                        Text("Get Hint")
                            .font(.headline)
                            .padding(10)
                            .frame(minWidth: 120)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Exit Game")
                            .font(.headline)
                            .padding(10)
                            .frame(minWidth: 120)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 30)
            }
            
            // Item found animation
            if gameState.showFoundAnimation {
                Circle()
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack {
                            Text("Found!")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("\(gameState.lastFoundItem)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("+\(gameState.itemPointValues[gameState.lastFoundItem] ?? 0) points")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            gameState.startGame()
        }
        .onDisappear {
            gameState.timer?.cancel()
        }
        .alert(isPresented: $gameState.showingEndGameAlert) {
            Alert(
                title: Text(gameState.gameWon ? "Congratulations!" : "Time's Up!"),
                message: Text("\(gameState.username), your final score: \(gameState.score)"),
                primaryButton: .default(Text("Play Again")) {
                    gameState.startGame()
                },
                secondaryButton: .destructive(Text("Exit")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - SwiftUI App
@main
struct ImmerseVidApp: App {
    @StateObject private var gameState = GameState()
    
    var body: some Scene {
        WindowGroup {
            WelcomeView(gameState: gameState)
        }
    }
}
