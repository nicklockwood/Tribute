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
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithWildcardInMiddle() {
        let path = "Globs*.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithSingleCharacterWildcardInMiddle() {
        let path = "GlobsTest?.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithWildcardAtEnd() {
        let path = "Glo*"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithDoubleWildcardAtEnd() {
        let path = "Glob**"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithCharacterClass() {
        let path = "Glob[sZ]*.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    func testExpandPathWithCharacterClassRange() {
        let path = "T[e-r]*.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 2)
    }

    func testExpandPathWithEitherOr() {
        let path = "T{emplate,ribute}.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 2)
    }

    func testExpandPathWithWildcardAtStart() {
        let path = "*Tests.swift"
        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 2)
    }

    func testExpandPathWithSubdirectoryAndWildcard() {
        let path = "Tests/*Tests.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 2)
    }

    func testSingleWildcardDoesNotMatchDirectorySlash() {
        let path = "*Tests.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertThrowsError(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path))
    }

    func testDoubleWildcardMatchesDirectorySlash() {
        let path = "**Tests.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 2)
    }

    func testDoubleWildcardMatchesNoSubdirectories() {
        let path = "Tests/**/GlobsTests.swift"
        let directory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(try matchGlobs(expandGlobs(path, in: directory.path), in: directory.path).count, 1)
    }

    // MARK: glob regex

    func testWildcardRegex() {
        let path = "/Rule*.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(_, regex) = expandGlobs(path, in: directory.path)[0] else {
            return
        }
        XCTAssertEqual(regex.pattern, "^Rule([^/]+)?\\.swift$")
    }

    func testDoubleWildcardRegex() {
        let path = "/**Rule.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(_, regex) = expandGlobs(path, in: directory.path)[0] else {
            return
        }
        XCTAssertEqual(regex.pattern, "^.+Rule\\.swift$")
    }

    func testDoubleWildcardSlashRegex() {
        let path = "/**/Rule.swift"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(_, regex) = expandGlobs(path, in: directory.path)[0] else {
            return
        }
        XCTAssertEqual(regex.pattern, "^(.+/)?Rule\\.swift$")
    }

    func testEitherOrRegex() {
        let path = "/SwiftFormat.{h,swift}"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(_, regex) = expandGlobs(path, in: directory.path)[0] else {
            return
        }
        XCTAssertEqual(regex.pattern, "^SwiftFormat\\.(h|swift)$")
    }

    func testEitherOrContainingDotRegex() {
        let path = "/SwiftFormat{.h,.swift}"
        let directory = URL(fileURLWithPath: #file)
        guard case let .regex(_, regex) = expandGlobs(path, in: directory.path)[0] else {
            return
        }
        XCTAssertEqual(regex.pattern, "^SwiftFormat(\\.h|\\.swift)$")
    }

    // MARK: glob description

    func testGlobPathDescription() {
        let path = "/foo/bar.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobWildcardDescription() {
        let path = "/foo/*.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobDoubleWildcardDescription() {
        let path = "/foo/**bar.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobDoubleWildcardSlashDescription() {
        let path = "/foo/**/bar.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobSingleCharacterWildcardDescription() {
        let path = "/foo/ba?.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobEitherOrDescription() {
        let path = "/foo/{bar,baz}.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobEitherOrWithDotsDescription() {
        let path = "/foo{.swift,.txt}"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobCharacterClassDescription() {
        let path = "/Options[DS]*.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }

    func testGlobCharacterRangeDescription() {
        let path = "/Options[D-S]*.swift"
        let directory = URL(fileURLWithPath: #file)
        let globs = expandGlobs(path, in: directory.path)
        XCTAssertEqual(globs[0].description, path)
    }
}
