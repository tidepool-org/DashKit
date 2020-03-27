//
//  MockCannulaInsertion.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import DashKit
import PodSDK

class MockCannulaInsertion: CannulaInsertion {
    
    private var attemptCount = 0
    
    func insertCannula(eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        attemptCount += 1
        
        if attemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(.bleCommunicationError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                eventListener(.event(.insertingCannula))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Pod.estimatedCannulaInsertionDuration) {
                eventListener(.event(.step2Completed))
            }
        }
    }
}
