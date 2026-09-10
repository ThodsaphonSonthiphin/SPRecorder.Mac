# Setup-check probe

A throwaway menu-bar app for the decision-map ticket `check-my-setup-probe` (#33). It
measures the two unmeasured claims under Check my setup: whether the app can reset its
own stuck permission from inside itself (`sprecorder-mac-0025`), and whether
computer-audio capture hears a chime the app plays, including when the output is muted
or on headphones (`sprecorder-mac-0023`). Same method as `tools/tcc-probe`; read its
README for the TCC traps.

It never records or logs a keystroke: the Input Monitoring test only checks that a
listen-only event tap can be created, and destroys it immediately.

## Build and run

```sh
swiftc -O -swift-version 5 probe.swift -o SetupCheckProbe
mkdir -p SetupCheckProbe.app/Contents/MacOS
cp SetupCheckProbe SetupCheckProbe.app/Contents/MacOS/
# Contents/Info.plist: CFBundleIdentifier com.sprecorder.setupcheckprobe,
# CFBundleExecutable SetupCheckProbe, CFBundlePackageType APPL, LSUIElement true,
# NSMicrophoneUsageDescription (any text - the mic test crashes without it)
codesign -s - --force --timestamp=none SetupCheckProbe.app
cp -R SetupCheckProbe.app ~/Applications/     # NOT /tmp - it never registers there
open ~/Applications/SetupCheckProbe.app
tail -f /tmp/setup-check-probe.log
```

Reset between runs, **always scoped to the bundle id** — never unscoped:

```sh
tccutil reset ScreenCapture com.sprecorder.setupcheckprobe
tccutil reset Microphone    com.sprecorder.setupcheckprobe
tccutil reset ListenEvent   com.sprecorder.setupcheckprobe
```

## The click-through (the human half)

Repeat for each permission — *Screen & System Audio*, then *Microphone*, then *Input
Monitoring* — from the **Probe** menu in the menu bar:

1. **1. Ask for permission** → press the macOS box's "no" button. Note the button names.
2. System Settings → Privacy & Security → that permission's list. If the probe is not
   listed, add it with **+** from `~/Applications`. Turn its switch **on**. If offered
   *Quit & Reopen*, press **Later**.
3. **2. Test it now** — the trap reproduces if this FAILs.
4. **3. Reset my own entry (from inside the app)** — note whether a password box appears.
5. **1. Ask for permission** again — note whether a box appears, and grant it.
6. **2. Test it now** — PASS here, with no relaunch, is the `sprecorder-mac-0025` pass.

Then the chime, three times: **Chime test** with speakers at normal volume; again with
the output **muted**; again with **headphones** as the output. The log records the
output device, volume and mute state itself, and says FOUND or NOT FOUND.

## Traps found running it, 2026-09-10

- **Turning a switch on offers to reopen the app. Press Later.** The reopen button quits the
  probe, and every "no relaunch needed" measurement after it is void. It was pressed 6 times in 8.
- **Open the lists by link, never by search.** Search led to *Voice Control* and then to the
  *System Audio Recording Only* list, which looks like the right place and is not:
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`,
  `…?Privacy_ScreenCapture`, `…?Privacy_ListenEvent`.
- **"No box" is often correct.** Screen and Input Monitoring never show an Allow button, only a
  notification pointing at System Settings. After a reset, a running process's own requests are
  answered from a stale cache: Microphone re-asks only when it *records*; Input Monitoring cannot
  re-ask at all until the probe is restarted — and its reset removes the probe from the list.
- **The snapshot line is a hint, not a verdict.** All three permission-reading calls kept stale
  values after a reset. Trust *Test it now*.
- **Watch tccd, not the probe, to see what macOS did:**
  `log show --last 10m --style compact --predicate 'subsystem == "com.apple.TCC" AND (eventMessage CONTAINS "setupcheckprobe" OR eventMessage CONTAINS "Notifying for access")'`
  — in zsh call it as `/usr/bin/log`, since `log` is a shell builtin there.
- When done: `tccutil reset All com.sprecorder.setupcheckprobe` and delete the app.
