// aac-splitting probe (sprecorder-mac-0026): measure, on this Mac, how an AAC .m4a
// behaves when cut into parts, and what survives if the app dies mid-write.
//
// Build:  swiftc -Onone -swift-version 5 probe.swift -o probe
// Usage:  ./probe <workdir>                  cut a 60 s source three ways, size mode, crash test
//         ./probe <workdir> extra            fragmented source, one-hour speed, size estimate-verify
//         ./probe <workdir> crash <0|1>      child used by the crash test: write 30 s, then SIGKILL
//
// Results as of 2026-09-10 on macOS 26.6.2 arm64 are recorded in sprecorder-mac-0026.
import Foundation
import AVFoundation
import CoreMedia
func check(_ c: @autoclosure () -> Bool, _ m: @autoclosure () -> String) { if !c() { print("CHECK FAILED: \(m())"); fflush(stdout); exit(9) } }

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
let work = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

let SR = 48000
let TOTAL_SECONDS = 60
let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(SR), channels: 1, interleaved: false)!

// Linear chirp 200 -> 2000 Hz over 60 s: non-periodic, so alignment by search is unambiguous.
func chirp(_ n: Int) -> Float {
    let t = Double(n) / Double(SR)
    let f0 = 200.0, k = (2000.0 - 200.0) / Double(TOTAL_SECONDS)
    return Float(0.5 * sin(2 * Double.pi * (f0 * t + 0.5 * k * t * t)))
}

func wait(_ body: (@escaping () -> Void) -> Void) {
    let sem = DispatchSemaphore(value: 0)
    body { sem.signal() }
    sem.wait()
}

func pcmSampleBuffer(start: Int, count: Int) -> CMSampleBuffer {
    let buf = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(count))!
    buf.frameLength = AVAudioFrameCount(count)
    let p = buf.floatChannelData![0]
    for i in 0..<count { p[i] = chirp(start + i) }
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

let aacSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: SR,
    AVNumberOfChannelsKey: 1,
    AVEncoderBitRateKey: 64000,
]

// Encode chirp samples [from, to) into an .m4a with a fresh encoder.
func encode(_ url: URL, from: Int, to: Int, fragmentSeconds: Double? = nil, killAfterAppend: Bool = false) {
    try? FileManager.default.removeItem(at: url)
    let w = try! AVAssetWriter(outputURL: url, fileType: .m4a)
    if let f = fragmentSeconds { w.movieFragmentInterval = CMTime(seconds: f, preferredTimescale: 600) }
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: aacSettings)
    input.expectsMediaDataInRealTime = false
    w.add(input)
    check(w.startWriting(), "startWriting \(String(describing: w.error))")
    w.startSession(atSourceTime: CMTime(value: CMTimeValue(from), timescale: CMTimeScale(SR)))
    var n = from
    let chunk = 4800
    while n < to {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        let c = min(chunk, to - n)
        check(input.append(pcmSampleBuffer(start: n, count: c)), "append \(String(describing: w.error))")
        n += c
    }
    if killAfterAppend {
        sleep(3) // let the writer flush whatever it is going to flush
        kill(getpid(), SIGKILL)
    }
    input.markAsFinished()
    wait { done in w.finishWriting { done() } }
    check(w.status == .completed, "finishWriting \(String(describing: w.error))")
}

func firstAudioTrack(_ url: URL) -> (AVURLAsset, AVAssetTrack)? {
    let asset = AVURLAsset(url: url)
    var track: AVAssetTrack?
    wait { done in
        asset.loadTracks(withMediaType: .audio) { tracks, _ in track = tracks?.first; done() }
    }
    guard let t = track else { return nil }
    return (asset, t)
}

// Decode through AVFoundation exactly as a player would (priming / edit list honoured).
func decode(_ url: URL) -> [Float]? {
    guard let (asset, track) = firstAudioTrack(url) else { return nil }
    guard let r = try? AVAssetReader(asset: asset) else { return nil }
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVNumberOfChannelsKey: 1,
        AVSampleRateKey: SR,
    ])
    r.add(out)
    guard r.startReading() else { return nil }
    var samples: [Float] = []
    while let sb = out.copyNextSampleBuffer() {
        guard let bb = CMSampleBufferGetDataBuffer(sb) else { continue }
        let len = CMBlockBufferGetDataLength(bb)
        var data = [Float](repeating: 0, count: len / 4)
        data.withUnsafeMutableBytes { raw in
            _ = CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: len, destination: raw.baseAddress!)
        }
        samples.append(contentsOf: data)
    }
    return r.status == .completed ? samples : nil
}

func fileSize(_ url: URL) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
}

// Packet-copy split: read compressed AAC packets, write them untouched into rolling files.
// roll(partPacketCount, partPayloadBytes, nextPacketBytes, nextPacketPTS, partStartPTS) -> Bool
func splitPacketCopy(_ src: URL, prefix: String,
                     roll: (Int, Int, Int, CMTime, CMTime) -> Bool) -> [(URL, Int)] {
    let (asset, track) = firstAudioTrack(src)!
    let r = try! AVAssetReader(asset: asset)
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    r.add(out)
    check(r.startReading(), "startReading")
    var parts: [(URL, Int)] = []
    var writer: AVAssetWriter?
    var input: AVAssetWriterInput?
    var packets = 0, payload = 0
    var partStart = CMTime.zero
    var printedAttachments = false
    func close() {
        guard let w = writer, let i = input else { return }
        i.markAsFinished()
        wait { done in w.finishWriting { done() } }
        check(w.status == .completed, "part finish \(String(describing: w.error))")
        parts[parts.count - 1].1 = payload
    }
    while let sb = out.copyNextSampleBuffer() {
        if !printedAttachments {
            printedAttachments = true
            let trim = CMGetAttachment(sb, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart, attachmentModeOut: nil)
            print("    passthrough reader, first buffer: \(CMSampleBufferGetNumSamples(sb)) packets, trim-at-start attachment = \(trim.map { "\($0)" } ?? "none")")
        }
        let nPackets = CMSampleBufferGetNumSamples(sb)
        let trimEnd = CMGetAttachment(sb, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd, attachmentModeOut: nil)
        if trimEnd != nil { print("    buffer with \(nPackets) packets at \(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))) s carries trim-at-end \(CMTimeGetSeconds(CMTimeMakeFromDictionary((trimEnd as! CFDictionary)))) s") }
        guard nPackets > 0, let fmt = CMSampleBufferGetFormatDescription(sb) else { print("    skipped a buffer with \(nPackets) packets and format \(CMSampleBufferGetFormatDescription(sb) == nil ? "none" : "present")"); continue }
        for i in 0..<CMSampleBufferGetNumSamples(sb) {
            var single: CMSampleBuffer?
            check(CMSampleBufferCopySampleBufferForRange(allocator: nil, sampleBuffer: sb,
                                                                sampleRange: CFRange(location: i, length: 1),
                                                                sampleBufferOut: &single) == noErr, "copy range")
            let size = CMSampleBufferGetSampleSize(sb, at: i)
            let pts = CMSampleBufferGetPresentationTimeStamp(single!)
            if writer == nil || roll(packets, payload, size, pts, partStart) {
                close()
                let url = work.appendingPathComponent(String(format: "\(prefix) %03d.m4a", parts.count + 1))
                try? FileManager.default.removeItem(at: url)
                let w = try! AVAssetWriter(outputURL: url, fileType: .m4a)
                let inp = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: fmt)
                inp.expectsMediaDataInRealTime = false
                w.add(inp)
                check(w.startWriting(), "part startWriting \(String(describing: w.error))")
                w.startSession(atSourceTime: pts)
                writer = w; input = inp
                parts.append((url, 0))
                packets = 0; payload = 0; partStart = pts
            }
            while !input!.isReadyForMoreMediaData { usleep(500) }
            check(input!.append(single!), "append packet \(String(describing: writer!.error))")
            packets += 1; payload += size
        }
    }
    close()
    return parts
}

func exportPassthrough(_ src: URL, to url: URL, start: Double, duration: Double?, lengthLimit: Int64? = nil) -> Bool {
    try? FileManager.default.removeItem(at: url)
    let asset = AVURLAsset(url: src)
    guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return false }
    s.outputURL = url
    s.outputFileType = .m4a
    let st = CMTime(seconds: start, preferredTimescale: CMTimeScale(SR))
    s.timeRange = CMTimeRange(start: st, duration: duration.map { CMTime(seconds: $0, preferredTimescale: CMTimeScale(SR)) } ?? .positiveInfinity)
    if let l = lengthLimit { s.fileLengthLimit = l }
    wait { done in s.exportAsynchronously { done() } }
    if s.status != .completed { print("    export failed: \(String(describing: s.error))") }
    return s.status == .completed
}

// Find where a decoded part sits inside the decoded reference.
func locate(_ part: [Float], in ref: [Float], expectedStart: Int) -> Int {
    let skip = 4096, win = 8192
    guard part.count > skip + win else { return -1 }
    var best = -1; var bestErr = Double.greatestFiniteMagnitude
    let lo = max(0, expectedStart - 8000), hi = min(ref.count - skip - win, expectedStart + 8000)
    if lo > hi { return -1 }
    for o in lo...hi {
        var e = 0.0
        var j = 0
        while j < win { let d = Double(part[skip + j] - ref[o + skip + j]); e += d * d; if e > bestErr { break }; j += 4 }
        if e < bestErr { bestErr = e; best = o }
    }
    return best
}

func rms(_ a: ArraySlice<Float>, _ b: ArraySlice<Float>) -> Double {
    var e = 0.0
    for (x, y) in zip(a, b) { let d = Double(x - y); e += d * d }
    return (e / Double(max(1, min(a.count, b.count)))).squareRoot()
}

func analyse(_ label: String, parts: [URL], ref: [Float], expectedStarts: [Int]) {
    print("  \(label)")
    var prevEnd: Int?
    var total = 0
    for (k, url) in parts.enumerated() {
        guard let pcm = decode(url) else { print("    part \(k + 1): UNREADABLE"); continue }
        total += pcm.count
        let start = pcm.count > 12288 ? locate(pcm, in: ref, expectedStart: prevEnd ?? 0) : (prevEnd ?? 0)
        let joinNote: String
        if let pe = prevEnd {
            let gap = start - pe
            joinNote = gap == 0 ? "joins exactly" : (gap > 0 ? "GAP of \(gap) samples (\(String(format: "%.1f", Double(gap) * 1000 / Double(SR))) ms missing)" : "OVERLAP of \(-gap) samples (\(String(format: "%.1f", Double(-gap) * 1000 / Double(SR))) ms repeated)")
        } else { joinNote = "first part" }
        let n = min(1024, pcm.count)
        let head = start >= 0 && start + n <= ref.count ? rms(pcm[0..<n], ref[start..<min(ref.count, start + n)]) : -1
        let mid = start >= 0 && pcm.count > 20000 ? rms(pcm[10000..<11024], ref[(start + 10000)..<(start + 11024)]) : -1
        print(String(format: "    part %d: %@  %8d bytes  %8d samples (%.3f s)  starts at ref sample %d  | %@  | head err %.4f vs mid err %.4f",
                     k + 1, url.lastPathComponent, fileSize(url), pcm.count, Double(pcm.count) / Double(SR), start, joinNote, head, mid))
        prevEnd = start + pcm.count
    }
    print("    total decoded samples across parts: \(total) (reference \(ref.count), difference \(total - ref.count))")
}

// ---------------- child mode: crash ----------------
if args.count > 2 && args[2] == "crash" {
    let frag = args[3] == "1"
    let url = work.appendingPathComponent(frag ? "crash-fragmented.m4a" : "crash-plain.m4a")
    encode(url, from: 0, to: 30 * SR, fragmentSeconds: frag ? 5 : nil, killAfterAppend: true)
    exit(0)
}

if args.count > 2 && args[2] == "extra" {
    // A. export split from a FINISHED fragmented source
    print("== A. Built-in trim on a source written in 5 s fragments (finished normally)")
    let fsrc = work.appendingPathComponent("fragmented-source.m4a")
    encode(fsrc, from: 0, to: TOTAL_SECONDS * SR, fragmentSeconds: 5)
    let fref = decode(fsrc)!
    print("  fragmented-source.m4a: \(fileSize(fsrc)) bytes, decodes to \(fref.count) samples")
    var fparts: [URL] = []
    for k in 0..<3 {
        let u = work.appendingPathComponent(String(format: "fragmented-export %03d.m4a", k + 1))
        if exportPassthrough(fsrc, to: u, start: Double(k * 20), duration: 20) { fparts.append(u) }
    }
    analyse("result", parts: fparts, ref: fref, expectedStarts: [])

    // B. speed on one hour
    print("\n== B. One hour of audio: encode, then cut into 30-minute parts with the built-in trim")
    let hour = work.appendingPathComponent("hour.m4a")
    var t0 = Date()
    encode(hour, from: 0, to: 3600 * SR)
    print(String(format: "  encoding 1 h took %.1f s; file %d bytes (%.1f MB)", Date().timeIntervalSince(t0), fileSize(hour), Double(fileSize(hour)) / 1_048_576))
    t0 = Date()
    for k in 0..<2 {
        let u = work.appendingPathComponent(String(format: "hour %03d.m4a", k + 1))
        _ = exportPassthrough(hour, to: u, start: Double(k * 1800), duration: 1800)
        print("  \(u.lastPathComponent): \(fileSize(u)) bytes")
    }
    print(String(format: "  cutting 1 h into 2 parts took %.2f s", Date().timeIntervalSince(t0)))

    // C. size mode by estimate, then verify and shrink
    print("\n== C. Size mode by estimate-then-verify: limit 150,000 bytes on the 60 s source")
    let src = work.appendingPathComponent("source.m4a")
    if fileSize(src) < 0 { encode(src, from: 0, to: TOTAL_SECONDS * SR) }
    let sref = decode(src)!
    let limit = 150_000
    let total = Double(TOTAL_SECONDS)
    let bytesPerSecond = Double(fileSize(src)) / total
    var start = 0.0, k = 0, attempts = 0
    var sparts: [URL] = []
    while start < total - 0.001 {
        k += 1
        var dur = min(total - start, Double(limit) * 0.97 / bytesPerSecond)
        let u = work.appendingPathComponent(String(format: "size-estimate %03d.m4a", k))
        while true {
            attempts += 1
            _ = exportPassthrough(src, to: u, start: start, duration: dur)
            let fs = fileSize(u)
            if fs <= limit { print(String(format: "  part %d: %.3f s, %d bytes, within limit", k, dur, fs)); break }
            let shrunk = dur * Double(limit) * 0.99 / Double(fs)
            print(String(format: "  part %d: %.3f s gave %d bytes, OVER; retrying at %.3f s", k, dur, fs, shrunk))
            dur = shrunk
        }
        sparts.append(u)
        start += dur
    }
    print("  \(attempts) exports for \(k) parts")
    analyse("joins", parts: sparts, ref: sref, expectedStarts: [])
    exit(0)
}

// ---------------- 1. source ----------------
print("== 1. Source: 60 s mono 48 kHz chirp encoded to AAC 64 kbps by AVAssetWriter (fresh encoder)")
let src = work.appendingPathComponent("source.m4a")
encode(src, from: 0, to: TOTAL_SECONDS * SR)
let ref = decode(src)!
print("  source.m4a: \(fileSize(src)) bytes, decodes to \(ref.count) samples (encoded \(TOTAL_SECONDS * SR), difference \(ref.count - TOTAL_SECONDS * SR))")

let starts20 = [0, 20 * SR, 40 * SR]

// ---------------- 2. packet copy by time ----------------
print("\n== 2. After stop, packet copy, Time mode (20 s parts)")
let pcTime = splitPacketCopy(src, prefix: "packetcopy-time") { _, _, _, pts, partStart in
    CMTimeGetSeconds(CMTimeSubtract(pts, partStart)) >= 20.0
}
analyse("result", parts: pcTime.map { $0.0 }, ref: ref, expectedStarts: starts20)

// ---------------- 3. export session passthrough by time ----------------
print("\n== 3. After stop, AVAssetExportSession passthrough on time ranges (20 s parts)")
var exParts: [URL] = []
for k in 0..<3 {
    let u = work.appendingPathComponent(String(format: "export-time %03d.m4a", k + 1))
    if exportPassthrough(src, to: u, start: Double(k * 20), duration: 20) { exParts.append(u) }
}
analyse("result", parts: exParts, ref: ref, expectedStarts: starts20)

// ---------------- 4. fresh encoder per part (= live rollover, or re-encode on split) ----------------
print("\n== 4. Fresh encoder per part from PCM (what a live rollover or a re-encoding split produces)")
var encParts: [URL] = []
for k in 0..<3 {
    let u = work.appendingPathComponent(String(format: "fresh-encoder %03d.m4a", k + 1))
    encode(u, from: k * 20 * SR, to: (k + 1) * 20 * SR)
    encParts.append(u)
}
analyse("result", parts: encParts, ref: ref, expectedStarts: starts20)

// ---------------- 5. size mode ----------------
print("\n== 5. Size mode: packet copy with a 150,000-byte limit, counting payload only (no overhead allowance)")
let limit = 150_000
let pcSize = splitPacketCopy(src, prefix: "packetcopy-size") { _, payload, next, _, _ in payload + next > limit }
for (u, payload) in pcSize {
    let fs = fileSize(u)
    print("  \(u.lastPathComponent): payload \(payload) bytes, file \(fs) bytes, container overhead \(fs - payload) bytes, \(fs <= limit ? "within" : "OVER") limit")
}
print("\n   Export session with fileLengthLimit = 150,000 from t = 0:")
let exSize = work.appendingPathComponent("export-size 001.m4a")
if exportPassthrough(src, to: exSize, start: 0, duration: nil, lengthLimit: Int64(limit)) {
    let pcm = decode(exSize)
    print("  \(exSize.lastPathComponent): file \(fileSize(exSize)) bytes, \(pcm.map { String(format: "%.3f s", Double($0.count) / Double(SR)) } ?? "UNREADABLE"), \(fileSize(exSize) <= limit ? "within" : "OVER") limit")
}

// ---------------- 6. crash durability ----------------
print("\n== 6. App killed (SIGKILL) after writing 30 s, before the file is finished")
for frag in ["0", "1"] {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = [work.path, "crash", frag]
    try! p.run()
    p.waitUntilExit()
    let u = work.appendingPathComponent(frag == "1" ? "crash-fragmented.m4a" : "crash-plain.m4a")
    let pcm = decode(u)
    print("  \(frag == "1" ? "with movieFragmentInterval 5 s" : "plain .m4a                    "): \(fileSize(u)) bytes on disk, child exit reason \(p.terminationReason == .uncaughtSignal ? "signal \(p.terminationStatus)" : "exit \(p.terminationStatus)"), readable: \(pcm.map { String(format: "YES, %.3f s of audio", Double($0.count) / Double(SR)) } ?? "NO")")
}
