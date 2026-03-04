//
//  ProfileViewController.swift
//  ProfileModule
//
//  Created by John Doe on 2024-01-15.
//

import UIKit
import SwiftUI
import Combine
import CoreLocation

class ProfileViewController: UIViewController {
    
    private let label = UILabel()
    private let button = UIButton()
    
    // TODO: Refactor to use ProfileStrings consistently
    // Note: ProfileStrings.title is used for the header
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up UI with localized strings
        label.text = ProfileStrings.profileTitle
        button.setTitle(ProfileStrings.saveButton, for: .normal)
        
        // Edge case: string literal containing the typealias name
        let debugMessage = "Debug: ProfileStrings is the typealias for localization"
        print(debugMessage)
        
        // Edge case: comment containing typealias
        // ProfileStrings.welcomeMessage should show the welcome text
        
        setupAccessibility()
    }
    
    private func setupAccessibility() {
        // Already using LocalizedTexts directly in some places
        label.accessibilityLabel = LocalizedTexts.profileTitleAccessibility
        button.accessibilityHint = ProfileStrings.saveButtonHint
    }
    
    // Edge case: closure with typealias usage
    private lazy var loadProfile: () -> Void = { [weak self] in
        self?.showAlert(
            title: ProfileStrings.errorTitle,
            message: ProfileStrings.errorMessage
        )
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: ProfileStrings.okButton, style: .default))
        present(alert, animated: true)
    }
}

// Edge case: extension with typealias usage
extension ProfileViewController {
    func configure(with name: String) {
        let formatted = String(format: ProfileStrings.greetingFormat, name)
        label.text = formatted
    }
}
