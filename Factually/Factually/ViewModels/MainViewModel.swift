import Foundation
import Combine
import AVFoundation
import Speech

/// Main view model for the app's core functionality
@MainActor
class MainViewModel: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecording: AudioRecording?
    @Published var factCheckHistory: [RecordingSession] = []
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
        setupSpeechRecognizer()
        requestMicrophonePermission()
        requestSpeechRecognitionPermission()
        setupShortcutListener()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Setup
    
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
    
    private func setupShortcutListener() {
        NotificationCenter.default.addObserver(
            forName: .startListeningIntentTriggered,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleShortcutTrigger()
            }
        }
        
        // Also listen for URL scheme triggers
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StartRecordingFromURL"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleURLSchemeTrigger()
            }
        }
    }
    
    private func handleShortcutTrigger() {
        print("🎯 Siri Shortcut triggered - starting recording")
        
        // Only start recording if we're not already recording or processing
        guard recordingState == .idle else {
            print("⚠️ Cannot start recording - current state: \(recordingState)")
            return
        }
        
        startRecording()
    }
    
    private func handleURLSchemeTrigger() {
        print("🔗 URL Scheme triggered - starting recording")
        
        // Only start recording if we're not already recording or processing
        guard recordingState == .idle else {
            print("⚠️ Cannot start recording - current state: \(recordingState)")
            return
        }
        
        startRecording()
    }
    
    // MARK: - Recording Functions
    
    func startRecording() {
        print("🎤 Starting audio recording...")
        
        // Setup audio session if not already active
        if !audioSession.isOtherAudioPlaying && audioSession.category != .playAndRecord {
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                print("✅ Audio session configured successfully")
            } catch {
                print("❌ Failed to set up audio session: \(error)")
                recordingState = .error("Audio setup failed")
                return
            }
        }
        
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
    
    func stopRecording(isTest: Bool = false) {
        print("⏹️ Stopping audio recording... (isTest: \(isTest))")
        
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
                await transcribeAudio(from: audioURL, isTest: isTest)
            }
        } else {
            print("❌ No audio file URL available for transcription")
            if isTest {
                testTranscriptionResult = "Error: No audio file to transcribe"
            }
            recordingState = .error("No audio file to transcribe")
        }
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Clean up
        audioRecorder = nil
        recordingStartTime = nil
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
    
    private func transcribeAudio(from url: URL, isTest: Bool = false) async {
        print("🎙️ Starting speech-to-text transcription... (isTest: \(isTest))")
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            await MainActor.run {
                if isTest {
                    testTranscriptionResult = "Error: Speech recognition unavailable"
                    recordingState = .idle
                    isTestRecording = false
                } else {
                    recordingState = .error("Speech recognition unavailable")
                    isProcessing = false
                }
            }
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ Speech recognition not authorized")
            await MainActor.run {
                if isTest {
                    testTranscriptionResult = "Error: Speech recognition not authorized"
                    recordingState = .idle
                    isTestRecording = false
                } else {
                    recordingState = .error("Speech recognition not authorized")
                    isProcessing = false
                }
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
                
                if isTest {
                    // For test mode: update test result and set state to idle
                    testTranscriptionResult = transcription.isEmpty ? "No speech detected" : transcription
                    recordingState = .idle
                    isTestRecording = false
                } else {
                    // For regular mode: continue with fact-checking
                    // (processFactCheck will be called below)
                }
            }
            
            // Process the fact-check with the real transcription (only for regular recording)
            if !isTest {
                await processFactCheck(transcription: transcription)
            }
            
        } catch {
            print("❌ Transcription error: \(error)")
            await MainActor.run {
                transcribedText = "Transcription error: \(error.localizedDescription)"
                
                if isTest {
                    // For test mode: update test result and set state to idle
                    testTranscriptionResult = "Transcription error: \(error.localizedDescription)"
                    recordingState = .idle
                    isTestRecording = false
                } else {
                    // For regular mode: set error state
                    recordingState = .error("Transcription failed")
                    isProcessing = false
                }
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
            print("📊 Found \(factCheckResponse.factChecks.count) fact check(s)")
            
            // Create FactCheck objects for each fact check returned by AI
            var newFactChecks: [FactCheck] = []
            
            for singleFactCheck in factCheckResponse.factChecks {
                print("📝 Claim: \(singleFactCheck.claim)")
                print("📝 Verdict: \(singleFactCheck.verdict.rawValue)")
                print("💡 Explanation: \(singleFactCheck.explanation)")
                
                let factCheck = FactCheck(
                    originalClaim: singleFactCheck.claim,
                    verdict: singleFactCheck.verdict,
                    explanation: singleFactCheck.explanation,
                    sources: [], // TODO: Could be enhanced to include sources from AI
                    sourceURL: singleFactCheck.sourceURL
                )
                
                newFactChecks.append(factCheck)
            }
            
            // If no fact checks were found, create a single entry indicating this
            if newFactChecks.isEmpty {
                print("ℹ️ No factual claims identified in the transcription")
                let noClaimsFactCheck = FactCheck(
                    originalClaim: transcription,
                    verdict: .unclear,
                    explanation: "No specific factual claims were identified in this recording.",
                    sources: [],
                    sourceURL: nil
                )
                newFactChecks.append(noClaimsFactCheck)
            }
            
            await MainActor.run {
                // Create a new recording session with all the fact checks
                let recordingSession = RecordingSession(factChecks: newFactChecks)
                self.factCheckHistory.insert(recordingSession, at: 0)
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
                sources: [],
                sourceURL: nil
            )
            
            await MainActor.run {
                // Create a recording session with the fallback fact check
                let fallbackSession = RecordingSession(factChecks: [fallbackFactCheck])
                self.factCheckHistory.insert(fallbackSession, at: 0)
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
