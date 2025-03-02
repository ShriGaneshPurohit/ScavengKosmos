//
//  WelcomeView.swift
//  ImmerseVid
//
//  Created by ShriGanesh K Purohit on 01/03/25.
//

import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import Combine
// MARK: - Welcome Screen
struct WelcomeView: View {
    @ObservedObject var gameState: GameState
    @State private var navigateToGame = false
    @State private var showInvalidNameAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Add ScrollView here to make content accessible
                ScrollView {
                    VStack(spacing: 30) {
                        // Title
                        Text("AR Scavenger Hunt")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                        
                        // Logo or Image
                        Image(systemName: "camera.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                            )
                        
                        // Username input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Enter Your Name:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("", text: $gameState.username)
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(10)
                                .font(.title3)
                        }
                        .padding(.horizontal, 30)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Game Instructions:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("1. Find AR markers in sequence\n2. Scan them with your camera\n3. Follow the clues\n4. Collect all items before time runs out!")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 30)
                        
                        // Start button
                        Button(action: {
                            if gameState.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showInvalidNameAlert = true
                            } else {
                                navigateToGame = true
                            }
                        }) {
                            Text("Start Game")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green)
                                )
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 50)
                        .padding(.top, 20)
                    }
                    .padding(.vertical, 30)
                }
                
                NavigationLink(
                    destination: GameView(gameState: gameState)
                        .navigationBarBackButtonHidden(true),
                    isActive: $navigateToGame
                ) {
                    EmptyView()
                }
            }
            .alert(isPresented: $showInvalidNameAlert) {
                Alert(
                    title: Text("Invalid Name"),
                    message: Text("Please enter your name to start the game."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
