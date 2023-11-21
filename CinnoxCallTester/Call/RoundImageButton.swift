//
//  CallButton.swift
//  CinnoxCallTester
//
//  Created by David on 2023/4/24.
//

import Foundation
import UIKit

class RoundImageButton: UIButton {
    
    enum ImageType {
        case mute
        case hold
        case end
        case hangup
        case speaker
        case transfer
        
        var image: UIImage? {
            switch self {
            case .mute:
                return UIImage(named: "call-panel-unmute")
            case .hold:
                return UIImage(named: "call-panel-hold")
            case .end:
                return UIImage(named: "call-panel-end")
            case .hangup:
                return UIImage(named: "call-panel-end")
            case .speaker:
                return UIImage(named: "call-panel-audio-speaker")
            case .transfer:
                return UIImage(named: "call-panel-transfer")
            }
        }
    }
    
    init(imageType: ImageType, backgroundColor: UIColor) {
        super.init(frame: .zero)
        
        // Set button image and background color
        setImage(imageType.image, for: .normal)
        imageView?.contentMode = .scaleAspectFit
        
        // Set background color and make the button round
        self.backgroundColor = backgroundColor
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true
        
        // Set button size constraints
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: bounds.width).isActive = true
        heightAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    
    func setSelected(isSelected: Bool) {
        DispatchQueue.main.async {
            self.backgroundColor = isSelected ? .white : .darkGray
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
    
}
