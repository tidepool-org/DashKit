//
//  DeactivatePodViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import DashKit
import LoopKitUI

class DeactivatePodViewModel: ObservableObject, Identifiable {
    
    enum DeactivatePodViewModelState {
        case active
        case deactivating
        case resultError(DeactivationError)
        case finished
        
        var actionButtonAccessibilityLabel: String {
            switch self {
            case .active:
                return LocalizedString("Deactivate Pod", comment: "Deactivate pod action button accessibility label while ready to deactivate")
            case .deactivating:
                return LocalizedString("Deactivating.", comment: "Deactivate pod action button accessibility label while deactivating")
            case .resultError(let error):
                return String(format: "%@ %@", error.errorDescription ?? "", error.recoverySuggestion ?? "")
            case .finished:
                return LocalizedString("Pod deactivated successfully. Continue.", comment: "Deactivate pod action button accessibility label when deactivation complete")
            }
        }

        var actionButtonDescription: String {
            switch self {
            case .active:
                return LocalizedString("Deactivate Pod", comment: "Action button description for deactivate while pod still active")
            case .resultError:
                return LocalizedString("Retry Deactivation", comment: "Action button description for deactivate after failed attempt")
            case .deactivating:
                return LocalizedString("Deactivating...", comment: "Action button description while deactivating")
            case .finished:
                return LocalizedString("Continue", comment: "Action button description when deactivated")
            }
        }
        
        var actionButtonStyle: ActionButton.ButtonType {
            switch self {
            case .active, .resultError:
                return .destructive
            default:
                return .primary
            }
        }

        
        var progressState: ProgressIndicatorState {
            switch self {
            case .active, .resultError:
                return .hidden
            case .deactivating:
                return .indeterminantProgress
            case .finished:
                return .completed
            }
        }
        
        var showProgressDetail: Bool {
            switch self {
            case .active:
                return false
            default:
                return true
            }
        }
        
        var isProcessing: Bool {
            switch self {
            case .deactivating:
                return true
            default:
                return false
            }
        }
        
        var isFinished: Bool {
            if case .finished = self {
                return true
            }
            return false
        }

    }
    
    @Published var state: DeactivatePodViewModelState = .active

    var error: DeactivationError? {
        if case .resultError(let error) = self.state {
            return error
        }
        return nil
    }

    var didFinish: (() -> Void)?
    
    var didCancel: (() -> Void)?
    
    var podDeactivator: PodDeactivater

    init(podDeactivator: PodDeactivater) {
        self.podDeactivator = podDeactivator
    }
    
    public func continueButtonTapped() {
        if case .finished = state {
            didFinish?()
        } else {
            self.state = .deactivating
            podDeactivator.deactivatePod { (result) in
                switch result {
                case .failure(let error):
                    self.state = .resultError(DeactivationError.podCommError(error))
                case .success:
                    self.state = .finished
                }
            }
        }
    }
    
    public func discardPodButtonTapped() {
        podDeactivator.discardPod { (result) in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.state = .resultError(DeactivationError.podCommError(error))
                case .success:
                    self.didFinish?()
                }
            }
        }
    }
}

enum DeactivationError : LocalizedError {
    case podCommError(PodCommError)
    
    var recoverySuggestion: String? {
        switch self {
        case .podCommError:
            return String(format: LocalizedString("If this problem persists, tap Discard Pod. You can then activate a new Pod", comment: "Format string for recovery suggestion during deactivate pod. (1: device model name)"), UIDevice.current.model)
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .podCommError(let error):
            return error.errorDescription
        }
    }
}
