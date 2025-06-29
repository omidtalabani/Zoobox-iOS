import UIKit

class CameraViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Camera Demo"
        view.backgroundColor = .systemBackground

        // Add a button to trigger camera permission check
        let button = UIButton(type: .system)
        button.setTitle("Use Camera", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        button.addTarget(self, action: #selector(onCameraTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 55),
            button.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    @objc func onCameraTap() {
        CameraPermissionManager.checkCameraPermission(from: self) { granted in
            if granted {
                self.openCamera()
            } else {
                print("Camera permission denied")
            }
        }
    }

    func openCamera() {
        // Replace with your camera opening logic (UIImagePicker/AVCapture)
        let alert = UIAlertController(
            title: "Camera",
            message: "Camera would open here.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}



