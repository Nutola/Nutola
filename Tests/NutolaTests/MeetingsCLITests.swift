import XCTest
@testable import Nutola

final class MeetingsCLITests: XCTestCase {
    private let id = "123E4567-E89B-12D3-A456-426614174000"

    func testParsesEveryCommand() throws {
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["help"]), .help)
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["list"]), .list(limit: 20, offset: 0))
        XCTAssertEqual(
            try MeetingsCLI.parse(arguments: ["list", "--limit", "250", "--offset", "4"]),
            .list(limit: 200, offset: 4)
        )
        XCTAssertEqual(
            try MeetingsCLI.parse(arguments: ["search", "device", "token", "--limit", "5", "--offset", "2"]),
            .search(query: "device token", limit: 5, offset: 2)
        )
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["show", id]), .show(id: id))
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["transcript", id]), .transcript(id: id))
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["live"]), .live(minutes: nil))
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["live", "--minutes", "0"]), .live(minutes: 0))
    }

    func testMeetingsPrefixAndNoCommandShowHelp() throws {
        XCTAssertEqual(try MeetingsCLI.parse(arguments: []), .help)
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["meetings"]), .help)
        XCTAssertEqual(try MeetingsCLI.parse(arguments: ["meetings", "help"]), .help)
        XCTAssertEqual(
            try MeetingsCLI.parse(arguments: ["meetings", "list", "--limit", "3"]),
            .list(limit: 3, offset: 0)
        )
    }

    func testRejectsMalformedSyntaxAndValues() {
        assertUsageError(["unknown"], contains: "Unknown meetings command")
        assertUsageError(["list", "--wat"], contains: "Unknown option")
        assertUsageError(["list", "--limit"], contains: "requires a value")
        assertUsageError(["list", "--limit", "many"], contains: "must be an integer")
        assertUsageError(["list", "--offset", "-1"], contains: "must be non-negative")
        assertUsageError(["list", "--limit", "2", "--limit", "3"], contains: "Duplicate option")
        assertUsageError(["search"], contains: "Search query is required")
        assertUsageError(["show"], contains: "Meeting UUID is required")
        assertUsageError(["show", "bad-id"], contains: "must be a meeting UUID")
        assertUsageError(["show", id, "extra"], contains: "Unexpected argument")
        assertUsageError(["transcript", "bad-id"], contains: "must be a meeting UUID")
        assertUsageError(["live", "--minutes", "-2"], contains: "must be non-negative")
    }

    func testSuccessfulRunnerWritesOnlyStdout() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutola-cli-success-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = MeetingArchive(root: root)
        var meeting = Meeting(title: "Daily sync", createdAt: Date())
        meeting.state = .ready
        try archive.createFolder(for: meeting.id)
        try archive.save(meeting)

        var output: [String] = []
        var errors: [String] = []
        let cli = MeetingsCLI(service: MeetingCommandService(archive: archive))

        let status = cli.run(
            arguments: ["list"],
            output: { output.append($0) },
            error: { errors.append($0) }
        )

        XCTAssertEqual(status, 0)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(output.count, 1)
        XCTAssertTrue(output[0].contains("Daily sync"))
    }

    func testHelpWritesOnlyStdout() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutola-cli-help-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        var output: [String] = []
        var errors: [String] = []
        let cli = MeetingsCLI(service: MeetingCommandService(archive: MeetingArchive(root: root)))

        let status = cli.run(
            arguments: ["help"],
            output: { output.append($0) },
            error: { errors.append($0) }
        )

        XCTAssertEqual(status, 0)
        XCTAssertTrue(output.joined().contains("Nutola meetings list"))
        XCTAssertEqual(errors, [])
    }

    func testParserFailureWritesUsageToStderrAndReturnsTwo() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutola-cli-parser-error-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        var output: [String] = []
        var errors: [String] = []
        let cli = MeetingsCLI(service: MeetingCommandService(archive: MeetingArchive(root: root)))

        let status = cli.run(
            arguments: ["list", "--offset", "-1"],
            output: { output.append($0) },
            error: { errors.append($0) }
        )

        XCTAssertEqual(status, 2)
        XCTAssertEqual(output, [])
        XCTAssertTrue(errors.joined().contains("must be non-negative"))
        XCTAssertTrue(errors.joined().contains("Usage:"))
    }

    func testServiceFailureWritesOnlyStderrAndReturnsOne() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutola-cli-service-error-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        var output: [String] = []
        var errors: [String] = []
        let cli = MeetingsCLI(service: MeetingCommandService(archive: MeetingArchive(root: root)))

        let status = cli.run(
            arguments: ["show", id],
            output: { output.append($0) },
            error: { errors.append($0) }
        )

        XCTAssertEqual(status, 1)
        XCTAssertEqual(output, [])
        XCTAssertEqual(errors, ["Error: No meeting with id \(id)"])
    }

    private func assertUsageError(
        _ arguments: [String],
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try MeetingsCLI.parse(arguments: arguments), file: file, line: line) { error in
            XCTAssertTrue(error.localizedDescription.contains(expected), "\(error)", file: file, line: line)
        }
    }
}
