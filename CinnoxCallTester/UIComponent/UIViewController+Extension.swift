//
//  UIViewController+Extension.swift
//  CinnoxCallTester
//
//  Created by David Hsu on 2024/2/7.
//

import Foundation
import UIKit

extension UIViewController {
    
    func showToast(message: String, duration: TimeInterval = 3.0) {
        let toastContainer = UIView()
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastContainer.alpha = 0.0
        toastContainer.clipsToBounds  =  true

        let toastLabel = UILabel()
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = toastLabel.font.withSize(12.0)
        toastLabel.text = message
        toastLabel.numberOfLines = 0

        toastContainer.addSubview(toastLabel)
        view.addSubview(toastContainer)

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 8),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -8),
            toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 8),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -8),
            toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            toastContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        // Layout to calculate dynamic size
        view.layoutIfNeeded()

        // Adjust corner radius based on height of the container
        toastContainer.layer.cornerRadius = toastContainer.frame.height / 2

        UIView.animate(withDuration: 0.5, animations: {
            toastContainer.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }, completion: {_ in
                toastContainer.removeFromSuperview()
            })
        })
    }
}
