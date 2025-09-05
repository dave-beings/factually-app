import SwiftUI

/// The main view of the app with the listen button and results
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    // SECTION 1: Top section for main title
                    VStack(spacing: 16) {
                        if viewModel.isLookBackEnabled {
                            // Look Back mode title
                            Text("Look Back Active")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            // Standard mode title
                            Text("Factually 🧐")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // SECTION 2: Center section for microphone button
                    ZStack {
                        // Glowing blue ring for Look Back mode
                        if viewModel.isLookBackEnabled {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 140, height: 140)
                                .scaleEffect(lookBackPulseScale)
                                .opacity(lookBackPulseOpacity)
                                .animation(
                                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                    value: lookBackPulseScale
                                )
                                .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 0)
                        }
                        
                        // Main button
                        ListenButton(recordingState: viewModel.recordingState) {
                            handleButtonTap()
                        }
                    }
                    
                    Spacer()
                    
                    // SECTION 3: Bottom section for subtitle and status text
                    VStack(spacing: 16) {
                        // Look Back subtitle (only in Look Back mode)
                        if viewModel.isLookBackEnabled {
                            Text("Capture Last 60s")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Status text (always show, but content varies by mode)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    
                    // Navigation to history
                    NavigationLink(destination: HistoryView(
                        recordingSessions: viewModel.factCheckHistory,
                        onClearHistory: {
                            viewModel.clearHistory()
                        }
                    )) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View History")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.factCheckHistory.isEmpty)
                    .opacity(viewModel.factCheckHistory.isEmpty ? 0.5 : 1.0)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingResults, onDismiss: {
            viewModel.latestSession = nil
        }) {
            if let session = viewModel.latestSession {
                ResultsView(session: session)
            }
        }
        .onChange(of: viewModel.latestSession) { _, newSession in
            if newSession != nil {
                showingResults = true
            }
        }
    }
    
    private var statusText: String {
        switch viewModel.recordingState {
        case .idle:
            return viewModel.isLookBackEnabled ? "Tap to process last 60 seconds" : "Tap to listen and fact-check"
        case .recording:
            return "Listening... Tap again to stop"
        case .processing:
            return "Verifying facts..."
        case .completed:
            return "Fact-check complete! Results will appear shortly."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var lookBackPulseScale: CGFloat {
        viewModel.isLookBackEnabled ? 1.05 : 1.0
    }
    
    private var lookBackPulseOpacity: Double {
        viewModel.isLookBackEnabled ? 0.8 : 1.0
    }
    
    private func handleButtonTap() {
        switch viewModel.recordingState {
        case .idle, .completed:
            viewModel.startRecording()
        case .recording:
            viewModel.stopRecording()
        case .processing, .error:
            break // Do nothing in these states
        }
    }
}

#Preview {
    MainView()
}
