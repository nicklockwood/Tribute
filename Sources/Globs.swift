//
//  Globs.swift
//  Tribute
//
//  Created by Nick Lockwood on 31/12/2018.
//

import Foundation

func expandPath(_ path: String, in directory: String) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
    }
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    return URL(fileURLWithPath: directory).appendingPathComponent(path)
}

func pathContainsGlobSyntax(_ path: String) -> Bool {
    "*?[{".contains(where: { path.contains($0) })
}

/// Glob type represents either an exact path or wildcard
enum Glob: CustomStringConvertible {
    case path(String)
    case regex(NSRegularExpression)

    func matches(_ path: String) -> Bool {
        switch self {
        case let .path(_path):
            return path.hasPrefix(_path)
        case let .regex(regex):
            let range = NSRange(location: 0, length: path.utf16.count)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        }
    }

    var description: String {
        switch self {
        case let .path(path):
            return path
        case let .regex(regex):
            var result = regex.pattern.dropFirst().dropLast()
                .replacingOccurrences(of: "([^/]+)?", with: "*")
                .replacingOccurrences(of: "(.+/)?", with: "**/")
                .replacingOccurrences(of: ".+", with: "**")
                .replacingOccurrences(of: "[^/]", with: "?")
                .replacingOccurrences(of: "\\", with: "")
            while let range = result.range(of: "\\([^)]+\\)", options: .regularExpression) {
                let options = result[range].dropFirst().dropLast().components(separatedBy: "|")
                result.replaceSubrange(range, with: "{\(options.joined(separator: ","))}")
            }
            return result
        }
    }
}

/// Expand one or more comma-delimited file paths using glob syntax
func expandGlob(_ path: String, in directory: String) -> Glob {
    guard pathContainsGlobSyntax(path) else {
        return .path(expandPath(path, in: directory).path)
    }
    var path = path
    var tokens = [String: String]()
    while let range = path.range(of: "\\{[^}]+\\}", options: .regularExpression) {
        let options = path[range].dropFirst().dropLast()
            .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
            .components(separatedBy: ",")
        let token = "<<<\(tokens.count)>>>"
        tokens[token] = "(\(options.joined(separator: "|")))"
        path.replaceSubrange(range, with: token)
    }
    do {
        let path = expandPath(path, in: directory).path
        if FileManager.default.fileExists(atPath: path) {
            // TODO: should we also handle cases where path includes tokens?
            return .path(path)
        }
        var regex = "^\(path)$"
            .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
            .replacingOccurrences(of: "?", with: "[^/]")
            .replacingOccurrences(of: "**/", with: "(.+/)?")
            .replacingOccurrences(of: "**", with: ".+")
            .replacingOccurrences(of: "*", with: "([^/]+)?")
        for (token, replacement) in tokens {
            regex = regex.replacingOccurrences(of: token, with: replacement)
        }
        return try! .regex(NSRegularExpression(pattern: regex, options: []))
    }
}

// NOTE: currently only used for testing
func matchGlobs(_ globs: [Glob], in directory: String) -> [URL] {
    var urls = [URL]()
    let keys: [URLResourceKey] = [.isDirectoryKey]
    let manager = FileManager.default
    func enumerate(_ directory: URL) {
        guard let files = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: []
        ) else {
            return
        }
        for url in files {
            let path = url.path
            var isDirectory: ObjCBool = false
            if globs.contains(where: { $0.matches(path) }) {
                urls.append(url)
            } else if manager.fileExists(atPath: path, isDirectory: &isDirectory),
                      isDirectory.boolValue
            {
                enumerate(url)
            }
        }
    }
    enumerate(URL(fileURLWithPath: directory))
    return urls
}
