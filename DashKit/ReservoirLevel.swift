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

    case empty
    case valid(Double)
    case aboveThreshold

    public func asPercentage() -> Double? {
        switch self {
        case .empty:
            return 0
        case .aboveThreshold:
            return nil
        case .valid(let value):
            return min(1, max(0, value / Pod.reservoirCapacity))
        }
    }

    public init(rawValue: RawValue) {
        switch rawValue {
        case 0:
            self = .empty
        case aboveThresholdMagicNumber:
            self = .aboveThreshold
        default:
            self = .valid(Double(rawValue) / 100)
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .empty:
            return 0
        case .valid(let value):
            return Int(round(value * 100))
        case .aboveThreshold:
            return aboveThresholdMagicNumber
        }
    }
}
