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
    @Published var audioLevel: Float = 0.0
    @Published var testTranscriptionResult: String = ""
    @Published var isTestRecording: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastRecordingURL: URL?
    private var audioLevelTimer: Timer?
    
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
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            recordingStartTime = Date()
            recordingState = .recording
            
            // Start audio level monitoring
            startAudioLevelMonitoring()
            
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
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Clean up
        audioRecorder = nil
        recordingStartTime = nil
    }
    
    // MARK: - Test Recording Functions
    
    func startTestRecording() async {
        print("🧪 Starting 5-second transcription test...")
        
        // Check microphone permission
        guard AVAudioApplication.shared.recordPermission == .granted else {
            print("❌ Microphone permission not granted")
            recordingState = .error("Microphone permission required")
            return
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("test_recording_\(Date().timeIntervalSince1970).m4a")
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
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            recordingStartTime = Date()
            recordingState = .recording
            isTestRecording = true
            testTranscriptionResult = "Recording for 5 seconds..."
            
            // Start audio level monitoring
            startAudioLevelMonitoring()
            
            print("✅ Test recording started successfully")
            print("📁 Recording to: \(audioFilename.lastPathComponent)")
            print("⏱️ Will auto-stop in 5 seconds")
            
            // Wait for 5 seconds using modern async/await
            try? await Task.sleep(for: .seconds(5))
            
            // Auto-stop after 5 seconds
            stopTestRecording()
            
        } catch {
            print("❌ Failed to start test recording: \(error)")
            recordingState = .error("Test recording failed to start")
            isTestRecording = false
        }
    }
    
    private func stopTestRecording() {
        print("⏹️ Stopping test recording...")
        
        // Note: No timer cleanup needed when using DispatchQueue.main.asyncAfter
        
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("❌ No active test recording to stop")
            isTestRecording = false
            return
        }
        
        // Stop recording and calculate duration
        recorder.stop()
        
        let duration = recordingStartTime != nil ? Date().timeIntervalSince(recordingStartTime!) : 0
        print("⏱️ Test recording duration: \(String(format: "%.1f", duration)) seconds")
        
        // Update UI state
        recordingState = .processing
        isTestRecording = false
        testTranscriptionResult = "Processing transcription..."
        
        print("🔄 Processing test transcription...")
        
        // Transcribe the audio file (without adding to history)
        if let audioURL = lastRecordingURL {
            Task {
                await transcribeTestAudio(from: audioURL)
            }
        } else {
            print("❌ No audio file URL available for test transcription")
            recordingState = .idle
            testTranscriptionResult = "Error: No audio file to transcribe"
        }
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Clean up
        audioRecorder = nil
        recordingStartTime = nil
    }
    
    private func transcribeTestAudio(from url: URL) async {
        print("🎙️ Starting test speech-to-text transcription...")
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            await MainActor.run {
                recordingState = .idle
                testTranscriptionResult = "Error: Speech recognition unavailable"
            }
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ Speech recognition not authorized")
            await MainActor.run {
                recordingState = .idle
                testTranscriptionResult = "Error: Speech recognition not authorized"
            }
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        do {
            let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            
            let transcription = result.bestTranscription.formattedString
            print("✅ Test transcription completed: \"\(transcription)\"")
            
            await MainActor.run {
                testTranscriptionResult = transcription.isEmpty ? "No speech detected" : transcription
                recordingState = .idle
            }
            
        } catch {
            print("❌ Test transcription error: \(error)")
            await MainActor.run {
                testTranscriptionResult = "Transcription error: \(error.localizedDescription)"
                recordingState = .idle
            }
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert decibel value to a 0-1 range
        // averagePower ranges from -160 (silence) to 0 (max volume)
        let normalizedLevel = max(0.0, (averagePower + 60.0) / 60.0)
        audioLevel = Float(normalizedLevel)
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
            let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            
            let transcription = result.bestTranscription.formattedString
            print("✅ Transcription completed: \"\(transcription)\"")
            
            await MainActor.run {
                transcribedText = transcription
            }
            
            // Process the fact-check with the real transcription
            await processFactCheck(transcription: transcription)
            
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
        print("🧠 Starting AI fact-checking for: \"\(transcription)\"")
        
        do {
            // Call Gemini API for fact-checking
            let factCheckResponse = try await GeminiService.shared.factCheck(transcription)
            
            print("✅ AI fact-check completed")
            print("📝 Verdict: \(factCheckResponse.verdict.rawValue)")
            print("💡 Explanation: \(factCheckResponse.explanation)")
            
            // Create fact check result with AI response
            let factCheck = FactCheck(
                originalClaim: transcription,
                verdict: factCheckResponse.verdict,
                explanation: factCheckResponse.explanation,
                sources: [] // TODO: Could be enhanced to include sources from AI
            )
            
            await MainActor.run {
                self.factCheckHistory.insert(factCheck, at: 0)
                self.isProcessing = false
                self.recordingState = .completed
            }
            
        } catch {
            print("❌ AI fact-checking failed: \(error)")
            
            // Fallback to placeholder if AI fails
            let fallbackFactCheck = FactCheck(
                originalClaim: transcription,
                verdict: .unclear,
                explanation: "Unable to verify this claim at the moment. Please check your internet connection and API key configuration. Error: \(error.localizedDescription)",
                sources: []
            )
            
            await MainActor.run {
                self.factCheckHistory.insert(fallbackFactCheck, at: 0)
                self.isProcessing = false
                self.recordingState = .completed
            }
        }
    }
    
    // MARK: - History Management
    
    func clearHistory() {
        factCheckHistory.removeAll()
    }
}
