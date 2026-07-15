import Foundation

/// Inline MCP config for Claude Code CLI runs that need the Parfait meeting archive.
enum ParfaitMCP {
    static var binaryPath: String {
        Bundle.main.executablePath ?? "/Applications/Parfait.app/Contents/MacOS/Parfait"
    }

    static let allowedTools = [
        "mcp__parfait__list_meetings",
        "mcp__parfait__search_meetings",
        "mcp__parfait__get_meeting",
        "mcp__parfait__get_transcript",
        "mcp__parfait__get_live_transcript",
        "mcp__parfait__list_templates",
    ]

    static var configJSON: String {
        """
        {"mcpServers":{"parfait":{"command":"\(binaryPath)","args":["--mcp"]}}}
        """
    }
}
