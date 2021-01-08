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

    public func asPercentage() -> Double? {
        switch self {
        case .aboveThreshold:
            return nil
        case .valid(let value):
            return min(1, max(0, value / Pod.reservoirCapacity))
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
