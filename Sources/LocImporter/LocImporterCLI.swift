import ArgumentParser
import Foundation
import LocImporterLib

@main
struct LocImporter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "l10n-migrator",
        abstract: "Migrate typealias string references to direct Texts usage",
        discussion: """
            This tool uses SwiftSyntax to accurately find and replace type references,
            correctly handling string literals, comments, and nested contexts.
            """
    )

    @Option(name: [.short, .long], help: "Directory to scan for Swift files")
    var path: String

    @Option(name: [.long], help: "The target struct name (default: Texts)")
    var target: String = "Texts"

    @Option(name: [.long], help: "The package name to import (default: L10n)")
    var packageName: String = "L10n"

    @Flag(name: [.short, .long], help: "Preview changes without writing files")
    var dryRun: Bool = false

    @Flag(name: [.short, .long], help: "Delete typealias declaration files after migration")
    var deleteTypealiases: Bool = false

    @Option(name: [.short, .long], help: "Path to output a report of changes")
    var report: String?

    @Flag(name: [.short, .long], help: "Enable verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        let rootURL = URL(fileURLWithPath: path)
        let config = MigrationConfig(target: target, packageName: packageName)
        let service = LocImporterService(config: config)

        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw ValidationError("Directory does not exist: \(path)")
        }

        print("🔍 Scanning for Swift files in: \(rootURL.path)")
        print("   Target struct: \(target)")
        print("   Package to import: \(packageName)")
        print("")

        // Step 1: Discover all typealias aliases
        let aliases = try discoverTypealiases(in: rootURL, service: service)
        
        if aliases.isEmpty {
            print("No typealiases found. Nothing to migrate.")
            return
        }

        print("Discovered \(aliases.count) typealias aliases:")
        for alias in aliases.sorted() {
            print("   \(alias) → \(target)")
        }
        print("")

        // Step 2: Find and process Swift files
        let swiftFiles = try findSwiftFiles(in: rootURL)
        print("Found \(swiftFiles.count) Swift files to process")
        print("")

        var summary = MigrationSummary()

        for fileURL in swiftFiles {
            let result = try processFile(fileURL, aliases: aliases, service: service)
            summary.merge(result)
        }

        // Step 3: Delete typealias files if requested
        if deleteTypealiases && !dryRun {
            let typealiasFiles = try findTypealiasFiles(in: rootURL, service: service)
            for fileURL in typealiasFiles {
                if verbose {
                    print("Deleting: \(fileURL.path)")
                }
                try FileManager.default.removeItem(at: fileURL)
                summary.typealiasFilesDeleted += 1
            }
        }

        // Step 4: Print summary
        print("")
        print("═══════════════════════════════════════════════════")
        print(dryRun ? " DRY RUN SUMMARY (no files were modified)" : " MIGRATION COMPLETE")
        print("═══════════════════════════════════════════════════")
        print("  Files scanned:      \(summary.filesScanned)")
        print("  Files modified:     \(summary.filesModified)")
        print("  Imports added:      \(summary.importsAdded)")
        print("  References updated: \(summary.referencesUpdated)")
        if deleteTypealiases {
            print("  Typealias files deleted: \(summary.typealiasFilesDeleted)")
        }
        print("")

        // Step 5: Write report if requested
        if let reportPath = report {
            try writeReport(summary, aliases: aliases, to: reportPath)
            print("📄 Report written to: \(reportPath)")
        }
    }

    // MARK: - File Operations

    private func discoverTypealiases(in rootURL: URL, service: LocImporterService) throws -> Set<String> {
        var allAliases: Set<String> = []

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let aliases = service.discoverTypealiases(in: content)
            allAliases.formUnion(aliases)
        }

        return allAliases
    }

    private func findSwiftFiles(in rootURL: URL) throws -> [URL] {
        var files: [URL] = []

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            files.append(fileURL)
        }

        return files
    }

    private func findTypealiasFiles(in rootURL: URL, service: LocImporterService) throws -> [URL] {
        var files: [URL] = []

        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            if service.isTypealiasOnlyFile(content) {
                files.append(fileURL)
            }
        }

        return files
    }

    private func processFile(_ fileURL: URL, aliases: Set<String>, service: LocImporterService) throws -> MigrationResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let (modifiedContent, result) = service.migrateFile(content: content, aliases: aliases)

        if result.wasModified {
            if dryRun {
                print("Would modify: \(fileURL.path)")
                if verbose {
                    printDiff(original: content, modified: modifiedContent)
                }
            } else {
                try modifiedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Modified: \(fileURL.path)")
            }
        }

        return result
    }

    private func printDiff(original: String, modified: String) {
        let originalLines = original.split(separator: "\n")
        let modifiedLines = modified.split(separator: "\n")

        print("   --- Original ---")
        for (index, line) in originalLines.enumerated().prefix(15) {
            print("   \(index + 1): \(line)")
        }
        print("   --- Modified ---")
        for (index, line) in modifiedLines.enumerated().prefix(15) {
            print("   \(index + 1): \(line)")
        }
    }

    private func writeReport(_ summary: MigrationSummary, aliases: Set<String>, to path: String) throws {
        var report = "# L10n Migration Report\n\n"
        report += "## Summary\n\n"
        report += "- **Files scanned:** \(summary.filesScanned)\n"
        report += "- **Files modified:** \(summary.filesModified)\n"
        report += "- **Imports added:** \(summary.importsAdded)\n"
        report += "- **References updated:** \(summary.referencesUpdated)\n"

        if deleteTypealiases {
            report += "- **Typealias files deleted:** \(summary.typealiasFilesDeleted)\n"
        }

        report += "\n## Typealias Migrations\n\n"
        for alias in aliases.sorted() {
            report += "- `\(alias)` → `\(target)`\n"
        }

        try report.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
