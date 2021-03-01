//
//  PairPodViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/2/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI
import DashKit
import PodSDK

class PairPodViewModel: ObservableObject, Identifiable {
    
    enum NavBarButtonAction {
        case cancel
        case discard

        var text: String {
            switch self {
            case .cancel:
                return LocalizedString("Cancel", comment: "Pairing interface navigation bar button text for cancel action")
            case .discard:
                return LocalizedString("Discard Pod", comment: "Pairing interface navigation bar button text for discard pod action")
            }
        }

        func color(using guidanceColors: GuidanceColors) -> Color? {
            switch self {
            case .discard:
                return guidanceColors.critical
            case .cancel:
                return nil
            }
        }
    }
    
    enum PairPodViewModelState {
        case ready
        case pairing
        case priming(finishTime: CFTimeInterval)
        case error(DashPairingError, PodCommState)
        case finished
        
        var instructionsDisabled: Bool {
            switch self {
            case .ready:
                return false
            case .error(let error, _):
                return !error.recoverable
            default:
                return true
            }
        }
        
        var actionButtonAccessibilityLabel: String {
            switch self {
            case .ready:
                return LocalizedString("Pair pod.", comment: "Pairing action button accessibility label while ready to pair")
            case .pairing:
                return LocalizedString("Pairing.", comment: "Pairing action button accessibility label while pairing")
            case .priming:
                return LocalizedString("Priming. Please wait.", comment: "Pairing action button accessibility label while priming")
            case .error(let error, _):
                return String(format: "%@ %@", error.errorDescription ?? "", error.recoverySuggestion ?? "")
            case .finished:
                return LocalizedString("Pod paired successfully. Continue.", comment: "Pairing action button accessibility label when pairing succeeded")
            }
        }
                
        var nextActionButtonDescription: String {
            switch self {
            case .ready:
                return LocalizedString("Pair Pod", comment: "Pod pairing action button text while ready to pair")
            case .error(let error, _):
                if !error.recoverable {
                    return LocalizedString("Deactivate Pod", comment: "Pod pairing action button text while showing unrecoverable error")
                } else {
                    return LocalizedString("Retry", comment: "Pod pairing action button text while showing recoverable error")
                }
            case .pairing:
                return LocalizedString("Pairing...", comment: "Pod pairing action button text while pairing")
            case .priming:
                return LocalizedString("Priming...", comment: "Pod pairing action button text while priming")
            case .finished:
                return LocalizedString("Continue", comment: "Pod pairing action button text when paired")
            }
        }
        
        var actionButtonType: ActionButton.ButtonType {
            if case .error(let error, _) = self, !error.recoverable {
                return .destructive
            } else {
                return .primary
            }
        }
        
        var navBarButtonAction: NavBarButtonAction {
            switch self {
            case .error(let (_, podCommState)):
                if podCommState == .activating {
                    return .discard
                }
            default:
                break
            }
            return .cancel
        }
        
        var navBarVisible: Bool {
            if case .error(let (error, _)) = self {
                return error.recoverable
            }
            return true
        }
                
        var showProgressDetail: Bool {
            switch self {
            case .ready:
                return false
            default:
                return true
            }
        }
        
        var progressState: ProgressIndicatorState {
            switch self {
            case .ready, .error:
                return .hidden
            case .pairing:
                return .indeterminantProgress
            case .priming(let finishTime):
                return .timedProgress(finishTime: finishTime)
            case .finished:
                return .completed
            }
        }
        
        var isProcessing: Bool {
            switch self {
            case .pairing, .priming:
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
    
    var error: DashPairingError? {
        if case .error(let error, _) = self.state {
            return error
        }
        return nil
    }

    @Published var state: PairPodViewModelState = .ready
    
    var podIsActivated: Bool {
        return podPairer.podCommState != .noPod
    }
    
    var didFinish: (() -> Void)?
    
    var didRequestDeactivation: (() -> Void)?
    
    var didCancelSetup: (() -> Void)?

    weak var navigator: DashUINavigator?
    
    var podPairer: PodPairer

    init(podPairer: PodPairer, navigator: DashUINavigator) {
        self.podPairer = podPairer
        self.navigator = navigator
    }
    
    private func handleEvent(_ event: ActivationStep1Event) {
        switch event {
        case .connecting, .retrievingPodVersion, .settingPodUid, .programmingLowReservoirAlert, .programmingLumpOfCoal, .checkingPodStatus, .programmingPodExpireAlert, .podStatus:
            // Ignoring these details for now at the UI level
            break
        case .primingPod:
            let finishTime = TimeInterval(Pod.estimatedPrimingDuration)
            state = .priming(finishTime: CACurrentMediaTime() + finishTime)
        case .step1Completed:
            state = .finished
        }
    }
    
    private func pair() {
        state = .pairing
        
        podPairer.pair { (status) in
            switch status {
            case .error(let error):
                let pairingError = DashPairingError.podCommError(error)
                self.state = .error(pairingError, self.podPairer.podCommState)
            case .event(let event):
                self.handleEvent(event)
            }
        }
    }
    
    public func continueButtonTapped() {
        switch state {
        case .error(let error, _):
            if !error.recoverable {
                self.navigator?.navigateTo(.deactivate)
            } else {
                // Retry
                pair()
            }
        case .finished:
            didFinish?()
        default:
            pair()
        }
    }    
}

// Pairing recovery suggestions
enum DashPairingError : LocalizedError {
    case podCommError(PodCommError)
    
    var recoverySuggestion: String? {
        switch self {
        case .podCommError(let error):
            switch error {
                case .podNotAvailable:
                    return LocalizedString("Please make sure the pod is filled with insulin and is close to your device and try again.", comment: "recovery suggestion for podNotAvailable during pairing.")
            default:
                return error.recoverySuggestion
            }
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .podCommError(let error):
            return error.errorDescription
        }
    }
    
    var recoverable: Bool {
        switch self {
        case .podCommError(let error):
            return error.recoverable
        }
    }
}

extension PodCommError {
    var recoverable: Bool {
        switch self {
        case .podIsInAlarm:
            return false
        case .activationError(let activationErrorCode):
            switch activationErrorCode {
            case .podIsLumpOfCoal1Hour, .podIsLumpOfCoal2Hours:
                return false
            default:
                return true
            }
        case .internalError(.incompatibleProductId):
            return false
        default:
            return true
        }
    }
}
