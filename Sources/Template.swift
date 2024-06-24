//
//  Template.swift
//  Tribute
//
//  Created by Nick Lockwood on 30/11/2020.
//

import Foundation

enum Format: String, CaseIterable {
    case text
    case xml
    case json
    case plist

    static func infer(from template: Template) -> Format {
        let text = template.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = text.first {
            if first == "<" {
                return text.contains("<plist") ? .plist : .xml
            }
            if ["{", "[", "\""].contains(first) {
                return .json
            }
        }
        return .text
    }

    static func infer(from url: URL) -> Format {
        switch url.pathExtension.lowercased() {
        case "xml":
            return .xml
        case "json":
            return .json
        case "plist":
            return .plist
        default:
            return .text
        }
    }
}

struct Template: RawRepresentable {
    let rawValue: String

    static func `default`(for format: Format) -> Template {
        switch format {
        case .text:
            return Template(rawValue: "$name ($version)\n\n$text\n\n")
        case .xml:
            return Template(rawValue: """
            <licenses>
                $start<license>
                    <name>$name</name>
                    <version>$version</version>
                    <type>$type</type>
                    <text>$text</text>
                    <path>$path</path>
                    <url>$url</url>
                </license>$separator
                $end
            </licenses>
            """)
        case .plist:
            return Template(rawValue: """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <array>
                $start<dict>
                    <key>name</key>
                    <string>$name</string>
                    <key>version</key>
                    <string>$version</string>
                    <key>type</key>
                    <string>$type</string>
                    <key>text</key>
                    <string>$text</string>
                    <key>path</key>
                    <string>$path</string>
                    <key>url</key>
                    <string>$url</string>
                </dict>$separator
                $end
            </array>
            </plist>
            """)
        case .json:
            return Template(rawValue: """
            [
                $start{
                    "name": "$name",
                    "version": "$version",
                    "type": "$type",
                    "text": "$text",
                    "path": "$path",
                    "url": "$url"
                }$separator,
                $end
            ]
            """)
        }
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    func render(_ libraries: [Library], as format: Format) throws -> String {
        let startRange = rawValue.range(of: "\n$start") ?? rawValue.range(of: "$start") ??
            (rawValue.startIndex ..< rawValue.startIndex)
        let endRange = rawValue.range(of: "\n$end") ?? rawValue.range(of: "$end") ??
            (rawValue.endIndex ..< rawValue.endIndex)
        let separatorRange = rawValue.range(of: "$separator") ?? (endRange.lowerBound ..< endRange.lowerBound)
        if startRange.upperBound > endRange.lowerBound {
            throw TributeError("$start must appear before $end")
        }
        if startRange.upperBound > separatorRange.lowerBound {
            throw TributeError("$start must appear before $separator")
        }
        if separatorRange.upperBound > endRange.lowerBound {
            throw TributeError("$separator must appear before $end")
        }

        let header = String(rawValue[..<startRange.lowerBound])
        let footer = String(rawValue[endRange.upperBound...])
        let section = String(rawValue[startRange.upperBound ..< separatorRange.lowerBound])
        let separator = String(rawValue[separatorRange.upperBound ..< endRange.lowerBound])

        let body = libraries.map { library -> String in
            let licenseType = library.licenseType?.rawValue ?? "Unknown"
            let version = library.version ?? "Unknown"
            let url = library.url?.absoluteString ?? "Unknown"
            return section
                .replacingOccurrences(
                    of: "$name", with: escape(library.name, as: format)
                )
                .replacingOccurrences(
                    of: " ($version)", with: library.version.map {
                        " (\(escape($0, as: format)))"
                    } ?? ""
                )
                .replacingOccurrences(
                    of: "($version)", with: library.version.map {
                        "(\(escape($0, as: format)))"
                    } ?? ""
                )
                .replacingOccurrences(
                    of: "$version", with: escape(version, as: format)
                )
                .replacingOccurrences(
                    of: "$type", with: escape(licenseType, as: format)
                )
                .replacingOccurrences(
                    of: "$text", with: escape(library.licenseText, as: format)
                )
                .replacingOccurrences(
                    of: "$path", with: escape(library.licensePath, as: format)
                )
                .replacingOccurrences(
                    of: "$url", with: escape(url, as: format)
                )
        }.joined(separator: separator)

        return header + body + footer
    }

    func escape(_ text: String, as format: Format) -> String {
        switch format {
        case .text:
            return text
        case .json:
            let jsonEncoder = JSONEncoder()
            if #available(macOS 10.15, *) {
                jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            } else {
                jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            let data = (try? jsonEncoder.encode(text)) ?? Data()
            return "\(String(data: data, encoding: .utf8)?.dropFirst().dropLast() ?? "")"
        case .xml, .plist:
            let plistEncoder = PropertyListEncoder()
            plistEncoder.outputFormat = .xml
            let data = (try? plistEncoder.encode([text])) ?? Data()
            let text = String(data: data, encoding: .utf8) ?? ""
            let start = text.range(of: "<string>")?.upperBound ?? text.startIndex
            let end = text.range(of: "</string>")?.lowerBound ?? text.endIndex
            return String(text[start ..< end]).replacingOccurrences(of: "\"", with: "&quot;")
        }
    }
}
