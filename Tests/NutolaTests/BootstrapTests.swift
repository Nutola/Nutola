import XCTest
@testable import Nutola

final class BootstrapTests: XCTestCase {
    func testNoArgumentsRouteToGUI() {
        XCTAssertEqual(Bootstrap.route(arguments: []), .app)
    }

    func testVersionAndMCPRetainExistingRouting() {
        XCTAssertEqual(Bootstrap.route(arguments: ["--version"]), .version)
        XCTAssertEqual(Bootstrap.route(arguments: ["--mcp"]), .mcp)
        XCTAssertEqual(Bootstrap.route(arguments: ["ignored", "--version"]), .version)
        XCTAssertEqual(Bootstrap.route(arguments: ["ignored", "--mcp"]), .mcp)
    }

    func testMeetingsPrefixRoutesToCLI() {
        XCTAssertEqual(
            Bootstrap.route(arguments: ["meetings"]),
            .meetings(arguments: ["meetings"])
        )
        XCTAssertEqual(
            Bootstrap.route(arguments: ["meetings", "list", "--limit", "3"]),
            .meetings(arguments: ["meetings", "list", "--limit", "3"])
        )
    }

    func testExistingFlagsTakePrecedenceOverMeetings() {
        XCTAssertEqual(Bootstrap.route(arguments: ["meetings", "--version"]), .version)
        XCTAssertEqual(Bootstrap.route(arguments: ["meetings", "--mcp"]), .mcp)
    }

    func testUnrelatedArgumentsKeepLaunchingGUI() {
        XCTAssertEqual(Bootstrap.route(arguments: ["unexpected"]), .app)
        XCTAssertEqual(Bootstrap.route(arguments: ["--legacy-flag"]), .app)
    }
}
