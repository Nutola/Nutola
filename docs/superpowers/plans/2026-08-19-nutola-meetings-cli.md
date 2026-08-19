# Nutola Meetings CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only meetings CLI backed by the same behavior as Nutola's MCP meeting tools, then install a Codex skill that uses that CLI for reliable transcript access.

**Architecture:** Extract the five MCP read operations into `MeetingCommandService`, leaving write/template behavior in `MCPServer`. Add a small argument parser and injectable CLI runner, route only `meetings` arguments through it in `Bootstrap`, and keep GUI and `--mcp` routing unchanged. Install a personal Codex skill that calls the absolute application binary and treats MCP as a compatibility fallback.

**Tech Stack:** Swift 6.2, Swift Package Manager, XCTest, macOS command-line process I/O, Markdown Codex skill.

## Global Constraints

- Preserve all existing MCP tool names, schemas, and text output.
- Preserve no-argument GUI launch and `--mcp` behavior.
- CLI commands are read-only and output human-readable text.
- Successful output goes to stdout with exit code `0`; validation and lookup failures go to stderr with a non-zero exit code.
- `limit` is clamped to `1...200`; `offset` must be non-negative.
- The skill prefers `/Applications/Nutola.app/Contents/MacOS/Nutola` CLI commands and retains MCP only as a fallback.
- Do not migrate or rewrite meeting files.

---

### Task 1: Shared Meeting Read Service

**Files:**
- Create: `Sources/Nutola/CLI/MeetingCommandService.swift`
- Modify: `Sources/Nutola/MCP/MCPServer.swift`
- Test: `Tests/NutolaTests/MeetingCommandServiceTests.swift`
- Test: `Tests/NutolaTests/MCPServerTests.swift`

**Interfaces:**
- Consumes: `MeetingArchive`, `Meeting`, `TranscriptFormatter`.
- Produces: `MeetingCommandService.init(archive:)`, `list(limit:offset:)`, `search(query:limit:offset:)`, `show(id:)`, `transcript(id:)`, and `live(minutes:)`, all returning `String` and throwing `MeetingCommandError` where lookup or input validation can fail.

- [ ] **Step 1: Write failing service and parity tests**

Create fixtures with one ready meeting, summary, transcript, and speakers. Assert exact list/search/show/transcript strings, pagination hints, malformed UUID behavior, missing meeting behavior, and default/whole live transcript behavior. Extend `MCPServerTests` to assert each read tool returns the same text as the service call.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `swift test --filter MeetingCommandServiceTests && swift test --filter MCPServerTests`

Expected: compilation fails because `MeetingCommandService` does not exist.

- [ ] **Step 3: Implement the shared read service**

Define:

```swift
enum MeetingCommandError: LocalizedError, Equatable {
    case badArgument(String)
    case notFound(String)
}

final class MeetingCommandService {
    let archive: MeetingArchive

    init(archive: MeetingArchive) { self.archive = archive }
    func list(limit: Int = 20, offset: Int = 0) -> String
    func search(query: String, limit: Int = 20, offset: Int = 0) throws -> String
    func show(id: String) throws -> String
    func transcript(id: String) throws -> String
    func live(minutes: Int? = nil) throws -> String
}
```

Move the existing read-only formatting and pagination behavior from `MCPServer.call` into these methods. Move or expose `describe`, meeting-ID lookup, and live transcript formatting only as needed so the service owns read behavior.

- [ ] **Step 4: Route MCP reads through the service**

Add a `MeetingCommandService` property initialized from the same archive. Replace the five read cases with direct calls while leaving every write/template case unchanged:

```swift
case "list_meetings":
    return reads.list(limit: arguments["limit"] as? Int ?? 20,
                      offset: arguments["offset"] as? Int ?? 0)
case "search_meetings":
    return try reads.search(query: arguments["query"] as? String ?? "",
                            limit: arguments["limit"] as? Int ?? 20,
                            offset: arguments["offset"] as? Int ?? 0)
```

- [ ] **Step 5: Run focused tests and commit**

Run: `swift test --filter MeetingCommandServiceTests && swift test --filter MCPServerTests`

Expected: both suites pass.

Commit message: `Add shared meeting read service` with the required Codex trailer.

### Task 2: Meetings CLI Parser and Runner

**Files:**
- Create: `Sources/Nutola/CLI/MeetingsCLI.swift`
- Test: `Tests/NutolaTests/MeetingsCLITests.swift`

**Interfaces:**
- Consumes: `MeetingCommandService` methods from Task 1.
- Produces: `MeetingsCLI.Command`, `MeetingsCLI.parse(arguments:)`, and `MeetingsCLI.run(arguments:output:error:) -> Int32`.

- [ ] **Step 1: Write failing parser tests**

Assert parsing for `help`, `list`, `search`, `show`, `transcript`, and `live`, including `--limit`, `--offset`, and `--minutes`. Assert simple multiword search joins remaining positional terms. Assert unknown commands/flags, missing UUID/query, non-integer values, negative offset/minutes, and extra arguments throw a usage error.

- [ ] **Step 2: Run parser tests and verify failure**

Run: `swift test --filter MeetingsCLITests`

Expected: compilation fails because `MeetingsCLI` does not exist.

- [ ] **Step 3: Implement command parsing**

Define commands with associated values:

```swift
enum Command: Equatable {
    case help
    case list(limit: Int, offset: Int)
    case search(query: String, limit: Int, offset: Int)
    case show(id: String)
    case transcript(id: String)
    case live(minutes: Int?)
}
```

Parse options without external dependencies. Reject duplicate options and unknown flags. Validate UUID syntax for `show` and `transcript` before service dispatch.

- [ ] **Step 4: Write failing runner I/O tests**

Inject closures `(String) -> Void` for stdout and stderr. Assert help and successful service results only populate stdout and return `0`. Assert parser errors and `MeetingCommandError` only populate stderr, include concise usage, and return `2` or `1` respectively.

- [ ] **Step 5: Implement the runner**

Dispatch parsed commands to the service and return stable exit statuses. Expose a static usage string covering every supported command. Do not call `exit()` inside the runner so XCTest can exercise it.

- [ ] **Step 6: Run focused tests and commit**

Run: `swift test --filter MeetingsCLITests`

Expected: all CLI parser and runner tests pass.

Commit message: `Add read-only meetings CLI` with the required Codex trailer.

### Task 3: Bootstrap Routing and Backward Compatibility

**Files:**
- Modify: `Sources/Nutola/Bootstrap.swift`
- Test: `Tests/NutolaTests/BootstrapTests.swift`

**Interfaces:**
- Consumes: `MeetingsCLI.run(arguments:output:error:)`.
- Produces: `Bootstrap.route(arguments:)` or equivalent testable routing decision that distinguishes version, MCP, meetings CLI, and GUI.

- [ ] **Step 1: Write failing routing tests**

Assert no args routes to GUI, `--mcp` routes to MCP, `--version` routes to version, and arguments beginning with `meetings` route to CLI. Assert unrelated arguments retain the existing GUI behavior.

- [ ] **Step 2: Run routing tests and verify failure**

Run: `swift test --filter BootstrapTests`

Expected: compilation fails because the testable route does not exist.

- [ ] **Step 3: Implement bootstrap routing**

Keep SIGPIPE and crash diagnostics initialization. Route `Array(CommandLine.arguments.dropFirst())` through a small enum. For `.meetings(arguments)`, construct `MeetingArchive`, `MeetingCommandService`, and `MeetingsCLI`, then terminate with the runner's status only when non-zero; all other routes preserve current behavior.

- [ ] **Step 4: Run CLI/MCP/bootstrap tests and commit**

Run: `swift test --filter 'MeetingsCLI|MeetingCommandService|MCPServer|Bootstrap'`

Expected: all focused suites pass.

Commit message: `Route meeting commands from Nutola bootstrap` with the required Codex trailer.

### Task 4: CLI Documentation and Codex Skill

**Files:**
- Modify: `README.md`
- Create: `/Users/matheus.gois/.codex/skills/nutola-meetings/SKILL.md`

**Interfaces:**
- Consumes: installed CLI command surface from Tasks 2 and 3.
- Produces: user documentation and a discoverable `nutola-meetings` Codex skill.

- [ ] **Step 1: Capture the pre-skill baseline**

Confirm `/Users/matheus.gois/.codex/skills/nutola-meetings/SKILL.md` is absent and record that the current task cannot invoke Nutola unless MCP discovery succeeds.

- [ ] **Step 2: Add README CLI reference**

Document all six commands, absolute installed binary examples, pagination behavior, stdout/stderr contract, read-only scope, and that MCP remains supported.

- [ ] **Step 3: Create the skill**

Use frontmatter:

```yaml
---
name: nutola-meetings
description: Read Nutola meeting notes and transcripts through the local Nutola CLI. Use when asked about recent meetings, meeting transcripts, decisions, commitments, follow-ups, blockers, forgotten tasks, or what was discussed in Nutola, especially when the MCP connector is unavailable.
---
```

Instruct the agent to prefer `/Applications/Nutola.app/Contents/MacOS/Nutola meetings ...`, use list before targeted reads, search by topic/person/project, fetch full transcripts for attribution, use live only for active meetings, distinguish direct evidence from inference, report missing transcripts, and never use write operations. Retain MCP read tools as a fallback for older installed builds only.

- [ ] **Step 4: Validate documentation and skill**

Run a frontmatter/command-reference check and inspect the rendered instruction length. Verify every command in README and SKILL matches CLI help exactly.

- [ ] **Step 5: Commit repository documentation**

Commit message: `Document Nutola meetings CLI` with the required Codex trailer. The personal skill remains outside the repository commit.

### Task 5: Full Verification and Installation

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: complete feature from Tasks 1-4.
- Produces: installed working app and evidence from real local meeting data.

- [ ] **Step 1: Run formatting and full tests**

Run: `swift test`

Expected: complete suite passes with zero failures.

- [ ] **Step 2: Build and install the application**

Run: `make install`

Expected: `/Applications/Nutola.app/Contents/MacOS/Nutola` is replaced by the new signed build.

- [ ] **Step 3: Smoke-test installed CLI against real data**

Run:

```bash
/Applications/Nutola.app/Contents/MacOS/Nutola meetings help
/Applications/Nutola.app/Contents/MacOS/Nutola meetings list --limit 3
/Applications/Nutola.app/Contents/MacOS/Nutola meetings search Paulo --limit 2
```

Extract one UUID from list output and run both `show` and `transcript`. Confirm exit code `0`, populated stdout, and no stderr. Run one malformed UUID command and confirm non-zero status with stderr only.

- [ ] **Step 4: Confirm backward compatibility**

Send MCP `initialize`, `tools/list`, and one `list_meetings` JSON-RPC line to the installed binary with `--mcp`. Confirm no-argument app launch routing still compiles and is covered by tests; do not launch a duplicate GUI instance during automated verification.

- [ ] **Step 5: Review final diff and commit state**

Run: `git diff --check`, `git status --short`, and `git log --oneline --decorate -8`.

Expected: no whitespace errors, no uncommitted repository changes, and the personal skill exists at its absolute path.
