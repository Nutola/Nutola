import XCTest
@testable import Nutola

final class TranscriptSearchTests: XCTestCase {
    private func makeTurns() -> [TranscriptTurn] {
        let segments = [
            TranscriptSegment(speakerID: "me", start: 0, end: 1, text: "Hello world"),
            TranscriptSegment(speakerID: "s1", start: 1, end: 2, text: "Hi there"),
            TranscriptSegment(speakerID: "me", start: 2, end: 3, text: "Goodbye"),
        ]
        return TranscriptTurnBuilder.turns(from: segments)
    }

    func testEmptySearchReturnsAll() {
        let turns = makeTurns()
        let filtered = TranscriptTurnBuilder.filter(turns: turns, by: "")
        XCTAssertEqual(filtered.count, turns.count)
    }

    func testCaseInsensitiveMatch() {
        let turns = makeTurns()
        let filtered = TranscriptTurnBuilder.filter(turns: turns, by: "HELLO")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.text, "Hello world")
    }

    func testPartialMatch() {
        let turns = makeTurns()
        let filtered = TranscriptTurnBuilder.filter(turns: turns, by: "good")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.text, "Goodbye")
    }

    func testNoResults() {
        let turns = makeTurns()
        let filtered = TranscriptTurnBuilder.filter(turns: turns, by: "nonexistent")
        XCTAssertTrue(filtered.isEmpty)
    }

    func testEmptyTurnsEmptySearch() {
        XCTAssertTrue(TranscriptTurnBuilder.filter(turns: [], by: "").isEmpty)
    }

    func testEmptyTurnsNonEmptySearch() {
        XCTAssertTrue(TranscriptTurnBuilder.filter(turns: [], by: "x").isEmpty)
    }
}
