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
    @IBOutlet weak var userEidOrNumberTextField: UITextField!
    
    private let core = CinnoxCore.current
 
    private var subscriptions = Set<AnyCancellable>()
    
    let defaultCliNumber = "+886910123456"
    let defaultOffnetNumbers = ["+886912345678"]
    let defaultOnnetCalleeEids = ["aaaaaaaa.bbbbbbbbbbbb.cccccccc.dddddddddddddddd"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.callManager?.addDelegate(self)
        dataBinding()
    }
    
    func dataBinding() {
        userEidOrNumberTextField.isUserInteractionEnabled = false
        userEidOrNumberTextField.delegate = self
        
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print(granted)
            }
        }
    }
    
    @IBAction func makeOnnetCall(_ sender: UIButton) {
        showSelectionActionSheet(from: defaultOnnetCalleeEids) { [weak self] calleeEid in
            Task {
                do {
                    try await self?.startOnnetCall(calleeEid: calleeEid)
                } catch {
                    self?.showAlertDialog(title: error.localizedDescription)
                }
            }
        }
        
    }
    
    @IBAction func makeOffnetCall(_ sender: UIButton) {
        guard let keypad = KeyPadViewController.instantiate(delegate: self) else { return }
        present(keypad, animated: true)
    }
    
    deinit {
        for subscription in subscriptions {
            subscription.cancel()
        }
    }
}

// MARK: Dial
extension MakeCallViewController: KeyPadViewControllerDelegate {
    func keyPadViewController(controller: KeyPadViewController, completeDial: String) {
        Task {
            try? await startOffnetCall(phoneNumber: completeDial)
        }
    }
}

// MARK: Make Call
extension MakeCallViewController {
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
    
    func startOffnetCall(phoneNumber: String) async throws {
        let options = CinnoxCallOptions.initOffnetCall(toNumber: phoneNumber, cliNumber: defaultCliNumber)
        guard let session = try? await callManager?.makeCall(callOptions: options) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let callView = CallViewController.instantiate(with: session) else { return }
            callView.modalPresentationStyle = .fullScreen
            self?.present(callView, animated: true)
        }
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
        return true
    }
}

// MARK: Alert, ActionSheet Stuff
extension MakeCallViewController {
    private func showSelectionActionSheet(from contents: [String], completeSelectAction: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var actions = contents.map { content in
            UIAlertAction(title: content, style: .default) { [weak self] _ in
                self?.userEidOrNumberTextField.text = content
                completeSelectAction(content)
            }
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        actions.append(cancel)
        actions.forEach { alertController.addAction($0) }
        present(alertController, animated: true)
    }
    
    func showAlertDialog(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension MakeCallViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        userEidOrNumberTextField.resignFirstResponder()
        return true
    }
}

extension MakeCallViewController {
    static func instantiate() -> MakeCallViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(withIdentifier: "MakeCallViewController") as? MakeCallViewController
        return viewController
    }
}

extension MakeCallViewController {
    var callManager: CinnoxCallManager? {
        return core?.callManager
    }
}

