//
//  MockPodVersion.swift
//  DashKit
//
//  Created by Pete Schwamb on 5/7/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

public struct MockPodVersion: PodVersionProtocol {
    public var lotNumber: Int
    public var sequenceNumber: Int
    public var majorVersion: Int
    public var minorVersion: Int
    public var interimVersion: Int
    public var bleMajorVersion: Int
    public var bleMinorVersion: Int
    public var bleInterimVersion: Int
    
    public init(
        lotNumber: Int,
        sequenceNumber: Int,
        majorVersion: Int,
        minorVersion: Int,
        interimVersion: Int,
        bleMajorVersion: Int,
        bleMinorVersion: Int,
        bleInterimVersion: Int
    ) {
        self.lotNumber = lotNumber
        self.sequenceNumber = sequenceNumber
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.interimVersion = interimVersion
        self.bleMajorVersion = bleMajorVersion
        self.bleMinorVersion = bleMinorVersion
        self.bleInterimVersion = bleInterimVersion
    }
}
