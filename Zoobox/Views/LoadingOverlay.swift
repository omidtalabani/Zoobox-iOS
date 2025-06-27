//
//  LoadingOverlay.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import UIKit

class LoadingOverlay: UIView {
    
    // MARK: - Properties
    private let activityIndicator: UIActivityIndicatorView
    private let messageLabel: UILabel
    private let containerView: UIView
    private let blurEffectView: UIVisualEffectView
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        // Create blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create container
        containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .systemBlue
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Create message label
        messageLabel = UILabel()
        messageLabel.text = "Loading..."
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        addSubview(blurEffectView)
        addSubview(containerView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            // Blur effect covers entire view
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Container centered
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            // Message label
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Public Methods
    func show(in view: UIView, message: String = "Loading...") {
        messageLabel.text = message
        translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Animate appearance
        alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        activityIndicator.startAnimating()
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.alpha = 1
            self.containerView.transform = .identity
        })
    }
    
    func hide() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.activityIndicator.stopAnimating()
            self.removeFromSuperview()
        }
    }
    
    func updateMessage(_ message: String) {
        UIView.transition(with: messageLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.messageLabel.text = message
        })
    }
}

// MARK: - Convenience Extension
extension UIViewController {
    
    private static var loadingOverlayKey: UInt8 = 0
    
    private var loadingOverlay: LoadingOverlay? {
        get {
            return objc_getAssociatedObject(self, &UIViewController.loadingOverlayKey) as? LoadingOverlay
        }
        set {
            objc_setAssociatedObject(self, &UIViewController.loadingOverlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func showLoadingOverlay(message: String = "Loading...") {
        DispatchQueue.main.async {
            if self.loadingOverlay == nil {
                self.loadingOverlay = LoadingOverlay()
            }
            
            self.loadingOverlay?.show(in: self.view, message: message)
        }
    }
    
    func hideLoadingOverlay() {
        DispatchQueue.main.async {
            self.loadingOverlay?.hide()
        }
    }
    
    func updateLoadingMessage(_ message: String) {
        DispatchQueue.main.async {
            self.loadingOverlay?.updateMessage(message)
        }
    }
}