import XCTest
@testable import Nutola

final class JaroWinklerTests: XCTestCase {
    func testIdenticalStrings() {
        XCTAssertEqual(JaroWinkler.similarity("nutola", "nutola"), 1.0, accuracy: 0.0001)
    }

    func testEmptyStrings() {
        XCTAssertEqual(JaroWinkler.similarity("", ""), 1.0, accuracy: 0.0001)
        XCTAssertEqual(JaroWinkler.similarity("abc", ""), 0.0, accuracy: 0.0001)
    }

    func testCloseTypo() {
        // "nutola" vs "nutoa" — missing one letter. Should score high (>0.9).
        let score = JaroWinkler.similarity("nutola", "nutoa")
        XCTAssertGreaterThan(score, 0.9)
    }

    func testUnrelated() {
        let score = JaroWinkler.similarity("nutola", "banana")
        XCTAssertLessThan(score, 0.6)
    }

    func testCommonPrefixBonus() {
        // Strings sharing a 4-char prefix score higher than same-jaro pairs
        // with a shorter prefix.
        let withPrefix = JaroWinkler.similarity("martha", "marhta")
        XCTAssertGreaterThan(withPrefix, 0.95)
    }
}
