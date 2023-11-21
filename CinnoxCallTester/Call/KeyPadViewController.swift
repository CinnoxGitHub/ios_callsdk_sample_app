//
//  KeyPadViewController.swift
//  CinnoxCallTester
//
//  Created by David on 2023/4/25.
//

import UIKit
import Combine

protocol KeyPadViewControllerDelegate: AnyObject {
    func keyPadViewController(controller: KeyPadViewController, completeDial: String)
}

enum KeyPadType {
    case dialpad
    case dtmf
}

class KeyPadViewController: UIViewController {
    
    @IBOutlet weak var dialNumberLabel: UILabel!
    @IBOutlet var keypadButtons: [UIButton]!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var dialButton: UIButton!
    private weak var delegate: KeyPadViewControllerDelegate?
    var keypadType: KeyPadType = .dialpad
    private var subscriptions = Set<AnyCancellable>()
    @Published var currentDialNumber = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        binding()
    }
    
    @IBAction func dialTapped(_ sender: UIButton) {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.keyPadViewController(controller: self, completeDial: self.currentDialNumber)
        }
    }
    
    @IBAction func numberRemoveTapped(_ sender: UIButton) {
        currentDialNumber = String(currentDialNumber.dropLast(1))
    }
    
}

private extension KeyPadViewController {
    func setupUI() {
        view.backgroundColor = keypadType == .dialpad ? .black : .systemGray
        setupButtons()
    }
    
    func binding() {
        $currentDialNumber.receive(on: DispatchQueue.main)
            .sink { [weak self] numberString in
            self?.dialNumberLabel.text = numberString
        }.store(in: &subscriptions)
        
    }
    
    func setupButtons() {
        keypadButtons.forEach { button in
            button.addTarget(self, action: #selector(keypadButtonPressed(_:)), for: .touchUpInside)
        }
        guard keypadType == .dtmf else {
            return
        }
        dialButton.isHidden = true
        deleteButton.isHidden = true
    }
    
    @objc
    func keypadButtonPressed(_ sender: UIButton) {
        guard let padItem = sender.currentTitle else { return }
        currentDialNumber.append(padItem)
        currentDialNumber = addPlusPrefix(for: currentDialNumber)
        guard keypadType == .dtmf else {
            return
        }
        delegate?.keyPadViewController(controller: self, completeDial: self.currentDialNumber)
    }
    
    func addPlusPrefix(for text: String) -> String {
        guard keypadType == .dialpad else {
            return text
        }
        var numberString = text
        if !numberString.hasPrefix("+") {
            numberString = "+" + numberString
        }
        return numberString
    }
}

extension KeyPadViewController {
    static func instantiate(delegate: KeyPadViewControllerDelegate, keypadType: KeyPadType = .dialpad) -> KeyPadViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(withIdentifier: "KeyPadViewController") as? KeyPadViewController
        viewController?.keypadType = keypadType
        viewController?.delegate = delegate
        return viewController
    }
}
