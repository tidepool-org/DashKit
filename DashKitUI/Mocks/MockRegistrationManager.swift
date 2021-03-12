//
//  MockRegistrationManager.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import DashKit
import PodSDK

public class MockRegistrationManager: PDMRegistrator {
    
    public var initialResponse: RegistrationStatus = .connectionTimeout
    
    private var attemptCount: Int = 0
    
    private var _isRegistered: Bool

    public init(isRegistered: Bool = false) {
        self._isRegistered = isRegistered
    }
    
    func startRegistration(phoneNumber: String, completion: @escaping (RegistrationStatus) -> ()) {
        // not used
        completion(.invalidConfiguration)
    }
    
    public func startRegistration(completion: @escaping (RegistrationStatus) -> ()) {
        attemptCount += 1
        let localAttemptCount = attemptCount
        
        if _isRegistered {
            DispatchQueue.main.async {
                completion(.alreadyRegistered)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if localAttemptCount == 1 {
                    completion(self.initialResponse)
                } else {
                    completion(.registered)
                }
            }
        }
    }
    
    func finishRegistration(verificationCode: String, completion: @escaping (RegistrationStatus) -> ()) {
        // not used
        completion(.registered)
    }
    
    public func isRegistered() -> Bool {
        return _isRegistered
    }
    
    
}
