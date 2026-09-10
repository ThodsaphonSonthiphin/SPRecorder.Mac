import Foundation
import CoreGraphics
import ScreenCaptureKit

let logPath = ProcessInfo.processInfo.environment["PROBE_LOG"] ?? "/tmp/tcc-probe.log"

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

log("=== PROBE START — pid \(getpid()) ===")
log("STEP 1  preflight at launch = \(CGPreflightScreenCaptureAccess())")

// This is the call that shows the system prompt.
let requested = CGRequestScreenCaptureAccess()
log("STEP 2  CGRequestScreenCaptureAccess() returned \(requested)")
log("STEP 3  now polling. Toggle the permission ON in System Settings.")
log("        The question: does capture start WITHOUT quitting this app?")

var attempt = 0
let deadline = Date().addingTimeInterval(3600)

func poll() {
    attempt += 1
    let pre = CGPreflightScreenCaptureAccess()
    Task {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            log("attempt \(attempt): preflight=\(pre)  SCShareableContent OK — \(content.displays.count) display(s)")
            log("VERDICT: CAPTURE WORKS IN THE SAME PROCESS — NO RELAUNCH REQUIRED")
            log("=== PROBE END ===")
            exit(0)
        } catch {
            log("attempt \(attempt): preflight=\(pre)  SCShareableContent FAILED — \(error)")
            if Date() > deadline {
                log("VERDICT: TIMED OUT after \(attempt) attempts — capture never started in this process")
                log("=== PROBE END ===")
                exit(2)
            }
        }
    }
}

Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in poll() }
poll()
RunLoop.main.run()
