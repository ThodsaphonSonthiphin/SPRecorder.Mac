# Plan 1 — first demo results

Task 11 of `2026-09-10-plan-1-foundation-and-first-demo.md`, run on the development Mac with the
developer at the keyboard. Each measurement is written down when it is taken.

**Mac:** macOS 26.6.2 (25G83), MacBook Air, arm64. **App:** `SPRecorder.app` (`com.sprecorder.mac`),
Debug build of branch `plan-1-foundation`, ad-hoc signed, run from `~/Applications`.

## Pass conditions (fixed in the plan before the run)

| # | Condition | Result | Measured |
|---|---|---|---|
| 1 | ⌃⌥R start/stop leaves one `yyyy-MM-dd EEE HH.mm` folder | **PASS** | `2026-09-11 Fri 08.58` for the 08:58:55 start |
| 2 | Exactly the two files, each `aac`, 1 ch | **PASS** | `Computer audio.m4a` and `My microphone.m4a`, both `1 ch, 48000 Hz, aac` |
| 3 | Decodable length within 2 s of the session | **PASS** | 53.58 s and 53.57 s for a 0:00:54 session |
| 4 | Computer audio has the video; My microphone has the voice | **PASS**, *reported by the operator* | no operator voice on Computer audio; voice on My microphone (plus the video through the speakers) |
| 5 | Diary started/stopped and both track-finished lines with `0 dropped`, no `completely silent` | **PASS** | 2679 and 5022 buffers, 0 dropped, no silent warning |
| 6 | `kill -9` after about 30 s leaves ≥ 26 s decodable | **PASS** | killed at 87.8 s, both 85.97 s decodable (1.8 s lost) |

**Track formats (research #3):** System track 48000 Hz, 1 channel. Mic track 48000 Hz, 1 channel on the built-in microphone;
16000 Hz, 1 channel on WF-1000XM5 earbuds, written at 48 kbps.

**Hotkey status code (research #5):** no refusal. The second copy's `RegisterEventHotKey` succeeded (logged `registered`) while
the first copy held ⌃⌥R, so `-9878` was not observed. The plan's stop-and-report condition: see Step 11 and Step 12.

**Permission prompts:** one Microphone box (first start, 07:33:25). No Screen & System Audio Recording box: tccd refused
without prompting. No Movies-folder box. Allowing the microphone after Don't Allow took effect only after reopening SPRecorder.

## Baseline — 2026-09-11 07:30 +0700, before the app first ran

- `~/Movies/SPRecorder`, `~/Library/Logs/SPRecorder`, `~/Library/Application Support/SPRecorder`: **none exist**.
- `~/Applications/SPRecorder.app`: does not exist. No `SPRecorder` process running.
- Unified log, last day, TCC events for `com.sprecorder.mac`: none for this bundle id (the only matches were
  `com.sprecorder.mac.notepanelprobe`, a probe from another session).
- Default input: **MacBook Air Microphone**. Default output: **MacBook Air Speakers**.
- Blast radius: no Session folder exists before the demo, so every Session folder afterwards is the demo's own.

## Measurements

### Step 3 — first launch, 07:31:25 (measured)

- Built, copied to `~/Applications/SPRecorder.app`; `codesign -dv`: `Identifier=com.sprecorder.mac`, `Signature=adhoc`.
- One process running (pid 78308).
- `settings.json` created with **26 keys**, including `"Hotkey" : "Control+Option+R"`, `"AudioBitrateKbps" : 64`,
  `"OutputDirectory" : "~/Movies/SPRecorder"`, `"FileNamePattern" : "{timestamp:yyyy-MM-dd EEE HH.mm}"`.
- Diary `2026-09-11.log`, first three lines:
  `[notice] App: SPRecorder 0.1 (1) started on Version 26.6.2 (Build 25G83)`,
  `[notice] Settings: No settings file; created …/settings.json with the defaults`,
  `[notice] Hotkey: Start/stop hotkey ⌃⌥R registered`.

### Step 4 — microphone refused on purpose, 07:33 (measured)

- tccd `AUTHREQ_PROMPTING service=kTCCServiceMicrophone subject=com.sprecorder.mac` at 07:33:25 — the Microphone box appeared.
- Operator pressed Don't Allow. Diary at 07:33:38: `[error] Permissions: Microphone access is refused`, then
  `[error] RecordingSession: Recording Session could not start (2026-09-11 Fri 07.33): SPRecorder is not allowed to use the microphone.`
- A second start at 07:33:40 was refused the same way with no box (the refusal is remembered).
- `~/Movies/SPRecorder` now exists and is **empty**: the Session folder created at start was removed on refusal.
- No screen-capture request was made: the microphone gate refuses first.

### Step 5 — microphone switched on in System Settings, 07:35 (measured)

- tccd: `TCCDEvent type=Create service=kTCCServiceMicrophone identifier=com.sprecorder.mac` at 07:33:38 (the Don't Allow),
  then `type=Modify` at 07:35:12 (the switch turned on).
- `pgrep -x SPRecorder`: still pid 78308 — the app was **not** reopened.

### Step 6 — start again after the switch, same process (measured) — refused

- Operator pressed Start at 07:36:09 and 07:36:23 (pid 78308, not reopened). Both refused:
  `[error] Permissions: Microphone access is refused` / `Recording Session could not start (… 07.36): SPRecorder is not allowed to use the microphone.`
- To the operator **nothing appeared to happen**: the refusal is shown only as a grey row inside the menu.
- tccd log: **no request from pid 78308** at either press (compare 07:33:25, where its Microphone request is logged and prompted).
  `AVCaptureDevice.requestAccess(for: .audio)` answered from the process's own remembered refusal, not from TCC.
- The two WindowServer checks for `com.sprecorder.mac` at 07:33:39 and 07:36:08 are `kTCCServiceListenEvent preflight=yes` — unrelated.
- `TCC.db` cannot be read (authorization denied), so the switch's stored value is not directly measurable.
- Next: fresh process test. Restarted at 07:39:42 (SIGTERM while idle, then `open`; new pid 78998). Diary shows start and
  `⌃⌥R registered`; no `SPRecorder quit` line, because SIGTERM skips `applicationWillTerminate`.

### Step 7 — the fresh process, 07:40 (measured) — root cause of Step 6 confirmed

- Operator pressed Start once in pid 78998 at 07:40:21.
- tccd: `AUTHREQ_CTX msgID=78998.2 service=kTCCServiceMicrophone preflight=no` → `AUTHREQ_RESULT authValue=2 authReason=4`
  — **macOS allowed the microphone**, and the new process actually asked.
- The session got past the microphone and stopped at computer audio:
  `ScreenCaptureKit would not list displays: The user declined TCCs … (com.apple.ScreenCaptureKit.SCStreamErrorDomain -3801)` →
  `Recording Session could not start (2026-09-11 Fri 07.40): SPRecorder is not allowed to record computer audio.`
  tccd for ScreenCapture: `Notifying for access … does not allow prompting; returning denied.` (no Allow box, as measured in #33).
- `~/Movies/SPRecorder` still empty (folder removed on refusal).
- 07:40:44 tccd `Modify kTCCServiceScreenCapture com.sprecorder.mac` (the Screen & System Audio switch turned on);
  07:40:46 Diary `SPRecorder quit` (a graceful quit — the reopen offer); 07:40:49 started again as pid 79117.
- At launch the app's own `kTCCServiceListenEvent preflight=yes` check returns `authValue=1` with no prompt (07:39:42, 07:40:49) —
  it coincides with registering the Carbon hotkey; Input Monitoring is never asked for.

**Root cause (Step 6):** after Don't Allow, `AVCaptureDevice.requestAccess(for: .audio)` keeps returning the refusal **inside the
running process** and does not ask tccd again; turning the switch on is not seen until SPRecorder is started again. A fresh
process asks and is allowed. Every breadcrumb agrees: the refused presses at 07:33:40, 07:36:09 and 07:36:23 made no tccd request;
the fresh press at 07:40:21 did and got `authValue=2`. Ruled out: the switch in the wrong list or turned back off
(the fresh result is allowed), and the "Don't Allow overrides the switch" stuck state (the fresh process passed).
This is the risk recorded against Task 9 (the ledger's requestAccess-gate ruling), now measured.

### An unplanned 6-second session, 07:41 (measured, found at 09:00)

- Started 07:41:10 in pid 79117, 21 s after the reopen, before Step 8 was given; stopped after 0:00:06.
- tccd 07:41:09: `msgID=79117.2 kTCCServiceMicrophone` → `authValue=2`; ScreenCaptureKit passed. Both permissions were in place.
- Session folder `2026-09-11 Fri 07.41` kept, with `Computer audio.m4a` (4282 bytes, 1 ch 48000 Hz aac, 5.86 s decodable, 1.5 kbps)
  and `My microphone.m4a` (52242 bytes, 1 ch 48000 Hz aac, 5.76 s decodable).
- Diary: `SystemTrack: Capture started on display 1, AAC 64 kbps`; `System track finished: … 293 buffers, 0 dropped`;
  `[warning] SystemTrack: System track is completely silent; if this is the Mic track, the microphone may not be allowed`;
  `Mic track finished: … 540 buffers, 0 dropped`.
- This answers the carried check **start with nothing playing**: the session records, the System track is kept (silent),
  and the Diary warns. The warning's second clause names the Mic track while it is reporting the System track: a wording defect.

### Step 8 — 54-second recording, 08:58 (measured)

- Diary: started 08:58:55.486 (`Capture started on display 1, AAC 64 kbps`), stopped 08:59:49.098, `stopped after 0:00:54`.
- Session folder `2026-09-11 Fri 08.58`: the `yyyy-MM-dd EEE HH.mm` shape.
- `Computer audio.m4a`: 283836 bytes, `1 ch, 48000 Hz, aac`, 53.58 s decodable, 39 kbps; `2679 buffers, 0 dropped`.
- `My microphone.m4a`: 462427 bytes, `1 ch, 48000 Hz, aac`, 53.57 s decodable, 65 kbps; `5022 buffers, 0 dropped`.
- Both tracks within 0.5 s of the session length (target: within 2 s). No `completely silent` warning.
- tccd 08:58:55: no Microphone request from pid 79117 — the running process answered from its remembered (now allowed) result;
  ScreenCaptureKit's own ScreenCapture checks passed.
- Whether it was started with the hotkey, and whether the ring turned red: not recorded by the Diary; owed by the operator.

### Step 9 — listening to the 08:58 files (reported by the operator, not independently measured)

- `Computer audio.m4a`: the operator's voice is **not** on it — the System track carries computer audio only, as intended.
- `My microphone.m4a`: the operator's voice **and** the video's sound are on it. The operator's reading: the microphone
  hears everything in the room. The output was the MacBook Air Speakers (baseline), so the built-in microphone picks up the
  video acoustically; the app applies no echo removal. Expected with speakers, not a capture fault. Consequence for the plan
  that builds the Mixed file: with speakers, the other participants are on both tracks, a few milliseconds apart.
  Not measured: the same recording with headphones.
- No clicks, gaps or robotic sound in either file.
- Started and stopped with the hotkey ⌃⌥R; the ring turned solid red while recording (light/dark menu bar not yet checked).

### Step 10 — killed mid-recording, 09:08 (measured)

- Started with ⌃⌥R at 09:06:33.240 (Diary `Recording Session started: …/2026-09-11 Fri 09.06`), pid 79117.
- The operator said "done" later than 35 s; `kill -9 79117` at 09:08:01.012, **87.8 s** into the session. 2 s later no SPRecorder process.
- `Computer audio.m4a`: 725907 bytes, `1 ch, 48000 Hz, aac`, **85.97 s decodable**.
- `My microphone.m4a`: 729156 bytes, `1 ch, 48000 Hz, aac`, **85.97 s decodable**.
- Lost at the end: 1.8 s of 87.8 s on each track — inside the 2-second pieces (`sprecorder-mac-0034`). The plan's floor was
  26 s of a 30 s session; the same loss bound holds here.
- Diary ends at `Mic track audio: 48000 Hz, 1 channel(s)`: no stop or track-finished lines, as expected for `kill -9`
  (Plan 2 finishes such a session at next launch).

### Step 11 — a second copy and the hotkey, 09:08 (measured) — the refusal did NOT happen

- `open ~/Applications/SPRecorder.app` → pid 81996, Diary 09:08:23.549 `Hotkey: Start/stop hotkey ⌃⌥R registered`.
- 3 s later `open -n …` → pid 82004, Diary 09:08:26.613 `Hotkey: Start/stop hotkey ⌃⌥R registered`.
- Both processes running at 09:08:29. **No status code**: `RegisterEventHotKey` returned success in the second process
  while the first held the same ⌃⌥R. Research #5 expected `-9878` (`eventHotKeyExistsErr`); on macOS 26.6.2 a combination
  held by another process is not refused. The plan's stop-and-report condition: the Inactive hotkey
  (`sprecorder-mac-0010` menu row, `sprecorder-mac-0017` check line) cannot be detected from this return value.

### Step 12 — ⌃⌥R with two copies running, 09:09–09:10 (measured; operator's report for the rings)

Operator: two rings; the first press made one ring record; the next press turned that ring off and the other ring recorded.

Unified log (`subsystem == "com.sprecorder.mac"`, messages private, so only process id, level, category and time are readable)
plus the Diary fragments and the Session folders give five moments:

| Time | pid 81996 | pid 82004 | Session folder |
|---|---|---|---|
| 09:09:54.7 | RecordingSession **error**: `Could not create a Session folder … “2026-09-11 Fri 09.09” couldn’t be saved` | starts recording | `09.09` (82004's) |
| 09:10:10.1 | starts recording | stops | `09.10` (81996's) |
| 09:10:13.7 | stops (silent System track warning) | starts recording | `09.10 (2)` |
| 09:10:14.5 | starts recording | stops | `09.10 (3)` |
| 09:10:17.6 | stops, `stopped after 0:00:03 … 09.10 (3)` | nothing logged | — |

- **Each press reaches both copies.** The idle copy starts and the recording copy stops, so the two take turns; one press never
  stops both. All stops are normal stops (RecordingSession at default level, no `stopped by itself` error).
- At the first press both copies were idle and both started: they picked the same Session folder name at the same moment,
  one created it and the other's create failed. The failure was shown only inside that copy's menu.
- The 09:10:17.6 moment reached 81996 only. Unexplained so far (a menu Stop on that ring would explain it); asked of the operator.
- **Two copies corrupt the Diary.** Each copy opens `2026-09-11.log`, seeks to the end once, and keeps writing at its own
  offset, so each overwrites the other: line 40 is cut mid-message, line 47 holds three run-together fragments, and 82004's
  `started` and `registered` lines from 09:08:26 are gone (the file has 54 lines; the 09:08:26 lines read at 09:08:29 no longer exist).
- No ADR decides whether a second copy may run. Both copies were idle when read at 09:11:14.

### Step 13 — both copies quit from their menus, 09:14 (measured)

- Unified log: `App` notice from pid 82004 at 09:14:38.672 and from pid 81996 at 09:14:44.189; Diary has two `App: SPRecorder quit`
  lines. At 09:14:56 `pgrep -x SPRecorder` finds nothing.
- The Diary was overwritten once more: 82004's quit line landed inside 81996's `Recording Session stopped` line (line 55).
- The menu question for the 09:10:17.6 moment was not answered; it stays unexplained.

### Step 14 — Quit from the menu while recording, 09:20 (measured)

- One copy (pid 82665, started 09:15:24). Mac appearance: Light (`AppleInterfaceStyle` not set) — so the Step 8 red ring was seen on a light menu bar.
- Started with ⌃⌥R 09:19:26.098 (`2026-09-11 Fri 09.19`). Quit at 09:20:15.045: `App: Quit during a Recording Session; finishing it first`,
  both `track finished … 0 dropped` at .084/.088, `Recording Session stopped after 0:00:49` at .089, `App: SPRecorder quit` at .094.
  From Quit to exit: 49 ms. At 09:20:28 no SPRecorder process.
- `Computer audio.m4a` 48.98 s and `My microphone.m4a` 48.94 s decodable, both `1 ch, 48000 Hz, aac` — finished files, not crash pieces.
- **Quit while "Stopping…" is not reachable by hand**: from Quit to `Recording Session stopped` took 44 ms. Left to the
  Task 10 review's fix, not measured.
- Whether a box asked anything, and whether the ring disappeared by itself: not answered by the operator; the process exit is measured.

### Step 15 — Bluetooth earbuds' microphone, 09:23 (measured)

- Reopened 09:21:12 (pid 82999). At 09:24:18 `system_profiler SPAudioDataType`: default output **WF-1000XM5** (Bluetooth, 16000 Hz);
  default input a Bluetooth device, 1 input channel, 16000 Hz (the WF-1000XM5 in its headset mode).
- Diary: `System track audio: 48000 Hz, 1 channel(s)`; `Capture started … AAC 64 kbps`;
  `Mic track audio: 16000 Hz, 1 channel(s)`; **`Mic track: 64 kbps is not offered at this sample rate; using 48 kbps`**;
  both `finished … 3061 buffers, 0 dropped`; `stopped after 0:01:01`.
- `Computer audio.m4a`: `1 ch, 48000 Hz, aac`, 61.22 s decodable. `My microphone.m4a`: `1 ch, 16000 Hz, aac`, 61.22 s decodable, 40 kbps.
- This is the case that failed `startWriting` with -11861 before the Task 9 fix: the fix picks 48 kbps and the Mic track records.
- Listening (reported by the operator, not independently measured): `My microphone.m4a` has **only the operator's voice, clear**;
  no video sound. With the meeting in the earbuds, the Mic track carries no second copy of the other participants — the
  speaker pickup seen in Step 9 does not happen with earbuds.

### Step 17 — the ring on a dark menu bar, 09:27–09:28 (measured timeline; what the ring looked like is owed by the operator)

- `chronod`: `AppleInterfaceStyle` changed at 09:27:29 (Dark), 09:27:47 (nil = Light), 09:28:01 (Dark), 09:28:06 (Light).
  At 09:28:35 `defaults read -g AppleInterfaceStyle` does not exist: **the Mac is back on Light**.
- Sessions: `09.27` 09:27:40.794 → 09:28:03.921 (0:00:23; Dark for its first 7 s) and `09.28` 09:28:08.840 → 09:28:24.922
  (0:00:16; Light throughout). Both with the earbuds still the input (16000 Hz, 48 kbps), both `0 dropped`, both with the
  System track `completely silent` warning (no video playing).
- So the red ring was on a Dark bar from 09:27:40 to 09:27:47, and the hollow ring from 09:28:03.9 to 09:28:06.

### Blast radius, 09:15 (measured)

- `~/Movies/SPRecorder` holds 7 Session folders, every one made during the demo (baseline: the folder did not exist):
  `07.41` (unplanned session), `08.58` (Step 8), `09.06` (Step 10, killed), `09.09`, `09.10`, `09.10 (2)`, `09.10 (3)` (Step 12).
  Plus a Finder `.DS_Store` from 09:01, when the files were played. Later steps added `09.19` (Step 14), `09.23` (Step 15),
  `09.27` and `09.28` (Step 17): 11 Session folders in all, each one accounted for.
- `settings.json` unchanged since its creation at 07:31:25. The Diary folder holds only `2026-09-11.log`.
- `~/Movies` neighbours `CapCut` (Sep 4) and `TV` (Sep 5) unchanged.

### Movies folder (measured across the whole demo, 07:29–09:00)

- tccd events containing `MoviesFolder`: **0**. No Movies-folder box was asked for while creating and writing Session folders
  under `~/Movies/SPRecorder`.
