import Foundation
 
/// Extension providing custom notification names for the app
extension Notification.Name {
    /// Notification fired when keyboard shortcuts are changed in settings
    static let shortcutsChanged = Notification.Name("shortcutsChanged")
    
    /// Notification to scroll transcript to top
    static let scrollTranscriptToTop = Notification.Name("scrollTranscriptToTop")
    
    /// Notification to scroll transcript to bottom
    static let scrollTranscriptToBottom = Notification.Name("scrollTranscriptToBottom")
} 