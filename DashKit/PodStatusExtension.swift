//
//  PodStatusExtension.swift
//  DashKit
//

import Foundation
import PodSDK

public extension PodStatus {
    var bolusRemaining: Double {
        return Double(bolusUnitsRemaining) / Pod.podSDKInsulinMultiplier
    }

    var delivered: Double {
        return Double(totalUnitsDelivered) / Pod.podSDKInsulinMultiplier
    }

    var reservoir: Double {
        return Double(reservoirUnitsRemaining) / Pod.podSDKInsulinMultiplier
    }
}

public extension InternalErrorCode {
    var localizedDescription: String {
        switch self {
        case .invalidCommand:
            return LocalizedString("Invalid command.", comment: "Description for InternalErrorCode.invalidCommand")

        case .invalidResponse:
            return LocalizedString("Invalid response.", comment: "Description for InternalErrorCode.invalidResponse")

        case .incompatibleProductId:
            return LocalizedString("Pod not compatible.", comment: "Description for InternalErrorCode.incompatibleProductId")

        case .unexpectedMessageSequence:
            return LocalizedString("Unexpected message sequence.", comment: "Description for InternalErrorCode.unexpectedMessageSequence")

        case .invalidPodId:
            return LocalizedString("Invalid Pod Identifier.", comment: "Description for InternalErrorCode.invalidPodId")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .incompatibleProductId:
            return LocalizedString("This Pod is not compatible with Tidepool Loop, and activation is not possible. Please discard the Pod.", comment: "Recovery suggestion for InternalErrorCode.incompatibleProductId")
        default:
            return LocalizedString("Please retry. If this problem persists, tap Discard Pod. You can then activate a new pod.", comment: "Recovery suggestion for InternalErrorCode.invalidCommand")
        }
    }
}

public extension ActivationErrorCode {
    var localizedDescription: String {
        switch self {
        case .moreThanOnePodAvailable:
            return LocalizedString("More than one Pod discovered.", comment: "Description for ActivationErrorCode.moreThanOnePodAvailable")

        case .podIsLumpOfCoal1Hour:
            return LocalizedString("Pod was not activated within 1 hour of initial pairing.", comment: "Description for ActivationErrorCode.podIsLumpOfCoal1Hour")

        case .podIsLumpOfCoal2Hours:
            return LocalizedString("Pod was not activated within 2 hours of filling reservoir.", comment: "Description for ActivationErrorCode.podIsLumpOfCoal2Hours")

        case .podActivationFailed:
            return LocalizedString("Pod activation failed.", comment: "Description for ActivationErrorCode.podActivationFailed")

        case .activationPhase1NotCompleted:
            return LocalizedString("Pod not paired.", comment: "Description for ActivationErrorCode.activationPhase1NotCompleted")
            
        case .podIsActivatedOrDeactivating:
            return LocalizedString("Pod is activated or deactivating.", comment: "Description for ActivationErrorCode.podIsActivatedOrDeactivating")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .moreThanOnePodAvailable:
            return LocalizedString("Please move your Pod to a new location and try again.", comment: "Recovery suggestion when multiple pods detected.")
        case .podIsLumpOfCoal1Hour:
            return LocalizedString("The Pod was not activated within one hour after filling the reservoir and cannot be used.", comment: "Recovery suggestion when pod is lump of coal 1 hour")
        case .podIsLumpOfCoal2Hours:
            return LocalizedString("Pod activation was not finished within two hours after filling the reservoir and cannot be used.", comment: "Recovery suggestion when pod is lump of coal 2 hours")
        default:
            return nil
        }
    }
}

public extension SystemErrorCode {
    var localizedDescription: String {
        switch self {
        case .crosscheckFailed:
            return LocalizedString("Crosscheck failed", comment: "Description for SystemErrorCode.crosscheckFailed")
        case .podTimeDeviation:
            return LocalizedString("Pod time and system time difference is too large", comment: "Description for SystemErrorCode.podTimeDeviation")
        case .unexpectedResponse:
            return LocalizedString("Unexpected response", comment: "Description for SystemErrorCode.unexpectedResponse")
        case .dataCorruption:
            return LocalizedString("Data on pod corrupted", comment: "Description for SystemErrorCode.dataCorruption")
        }
    }
}

public extension SystemError {
    var localizedDescription: String {
        if self.referenceCode.count > 0 {
            return String(format: LocalizedString("%1$@: %2$@", comment: "Format string for error description for PodCommError.systemError (1: system error code description) (2: support reference code)"), self.errorCode.localizedDescription, self.referenceCode)
        } else {
            return self.errorCode.localizedDescription
        }
    }
    
    var recoverySuggestion: String {
        return LocalizedString("Pod must be deactivated.", comment: "Recovery suggestion for SystemErrorCode errors")
    }
}

public extension NackErrorCode {
    var localizedDescription: String {
        switch self {
        case .errorPodState:
            return LocalizedString("Pod State", comment: "Description for NackErrorCode.errorPodState")
            
        case .errorPumpState:
            return LocalizedString("Pump State", comment: "Description for NackErrorCode.errorPumpState")

        case .podInAlarm:
            return LocalizedString("Pod In Alarm", comment: "Description for NackErrorCode.podInAlarm")

        case .invalidCrc:
            return LocalizedString("Invalid CRC", comment: "Description for NackErrorCode.invalidCrc")

        case .generalError:
            return LocalizedString("General Error", comment: "Description for NackErrorCode.generalError")
        }
    }
}


extension PodCommError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownError:
            return LocalizedString("Unknown Error.", comment: "Error description for PodCommError.unknownError")

        case .phoneNotRegistered:
            return LocalizedString("Phone is not registered.", comment: "Error description for PodCommError.phoneNotRegistered")

        case .podServiceIsBusy:
            return LocalizedString("Pod service is busy.", comment: "Error description for PodCommError.podServiceIsBusy")

        case .podIsNotActive:
            return LocalizedString("Pod is not active.", comment: "Error description for PodCommError.podIsNotActive")

        case .failToConnect:
            return LocalizedString("Failed to connect.", comment: "Error description for PodCommError.failToConnect")

        case .operationTimeout:
            return LocalizedString("Operation timed out.", comment: "Error description for PodCommError.operationTimeout")

        case .notConnected:
            return LocalizedString("There was a problem communicating with the Pod.", comment: "Error description for PodCommError.notConnected")

        case .messageSigningFailed:
            return LocalizedString("Message signing failed.", comment: "Error description for PodCommError.messageSigningFailed")

        case .podNotAvailable:
            return LocalizedString("Cannot locate Pod.", comment: "Error description for PodCommError.podNotAvailable")

        case .bluetoothOff:
            return LocalizedString("Bluetooth is off.", comment: "Error description for PodCommError.bluetoothOff")

        case .internalError(let internalErrorCode):
            return internalErrorCode.localizedDescription

        case .activationError(let activationErrorCode):
            return activationErrorCode.localizedDescription
            
        case .nackReceived(let nackCode):
            return String(format: LocalizedString("Nack received: %1$@.", comment: "Format string for error description for PodCommError.nackReceived (1: nack error code description)"), nackCode.localizedDescription)

        case .podIsInAlarm:
            return LocalizedString("Pod is in alarm.", comment: "Error description for PodCommError.podIsInAlarm")

        case .invalidProgram:
            return LocalizedString("Invalid program.", comment: "Error description for PodCommError.invalidProgram")

        case .invalidAlertSetting:
            return LocalizedString("Invalid alert settings.", comment: "Error description for PodCommError.invalidAlertSetting")

        case .invalidProgramStatus:
            return LocalizedString("Invalid program status.", comment: "Error description for PodCommError.invalidProgramStatus")

        case .unacknowledgedCommandPendingRetry:
            return LocalizedString("Unacknowledged command pending retry.", comment: "Error description for PodCommError.unacknowledgedCommandPendingRetry")

        case .noUnacknowledgedCommandToRetry:
            return LocalizedString("No unacknowledged command to retry.", comment: "Error description for PodCommError.noUnacknowledgedCommandToRetry")

        case .bleCommunicationError:
            return LocalizedString("There was a problem communicating with the Pod.", comment: "Error description for PodCommError.bleCommunicationError")
            
        case .bluetoothUnauthorized:
            return LocalizedString("Bluetooth not authorized.", comment: "Error description for PodCommError.bluetoothUnauthorized")
            
        case .systemError(let systemError):
            return systemError.localizedDescription

        case .sdkNotInitialized:
            return LocalizedString("SDK Not Initialized.", comment: "Error description for PodCommError.sdkNotInitialized")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .activationError(let activationError):
            return activationError.recoverySuggestion
        case .bluetoothUnauthorized:
            return LocalizedString("Please authorize Loop for bluetooth in settings app.", comment: "Recovery suggestion for PodCommError.bluetoothUnauthorized")
        case .bluetoothOff:
            return LocalizedString("Please re-enable bluetooth and try again.", comment: "Recovery suggestion bluetooth not authorized.")
        case .internalError(let internalErrorCode):
            return internalErrorCode.recoverySuggestion
        case .systemError(let systemError):
            return systemError.recoverySuggestion
        case .bleCommunicationError, .podNotAvailable, .notConnected, .failToConnect:
            return String(format: LocalizedString("Move to a new area, place your %1$@ and Pod close to each other, and tap “Try Pairing Again”", comment: "Format string for recovery suggestion when pod may be out of range of phone. (1: device model name)"), UIDevice.current.model)
        case .phoneNotRegistered, .sdkNotInitialized, .messageSigningFailed:
            return LocalizedString("Please re-attempt app configuration.", comment: "Recovery suggestion for errors that should not happen after configuration.")
        case .podServiceIsBusy, .operationTimeout, .unknownError:
            return LocalizedString("Please try again.", comment: "Recovery suggestion for temporary issues.")
        case .podIsNotActive, .podIsInAlarm:
            return LocalizedString("Please deactivate pod and pair new pod.", comment: "Recovery suggestion for podIsNotActive.")
        case .unacknowledgedCommandPendingRetry, .noUnacknowledgedCommandToRetry, .nackReceived:
            return LocalizedString("Please retry.", comment: "Recovery suggestion for unacknowledgedCommandPendingRetry and noUnacknowledgedCommandToRetry.")
        case .invalidProgram, .invalidAlertSetting, .invalidProgramStatus:
            return LocalizedString("Please check settings and try again.", comment: "Recovery suggestion for invalidProgram, invalidAlertSetting, and invalidProgramStatus.")
        }
    }
}

extension ActivationStep1Event {
    public var description : String {
        switch self {
        case .connecting:
            return "Pod is connecting"

        case .retrievingPodVersion:
            return "Retrieving pod version"

        case .settingPodUid:
            return "Setting pod UID"

        case .programmingLowReservoirAlert:
            return "Programming low reservoir alert"

        case .programmingLumpOfCoal:
            return "Programming lump of coal"

        case .primingPod:
            return "Priming pod"

        case .checkingPodStatus:
            return "Checking pod status"

        case .programmingPodExpireAlert:
            return "Programming pod expiration alert"

        case .podStatus:
            return "Pod status"

        case .step1Completed:
            return "Activation step 1 completed"
        }
    }
}

extension ActivationStep2Event {
    public var description : String {
        switch self {
        case .connecting:
            return "Pod is connecting"

        case .programmingActiveBasal:
            return "Programming active basal"

        case .insertingCannula:
            return "Inserting cannula."

        case .checkingPodStatus:
            return "Checking pod status"

        case .podStatus:
            return "Pod status"

        case .step2Completed:
            return "Activation phase 2 completed"

        case .cancelLumpOfCoalProgrammingAutoOff:
            return "Cancelling lump of coal"
        }
    }
}

extension PodState : CustomStringConvertible {
    public var description : String {
        switch self {
        case .uninitialized:
            return "Pod is uninitialized"

        case .mfgTest:
            return "MFG Test"

        case .filled:
            return "Pod is filled"

        case .uidSet:
            return "UID is set"

        case .engagingClutchDrive:
            return "Engaging Clutch Drive. \nPlease wait for 35 seconds. Activation is in Progress......"

        case .clutchDriveEnaged:
            return "Clutch drive is engaged"

        case .basalProgramRunning:
            return "Basal program is Running"

        case .priming:
            return "Pod is priming. \nPlease wait for 10 seconds. Activation is in process......"

        case .runningAboveMinVolume:
            return "Running above minimum volume"

        case .runningBelowMinVolume:
            return "Running below minimum volume"

        case .alarm:
            return "Pod is in alarm"

        case .lumpOfCoal:
            return "Pod is lump of coal"

        case .deactivated:
            return "Pod is deactivated"

        case .unknown:
            return "Pod status is unknown"
        }
    }
}

public extension PodCommState {
    var description: String {
        switch self {
        case .active:
            return "Pod is active"

        case .noPod:
            return "No pod is Present"

        case .activating:
            return "Pod is activating"

        case .alarm:
            return "Pod is in Alarm state"

        case .deactivating:
            return "Pod is deactivating"

        case .systemError(let error):
            return "System Error: \(error)"
        }
    }
}
