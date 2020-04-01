//
//  MockPodPairer.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/5/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import PodSDK
import DashKit


class MockPodPairer: PodPairer {
    private var attemptCount = 0
    
    var podCommState: PodCommState = .noPod
    
    //var initialError: PodCommError = .internalError(.incompatibleProductId)
    var initialError: PodCommError = .podNotAvailable

    func pair(eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        attemptCount += 1
        
        if attemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                eventListener(.error(self.initialError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                eventListener(.event(.connecting))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.podCommState = .activating
                eventListener(.event(.primingPod))
            }
            // Priming is normally 35s, but we'll send the completion faster in the mock
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.podCommState = .active
                eventListener(.event(.step1Completed))
            }
        }
    }
    
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.podCommState = .noPod
            completion(.success(true))
        }
    }
}
