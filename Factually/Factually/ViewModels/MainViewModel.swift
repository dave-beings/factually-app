import Foundation
import Combine
import AVFoundation

/// Main view model for the app's core functionality
@MainActor
class MainViewModel: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecording: AudioRecording?
    @Published var factCheckHistory: [FactCheck] = []
    @Published var isProcessing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    
    init() {
        setupAudioSession()
        requestMicrophonePermission()
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Failed to set up audio session: \(error)")
            recordingState = .error("Audio setup failed")
        }
    }
    
    private func requestMicrophonePermission() {
        audioSession.requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                    self?.recordingState = .error("Microphone permission denied")
                }
            }
        }
    }
    
    // MARK: - Recording Functions
    
    func startRecording() {
        print("🎤 Starting audio recording...")
        
        // Check microphone permission
        guard audioSession.recordPermission == .granted else {
            print("❌ Microphone permission not granted")
            recordingState = .error("Microphone permission required")
            return
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        // Configure recording settings
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create and start the audio recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            recordingStartTime = Date()
            recordingState = .recording
            
            print("✅ Recording started successfully")
            print("📁 Recording to: \(audioFilename.lastPathComponent)")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            recordingState = .error("Recording failed to start")
        }
    }
    
    func stopRecording() {
        print("⏹️ Stopping audio recording...")
        
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("❌ No active recording to stop")
            return
        }
        
        // Stop recording and calculate duration
        recorder.stop()
        
        let duration = recordingStartTime != nil ? Date().timeIntervalSince(recordingStartTime!) : 0
        print("⏱️ Recording duration: \(String(format: "%.1f", duration)) seconds")
        
        // Create AudioRecording object
        currentRecording = AudioRecording(duration: duration, transcription: nil)
        
        // Update UI state
        recordingState = .processing
        isProcessing = true
        
        print("🔄 Processing recording...")
        
        // TODO: This will eventually:
        // 1. Send audio file to speech-to-text service
        // 2. Send transcription to AI for fact-checking
        // 3. Update the UI with results
        
        // For now, simulate processing with placeholder text
        Task {
            await processFactCheck(transcription: "Sample transcribed text from \(String(format: "%.1f", duration)) second recording")
        }
        
        // Clean up
        audioRecorder = nil
        recordingStartTime = nil
    }
    
    // MARK: - Fact Checking Functions
    
    func processFactCheck(transcription: String) async {
        // TODO: Implement AI fact-checking logic
        // This is a placeholder for the actual implementation
        
        // Simulate processing delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Create a sample fact check result
        let sampleFactCheck = FactCheck(
            originalClaim: transcription,
            verdict: .correction,
            explanation: "This is a placeholder explanation that will be replaced with actual AI-generated content.",
            sources: ["https://example.com"]
        )
        
        DispatchQueue.main.async {
            self.factCheckHistory.insert(sampleFactCheck, at: 0)
            self.isProcessing = false
            self.recordingState = .completed
        }
    }
    
    // MARK: - History Management
    
    func clearHistory() {
        factCheckHistory.removeAll()
    }
}
