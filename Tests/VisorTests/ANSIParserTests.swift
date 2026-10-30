import XCTest
@testable import Visor

final class ANSIParserTests: XCTestCase {
    func testPlainTextIsPreserved() {
        var parser = ANSIParser()
        XCTAssertEqual(parser.parse(Data("hello\n".utf8), fontSize: 14).string, "hello\n")
    }

    func testSGRSequencesAreRemoved() {
        var parser = ANSIParser()
        let output = parser.parse(Data("plain \u{1B}[31mred\u{1B}[0m done".utf8), fontSize: 14)
        XCTAssertEqual(output.string, "plain red done")
    }

    func testSplitSequenceIsBuffered() {
        var parser = ANSIParser()
        XCTAssertEqual(parser.parse(Data("a\u{1B}[3".utf8), fontSize: 14).string, "a")
        XCTAssertEqual(parser.parse(Data("2mb".utf8), fontSize: 14).string, "b")
    }

    func testCursorControlDoesNotSwallowFollowingOutput() {
        var parser = ANSIParser()
        let output = parser.parse(Data("\u{1B}[?2004hcommand\r\nresult\u{1B}[?2004l".utf8), fontSize: 14)
        XCTAssertEqual(output.string, "command\nresult")
    }

    func testSplitCursorSequenceIsBuffered() {
        var parser = ANSIParser()
        XCTAssertEqual(parser.parse(Data("\u{1B}[?20".utf8), fontSize: 14).string, "")
        XCTAssertEqual(parser.parse(Data("04hvisible".utf8), fontSize: 14).string, "visible")
    }

    func testWindowTitleSequenceIsRemovedWithoutLosingText() {
        var parser = ANSIParser()
        let output = parser.parse(Data("\u{1B}]0;zsh\u{07}prompt".utf8), fontSize: 14)
        XCTAssertEqual(output.string, "prompt")
    }
}
