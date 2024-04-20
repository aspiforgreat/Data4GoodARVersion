import UIKit
import MapboxMaps

public protocol ExampleProtocol: AnyObject {
    func finish()
}

public protocol NonMapViewExampleProtocol: ExampleProtocol { }

extension ExampleProtocol {

    public func finish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("nothing")
        }
    }
}

extension ExampleProtocol where Self: UIViewController {
    // Presents an alert with a given title.
    public func showAlert(with title: String) {
        let alertController = UIAlertController(title: title,
                                                message: nil,
                                                preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Close", style: .default, handler: nil))

        present(alertController, animated: true, completion: nil)
    }
}
