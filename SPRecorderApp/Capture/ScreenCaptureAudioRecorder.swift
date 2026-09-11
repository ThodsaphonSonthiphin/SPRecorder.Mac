import AVFoundation
import CoreMedia
import ScreenCaptureKit
import SPRecorderCore

/// Records the System track and the Mic track from one ScreenCaptureKit stream (research #3):
/// `capturesAudio` for computer audio, `captureMicrophone` for the microphone. The stream needs
/// a display to exist, so it is given the first display and a tiny, slow video output whose
/// frames are ignored — the same configuration that captured audio in
/// `tools/setup-check-probe`.
final class ScreenCaptureAudioRecorder: NSObject, AudioCapturing, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let diary: Diary
    private let bitrateKbps: @Sendable () -> Int
    private let queue = DispatchQueue(label: "com.sprecorder.mac.capture")

    // Touched only on `queue`.
    private var stream: SCStream?
    private var systemTrackURL: URL?
    private var micTrackURL: URL?
    private var system: TrackWriter?
    private var mic: TrackWriter?
    private var failedTracks: Set<String> = []
    private var sessionStart: CMTime?
    private var bitrate = 64
    private var onInterrupted: (@Sendable (CaptureError) -> Void)?

    init(diary: Diary, bitrateKbps: @escaping @Sendable () -> Int) {
        self.diary = diary
        self.bitrateKbps = bitrateKbps
    }

    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws {
        // Asked lazily, when recording first starts (sprecorder-mac-0006). A refusal found here
        // is certain; a grant is not, so capture itself is still the proof.
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            diary.error(.permissions, "Microphone access is refused; a running SPRecorder keeps this answer, so allowing it in System Settings takes effect after reopening")
            throw CaptureError.microphoneNotAllowed
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            diary.error(.permissions, "ScreenCaptureKit would not list displays: \(Self.describe(error))")
            throw Self.translate(error)
        }
        guard let display = content.displays.first else {
            diary.error(.systemTrack, "ScreenCaptureKit listed no displays")
            throw CaptureError.failed("No display was found, and computer audio is captured through one.")
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.captureMicrophone = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.width = 16
        config.height = 16
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2)

        let newStream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try newStream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        } catch {
            diary.error(.systemTrack, "Could not attach to the capture stream: \(Self.describe(error))")
            throw Self.translate(error)
        }

        let kbps = bitrateKbps()
        queue.sync {
            systemTrackURL = systemTrack
            micTrackURL = micTrack
            system = nil
            mic = nil
            failedTracks = []
            sessionStart = nil
            bitrate = kbps
            self.onInterrupted = onInterrupted
        }

        do {
            try await newStream.startCapture()
        } catch {
            diary.error(.systemTrack, "Capture stream did not start: \(Self.describe(error))")
            queue.sync { self.onInterrupted = nil }
            throw Self.translate(error)
        }
        queue.sync { stream = newStream }
        diary.notice(.systemTrack, "Capture started on display \(display.displayID), AAC \(kbps) kbps")
    }

    func stop() async throws {
        let running = queue.sync { stream }
        if let running {
            do {
                try await running.stopCapture()
            } catch {
                diary.warning(.systemTrack, "Capture stream did not stop cleanly: \(Self.describe(error))")
            }
        }
        // stopCapture has returned; disarm everything so a late buffer cannot start a new writer, then take the writers off the queue.
        let (systemWriter, micWriter) = queue.sync { () -> (TrackWriter?, TrackWriter?) in
            let writers = (system, mic)
            stream = nil
            system = nil
            mic = nil
            onInterrupted = nil
            systemTrackURL = nil
            micTrackURL = nil
            sessionStart = nil
            return writers
        }

        var firstError: CaptureError?
        for (name, category, writer) in [("System track", DiaryCategory.systemTrack, systemWriter), ("Mic track", .micTrack, micWriter)] {
            guard let writer else {
                diary.warning(category, "\(name): no audio arrived, so no file was written")
                continue
            }
            do {
                try await writer.finish()
                diary.notice(category, "\(name) finished: \(writer.url.lastPathComponent), \(writer.appendedBuffers) buffers, \(writer.droppedBuffers) dropped")
                if writer.droppedBuffers > 0 {
                    diary.warning(category, "\(name) dropped \(writer.droppedBuffers) buffers; the file has short gaps")
                }
                if !writer.heardSound {
                    diary.warning(category, category == .micTrack
                        ? "\(name) is completely silent; the microphone may be muted or not allowed"
                        : "\(name) is completely silent; the computer played no sound during the Recording Session")
                }
            } catch {
                let reason = CaptureError(error)
                diary.error(category, reason.plainWords)
                if firstError == nil { firstError = reason }
            }
        }
        if let firstError { throw firstError }
    }

    // MARK: SCStreamOutput — called on `queue`

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, type == .audio || type == .microphone else { return }
        if sessionStart == nil { sessionStart = sampleBuffer.presentationTimeStamp }
        if type == .audio {
            system = system ?? makeWriter(name: "System track", category: .systemTrack, url: systemTrackURL, first: sampleBuffer)
            append(sampleBuffer, to: system, name: "System track", category: .systemTrack)
        } else {
            mic = mic ?? makeWriter(name: "Mic track", category: .micTrack, url: micTrackURL, first: sampleBuffer)
            append(sampleBuffer, to: mic, name: "Mic track", category: .micTrack)
        }
    }

    /// Appends, and the first time a track's writer has failed, stops the session: a full disk or a
    /// changed input format would otherwise look like dropped buffers until stop.
    private func append(_ buffer: CMSampleBuffer, to writer: TrackWriter?, name: String, category: DiaryCategory) {
        guard let writer, !failedTracks.contains(name) else { return }
        writer.append(buffer)
        guard let error = writer.failure else { return }
        failedTracks.insert(name)
        let reason = CaptureError.failed("The \(name) stopped writing: \(error.localizedDescription)")
        diary.error(category, reason.plainWords)
        onInterrupted?(reason)
        onInterrupted = nil
    }

    private func makeWriter(name: String, category: DiaryCategory, url: URL?, first: CMSampleBuffer) -> TrackWriter? {
        guard let url, let format = first.formatDescription, let sessionStart, !failedTracks.contains(name) else { return nil }
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
            diary.notice(category, "\(name) audio: \(Int(asbd.mSampleRate)) Hz, \(asbd.mChannelsPerFrame) channel(s), writing \(url.lastPathComponent)")
        }
        do {
            let writer = try TrackWriter(url: url, trackName: name, format: format, bitrateKbps: bitrate, sessionStart: sessionStart)
            if writer.bitrateKbps != bitrate {
                diary.notice(category, "\(name): \(bitrate) kbps is not offered at this sample rate; using \(writer.bitrateKbps) kbps")
            }
            return writer
        } catch {
            failedTracks.insert(name)
            let reason = CaptureError(error)
            diary.error(category, reason.plainWords)
            onInterrupted?(reason)
            onInterrupted = nil
            return nil
        }
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        diary.error(.systemTrack, "Capture stream stopped by itself: \(Self.describe(error))")
        queue.async {
            let callback = self.onInterrupted
            self.onInterrupted = nil
            callback?(Self.translate(error))
        }
    }

    // MARK: Errors

    /// `-3801` in `SCStreamErrorDomain` is the refusal measured by `tools/tcc-probe`:
    /// "The user declined TCCs for application, window, display capture".
    static func translate(_ error: any Error) -> CaptureError {
        let ns = error as NSError
        if ns.domain == SCStreamErrorDomain && ns.code == SCStreamError.Code.userDeclined.rawValue {
            return .computerAudioNotAllowed
        }
        return CaptureError(error)
    }

    static func describe(_ error: any Error) -> String {
        let ns = error as NSError
        return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
    }
}
