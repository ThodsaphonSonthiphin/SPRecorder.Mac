# SPRecorder.Mac

The macOS port of SPRecorder. The Windows original lives in a sibling repo,
`ThodsaphonSonthiphin/SPRecorder`, and is **frozen but alive**: it gains no new
features, so this port may diverge freely. Never write changes into it.

## Ubiquitous language

The domain glossary is the Windows repo's `CONTEXT.md`. Both apps use one
vocabulary — Recording Session, System track, Mic track, Mixed file, Screen
recording, Marker, Marker review page, Key caster, Inactive hotkey. Whether this
repo copies that file or references it across repos is still open; see the
`adr-and-repo-strategy` decision ticket.

## ADRs

- **ADR sequence prefix: `sprecorder-mac`.** Files are
  `docs/adr/sprecorder-mac-<number>-<slug>.md`, four-digit zero-padded.
- Cite as `sprecorder-mac-0001`. The Windows repo owns a **separate, unprefixed**
  sequence (its own `0001`-`0022`), so a bare number is ambiguous between the two
  repos — always carry the prefix when citing across them.

## Planning

Work on this port is charted as a Decision map on GitHub Issues — map issue
[#1](https://github.com/ThodsaphonSonthiphin/SPRecorder.Mac/issues/1), one
sub-issue per decision. See `docs/decision-map/sprecorder-macos-port/map.md`.
Continue it with `/decision-map:work`.
