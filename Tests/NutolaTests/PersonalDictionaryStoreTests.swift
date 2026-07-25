import XCTest
@testable import Nutola

final class PersonalDictionaryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "test-personal-dict-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeStore() -> PersonalDictionaryStore {
        PersonalDictionaryStore(defaults: defaults, key: "test-personal-dict")
    }

    func testEmptyStoreLeavesTextUntouched() {
        let store = makeStore()
        XCTAssertEqual(store.apply(to: "hello world"), "hello world")
    }

    func testPhraseMatchExactReplacement() {
        let store = makeStore()
        store.add(.init(word: "AI", phraseMatch: "artificial intelligence", replacement: "AI"))
        XCTAssertEqual(
            store.apply(to: "We discussed artificial intelligence today."),
            "We discussed AI today.")
    }

    func testPhraseMatchCaseInsensitive() {
        let store = makeStore()
        store.add(.init(word: "AI", phraseMatch: "Artificial Intelligence", replacement: "AI"))
        XCTAssertEqual(
            store.apply(to: "we talked about artificial intelligence"),
            "we talked about AI")
    }

    func testWordFuzzyReplacementCatchesTypo() {
        let store = makeStore()
        store.add(.init(word: "Nutola", replacement: "Nutola", minSimilarity: 0.85))
        XCTAssertEqual(
            store.apply(to: "I use Nutoa every day"),
            "I use Nutola every day")
    }

    func testWordOnlyEntryIsNoOp() {
        // A word with no replacement is a vocabulary hint — text unchanged.
        let store = makeStore()
        store.add(.init(word: "Nutola", replacement: nil))
        XCTAssertEqual(store.apply(to: "I use Nutola"), "I use Nutola")
    }

    func testDoesNotReplaceBelowSimilarityThreshold() {
        let store = makeStore()
        store.add(.init(word: "Nutola", replacement: "Nutola", minSimilarity: 0.95))
        // "banana" is far below 0.95 — must stay.
        XCTAssertEqual(store.apply(to: "I ate a banana"), "I ate a banana")
    }

    func testRoundTripPersistence() {
        let store = makeStore()
        store.add(.init(word: "DD", phraseMatch: "DoorDash", replacement: "DoorDash"))
        let store2 = makeStore()
        XCTAssertTrue(store2.hasAny)
        XCTAssertEqual(store2.entries.first?.replacement, "DoorDash")
    }
}
