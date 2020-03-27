//
//  RegistrationViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import os.log
import DashKit
import SwiftUI
import LoopKitUI
import Combine

public struct RegistrationError: Error, LocalizedError {
    let registrationStatus: RegistrationStatus
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch registrationStatus {
        case .alreadyRegistered:
            return LocalizedString("Already registered.", comment: "Description of registration error when already registered.")
        case .connectionTimeout:
            return LocalizedString("Connection timeout.", comment: "Description of registration error for connection timeout.")
        case .noDataConnection:
            return LocalizedString("No data connection.", comment: "Description of registration error for connection timeout.")
        default:
            return LocalizedString("Unknown Error.", comment: "Description of registration error when error is unknown.")
        }
    }

//    /// A localized message describing the reason for the failure.
//    var failureReason: String? {
//    }
//
//    /// A localized message describing how one might recover from the failure.
//    var recoverySuggestion: String? { get }
//
//    /// A localized message providing "help" text if the user requests help.
//    var helpAnchor: String? { get }
}


class RegistrationViewModel: ObservableObject, Identifiable {
    @Published var error: RegistrationError?
    
    @Published var progressState: ProgressIndicatorState
    
    @Published var isRegistered: Bool
    
    @Published var isRegistering: Bool
    
    private var registrationManager: RegistrationManagerProtocol

    private let log = OSLog(category: "RegistrationViewModel")
    
    var completion: (() -> Void)?

    init(registrationManager: RegistrationManagerProtocol) {
        self.registrationManager = registrationManager
        isRegistered = registrationManager.isRegistered()
        isRegistering = false
        progressState = .hidden
    }

    func registerTapped() {
        if isRegistered {
            completion?()
        }
        
        isRegistering = false
        error = nil
        self.progressState = .indeterminantProgress
        registrationManager.startRegistration { (status) in
            self.isRegistering = false
            switch status {
            case .registered, .alreadyRegistered:
                self.isRegistered = true
                self.progressState = .completed
            default:
                self.error = RegistrationError(registrationStatus: status)
                self.progressState = .hidden
            }
        }
    }
}
