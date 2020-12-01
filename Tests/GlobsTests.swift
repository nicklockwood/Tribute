//
//  GlobsTests.swift
//  TributeTests
//
//  Created by Nick Lockwood on 01/12/2020.
//

import XCTest

class GlobsTests: XCTestCase {
    // MARK: Glob matching

    func testExpandWildcardPathWithExactName() {
        let path = "GlobsTests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithWildcardInMiddle() {
        let path = "Globs*.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithSingleCharacterWildcardInMiddle() {
        let path = "GlobsTest?.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithWildcardAtEnd() {
        let path = "Glo*"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithDoubleWildcardAtEnd() {
        let path = "Glob**"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithCharacterClass() {
        let path = "Glob[sZ]*.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testExpandPathWithCharacterClassRange() {
        let path = "T[e-r]*.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 2)
    }

    func testExpandPathWithEitherOr() {
        let path = "T{emplate,ribute}.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 2)
    }

    func testExpandPathWithWildcardAtStart() {
        let path = "*Tests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 2)
    }

    func testExpandPathWithSubdirectoryAndWildcard() {
        let path = "Tests/*Tests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 2)
    }

    func testSingleWildcardDoesNotMatchDirectorySlash() {
        let path = "*GlobsTests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 0)
    }

    func testDoubleWildcardMatchesDirectorySlash() {
        let path = "**GlobsTests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    func testDoubleWildcardMatchesNoSubdirectories() {
        let path = "Tests/**/GlobsTests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(matchGlobs([expandGlob(path, in: directory.path)], in: directory.path).count, 1)
    }

    // MARK: Glob regex

    func testWildcardRegex() {
        let path = "/Rule*.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(regex) = expandGlob(path, in: directory.path) else {
            return
        }
        XCTAssertEqual(regex.pattern, "^/Rule([^/]+)?\\.swift$")
    }

    func testDoubleWildcardRegex() {
        let path = "/**Rule.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(regex) = expandGlob(path, in: directory.path) else {
            return
        }
        XCTAssertEqual(regex.pattern, "^/.+Rule\\.swift$")
    }

    func testDoubleWildcardSlashRegex() {
        let path = "/**/Rule.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(regex) = expandGlob(path, in: directory.path) else {
            return
        }
        XCTAssertEqual(regex.pattern, "^/(.+/)?Rule\\.swift$")
    }

    func testEitherOrRegex() {
        let path = "/SwiftFormat.{h,swift}"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(regex) = expandGlob(path, in: directory.path) else {
            return
        }
        XCTAssertEqual(regex.pattern, "^/SwiftFormat\\.(h|swift)$")
    }

    func testEitherOrContainingDotRegex() {
        let path = "/SwiftFormat{.h,.swift}"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(regex) = expandGlob(path, in: directory.path) else {
            return
        }
        XCTAssertEqual(regex.pattern, "^/SwiftFormat(\\.h|\\.swift)$")
    }

    // MARK: Glob description

    func testGlobPathDescription() {
        let path = "/foo/bar"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobWildcardDescription() {
        let path = "/foo/*.txt"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobDoubleWildcardDescription() {
        let path = "/foo/**bar"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobDoubleWildcardSlashDescription() {
        let path = "/foo/**/bar.md"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobSingleCharacterWildcardDescription() {
        let path = "/foo/ba?.txt"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobEitherOrDescription() {
        let path = "/foo/{bar,baz}.md"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobEitherOrWithDotsDescription() {
        let path = "/foo{.md,.txt}"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobCharacterClassDescription() {
        let path = "/Options[DS]*.md"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }

    func testGlobCharacterRangeDescription() {
        let path = "/Options[D-S]*.txt"
        let directory = URL(fileURLWithPath: #file)
        let glob = expandGlob(path, in: directory.path)
        XCTAssertEqual(glob.description, path)
    }
}
