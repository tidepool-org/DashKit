//
//  PDMRegistrator.swift
//  DashKit
//
//  Created by Pete Schwamb on 2/11/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

public protocol PDMRegistrator {
    
    /**
     Starts a registration process without SMS validation.
     
     - parameters:
        - completion: A closure to be called when a `PodCommEvent` is issued by the comm. layer.
            - status: Registration status.
     
     - Note: Only use this API if your app does not require SMS validation (as per the Insulet Cloud configuration set for your team).
     */
    func startRegistration(completion: @escaping (PodSDK.RegistrationStatus) -> ())

    /// Registration is complete.
    func isRegistered() -> Bool

}

extension RegistrationManager: PDMRegistrator { }
