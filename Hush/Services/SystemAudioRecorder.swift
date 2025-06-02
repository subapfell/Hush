import SwiftUI
import Combine
import AVFoundation
import OSLog

@MainActor
final class SystemAudioRecorder: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether system audio recording is active
    @Published var isRecording: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: SystemAudioRecorder.self))
    private var processController = AudioProcessController()
    private var tap: ProcessTap?
    private var recorder: ProcessTapRecorder?
    private let transcriptionService = TranscriptionService.shared
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "SystemAudioRecorder", qos: .userInitiated)
    
    // MARK: - Shared Instance
    
    static let shared = SystemAudioRecorder()
    
    // MARK: - Initialization
    
    private init() {
        processController.activate()
    }
    
    // MARK: - Public Methods
    
    /// Toggle system audio recording
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// Start recording system audio
    func startRecording() {
        guard !isRecording else { return }
        
        logger.debug("Starting system audio recording")
        
        // Check permissions first
        let permission = AudioRecordingPermission()
        if permission.status == .denied {
            logger.error("Audio recording permission denied")
            let alert = NSAlert()
            alert.messageText = "Audio Recording Permission Required"
            alert.informativeText = "Please grant audio recording permission in System Preferences > Security & Privacy > Privacy > Microphone and Screen Recording."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
            return
        }
        
        do {
            // Find the system audio process
            if let systemProcess = findSystemAudioProcess() {
                try setupDirectTapToTranscription(for: systemProcess)
                isRecording = true
                // Only show transcript viewer if enabled in preferences
                AppState.shared.showTranscript = AppPreferences.shared.showTranscriptionViewer
                logger.info("Successfully started system audio recording for process: \(systemProcess.name)")
            } else {
                logger.error("No system audio process found")
                let alert = NSAlert()
                alert.messageText = "No Audio Processes Found"
                alert.informativeText = "No system audio processes are currently available. Please ensure audio is playing from another application and try again."
                alert.alertStyle = .warning
                alert.runModal()
                throw NSError(domain: "SystemAudioRecorderErrorDomain", code: 1, 
                              userInfo: [NSLocalizedDescriptionKey: "No system audio process found"])
            }
        } catch {
            logger.error("Failed to start system audio recording: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "System Audio Recording Failed"
            alert.informativeText = "Error: \(error.localizedDescription)\n\nThis may be due to insufficient permissions or system restrictions. Please check that the app has the necessary permissions in System Preferences."
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    /// Stop recording system audio
    func stopRecording() {
        guard isRecording else { return }
        
        logger.debug("Stopping system audio recording")
        
        // Stop transcription
        transcriptionService.stopRecording()
        
        // Stop recording
        tap?.invalidate()
        tap = nil
        
        isRecording = false
        
        // Hide transcript view when stopping
        DispatchQueue.main.async {
            AppState.shared.showTranscript = false
        }
    }
    
    // MARK: - Private Methods
    
    private func findSystemAudioProcess() -> AudioProcess? {
        // Log all available processes for debugging
        logger.debug("Available processes:")
        for group in processController.processGroups {
            logger.debug("Group: \(group.title)")
            for process in group.processes {
                logger.debug("  - \(process.name) (audioActive: \(process.audioActive), bundleID: \(process.bundleID ?? "nil"))")
            }
        }
        
        // First try to find system audio processes
        let processes = processController.processGroups.flatMap { $0.processes }
        
        // Try to find a coreaudiod or SystemAudioDevice process
        if let systemProcess = processes.first(where: { $0.name.contains("coreaudiod") || $0.name.contains("SystemAudioDevice") }) {
            logger.debug("Found system audio process: \(systemProcess.name)")
            return systemProcess
        }
        
        // If not found, try to find any active audio process
        if let activeProcess = processes.first(where: { $0.audioActive }) {
            logger.debug("Found active audio process: \(activeProcess.name)")
            return activeProcess
        }
        
        // If still not found, just use the first available process
        if let firstProcess = processController.processGroups.first?.processes.first {
            logger.debug("No ideal audio process found, using first available: \(firstProcess.name)")
            return firstProcess
        }
        
        logger.error("No audio processes found")
        return nil
    }
    
    private func setupDirectTapToTranscription(for process: AudioProcess) throws {
        // Create a new tap for the selected process
        let newTap = ProcessTap(process: process)
        self.tap = newTap
        newTap.activate()
        
        // Get the tap stream description
        guard let streamDescription = newTap.tapStreamDescription else {
            throw NSError(domain: "SystemAudioRecorderErrorDomain", code: 2, 
                          userInfo: [NSLocalizedDescriptionKey: "Could not get audio stream description"])
        }
        
        // Initialize transcription service with the audio format
        try transcriptionService.startSystemAudioTranscription(with: streamDescription)
        
        // Connect the tap directly to the transcription service
        try newTap.run(on: queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self = self else { return }
            
            // Forward the audio buffer directly to the transcription service
            self.transcriptionService.processAudioBuffer(inInputData, bufferTimeStamp: inInputTime)
            
        } invalidationHandler: { [weak self] tap in
            guard let self = self else { return }
            logger.debug("Tap was invalidated")
            DispatchQueue.main.async {
                self.stopRecording()
            }
        }
    }
} 