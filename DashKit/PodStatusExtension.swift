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
        return Double(bolusUnitsRemaining) / 100.0
    }

    var delivered: Double {
        return Double(totalUnitsDelivered) / 100.0
    }

    var reservoir: Double {
        return Double(reservoirUnitsRemaining) / 100.0
    }
}

public extension InternalErrorCode {
    var description: String {
        switch self {
        case .inconsistentCommand:
            return "Not a valid Pod command"

        case .invalidCommand:
            return "Invalid command"

        case .invalidResponse:
            return "Invalid response"

        case .incompatibleProductId:
            return "Incompatible product Id"

        case .unexpectedResponse:
            return "Unexpected response"

        case .unexpectedMessageSequence:
            return "Unexpected message sequence"
        }
    }
}

public extension ActivationErrorCode {
    var description: String {
        switch self {
        case .moreThanOnePodAvailable:
            return "More than one Pod found during Pod activation"

        case .podIsLumpOfCoal1Hour:
            return "Pod is not activated during 1 hour after UID is set"

        case .podIsLumpOfCoal2Hours:
            return "Pod is not activated during 2 hour after insulin is filled"

        case .podActivationFailed:
            return "Other errors during Pod activation"

        case .podIsAlreadyActive:
            return "Try to activate a Pod when a Pod is already activated"

        case .activationPhase1NotCompleted:
            return "Try to call activation phase 2 before completing phase 1"
        }
    }
}

public extension PodCommError {
    var description: String {
        switch self {
        case .unknownError:
            return "Error not mapped"

        case .phoneNotRegistered:
            return "Phone is not registered"

        case .podServiceIsBusy:
            return "Pod service is busy"

        case .podIsNotActive:
            return "Pod is not active"

        case .failToConnect:
            return "Failed to connect"

        case .operationTimeout:
            return "Operation timed out"

        case .notConnected:
            return "Pod is not connected"

        case .messageSigningFailed:
            return "Message signinng failed"

        case .podNotAvailable:
            return "Pod is not available"

        case .bluetoothOff:
            return "Bluetooth is off"

        case .internalError:
            return "Internal error"

        case .activationError:
            return "Activation error"

        case .nackReceived:
            return "NACK received"

        case .podIsInAlarm:
            return "Pod is in alarm"

        case .systemAlarm:
            return "System alarm"

        case .invalidProgram:
            return "Invalid program"

        case .invalidAlertSetting:
            return "Invalid alert settings"

        case .invalidProgramStatus:
            return "Invalid Program status"
        }
    }
}

extension ActivationStep1Event : Equatable {

    var description : String {
        switch self {
        case .connecting:
            return " Pod is connecting"

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
        case ( .connecting, .connecting):
            return true

        case ( .retrievingPodVersion, .retrievingPodVersion):
            return true

        case ( .settingPodUid, .settingPodUid):
            return true

        case ( .programmingLowReservoirAlert, .programmingLowReservoirAlert):
            return true

        case ( .programmingLumpOfCoal, .programmingLumpOfCoal):
            return true

        case ( .primingPod, .primingPod):
            return true

        case ( .checkingPodStatus, .checkingPodStatus):
            return true

        case ( .programmingPodExpireAlert, .programmingPodExpireAlert):
            return true

        case ( .podStatus, .podStatus):
            return true

        case ( .step1Completed, .step1Completed):
            return true

        default:
            return false
        }
    }
}

extension ActivationStep2Event : Equatable{

    var description : String {
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
