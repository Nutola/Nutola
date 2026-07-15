# Manual smoke checklist

The audio/ML paths need live TCC grants and Apple Intelligence, which no CI box
has — so they're verified by hand before a release. `swift test` covers the pure
logic (store, labeling, formatting, templates, MCP, HTML export, CLI args).

## Setup
- [ ] `make install` then launch Parfait from /Applications
- [ ] Parfait glass appears in the menu bar; popover opens

## Recording
- [ ] "Start recording" prompts for mic on first use; level meter moves when you talk
- [ ] Play any audio (YouTube) — first recording prompts for System Audio Recording;
      after granting, restart the recording once (macOS quirk: the first grant applies
      to the *next* tap)
- [ ] Stop & summarize → meeting appears, goes `processing` → `ready`
- [ ] Both `mic.m4a` and `system.m4a` exist in the meeting folder (Share → Show files)

## Detection
- [ ] With "Detect meetings" on: start a Zoom/Meet/FaceTime call → notification appears
- [ ] "Record" on the notification starts the session (source app shows in the header)
- [ ] With "Start recording without asking" on: recording starts by itself, and stops
      ~8s after the call app releases the mic

## Pipeline quality
- [ ] Transcript has your words under your name and remote audio under Speaker 1..N
- [ ] With "Identify individual speakers" on and a 2+ person call, remote speakers split
- [ ] Rename a speaker → every segment updates; calendar attendees offered as suggestions
- [ ] Summary follows the selected template's headings; title becomes specific
- [ ] On a Mac without Apple Intelligence (or with a >30 min meeting): summary badge
      says Claude instead of On-device

## Editing
- [ ] Title, summary (Edit), and transcript (Edit as text) all save and survive relaunch
- [ ] Switching template + Regenerate rewrites the notes

## Chat
- [ ] Meeting → Ask Claude: tapping a suggestion chip opens Claude Desktop with a new chat,
      prompt pre-filled, naming the parfait connector and this meeting's id
- [ ] Typing a custom question + "Open in Claude" does the same with the typed text
- [ ] "Ask your meetings" does the same, naming list_meetings/search_meetings/get_meeting
- [ ] With Claude Desktop not installed: chips + button are disabled, a note links to
      claude.ai/download and to Settings → Connect Claude

## Publish
- [ ] Share → Publish to secret Gist returns a URL that renders the styled page in a browser (needs gh)
- [ ] URL lands on the clipboard; "Open published page" works after reselecting the meeting
- [ ] Share → Preview in browser opens the styled page locally (nothing uploaded)
- [ ] Share → Export HTML… writes a self-contained file that opens in a browser
- [ ] With gh not installed, the Gist item is disabled; preview + export still work

## MCP
- [ ] `claude mcp add parfait -s user -- "/Applications/Parfait.app/Contents/MacOS/Parfait" --mcp`
- [ ] In any `claude` session: "list my recent meetings" hits mcp__parfait__list_meetings

## Resilience
- [ ] Quit the app mid-recording, relaunch → orphaned meeting finalizes into a normal one
- [ ] Deny mic but grant system audio → recording still works, notice explains the gap

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
- [ ] Drag onto Meetings section header → Remove from folder
- [ ] Folder row highlights on drag-over; no drop on current folder
- [ ] Recording meeting is not draggable

### Calendar auto-file
- [ ] Record a calendar-titled standup → assign to folder manually
- [ ] Record next week's same-titled standup → auto-lands in that folder
- [ ] Standup with different title → stays unfiled until assigned

### Coming up
- [ ] Click upcoming event → opens prep view with side notes panel
- [ ] Write side notes before meeting → saved and visible on return
- [ ] "Start now" in floating panel begins recording
- [ ] "Add to folder" on agenda row creates rule without recording
- [ ] Row shows folder badge when rule exists
- [ ] Record that event → notes appear in folder

### Delete & edge cases
- [ ] Delete folder → meetings become unfiled; rules removed
- [ ] Rename folder → meetings stay linked; rules unchanged
- [ ] Meeting without calendar title → manual assign only; no rule unless title present
