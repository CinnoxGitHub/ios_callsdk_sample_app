//
//  ViewController.swift
//  CinnoxCallTester
//
//  Created by David on 2023/3/19.
//

import UIKit
import M800CoreSDK
import Combine
public typealias GenericClosure = () -> Void

class LoginViewController: UIViewController {
    
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    
    @Published var hadLogin: Bool = false
    private var subscriptions = Set<AnyCancellable>()
    
    let serviceName = "YOURSERVICENAME.cinnox.com"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
        checkLogin()
    }
    
    private func binding() {
        $hadLogin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success in
            if success {
                self?.showHomePage()
            }
        }.store(in: &subscriptions)
    }
    
    @IBAction func login(_ sender: UIButton) {
        guard let account = emailTextField.text, let password = passwordTextField.text else {
            return
        }
        CinnoxCore.current?.authenticationManager?.login(account: account, password: password, completionHandler: { [weak self] eid, error in
            if let error = error {
                NSLog("login account(\(account) failed: \(error)")
                return
            }
            self?.hadLogin = true
        })
    }
    
    deinit {
        for subscription in subscriptions {
            subscription.cancel()
        }
    }
}

private extension LoginViewController {
    func checkLogin() {
        guard let core = CinnoxCore.initialize(serviceId: serviceName) else {
            return
        }
        if core.authenticationManager?.isUserLogin() ?? false {
            hadLogin = true
        }
    }
}

private extension LoginViewController {
    func showHomePage() {
        guard let makeCallVC = MakeCallViewController.instantiate() else { return }
        let navigationController = UINavigationController(rootViewController: makeCallVC)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
}

