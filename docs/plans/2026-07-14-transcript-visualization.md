# Transcript visualization — implementation plan (2026-07-14)

> Status: PLAN — transcript data and tabs exist; the **Transcript** surface is still a sparse
> text list. This doc refactors it into a scannable, speaker-aware reader (Granola-inspired
> layout, Parfait palette).

## What we're building

Parfait already records, diarizes, and stores `[TranscriptSegment]` with per-turn timestamps
and renameable speakers. The gap: the **Transcript** tab renders turns as plain left-aligned
text with huge empty margins — hard to scan, no visual speaker separation, no search, no
playback context. Notes and Ask AI are separate tabs with their own empty layouts.

Goal: make the transcript feel like a **first-class document** you can read, search, rename
speakers inline, and jump from — without changing the underlying storage format.

### UX patterns to adopt

| Pattern | Reference (Granola) | Parfait (this plan) |
|---|---|---|
| Reading column | Centered ~660–720px document column | Keep `maxWidth: 660`; add card turns inside |
| Speaker blocks | Name + indented bullets / sections | **Turn cards** with colored left rail per speaker |
| Metadata | Chips (Enhanced, date, team) | Reuse header chips; add transcript stats bar |
| Bottom assistant | Floating “Ask anything” + suggestions | Phase 2: sticky compose on Transcript tab |
| Live vs final | Polished reader for saved notes | Same visual language for `LiveTranscriptView` |

### Parfait-specific choices

- **No layout overhaul** of `MeetingDetailView` — keep Notes / Transcript / Ask AI tabs and
  the existing edit-as-text path (`TranscriptFormatter.plainText` / `parseEdited`).
- **Bright Parfait palette** (`Theme`): blueberry = “You”, raspberry = remote speakers,
  honey = timestamps / chrome, cream cards.
- **On-device only** — no cloud transcript viewer; published HTML can later reuse the same
  turn markup (`HTMLExporter` already has `.turn` styles).
- **Audio playback is Phase 3** — timestamps are clickable in Phase 2 (scroll/highlight) before
  we wire `AVAudioPlayer` to `mic.m4a` / `system.m4a`.

## Where we are today

| Area | Status |
|---|---|
| `TranscriptSegment` + `Speaker` | `start`/`end`/`speakerID`/`text` — sufficient |
| `TranscriptTab` / `LiveTranscriptView` | `MeetingContentTabs.swift` — minimal `LazyVStack` |
| Turn grouping | Duplicated in `TranscriptTab.groupedTurns` and `LiveTranscriber.turns` |
| `TranscriptFormatter.markdown` | Groups consecutive same-speaker segments (for export/MCP) |
| `HTMLExporter.transcriptTurns` | Card-style HTML turns — **not mirrored in SwiftUI** |
| Audio files | `mic.m4a`, `system.m4a` on disk — **no in-app player** |
| Search in transcript | None |
| Ask AI on selection | `MeetingLauncherView` is a separate tab with empty suggestions |

### Current pain (from screenshots)

1. **Transcript tab** — one small turn at the top, rest of the panel is dead space; turns lack
   cards, dividers, or density cues.
2. **Live transcript** — same sparse layout; volatile line is italic secondary text only.
3. **Notes vs Transcript** — Notes uses `MarkdownText` in a scroll view; Transcript does not
   share that “document” feel.
4. **Ask AI** — disconnected from transcript content; no “ask about this paragraph” flow.

## Architecture

```
 transcript.json  [TranscriptSegment]
        │
        ▼
 TranscriptTurnBuilder (pure, shared)
   └─ merge consecutive same-speaker segments → TranscriptTurn
        │
        ├────────────────────┬──────────────────────
        ▼                    ▼                      ▼
 TranscriptReaderView   LiveTranscriptView    HTMLExporter
 (saved, searchable)    (live + volatile)     (publish parity)
        │
        ├─ TranscriptToolbar (search, segment count, edit)
        ├─ TranscriptTimelineRail (optional, Phase 2)
        └─ TranscriptTurnCard × N
```

### A. Shared turn model (`Sources/Parfait/Transcription/TranscriptTurn.swift`)

Extract grouping logic once; delete duplicate `Turn` structs in UI.

```swift
struct TranscriptTurn: Identifiable, Equatable, Sendable {
    var id: String          // "\(speakerID)-\(start)" stable for scroll/search
    var speakerID: String
    var start: TimeInterval
    var end: TimeInterval   // last segment's end
    var text: String        // joined segment texts
    var segmentCount: Int
}

enum TranscriptTurnBuilder {
    static func turns(from segments: [TranscriptSegment]) -> [TranscriptTurn]
    static func speakerColor(
        speakerID: String, speakers: [Speaker], scheme: ColorScheme
    ) -> Color
}
```

- Move color rules here: `isMe` / `speakerID == LiveTranscriber.youSpeakerID` → blueberry;
  remote speakers cycle raspberry / honey / mint (max 6, then muted secondary).
- Unit tests in `TranscriptTurnBuilderTests.swift` (mirror `LiveTranscriberTests` cases).

### B. Transcript UI module (`Sources/Parfait/UI/Transcript/`)

Split out of `MeetingContentTabs.swift` to keep tab files readable.

| File | Responsibility |
|---|---|
| `TranscriptReaderView.swift` | Saved transcript shell: toolbar + scroll + empty states |
| `TranscriptTurnCard.swift` | One speaker turn: rail, name button, timestamp, body |
| `TranscriptToolbar.swift` | Segment count, search field, Edit / Save / Cancel |
| `TranscriptSearch.swift` | Filter highlights + `scrollTo(turnID)` |
| `TranscriptTimelineRail.swift` | Phase 2 — vertical proportion bar with turn ticks |
| `LiveTranscriptReaderView.swift` | Live banner + same turn cards + volatile tail |

**`TranscriptTurnCard` layout (Phase 1)**

```
┌─────────────────────────────────────────────┐
│ ▌ You                          0:00         │  ← 3px colored rail (blueberry)
│ ▌ Hey, I'm using this to test…            │  ← 13pt rounded, selectable text
└─────────────────────────────────────────────┘
   card background: Theme.card(scheme), cornerRadius 12, padding 14
   spacing between cards: 10
```

- Speaker name remains a **button** → existing rename sheet (calendar attendee chips).
- Timestamp: monospaced `MeetingArchive.timestamp`, tertiary color; Phase 2 adds
  `Button` → scroll/highlight (Phase 3 → seek audio).
- Long meetings: `LazyVStack` inside `ScrollViewReader` (keep current performance model).

**Toolbar (Phase 1)**

Replace the lone “4 segments” label with:

```
[ 🔍 Search transcript… ]     4 segments · 2 min     [ Edit as text ]
```

- Search: case-insensitive match in `turn.text` and speaker display name; dim non-matching
  cards to 0.45 opacity; show “2 of 14 turns” when filtered.
- Edit path unchanged: `TranscriptFormatter.plainText` → `TextEditor` → `parseEdited`.

### C. Live transcript parity

`LiveTranscriptView` should render **`TranscriptTurnCard`** for finalized `liveSegments` and a
**`VolatileTailView`** (italic, pulsing cursor optional) for `session.volatileText`.

- Keep auto-scroll to bottom via `ScrollViewReader` + `"live-bottom"` anchor.
- Banner copy stays; style as a slim honey-tinted info bar instead of plain `HStack`.

### D. Notes tab — light touch (Phase 1)

Do **not** merge Notes and Transcript. Optional polish only:

- Wrap `MarkdownText` in the same **card** treatment as transcript turns (single large card)
  so both tabs feel like one product.
- Keep `maxWidth: 660` and streaming badge behavior.

### E. Ask AI bridge (Phase 2)

Granola’s bottom compose bar is the reference for **in-context** questions.

1. Add `TranscriptSelection` state: optional `(turnID, excerpt)` when user selects text in a
   turn card (`textSelection` + `onSelectionChange` on macOS 14+).
2. Sticky footer on Transcript tab only:

```
┌──────────────────────────────────────────────────────────┐
│ Ask about this meeting…                    [ Ask AI ▾ ]   │
│ Suggestions: Write follow-up · Summarize speaker · …    │
└──────────────────────────────────────────────────────────┘
```

3. Reuse `AILauncherView` prompt builders; if selection exists, prepend:
   `Regarding this excerpt from the transcript: "…" — {question}`
4. Suggestions (meeting-scoped, static list initially):
   - “Write follow-up email”
   - “List action items”
   - “What did {top speaker} say?”
5. Keep the **Ask AI tab** for users who prefer full-page launcher; footer is additive.

### F. Timeline rail (Phase 2)

For meetings longer than ~3 minutes, show a narrow (24px) rail left of the scroll column:

- Full height ∝ `meeting.duration`
- Ticks at each `turn.start`, colored by speaker
- Hover / click tick → `scrollTo(turn.id)` and brief highlight ring on the card
- Hide rail when `duration < 180` or when search is active (space for results)

### G. Audio playback sync (Phase 3 — optional)

Prerequisite: `MeetingArchive` already stores `mic.m4a` and `system.m4a`.

```swift
@MainActor
final class MeetingPlaybackController: ObservableObject {
    var currentTime: TimeInterval
    func play(from: TimeInterval)
    func pause()
    // Merge mic+system is out of scope v1; play system.m4a only or
    // sequential mic-then-system by timestamp — DECIDE at implementation.
}
```

- Active turn highlight: `turn.start <= currentTime < turn.end`
- Timestamp buttons call `play(from: turn.start)`
- Mini transport in toolbar: play/pause, elapsed, scrubber
- **Defer** if AVFoundation merge complexity is high; Phase 1–2 still ship value without audio.

### H. Publish parity (Phase 2)

Refactor `HTMLExporter.transcriptTurns` to call `TranscriptTurnBuilder` so exported pages
match in-app grouping. Optional: emit `data-turn-id` attributes for deep links later.

## File changes (by phase)

### Phase 1 — Visual reader (ship first)

| Action | File |
|---|---|
| Add | `Transcription/TranscriptTurn.swift` |
| Add | `UI/Transcript/TranscriptTurnCard.swift` |
| Add | `UI/Transcript/TranscriptReaderView.swift` |
| Add | `UI/Transcript/LiveTranscriptReaderView.swift` |
| Modify | `UI/MeetingContentTabs.swift` — thin wrappers delegating to new views |
| Modify | `UI/MeetingContentTabs.swift` — Notes: optional single card wrapper |
| Add | `Tests/ParfaitTests/TranscriptTurnBuilderTests.swift` |

**Acceptance**

- [ ] Saved transcript shows turn **cards** with speaker color rail, not bare text
- [ ] Live transcript uses the same cards + volatile tail
- [ ] Rename speaker still works from name button
- [ ] Edit as text / save / cancel unchanged
- [ ] Empty and processing states unchanged
- [ ] `make test` green

### Phase 2 — Search, timeline, Ask footer

| Action | File |
|---|---|
| Add | `UI/Transcript/TranscriptToolbar.swift` |
| Add | `UI/Transcript/TranscriptSearch.swift` |
| Add | `UI/Transcript/TranscriptTimelineRail.swift` |
| Add | `UI/Transcript/TranscriptAskFooter.swift` |
| Modify | `UI/ClaudeLauncherViews.swift` — expose suggestion chips helper |
| Modify | `Publish/HTMLExporter.swift` — use `TranscriptTurnBuilder` |

**Acceptance**

- [ ] Search filters/highlights turns; clearing restores full list
- [ ] Timeline rail scrolls to turn on click (meetings ≥ 3 min)
- [ ] Transcript footer launches Ask AI with optional selection context
- [ ] Published HTML turn boundaries match in-app grouping

### Phase 3 — Playback (optional)

| Action | File |
|---|---|
| Add | `Audio/MeetingPlaybackController.swift` |
| Modify | `TranscriptReaderView.swift` — active turn highlight + transport |
| Modify | `MeetingDetailView.swift` — pass `meeting.duration` + audio URLs |

**Acceptance**

- [ ] Click timestamp seeks audio (system channel minimum)
- [ ] Playing meeting highlights current turn
- [ ] Playback stops when leaving meeting detail

## UI spec (quick reference)

| Token | Use |
|---|---|
| `Theme.blueberry` | “You” / `isMe` speaker rail + name |
| `Theme.raspberry` | First remote speaker |
| `Theme.honey` | Timestamps, live banner, timeline ticks |
| `Theme.card(scheme)` | Turn card fill |
| `Theme.cornerRadius` (16) | Cards; turn cards may use 12 for density |
| Font `.parfait(12, .bold)` | Speaker name |
| Font `.parfait(13)` | Turn body |
| Monospaced 10pt | Timestamp |

**Spacing**

- Outer padding: 20 (match Notes)
- Column max width: 660, centered
- Inter-turn gap: 10
- Card inner padding: 14

## Testing

| Test | Covers |
|---|---|
| `TranscriptTurnBuilderTests` | Grouping, empty input, speaker handoff, `end` time |
| `TranscriptFormatterTests` (existing) | Edit round-trip still passes after builder extraction |
| `HTMLExporterTests` (existing) | Update fixtures if turn boundaries change |
| Manual | Short (2 min) + long (30 min) meetings, light/dark mode, live → saved transition |

## Out of scope

- Word-level karaoke highlighting (we have `TranscribedWord` in batch output but do not persist
  per-word timings in `transcript.json` today)
- Inline transcript editing per card (keep monolithic text editor)
- Replacing tabbed layout with Granola’s single scrolling note + embedded transcript
- Cloud sync or collaborative transcript view
- Re-diarization UI
- **Appending audio to meetings that already have a transcript** (continue recording is
  implemented for failed / empty meetings only — see below)

## Continue recording (implemented 2026-07-14)

Granola’s floating panel exposes **Resume** when a capture failed or was interrupted. Parfait
matches that for **failed** meetings and **ready** meetings with an empty transcript.

| Trigger | UI |
|---|---|
| `meeting.state == .failed` | **Continue recording** in notice banner + empty Notes/Transcript states |
| `ready` + empty `transcript.json` | Same |
| Active session for this meeting | Transcript tab auto-selected; live reader |

**Behavior (`AppState.continueRecording`)**

- Reuses meeting folder, title, calendar metadata
- Deletes prior `mic.m4a` / `system.m4a` / `live.json` (nothing durable to keep)
- Sets `state = .recording`; `RecordingSession` honors `elapsedOffset` from prior `duration`
- On stop → normal `process()` pipeline

**Not yet:** resume/append when a non-empty transcript already exists (needs audio concat +
timestamp offset in the pipeline).

## Open questions (decide before Phase 3)

1. **Playback source:** system-only, mic-only, or mixed timeline? Mixed is best UX but needs
   a small mixer or interleaved segment model.
2. **Ask footer vs tab:** ship footer only on Transcript, or also on Notes?
3. **Speaker color cycle:** fixed map by `speakerID` vs hash — fixed map is more stable across
   renames.

## Suggested implementation order

1. `TranscriptTurnBuilder` + tests (no UI risk)
2. `TranscriptTurnCard` + `TranscriptReaderView` (biggest visual win)
3. Live reader parity
4. Notes card wrapper (quick)
5. Search + toolbar
6. Timeline rail
7. Ask footer + selection
8. HTMLExporter alignment
9. Playback (if warranted)

---

*Reference screenshots: Granola reader density + Parfait current Transcript/Notes/Ask tabs
(2026-07-14).*
