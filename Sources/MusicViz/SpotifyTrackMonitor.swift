import AppKit
import Foundation

/// Watches the installed Spotify desktop app through its local AppleScript interface.
@MainActor
final class SpotifyTrackMonitor {
    var onTrackChanged: (() -> Void)?
    private var previousTrackID: String?
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    private func poll() {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) else {
            previousTrackID = nil
            return
        }
        let script = """
        tell application id "com.spotify.client"
            if player state is playing then return id of current track
            return ""
        end tell
        """
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue,
              !result.isEmpty else { return }
        defer { previousTrackID = result }
        if let previousTrackID, previousTrackID != result { onTrackChanged?() }
    }
}
