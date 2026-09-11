# SPRecorder.Mac

The macOS port of SPRecorder. The Windows original lives in a sibling repo,
`ThodsaphonSonthiphin/SPRecorder`, and is **frozen but alive**: it gains no new
features, so this port may diverge freely. Never write changes into it.

## Ubiquitous language

The domain glossary is this repo's own [`CONTEXT.md`](CONTEXT.md). It started from the
Windows repo's `CONTEXT.md` and is corrected wherever the Mac app differs (no MP3, the
built-in screen, a Session folder for every Recording Session) and extended with the
Mac-only terms: Diary, Check my setup, Problem report, Private copy, Part, Failure
notice, Transcript. Use its terms, and the words under *Avoid* nowhere. Add or correct a term in
the same commit as the ADR that settles it. See `sprecorder-mac-0039`.

## ADRs

- **ADR sequence prefix: `sprecorder-mac`.** Files are
  `docs/adr/sprecorder-mac-<number>-<slug>.md`, four-digit zero-padded.
- Cite as `sprecorder-mac-0001`. The Windows repo owns a **separate, unprefixed**
  sequence (its own `0001`-`0022`), so a bare number is ambiguous between the two
  repos — always carry the prefix when citing across them.
- **Cite a Windows ADR as `Windows ADR NNNN`**, never a bare `ADR NNNN`. Windows ADRs
  are cited, never copied, and the Windows repo is never edited (`sprecorder-mac-0039`).

## Planning

Work on this port is charted as a Decision map on GitHub Issues — map issue
[#1](https://github.com/ThodsaphonSonthiphin/SPRecorder.Mac/issues/1), one
sub-issue per decision. See `docs/decision-map/sprecorder-macos-port/map.md`.
Continue it with `/decision-map:work`.
