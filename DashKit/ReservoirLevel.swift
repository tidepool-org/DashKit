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
        case aboveThresholdMagicNumber:
            self = .aboveThreshold
        default:
            self = .valid(Double(rawValue) / 100)
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .valid(let value):
            return Int(round(value * 100))
        case .aboveThreshold:
            return aboveThresholdMagicNumber
        }
    }
}
