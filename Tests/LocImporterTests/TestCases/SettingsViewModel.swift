import L10n
import Foundation
import Network

// Legacy typealias for Settings module
typealias SettingsStrings = LocalizedTexts

struct SettingsViewModel {
    
    enum SettingsSection: CaseIterable {
        case account
        case notifications
        case privacy
        
        var title: String {
            switch self {
            case .account: return SettingsStrings.sectionAccount
            case .notifications: return SettingsStrings.sectionNotifications
            case .privacy: return SettingsStrings.sectionPrivacy
            }
        }
    }
    
    // Edge case: nested struct using both typealiases
    struct Config {
        static var appVersion: String {
            // Mix of direct and typealias usage
            "\(LocalizedTexts.versionLabel) 1.0.0"
        }
        
        static var buildInfo: String {
            SettingsStrings.buildInfo
        }
    }
    
    let sections = SettingsSection.allCases
    
    func updateSetting(_ key: String, value: Bool) {
        // Edge case: dictionary with string key matching typealias pattern
        let keys = [
            "ProfileStrings": "deprecated_key",
            "SettingsStrings": "current_key"
        ]
        print("Updating \(key): \(value)")
        print("Key mapping: \(keys)")
    }
    
    // Edge case: multiline string with typealias in it
    var helpText: String {
        """
        Welcome to Settings!
        
        Use SettingsStrings.shareOption to share your profile.
        This text contains "ProfileStrings" as literal text.
        """
    }
}
