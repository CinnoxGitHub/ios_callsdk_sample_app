//
//  CallViewController.swift
//  CinnoxCallTester
//
//  Created by David on 2023/4/24.
//

import UIKit
import M800CallSDK
import M800CoreSDK
import Combine

class CallViewController: UIViewController {
    let callControlStackView = UIStackView()
    let callControlBottomView = UIView()
    
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var recordingStatusLabel: UILabel!
    
    let muteButton = RoundImageButton(imageType: .mute, backgroundColor: .white)
    let holdButton = RoundImageButton(imageType: .hold, backgroundColor: .white)
    let hangupButton = RoundImageButton(imageType: .hangup, backgroundColor: .systemRed)
    let routingButton = RoundImageButton(imageType: .speaker, backgroundColor: .white)
    let dtmfButton = RoundImageButton(imageType: .dtmf, backgroundColor: .white)
    
    @IBOutlet weak var callInviteView: UIStackView!
    let durationTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    let recordingTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private var subscriptions = Set<AnyCancellable>()
    
    
    private (set) var callSession: CinnoxCallSession?
    @Published private var hideCallControls = false
    @Published var callState: CinnoxCallState = .created
    @Published var isSpeakerOn = false
    private var dtmfFullText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        binding()
        callSession?.addDelegate(self)
        view.backgroundColor = .black
        setupInitialCallState()
        generateCallControls()
    }
    
    @IBAction func pickupCallTapped(_ sender: UIButton) {
        guard let callSession = callSession, callSession.direction == .incoming else { return }
        callSession.answer()
    }
    
    @IBAction func rejectCallTapped(_ sender: UIButton) {
        hangup()
    }
    
    @objc
    private func mute() {
        guard let callSession = callSession else { return }
        callSession.setMute(enabled: !callSession.isMute)
    }
    
    @objc
    private func hold() {
        guard let callSession = callSession else { return }
        callSession.setHold(enabled: !callSession.isHeld)
    }
    
    @objc
    private func hangup() {
        guard let callSession = callSession else { return }
        callSession.hangUp(isUserClickHangUp: true)
    }
    
    @objc
    private func changeRoute() {
        let newState = !isSpeakerOn
        let newRoute: CinnoxAudioRoute = newState ? .speaker : .earpiece
        CinnoxCore.current?.callManager?.audioController.setAudioRoute(route: newRoute)
        isSpeakerOn = newState
    }
    
    @objc
    private func dtmf() {
        guard let keypad = KeyPadViewController.instantiate(delegate: self, keypadType: .dtmf) else { return }
        keypad.currentDialNumber = dtmfFullText
        let popoverViewController = UINavigationController(rootViewController: keypad)
        popoverViewController.modalPresentationStyle = .popover
        keypad.preferredContentSize = CGSize(width: 320, height: 500)
        if let popoverController = popoverViewController.popoverPresentationController {
            popoverController.delegate = self
            popoverController.sourceView = dtmfButton
            popoverController.sourceRect = dtmfButton.bounds
            popoverController.permittedArrowDirections = .any
            popoverController.backgroundColor = UIColor.white
            present(popoverViewController, animated: true, completion: nil)
        }
    }
    
    private func binding() {
        $hideCallControls.receive(on: DispatchQueue.main)
            .sink { [weak self] isHidden in
                guard let self = self else { return }
                self.callControlBottomView.isHidden = isHidden
                self.callInviteView.isHidden = !isHidden
            }.store(in: &subscriptions)
        
        $callState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
            self?.handleUI(state: state)
        }.store(in: &subscriptions)
        
        $isSpeakerOn.receive(on: DispatchQueue.main)
            .sink { [weak self] enabeld in
                self?.routingButton.setSelected(isSelected: enabeld)
        }.store(in: &subscriptions)
    }
    
    func updateDuration() {
        durationTimer.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            guard let self = self else { return }
            guard let callSession = self.callSession else { return }
            let second = callSession.talkingTime
            let isHold = callSession.isHeld || callSession.isRemoteHeld
            self.callStatusLabel.text = isHold ? "Hold" : second.secondsAsString()
        }.store(in: &subscriptions)
        
        recordingTimer.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            guard let self = self else { return }
            guard let callSession = self.callSession else { return }
            let second = callSession.getRecordingDuration()
            guard second > 0 else {
                self.recordingStatusLabel.text = ""
                return
            }
            
            let attributedText = NSMutableAttributedString(string: "● ")
            attributedText.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 1))
            attributedText.append(NSAttributedString(string: second.secondsAsString()))

            self.recordingStatusLabel.attributedText = attributedText
        }.store(in: &subscriptions)
    }
    
    deinit {
        for subscription in subscriptions {
            subscription.cancel()
        }
    }
}

extension CallViewController: KeyPadViewControllerDelegate {
    func keyPadViewController(controller: KeyPadViewController, completeDial: String) {
        dtmfFullText = completeDial
        guard let digitalCharacter = dtmfFullText.last else {
            return
        }
        let digitalString = String(digitalCharacter)
        callSession?.sendDTMF(digits: digitalString)
    }
}

extension CallViewController: CinnoxCallSessionDelegate {
    func onCallStateChanged(session: CinnoxCallSession, state: CinnoxCallState) {
        callState = state
    }
    
    func onMuteStateChange(session: CinnoxCallSession, isMute: Bool) {
        muteButton.setSelected(isSelected: !isMute)
    }
}


// MARK: UI
private extension CallViewController {
    func generateCallControls() {
        recordingStatusLabel.text = ""
        view.addSubview(callControlBottomView)
        callControlBottomView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            callControlBottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            callControlBottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            callControlBottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            callControlBottomView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        callControlBottomView.addSubview(callControlStackView)
        callControlBottomView.backgroundColor = UIColor(red: 38 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1)
        
        // Set stack view constraints
        callControlStackView.axis = .horizontal
        callControlStackView.distribution = .fillEqually
        callControlStackView.spacing = 16
        callControlStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            callControlStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            callControlStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            callControlStackView.centerXAnchor.constraint(equalTo: callControlBottomView.centerXAnchor),
            callControlStackView.centerYAnchor.constraint(equalTo: callControlBottomView.centerYAnchor),
            callControlStackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        muteButton.addTarget(self, action: #selector(mute), for: .touchUpInside)
        holdButton.addTarget(self, action: #selector(hold), for: .touchUpInside)
        hangupButton.addTarget(self, action: #selector(hangup), for: .touchUpInside)
        routingButton.addTarget(self, action: #selector(changeRoute), for: .touchUpInside)
        dtmfButton.addTarget(self, action: #selector(dtmf), for: .touchUpInside)
  
        [muteButton, holdButton, hangupButton, routingButton, dtmfButton].forEach { button in
            callControlStackView.addArrangedSubview(button)
        }
    }
    
    func setupInitialCallState() {
        guard let callSession = callSession else { return }
        if callSession.direction == .incoming {
            hideCallControls = true
            callStatusLabel.text = "Incoming Call"
        } else {
            callStatusLabel.text = "Calling"
        }
    }
    
    func handleUI(state: CinnoxCallState) {
        switch state {
        case .created:
            holdButton.isEnabled = false
            holdButton.setSelected(isSelected: false)
        case .talking:
            holdButton.isEnabled = true
            hideCallControls = false
            holdButton.setSelected(isSelected: false)
            updateDuration()
        case .hold:
            holdButton.setSelected(isSelected: true)
            callStatusLabel.text = "Hold"
        case .remoteHold:
            holdButton.isEnabled = false
            holdButton.setSelected(isSelected: true)
            callStatusLabel.text = "Hold"
        case .terminated, .destroyed, .unknown:
            dismiss(animated: true)
        default:
            break
        }
    }
    
}

extension CallViewController {
    static func instantiate(with callSession: CinnoxCallSession) -> CallViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(withIdentifier: "CallViewController") as? CallViewController
        viewController?.callSession = callSession
        return viewController
    }
}

extension CallViewController: UIPopoverPresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension Double {
    func secondsAsString() -> String {
        let interval: TimeInterval = self
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if self > 3_600 {
            formatter.dateFormat = "HH:mm:ss"
        } else {
            formatter.dateFormat = "mm:ss"
        }

        return formatter.string(from: Date(timeIntervalSinceReferenceDate: interval))
    }
}
