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

    static func infer(from template: Template) -> Format {
        let text = template.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = text.first {
            if first == "<" || text.contains("</") {
                return .xml
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
            return Template(rawValue: "$name\n\n$text\n\n")
        case .xml:
            return Template(rawValue: """
            <licenses>
                $start
                <license>
                    <name>$name</name>
                    <type>$type</type>
                    <text>$text</text>
                </license>
                $end
            </licenses>
            """)
        case .json:
            return Template(rawValue: """
            [
                $start
                {
                    "name": $name,
                    "type": $type,
                    "text": $text
                }$separator,$end
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
            return section
                .replacingOccurrences(
                    of: "\"$name\"", with: escape(library.name, as: format, inQuotes: true)
                )
                .replacingOccurrences(
                    of: "$name", with: escape(library.name, as: format, inQuotes: false)
                )
                .replacingOccurrences(
                    of: "\"$type\"", with: escape(licenseType, as: format, inQuotes: true)
                )
                .replacingOccurrences(
                    of: "$type", with: escape(licenseType, as: format, inQuotes: false)
                )
                .replacingOccurrences(
                    of: "\"$text\"", with: escape(library.licenseText, as: format, inQuotes: true)
                )
                .replacingOccurrences(
                    of: "$text", with: escape(library.licenseText, as: format, inQuotes: false)
                )
        }.joined(separator: separator)

        return header + body + footer
    }

    func escape(_ text: String, as format: Format, inQuotes: Bool) -> String {
        switch format {
        case .text:
            return inQuotes ? "\"\(text)\"" : text
        case .json:
            let jsonEncoder = JSONEncoder()
            if #available(macOS 10.15, *) {
                jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            } else {
                jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            let data = (try? jsonEncoder.encode(text)) ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        case .xml:
            let plistEncoder = PropertyListEncoder()
            plistEncoder.outputFormat = .xml
            let data = (try? plistEncoder.encode([text])) ?? Data()
            var text = String(data: data, encoding: .utf8) ?? ""
            let start = text.range(of: "<string>")?.upperBound ?? text.startIndex
            let end = text.range(of: "</string>")?.lowerBound ?? text.endIndex
            text = String(text[start ..< end]).replacingOccurrences(of: "\"", with: "&quot;")
            return inQuotes ? "\"\(text)\"" : text
        }
    }
}
