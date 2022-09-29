//
//  TributeTests.swift
//  TributeTests
//
//  Created by Nick Lockwood on 01/12/2020.
//

import XCTest

class TemplateTests: XCTestCase {
    // MARK: Fields

    func testName() throws {
        let template = Template(rawValue: "foo$namebaz")
        let library = Library(
            name: "bar",
            licensePath: "",
            licenseType: .mit,
            licenseText: ""
        )
        XCTAssertEqual(try template.render([library], as: .text), "foobarbaz")
    }

    func testType() throws {
        let template = Template(rawValue: "foo$typebaz")
        let library = Library(
            name: "bar",
            licensePath: "",
            licenseType: .mit,
            licenseText: ""
        )
        XCTAssertEqual(try template.render([library], as: .text), "fooMITbaz")
    }

    func testText() throws {
        let template = Template(rawValue: "foo$textbaz")
        let library = Library(
            name: "quux",
            licensePath: "",
            licenseType: .mit,
            licenseText: "bar"
        )
        XCTAssertEqual(try template.render([library], as: .text), "foobarbaz")
    }

    func testHeaderAndFooter() throws {
        let template = Template(rawValue: """
        foo
        $start
        $name
        $end
        bar
        """)
        let library = Library(
            name: "quux",
            licensePath: "",
            licenseType: .mit,
            licenseText: "bar"
        )
        XCTAssertEqual(try template.render([library, library], as: .text), """
        foo
        quux
        quux
        bar
        """)
    }

    func testInlineHeaderAndFooter() throws {
        let template = Template(rawValue: """
        foo$start$name$endbar
        """)
        let library = Library(
            name: "quux",
            licensePath: "",
            licenseType: .mit,
            licenseText: "bar"
        )
        XCTAssertEqual(try template.render([library, library], as: .text), """
        fooquuxquuxbar
        """)
    }

    func testSeparator() throws {
        let template = Template(rawValue: """
        foo
        $start
        $name$separator,
        $end
        bar
        """)
        let library = Library(
            name: "quux",
            licensePath: "",
            licenseType: .mit,
            licenseText: "bar"
        )
        XCTAssertEqual(try template.render([library, library], as: .text), """
        foo
        quux,
        quux
        bar
        """)
    }

    // MARK: Format

    func testJSON() throws {
        let template = Template(rawValue: """
        {
            "name": "$name",
            "version": "$version",
            "text": "$text",
            "path": "$path",
            "url": "$url"
        }
        """)
        let library = Library(
            name: "Foobar",
            version: "1.0.1",
            url: .init(string: "https://github.com/example/Foobar")!,
            licensePath: "",
            licenseType: .mit,
            licenseText: """
            line 1
            line 2
            """
        )
        XCTAssertEqual(try template.render([library], as: .json), """
        {
            "name": "Foobar",
            "version": "1.0.1",
            "text": "line 1\\nline 2",
            "path": "",
            "url": "https://github.com/example/Foobar"
        }
        """)
    }

    func testXML() throws {
        let template = Template(rawValue: """
        <root>
            <name>$name</name>
            <text>$text</text>
            <path>$path</path>
            <url>$url</url>
        </root>
        """)
        let library = Library(
            name: "foo & bar - \"the best!\"",
            url: .init(string: "https://github.com/example/Foobar")!,
            licensePath: "",
            licenseType: .mit,
            licenseText: """
            line 1
            line 2
            """
        )
        XCTAssertEqual(try template.render([library], as: .xml), """
        <root>
            <name>foo &amp; bar - &quot;the best!&quot;</name>
            <text>line 1\nline 2</text>
            <path></path>
            <url>https://github.com/example/Foobar</url>
        </root>
        """)
    }
}
