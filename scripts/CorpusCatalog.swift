#!/usr/bin/env swift

import Foundation

// Shared corpus metadata for batch maintenance scripts. Data lives in
// `corpus-catalog.json` beside this file; each consumer script loads it via
// `loadCorpusCatalog()` using `#filePath` relative resolution.
//
// Run standalone to list or validate the catalog:
//   swift scripts/CorpusCatalog.swift
//   swift scripts/CorpusCatalog.swift --validate

struct CorpusRecord: Decodable, Sendable {
    let id: String
    let root: String
    let originals: String
    let vocab: String
    let rulebook: String
    let skillsOut: String
    let resolverOriginal: String
    let resolverOut: String
    let migrationDeviations: String
    let modulePath: String?
}

struct CorpusCatalogFile: Decodable, Sendable {
    let corpora: [CorpusRecord]
}

enum CorpusCatalog {
    static let fileName = "corpus-catalog.json"

    static func catalogURL(relativeTo scriptFile: String = #filePath) -> URL {
        URL(fileURLWithPath: scriptFile)
            .deletingLastPathComponent()
            .appendingPathComponent(fileName)
    }

    static func load(relativeTo scriptFile: String = #filePath) throws -> CorpusCatalogFile {
        let url = catalogURL(relativeTo: scriptFile)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CorpusCatalogFile.self, from: data)
    }

    static func ids(from catalog: CorpusCatalogFile) -> [String] {
        catalog.corpora.map(\.id).sorted()
    }

    static func select(_ id: String, from catalog: CorpusCatalogFile) throws -> [CorpusRecord] {
        if id == "all" { return catalog.corpora }
        let matches = catalog.corpora.filter { $0.id == id }
        guard !matches.isEmpty else {
            throw CorpusCatalogError.unknownCorpus(id, available: ids(from: catalog))
        }
        return matches
    }

    static func usageCorpusList(from catalog: CorpusCatalogFile) -> String {
        ids(from: catalog).joined(separator: "|") + "|all"
    }
}

enum CorpusCatalogError: Error, CustomStringConvertible {
    case unknownCorpus(String, available: [String])

    var description: String {
        switch self {
        case .unknownCorpus(let id, let available):
            "unknown corpus: \(id) (available: \(available.joined(separator: ", ")))"
        }
    }
}

func loadCorpusCatalog(relativeTo scriptFile: String = #filePath) throws -> CorpusCatalogFile {
    try CorpusCatalog.load(relativeTo: scriptFile)
}

// MARK: - Standalone CLI (validate / list)

private func corpusCatalogStandaloneMain() {
    do {
        let catalog = try loadCorpusCatalog()
        for record in catalog.corpora {
            print("\(record.id)\t\(record.root)")
        }
        if CommandLine.arguments.contains("--validate") {
            let ids = Set(catalog.corpora.map(\.id))
            if ids.count != catalog.corpora.count {
                fputs("duplicate corpus id in catalog\n", stderr)
                exit(1)
            }
        }
    } catch {
        fputs("\(error)\n", stderr)
        exit(1)
    }
}

if URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent == "CorpusCatalog.swift" {
    corpusCatalogStandaloneMain()
}
