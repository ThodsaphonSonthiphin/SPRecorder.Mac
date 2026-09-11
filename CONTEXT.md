# SPRecorder.Mac

A macOS menu-bar app that records a meeting as two separate audio tracks and a
combined file, and optionally the screen, so the conversation can be handed to an
AI summarizer such as NotebookLM. It started from the Windows SPRecorder glossary
and differs from it wherever the Mac app differs. This file, not the Windows one,
is the vocabulary for this repo.

## Recording

**Recording Session**:
One start-to-stop capture, identified by the time it started. Produces a System
track, a Mic track, a Mixed file and, optionally, a Screen recording.
_Avoid_: recording job, capture run, meeting (when you mean the capture)

**Session folder**:
The folder every Recording Session gets, named for the date and time it started.
All of that session's tracks, parts and Marker files live inside it.
_Avoid_: output folder, recording directory

**Named session**:
A Recording Session the user has given a short label. The label is added to the
Session folder's name after the date, so the topic is obvious later.
_Avoid_: title, tag, project name

**Track**:
One captured stream saved as its own file: the System track, the Mic track, the
Mixed file or the Screen recording. On disk each is named in plain words, not with
these terms.
_Avoid_: channel, stream, source

**System track**:
The recording of computer audio: what the other participants say. On disk:
*Computer audio*.
_Avoid_: speaker track, output audio, loopback, "them"

**Mic track**:
The recording of the local microphone: the user's own voice. On disk:
*My microphone*.
_Avoid_: input track, "me"

**Mixed file**:
The single recording that combines the System track and the Mic track. This is the
file shared with an AI summarizer; the two tracks are kept as the archive. On disk:
*Both voices*.
_Avoid_: merged file, output file, final file

**Part**:
One piece of a long track, cut after the Recording Session stops. When the session
has Markers, the uncut Mixed file is kept alongside its parts.
_Avoid_: chunk, segment, split file

**Screen recording**:
The optional video of the Recorded monitor, with the meeting audio embedded so it
plays on its own. On disk: *Screen recording*.
_Avoid_: video capture, screencast, screen grab

**Self-contained MP4**:
A Screen recording that carries both the video and the meeting audio, so it is
watchable without the separate audio tracks.
_Avoid_: muxed file, combined video

**Recorded monitor**:
The display the Screen recording captures. On the Mac it is always the built-in
screen; choosing an external monitor is deferred. The Key caster is pinned to it.
_Avoid_: target screen, active monitor

**Record-screen toggle**:
The single opt-in switch for the Screen recording, reachable from Settings and from
the menu-bar menu. There is no per-recording prompt.
_Avoid_: screen checkbox, video flag

**Inactive hotkey**:
A configured global hotkey that another app already owns, so pressing it does
nothing until the user chooses a different one.
_Avoid_: broken hotkey, disabled hotkey, dead key

## On-screen feedback

**Input highlight**:
The visual feedback drawn over the screen while the Screen recording runs: a ripple
where the mouse is clicked, and a caption of the keys being pressed. It is meant to
appear in the video.
_Avoid_: cursor effect, keystroke display, visualizer

**Mouse highlight**:
The click-ripple part of the Input highlight.

**Key caster**:
The keyboard part of the Input highlight: a caption showing every key pressed. What
it shows is never written down anywhere, in any form.
_Avoid_: keylogger, key display

**Failure notice**:
A short message in plain words that appears over a full-screen meeting when part of
a Recording Session has failed, and says what is still recording. It is the only
mid-meeting message that uses words; a Marker gets a wordless tick.
_Avoid_: alert, toast, balloon

## Markers

**Marker**:
A timestamped point of interest the user flags while a Recording Session is
running, stored as the time elapsed since the session started, with an optional
short note.
_Avoid_: bookmark, flag, chapter, cue point

**Marker note**:
The optional short text a user types for a Marker.
_Avoid_: comment, annotation, label

**Marker log**:
The sidecar file, one per Recording Session, that lists all its Markers. Kept
separate from the tracks so it survives cutting, and so it can be handed to an AI
summarizer on its own.
_Avoid_: marker file, notes file, index

**Marker review page**:
The self-contained web page generated in the Session folder when a session has at
least one Marker. It plays the recording and lists every Marker; clicking one jumps
the player to that moment. The browser is the player.
_Avoid_: viewer, web player, player page

## Transcript

**Transcript**:
The text of what was said in an audio or video file, made by SPTranscriber — for
any file, and for every Recording Session, which SPRecorder hands to SPTranscriber
after stop so it lands in the Session folder. Each
turn is one paragraph with its time and its voice: *Speaker 1*, *Speaker 2* … for
the voices told apart, plus *Me* for the Mic track when the file is a Recording
Session. Markers sit in it at their time. It is the meeting, so it never goes into
a Problem report. On disk, in a Session folder: *Transcript.md*.
_Avoid_: words file, captions, subtitles, minutes, meeting notes

**SPTranscriber**:
The second app in this repo. A normal Mac app with a window and a Dock icon that
turns any audio or video file into a Transcript. A file gets in by dropping it on the
window or the Dock icon, by Choose a File…, or by Finder's Open With; files are made
one at a time, in a list that shows what is happening to each.
_Avoid_: the separate app, the transcription app, the transcriber

**Hand-off**:
SPRecorder giving a finished Recording Session to SPTranscriber after stop, so the
Transcript is made with nobody pressing anything. It passes the whole Session folder,
it shows nothing on screen, and a Recording Session records and saves whether or not
SPTranscriber is there.
_Avoid_: hand-over, auto-transcribe, trigger, pipeline

## Support

**Diary**:
An app's own day-by-day record of what it did and what went wrong, kept for seven
days and then deleted. It records everything except keystrokes. SPRecorder and
SPTranscriber each keep their own.
_Avoid_: log file, logs, trace, history

**Check my setup**:
A check the user runs on their own Mac. It makes a two-second test capture
and reports, one line per part, whether the microphone, computer audio, screen,
Key caster, hotkeys and recordings folder work. It is never a Recording Session.
_Avoid_: self-test, self-check, diagnostics, test recording

**Problem report**:
A file the user sends the developer when something goes wrong. It carries facts
about their recordings (both apps' Diaries, settings, crash reports and a list of
recent Session folders) but never a recording itself, and never a Transcript. It is
started in one place and gathers both apps, so the user never has to know which of
them failed.
_Avoid_: diagnostic bundle, support bundle, crash report, logs

**Private copy**:
The version of a Problem report with everything the user typed removed: Marker
notes and the names of Named sessions.
_Avoid_: redacted version, safe copy
