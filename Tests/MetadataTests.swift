//
//  MetadataTests.swift
//  TributeTests
//
//  Created by Nick Lockwood on 31/05/2022.
//

import XCTest

private let projectDirectory = URL(fileURLWithPath: #file)
    .deletingLastPathComponent().deletingLastPathComponent()

private let projectURL = projectDirectory
    .appendingPathComponent("Tribute.xcodeproj")
    .appendingPathComponent("project.pbxproj")

private let changelogURL = projectDirectory
    .appendingPathComponent("CHANGELOG.md")

private let tributeFileURL = projectDirectory
    .appendingPathComponent("Sources")
    .appendingPathComponent("Tribute.swift")

private let tributeVersion: String = {
    let string = try! String(contentsOf: projectURL)
    let start = string.range(of: "MARKETING_VERSION = ")!.upperBound
    let end = string.range(of: ";", range: start ..< string.endIndex)!.lowerBound
    return String(string[start ..< end])
}()

class MetadataTests: XCTestCase {
    // MARK: Releases

    func testLatestVersionInChangelog() {
        let changelog = try! String(contentsOf: changelogURL, encoding: .utf8)
        XCTAssertTrue(
            changelog.contains("[\(tributeVersion)]"),
            "CHANGELOG.md does not mention latest release"
        )
        XCTAssertTrue(
            changelog.contains(
                "(https://github.com/nicklockwood/Tribute/" +
                    "releases/tag/\(tributeVersion))"
            ),
            "CHANGELOG.md does not include correct link for latest release"
        )
    }

    func testVersionConstantUpdated() throws {
        let source = try String(contentsOf: tributeFileURL)
        XCTAssertNotNil(source.range(of: """
                case .version:
                    return "\(tributeVersion)"
        """))
    }
}
