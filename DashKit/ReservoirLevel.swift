//
//  ReservoirLevel.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/31/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation



public enum ReservoirLevel: RawRepresentable, Equatable {
    public typealias RawValue = Int
    
    public static let aboveThresholdMagicNumber: Int = 5115

    case valid(Double)
    case aboveThreshold

    public var percentage: Double {
        switch self {
        case .aboveThreshold:
            return 1
        case .valid(let value):
            // Set 50U as the halfway mark, even though pods can hold 200U.
            return min(1, max(0, value / 100))
        }
    }

    public init(rawValue: RawValue) {
        switch rawValue {
        case Self.aboveThresholdMagicNumber:
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
            return Self.aboveThresholdMagicNumber
        }
    }
}
