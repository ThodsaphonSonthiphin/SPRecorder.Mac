import AVFoundation
import CoreMedia
import SPRecorderCore

/// Writes one track as AAC in an `.m4a` (research #6), in 2-second pieces so a crash keeps all
/// but the last few seconds (sprecorder-mac-0034, sprecorder-mac-0038 rule 1).
/// Used only from the capture queue.
final class TrackWriter: @unchecked Sendable {
    let url: URL
    let trackName: String
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private(set) var appendedBuffers = 0
    private(set) var droppedBuffers = 0
    /// False while every sample so far is exactly zero — what a refused microphone delivers
    /// (measured, sprecorder-mac-0023 amendment).
    private(set) var heardSound = false

    init(url: URL, trackName: String, format: CMFormatDescription, bitrateKbps: Int, sessionStart: CMTime) throws {
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
            throw CaptureError.failed("The \(trackName) delivered audio in a format SPRecorder cannot read.")
        }
        self.url = url
        self.trackName = trackName
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        writer.movieFragmentInterval = CMTime(seconds: 2, preferredTimescale: 600)
        input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: asbd.mSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: bitrateKbps * 1000,
        ], sourceFormatHint: format)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw CaptureError.failed("The \(trackName) could not be set up for writing.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw CaptureError.failed("The \(trackName) could not start writing: \(writer.error?.localizedDescription ?? "unknown error")")
        }
        // Every track starts its timeline at the first buffer of the whole stream, so the two
        // files stay in step for the Mixed file (Plan 2).
        writer.startSession(atSourceTime: sessionStart)
    }

    func append(_ buffer: CMSampleBuffer) {
        if !heardSound { heardSound = Self.containsSound(buffer) }
        if input.isReadyForMoreMediaData && input.append(buffer) {
            appendedBuffers += 1
        } else {
            droppedBuffers += 1
        }
    }

    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw CaptureError.failed("The \(trackName) could not be finished: \(writer.error?.localizedDescription ?? "unknown error")")
        }
    }

    private static func containsSound(_ buffer: CMSampleBuffer) -> Bool {
        var found = false
        try? buffer.withAudioBufferList { list, _ in
            for audio in list {
                guard let data = audio.mData else { continue }
                let bytes = UnsafeRawBufferPointer(start: data, count: Int(audio.mDataByteSize))
                if bytes.contains(where: { $0 != 0 }) { found = true; return }
            }
        }
        return found
    }
}
