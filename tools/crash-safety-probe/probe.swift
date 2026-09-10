// recording-crash-safety probe (#31): measure, on this Mac, what survives when the app is
// killed while AVAssetWriter is still writing, and what writing in fragments costs later.
//
// Build:  swiftc -O -swift-version 5 probe.swift -o probe
// Usage:  ./probe <workdir>                               run everything below
//         ./probe <workdir> crash <audio|video> <frag>    child: write 30 s, then SIGKILL
//                                                          (frag = fragment seconds, 0 = plain)
//
// Results as of 2026-09-10 on macOS 26.6.2 arm64 are recorded in sprecorder-mac-0034.
import Foundation
import AVFoundation
import CoreMedia
import CoreVideo

func check(_ c: @autoclosure () -> Bool, _ m: @autoclosure () -> String) { if !c() { print("CHECK FAILED: \(m())"); fflush(stdout); exit(9) } }
setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
let work = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

let SR = 48000
let FPS = 30
let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(SR), channels: 1, interleaved: false)!

func wait(_ body: (@escaping () -> Void) -> Void) { let s = DispatchSemaphore(value: 0); body { s.signal() }; s.wait() }
func fileSize(_ u: URL) -> Int { (try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int) ?? -1 }

func tone(_ n: Int) -> Float { Float(0.4 * sin(2 * Double.pi * (300.0 + Double(n % (SR * 7)) / Double(SR) * 40.0) * Double(n) / Double(SR))) }

func pcmSampleBuffer(start: Int, count: Int) -> CMSampleBuffer {
    let buf = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(count))!
    buf.frameLength = AVAudioFrameCount(count)
    let p = buf.floatChannelData![0]
    for i in 0..<count { p[i] = tone(start + i) }
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(SR)),
                                    presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(SR)),
                                    decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    var st = CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                                  makeDataReadyCallback: nil, refcon: nil, formatDescription: pcmFormat.formatDescription,
                                  sampleCount: count, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                  sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sb)
    check(st == noErr, "CMSampleBufferCreate \(st)")
    st = CMSampleBufferSetDataBufferFromAudioBufferList(sb!, blockBufferAllocator: kCFAllocatorDefault,
                                                        blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0,
                                                        bufferList: buf.audioBufferList)
    check(st == noErr, "SetDataBuffer \(st)")
    return sb!
}

let aacSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: SR,
                                  AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000]
let W = 1280, H = 720
let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H]

// Write `seconds` of audio (and, if video, 30 fps H.264 frames) into url.
func write(_ url: URL, seconds: Int, video: Bool, fragment: Double, kill doKill: Bool = false) {
    try? FileManager.default.removeItem(at: url)
    let w = try! AVAssetWriter(outputURL: url, fileType: video ? .mp4 : .m4a)
    if fragment > 0 { w.movieFragmentInterval = CMTime(seconds: fragment, preferredTimescale: 600) }
    let a = AVAssetWriterInput(mediaType: .audio, outputSettings: aacSettings)
    a.expectsMediaDataInRealTime = false
    w.add(a)
    var v: AVAssetWriterInput? = nil
    var adaptor: AVAssetWriterInputPixelBufferAdaptor? = nil
    if video {
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vi.expectsMediaDataInRealTime = false
        w.add(vi)
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vi, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
        v = vi
    }
    check(w.startWriting(), "startWriting \(String(describing: w.error))")
    w.startSession(atSourceTime: .zero)
    let perFrame = SR / FPS
    for f in 0..<(seconds * FPS) {
        if let vi = v, let ad = adaptor {
            while !vi.isReadyForMoreMediaData { usleep(500) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, ad.pixelBufferPool!, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            let base = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
            let bpr = CVPixelBufferGetBytesPerRow(pb!)
            let shade = UInt8(f % 256)
            for y in stride(from: 0, to: H, by: 1) { memset(base + y * bpr, Int32((Int(shade) + y / 8) & 0xff), bpr) }
            CVPixelBufferUnlockBaseAddress(pb!, [])
            check(ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(FPS))), "video append \(String(describing: w.error))")
        }
        while !a.isReadyForMoreMediaData { usleep(500) }
        check(a.append(pcmSampleBuffer(start: f * perFrame, count: perFrame)), "audio append \(String(describing: w.error))")
    }
    if doKill { sleep(3); kill(getpid(), SIGKILL) }
    a.markAsFinished(); v?.markAsFinished()
    wait { done in w.finishWriting { done() } }
    check(w.status == .completed, "finishWriting \(String(describing: w.error))")
}

// What a player can get out of a file: seconds of decodable audio, and video frames.
func survives(_ url: URL) -> (audio: Double?, frames: Int?) {
    let asset = AVURLAsset(url: url)
    var at: AVAssetTrack?, vt: AVAssetTrack?
    wait { d in asset.loadTracks(withMediaType: .audio) { t, _ in at = t?.first; d() } }
    wait { d in asset.loadTracks(withMediaType: .video) { t, _ in vt = t?.first; d() } }
    var secs: Double? = nil, frames: Int? = nil
    if let t = at, let r = try? AVAssetReader(asset: asset) {
        let o = AVAssetReaderTrackOutput(track: t, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1, AVSampleRateKey: SR])
        r.add(o)
        if r.startReading() {
            var n = 0
            while let sb = o.copyNextSampleBuffer() { n += CMSampleBufferGetNumSamples(sb) }
            if r.status != .failed { secs = Double(n) / Double(SR) }
        }
    }
    if let t = vt, let r = try? AVAssetReader(asset: asset) {
        let o = AVAssetReaderTrackOutput(track: t, outputSettings: nil)
        r.add(o)
        if r.startReading() {
            var n = 0
            while let sb = o.copyNextSampleBuffer() { n += CMSampleBufferGetNumSamples(sb) }
            if r.status != .failed { frames = n }
        }
    }
    return (secs, frames)
}

// Top-level MP4 boxes, run-length compressed: "ftyp moov mdat" or "ftyp moov moof+mdat x12".
func boxes(_ url: URL) -> String {
    guard let h = try? FileHandle(forReadingFrom: url) else { return "?" }
    defer { try? h.close() }
    let total = UInt64(fileSize(url))
    var off: UInt64 = 0
    var seq: [String] = []
    while off + 8 <= total {
        try? h.seek(toOffset: off)
        guard let hd = try? h.read(upToCount: 16), hd.count >= 8 else { break }
        var size = UInt64(hd[0]) << 24 | UInt64(hd[1]) << 16 | UInt64(hd[2]) << 8 | UInt64(hd[3])
        let type = String(bytes: hd[4..<8], encoding: .ascii) ?? "????"
        if size == 1, hd.count >= 16 { size = hd[8..<16].reduce(0) { $0 << 8 | UInt64($1) } }
        if size == 0 { size = total - off }
        if size < 8 { seq.append("\(type)(bad)"); break }
        seq.append(type); off += size
    }
    var out: [String] = []
    var i = 0
    while i < seq.count {
        if i + 1 < seq.count && seq[i] == "moof" && seq[i + 1] == "mdat" {
            var n = 0
            while i + 1 < seq.count && seq[i] == "moof" && seq[i + 1] == "mdat" { n += 1; i += 2 }
            out.append("(moof mdat) x\(n)")
        } else { out.append(seq[i]); i += 1 }
    }
    return out.joined(separator: " ")
}

func exportPassthrough(_ src: URL, _ dst: URL, video: Bool) -> (ok: Bool, seconds: Double, err: String) {
    try? FileManager.default.removeItem(at: dst)
    let asset = AVURLAsset(url: src)
    guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return (false, 0, "no session") }
    ex.outputURL = dst
    ex.outputFileType = video ? .mp4 : .m4a
    let t0 = Date()
    wait { d in ex.exportAsynchronously { d() } }
    return (ex.status == .completed, Date().timeIntervalSince(t0), ex.error.map { "\($0)" } ?? "")
}

// ---------------- child mode ----------------
if args.count > 4 && args[2] == "crash" {
    let video = args[3] == "video"
    let frag = Double(args[4])!
    write(work.appendingPathComponent("crash-\(args[3])-frag\(args[4]).\(video ? "mp4" : "m4a")"), seconds: 30, video: video, fragment: frag, kill: true)
    exit(0)
}

// ---------------- 1. killed mid-write ----------------
print("== 1. Killed (SIGKILL) after 30 s written, before the file is finished")
for kind in ["audio", "video"] {
    for frag in ["0", "1", "2", "5"] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = [work.path, "crash", kind, frag]
        try! p.run(); p.waitUntilExit()
        let u = work.appendingPathComponent("crash-\(kind)-frag\(frag).\(kind == "video" ? "mp4" : "m4a")")
        let s = survives(u)
        let label = frag == "0" ? "plain         " : "fragments \(frag) s "
        let a = s.audio.map { String(format: "%.2f s audio", $0) } ?? "NO audio"
        let v = kind == "video" ? (s.frames.map { " , \($0) of 900 frames (\(String(format: "%.2f", Double($0) / Double(FPS))) s)" } ?? " , NO video") : ""
        print("  \(kind) \(label): \(fileSize(u)) bytes, \(a)\(v)  [\(boxes(u))]")
    }
}

// ---------------- 2. repairing a crashed fragmented file ----------------
print("\n== 2. Passthrough export of a crashed fragmented file (what a next-launch repair would do)")
for (kind, frag) in [("audio", "5"), ("video", "5"), ("audio", "0")] {
    let video = kind == "video"
    let src = work.appendingPathComponent("crash-\(kind)-frag\(frag).\(video ? "mp4" : "m4a")")
    let dst = work.appendingPathComponent("repaired-\(kind)-frag\(frag).\(video ? "mp4" : "m4a")")
    let r = exportPassthrough(src, dst, video: video)
    if r.ok {
        let s = survives(dst)
        print("  \(kind) frag \(frag): OK in \(String(format: "%.2f", r.seconds)) s -> \(fileSize(dst)) bytes, " +
              "\(s.audio.map { String(format: "%.2f s audio", $0) } ?? "NO audio")\(video ? ", \(s.frames ?? -1) frames" : "")  [\(boxes(dst))]")
    } else {
        print("  \(kind) frag \(frag): FAILED - \(r.err)")
    }
}

// ---------------- 3. finished normally: structure and size cost ----------------
print("\n== 3. Finished normally - 10 min audio: what the finished file looks like, and what fragments cost")
var plainBytes = 0
for frag in [0.0, 1.0, 2.0, 5.0] {
    let u = work.appendingPathComponent("finished-audio-frag\(Int(frag)).m4a")
    let t0 = Date()
    write(u, seconds: 600, video: false, fragment: frag)
    let bytes = fileSize(u)
    if frag == 0 { plainBytes = bytes }
    let s = survives(u)
    print("  frag \(Int(frag)) s: \(bytes) bytes (\(frag == 0 ? "baseline" : String(format: "%+.2f%%", 100.0 * Double(bytes - plainBytes) / Double(plainBytes)))), " +
          "\(String(format: "%.2f", s.audio ?? -1)) s audio, written in \(String(format: "%.1f", Date().timeIntervalSince(t0))) s  [\(boxes(u))]")
}

print("\n== 4. Finished normally - 60 s video+audio, fragments 2 s vs plain")
for frag in [0.0, 2.0] {
    let u = work.appendingPathComponent("finished-video-frag\(Int(frag)).mp4")
    write(u, seconds: 60, video: true, fragment: frag)
    let s = survives(u)
    print("  frag \(Int(frag)) s: \(fileSize(u)) bytes, \(s.frames ?? -1) frames, \(String(format: "%.2f", s.audio ?? -1)) s audio  [\(boxes(u))]")
}

print("\n== 5. Passthrough export of a FINISHED fragmented file - does it come out plain, and how fast?")
for (name, video) in [("finished-audio-frag2.m4a", false), ("finished-video-frag2.mp4", true)] {
    let src = work.appendingPathComponent(name)
    let dst = work.appendingPathComponent("tidied-" + name)
    let r = exportPassthrough(src, dst, video: video)
    let s = survives(dst)
    print("  \(name): \(r.ok ? "OK" : "FAILED \(r.err)") in \(String(format: "%.2f", r.seconds)) s -> \(fileSize(dst)) bytes, " +
          "\(String(format: "%.2f", s.audio ?? -1)) s audio\(video ? ", \(s.frames ?? -1) frames" : "")  [\(boxes(dst))]")
}
print("\ndone")
