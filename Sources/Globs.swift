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
    case regex(String, NSRegularExpression)

    func matches(_ path: String) -> Bool {
        switch self {
        case let .path(_path):
            return _path == path
        case let .regex(prefix, regex):
            guard path.hasPrefix(prefix) else {
                return false
            }
            let count = prefix.utf16.count
            let range = NSRange(location: count, length: path.utf16.count - count)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        }
    }

    var description: String {
        switch self {
        case let .path(path):
            return path
        case let .regex(prefix, regex):
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
            return prefix + result
        }
    }
}

/// Expand one or more comma-delimited file paths using glob syntax
func expandGlobs(_ path: String, in directory: String) -> [Glob] {
    guard pathContainsGlobSyntax(path) else {
        return [.path(expandPath(path, in: directory).path)]
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
    path = expandPath(path, in: directory).path
    if FileManager.default.fileExists(atPath: path) {
        // TODO: should we also handle cases where path includes tokens?
        return [.path(path)]
    }
    var prefix = "", regex = ""
    let parts = path.components(separatedBy: "/")
    for (i, part) in parts.enumerated() {
        if pathContainsGlobSyntax(part) || part.contains("<<<") {
            regex = parts[i...].joined(separator: "/")
            break
        }
        prefix += "\(part)/"
    }
    regex = "^\(regex)$"
        .replacingOccurrences(of: "[.+(){\\\\|]", with: "\\\\$0", options: .regularExpression)
        .replacingOccurrences(of: "?", with: "[^/]")
        .replacingOccurrences(of: "**/", with: "(.+/)?")
        .replacingOccurrences(of: "**", with: ".+")
        .replacingOccurrences(of: "*", with: "([^/]+)?")
    for (token, replacement) in tokens {
        regex = regex.replacingOccurrences(of: token, with: replacement)
    }
    return [.regex(prefix, try! NSRegularExpression(pattern: regex, options: []))]
}

func matchGlobs(_ globs: [Glob], in directory: String) throws -> [URL] {
    var urls = [URL]()
    let keys: [URLResourceKey] = [.isDirectoryKey]
    let manager = FileManager.default
    func enumerate(_ directory: URL, with glob: Glob) {
        guard let files = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: []
        ) else {
            return
        }
        for url in files {
            let path = url.path
            var isDirectory: ObjCBool = false
            if glob.matches(path) {
                urls.append(url)
            } else if manager.fileExists(atPath: path, isDirectory: &isDirectory),
                      isDirectory.boolValue
            {
                enumerate(url, with: glob)
            }
        }
    }
    for glob in globs {
        switch glob {
        case let .path(path):
            if manager.fileExists(atPath: path) {
                urls.append(URL(fileURLWithPath: path))
            } else {
                throw TributeError("File not found at \(glob)")
            }
        case let .regex(path, _):
            let count = urls.count
            if directory.hasPrefix(path) {
                enumerate(URL(fileURLWithPath: directory).standardized, with: glob)
            } else if path.hasPrefix(directory) {
                enumerate(URL(fileURLWithPath: path).standardized, with: glob)
            }
            if count == urls.count {
                throw TributeError("Glob did not match any files at \(glob)")
            }
        }
    }
    return urls
}
