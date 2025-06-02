import SwiftUI
import AppKit

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
    @State private var scrollProxy: ScrollViewProxy?
    
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
                                .help("Toggle auto-scroll (⌘⌃Space)")
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
                            HStack(spacing: 0) {
                                Text("Auto-scroll: ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("⌘⌃Space")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                
                                Text(" • Scroll: ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("⌘⌃↑/↓")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
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
        .onKeyPress(.space, modifiers: [.command, .control]) {
            // Toggle auto-scroll
            isAutoScrollEnabled.toggle()
            if isAutoScrollEnabled, let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("transcriptText", anchor: .bottom)
                }
            }
            return .handled
        }
        .onKeyPress(.upArrow, modifiers: [.command, .control]) {
            // Scroll to top
            if let proxy = scrollProxy {
                isAutoScrollEnabled = false
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("transcriptText", anchor: .top)
                }
            }
            return .handled
        }
        .onKeyPress(.downArrow, modifiers: [.command, .control]) {
            // Scroll to bottom and enable auto-scroll
            if let proxy = scrollProxy {
                isAutoScrollEnabled = true
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("transcriptText", anchor: .bottom)
                }
            }
            return .handled
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