// Setup-check probe - a throwaway menu-bar app for the decision-map ticket
// `check-my-setup-probe`. It measures two claims the Check my setup design
// rests on, instead of guessing at them:
//
//   1. sprecorder-mac-0025 - after Don't Allow, can the app reset ITS OWN
//      permission entry from inside itself (no terminal, no admin password),
//      be asked again, and capture without a relaunch?
//   2. sprecorder-mac-0023 - does ScreenCaptureKit's computer-audio capture
//      hear a chime the app itself plays - and still hear it when the output
//      is muted, or routed to headphones?
//
// It never records or logs a keystroke. The Input Monitoring test only asks
// whether a listen-only event tap CAN be created, and destroys it at once.

import AppKit
import AVFoundation
import AudioToolbox
import CoreAudio
import CoreGraphics
import CoreMedia
import IOKit.hid
import ScreenCaptureKit

let logPath = ProcessInfo.processInfo.environment["PROBE_LOG"] ?? "/tmp/setup-check-probe.log"
let bundleID = Bundle.main.bundleIdentifier ?? "(no bundle id - not running as an .app)"

func log(_ s: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(s)\n"
    if !FileManager.default.fileExists(atPath: logPath) {
        FileManager.default.createFile(atPath: logPath, contents: nil)
    }
    if let fh = FileHandle(forWritingAtPath: logPath) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        try? fh.close()
    }
}

// MARK: - The three permissions

enum Grant: String, CaseIterable {
    case screen = "ScreenCapture"   // Screen & System Audio Recording
    case mic = "Microphone"
    case input = "ListenEvent"      // Input Monitoring

    var label: String {
        switch self {
        case .screen: return "Screen & System Audio"
        case .mic: return "Microphone"
        case .input: return "Input Monitoring"
        }
    }
}

func snapshot() -> String {
    let screen = CGPreflightScreenCaptureAccess()
    let mic: String
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: mic = "authorized"
    case .denied: mic = "denied"
    case .restricted: mic = "restricted"
    case .notDetermined: mic = "notDetermined"
    @unknown default: mic = "unknown"
    }
    let hid: String
    switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
    case kIOHIDAccessTypeGranted: hid = "granted"
    case kIOHIDAccessTypeDenied: hid = "denied"
    default: hid = "unknown"
    }
    return "screenPreflight=\(screen) micStatus=\(mic) inputHID=\(hid) listenPreflight=\(CGPreflightListenEventAccess())"
}

final class Probe: NSObject, NSApplicationDelegate, SCStreamOutput, SCStreamDelegate {
    var item: NSStatusItem!
    let audioQueue = DispatchQueue(label: "probe.audio")
    let lock = NSLock()
    var samples: [Float] = []
    var sampleRate: Double = 48_000
    var chimeStartIndex: Int? = nil
    var micEngine: AVAudioEngine?
    var chimeEngine: AVAudioEngine?
    var stream: SCStream?
    var loggedFormat = false

    func applicationDidFinishLaunching(_ n: Notification) {
        log("=== PROBE START - pid \(getpid()) bundle \(bundleID) ===")
        log("snapshot at launch: \(snapshot())")
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Probe"
        let menu = NSMenu()
        for g in Grant.allCases {
            let header = NSMenuItem(title: g.label, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(action("   1. Ask for permission") { self.ask(g) })
            menu.addItem(action("   2. Test it now") { self.test(g) })
            menu.addItem(action("   3. Reset my own entry (from inside the app)") { self.reset(g) })
            menu.addItem(.separator())
        }
        menu.addItem(action("Chime test - play a chime, listen to computer audio") { self.chimeTest() })
        menu.addItem(.separator())
        menu.addItem(action("Quit probe") { log("=== PROBE QUIT ==="); NSApp.terminate(nil) })
        item.menu = menu
    }

    func verdict(_ s: String) {
        log(s)
        DispatchQueue.main.async { self.item.button?.title = "Probe: " + String(s.prefix(40)) }
    }

    // MARK: ask

    func ask(_ g: Grant) {
        log("ASK \(g.rawValue) - before: \(snapshot())")
        switch g {
        case .screen:
            log("ASK ScreenCapture - CGRequestScreenCaptureAccess() returned \(CGRequestScreenCaptureAccess())")
        case .mic:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                log("ASK Microphone - requestAccess completion granted=\(granted)")
            }
        case .input:
            log("ASK ListenEvent - CGRequestListenEventAccess() returned \(CGRequestListenEventAccess())")
            log("ASK ListenEvent - IOHIDRequestAccess() returned \(IOHIDRequestAccess(kIOHIDRequestTypeListenEvent))")
        }
    }

    // MARK: test - attempt the real thing, never trust the cached hint alone

    func test(_ g: Grant) {
        log("TEST \(g.rawValue) - snapshot: \(snapshot())")
        switch g {
        case .screen:
            Task {
                do {
                    let c = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    self.verdict("TEST ScreenCapture PASS - SCShareableContent OK, \(c.displays.count) display(s)")
                } catch {
                    self.verdict("TEST ScreenCapture FAIL - \(error.localizedDescription)")
                }
            }
        case .mic:
            let engine = AVAudioEngine()
            micEngine = engine
            let input = engine.inputNode
            let fmt = input.outputFormat(forBus: 0)
            var peak: Float = 0
            var frames = 0
            input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { buf, _ in
                guard let ch = buf.floatChannelData?[0] else { return }
                for i in 0..<Int(buf.frameLength) { peak = max(peak, abs(ch[i])) }
                frames += Int(buf.frameLength)
            }
            do {
                try engine.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    input.removeTap(onBus: 0)
                    engine.stop()
                    let db = peak > 0 ? 20 * log10(peak) : -999
                    let ok = frames > 0 && peak > 0
                    self.verdict("TEST Microphone \(ok ? "PASS" : "FAIL") - frames=\(frames) peak=\(String(format: "%.1f", db)) dBFS (all-zero samples = no access)")
                }
            } catch {
                verdict("TEST Microphone FAIL - engine did not start: \(error.localizedDescription)")
            }
        case .input:
            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            // The callback passes every event straight through and looks at nothing.
            let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .listenOnly, eventsOfInterest: mask,
                                        callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
                                        userInfo: nil)
            if let tap {
                CFMachPortInvalidate(tap)
                verdict("TEST ListenEvent PASS - listen-only tap created (and destroyed at once)")
            } else {
                verdict("TEST ListenEvent FAIL - tapCreate returned nil")
            }
        }
    }

    // MARK: reset - the claim under test in sprecorder-mac-0025

    func reset(_ g: Grant) {
        log("RESET \(g.rawValue) - before: \(snapshot())")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        p.arguments = ["reset", g.rawValue, bundleID]   // scoped to THIS app, never unscoped
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
            p.waitUntilExit()
            let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            verdict("RESET \(g.rawValue) exit=\(p.terminationStatus) stdout=\(o.trimmingCharacters(in: .whitespacesAndNewlines)) stderr=\(e.trimmingCharacters(in: .whitespacesAndNewlines))")
        } catch {
            verdict("RESET \(g.rawValue) could not launch tccutil: \(error.localizedDescription)")
        }
        log("RESET \(g.rawValue) - after: \(snapshot())")
    }

    // MARK: chime - the claim under test in sprecorder-mac-0023

    func outputConditions() -> String {
        var dev = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        var name: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        addr.mSelector = kAudioObjectPropertyName
        _ = withUnsafeMutablePointer(to: &name) { AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, $0) }
        // Volume and mute as the user sees them, via the standard scripting addition.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "get volume settings"]
        let out = Pipe()
        p.standardOutput = out
        var settings = "?"
        if (try? p.run()) != nil {
            p.waitUntilExit()
            settings = (String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "?")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "output device=\"\(name)\" | \(settings)"
    }

    func chimeTest() {
        log("CHIME start - \(outputConditions())")
        lock.lock(); samples = []; chimeStartIndex = nil; lock.unlock()
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { verdict("CHIME FAIL - no display"); return }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let cfg = SCStreamConfiguration()
                cfg.capturesAudio = true
                cfg.excludesCurrentProcessAudio = false   // the check NEEDS its own sound
                cfg.sampleRate = 48_000
                cfg.channelCount = 2
                cfg.width = 16
                cfg.height = 16
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 2)
                let s = SCStream(filter: filter, configuration: cfg, delegate: self)
                try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
                try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: audioQueue)
                try await s.startCapture()
                self.stream = s
                log("CHIME capture started (ScreenCaptureKit, capturesAudio, excludesCurrentProcessAudio=false)")
                try await Task.sleep(nanoseconds: 1_200_000_000)            // baseline
                await MainActor.run { self.playChime() }
                try await Task.sleep(nanoseconds: 2_000_000_000)            // chime + tail
                try await s.stopCapture()
                self.stream = nil
                self.analyse()
            } catch {
                verdict("CHIME FAIL - \(error.localizedDescription)")
            }
        }
    }

    func playChime() {
        let sr = 48_000.0
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        let toneLen = Int(sr * 0.35)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(toneLen * 2))!
        buf.frameLength = buf.frameCapacity
        let d = buf.floatChannelData![0]
        let fade = Int(sr * 0.01)
        for i in 0..<(toneLen * 2) {
            let f = i < toneLen ? 880.0 : 1320.0
            let j = i % toneLen
            let env = Float(min(1.0, Double(min(j, toneLen - j)) / Double(fade)))
            d[i] = 0.3 * env * Float(sin(2 * Double.pi * f * Double(i) / sr))
        }
        do {
            try engine.start()
            chimeEngine = engine
            lock.lock(); chimeStartIndex = samples.count; lock.unlock()
            player.scheduleBuffer(buf, at: nil, options: []) { }
            player.play()
            log("CHIME played 880 Hz + 1320 Hz, 0.7 s, amplitude 0.3 (sample index \(chimeStartIndex ?? -1))")
        } catch {
            log("CHIME could not play: \(error.localizedDescription)")
        }
    }

    // Tone amplitude at one frequency (Goertzel), as a fraction of full scale.
    func toneAmp(_ x: ArraySlice<Float>, _ freq: Double) -> Double {
        let n = x.count
        guard n > 0 else { return 0 }
        let k = (Double(n) * freq / sampleRate).rounded()
        let w = 2 * Double.pi * k / Double(n)
        let c = 2 * cos(w)
        var s1 = 0.0, s2 = 0.0
        for v in x { let s0 = Double(v) + c * s1 - s2; s2 = s1; s1 = s0 }
        let power = s1 * s1 + s2 * s2 - c * s1 * s2
        return 2 * sqrt(max(power, 0)) / Double(n)
    }

    func analyse() {
        lock.lock(); let x = samples; let start = chimeStartIndex; lock.unlock()
        let sr = Int(sampleRate)
        guard let start, x.count > start + sr / 2, start > sr / 4 else {
            verdict("CHIME FAIL - not enough audio captured (samples=\(x.count), chimeStart=\(String(describing: start)))")
            return
        }
        let block = 4096
        func maxAmp(_ lo: Int, _ hi: Int, _ f: Double) -> Double {
            var best = 0.0
            var i = lo
            while i + block <= hi { best = max(best, toneAmp(x[i..<(i + block)], f)); i += block / 2 }
            return best
        }
        func rmsDB(_ lo: Int, _ hi: Int) -> Double {
            guard hi > lo else { return -999 }
            var acc = 0.0
            for i in lo..<hi { acc += Double(x[i] * x[i]) }
            let r = sqrt(acc / Double(hi - lo))
            return r > 0 ? 20 * log10(r) : -999
        }
        let hi = min(x.count, start + Int(1.5 * Double(sr)))
        let base880 = maxAmp(0, start, 880), base1320 = maxAmp(0, start, 1320)
        let ch880 = maxAmp(start, hi, 880), ch1320 = maxAmp(start, hi, 1320)
        let floor = 0.001   // -60 dBFS
        let found = ch880 > max(8 * base880, floor) && ch1320 > max(8 * base1320, floor)
        log(String(format: "CHIME numbers - samples=%d sr=%.0f | baseline rms %.1f dBFS, 880=%.5f 1320=%.5f | chime window rms %.1f dBFS, 880=%.5f 1320=%.5f",
                   x.count, sampleRate, rmsDB(0, start), base880, base1320, rmsDB(start, hi), ch880, ch1320))
        verdict("CHIME \(found ? "FOUND" : "NOT FOUND") - \(outputConditions())")
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sb.isValid else { return }
        if let fd = sb.formatDescription, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee {
            sampleRate = asbd.mSampleRate
        }
        try? sb.withAudioBufferList { abl, _ in
            guard let first = abl.first, let data = first.mData else { return }
            let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            let ptr = data.bindMemory(to: Float.self, capacity: count)
            // Take channel 0 only. Non-interleaved: the first buffer IS channel 0.
            // Interleaved: step over the other channels, or the tone reads at the wrong pitch.
            let step = max(1, Int(first.mNumberChannels))
            if !loggedFormat {
                loggedFormat = true
                log("CHIME audio format - buffers=\(abl.count) channelsInFirst=\(first.mNumberChannels) sampleRate=\(sampleRate)")
            }
            lock.lock()
            for i in stride(from: 0, to: count, by: step) { samples.append(ptr[i]) }
            lock.unlock()
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log("CHIME stream stopped with error: \(error.localizedDescription)")
    }

    // MARK: menu helper

    final class ClosureItem: NSMenuItem {
        var run: () -> Void = {}
        @objc func fire() { run() }
    }

    func action(_ title: String, _ run: @escaping () -> Void) -> NSMenuItem {
        let i = ClosureItem(title: title, action: #selector(ClosureItem.fire), keyEquivalent: "")
        i.target = i
        i.run = run
        return i
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let probe = Probe()
app.delegate = probe
app.run()
