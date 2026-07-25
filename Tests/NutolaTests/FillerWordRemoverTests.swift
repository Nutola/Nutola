import XCTest
@testable import Nutola

final class FillerWordRemoverTests: XCTestCase {
    func testRemovesStandaloneFillers() {
        XCTAssertEqual(
            FillerWordRemover.clean("uh so I think we should um go with that"),
            "so I think we should go with that")
    }

    func testPreservesPunctuation() {
        XCTAssertEqual(
            FillerWordRemover.clean("I, um, was thinking, uh, maybe later"),
            "I, was thinking, maybe later")
    }

    func testDoesNotMatchSubstrings() {
        // "um" inside "album" must stay.
        XCTAssertEqual(
            FillerWordRemover.clean("the album is um amazing"),
            "the album is amazing")
    }

    func testPortugueseFillers() {
        XCTAssertEqual(
            FillerWordRemover.clean("tipo, a gente faz assim né"),
            "a gente faz assim")
    }

    func testCollapsesMultipleSpaces() {
        XCTAssertEqual(
            FillerWordRemover.clean("hmm let me see hmm okay"),
            "let me see okay")
    }

    func testTrailingFiller() {
        XCTAssertEqual(
            FillerWordRemover.clean("trailing filler um"),
            "trailing filler")
    }
    func testNoFillers() {
        let input = "no fillers here at all"
        XCTAssertEqual(FillerWordRemover.clean(input), input)
    }

    func testEmpty() {
        XCTAssertEqual(FillerWordRemover.clean(""), "")
    }

    func testCustomFillerSet() {
        XCTAssertEqual(
            FillerWordRemover.clean("yknow like whatever", fillers: ["yknow", "like"]),
            "whatever")
    }
}
