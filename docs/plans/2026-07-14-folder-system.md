# Folder system — implementation plan (2026-07-14)

> Status: PLAN — no folder model or UI exists yet.
> Reference UX: sidebar **Spaces** / **Folders**, folder landing page with meeting history,
> and **Add to folder** on upcoming calendar events (Granola-style).
> Builds on [calendar integration](./2026-07-14-calendar-integration.md) (`calendarEventTitle`,
> `CalendarEventSummary`, Coming up).

## What we're building

Parfait today keeps a flat **Meetings** list. Users with recurring calendar events (standups,
1:1s, project syncs) want those recordings grouped together — one folder per "meeting series,"
with every past instance listed chronologically.

### Core behaviors

| Behavior | Rule |
|---|---|
| Manual assign — menu | **Move to…** submenu on any meeting row (sidebar, folder page, detail overflow) |
| Manual assign — drag | Drag a meeting row onto a folder in the sidebar → assign |
| Auto-assign on record | When recording starts with a calendar title, if **any prior meeting** used the same normalized title in a folder, the new recording lands in **that same folder** |
| Auto-assign on manual move | Any manual move (menu or drag) into a folder persists a **title → folder** rule for future occurrences |
| Unfiled | Meetings with no folder stay in the flat **Meetings** sidebar section; **Remove from folder** clears `folderID` only (rule unchanged unless user re-assigns) |

### UX patterns to adopt

| Surface | Reference pattern | Parfait (this plan) |
|---|---|---|
| Sidebar | Spaces / folder list under nav | New **Folders** section between nav and Meetings |
| Sidebar meeting row | Right-click → Move to… | Context menu + drag onto folder row |
| Folder page | Title, description, meeting list by date | `FolderDetailView` — notes list; row **Move to…** + drag out |
| Coming up row | **Add to folder** menu | Menu on agenda rows; pre-selects folder when title rule exists |
| Meeting detail | Folder pill / overflow | **Move to…** in toolbar overflow; same picker everywhere |
| Recording | (implicit) same series → same folder | Auto `folderID` at `startRecording` when rule matches |
| Ask / chat | "Ask about folder" | v1.1 — folder-scoped Claude prompt (out of scope v1) |

### Parfait-specific choices

- **Match key = calendar event title** (normalized string), not `calendarEventID`.
  Recurring events get new EventKit IDs per occurrence; title is the stable series key.
- **Exact normalized match v1** — no fuzzy matching, no attendee-based grouping.
- Folders are **local-only** (Application Support), same as meetings — no sync.
- Folder delete → meetings become unfiled (`folderID = nil`), not deleted.
- Keep bright Parfait palette; folder rows use a simple folder icon + name.

## Where we are today

| Area | Status |
|---|---|
| `Meeting` model | Has `calendarEventTitle`, `calendarEventID` — **no `folderID`** |
| `MeetingStore` / `MeetingArchive` | Flat `Meetings/<uuid>/` — **no Folders/** tree |
| Sidebar | Home, Ask your meetings, flat Meetings list — **no Folders section** |
| `ComingUpView` | Agenda + Record — **no Add to folder** |
| `startRecording(calendarEvent:)` | Pre-fills title/attendees — **no folder lookup** |
| MCP | list/search/get meetings — **no folder tools** (v1.1) |

## Architecture

```
 Calendar event title (normalized)
        │
        ▼
 FolderRuleIndex                    MeetingFolderStore
   title → folderID                   ├─ folders.json
        │                             └─ CRUD + publish
        │                                      │
        └──────── auto-assign ────────────────┤
                                               ▼
                                         Meeting.folderID
                                               │
                    ┌──────────────────────────┼──────────────────────┐
                    ▼                          ▼                      ▼
              startRecording            FolderDetailView      Sidebar Folders
              (auto folderID)           (meetings in folder)   section
                    │
                    ▼
              User manual move (menu / drag / Add to folder)
              → set folderID + write rule
```

### A. Data model (`Store/Models.swift`)

```swift
struct MeetingFolder: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var createdAt: Date
    var sortOrder: Int = 0   // sidebar ordering; append on create
}

extension Meeting {
    var folderID: UUID?       // NEW — nil = unfiled
}

/// Persisted mapping for auto-filing. Key is normalized calendar title.
struct FolderTitleRule: Codable, Equatable, Sendable {
    var normalizedTitle: String
    var folderID: UUID
    var updatedAt: Date
}
```

**Title normalization** (pure helper, tested):

```swift
enum FolderTitleNormalizer {
    /// Trim, collapse internal whitespace, lowercase for comparison.
    /// Display title unchanged; only the key is normalized.
    static func key(for title: String) -> String
}
```

Examples:

| Raw title | Key |
|---|---|
| `"Identity Intelligence Eng Standup"` | `"identity intelligence eng standup"` |
| `"  Weekly  1:1  "` | `"weekly 1:1"` |

### B. Storage (`Store/FolderArchive.swift`)

File-backed, mirrors `MeetingArchive` style:

```
~/Library/Application Support/Parfait/
  Folders/
    folders.json          // [MeetingFolder]
    title-rules.json      // [FolderTitleRule]
  Meetings/
    <uuid>/
      meeting.json        // includes folderID
```

**`FolderArchive`** (thread-safe, `@unchecked Sendable`):

```swift
final class FolderArchive: @unchecked Sendable {
    func allFolders() -> [MeetingFolder]
    func save(_ folder: MeetingFolder) throws
    func deleteFolder(id: UUID) throws          // does not touch meetings

    func allTitleRules() -> [FolderTitleRule]
    func rule(forTitle title: String) -> FolderTitleRule?
    func setRule(normalizedTitle: String, folderID: UUID) throws
    func removeRules(forFolderID: UUID) throws
}
```

**`MeetingFolderStore`** (`@MainActor`, owned by `AppState`):

```swift
@MainActor
final class MeetingFolderStore: ObservableObject {
    @Published private(set) var folders: [MeetingFolder] = []
    @Published private(set) var titleRules: [FolderTitleRule] = []

    func reload()
    func createFolder(name: String) -> MeetingFolder
    func updateFolder(_ folder: MeetingFolder)
    func deleteFolder(id: UUID)                    // clears folderID on affected meetings
    func assign(meetingID: UUID, to folderID: UUID?) // nil = unfile
    func assign(calendarTitle: String, to folderID: UUID)  // writes rule + optional future meetings
    func folder(forTitle title: String) -> MeetingFolder?
    func meetings(in folderID: UUID, from store: MeetingStore) -> [Meeting]
}
```

**Delete folder semantics:**

1. Remove folder from `folders.json`.
2. Remove all `FolderTitleRule` entries pointing at that folder.
3. For each meeting with `folderID == id`, set `folderID = nil` and save.

**Migration:** existing meetings decode with `folderID: nil` (optional field, default nil).

### C. Auto-assign pipeline

#### On `startRecording(calendarEvent:)` / auto `currentEvent()`

After calendar metadata is applied:

```swift
if let title = meeting.calendarEventTitle ?? calendarEvent?.title,
   let folder = folderStore.folder(forTitle: title) {
    meeting.folderID = folder.id
}
```

No rule → unfiled (user can assign later; manual assign creates the rule).

#### On manual assign (UI or context menu)

When user moves meeting `M` into folder `F`:

1. `M.folderID = F.id`; upsert meeting.
2. If `M.calendarEventTitle` (or `M.title` when no calendar title) is non-empty:
   `folderStore.setRule(normalizedTitle: key, folderID: F.id)`.

When user assigns an **upcoming event** (no recording yet) via Coming up:

1. Write rule only: `setRule(title: event.title, folderID:)`.
2. Next recording with that title auto-files.
3. Optionally retroactively file past unfiled meetings with the same title (prompt or silent — **silent v1**).

#### Retroactive backfill (v1, silent)

On `setRule`, scan `store.meetings` where:

- `folderID == nil`, and
- `calendarEventTitle` or `title` normalizes to the same key

→ set `folderID` on each. Keeps the folder page complete without a separate migration step.

### D. Sidebar — Folders section (`MainWindowView`)

Extend `SidebarItem`:

```swift
enum SidebarItem: Hashable {
    case home
    case library
    case folder(UUID)    // NEW
    case meeting(UUID)
}
```

Layout:

```
┌─ sidebar ─────────────┐
│ 🔍 Filter meetings    │
│                       │
│ Coming up             │
│ Ask your meetings     │
│                       │
│ Folders               │  ← NEW section
│   My notes            │     (user-created; "My notes" is just a default name)
│   Identity Intelligence│
│   + New folder        │
│                       │
│ Meetings              │  ← only unfiled meetings (folderID == nil)
│   Ad-hoc call …       │
│   …                   │
└───────────────────────┘
```

Behavior:

- **Meetings** section shows only `folderID == nil` meetings (avoids duplicate rows).
- Folder row click → `FolderDetailView`.
- **New folder** → sheet with name field; creates empty folder, selects it.
- Folder context menu: Rename, Delete…, Show in Finder (opens `Folders/` root).
- Meeting row context menu (sidebar + folder page):

  ```
  Move to ▶
    ✓ Current folder     (when already filed here)
    Identity Intelligence
    My notes
    ─────────────
    New folder…
  Remove from folder     (only when folderID != nil)
  ─────────────
  Show in Finder
  Delete…
  ```

- **Drag-and-drop** (sidebar):
  - Meeting rows in **Meetings** and inside **FolderDetailView** are draggable (`Transferable` UUID).
  - Folder rows accept drops; drop target highlights with `Theme.mint` background.
  - Drop on folder → `assign(meetingID:to:)` + write title rule (same as menu).
  - Drop on **Meetings** section header (or a dedicated "Unfiled" drop zone) → `assign(meetingID:to: nil)`.
  - While dragging, non-target folders dim slightly; invalid targets (self, current folder) show "not allowed" cursor.
  - Recording-in-progress meetings are not draggable.

### E. Folder detail view (`FolderDetailView.swift`)

Reference: Identity Intelligence page — title, optional description, chronological meeting list.

```
┌─ Identity Intelligence ──────────────── [Share — v1.1] ─┐
│ 📁 Identity Intelligence                                 │
│ Add description…                                         │
│                                                          │
│ Notes                                                    │
│ ┌ Identity Intelligence Eng Standup ─ Tue, Jun 2, 2:30 PM ┐
│ │   Guilherme, Paulo & 6 others                            │
│ ├ Identity Intelligence Eng Standup ─ Thu, May 7, 2:30 PM ─┤
│ …                                                          │
└──────────────────────────────────────────────────────────┘
```

Behavior:

- Header: editable folder name + description (inline or sheet).
- List: `folderStore.meetings(in:)` sorted by `createdAt` descending.
- Row: title (prefer `calendarEventTitle ?? title`), date/time, attendee snippet.
- Tap row → `SidebarItem.meeting(id)` (existing detail).
- Empty state: "No notes yet — record a meeting or add an existing one."
- **Add existing meeting** menu (v1): picker of unfiled meetings.
- Each row: same **Move to…** context menu as sidebar; draggable to another folder in sidebar.
- Toolbar **⋯** on folder header: Rename, Delete folder…, Show in Finder.

Reuse `MeetingDayGrouper` optionally for day headers inside the folder list.

### F. Coming up — Add to folder (`ComingUpView`)

On each agenda event row, trailing **Add to folder** menu (reference screenshot):

```
Add to folder ▾
  ✓ Identity Intelligence    ← checked when rule exists for this title
  My notes
  Engineering
  ─────────────
  New folder…
```

Behavior:

- If `folderStore.folder(forTitle: event.title)` exists → show checkmark on that folder.
- Pick folder → `assign(calendarTitle: event.title, to: folderID)` (rule only until recorded).
- **New folder…** → name sheet → create + assign rule.
- Does **not** start recording; orthogonal to **Record**.
- When rule exists, show subtle folder badge on the agenda row (folder name, truncated).

### G. Shared folder picker (`FolderPickerMenu.swift`)

One reusable component wired everywhere — avoids four divergent menus:

```swift
struct FolderPickerMenu<Label: View>: View {
    /// When set, "Move to" checks this folder; nil = unfiled.
    var currentFolderID: UUID?
    /// Calendar title for rule write; nil = meeting.title only.
    var calendarTitle: String?
    var meetingID: UUID?          // nil = rule-only (Coming up)
    @ViewBuilder var label: () -> Label
}
```

Surfaces:

| Surface | Trigger label | `meetingID` |
|---|---|---|
| Sidebar meeting row | Context menu **Move to ▶** | set |
| Folder detail row | Context menu **Move to ▶** | set |
| Meeting detail header | Folder pill / **Add to folder** | set |
| Meeting detail overflow | **Move to folder…** | set |
| Coming up row | **Add to folder ▾** | nil (rule only) |

Menu contents (all surfaces):

- One item per folder, checkmark on current.
- **New folder…** → name sheet → create + assign.
- **Remove from folder** when `currentFolderID != nil` (meeting moves only; does not delete title rule).

### H. Meeting detail — folder chip

In `MeetingDetailView` header or metadata strip:

- Show current folder name as a pill, or **Add to folder** when unfiled.
- Click pill → `FolderPickerMenu` (same as **Move to…** elsewhere).
- Overflow menu duplicates **Move to folder…** for discoverability.
- Changing folder updates rule when calendar title is present.

### I. Recording + processing (no changes beyond assign)

`ProcessingPipeline` and title generation: if `calendarEventTitle` is set, do not overwrite
folder assignment. Title renames do **not** update rules automatically (rule stays on original
calendar title key; user can re-assign manually).

## Implementation order

| Phase | Work | Files |
|---|---|---|
| **1 — Model** | `MeetingFolder`, `FolderTitleRule`, `Meeting.folderID`, normalizer | `Models.swift`, `FolderTitleNormalizer.swift` |
| **2 — Storage** | `FolderArchive`, JSON round-trip tests | `FolderArchive.swift`, `FolderArchiveTests.swift` |
| **3 — Store** | `MeetingFolderStore`, wire into `AppState` | `MeetingFolderStore.swift`, `AppState.swift` |
| **4 — Auto-assign** | Hook `startRecording`, retroactive backfill on `setRule` | `AppState.swift` |
| **5 — Picker** | Shared `FolderPickerMenu` + New folder sheet | `FolderPickerMenu.swift` |
| **6 — Sidebar** | Folders section, filter Meetings to unfiled, **Move to…** menu | `MainWindowView.swift` |
| **7 — Drag-drop** | Draggable meetings, droppable folder rows, unfiled drop zone | `MainWindowView.swift`, `FolderDetailView.swift` |
| **8 — Folder page** | `FolderDetailView`, create/rename/delete, row menus | `FolderDetailView.swift` |
| **9 — Coming up** | Add to folder menu + badge | `ComingUpView.swift` |
| **10 — Detail chip** | Folder pill + overflow Move to on meeting detail | `MeetingDetailView.swift` |
| **11 — Polish** | Empty states, delete-folder confirmation, Finder reveal, drag affordances | UI polish |
| **12 — Docs** | Manual checklist in `TESTING.md` | `docs/TESTING.md` |

## Testing

### Unit

- `FolderTitleNormalizer` — trim, collapse spaces, case, empty string.
- `FolderArchive` — create/read/update/delete folders and rules; delete folder clears rules.
- `MeetingFolderStore.assign` — manual assign writes rule; backfill assigns unfiled matches.
- Auto-assign in `startRecording` — mock folderStore returns folder for title → `meeting.folderID` set.
- Sidebar filter — meetings with `folderID` excluded from flat list.

### Manual (`docs/TESTING.md`)

```markdown
## Folders

### Create & organize
- [ ] Sidebar shows Folders section with "New folder"
- [ ] Create folder → appears in sidebar; empty folder page
- [ ] Assign meeting to folder via detail chip → meeting leaves flat Meetings list
- [ ] Folder page lists assigned meetings, newest first

### Move to… menu
- [ ] Sidebar meeting row → Move to… → pick folder → meeting moves
- [ ] Folder page row → Move to… → different folder → meeting moves
- [ ] Remove from folder → meeting appears in flat Meetings list
- [ ] New folder… from menu creates folder and assigns in one step
- [ ] Meeting detail overflow → Move to folder… works the same

### Drag-and-drop
- [ ] Drag meeting from Meetings list onto folder row → assigns; row leaves Meetings
- [ ] Drag meeting from folder page onto another folder → reassigns
- [ ] Drag onto Meetings / Unfiled zone → Remove from folder
- [ ] Folder row highlights on drag-over; no drop on current folder
- [ ] Recording meeting is not draggable

### Calendar auto-file
- [ ] Record "Engineering standup" (calendar-titled) → assign to folder "Eng"
- [ ] Record next week's "Engineering standup" → auto-lands in "Eng" without manual step
- [ ] Standup with different title → stays unfiled until assigned

### Coming up
- [ ] "Add to folder" on agenda row creates rule without recording
- [ ] Row shows folder badge when rule exists
- [ ] Record that event → notes appear in folder

### Delete & edge cases
- [ ] Delete folder → meetings become unfiled; rules removed
- [ ] Rename folder → meetings stay linked; rules unchanged
- [ ] Meeting without calendar title → manual assign only; no rule unless title present
```

## Cost, performance, risk

- **Rules file size:** one entry per unique calendar title — typically <100 entries; read once at launch.
- **Backfill scan:** O(meetings) on rule write — fine for hundreds of meetings; debounce if user bulk-assigns (v1.1).
- **Title collisions:** two different series with identical titles share a folder — acceptable v1; disambiguation (pick calendar, attendees) is v1.1.
- **Renamed calendar events:** organizer renames series → new title → new folder unless user re-assigns; document in UI tooltip.
- **MCP:** folder-aware search deferred; existing tools still work on flat meeting list.

## Decisions — resolved

1. **Match key** → normalized `calendarEventTitle`, fallback to `title` when no calendar match.
2. **Recurring EventKit IDs** → ignored for folder rules; title is the series key.
3. **Flat Meetings list** → unfiled only; filed meetings live under their folder.
4. **Retroactive backfill** → silent on rule create (v1).
5. **Default folder** → none; no auto-created "My notes" unless user creates it.
6. **Folder-scoped chat** → v1.1 (Claude prompt "summarize this folder").
7. **Manual move surfaces** → **Move to…** menu + drag-drop both ship in v1; one shared `FolderPickerMenu`.
8. **Remove from folder** → clears `folderID` only; title rule stays (future recordings still auto-file unless rule is cleared — v1.1: "Stop auto-filing this title").

## Out of scope (later)

- Drag to **reorder** folders or meetings within a folder (ordering is `createdAt` / `sortOrder` only).
- Folder icons, colors, emoji.
- Nested folders / subfolders.
- Export folder as zip or shared link.
- MCP `list_folders` / `search_folder` tools.
- Fuzzy title matching or attendee-based grouping.
- Sync folders across devices (iCloud).
- Auto-create folder from first occurrence without user action.

## Definition of done

Folder system is **complete** when:

1. User can create folders and assign meetings manually via **Move to…**, drag-drop, or detail chip.
2. Recording a calendar-titled event auto-files when a title rule exists.
3. Any manual move into a folder creates the title rule for future occurrences.
4. Sidebar Folders section + folder detail page list all instances of a series.
5. Coming up shows **Add to folder** with correct pre-selection.
6. Drag meeting onto folder row (or **Move to…**) assigns; drag to Unfiled removes.
7. Delete folder unfiles meetings without deleting them.
8. Unit tests cover normalizer, archive, auto-assign; manual checklist passes.
