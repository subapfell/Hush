import SwiftUI

/// A view that displays live audio transcription
struct TranscriptView: View {
    /// The transcription text to display
    let transcript: String
    
    /// Whether recording is currently active
    let isRecording: Bool
    
    /// Whether screenshots are available
    let hasScreenshots: Bool
    
    /// Whether auto-scroll is enabled
    @State private var isAutoScrollEnabled: Bool = true
    
    /// Previous transcript length to detect new content
    @State private var previousTranscriptLength: Int = 0
    
    /// ScrollViewReader proxy for programmatic scrolling
    @State private var scrollProxy: ScrollViewReader.ScrollViewProxy?
    
    var body: some View {
        ZStack {
            // Glass background for transcript
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            
            // Transcript content
            if transcript.isEmpty {
                Text(isRecording ? "Listening..." : "No transcript available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ZStack {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(transcript)
                                    .font(.body)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .id("transcriptText")
                            }
                            .onAppear {
                                // Store the scroll proxy for keyboard shortcuts
                                scrollProxy = proxy
                            }
                            .onChange(of: transcript) {
                                // Only auto-scroll if enabled and new content was added
                                let newLength = transcript.count
                                if isAutoScrollEnabled && newLength > previousTranscriptLength {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("transcriptText", anchor: .bottom)
                                    }
                                }
                                previousTranscriptLength = newLength
                            }
                            .onChange(of: isAutoScrollEnabled) {
                                // Scroll to bottom when auto-scroll is re-enabled
                                if isAutoScrollEnabled {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("transcriptText", anchor: .bottom)
                                    }
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { _ in
                                        // Disable auto-scroll when user manually scrolls
                                        isAutoScrollEnabled = false
                                    }
                            )
                        }
                        
                        // Auto-scroll control button (bottom right)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    isAutoScrollEnabled.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isAutoScrollEnabled ? "arrow.down.doc.fill" : "arrow.down.doc")
                                            .font(.system(size: 10))
                                        
                                        Text(isAutoScrollEnabled ? "AUTO" : "MANUAL")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                                    .foregroundColor(isAutoScrollEnabled ? .blue : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Toggle auto-scroll (⌘Space)")
                                .padding(.trailing, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    // Hint text for non-empty transcripts
                    if !transcript.isEmpty && !isRecording {
                        VStack(spacing: 2) {
                            HStack(spacing: 0) {
                                Text("Press ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("⌘↩")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                
                                Text(" to process transcript")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    
                                if hasScreenshots {
                                    Text(" with screenshots")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Keyboard shortcuts hint
                            VStack(spacing: 1) {
                                HStack(spacing: 0) {
                                    Text("Scroll: ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("⌘↑/↓")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                    
                                    Text(" • Toggle: ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("⌘Space")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                }
                                
                                HStack(spacing: 0) {
                                    Text("With Shift: ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("⌘⇧↑/↓")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                    
                                    Text(" • Toggle: ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("⌘⇧Space")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(height: Constants.UI.transcriptViewHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcript")
        .accessibilityValue(transcript.isEmpty ? "No transcript available" : transcript)
        .accessibilityHint(isRecording ? "Currently recording audio" : "Recording paused")
        .onKeyPress(.space, modifiers: .command) {
            // Command+Space: Toggle auto-scroll
            isAutoScrollEnabled.toggle()
            return .handled
        }
        .onKeyPress(.space, modifiers: [.command, .shift]) {
            // Command+Shift+Space: Toggle auto-scroll mode (AUTO ↔ MANUAL)
            isAutoScrollEnabled.toggle()
            return .handled
        }
        .onKeyPress(.upArrow, modifiers: .command) {
            // Command+Up: Scroll to top
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.5)) {
                    proxy.scrollTo("transcriptText", anchor: .top)
                }
                isAutoScrollEnabled = false
            }
            return .handled
        }
        .onKeyPress(.upArrow, modifiers: [.command, .shift]) {
            // Command+Shift+Up: Scroll to top of transcript
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.5)) {
                    proxy.scrollTo("transcriptText", anchor: .top)
                }
            }
            return .handled
        }
        .onKeyPress(.downArrow, modifiers: .command) {
            // Command+Down: Scroll to bottom
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.5)) {
                    proxy.scrollTo("transcriptText", anchor: .bottom)
                }
                isAutoScrollEnabled = true
            }
            return .handled
        }
        .onKeyPress(.downArrow, modifiers: [.command, .shift]) {
            // Command+Shift+Down: Scroll to bottom and enable auto-scroll
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.5)) {
                    proxy.scrollTo("transcriptText", anchor: .bottom)
                }
                isAutoScrollEnabled = true
            }
            return .handled
        }
        .onKeyPress(.pageUp) {
            // Page Up: Scroll up by page
            scrollByPage(direction: .up)
            return .handled
        }
        .onKeyPress(.pageDown) {
            // Page Down: Scroll down by page
            scrollByPage(direction: .down)
            return .handled
        }
        .onKeyPress(.upArrow) {
            // Up Arrow: Scroll up by line
            scrollByLine(direction: .up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            // Down Arrow: Scroll down by line
            scrollByLine(direction: .down)
            return .handled
        }

    }
    
    // MARK: - Helper Methods
    
    /// Scroll direction for helper methods
    private enum ScrollDirection {
        case up, down
    }
    
    /// Scroll by page (approximate)
    /// - Parameter direction: Direction to scroll
    private func scrollByPage(direction: ScrollDirection) {
        // Disable auto-scroll when manually scrolling
        isAutoScrollEnabled = false
        
        // For page scrolling, we'll use a simple approach since SwiftUI ScrollView
        // doesn't provide direct access to scroll position
        // This is a simplified implementation - in a real app you might want
        // to use UIScrollView or NSScrollView for more precise control
        
        // For now, we'll just scroll to top/bottom as page equivalents
        guard let proxy = scrollProxy else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            switch direction {
            case .up:
                proxy.scrollTo("transcriptText", anchor: .top)
            case .down:
                proxy.scrollTo("transcriptText", anchor: .bottom)
            }
        }
    }
    
    /// Scroll by line (approximate)
    /// - Parameter direction: Direction to scroll
    private func scrollByLine(direction: ScrollDirection) {
        // Disable auto-scroll when manually scrolling
        isAutoScrollEnabled = false
        
        // Similar limitation as page scrolling - SwiftUI doesn't provide
        // fine-grained scroll control. This is a simplified implementation.
        // In a production app, you might want to implement custom scrolling
        // or use platform-specific scroll views for precise control.
        
        // For now, we'll provide a subtle scroll animation
        guard let proxy = scrollProxy else { return }
        
        withAnimation(.easeOut(duration: 0.1)) {
            switch direction {
            case .up:
                // Scroll towards top (but not all the way)
                proxy.scrollTo("transcriptText", anchor: .center)
            case .down:
                // Scroll towards bottom
                proxy.scrollTo("transcriptText", anchor: .bottom)
            }
        }
    }
    

}

#Preview {
    TranscriptView(
        transcript: "This is a sample transcript of what the speech recognition might capture. It demonstrates how the text would appear in the transcript view. This is a longer text to show the scrolling behavior when there's more content than can fit in the view. Users can now scroll up and down manually, and control whether new content automatically scrolls to the bottom.",
        isRecording: true,
        hasScreenshots: true
    )
} 
 