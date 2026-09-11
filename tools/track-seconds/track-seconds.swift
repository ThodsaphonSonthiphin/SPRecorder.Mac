// Prints how many seconds of audio a player can decode from each file given — the same
// measure tools/crash-safety-probe used (sprecorder-mac-0034). Works on a file whose writer
// was killed before it finished.
//
// Usage: swift tools/track-seconds/track-seconds.swift <file.m4a> [more files...]
import AVFoundation

func decodableSeconds(_ url: URL) async -> String {
    let asset = AVURLAsset(url: url)
    guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return "no audio track" }
    guard let reader = try? AVAssetReader(asset: asset) else { return "unreadable" }
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
    reader.add(output)
    guard reader.startReading() else { return "unreadable: \(reader.error?.localizedDescription ?? "?")" }
    var frames = 0
    var rate = 0.0
    while let buffer = output.copyNextSampleBuffer() {
        frames += CMSampleBufferGetNumSamples(buffer)
        if rate == 0, let f = buffer.formatDescription, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(f)?.pointee {
            rate = asbd.mSampleRate
        }
    }
    if reader.status == .failed { return "decode failed after \(frames) frames: \(reader.error?.localizedDescription ?? "?")" }
    return rate > 0 ? String(format: "%.2f s decodable", Double(frames) / rate) : "no samples"
}

for path in CommandLine.arguments.dropFirst() {
    print("\(path): \(await decodableSeconds(URL(fileURLWithPath: path)))")
}
