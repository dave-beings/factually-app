import Foundation
import Combine
import AVFoundation
import Speech
import UserNotifications

/// Circular audio buffer for Look Back feature
class CircularAudioBuffer {
    private let maxDuration: TimeInterval = Constants.lookBackMaxDuration
    private var audioFiles: [(url: URL, timestamp: Date)] = []
    private var currentFileIndex: Int = 0
    private let chunkDuration: TimeInterval = Constants.lookBackChunkDuration
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    init() {
        // Clean up any existing buffer files
        cleanupBufferFiles()
    }
    
    deinit {
        cleanupBufferFiles()
    }
    
    func getNextFileURL() -> URL {
        let timestamp = Date()
        let filename = "lookback_chunk_\(currentFileIndex)_\(timestamp.timeIntervalSince1970).m4a"
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        // Add the new file to the buffer
        audioFiles.append((url: fileURL, timestamp: timestamp))
        currentFileIndex = (currentFileIndex + 1) % Constants.maxFileIndex // Large number to avoid collisions
        
        return fileURL
    }
    
    func enforceChunkLimit() {
        // Sort array by timestamp to ensure chronological order
        audioFiles.sort { $0.timestamp < $1.timestamp }
        
        // If we have more than the maximum chunks, remove the oldest
        while audioFiles.count > Constants.lookBackMaxChunks {
            let oldestFile = audioFiles.removeFirst()
            
            // Delete the file from disk
            do {
                try FileManager.default.removeItem(at: oldestFile.url)
                print("🗑️ Removed old chunk: \(oldestFile.url.lastPathComponent)")
            } catch {
                print("⚠️ Failed to delete old chunk \(oldestFile.url.lastPathComponent): \(error)")
            }
        }
        
        print("📊 Buffer now contains \(audioFiles.count) chunks")
    }
    
    
    func combineBufferToFile() async -> URL? {
        guard !audioFiles.isEmpty else { 
            print("❌ No audio files in buffer")
            return nil 
        }
        
        // Ensure the most recent chunk is properly finalized before combining
        print("⏸️ Finalizing most recent chunk before combination...")
        try? await Task.sleep(for: .milliseconds(Constants.bufferFinalizationDelay))
        
        // Sort files by timestamp to ensure proper chronological order
        let sortedFiles = audioFiles.sorted { $0.timestamp < $1.timestamp }
        
        print("🔄 Combining \(sortedFiles.count) audio chunks in chronological order...")
        
        let finalURL = documentsPath.appendingPathComponent("lookback_combined_\(Date().timeIntervalSince1970).m4a")
        
        do {
            return try await combineAudioFiles(sortedFiles.map { $0.url }, outputURL: finalURL)
        } catch {
            print("❌ Failed to combine audio files: \(error)")
            return nil
        }
    }
    
    private func combineAudioFiles(_ inputURLs: [URL], outputURL: URL) async throws -> URL {
        // Create a mutable composition
        let composition = AVMutableComposition()
        
        // Create an audio track in the composition
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioCompositionError.failedToCreateTrack
        }
        
        var currentTime = CMTime.zero
        
        // Add each audio file to the composition
        for inputURL in inputURLs {
            // Check if file exists and is readable
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                print("⚠️ Skipping missing file: \(inputURL.lastPathComponent)")
                continue
            }
            
            // Use AVURLAsset for modern API compatibility
            let asset = AVURLAsset(url: inputURL)
            
            do {
                // Wait for asset to load using modern async API
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    print("⚠️ Skipping unplayable file: \(inputURL.lastPathComponent)")
                    continue
                }
                
                // Get the audio track from the asset
                let assetTracks = try await asset.loadTracks(withMediaType: .audio)
                guard let assetTrack = assetTracks.first else {
                    print("⚠️ Skipping file with no audio track: \(inputURL.lastPathComponent)")
                    continue
                }
                
                // Get the duration of the asset
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                
                // Insert the audio track into the composition
                try audioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration)
                
                print("✅ Added chunk: \(inputURL.lastPathComponent) (duration: \(CMTimeGetSeconds(duration))s)")
                
            } catch {
                print("⚠️ Error processing file \(inputURL.lastPathComponent): \(error)")
                continue
            }
        }
        
        // Check if we have any audio content
        guard CMTimeGetSeconds(currentTime) > 0 else {
            throw AudioCompositionError.noAudioContent
        }
        
        // Create export session with the composition
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioCompositionError.failedToCreateExportSession
        }
        
        // Configure the export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Use modern async throws export method
        try await exportSession.export(to: outputURL, as: .m4a)
        
        print("✅ Successfully combined audio files to: \(outputURL.lastPathComponent)")
        print("📊 Final duration: \(String(format: "%.1f", CMTimeGetSeconds(currentTime)))s")
        return outputURL
    }
    
    private func cleanupBufferFiles() {
        for fileInfo in audioFiles {
            try? FileManager.default.removeItem(at: fileInfo.url)
        }
        audioFiles.removeAll()
    }
}

/// Errors that can occur during audio composition
enum AudioCompositionError: LocalizedError {
    case failedToCreateTrack
    case failedToCreateExportSession
    case noAudioContent
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateTrack:
            return "Failed to create audio track in composition"
        case .failedToCreateExportSession:
            return "Failed to create export session"
        case .noAudioContent:
            return "No valid audio content found in buffer"
        }
    }
}

/// Main view model for the app's core functionality
@MainActor
class MainViewModel: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecording: AudioRecording?
    @Published var factCheckHistory: [RecordingSession] = []
    @Published var latestSession: RecordingSession?
    @Published var isProcessing: Bool = false
    @Published var transcribedText: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var testTranscriptionResult: String = ""
    @Published var isTestRecording: Bool = false
    @Published var isLookBackEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastRecordingURL: URL?
    private var audioLevelTimer: Timer?
    
    // Look Back feature properties
    private var lookBackRecorder: AVAudioRecorder?
    private var lookBackBuffer: CircularAudioBuffer?
    private var lookBackTimer: Timer?
    private var lookBackStartTime: Date?
    
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
        // Listen for unified start recording notification
        NotificationCenter.default.addObserver(
            forName: Constants.startRecordingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleStartRecordingTrigger()
            }
        }
    }
    
    private func handleStartRecordingTrigger() {
        print("🎯 Start recording triggered - starting recording")
        
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
        
        // If Look Back mode is enabled, process the buffer instead of starting new recording
        if isLookBackEnabled {
            processLookBackBuffer()
            return
        }
        
        // Always setup audio session for recording, handling Siri conflicts
        do {
            // First, deactivate any existing audio session to handle Siri conflicts
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configure for recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            print("✅ Audio session configured successfully (handled Siri conflicts)")
        } catch {
            print("❌ Failed to set up audio session: \(error)")
            recordingState = .error("Audio setup failed: \(error.localizedDescription)")
            cleanupRecording() // Ensure clean state on error
            return
        }
        
        // Check microphone permission
        guard AVAudioApplication.shared.recordPermission == .granted else {
            print("❌ Microphone permission not granted")
            recordingState = .error("Microphone permission required")
            cleanupRecording() // Ensure clean state on error
            return
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        lastRecordingURL = audioFilename
        
        // Configure recording settings
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Constants.audioSampleRate,
            AVNumberOfChannelsKey: Constants.audioChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create and start the audio recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            
            let recordingStarted = audioRecorder?.record() ?? false
            
            // Verify recording actually started
            guard recordingStarted, audioRecorder?.isRecording == true else {
                print("❌ Recording failed to start - recorder not active")
                recordingState = .error("Recording failed to start")
                audioRecorder = nil
                return
            }
            
            recordingStartTime = Date()
            recordingState = .recording
            
            // Start audio level monitoring
            startAudioLevelMonitoring()
            
            print("✅ Recording started successfully and verified")
            print("📁 Recording to: \(audioFilename.lastPathComponent)")
            
        } catch {
            print("❌ Failed to create recorder: \(error)")
            recordingState = .error("Recording failed to start: \(error.localizedDescription)")
            audioRecorder = nil
        }
    }
    
    func stopRecording(isTest: Bool = false) {
        print("⏹️ Stopping audio recording... (isTest: \(isTest))")
        
        guard let recorder = audioRecorder else {
            print("❌ No audio recorder available")
            recordingState = .idle
            return
        }
        
        // Verify recorder is actually recording
        guard recorder.isRecording else {
            print("❌ Recorder is not currently recording")
            // Clean up and reset state
            cleanupRecording()
            recordingState = .idle
            return
        }
        
        // Stop recording and calculate duration
        recorder.stop()
        print("✅ Audio recorder stopped successfully")
        
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
        
        // Clean up recording resources and audio session
        cleanupRecording()
    }
    
    // MARK: - Recording Cleanup
    
    private func cleanupRecording() {
        // Clean up recorder
        audioRecorder?.stop()
        audioRecorder = nil
        recordingStartTime = nil
        
        // Only deactivate audio session if Look Back mode is not active
        // This prevents interrupting the continuous background recording
        if !isLookBackEnabled || lookBackRecorder == nil {
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("✅ Audio session deactivated successfully")
            } catch {
                print("⚠️ Failed to deactivate audio session: \(error)")
            }
        } else {
            print("ℹ️ Keeping audio session active for Look Back mode")
        }
    }
    
    // MARK: - Look Back Functions
    
    func startLookBack() {
        print("🔄 Starting Look Back continuous recording...")
        
        // Configure audio session for background recording
        do {
            // Configure for background audio recording with proper options
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]
            )
            
            // Activate the session - this is critical for background operation
            try audioSession.setActive(true, options: [])
            print("✅ Audio session configured for Look Back with background support")
        } catch {
            print("❌ Failed to set up audio session for Look Back: \(error)")
            return
        }
        
        // Check microphone permission
        guard AVAudioApplication.shared.recordPermission == .granted else {
            print("❌ Microphone permission not granted for Look Back")
            return
        }
        
        // Initialize the circular buffer
        lookBackBuffer = CircularAudioBuffer()
        lookBackStartTime = Date()
        
        // Start the first recording chunk
        Task {
            await startNextLookBackChunk()
        }
        
        // Set up timer to switch to new chunks
        lookBackTimer = Timer.scheduledTimer(withTimeInterval: Constants.lookBackChunkDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.startNextLookBackChunk()
            }
        }
        
        print("✅ Look Back recording started successfully")
    }
    
    func stopLookBack() {
        print("⏹️ Stopping Look Back continuous recording...")
        
        // Stop the timer first to prevent new chunks
        lookBackTimer?.invalidate()
        lookBackTimer = nil
        
        // Stop the current recording with proper finalization
        if let recorder = lookBackRecorder, recorder.isRecording {
            recorder.stop()
            
            // Add a small delay to ensure the final chunk is properly written
            Task {
                try? await Task.sleep(for: .milliseconds(Constants.audioFinalizationDelay))
                await MainActor.run {
                    print("✅ Final Look Back chunk finalized")
                }
            }
        }
        
        lookBackRecorder = nil
        
        // Clean up
        lookBackStartTime = nil
        lookBackBuffer = nil
        
        // Deactivate audio session only if we're not actively recording
        if recordingState == .idle {
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("✅ Audio session deactivated after Look Back stop")
            } catch {
                print("⚠️ Failed to deactivate audio session after Look Back stop: \(error)")
            }
        }
        
        print("✅ Look Back recording stopped")
    }
    
    private func startNextLookBackChunk() async {
        // Stop the current recorder if it exists
        if let recorder = lookBackRecorder, recorder.isRecording {
            print("⏹️ Stopping previous Look Back chunk...")
            recorder.stop()
            
            // Wait for the file to be properly finalized before proceeding
            // This prevents "unplayable" errors when accessing the chunk files
            try? await Task.sleep(for: .milliseconds(Constants.audioFinalizationDelay))
            print("✅ Previous chunk finalized")
        }
        
        guard let buffer = lookBackBuffer else { return }
        
        let chunkURL = buffer.getNextFileURL()
        
        // Configure recording settings
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Constants.audioSampleRate,
            AVNumberOfChannelsKey: Constants.audioChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create and start the new chunk recorder
            lookBackRecorder = try AVAudioRecorder(url: chunkURL, settings: settings)
            lookBackRecorder?.isMeteringEnabled = false // Don't need metering for background recording
            lookBackRecorder?.record()
            
            print("📁 Recording Look Back chunk: \(chunkURL.lastPathComponent)")
            
            // After successfully starting the new chunk, enforce the 12-chunk limit
            buffer.enforceChunkLimit()
            
        } catch {
            print("❌ Failed to start Look Back chunk recording: \(error)")
        }
    }
    
    private func processLookBackBuffer() {
        print("🔄 Processing Look Back buffer...")
        
        guard let buffer = lookBackBuffer else {
            print("❌ No Look Back buffer available")
            recordingState = .error("No Look Back buffer available")
            return
        }
        
        // Update UI state immediately
        recordingState = .processing
        isProcessing = true
        
        // Process the buffer asynchronously
        Task {
            // Combine the buffer into a single file using AVMutableComposition
            guard let combinedAudioURL = await buffer.combineBufferToFile() else {
                await MainActor.run {
                    print("❌ Failed to combine Look Back buffer")
                    recordingState = .error("Failed to process Look Back audio")
                    isProcessing = false
                }
                return
            }
            
            await MainActor.run {
                // Set this as the last recording URL for transcription
                lastRecordingURL = combinedAudioURL
                
                // Calculate duration (approximately max duration or less if buffer isn't full)
                let duration = lookBackStartTime != nil ? Date().timeIntervalSince(lookBackStartTime!) : Constants.lookBackMaxDuration
                print("⏱️ Look Back buffer duration: \(String(format: "%.1f", duration)) seconds")
                
                // Create AudioRecording object
                currentRecording = AudioRecording(duration: duration, transcription: nil)
                
                print("🔄 Starting transcription of combined Look Back recording...")
            }
            
            // Transcribe the combined audio file
            await transcribeAudio(from: combinedAudioURL, isTest: false)
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: Constants.audioLevelUpdateInterval, repeats: true) { [weak self] _ in
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
        // averagePower ranges from silence to 0 (max volume)
        let normalizedLevel = max(0.0, (averagePower + Constants.audioLevelDecibelRange) / Constants.audioLevelDecibelRange)
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
                    // For regular mode: show user-friendly error message and reset to idle
                    let userFriendlyMessage = getUserFriendlyErrorMessage(for: error)
                    recordingState = .error(userFriendlyMessage)
                    isProcessing = false
                    
                    // Reset to idle after a brief delay so user can see the error message
                    Task {
                        try? await Task.sleep(for: .seconds(Constants.errorDisplayDuration))
                        await MainActor.run {
                            if case .error = recordingState {
                                recordingState = .idle
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getUserFriendlyErrorMessage(for error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("no speech") || errorDescription.contains("speech not detected") {
            return "No speech detected. Please try speaking more clearly."
        } else if errorDescription.contains("network") || errorDescription.contains("internet") {
            return "Network error. Please check your connection and try again."
        } else if errorDescription.contains("authorization") || errorDescription.contains("permission") {
            return "Microphone permission required. Please enable in Settings."
        } else if errorDescription.contains("audio") || errorDescription.contains("recording") {
            return "Audio recording issue. Please try again."
        } else {
            return "Transcription failed. Please try again."
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
                self.latestSession = recordingSession
                self.isProcessing = false
                self.recordingState = .completed
                
                // Show notification for the fact-check result
                self.showFactCheckNotification(for: recordingSession)
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
                self.latestSession = fallbackSession
                self.isProcessing = false
                self.recordingState = .completed
                
                // Show notification for the fallback fact-check result
                self.showFactCheckNotification(for: fallbackSession)
            }
        }
    }
    
    // MARK: - History Management
    
    func clearHistory() {
        factCheckHistory.removeAll()
    }
    
    // MARK: - Notification Functions
    
    func showFactCheckNotification(for session: RecordingSession) {
        // Check if notifications are authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("❌ Notifications not authorized")
                return
            }
            
            // Find the most relevant fact-check from the session
            let relevantFactCheck = self.getMostRelevantFactCheck(from: session)
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = relevantFactCheck.verdict.rawValue
            content.body = relevantFactCheck.explanation
            content.sound = .default
            
            // Create immediate trigger (deliver now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Constants.notificationTriggerDelay, repeats: false)
            
            // Create notification request
            let request = UNNotificationRequest(
                identifier: "factcheck_\(session.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            // Schedule the notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("✅ Fact-check notification scheduled: \(relevantFactCheck.verdict.rawValue)")
                }
            }
        }
    }
    
    private func getMostRelevantFactCheck(from session: RecordingSession) -> FactCheck {
        // Priority order for selecting the most relevant fact-check:
        // 1. Incorrect (highest priority - user needs to know)
        // 2. Partially Correct (important correction)
        // 3. Correction (factual correction)
        // 4. Correct (confirmation)
        // 5. Unclear (lowest priority)
        
        let priorityOrder: [FactCheckVerdict] = [.incorrect, .partiallyCorrect, .correction, .correct, .unclear]
        
        for verdict in priorityOrder {
            if let factCheck = session.factChecks.first(where: { $0.verdict == verdict }) {
                return factCheck
            }
        }
        
        // Fallback to the first fact-check if no priority match
        return session.factChecks.first ?? FactCheck(
            originalClaim: "No claims found",
            verdict: .unclear,
            explanation: "No fact-checks were found in this session."
        )
    }
}
