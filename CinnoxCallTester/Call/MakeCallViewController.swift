//
//  MakeCallViewController.swift
//  CinnoxCallTester
//
//  Created by David on 2023/3/20.
//

import UIKit
import M800CoreSDK
import M800CallSDK
import AVFAudio
import Combine

class MakeCallViewController: UIViewController {
    
    // MARK: UI elements
    @IBOutlet weak var onnetCallButton: UIButton!
    @IBOutlet weak var offnetCallButton: UIButton!
    
    @IBOutlet weak var offnetStackView: UIStackView!
    @IBOutlet weak var onnetStackView: UIStackView!
    
    @IBOutlet weak var callerCLITextField: UITextField!
    @IBOutlet weak var calleeNumberTextField: UITextField!
    
    @IBOutlet weak var calleeEidTextField: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    
    private var core: CinnoxCore? {
        return CinnoxCore.current
    }
    
    var callManager: CinnoxCallManager? {
        return core?.callManager
    }
    
    var staffManager: CinnoxStaffManager? {
        return core?.staffManager
    }
 
    @Published private var hadLogin: Bool = false
    private var subscriptions = Set<AnyCancellable>()
    
    let serviceName = "YOURSERVICENAME.cinnox.com"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.callManager?.addDelegate(self)
        binding()
        setupUI()
        setupAudioPermission()
        checkLogin()
    }
    
    // MARK: Make Call
    @IBAction func makeOnnetCall(_ sender: UIButton) {
        let calleeEid = calleeEidTextField.text ?? ""
        Task {
            do {
                guard !calleeEid.isEmpty else {
                    showAlertDialog(title: "Missing Callee Eid")
                    return
                }
                try await startOnnetCall(calleeEid: calleeEid)
            } catch {
                showAlertDialog(title: error.localizedDescription)
            }
        }
    }
    
    @IBAction func makeOffnetCall(_ sender: UIButton) {
        let callerCLI = callerCLITextField.text ?? ""
        let calleeNumber = calleeNumberTextField.text ?? ""
        Task {
            do {
                guard !callerCLI.isEmpty, !calleeNumber.isEmpty else {
                    showAlertDialog(title: "Missing Caller CLI or Callee Number")
                    return
                }
                try await startOffnetCall(callerCLI: callerCLI, phoneNumber: calleeNumber)
            } catch {
                showAlertDialog(title: error.localizedDescription)
            }
        }
    }
    
    func startOnnetCall(calleeEid: String) async throws {
        let options = CinnoxCallOptions.initOnnetCall(eid: calleeEid)
        guard let session = try? await callManager?.makeCall(callOptions: options) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let callView = CallViewController.instantiate(with: session) else { return }
            callView.modalPresentationStyle = .fullScreen
            self?.present(callView, animated: true)
        }
    }
    
    func startOffnetCall(callerCLI: String, phoneNumber: String) async throws {
        let options = CinnoxCallOptions.initOffnetCall(toNumber: phoneNumber, cliNumber: callerCLI)
        guard let session = try? await callManager?.makeCall(callOptions: options) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let callView = CallViewController.instantiate(with: session) else { return }
            callView.modalPresentationStyle = .fullScreen
            self?.present(callView, animated: true)
        }
    }

    @objc func selectCallerCli() {
        Task {
            // Fetch CinnoxCli list
            let callerCliList = try await staffManager?.fetchCliList() ?? []
            presentCliSelectionAlert(cliList: callerCliList)
        }
    }

    @IBAction func onLoginTapped(_ sender: UIButton) {
        let alertContoller = UIAlertController(title: "Login", message: nil, preferredStyle: .alert)
        alertContoller.addTextField { textField in
            textField.placeholder = "Account"
        }
        
        alertContoller.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        let loginAction = UIAlertAction(title: "Login", style: .default) { [weak self] _ in
            guard let account = alertContoller.textFields?.first?.text, let password = alertContoller.textFields?.last?.text else {
                return
            }
            self?.login(account: account, password: password)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertContoller.addAction(cancelAction)
        alertContoller.addAction(loginAction)
        present(alertContoller, animated: true)
    }
    
    @IBAction func onLogoutTapped(_ sender: UIButton) {
        logout()
    }
    
    @IBAction func onCallTypeSwitch(_ sender: UISwitch) {
        offnetStackView.isHidden = sender.isOn
        offnetCallButton.isHidden = sender.isOn
        onnetStackView.isHidden = !sender.isOn
        onnetCallButton.isHidden = !sender.isOn
    }
}

// MARK: CallSessionDelegate
extension MakeCallViewController: CinnoxCallManagerDelegate {
    func onStateChanged(newState: CinnoxCallManagerState) -> Bool {
        return true
    }
    
    func onIncomingCall(session: CinnoxCallSession) -> Bool {
        DispatchQueue.main.async { [weak self] in
            guard let callView = CallViewController.instantiate(with: session) else { return }
            callView.modalPresentationStyle = .fullScreen
            self?.present(callView, animated: true)
        }
        return true
    }
    
    func onMissedCall(info: M800CallSDK.CinnoxMissedCallInfo) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.showToast(message: "Call Missed")
        }
        return true
    }
}

// MARK: Authentication
extension MakeCallViewController {
    func login(account: String, password: String) {
        core?.authenticationManager?.login(account: account, password: password, completionHandler: { [weak self] eid, error in
            if let error = error {
                NSLog("login account(\(account) failed: \(error)")
                return
            }
            self?.hadLogin = true
        })
    }
    
    func logout() {
        core?.authenticationManager?.logout(completionHandler: { [weak self] error in
            if let error = error {
                NSLog("logout failed: \(error)")
                return
            } else {
                self?.hadLogin = false
            }
        })
    }
    
    func checkLogin() {
        guard let core = CinnoxCore.initialize(serviceName: serviceName) else { return }
        if core.authenticationManager?.isUserLogin() ?? false {
            hadLogin = true
        }
    }
}

// MARK: Utils
extension MakeCallViewController {
    @MainActor
    func showAlertDialog(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @MainActor
    func presentCliSelectionAlert(cliList: [CinnoxCli]) {
        let alertContoller = UIAlertController(title: "Select Caller CLI", message: nil, preferredStyle: .actionSheet)
        cliList.forEach { cinnoxCli in
            let action = UIAlertAction(title: cinnoxCli.number, style: .default) { [weak self] _ in
                self?.callerCLITextField.text = cinnoxCli.number
            }
            alertContoller.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertContoller.addAction(cancelAction)
        present(alertContoller, animated: true)
    }
    
    func setupAudioPermission() {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print(granted)
            }
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func binding() {
        $hadLogin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isUserLogin in
                guard let self = self else { return }
                self.loginButton.isHidden = isUserLogin
                self.logoutButton.isHidden = !isUserLogin
                self.onnetCallButton.isEnabled = isUserLogin
                self.offnetCallButton.isEnabled = isUserLogin
            }.store(in: &subscriptions)
    }
    
    func setupUI() {
        callerCLITextField.placeholder = "Caller CLI Number(ex. +852xxxxxxxxx)"
        calleeEidTextField.placeholder = "Callee Eid(ex. aaaaaaaa.bbbbbbbbbbbb.cccccccc.dddddddddddddddd)"
        calleeNumberTextField.placeholder = "Callee Number(ex. +852xxxxxxxxx)"
        onnetCallButton.isHidden = true
        callerCLITextField.keyboardType = .phonePad
        calleeNumberTextField.keyboardType = .phonePad
        
        let selectCallerCliGesture = UITapGestureRecognizer(target: self, action: #selector(selectCallerCli))
        callerCLITextField.addGestureRecognizer(selectCallerCliGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
}
