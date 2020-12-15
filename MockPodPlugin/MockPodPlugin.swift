//
//  MockPodPlugin.swift
//  MockPodPlugin
//
//  Created by Pete Schwamb on 12/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import LoopKitUI
import DashKit
import DashKitUI
import os.log

class MockPodPlugin: NSObject, LoopUIPlugin {
    
    private let log = OSLog(category: "MockPodPlugin")

    public var pumpManagerType: PumpManagerUI.Type? {
        return MockPodPumpManager.self
    }

    public var cgmManagerType: CGMManagerUI.Type? {
        return nil
    }

    override init() {
        super.init()
        log.default("MockPodPlugin Instantiated")
    }
}
