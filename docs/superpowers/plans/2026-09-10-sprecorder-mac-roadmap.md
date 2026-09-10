# SPRecorder.Mac — Build Roadmap

The Decision map (`docs/decision-map/sprecorder-macos-port`, GitHub issue #1) has no open
tickets. This roadmap turns its 41 ADRs (`docs/adr/sprecorder-mac-0001` … `0041`) into build
plans. Agreed with the user on 2026-09-10: **one plan per subsystem**, each ending in working,
testable software; **Plan 1 is written in full first**, Plans 2–9 are written when reached, on
top of the code that exists by then. Remaining fog on the map is settled during the build.

**Destination (from the map):** full parity with what the Windows SPRecorder runs today, on two
Macs (the developer's and his wife's), with logs good enough to diagnose a problem she reports.

## The plans, in build order

Plan 1 is written: `2026-09-10-plan-1-foundation-and-first-demo.md`.

| # | plan | what works at the end | implements |
|---|---|---|---|
| 1 | **Foundation + first demo** | Xcode project (Core framework, App, Core tests), forbidden-import guard, tests on GitHub, settings JSON, diary logging seam, Session folder naming; a Carbon hotkey starts/stops a Recording Session that writes `My microphone.m4a` and `Computer audio.m4a` into its folder; minimal menu-bar icon | 0001, 0002, 0003 (partial), 0004, 0005, 0007, 0009, 0013, 0014, 0015, 0016, 0019; research #3 system audio, #5 hotkey, #6 AAC |
| 2 | **Recording that survives** | `Both voices.m4a` (Mixed file) after stop; 2-second pieces on every live writer; the app's own interrupted-session note; finish an interrupted session at next launch and announce it; long recordings cut after stop, uncut Mixed file kept when there are Markers | 0026, 0027, 0034, 0035, 0036, 0038 |
| 3 | **Markers** | marker hotkeys, the non-activating note panel, Marker log (flushed on press), Marker review page, the tick and failure notice over a full-screen meeting | 0012, 0020; Windows ADRs 0009/0010/0012/0014 via 0039 |
| 4 | **Screen recording** | built-in screen as a Self-contained MP4 with two audio tracks behind the macOS-27 seam; Mouse highlight and Key caster overlay kept in capture, notices kept out; the keystroke leak test | 0018, 0021; research #4 screen stack, #7 input overlay |
| 5 | **Call detection** | `CallDetectionStateMachine` translated; CoreAudio process-object signal; auto-record on call start; call-end notification with Stop / Keep going | 0003; research #8 call detection; 0012 notifications |
| 6 | **Menu bar + Settings** | the 12-row menu and three icon states; the seven-tab Settings scene (General, Audio, Mixed file, Splitting, Screen, Markers, Permissions); hotkey capture; Named session prompt; permissions asked lazily per feature; Inactive hotkey | 0006, 0010, 0011, 0022, 0033 (menu row) |
| 7 | **Check my setup** | the real two-second check with chime and voice, split on failure, plain-names report, never a Recording Session; no Reset permission button | 0017, 0023, 0028, 0031, 0032, 0041; probe results in 0025/0023 amendments |
| 8 | **Problem report** | contents window, private copy (typed text marked where written), share list, `Problem reports` folder, *What went wrong?* picker | 0024, 0029, 0030, 0033 |
| 9 | **Getting it onto her Mac** | one self-signed certificate, updates over home file sharing, the first-update permission probe | 0040 (supersedes 0008's signing) |

Not built: HDR detection and warning (dropped by research #9); Google Drive upload (fog);
public install/update (fog, returned 2026-09-10); external monitors (deferred, 0021).

## Inputs Plan 1 must be written from — read these, not memory

**ADRs:** 0001, 0002 (+ correction), 0003 (+ amendment), 0004, 0005, 0006, 0007, 0009, 0013,
0014, 0015, 0016, 0018 (injected log directory), 0019 (+ correction), 0034 and 0038 (the
writer must set `movieFragmentInterval` from the start, so Plan 2 does not rework it).

**Research resolutions on GitHub** (`gh issue view <n> --repo ThodsaphonSonthiphin/SPRecorder.Mac --comments`):
#3 system audio (ScreenCaptureKit `capturesAudio` + `captureMicrophone`), #4 screen stack
(two audio tracks via `AVAssetWriter` on 26.x), #5 global hotkey (Carbon
`RegisterEventHotKey`), #6 audio encoding (AAC `.m4a` via AVFoundation), #11 pure-logic reuse.

**Measured working code:** `tools/crash-safety-probe/` (AVAssetWriter AAC settings with
`movieFragmentInterval`), `tools/aac-split-probe/`, `tools/tcc-probe/`,
`tools/setup-check-probe/` (ScreenCaptureKit audio stream configuration that captured audio).

**Windows source** (`/Users/liusp/Documents/repo/SPRecorder`, frozen, read only):
`src/SPRecorder/Configuration/AppConfig.cs` (the 27 settings and `Load` validation),
`Settings/AppConfigStore.cs`, `Recording/FileNameBuilder.cs`, `Recording/RecordingSession.cs`,
`Hotkey/GlobalHotkey.cs`, `Hotkey/HotkeyStatus.cs`, `Hotkey/HotkeyValidation.cs`,
`Tray/TrayApp.cs` (start/stop flow), and the matching tests in `tests/SPRecorder.Tests/`.

**Facts already verified on this Mac (2026-09-10):** macOS 26.6.2 arm64; Xcode 26.6;
Swift 6.3.3; no code-signing identity; GitHub `macos-26` runner default Xcode 26.6.
**Unverified, to confirm in Plan 1:** `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS'`.

## Execution

Each plan is executed with `sp-subagent-driven-development` (recommended) or
`sp-executing-plans`. Parallel Claude sessions share this working tree: stage explicit paths
only, and re-check ADR numbers before writing one.
