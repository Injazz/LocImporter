import AVFoundation
import CoreData
import WebKit

class EdgeCaseViewController: UIViewController {
    
    // MARK: - String Literals (should NOT be replaced)
    
    let stringLiteral1 = "ProfileStrings is a typealias"
    let stringLiteral2 = "Use SettingsStrings for settings"
    let stringLiteral3 = """
        Multi-line string with ProfileStrings inside.
        And SettingsStrings on another line.
        """
    
    // MARK: - Comments (should NOT be replaced)
    
    // TODO: Remove ProfileStrings usage
    // FIXME: SettingsStrings is deprecated
    /* 
     * ProfileStrings should be migrated
     * SettingsStrings too
     */
    
    // MARK: - Actual Code (SHOULD be replaced)
    
    func loadUI() {
        // These should be replaced
        titleLabel.text = ProfileStrings.screenTitle
        subtitleLabel.text = SettingsStrings.screenSubtitle
        
        // String interpolation - SHOULD replace
        let greeting = "\(ProfileStrings.welcome), User!"
        
        // Format string - SHOULD replace
        let formatted = String(format: ProfileStrings.template, arg1, arg2)
    }
    
    // MARK: - Dictionary with string keys (should NOT replace keys)
    
    let stringKeys: [String: String] = [
        "ProfileStrings": "value1",
        "SettingsStrings": "value2",
        "NormalKey": ProfileStrings.normalValue  // Value SHOULD be replaced
    ]
    
    // MARK: - Array with string literals (should NOT replace)
    
    let stringArray = [
        "ProfileStrings",
        "SettingsStrings",
        ProfileStrings.arrayValue  // This SHOULD be replaced
    ]
    
    // MARK: - Nested quotes
    
    let nestedQuotes = "She said \"Use ProfileStrings for this\" loudly"
    
    // MARK: - Type context
    
    var stringsType: ProfileStrings.Type { ProfileStrings.self }
    
    // MARK: - Closure with mixed content
    
    lazy var action: () -> Void = {
        // Comment with ProfileStrings
        print("Debug: ProfileStrings")  // String literal
        _ = ProfileStrings.closureValue  // SHOULD replace
    }
    
    // MARK: - Optional chaining
    
    var optionalString: String? {
        ProfileStrings.optionalValue  // SHOULD replace
    }
    
    // MARK: - Guard/Let
    
    func process() {
        guard let text = ProfileStrings.guardValue.isEmpty ? nil : ProfileStrings.guardValue else {
            // ProfileStrings in comment
            print("ProfileStrings")  // String literal
            return
        }
        print(text)
    }
}
