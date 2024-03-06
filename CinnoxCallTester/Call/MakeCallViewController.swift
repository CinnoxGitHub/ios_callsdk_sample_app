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
    
    @Published private var hadLogin: Bool = false
    private var subscriptions = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
        setupUI()
        setupAudioPermission()
        checkLogin()
        self.callManager?.addDelegate(self)
    }
}

// MARK: CinnoxCallManagerDelegate
extension MakeCallViewController: CinnoxCallManagerDelegate {
    func onStateChanged(newState: CinnoxCallManagerState) -> Bool {
        return true
    }
    
    @MainActor
    func onIncomingCall(session: CinnoxCallSession) -> Bool {
        DispatchQueue.main.async { [weak self] in
            guard let callView = CallViewController.instantiate(with: session) else { return }
            callView.modalPresentationStyle = .fullScreen
            self?.present(callView, animated: true)
        }
        return true
    }
    
    func onMissedCall(info: M800CallSDK.CinnoxMissedCallInfo) -> Bool {
        showToast(message: "Call Missed")
        return true
    }
}

// MARK: Make On-net Call
private extension MakeCallViewController {
    @IBAction func makeOnnetCall(_ sender: UIButton) {
        let calleeEid = calleeEidTextField.text ?? ""
        guard !calleeEid.isEmpty else {
            showAlertDialog(title: "Missing Callee Eid")
            return
        }
        Task {
            do {
                try await startOnnetCall(calleeEid: calleeEid)
            } catch {
                showAlertDialog(title: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    func startOnnetCall(calleeEid: String) async throws {
        let options = CinnoxCallOptions.initOnnetCall(eid: calleeEid)
        guard let session = try? await callManager?.makeCall(callOptions: options) else {
            return
        }
        guard let callView = CallViewController.instantiate(with: session) else { return }
        callView.modalPresentationStyle = .fullScreen
        present(callView, animated: true)
    }
}

// MARK: Make Off-net Call
private extension MakeCallViewController {
    @IBAction func makeOffnetCall(_ sender: UIButton) {
        let callerCLI = callerCLITextField.text ?? ""
        let calleeNumber = calleeNumberTextField.text ?? ""
        guard !callerCLI.isEmpty, !calleeNumber.isEmpty else {
            showAlertDialog(title: "Missing Caller CLI or Callee Number")
            return
        }
        Task {
            do {
                try await startOffnetCall(callerCLI: callerCLI, phoneNumber: calleeNumber)
            } catch {
                showAlertDialog(title: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    func startOffnetCall(callerCLI: String, phoneNumber: String) async throws {
        let options = CinnoxCallOptions.initOffnetCall(toNumber: phoneNumber, cliNumber: callerCLI)
        guard let session = try? await callManager?.makeCall(callOptions: options) else {
            return
        }
        guard let callView = CallViewController.instantiate(with: session) else { return }
        callView.modalPresentationStyle = .fullScreen
        present(callView, animated: true)
    }

    @objc func selectCallerCli() {
        Task {
            // Fetch CinnoxCli list
            let callerCliList = try await staffManager?.fetchCliList() ?? []
            presentCliSelectionAlert(cliList: callerCliList)
        }
    }
}

// MARK: Authentication
private extension MakeCallViewController {
    func checkLogin() {
        guard let core = CinnoxCore.current else { return }
        if core.authenticationManager?.isUserLogin() ?? false {
            hadLogin = true
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
    
    func login(account: String, password: String) {
        Task { [weak self] in
            do {
                guard let eid = try await self?.core?.authenticationManager?.loginStaff(email: account, password: password) else {
                    return
                }
                NSLog("login account(\(account) success, eid: \(eid)")
                self?.hadLogin = true
            } catch {
                NSLog("login account(\(account)) failed: \(error)")
            }
        }
    }
    
    @IBAction func onLogoutTapped(_ sender: UIButton) {
        logout()
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
}

// MARK: Configure
private extension MakeCallViewController {
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
    
    func setupAudioPermission() {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print(granted)
            }
        }
    }
    
    @IBAction func onCallTypeSwitch(_ sender: UISwitch) {
        offnetStackView.isHidden = sender.isOn
        offnetCallButton.isHidden = sender.isOn
        onnetStackView.isHidden = !sender.isOn
        onnetCallButton.isHidden = !sender.isOn
    }
}

// MARK: Utils
private extension MakeCallViewController {
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
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

private extension MakeCallViewController {
    var core: CinnoxCore? {
        return CinnoxCore.current
    }
    
    var callManager: CinnoxCallManager? {
        return core?.callManager
    }
    
    var staffManager: CinnoxStaffManager? {
        return core?.staffManager
    }
}
