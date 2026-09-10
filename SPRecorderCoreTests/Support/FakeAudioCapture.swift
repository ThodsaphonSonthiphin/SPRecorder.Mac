import Foundation
@testable import SPRecorderCore

/// Stands in for ScreenCaptureKit in tests (sprecorder-mac-0015). Writes a placeholder file per
/// track on start, so the session can be checked against a real folder, and can be told to
/// fail, to hold `start` open, or to stop by itself.
@MainActor
final class FakeAudioCapture: AudioCapturing {
    var startError: CaptureError?
    var stopError: CaptureError?
    /// When true, `start` waits until `releaseStart()` is called.
    var holdStart = false

    private(set) var startCalls: [(systemTrack: URL, micTrack: URL)] = []
    private(set) var stopCalls = 0
    private var onInterrupted: (@Sendable (CaptureError) -> Void)?
    private var heldStart: CheckedContinuation<Void, Never>?

    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws {
        startCalls.append((systemTrack, micTrack))
        if holdStart {
            await withCheckedContinuation { heldStart = $0 }
        }
        if let startError { throw startError }
        FileManager.default.createFile(atPath: systemTrack.path, contents: Data("system".utf8))
        FileManager.default.createFile(atPath: micTrack.path, contents: Data("mic".utf8))
        self.onInterrupted = onInterrupted
    }

    func stop() async throws {
        stopCalls += 1
        if let stopError { throw stopError }
    }

    func releaseStart() {
        heldStart?.resume()
        heldStart = nil
    }

    var isHoldingStart: Bool { heldStart != nil }

    /// Simulates the capture stopping by itself mid-session.
    func interrupt(_ reason: CaptureError) {
        onInterrupted?(reason)
    }
}
