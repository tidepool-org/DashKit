//
//  MockPodPumpManager.swift
//  MockPodPlugin
//
//  Created by Pete Schwamb on 12/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import LoopKit

class MockPodPumpManager: DashPumpManager {
    
    let mockPodCommManager: MockPodCommManager

    public override var managerIdentifier: String {
        return "OmnipodDemo"
    }

    public required init(podStatus: MockPodStatus? = nil, state: DashPumpManagerState, dateGenerator: @escaping () -> Date = Date.init) {
        
        mockPodCommManager = MockPodCommManager(podStatus: podStatus)
        
        super.init(state: state, podCommManager: mockPodCommManager, dateGenerator: dateGenerator)

        mockPodCommManager.dashPumpManager = self
        
        mockPodCommManager.addObserver(self, queue: DispatchQueue.main)
    }
    
    public convenience required init?(rawState: PumpManager.RawStateValue) {
        
        guard let rawPumpManagerState = rawState["pumpManagerState"] as? PumpManager.RawStateValue,
              let pumpManagerState = DashPumpManagerState(rawValue: rawPumpManagerState)
        else {
            return nil
        }
        
        let mockPodStatus: MockPodStatus?
        
        if let rawMockPodStatus = rawState["mockPodStatus"] as? MockPodStatus.RawValue {
            mockPodStatus = MockPodStatus(rawValue: rawMockPodStatus)
        } else {
            mockPodStatus = nil
        }
        
        self.init(podStatus: mockPodStatus, state: pumpManagerState)
    }
    
    required convenience init(state: DashPumpManagerState, dateGenerator: @escaping () -> Date = Date.init) {
        self.init(podStatus: nil, state: state, dateGenerator: dateGenerator)
    }
    
    public override var rawState: PumpManager.RawStateValue {
        var value: PumpManager.RawStateValue = [
            "pumpManagerState": super.rawState
        ]
        
        if let podStatus = mockPodCommManager.podStatus {
            value["mockPodStatus"] = podStatus.rawValue
        }
        
        return value
    }
}

extension MockPodPumpManager: MockPodCommManagerObserver {
    func mockPodCommManagerDidUpdate() {
        notifyDelegateOfStateUpdate()
    }
}
