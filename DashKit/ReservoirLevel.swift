//
//  ReservoirLevel.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/31/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

fileprivate let aboveThresholdMagicNumber: Int = 5115

public enum ReservoirLevel: RawRepresentable, Equatable {
    public typealias RawValue = Int

    case valid(Double)
    case aboveThreshold // the threshold is 50 units remaining

    public func asPercentage() -> Double? {
        switch self {
        case .aboveThreshold:
            // reservoir has more than 50 units remaining
            return nil
        case .valid(let value):
            // design requested that reservoir level start display at 50%. This means that 50 units remaining = 50%, 25 units = 25% and so on.
            return min(1, max(0, value / 100))
        }
    }

    public init(rawValue: RawValue) {
        switch rawValue {
        case aboveThresholdMagicNumber:
            self = .aboveThreshold
        default:
            self = .valid(Double(rawValue) / Pod.podSDKInsulinMultiplier)
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .valid(let value):
            return Int(round(value * Pod.podSDKInsulinMultiplier))
        case .aboveThreshold:
            return aboveThresholdMagicNumber
        }
    }
}
