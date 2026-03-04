import XCTest
import Foundation
import SwiftSyntax
import SwiftParser
@testable import LocImporterLib

final class LocImporterTests: XCTestCase {
    
    var sut: LocImporterService!
    
    override func setUp() {
        super.setUp()
        sut = LocImporterService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Typealias Discovery Tests
    
    func testDiscoverTypealiases_FindsProfileStrings() throws {
        let content = """
            import Foundation
            
            typealias ProfileStrings = Texts
            """
        
        let aliases = sut.discoverTypealiases(in: content)
        
        XCTAssertEqual(aliases.count, 1)
        XCTAssertTrue(aliases.contains("ProfileStrings"))
    }
    
    func testDiscoverTypealiases_FindsMultipleTypealiases() throws {
        let content = """
            import Foundation
            
            typealias ProfileStrings = Texts
            typealias SettingsStrings = Texts
            typealias HomeStrings = Texts
            """
        
        let aliases = sut.discoverTypealiases(in: content)
        
        XCTAssertEqual(aliases.count, 3)
        XCTAssertTrue(aliases.contains("ProfileStrings"))
        XCTAssertTrue(aliases.contains("SettingsStrings"))
        XCTAssertTrue(aliases.contains("HomeStrings"))
    }
    
    func testDiscoverTypealiases_IgnoresNonStringsSuffix() throws {
        let content = """
            import Foundation
            
            typealias ProfileText = Texts
            typealias SettingsConfig = Texts
            typealias HomeStrings = Texts
            """
        
        let aliases = sut.discoverTypealiases(in: content)
        
        XCTAssertEqual(aliases.count, 1)
        XCTAssertTrue(aliases.contains("HomeStrings"))
        XCTAssertFalse(aliases.contains("ProfileText"))
        XCTAssertFalse(aliases.contains("SettingsConfig"))
    }
    
    // MARK: - Import Detection Tests
    
    func testHasImport_DetectsExistingImport() throws {
        let content = """
            import L10n
            import Foundation
            
            class MyClass {}
            """
        
        XCTAssertTrue(sut.hasImport(content))
    }
    
    func testHasImport_ReturnsFalseForMissingImport() throws {
        let content = """
            import Foundation
            import UIKit
            
            class MyClass {}
            """
        
        XCTAssertFalse(sut.hasImport(content))
    }
    
    func testHasImport_WorksWithCustomPackageName() throws {
        let config = MigrationConfig(packageName: "MyLocalization")
        let service = LocImporterService(config: config)
        
        let content = """
            import MyLocalization
            import Foundation
            
            class MyClass {}
            """
        
        XCTAssertTrue(service.hasImport(content))
    }
    
    // MARK: - Type Reference Detection Tests
    
    func testFindTypeReferences_FindsSimpleReference() throws {
        let content = """
            label.text = ProfileStrings.title
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        XCTAssertEqual(positions.count, 1)
    }
    
    func testFindTypeReferences_FindsMultipleReferences() throws {
        let content = """
            label.text = ProfileStrings.title
            button.setTitle(ProfileStrings.save, for: .normal)
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        XCTAssertEqual(positions.count, 2)
    }
    
    func testFindTypeReferences_IgnoresStringLiterals() throws {
        let content = """
            let message = "ProfileStrings is a typealias"
            label.text = ProfileStrings.title
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        // Should only find the actual reference, not the string literal
        XCTAssertEqual(positions.count, 1)
    }
    
    func testFindTypeReferences_IgnoresComments() throws {
        let content = """
            // TODO: Fix ProfileStrings usage
            /* ProfileStrings should be removed */
            label.text = ProfileStrings.title
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        // Should only find the actual reference, not the comments
        XCTAssertEqual(positions.count, 1)
    }
    
    func testFindTypeReferences_IgnoresMultilineStringLiterals() throws {
        let content = #"""
            let message = """
            ProfileStrings is inside a multiline string.
            SettingsStrings too.
            """
            label.text = ProfileStrings.title
            """#
        
        let aliases: Set<String> = ["ProfileStrings", "SettingsStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        // Should only find the actual reference, not the multiline string
        XCTAssertEqual(positions.count, 1)
    }
    
    func testFindTypeReferences_IgnoresDictionaryStringKeys() throws {
        let content = """
            let dict = [
                "ProfileStrings": "value1",
                "SettingsStrings": "value2",
                "key": ProfileStrings.actualValue
            ]
            """
        
        let aliases: Set<String> = ["ProfileStrings", "SettingsStrings"]
        let positions = sut.findTypeReferences(in: content, aliases: aliases)
        
        // Should only find the value reference, not the string keys
        XCTAssertEqual(positions.count, 1)
    }
    
    // MARK: - Migration Tests
    
    func testMigrateFile_ReplacesTypeReferences() throws {
        let content = """
            import Foundation
            
            class MyClass {
                let text = ProfileStrings.title
            }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        XCTAssertFalse(modified.contains("ProfileStrings"))
        XCTAssertTrue(modified.contains("Texts.title"))
        XCTAssertEqual(result.referencesUpdated, 1)
    }
    
    func testMigrateFile_AddsImportWhenMissing() throws {
        let content = """
            import Foundation
            
            class MyClass {
                let text = ProfileStrings.title
            }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.importsAdded == 1)
        XCTAssertTrue(modified.contains("import L10n"))
    }
    
    func testMigrateFile_DoesNotAddDuplicateImport() throws {
        let content = """
            import L10n
            import Foundation
            
            class MyClass {
                let text = ProfileStrings.title
            }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertEqual(result.importsAdded, 0)
        // Should still have only one import L10n
        XCTAssertEqual(modified.components(separatedBy: "import L10n").count - 1, 1)
    }
    
    func testMigrateFile_SkipsTypealiasOnlyFiles() throws {
        let content = """
            import Foundation
            
            typealias ProfileStrings = Texts
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertFalse(result.wasModified)
        XCTAssertEqual(content, modified)
    }
    
    func testMigrateFile_PreservesStringLiterals() throws {
        let content = """
            import Foundation
            
            class MyClass {
                let message = "ProfileStrings should not change"
                let text = ProfileStrings.title
            }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, _) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(modified.contains(#""ProfileStrings should not change""#))
    }
    
    func testMigrateFile_PreservesComments() throws {
        let content = """
            import Foundation
            
            class MyClass {
                // TODO: Fix ProfileStrings
                let text = ProfileStrings.title
            }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, _) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(modified.contains("// TODO: Fix ProfileStrings"))
    }
    
    func testMigrateFile_HandlesStringInterpolation() throws {
        let content = """
            import Foundation
            
            let greeting = "\\(ProfileStrings.welcome), User!"
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        XCTAssertTrue(modified.contains("Texts.welcome"))
    }
    
    func testMigrateFile_HandlesTypeContext() throws {
        let content = """
            import Foundation
            
            var stringsType: ProfileStrings.Type { ProfileStrings.self }
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        XCTAssertTrue(modified.contains("Texts.Type"))
        XCTAssertTrue(modified.contains("Texts.self"))
    }
    
    // MARK: - Import Insertion Tests
    
    func testAddImport_InsertsBeforeExistingImports() throws {
        let content = """
            import Foundation
            import UIKit
            
            class MyClass {}
            """
        
        let modified = sut.addImport(to: content)
        
        XCTAssertTrue(modified.hasPrefix("import L10n\nimport Foundation"))
    }
    
    func testAddImport_InsertsAfterHeaderComments() throws {
        let content = """
            //
            //  File.swift
            //  Project
            //
            
            import Foundation
            
            class MyClass {}
            """
        
        let modified = sut.addImport(to: content)
        
        XCTAssertTrue(modified.contains("import L10n"))
        XCTAssertTrue(modified.contains("import Foundation"))
    }
    
    func testAddInsert_InsertsAtTopWhenNoImports() throws {
        let content = """
            class MyClass {}
            """
        
        let modified = sut.addImport(to: content)
        
        XCTAssertTrue(modified.hasPrefix("import L10n"))
    }
    
    // MARK: - Custom Config Tests
    
    func testCustomTarget_ReplacesWithCorrectName() throws {
        let config = MigrationConfig(target: "CustomTexts")
        let service = LocImporterService(config: config)
        
        let content = """
            import Foundation
            
            let text = ProfileStrings.title
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, result) = service.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        XCTAssertTrue(modified.contains(" CustomTexts.title"))
        XCTAssertFalse(modified.contains(" Texts.title"))
    }
    
    func testCustomPackageName_AddsCorrectImport() throws {
        let config = MigrationConfig(packageName: "MyLocalization")
        let service = LocImporterService(config: config)
        
        let content = """
            import Foundation
            
            let text = ProfileStrings.title
            """
        
        let aliases: Set<String> = ["ProfileStrings"]
        let (modified, _) = service.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(modified.contains("import MyLocalization"))
    }
    
    // MARK: - Integration Tests with Fixtures
    
    func testMigrate_ProfileViewController() throws {
        let content = try loadFixture(named: "ProfileViewController")
        let aliases: Set<String> = ["ProfileStrings"]
        
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        
        // Should NOT replace string literals
        XCTAssertTrue(modified.contains(#""Debug: ProfileStrings is the typealias for localization""#))
        
        // Should NOT replace comments
        XCTAssertTrue(modified.contains("// TODO: Refactor to use ProfileStrings"))
        XCTAssertTrue(modified.contains("// ProfileStrings.welcomeMessage"))
        
        // Should replace actual references
        XCTAssertTrue(modified.contains("Texts.profileTitle"))
        XCTAssertTrue(modified.contains("Texts.saveButton"))
        XCTAssertTrue(modified.contains("Texts.errorTitle"))
    }
    
    func testMigrate_SettingsViewModel_HasExistingImport() throws {
        let content = try loadFixture(named: "SettingsViewModel")
        let aliases: Set<String> = ["SettingsStrings"]
        
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        
        // Should not add duplicate import
        XCTAssertEqual(modified.components(separatedBy: "import L10n").count - 1, 1)
        
        // Should NOT replace dictionary string keys
        XCTAssertTrue(modified.contains(#""ProfileStrings": "deprecated_key""#))
        XCTAssertTrue(modified.contains(#""SettingsStrings": "current_key""#))
        
        // Should NOT replace multiline string literals
        XCTAssertTrue(modified.contains("Use SettingsStrings.shareOption"))
        
        // Should replace actual references
        XCTAssertTrue(modified.contains("Texts.sectionAccount"))
    }
    
    func testMigrate_EdgeCaseViewController() throws {
        let content = try loadFixture(named: "EdgeCaseViewController")
        let aliases: Set<String> = ["ProfileStrings", "SettingsStrings"]
        
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertTrue(result.wasModified)
        
        // String literals should NOT be replaced
        XCTAssertTrue(modified.contains(#""ProfileStrings is a typealias""#))
        XCTAssertTrue(modified.contains(#""Use SettingsStrings for settings""#))
        XCTAssertTrue(modified.contains(#""ProfileStrings""#))  // print statement
        
        // Comments should NOT be replaced
        XCTAssertTrue(modified.contains("// TODO: Remove ProfileStrings usage"))
        XCTAssertTrue(modified.contains("// FIXME: SettingsStrings is deprecated"))
        
        // Dictionary keys should NOT be replaced
        XCTAssertTrue(modified.contains(#""ProfileStrings": "value1""#))
        XCTAssertTrue(modified.contains(#""SettingsStrings": "value2""#))
        
        // Array string literals should NOT be replaced
        XCTAssertTrue(modified.contains(#""ProfileStrings""#))
        XCTAssertTrue(modified.contains(#""SettingsStrings""#))
        
        // Actual references SHOULD be replaced
        XCTAssertTrue(modified.contains("Texts.screenTitle"))
        XCTAssertTrue(modified.contains("Texts.welcome"))
        XCTAssertTrue(modified.contains("Texts.normalValue"))
        XCTAssertTrue(modified.contains("Texts.closureValue"))
        XCTAssertTrue(modified.contains("Texts.Type"))
    }
    
    func testMigrate_CleanViewController_NoChanges() throws {
        let content = try loadFixture(named: "CleanViewController")
        let aliases: Set<String> = ["ProfileStrings"]
        
        let (modified, result) = sut.migrateFile(content: content, aliases: aliases)
        
        XCTAssertFalse(result.wasModified)
        XCTAssertEqual(content, modified)
        XCTAssertEqual(result.referencesUpdated, 0)
        XCTAssertEqual(result.importsAdded, 0)
    }
    
    // MARK: - Helper Methods
    
    private func loadFixture(named name: String) throws -> String {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "swift", subdirectory: "Fixtures") else {
            throw XCTSkip("Fixture not found: \(name).swift")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
