import Foundation

/// Why capture could not start, or stopped. The adapter translates platform errors into these,
/// so the Core can name the problem in plain words without knowing any platform framework.
public enum CaptureError: Error, Equatable, Sendable {
    case microphoneNotAllowed
    case computerAudioNotAllowed
    case failed(String)

    public init(_ error: any Error) {
        self = (error as? CaptureError) ?? .failed(error.localizedDescription)
    }

    public var plainWords: String {
        switch self {
        // A running SPRecorder keeps macOS's first answer, so a switch turned on later needs a reopen (first demo, Step 6).
        case .microphoneNotAllowed: "SPRecorder is not allowed to use the microphone. If you have just allowed it in System Settings, quit and reopen SPRecorder."
        case .computerAudioNotAllowed: "SPRecorder is not allowed to record computer audio."
        case .failed(let detail): detail
        }
    }
}

/// What a Recording Session needs from the platform to record the System track and the
/// Mic track (sprecorder-mac-0002). The app implements it with ScreenCaptureKit (research #3);
/// tests implement it with a fake (sprecorder-mac-0015).
public protocol AudioCapturing: AnyObject, Sendable {
    /// Begins writing computer audio to `systemTrack` and the microphone to `micTrack`.
    /// Throws a `CaptureError` when capture cannot begin. `onInterrupted` is called at most
    /// once if capture stops by itself after starting.
    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws

    /// Stops capture and finishes both files.
    func stop() async throws
}
