import Foundation
import Combine
import AVFoundation
import Speech

/// Main view model for the app's core functionality
@MainActor
class MainViewModel: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecording: AudioRecording?
    @Published var factCheckHistory: [FactCheck] = []
    @Published var isProcessing: Bool = false
    @Published var transcribedText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastRecordingURL: URL?
    
    init() {
        setupAudioSession()
        setupSpeechRecognizer()
        requestMicrophonePermission()
        requestSpeechRecognitionPermission()
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
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard speechRecognizer != nil else {
            print("❌ Speech recognition not available for this locale")
            return
        }
        print("✅ Speech recognizer initialized")
    }
    
    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    print("✅ Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                    self?.recordingState = .error("Microphone permission denied")
                }
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition permission granted")
                case .denied:
                    print("❌ Speech recognition permission denied")
                    self?.recordingState = .error("Speech recognition denied")
                case .restricted, .notDetermined:
                    print("⚠️ Speech recognition permission restricted or not determined")
                @unknown default:
                    print("❓ Unknown speech recognition authorization status")
                }
            }
        }
    }
    
    // MARK: - Recording Functions
    
    func startRecording() {
        print("🎤 Starting audio recording...")
        
        // Check microphone permission
        guard AVAudioApplication.shared.recordPermission == .granted else {
            print("❌ Microphone permission not granted")
            recordingState = .error("Microphone permission required")
            return
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        lastRecordingURL = audioFilename
        
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
        
        // Transcribe the audio file
        if let audioURL = lastRecordingURL {
            Task {
                await transcribeAudio(from: audioURL)
            }
        } else {
            print("❌ No audio file URL available for transcription")
            recordingState = .error("No audio file to transcribe")
        }
        
        // Clean up
        audioRecorder = nil
        recordingStartTime = nil
    }
    
    // MARK: - Speech Recognition Functions
    
    private func transcribeAudio(from url: URL) async {
        print("🎙️ Starting speech-to-text transcription...")
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            await MainActor.run {
                recordingState = .error("Speech recognition unavailable")
                isProcessing = false
            }
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ Speech recognition not authorized")
            await MainActor.run {
                recordingState = .error("Speech recognition not authorized")
                isProcessing = false
            }
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        do {
            let (result, error) = try await withCheckedThrowingContinuation { continuation in
                speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        continuation.resume(returning: (result, nil))
                    }
                }
            }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                print("✅ Transcription completed: \"\(transcription)\"")
                
                await MainActor.run {
                    transcribedText = transcription
                }
                
                // Process the fact-check with the real transcription
                await processFactCheck(transcription: transcription)
                
            } else {
                print("❌ No transcription result")
                await MainActor.run {
                    transcribedText = "Could not transcribe audio"
                    recordingState = .error("Transcription failed")
                    isProcessing = false
                }
            }
            
        } catch {
            print("❌ Transcription error: \(error)")
            await MainActor.run {
                transcribedText = "Transcription error: \(error.localizedDescription)"
                recordingState = .error("Transcription failed")
                isProcessing = false
            }
        }
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
