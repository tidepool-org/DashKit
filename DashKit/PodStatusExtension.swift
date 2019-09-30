//
//  PodStatusExtension.swift
//  SampleApp
//
// Copyright (C) 2019, Insulet Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
            return LocalizedString("Invalid command", comment: "Description for InternalErrorCode.invalidCommand")

        case .invalidResponse:
            return LocalizedString("Invalid response", comment: "Description for InternalErrorCode.invalidResponse")

        case .incompatibleProductId:
            return LocalizedString("Incompatible product ID", comment: "Description for InternalErrorCode.incompatibleProductId")

        case .unexpectedMessageSequence:
            return LocalizedString("Unexpected message sequence", comment: "Description for InternalErrorCode.unexpectedMessageSequence")

        case .invalidPodId:
            return LocalizedString("Invalid POD ID", comment: "Description for InternalErrorCode.invalidPodId")
        }
    }
}

public extension ActivationErrorCode {
    var localizedDescription: String {
        switch self {
        case .moreThanOnePodAvailable:
            return LocalizedString("More than one Pod found during Pod activation", comment: "Description for ActivationErrorCode.moreThanOnePodAvailable")

        case .podIsLumpOfCoal1Hour:
            return LocalizedString("Pod is not activated during 1 hour after UID is set", comment: "Description for ActivationErrorCode.podIsLumpOfCoal1Hour")

        case .podIsLumpOfCoal2Hours:
            return LocalizedString("Pod is not activated during the 2 hours after insulin is filled", comment: "Description for ActivationErrorCode.podIsLumpOfCoal2Hours")

        case .podActivationFailed:
            return LocalizedString("Pod Activation Failed", comment: "Description for ActivationErrorCode.podActivationFailed")

        case .activationPhase1NotCompleted:
            return LocalizedString("Try to call activation phase 2 before completing phase 1", comment: "Description for ActivationErrorCode.activationPhase1NotCompleted")
            
        case .podIsActivatedOrDeactivating:
            return LocalizedString("Pod is activated or deactivating", comment: "Description for ActivationErrorCode.podIsActivatedOrDeactivating")
        }
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
            return LocalizedString("Unknown Error", comment: "Error description for PodCommError.unknownError")

        case .phoneNotRegistered:
            return LocalizedString("Phone is not registered", comment: "Error description for PodCommError.phoneNotRegistered")

        case .podServiceIsBusy:
            return LocalizedString("Pod service is busy", comment: "Error description for PodCommError.podServiceIsBusy")

        case .podIsNotActive:
            return LocalizedString("Pod is not active", comment: "Error description for PodCommError.podIsNotActive")

        case .failToConnect:
            return LocalizedString("Failed to connect", comment: "Error description for PodCommError.failToConnect")

        case .operationTimeout:
            return LocalizedString("Operation timed out", comment: "Error description for PodCommError.operationTimeout")

        case .notConnected:
            return LocalizedString("Pod is not connected", comment: "Error description for PodCommError.notConnected")

        case .messageSigningFailed:
            return LocalizedString("Message signing failed", comment: "Error description for PodCommError.messageSigningFailed")

        case .podNotAvailable:
            return LocalizedString("Pod not available", comment: "Error description for PodCommError.podNotAvailable")

        case .bluetoothOff:
            return LocalizedString("Bluetooth is off", comment: "Error description for PodCommError.bluetoothOff")

        case .internalError(let internalErrorCode):
            return String(format: LocalizedString("Internal error: %1$@", comment: "Format string for error description for PodCommError.internalError (1: internal error code description)"), internalErrorCode.localizedDescription)

        case .activationError(let activationErrorCode):
            return String(format: LocalizedString("Activation error: %1$@", comment: "Format string for error description for PodCommError.activationError (1: activation error code description)"), activationErrorCode.localizedDescription)
            
        case .nackReceived(let nackCode):
            return String(format: LocalizedString("Nack received: %1$@", comment: "Format string for error description for PodCommError.nackReceived (1: nack error code description)"), nackCode.localizedDescription)

        case .podIsInAlarm:
            return LocalizedString("Pod is in alarm", comment: "Error description for PodCommError.podIsInAlarm")

        case .systemAlarm:
            return LocalizedString("System alarm", comment: "Error description for PodCommError.systemAlarm")

        case .invalidProgram:
            return LocalizedString("Invalid program", comment: "Error description for PodCommError.invalidProgram")

        case .invalidAlertSetting:
            return LocalizedString("Invalid alert settings", comment: "Error description for PodCommError.invalidAlertSetting")

        case .invalidProgramStatus:
            return LocalizedString("Invalid Program status", comment: "Error description for PodCommError.invalidProgramStatus")

        case .unacknowledgedCommandPendingRetry:
            return LocalizedString("Unacknowledged Command Pending Retry", comment: "Error description for PodCommError.unacknowledgedCommandPendingRetry")

        case .noUnacknowledgedCommandToRetry:
            return LocalizedString("No Unacknowledged Command To Retry", comment: "Error description for PodCommError.noUnacknowledgedCommandToRetry")

        case .podSDKExpired:
            return LocalizedString("Pod SDK Expired", comment: "Error description for PodCommError.podSDKExpired")
            
        case .bleCommunicationError:
            return LocalizedString("Bluetooth Communication Error", comment: "Error description for PodCommError.bleCommunicationError")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .podNotAvailable:
            return LocalizedString("Move to a new area, place your phone and Pod close to each other and tap Retry.", comment: "Recovery suggestion when pod not available.")
        case .activationError(let error):
            switch error {
            case .moreThanOnePodAvailable:
                return LocalizedString("Please move to a new location and try again.", comment: "Recovery suggestion when multiple pods detected.")
            case .podIsLumpOfCoal1Hour, .podIsLumpOfCoal2Hours:
                return LocalizedString("Pod activation took too long. The pod was not activated within two hours after filling the reservoir and cannot be used.", comment: "Recovery suggestion when pod is lump of coal")
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

extension ActivationStep1Event : Equatable {

    public var description : String {
        switch self {
        case .connecting:
            return "Pod is connecting"

        case .retrievingPodVersion:
            return "Retrieving Pod version"

        case .settingPodUid:
            return "Setting Pod Uid"

        case .programmingLowReservoirAlert:
            return "Programming low reservoir alert"

        case .programmingLumpOfCoal:
            return "Programming lump of coal"

        case .primingPod:
            return "Priming Pod"

        case .checkingPodStatus:
            return "Checking Pod status"

        case .programmingPodExpireAlert:
            return "Programming Pod expiration alert"

        case .podStatus:
            return "Pod status"

        case .step1Completed:
            return "Activation Step 1 completed"
        }
    }

    public static func ==(lhs: ActivationStep1Event, rhs: ActivationStep1Event) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting):
            return true

        case (.retrievingPodVersion, .retrievingPodVersion):
            return true

        case (.settingPodUid, .settingPodUid):
            return true

        case (.programmingLowReservoirAlert, .programmingLowReservoirAlert):
            return true

        case (.programmingLumpOfCoal, .programmingLumpOfCoal):
            return true

        case (.primingPod, .primingPod):
            return true

        case (.checkingPodStatus, .checkingPodStatus):
            return true

        case (.programmingPodExpireAlert, .programmingPodExpireAlert):
            return true

        case (.podStatus, .podStatus):
            return true

        case (.step1Completed, .step1Completed):
            return true

        default:
            return false
        }
    }
}

extension ActivationStep2Event : Equatable {

    public var description : String {
        switch self {
        case .connecting:
            return "Pod is connecting"

        case .programmingActiveBasal:
            return "Programming active basal"

        case .insertingCannula:
            return "Inserting Cannula."

        case .checkingPodStatus:
            return "Checking Pod status"

        case .podStatus:
            return "Pod status"

        case .step2Completed:
            return "Activation phase 2 completed"

        case .cancelLumpOfCoalProgrammingAutoOff:
            return "Cancelling lump of coal"
        }
    }
    public static func ==(lhs: ActivationStep2Event, rhs: ActivationStep2Event) -> Bool {
        switch (lhs, rhs) {
        case ( .connecting, .connecting):
            return true

        case ( .programmingActiveBasal, .programmingActiveBasal):
            return true

        case ( .insertingCannula, .insertingCannula):
            return true

        case ( .checkingPodStatus, .checkingPodStatus):
            return true

        case ( .podStatus, .podStatus):
            return true

        case ( .step2Completed, .step2Completed):
            return true

        default:
            return false
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
            return "Basal Program is Running"

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
            return "Pod is Active"

        case .noPod:
            return "No Pod is Present"

        case .activating:
            return "Pod is activating"

        case .alarm:
            return "Pod is in Alarm state"

        case .deactivating:
            return "Pod is deactivating"

        }
    }
}
