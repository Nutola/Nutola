# Nutola Meetings CLI and Codex Skill Design

## Goal

Make Nutola meeting notes and transcripts reliably readable from Codex without requiring MCP tool discovery. Keep the existing MCP server working for backward compatibility while making a read-only CLI the preferred interface for agent workflows.

## Scope

The first version exposes only meeting-library reads:

```text
Nutola meetings list [--limit N] [--offset N]
Nutola meetings search <query> [--limit N] [--offset N]
Nutola meetings show <meeting-uuid>
Nutola meetings transcript <meeting-uuid>
Nutola meetings live [--minutes N]
Nutola meetings help
```

Running `Nutola` without a recognized CLI command continues to launch the macOS app. Running `Nutola --mcp` continues to start the existing stdio MCP server. Template mutation, summary regeneration, meeting deletion, and other writes remain outside the CLI in this version.

## Architecture

Introduce a read-only meeting command service that owns the behavior currently embedded in the MCP handlers:

- list meetings with pagination
- search titles, summaries, transcripts, and attendees with pagination
- render meeting metadata and summary
- render a stored transcript
- render the recent or complete live transcript

Both `MCPServer` and the new CLI adapter call this service. The service depends on `MeetingArchive` and returns plain text or typed errors. The MCP layer remains responsible only for JSON-RPC decoding and response encoding. The CLI layer remains responsible only for argument parsing, stdout/stderr, and exit codes.

This preserves one implementation of search, pagination, formatting, UUID validation, and live-meeting freshness checks.

## CLI Behavior

### General

- Print successful command output to stdout.
- Print usage and validation errors to stderr.
- Return exit code `0` on success and non-zero on invalid syntax, invalid values, or missing meetings.
- Clamp `limit` to the existing `1...200` range and require non-negative `offset`.
- Treat all remaining positional words after `search` as one query so shell quoting is optional for simple searches.
- Keep output human-readable and stable enough for a skill to parse meeting UUIDs from the existing `[UUID] Title` format.

### Commands

`meetings list` returns newest meetings first and includes `next_offset` when more results remain.

`meetings search` uses the existing archive full-text ranking and includes matching transcript excerpts and `next_offset`.

`meetings show` returns metadata, attendees, speakers, and the stored summary.

`meetings transcript` returns the full stored transcript with speaker names and timestamps.

`meetings live` reuses the existing freshness guard. `--minutes` defaults to the current six-minute window; `0` returns the complete live transcript.

`meetings help`, `Nutola help`, and invalid subcommands print concise usage.

## Backward Compatibility

- Keep every existing MCP tool and schema unchanged.
- Preserve the current MCP text output for meeting reads by routing them through the shared service.
- Keep `NutolaMCP` and assistant setup UI unchanged.
- Keep the default GUI launch behavior unchanged.
- Do not migrate or rewrite meeting files.

## Codex Skill

Create the personal skill `nutola-meetings` under `~/.codex/skills/nutola-meetings/`.

The skill triggers for requests involving Nutola meetings, recent meeting notes, transcripts, forgotten commitments, decisions, follow-ups, or action-item extraction. It uses the installed binary:

```text
/Applications/Nutola.app/Contents/MacOS/Nutola
```

The workflow is:

1. Run `meetings list` to identify recent meeting UUIDs.
2. Use `meetings search` for named topics, people, projects, commitments, or blockers.
3. Use `meetings show` for summary context.
4. Use `meetings transcript` when precise attribution or missing details matter.
5. Use `meetings live` only when the user asks about an active meeting.
6. Clearly distinguish direct transcript evidence from inference and report meetings without transcripts.

The skill must prefer the CLI even when the legacy MCP connector is available. It must not edit or delete meetings.

## Installation and Documentation

Update the README with the CLI command reference and examples. `make install` remains the way to install the updated app binary. No extra wrapper or symlink is required because the skill uses the absolute installed binary path.

## Error Handling

Define errors for:

- missing command or required argument
- unknown command or flag
- non-integer or out-of-range numeric option
- malformed meeting UUID
- meeting not found

Empty libraries, empty search results, meetings without summaries, meetings without transcripts, and no active recording remain successful informational results, matching current MCP behavior.

## Testing

Add focused unit tests before implementation:

- parser recognizes every supported command and option
- parser rejects malformed syntax, unknown flags, and invalid numeric values
- list/search preserve pagination and result formatting
- show/transcript return expected content and errors
- live command preserves default, explicit, and whole-meeting windows
- CLI exit status and stdout/stderr routing are correct through an injectable runner
- MCP read tests continue passing and prove output parity through the shared service
- app launch and `--mcp` argument routing remain unchanged

Run focused CLI/MCP tests first, then the complete `swift test` suite.

## Non-Goals

- Removing MCP support
- Adding write commands
- Adding JSON output in the first version
- Changing search ranking or transcript storage
- Installing a daemon or network service
- Exposing Nutola data outside the local machine
