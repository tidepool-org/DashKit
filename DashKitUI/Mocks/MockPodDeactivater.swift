//
//  MockPodDeactivater.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import DashKit
import PodSDK

class MockPodDeactivater: PodDeactivater {
    private var attemptCount = 0
    
    func deactivatePod(completion: @escaping (PodCommResult<PodStatus>) -> ()) {
        attemptCount += 1
        
        if attemptCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion(.failure(.bleCommunicationError))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success(MockPodStatus.normal))
            }
        }
    }
    
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(.success(true))
        }
    }
    
}
