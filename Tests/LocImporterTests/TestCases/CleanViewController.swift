import Foundation
import UIKit

// A file with no typealias references at all
class CleanViewController: UIViewController {
    
    let label = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "No localization here"
    }
}
