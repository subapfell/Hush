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
    @Binding var isAutoScrollEnabled: Bool
    
    /// Callback to notify parent of height changes
    let onHeightChange: ((CGFloat) -> Void)?
    
    /// Previous transcript length to detect new content
    @State private var previousTranscriptLength: Int = 0
    
    /// ScrollViewReader proxy for programmatic scrolling
    @State private var scrollProxy: ScrollViewProxy?
    
    /// Dynamic height based on content
    @State private var contentHeight: CGFloat = Constants.UI.transcriptViewHeight
    
    /// Updates the content height based on text content
    private func updateContentHeight() {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let attributedString = NSAttributedString(string: transcript, attributes: attributes)
        
        // Calculate the width available for text (accounting for padding)
        let availableWidth = 400.0 - 32.0 // Assuming reasonable width minus horizontal padding
        
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        // Add padding (top + bottom) and some extra space for the hint text
        let calculatedHeight = boundingRect.height + 24 + 40 // 12 top + 12 bottom padding + hint text area
        
        // Use minimum height or calculated height, whichever is larger
        let newHeight = max(Constants.UI.transcriptViewHeight, calculatedHeight)
        contentHeight = newHeight
        
        // Notify parent of height change
        onHeightChange?(min(newHeight, 300))
    }
    
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
                                // Calculate initial content height
                                updateContentHeight()
                            }
                            .onChange(of: transcript) {
                                // Update content height when transcript changes
                                updateContentHeight()
                                
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
                                Text("Scroll to top: ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("⇧↑")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                
                                Text(" • Scroll to bottom: ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("⇧↓")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(height: min(contentHeight, 300))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcript")
        .accessibilityValue(transcript.isEmpty ? "No transcript available" : transcript)
        .accessibilityHint(isRecording ? "Currently recording audio" : "Recording paused")
        .onReceive(NotificationCenter.default.publisher(for: .scrollTranscriptToTop)) { _ in
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("transcriptText", anchor: .top)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollTranscriptToBottom)) { _ in
            if let proxy = scrollProxy {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("transcriptText", anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    @State var isAutoScrollEnabled = true
    
    return TranscriptView(
        transcript: "This is a sample transcript of what the speech recognition might capture. It demonstrates how the text would appear in the transcript view. This is a longer text to show the scrolling behavior when there's more content than can fit in the view. Users can now scroll up and down manually, and control whether new content automatically scrolls to the bottom.",
        isRecording: true,
        hasScreenshots: true,
        isAutoScrollEnabled: $isAutoScrollEnabled,
        onHeightChange: nil
    )
}