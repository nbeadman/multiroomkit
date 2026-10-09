import XCTest

final class TerminalInputTests: XCTestCase {
    private func line(_ bytes: [UInt8]) throws -> String {
        var remaining = bytes.makeIterator()
        return try PrivateTerminal.readLine { remaining.next() }
    }

    func testCompleteLinePreservesInput() throws {
        XCTAssertEqual(try line(Array("synthetic-value\n".utf8)), "synthetic-value")
        XCTAssertEqual(try line(Array("synthetic-value\r".utf8)), "synthetic-value")
    }

    func testEmptyInputIsNotMisreportedAsAuthenticationFailure() {
        XCTAssertThrowsError(try line([10])) { error in
            guard case TerminalInteractionError.emptyInput = error else { return XCTFail("Expected an empty-input diagnostic") }
        }
    }

    func testEOFDoesNotAcceptAnIncompleteCredential() {
        XCTAssertThrowsError(try line(Array("synthetic-partial".utf8))) { error in
            guard case TerminalInteractionError.endOfInput = error else { return XCTFail("Expected an EOF diagnostic") }
        }
    }

    func testReadFailureIsNotMisreportedAsAuthenticationFailure() {
        XCTAssertThrowsError(try PrivateTerminal.readLine { throw TerminalInteractionError.readFailed }) { error in
            guard case TerminalInteractionError.readFailed = error else { return XCTFail("Expected a terminal-read diagnostic") }
        }
    }

    func testOversizedAndInvalidUTF8InputAreRejected() {
        XCTAssertThrowsError(try line(Array(repeating: UInt8(65), count: 4097) + [10]))
        XCTAssertThrowsError(try line([255, 10]))
    }
}
