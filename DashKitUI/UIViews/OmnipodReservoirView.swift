//
//  OmnipodReservoirView.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKitUI
import DashKit

public final class OmnipodReservoirView: LevelHUDView, NibLoadable {
    
    override public var orderPriority: HUDViewOrderPriority {
        return 11
    }

    @IBOutlet private weak var volumeLabel: UILabel!
    
    @IBOutlet private weak var alertLabel: UILabel! {
        didSet {
            alertLabel.alpha = 0
            alertLabel.textColor = UIColor.white
            alertLabel.layer.cornerRadius = 9
            alertLabel.clipsToBounds = true
        }
    }

    public class func instantiate() -> OmnipodReservoirView {
        return nib().instantiate(withOwner: nil, options: nil)[0] as! OmnipodReservoirView
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        volumeLabel.isHidden = true
    }

    private var reservoirLevel: ReservoirLevel?
    private var lastUpdateDate: Date?
    private var reservoirAlertState = ReservoirAlertState.ok

    override public func tintColorDidChange() {
        super.tintColorDidChange()
        
        volumeLabel.textColor = tintColor
    }

    
    private func updateColor() {
        switch reservoirAlertState {
        case .lowReservoir, .empty:
            alertLabel?.backgroundColor = stateColors?.warning
        case .ok:
            alertLabel?.backgroundColor = stateColors?.normal
        }
    }

    override public func stateColorsDidUpdate() {
        super.stateColorsDidUpdate()
        updateColor()
    }

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    private func updateViews() {
        if let reservoirLevel = reservoirLevel, let date = lastUpdateDate {

            let time = timeFormatter.string(from: date)
            caption?.text = time

            // graduations changed from that in the LevelHUDView. This sets the label and image colour
            switch reservoirLevel {
            case .aboveThreshold:
                level = nil
                volumeLabel.isHidden = true
                volumeLabel.textColor = stateColors?.normal
                tintColor = stateColors?.normal
                if let units = numberFormatter.string(from: Pod.maximumReservoirReading) {
                    volumeLabel.text = String(format: LocalizedString("%@+ U", comment: "Format string for reservoir volume when above maximum reading. (1: The maximum reading)"), units)
                    accessibilityValue = String(format: LocalizedString("Greater than %1$@ units remaining at %2$@", comment: "Accessibility format string for (1: localized volume)(2: time)"), units, time)
                }
            case .valid(let value):
                level = reservoirLevel.asPercentage()
                switch level {
                case .none:
                    volumeLabel.isHidden = true
                    volumeLabel.textColor = stateColors?.unknown
                    tintColor = stateColors?.unknown
                case let x? where x > 0.5:
                    volumeLabel.isHidden = true
                    volumeLabel.textColor = stateColors?.normal
                    tintColor = stateColors?.normal
                case let x? where x > 0.2:
                    volumeLabel.isHidden = false
                    volumeLabel.textColor = stateColors?.warning
                    tintColor = stateColors?.warning
                default:
                    volumeLabel.isHidden = false
                    volumeLabel.textColor = stateColors?.error
                    tintColor = stateColors?.error
                }

                if let units = numberFormatter.string(from: value) {
                    volumeLabel.text = String(format: LocalizedString("%@U", comment: "Format string for reservoir volume. (1: The localized volume)"), units)

                    accessibilityValue = String(format: LocalizedString("%1$@ units remaining at %2$@", comment: "Accessibility format string for (1: localized volume)(2: time)"), units, time)
                }
            }
        } else {
            level = 0
            volumeLabel.isHidden = true
        }

        var alertLabelAlpha: CGFloat = 1
        switch reservoirAlertState {
        case .ok:
            alertLabelAlpha = 0
        case .lowReservoir, .empty:
            alertLabel?.text = "!"
        }

        UIView.animate(withDuration: 0.25, animations: {
            self.alertLabel?.alpha = alertLabelAlpha
        })
    }

    public func update(level: ReservoirLevel?, at date: Date, reservoirAlertState: ReservoirAlertState) {
        self.reservoirLevel = level
        self.lastUpdateDate = date
        self.reservoirAlertState = reservoirAlertState
        updateViews()
    }
}
