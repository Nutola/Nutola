import XCTest
@testable import Parfait

final class GitHubGistTests: XCTestCase {
    // MARK: - renderedURL

    func testMapsModernThirtyTwoHexGist() {
        let raw = "https://gist.githubusercontent.com/conrad-vanl/" +
            "0123456789abcdef0123456789abcdef/raw/" +
            "abcdef0123456789abcdef0123456789abcdef01/meeting.html"
        let url = GitHubGist.renderedURL(fromRaw: raw)
        XCTAssertEqual(
            url?.absoluteString,
            "https://notes.parfait.to/conrad-vanl/" +
                "0123456789abcdef0123456789abcdef/raw/" +
                "abcdef0123456789abcdef0123456789abcdef01/meeting.html")
    }

    func testMapsLegacyTwentyHexGist() {
        let raw = "https://gist.githubusercontent.com/conrad-vanl/" +
            "0123456789abcdef0123/raw/" +
            "abcdef0123456789abcdef0123456789abcdef01/meeting.html"
        let url = GitHubGist.renderedURL(fromRaw: raw)
        XCTAssertEqual(
            url?.absoluteString,
            "https://notes.parfait.to/conrad-vanl/" +
                "0123456789abcdef0123/raw/" +
                "abcdef0123456789abcdef0123456789abcdef01/meeting.html")
    }

    func testEmptyRawStringYieldsNil() {
        // Foundation's URL(string:) percent-encodes almost anything successfully (even
        // stray whitespace/control characters), so an empty raw string — the shape
        // GitHubGist.publish() actually observes when gh's raw_url lookup comes back
        // blank — is the one malformed case renderedURL guards explicitly.
        XCTAssertNil(GitHubGist.renderedURL(fromRaw: ""))
    }
}
