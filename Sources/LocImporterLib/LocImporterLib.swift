import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Types

public struct MigrationConfig {
    public let target: String
    public let packageName: String
    
    public init(target: String = "LocalizedTexts", packageName: String = "L10n") {
        self.target = target
        self.packageName = packageName
    }
}

public struct MigrationResult {
    public var wasModified: Bool = false
    public var importsAdded: Int = 0
    public var referencesUpdated: Int = 0
    
    public init(wasModified: Bool = false, importsAdded: Int = 0, referencesUpdated: Int = 0) {
        self.wasModified = wasModified
        self.importsAdded = importsAdded
        self.referencesUpdated = referencesUpdated
    }
}

public struct MigrationSummary {
    public var filesScanned: Int = 0
    public var filesModified: Int = 0
    public var importsAdded: Int = 0
    public var referencesUpdated: Int = 0
    public var typealiasFilesDeleted: Int = 0
    
    public init() {}
    
    public mutating func merge(_ other: MigrationResult) {
        filesScanned += 1
        if other.wasModified {
            filesModified += 1
            importsAdded += other.importsAdded
            referencesUpdated += other.referencesUpdated
        }
    }
}

public struct ReplacementPosition: Equatable {
    public let offset: Int
    public let length: Int
    
    public init(offset: Int, length: Int) {
        self.offset = offset
        self.length = length
    }
}

// MARK: - LocImporterService

public final class LocImporterService {
    public let config: MigrationConfig
    
    public init(config: MigrationConfig = MigrationConfig()) {
        self.config = config
    }
    
    /// Discovers all typealias aliases in a Swift file
    public func discoverTypealiases(in content: String) -> Set<String> {
        let sourceFile = Parser.parse(source: content)
        let visitor = TypealiasDiscoveryVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.aliases
    }
    
    /// Checks if a Swift file has an import for the package
    public func hasImport(_ content: String) -> Bool {
        let sourceFile = Parser.parse(source: content)
        for statement in sourceFile.statements {
            if let importDecl = statement.item.as(ImportDeclSyntax.self) {
                if importDecl.path.description.trimmingCharacters(in: .whitespaces) == config.packageName {
                    return true
                }
            }
        }
        return false
    }
    
    /// Finds all type references that need to be replaced
    public func findTypeReferences(in content: String, aliases: Set<String>) -> [ReplacementPosition] {
        let sourceFile = Parser.parse(source: content)
        let visitor = TypeReferenceVisitor(aliases: aliases)
        visitor.walk(sourceFile)
        return visitor.positions
    }
    
    /// Checks if a file is a typealias-only declaration file
    public func isTypealiasOnlyFile(_ content: String) -> Bool {
        let sourceFile = Parser.parse(source: content)
        let visitor = TypealiasDiscoveryVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        
        if visitor.aliases.isEmpty {
            return false
        }
        
        let contentWithoutTypealiases = removeTypealiasDeclarations(from: content)
        let trimmedContent = contentWithoutTypealiases
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingComments()
        
        return trimmedContent.isEmpty
    }
    
    /// Migrates a single Swift file
    public func migrateFile(content: String, aliases: Set<String>) -> (String, MigrationResult) {
        var result = MigrationResult()
        
        // Check if this is a typealias-only file
        if isTypealiasOnlyFile(content) {
            return (content, result)
        }
        
        // Check if import already exists
        let hasExistingImport = hasImport(content)
        
        // Find all type references to replace
        let positions = findTypeReferences(in: content, aliases: aliases)
        
        guard !positions.isEmpty else { return (content, result) }
        
        var modifiedContent = content
        
        // Replace type references (positions are sorted in reverse order)
        let sortedPositions = positions.sorted(by: { $0.offset > $1.offset })
        var replacementsCount = 0
        
        for position in sortedPositions {
            let startIndex = modifiedContent.index(
                modifiedContent.startIndex,
                offsetBy: position.offset
            )
            let endIndex = modifiedContent.index(startIndex, offsetBy: position.length)
            
            modifiedContent.replaceSubrange(startIndex..<endIndex, with: config.target)
            replacementsCount += 1
        }
        
        //  add import if needed (after replacements, so offsets aren't affected)
        if !hasExistingImport {
            modifiedContent = addImport(to: modifiedContent)
            result.importsAdded = 1
        }
        
        result.wasModified = (modifiedContent != content)
        result.referencesUpdated = replacementsCount
        
        return (modifiedContent, result)
    }
    
    /// Adds import statement to content
    public func addImport(to content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var insertIndex = 0
        var inBlockComment = false
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if inBlockComment {
                if trimmed.contains("*/") {
                    inBlockComment = false
                    insertIndex = index + 1
                }
                continue
            }
            
            if trimmed.hasPrefix("//") || trimmed.isEmpty {
                insertIndex = index + 1
            } else if trimmed.hasPrefix("/*") {
                inBlockComment = true
                if trimmed.contains("*/") {
                    inBlockComment = false
                    insertIndex = index + 1
                }
            } else if trimmed.hasPrefix("import") {
                insertIndex = index
                break
            } else {
                break
            }
        }
        
        if insertIndex >= lines.count {
            return "import \(config.packageName)\n\n" + content
        }
        
        var result = lines[0..<insertIndex].joined(separator: "\n")
        if !result.isEmpty { result += "\n" }
        result += "import \(config.packageName)\n"
        result += lines[insertIndex...].joined(separator: "\n")
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func removeTypealiasDeclarations(from content: String) -> String {
        var result = content
        let pattern = #"typealias\s+\w+Strings\s*=\s*\w+.*"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        return result
    }
}

// MARK: - SwiftSyntax Visitors

final class TypealiasDiscoveryVisitor: SyntaxVisitor {
    var aliases: Set<String> = []
    
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name.hasSuffix("Strings") {
            aliases.insert(name)
        }
        return .visitChildren
    }
}

final class TypeReferenceVisitor: SyntaxVisitor {
    let aliases: Set<String>
    var positions: [ReplacementPosition] = []
    
    init(aliases: Set<String>) {
        self.aliases = aliases
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let typeName = node.name.text
        if aliases.contains(typeName) {
            let position = ReplacementPosition(
                offset: node.position.utf8Offset,
                length: node.name.text.utf8.count
            )
            positions.append(position)
        }
        return .visitChildren
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.base {
            if let identifierExpr = base.as(DeclReferenceExprSyntax.self) {
                let baseName = identifierExpr.baseName.text
                if aliases.contains(baseName) {
                    let position = ReplacementPosition(
                        offset: identifierExpr.position.utf8Offset,
                        length: baseName.utf8.count
                    )
                    positions.append(position)
                }
            }
        }
        return .visitChildren
    }
    
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if aliases.contains(name) {
            let alreadyAdded = positions.contains { pos in
                pos.offset == node.position.utf8Offset
            }
            if !alreadyAdded {
                let position = ReplacementPosition(
                    offset: node.position.utf8Offset,
                    length: name.utf8.count
                )
                positions.append(position)
            }
        }
        return .visitChildren
    }
}

// MARK: - String Helpers

extension String {
    func removingComments() -> String {
        var result = self
        
        // Remove single-line comments
        if let singleLineRegex = try? NSRegularExpression(pattern: #"//.*"#, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = singleLineRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        // Remove multi-line comments
        if let multiLineRegex = try? NSRegularExpression(pattern: #"/\*.*?\*/"#, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(result.startIndex..., in: result)
            result = multiLineRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        return result
    }
}
