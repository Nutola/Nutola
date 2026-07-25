# Muesli → Nutola Feature Gap Analysis

Source: https://github.com/Muesli-HQ/muesli (README, 2026-07-20)
Baseline: Nutola @ `develop` (post archived-events fix)

Legend: ✅ already in Nutola · ❌ missing · 🟡 partial / different

## 1. Core ASR & Transcription

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Multiple ASR models (Parakeet, Nemotron, Cohere, Whisper, Qwen3, SenseVoice, Indic, Gemma) | ✅ | Nutola uses FluidAudio (Parakeet/Nemotron) + WhisperKit + Apple on-device. Same family. |
| VAD-driven chunk rotation (Silero) | ✅ | `LiveTranscriber` + Silero VAD via FluidAudio. |
| Speaker diarization (pyannote CoreML) | ✅ | `ZoomSpeakerTracker` + platform speaker events. |
| Live meeting transcript (Nemotron 3.5 or Parakeet Realtime EOU) | ✅ | `LiveTranscriber` streams during recording. |
| Filler word removal ("uh", "um", "er", "hmm") | ❌ | **Missing.** Post-transcript cleanup step. |
| Personal dictionary (Jaro-Winkler fuzzy matching) | ❌ | **Missing.** Custom vocabulary for transcription correction. |
| Model management UI (download/delete/switch) | ✅ | `NemotronModelStore`, `SoniqoModelStore`, Models tab. |

## 2. Dictation

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Hold-to-talk dictation (hotkey → speak → paste) | ❌ | **Missing entirely.** Nutola is meeting-recording only. |
| Hands-free (double-tap) mode | ❌ | **Missing.** |
| ~0.13s latency paste-at-cursor | ❌ | **Missing.** |

## 3. Meeting Recording & Detection

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Mic + system audio capture (CoreAudio tap + ScreenCaptureKit fallback) | ✅ | `SystemAudioTap` + `MicRecorder`. |
| Camera-based meeting detection (webcam + mic in Zoom/Teams/etc) | ❌ | **Missing.** Nutola uses mic-only `MeetingDetector`. |
| Join & Record split button (Join+Record / Join Only / Record Only) | 🟡 | Nutola has `ConferenceJoinButton` (open URL) but no "join + start recording" combined action. |
| Import Audio (m4a/mp4/wav/mp3 → offline transcription + diarization + summary) | ❌ | **Missing.** |
| Floating indicator (frosted glass pill + waveform + click-to-stop) | ✅ | `RecordingCardController` / live recording card. |
| Configurable hotkeys | 🟡 | Nutola has ⌃⌥B for bookmarks; no dictation hotkey. |

## 4. Calendar & Coming Up

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Google Calendar integration (OAuth) | 🟡 | Nutola uses EventKit (system calendars), not Google OAuth directly. Same outcome. |
| Coming Up section + status bar | ✅ | `ComingUpView`, `MenuBarView`. |
| 1/2/3 day horizon | ✅ | `fetchHorizonDays`. |
| Dismiss/archive calendar events | ✅ | `ArchivedEventStore` (just fixed). |
| Pre-meeting countdowns | ✅ | `countdownText`, "Marauder's Map" easter egg likely. |
| Platform icons (Zoom/Meet) in notification | ✅ | `ConferenceVideoIcon`, `ConferenceProvider`. |
| Event-driven refresh (`EKEventStoreChangedNotification`) | ✅ | `CalendarStore` observers. |

## 5. AI Notes & Summaries

| Muesli feature | Nutola status | Notes |
|---|---|---|
| BYOK OpenAI / OpenRouter | ❌ | **Missing.** Nutola uses Apple Intelligence + Claude CLI + Codex CLI, not API-key providers. |
| ChatGPT subscription (OAuth PKCE, no API key) | ❌ | **Missing.** Nutola uses Claude/Codex CLIs instead. |
| Local Ollama models | ❌ | **Missing.** |
| Auto-generated meeting titles | ✅ | `generateTitle` in pipeline. |
| Re-summarize any meeting | ✅ | `regenerateSummary` use case + MCP tool. |
| Meeting templates (built-in + custom) | ✅ | `TemplateStore`, `TemplateOverrideStore`. |
| Smart template selection by meeting type | ✅ | `MeetingTemplateResolver`. |

## 6. Export & Sync

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Export notes/transcript as PDF (US Letter) | ❌ | **Missing.** Nutola exports Markdown/HTML/SRT/VTT/CSV but not PDF. |
| Export as Markdown | ✅ | `exportMarkdown()`. |
| iCloud Text Sync & iPhone Bridge (CloudKit private DB) | ❌ | **Missing entirely.** |
| Audio never synced | ✅ (vacuously) | Nutola has no sync at all. |

## 7. Organization & History

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Meeting folders + title rules | ✅ | `MeetingFolderStore`, `FolderArchive`. |
| Dictation history | ❌ | N/A — no dictation. |
| Meeting notes (Notes-style split view) | ✅ | `MeetingDetailView`. |

## 8. Automation & Integrations

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Computer Use planner (voice-driven local app/browser actions) | ❌ | **Missing.** |
| Post-meeting hooks (run user executable, JSON payload on stdin) | ❌ | **Missing.** |
| Agent CLI (`muesli-cli` for Codex/Claude Code) | ✅ | Nutola has `--mcp` MCP server instead of a dedicated CLI. Different shape, same purpose. |

## 9. App & UX

| Muesli feature | Nutola status | Notes |
|---|---|---|
| Onboarding wizard (model select, perms, hotkey, live test) | ✅ | `OnboardingView`. |
| Launch at Login (`SMAppService.mainApp`) | ✅ | `LaunchAtLogin.swift`. |
| Dark & light mode | ✅ | `Theme` system. |
| SwiftUI dashboard | ✅ | `MainWindowView`, `MeetingsListView`, etc. |
| Accent color customization | 🟡 | Folder icons only; not a global accent. |

---

## Summary: Missing features to implement

Ordered by impact × feasibility (high-value, well-scoped first):

### Tier 1 — High value, clear scope (✅ implemented 2026-07-21)
1. ✅ **Filler word removal** — `FillerWordRemover.swift`, `AppSettings.fillerRemoval` toggle in Settings → Understanding. Strips uh/um/er/hmm from the summary text only; saved transcript stays verbatim. 9 unit tests.
2. ✅ **Personal dictionary** — `PersonalDictionaryStore.swift` + `JaroWinkler.swift`. Phrase matches (case-insensitive exact) and word matches (Jaro-Winkler fuzzy, default 0.92). Applied to summary text alongside filler removal. 12 unit tests.
3. ✅ **PDF export** — `PDFExporter.swift`. `NSPrintOperation` + `NSPrintInfo.jobSavingURL`, paginated US Letter, 0.75" margins. New "PDF…" item in MeetingDetailView export menu. 1 integration test that verifies a real `%PDF` file is produced.
4. ✅ **Import Audio** — `ImportAudioUseCase.swift`. `NSOpenPanel` (via SwiftUI `.fileImporter`) accepts `.mp3/.wav/.m4a/.mpeg4Movie`. Copies file into the meeting's archive folder, creates a `Meeting(sourceApp: "Audio Import")`, runs the full `ProcessingPipeline` offline. New "+" → "Import Audio…" menu in Meetings list. 4 unit tests (including a hand-rolled silent-WAV generator).
5. ✅ **Join & Record split button** — `ConferenceJoinButton` gains an optional `calendarEvent` param; when set, it renders a primary "Join & Record" button (opens conference + starts a calendar-linked recording) plus a chevron menu with "Join only" / "Record only". Wired into ComingUpView, MenuBarView, and MeetingDetailView (prominent variant).

### Beyond Muesli — Nutola-specific addition
6. ✅ **"Additional participants" annotation** — `AdditionalParticipantsAnnotator.swift` + hooks in `ProcessingPipeline.run` and `RegenerateSummaryUseCase.execute`. When Zoom's AX roster contains names that are NOT on the calendar invite (excluding the local "You"), the notes get a trailing markdown section listing them: `**Additional participants (from Zoom, not on the calendar invite):** Lian Fernandes, SiHun Sung`. This addresses the case where a meeting is linked to a calendar event with no/incorrect attendees but real people show up in the Zoom call. 9 unit tests.

### Tier 2 — Medium value, larger scope
6. **Camera-based meeting detection** — CoreMediaIO webcam listener + mic-in-meeting-app heuristic. Reduces false negatives vs mic-only detection.
7. **Post-meeting hooks** — run user executable with JSON payload after `process()` completes.
8. **Ollama / OpenAI / OpenRouter BYOK** — add API-key summary providers alongside Apple/Claude/Codex.

### Tier 3 — Large scope, different product direction
9. **Dictation (hold-to-talk + hands-free)** — new top-level mode, hotkey handling, paste-at-cursor. Big build.
10. **iCloud Text Sync / iPhone Bridge** — CloudKit private DB + a companion iOS app. Huge.
11. **ChatGPT OAuth (PKCE)** — browser-based flow, token storage. Nutola's CLI-based approach already covers the same need.
12. **Computer Use planner** — voice-driven app/browser automation. Out of scope for a meeting tool.

### Not applicable
- Google Calendar OAuth — Nutola uses EventKit which covers all system calendars including Google via macOS accounts. No gap in practice.
- Dictation history — N/A without dictation.

---

## Implementation plan (Tier 1)

Build order chosen to reuse existing infra and keep each slice independently shippable.

1. **Filler word removal** (`Sources/Nutola/Intelligence/FillerWordRemover.swift`)
   - New post-transcript pass in `ProcessingPipeline.run`, before summary.
   - Word-boundary regex for `uh|um|er|hmm|ah` (English) + common PT-BR fillers (`é|tipo|né`). Toggle in `AppSettings`.
   - Unit-testable: pure `String → String`.

2. **Personal dictionary** (`Sources/Nutola/Store/PersonalDictionaryStore.swift`)
   - `[DictionaryEntry]` in UserDefaults: `word`, optional `phraseMatch`, optional `replacement`.
   - Jaro-Winkler similarity (Swift stdlib has no JaroWinkler; small self-contained impl).
   - Applied as a post-transcript pass after filler removal.
   - Settings UI for CRUD.

3. **PDF export** (`Sources/Nutola/Publish/PDFExporter.swift`)
   - `NSPrintOperation` with paginated `NSAttributedString` (US Letter).
   - Add "PDF…" button next to "Markdown…" in `MeetingDetailView` export menu.

4. **Import Audio** (`Sources/Nutola/Domain/UseCases/ImportAudioUseCases.swift`)
   - `NSOpenPanel` for `.m4a/.mp4/.wav/.mp3`.
   - Create a `Meeting(source: .audioImport)`, copy file into archive, run `ProcessingPipeline.run` offline.
   - New "Import Audio…" menu item in Meetings list + menu bar.

5. **Join & Record split button** (`Sources/Nutola/UI/Components/ConferenceJoinButton.swift`)
   - Extend existing button to a split button: primary "Join & Record", secondary "Join Only" / "Record Only".
   - Wire to `startRecording(calendarEvent:)` + `NSWorkspace.open(url)`.
