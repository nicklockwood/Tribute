//
//  Tribute.swift
//  Tribute
//
//  Created by Nick Lockwood on 30/11/2020.
//

import Foundation

struct TributeError: Error, CustomStringConvertible {
    let description: String

    init(_ message: String) {
        self.description = message
    }
}

enum Argument: String, CaseIterable {
    case anonymous = ""
    case allow
    case skip
    case exclude
    case template
    case format
    case spmcache
}

enum Command: String, CaseIterable {
    case export
    case list
    case check
    case help
    case version

    var help: String {
        switch self {
        case .help: return "Display general or command-specific help"
        case .list: return "Display list of libraries and licenses found in project"
        case .export: return "Export license information for project"
        case .check: return "Check that exported license info is correct"
        case .version: return "Display the current version of Tribute"
        }
    }
}

enum LicenseType: String, CaseIterable {
    case bsd = "BSD"
    case mit = "MIT"
    case isc = "ISC"
    case zlib = "Zlib"
    case apache = "Apache"

    private var matchStrings: [String] {
        switch self {
        case .bsd:
            return [
                "BSD License",
                "Redistribution and use in source and binary forms, with or without modification",
                "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR",
            ]
        case .mit:
            return [
                "The MIT License",
                "Permission is hereby granted, free of charge, to any person",
                "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR",
            ]
        case .isc:
            return [
                "Permission to use, copy, modify, and/or distribute this software for any",
            ]
        case .zlib:
            return [
                "Altered source versions must be plainly marked as such, and must not be",
            ]
        case .apache:
            return [
                "Apache License",
            ]
        }
    }

    init?(licenseText: String) {
        let preprocessedText = Self.preprocess(licenseText)
        guard let type = Self.allCases.first(where: {
            $0.matches(preprocessedText: preprocessedText)
        }) else {
            return nil
        }
        self = type
    }

    func matches(_ licenseText: String) -> Bool {
        matches(preprocessedText: Self.preprocess(licenseText))
    }

    private func matches(preprocessedText: String) -> Bool {
        matchStrings.contains {
            preprocessedText.range(of: $0, options: .caseInsensitive) != nil
        }
    }

    private static func preprocess(_ licenseText: String) -> String {
        licenseText.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

struct Library {
    var name: String
    var version: String?
    var licensePath: String
    var licenseType: LicenseType?
    var licenseText: String

    func with(_ fn: (inout Library) -> Void) -> Library {
        var copy = self
        fn(&copy)
        return copy
    }
}

private extension String {
    func addingTrailingSpace(toWidth width: Int) -> String {
        self + String(repeating: " ", count: width - count)
    }
}

class Tribute {
    // Find best match for a given string in a list of options
    func bestMatches(for query: String, in options: [String]) -> [String] {
        let lowercaseQuery = query.lowercased()
        // Sort matches by Levenshtein edit distance
        return options
            .compactMap { option -> (String, Int)? in
                let lowercaseOption = option.lowercased()
                let distance = editDistance(lowercaseOption, lowercaseQuery)
                guard distance <= lowercaseQuery.count / 2 ||
                    !lowercaseOption.commonPrefix(with: lowercaseQuery).isEmpty
                else {
                    return nil
                }
                return (option, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    /// The Levenshtein edit-distance between two strings
    func editDistance(_ lhs: String, _ rhs: String) -> Int {
        var dist = [[Int]]()
        for i in 0 ... lhs.count {
            dist.append([i])
        }
        for j in 1 ... rhs.count {
            dist[0].append(j)
        }
        for i in 1 ... lhs.count {
            let lhs = lhs[lhs.index(lhs.startIndex, offsetBy: i - 1)]
            for j in 1 ... rhs.count {
                if lhs == rhs[rhs.index(rhs.startIndex, offsetBy: j - 1)] {
                    dist[i].append(dist[i - 1][j - 1])
                } else {
                    dist[i].append(min(dist[i - 1][j] + 1, dist[i][j - 1] + 1, dist[i - 1][j - 1] + 1))
                }
            }
        }
        return dist[lhs.count][rhs.count]
    }

    // Parse a flat array of command-line arguments into a dictionary of flags and values
    func preprocessArguments(_ args: [String]) throws -> [Argument: [String]] {
        let arguments = Argument.allCases
        let argumentNames = arguments.map { $0.rawValue }
        var namedArgs: [Argument: [String]] = [:]
        var name: Argument?
        for arg in args {
            if arg.hasPrefix("--") {
                // Long argument names
                let key = String(arg.unicodeScalars.dropFirst(2))
                guard let argument = Argument(rawValue: key) else {
                    guard let match = bestMatches(for: key, in: argumentNames).first else {
                        throw TributeError("Unknown option --\(key).")
                    }
                    throw TributeError("Unknown option --\(key). Did you mean --\(match)?")
                }
                name = argument
                namedArgs[argument] = namedArgs[argument] ?? []
                continue
            } else if arg.hasPrefix("-") {
                // Short argument names
                let flag = String(arg.unicodeScalars.dropFirst())
                guard let match = arguments.first(where: { $0.rawValue.hasPrefix(flag) }) else {
                    throw TributeError("Unknown flag -\(flag).")
                }
                name = match
                namedArgs[match] = namedArgs[match] ?? []
                continue
            }
            var arg = arg
            let hasTrailingComma = arg.hasSuffix(",") && arg != ","
            if hasTrailingComma {
                arg = String(arg.dropLast())
            }
            let existing = namedArgs[name ?? .anonymous] ?? []
            namedArgs[name ?? .anonymous] = existing + [arg]
        }
        return namedArgs
    }

    func fetchLibraries(
        in directory: URL,
        excluding: [Glob],
        spmCache: URL?,
        includingPackages: Bool = true
    ) throws -> [Library] {
        let standardizedDirectory = directory.standardized
        let directoryPath = standardizedDirectory.path

        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: standardizedDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            throw TributeError("Unable to process directory at \(directoryPath).")
        }

        // Fetch libraries
        var libraries = [Library]()
        for case let licenceFile as URL in enumerator {
            if excluding.contains(where: { $0.matches(licenceFile.path) }) {
                continue
            }
            let licensePath = licenceFile.path.dropFirst(directoryPath.count)
            if includingPackages {
                if licenceFile.lastPathComponent == "Package.resolved" {
                    libraries += try fetchLibraries(forResolvedPackageAt: licenceFile, spmCache: spmCache)
                    continue
                }
                if licenceFile.lastPathComponent == "Package.swift",
                   !manager.fileExists(
                       atPath: licenceFile.deletingPathExtension()
                           .appendingPathExtension("resolved").path
                   )
                {
                    guard let string = try? String(contentsOf: licenceFile) else {
                        throw TributeError("Unable to read Package.swift at \(licensePath).")
                    }
                    if string.range(of: ".package(") != nil {
                        throw TributeError(
                            "Found unresolved Package.swift at \(licensePath). Run 'swift package resolve' to resolve dependencies."
                        )
                    }
                }
            }
            let name = licenceFile.deletingLastPathComponent().lastPathComponent
            if libraries.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                continue
            }
            let ext = licenceFile.pathExtension
            let fileName = licenceFile.deletingPathExtension().lastPathComponent.lowercased()
            guard ["license", "licence"].contains(fileName),
                  ["", "text", "txt", "md"].contains(ext)
            else {
                continue
            }
            var isDirectory: ObjCBool = false
            _ = manager.fileExists(atPath: licenceFile.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                continue
            }
            do {
                let licenseText = try String(contentsOf: licenceFile)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let library = Library(
                    name: name,
                    version: nil,
                    licensePath: String(licensePath),
                    licenseType: LicenseType(licenseText: licenseText),
                    licenseText: licenseText
                )
                libraries.append(library)
            } catch {
                throw TributeError("Unable to read license file at \(licensePath).")
            }
        }

        return libraries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func fetchLibraries(forResolvedPackageAt url: URL, spmCache: URL?) throws -> [Library] {
        struct Resolved: Decodable {
            var version: Double
        }

        struct State: Decodable {
            let revision: String?
            let version: String?
        }

        struct ResolvedV1: Decodable {
            struct Pin: Decodable {
                let package: String
                let repositoryURL: URL
                let state: State?
            }

            struct Object: Decodable {
                let pins: [Pin]
            }

            let object: Object
        }

        struct ResolvedV2: Decodable {
            struct Pin: Decodable {
                let identity: String
                let location: URL
                let state: State?
            }

            let pins: [Pin]

            init(_ v1: ResolvedV1) {
                self.pins = v1.object.pins.map {
                    Pin(
                        identity: $0.package,
                        location: $0.repositoryURL,
                        state: $0.state
                    )
                }
            }

            func pin(for name: String) -> Pin? {
                pins.first(where: {
                    name.caseInsensitiveCompare($0.identity) == .orderedSame ||
                        name.caseInsensitiveCompare(
                            $0.location
                                .deletingPathExtension()
                                .lastPathComponent
                        ) == .orderedSame
                })
            }
        }

        let resolved: ResolvedV2
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let version = try decoder.decode(Resolved.self, from: data).version
            switch version {
            case 1:
                resolved = try ResolvedV2(decoder.decode(ResolvedV1.self, from: data))
            case 2:
                resolved = try decoder.decode(ResolvedV2.self, from: data)
            default:
                throw TributeError("Unsupported Swift Package.resolved version: \(version).")
            }
        } catch {
            throw TributeError("Unable to read Swift Package file at \(url.path).")
        }
        let directory: URL
        if let spmCache = spmCache {
            directory = spmCache
        } else if let derivedDataDirectory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Developer/Xcode/DerivedData")
        {
            directory = derivedDataDirectory
        } else {
            throw TributeError("Unable to locate ~/Library/Developer/Xcode/DerivedData directory.")
        }
        let libraries = try fetchLibraries(
            in: directory,
            excluding: [],
            spmCache: nil,
            includingPackages: false
        )
        return libraries.compactMap {
            guard let pin = resolved.pin(for: $0.name) else {
                return nil
            }
            return $0.with { $0.version = pin.state?.version }
        }
    }

    func getHelp(with arg: String?) throws -> String {
        guard let arg = arg else {
            let width = Command.allCases.map { $0.rawValue.count }.max(by: <) ?? 0
            return """
            Available commands:

            \(Command.allCases.map {
                "   \($0.rawValue.addingTrailingSpace(toWidth: width))   \($0.help)"
            }.joined(separator: "\n"))

            (Type 'tribute help [command]' for more information)
            """
        }
        guard let command = Command(rawValue: arg) else {
            let commands = Command.allCases.map { $0.rawValue }
            if let closest = bestMatches(for: arg, in: commands).first {
                throw TributeError("Unrecognized command '\(arg)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unrecognized command '\(arg)'.")
        }
        let detailedHelp: String
        switch command {
        case .help:
            detailedHelp = """
               [command]  The command to display help for.
            """
        case .export:
            detailedHelp = """
               [filepath]   Path to the file that the licenses should be exported to. If omitted
                            then the licenses will be written to stdout.

               --exclude    One or more directories to be excluded from the library search.
                            Paths should be relative to the current directory, and may include
                            wildcard/glob syntax.

               --skip       One or more libraries to be skipped. Use this for libraries that do
                            not require attribution, or which are used in the build process but
                            are not actually shipped to the end-user.

               --allow      A list of libraries that should be included even if their licenses
                            are not supported/recognized.

               --template   A template string or path to a template file to use for generating
                            the licenses file. The template should contain one or more of the
                            following placeholder strings:

                            $name        The name of the library
                            $version     The installed version of the library or "Unknown"
                            ($version)   Version in parentheses - will be omitted if unknown
                            $type        The license type (e.g. MIT, Apache, BSD) or "Unknown"
                            $text        The text of the license itself
                            $start       The start of the license template (after the header)
                            $end         The end of the license template (before the footer)
                            $separator   A delimiter to be included between each license

               --format     How the output should be formatted (JSON, XML or text). If omitted
                            this will be inferred automatically from the template contents.

               --spmcache   Path to the Swift Package Manager cache (where SPM stores downloaded
                            libraries). If omitted the standard derived data path will be used.
            """
        case .check:
            detailedHelp = """
               [filepath]   The path to the licenses file that will be compared against the
                            libraries found in the project (required). An error will be returned
                            if any libraries are missing from the file, or if the format doesn't
                            match the other parameters.

               --exclude    One or more directories to be excluded from the library search.
                            Paths should be relative to the current directory, and may include
                            wildcard/glob syntax.

               --skip       One or more libraries to be skipped. Use this for libraries that do
                            not require attribution, or which are used in the build process but
                            are not actually shipped to the end-user.
            """
        case .list, .version:
            return command.help
        }

        return command.help + ".\n\n" + detailedHelp + "\n"
    }

    func listLibraries(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let globs = (arguments[.exclude] ?? []).flatMap { expandGlobs($0, in: directory) }
        let spmCache = arguments[.spmcache]?.first

        // Directories
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheURL = spmCache.map { expandPath($0, in: directory) }
        let libraries = try fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheURL)

        // Output
        let nameWidth = libraries.map {
            $0.name.count + ($0.version.map { $0.count + 3 } ?? 0)
        }.max() ?? 0
        let licenceWidth = libraries.map {
            ($0.licenseType?.rawValue ?? "Unknown").count
        }.max() ?? 0
        return libraries.map {
            var name = $0.name + ($0.version.map { " (\($0))" } ?? "")
            name += String(repeating: " ", count: nameWidth - name.count)
            var type = ($0.licenseType?.rawValue ?? "Unknown")
            type += String(repeating: " ", count: licenceWidth - type.count)
            return "\(name)  \(type)  \($0.licensePath)"
        }.joined(separator: "\n")
    }

    func check(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let skip = (arguments[.skip] ?? []).map { $0.lowercased() }
        let globs = (arguments[.exclude] ?? []).flatMap { expandGlobs($0, in: directory) }
        let spmCache = arguments[.spmcache]?.first

        // Directory
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheURL = spmCache.map { expandPath($0, in: directory) }
        var libraries = try fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheURL)
        let libraryNames = libraries.map { $0.name.lowercased() }

        if let name = skip.first(where: { !libraryNames.contains($0) }) {
            if let closest = bestMatches(for: name.lowercased(), in: libraryNames).first {
                throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unknown library '\(name)'.")
        }

        // Filtering
        libraries = libraries.filter { !skip.contains($0.name.lowercased()) }

        // File path
        let anon = arguments[.anonymous] ?? []
        guard let inputURL = (anon.count > 2 ? anon[2] : nil).map({
            expandPath($0, in: directory)
        }) else {
            throw TributeError("Missing path to licenses file.")
        }

        // Check
        guard var licensesText = try? String(contentsOf: inputURL) else {
            throw TributeError("Unable to read licenses file at \(inputURL.path).")
        }
        licensesText = licensesText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if let library = libraries.first(where: { !licensesText.contains($0.name) }) {
            throw TributeError("License for '\(library.name)' is missing from licenses file.")
        }
        return "Licenses file is up-to-date."
    }

    func export(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let allow = (arguments[.allow] ?? []).map { $0.lowercased() }
        let skip = (arguments[.skip] ?? []).map { $0.lowercased() }
        let globs = (arguments[.exclude] ?? []).flatMap { expandGlobs($0, in: directory) }
        let rawFormat = arguments[.format]?.first
        let cache = arguments[.spmcache]?.first

        // File
        let anon = arguments[.anonymous] ?? []
        let outputURL = (anon.count > 2 ? anon[2] : nil).map { expandPath($0, in: directory) }

        // Template
        let template: Template
        if let pathOrTemplate = arguments[.template]?.first {
            if pathOrTemplate.contains("$name") {
                template = Template(rawValue: pathOrTemplate)
            } else {
                let templateFile = expandPath(pathOrTemplate, in: directory)
                let templateText = try String(contentsOf: templateFile)
                template = Template(rawValue: templateText)
            }
        } else {
            template = .default(
                for: rawFormat.flatMap(Format.init) ??
                    outputURL.flatMap { .infer(from: $0) } ?? .text
            )
        }

        // Format
        let format: Format
        if let rawFormat = rawFormat {
            guard let _format = Format(rawValue: rawFormat) else {
                let formats = Format.allCases.map { $0.rawValue }
                if let closest = bestMatches(for: rawFormat, in: formats).first {
                    throw TributeError("Unsupported output format '\(rawFormat)'. Did you mean '\(closest)'?")
                }
                throw TributeError("Unsupported output format '\(rawFormat)'.")
            }
            format = _format
        } else {
            format = .infer(from: template)
        }

        // Directory
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheDirectory: URL?
        if let cache = cache {
            cacheDirectory = expandPath(cache, in: directory)
        } else {
            cacheDirectory = nil
        }
        var libraries = try fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheDirectory)
        let libraryNames = libraries.map { $0.name.lowercased() }

        if let name = (allow + skip).first(where: { !libraryNames.contains($0) }) {
            if let closest = bestMatches(for: name.lowercased(), in: libraryNames).first {
                throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unknown library '\(name)'.")
        }

        // Filtering
        libraries = try libraries.filter { library in
            if skip.contains(library.name.lowercased()) {
                return false
            }
            let name = library.name
            guard allow.contains(name.lowercased()) || library.licenseType != nil else {
                let escapedName = (name.contains(" ") ? "\"\(name)\"" : name).lowercased()
                throw TributeError(
                    "Unrecognized license at \(library.licensePath). "
                        + "Use '--allow \(escapedName)' or '--skip \(escapedName)' to bypass."
                )
            }
            return true
        }

        // Output
        let result = try template.render(libraries, as: format)
        if let outputURL = outputURL {
            do {
                try result.write(to: outputURL, atomically: true, encoding: .utf8)
                return "License data successfully written to \(outputURL.path)."
            } catch {
                throw TributeError("Unable to write output to \(outputURL.path). \(error).")
            }
        } else {
            return result
        }
    }

    func run(in directory: String, with args: [String] = CommandLine.arguments) throws -> String {
        let arg = args.count > 1 ? args[1] : Command.help.rawValue
        guard let command = Command(rawValue: arg) else {
            let commands = Command.allCases.map { $0.rawValue }
            if let closest = bestMatches(for: arg, in: commands).first {
                throw TributeError("Unrecognized command '\(arg)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unrecognized command '\(arg)'.")
        }
        switch command {
        case .help:
            return try getHelp(with: args.count > 2 ? args[2] : nil)
        case .list:
            return try listLibraries(in: directory, with: args)
        case .export:
            return try export(in: directory, with: args)
        case .check:
            return try check(in: directory, with: args)
        case .version:
            return "0.3.1"
        }
    }
}
