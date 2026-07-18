import XCTest
@testable import Nutola

final class TranscriptFormatterTests: XCTestCase {
    let speakers = [
        Speaker(id: "me", name: "Me", isMe: true),
        Speaker(id: "s1", name: "Alice"),
        Speaker(id: "s2", name: "Bob"),
    ]

    let segments = [
        TranscriptSegment(speakerID: "me", start: 0, end: 5, text: "Hello world"),
        TranscriptSegment(speakerID: "s1", start: 5, end: 10, text: "Hi there"),
        TranscriptSegment(speakerID: "s2", start: 10, end: 15, text: "Good to see you"),
    ]

    // MARK: - SRT

    func testSRTFormat() {
        let srt = TranscriptFormatter.srt(segments, speakers: speakers)

        // Sequential indices for each segment.
        XCTAssertTrue(srt.contains("1\n"))
        XCTAssertTrue(srt.contains("2\n"))
        XCTAssertTrue(srt.contains("3\n"))

        // Comma-separated SRT timestamps.
        XCTAssertTrue(srt.contains("00:00:00,000 --> 00:00:05,000"))
        XCTAssertTrue(srt.contains("00:00:05,000 --> 00:00:10,000"))
        XCTAssertTrue(srt.contains("00:00:10,000 --> 00:00:15,000"))

        // Speaker name prefix on cue lines.
        XCTAssertTrue(srt.contains("Me: Hello world"))
        XCTAssertTrue(srt.contains("Alice: Hi there"))
        XCTAssertTrue(srt.contains("Bob: Good to see you"))

        // Entries are blank-line separated (three entries → two double-newlines).
        XCTAssertEqual(srt.components(separatedBy: "\n\n").count, 3)
    }

    func testSRTEmpty() {
        XCTAssertEqual(TranscriptFormatter.srt([], speakers: speakers), "")
    }

    func testSRTUnknownSpeakerFallsBackToID() {
        let seg = [TranscriptSegment(speakerID: "ghost", start: 0, end: 1, text: "Boo")]
        let srt = TranscriptFormatter.srt(seg, speakers: speakers)
        XCTAssertTrue(srt.contains("ghost: Boo"))
    }

    // MARK: - VTT

    func testVTTFormat() {
        let vtt = TranscriptFormatter.vtt(segments, speakers: speakers)

        // Header.
        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n"))

        // Dot-separated VTT timestamps.
        XCTAssertTrue(vtt.contains("00:00:00.000 --> 00:00:05.000"))
        XCTAssertTrue(vtt.contains("00:00:05.000 --> 00:00:10.000"))
        XCTAssertTrue(vtt.contains("00:00:10.000 --> 00:00:15.000"))

        // WebVTT speaker tags; no sequential indices.
        XCTAssertTrue(vtt.contains("<v Me> Hello world"))
        XCTAssertTrue(vtt.contains("<v Alice> Hi there"))
        XCTAssertTrue(vtt.contains("<v Bob> Good to see you"))
        XCTAssertFalse(vtt.contains("\n1\n"))
        XCTAssertFalse(vtt.contains("\n2\n"))

        // Three cues separated by blank lines (after the header).
        let body = vtt.dropFirst("WEBVTT\n\n".count)
        XCTAssertEqual(body.components(separatedBy: "\n\n").count, 3)
    }

    func testVTTEmpty() {
        // No segments → just the header.
        XCTAssertEqual(TranscriptFormatter.vtt([], speakers: speakers), "WEBVTT\n\n")
    }

    func testVTTUnknownSpeakerFallsBackToID() {
        let seg = [TranscriptSegment(speakerID: "ghost", start: 0, end: 1, text: "Boo")]
        let vtt = TranscriptFormatter.vtt(seg, speakers: speakers)
        XCTAssertTrue(vtt.contains("<v ghost> Boo"))
    }

    // MARK: - subtitleTimestamp (via srt/vtt output)

    func testSubtitleTimestampAtZero() {
        let seg = [TranscriptSegment(speakerID: "me", start: 0, end: 0, text: "Go")]
        let srt = TranscriptFormatter.srt(seg, speakers: speakers)
        XCTAssertTrue(srt.contains("00:00:00,000 --> 00:00:00,000"))
    }

    func testSubtitleTimestampAt65Seconds() {
        // 65s → 00:01:05
        let seg = [TranscriptSegment(speakerID: "me", start: 65, end: 66, text: "Go")]
        let srt = TranscriptFormatter.srt(seg, speakers: speakers)
        XCTAssertTrue(srt.contains("00:01:05,000 --> 00:01:06,000"))
    }

    func testSubtitleTimestampAt3661Seconds() {
        // 3661s = 1h 1m 1s → 01:01:01
        let seg = [TranscriptSegment(speakerID: "me", start: 3661, end: 3662, text: "Go")]
        let vtt = TranscriptFormatter.vtt(seg, speakers: speakers)
        XCTAssertTrue(vtt.contains("01:01:01.000 --> 01:01:02.000"))
    }

    func testSubtitleTimestampMilliseconds() {
        // Fractional seconds round to the nearest millisecond.
        let seg = [TranscriptSegment(speakerID: "me", start: 1.234, end: 2.567, text: "Go")]
        let srt = TranscriptFormatter.srt(seg, speakers: speakers)
        XCTAssertTrue(srt.contains("00:00:01,234 --> 00:00:02,567"))
    }
}
