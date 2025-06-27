//
//  ErrorViewController.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import UIKit

class ErrorViewController: UIViewController {
    
    // MARK: - Properties
    private let errorType: ZooboxError
    private let retryAction: (() -> Void)?
    
    // UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemRed
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let recoveryLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open Settings", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dismiss", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    init(error: ZooboxError, retryAction: (() -> Void)? = nil) {
        self.errorType = error
        self.retryAction = retryAction
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureForError()
        setupActions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateAppearance()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(recoveryLabel)
        containerView.addSubview(retryButton)
        containerView.addSubview(settingsButton)
        containerView.addSubview(dismissButton)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Recovery
            recoveryLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            recoveryLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            recoveryLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Retry button
            retryButton.topAnchor.constraint(equalTo: recoveryLabel.bottomAnchor, constant: 24),
            retryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            retryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            retryButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Settings button
            settingsButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 12),
            settingsButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Dismiss button
            dismissButton.topAnchor.constraint(equalTo: settingsButton.bottomAnchor, constant: 12),
            dismissButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    private func configureForError() {
        switch errorType {
        case .networkUnavailable:
            iconImageView.image = UIImage(systemName: "wifi.slash")
            titleLabel.text = "No Internet Connection"
            settingsButton.isHidden = false
            
        case .locationPermissionDenied:
            iconImageView.image = UIImage(systemName: "location.slash")
            titleLabel.text = "Location Access Required"
            settingsButton.isHidden = false
            
        case .webViewLoadFailed:
            iconImageView.image = UIImage(systemName: "exclamationmark.triangle")
            titleLabel.text = "Page Load Failed"
            settingsButton.isHidden = true
            
        case .cookieStorageFailed:
            iconImageView.image = UIImage(systemName: "key.horizontal")
            titleLabel.text = "Session Storage Error"
            settingsButton.isHidden = true
            
        case .notificationPermissionDenied:
            iconImageView.image = UIImage(systemName: "bell.slash")
            titleLabel.text = "Notifications Disabled"
            settingsButton.isHidden = false
            
        case .sessionExpired:
            iconImageView.image = UIImage(systemName: "clock.badge.exclamationmark")
            titleLabel.text = "Session Expired"
            settingsButton.isHidden = true
            
        case .unknownError:
            iconImageView.image = UIImage(systemName: "questionmark.circle")
            titleLabel.text = "Something Went Wrong"
            settingsButton.isHidden = true
        }
        
        messageLabel.text = errorType.localizedDescription
        recoveryLabel.text = errorType.recoveryAction
        
        // Hide retry button if no retry action provided
        retryButton.isHidden = retryAction == nil
    }
    
    private func setupActions() {
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        // Tap to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    @objc private func retryTapped() {
        dismiss(animated: true) {
            self.retryAction?()
        }
    }
    
    @objc private func settingsTapped() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        dismiss(animated: true)
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            dismiss(animated: true)
        }
    }
    
    // MARK: - Animation
    private func animateAppearance() {
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })
    }
}

// MARK: - Convenience Methods
extension ErrorViewController {
    
    static func presentNetworkError(in viewController: UIViewController, retryAction: @escaping () -> Void) {
        let errorVC = ErrorViewController(error: .networkUnavailable, retryAction: retryAction)
        viewController.present(errorVC, animated: true)
    }
    
    static func presentLocationError(in viewController: UIViewController) {
        let errorVC = ErrorViewController(error: .locationPermissionDenied)
        viewController.present(errorVC, animated: true)
    }
    
    static func presentWebViewError(_ error: Error, in viewController: UIViewController, retryAction: @escaping () -> Void) {
        let errorVC = ErrorViewController(error: .webViewLoadFailed(error), retryAction: retryAction)
        viewController.present(errorVC, animated: true)
    }
}