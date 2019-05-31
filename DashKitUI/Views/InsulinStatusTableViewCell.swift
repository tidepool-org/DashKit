//
//  InsulinStatusTableViewCell.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/29/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit
import HealthKit

public class InsulinStatusTableViewCell: UITableViewCell {

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        formatter.formattingContext = .middleOfSentence
        
        return formatter
    }()

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    fileprivate lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 0

        return quantityFormatter
    }()

    @IBOutlet public weak var insulinLabel: UILabel!

    @IBOutlet public weak var recencyLabel: UILabel!

    public func setReservoir(level: ReservoirLevel, validAt date: Date) {

        let time = timeFormatter.string(from: date)

        switch level {
        case .aboveThreshold:
            if let units = numberFormatter.string(from: Pod.maximumReservoirReading) {
                insulinLabel.text = String(format: LocalizedString("Pod Insulin: %@+ U", comment: "Format string for status page reservoir volume when above maximum reading. (1: The maximum reading)"), units)
                accessibilityValue = String(format: LocalizedString("Greater than %1$@ units remaining at %2$@", comment: "Accessibility format string for status page reservoir volume when reading is above maximum (1: localized volume)(2: time)"), units, time)
            }
        case .valid(let value):
            let unit: HKUnit = .internationalUnit()
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            if let quantityString = quantityFormatter.string(from: quantity, for: unit) {
                insulinLabel.text = String(format: LocalizedString("Pod Insulin: %1$@", comment: "Format string for for status page reservoir volume. (1: The localized volume)"), quantityString)
                accessibilityValue = String(format: LocalizedString("%1$@ units remaining at %2$@", comment: "Accessibility format string for status page reservoir volume (1: localized volume)(2: time)"), quantityString, time)
            }
        }
        recencyLabel.text =  String(format: LocalizedString("(updated %1$@)", comment: "Accessibility format string for (1: localized volume)(2: time)"), time)
    }
}

extension InsulinStatusTableViewCell: NibLoadable { }
