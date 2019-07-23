//
//  PodSDKProtocol.swift
//  DashKit
//
//  Created by Pete Schwamb on 6/26/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import ObjectMapper

public protocol PodStatusProtocol {
    ///Current pod state
    var podState: PodSDK.PodState { get }

    ///Current program status
    var programStatus: PodSDK.ProgramStatus { get }

    ///Current active alerts
    var activeAlerts: PodSDK.PodAlerts  { get }

    ///Whether occlusion alert active
    var isOcclusionAlertActive: Bool { get }

    /**
     If bolus is running, the number of bolus units(1U = 100) remaining.
     */
    var bolusUnitsRemaining: Int { get }

    /**
     The total number of units(1U = 100) been delivered since pod activation.
     */
    var totalUnitsDelivered: Int { get }

    /**
     The number of units(1U = 100) remaining in reservoir.
     */
    var reservoirUnitsRemaining: Int { get }

    ///Time when Pod is activated
    var activationTime: Date { get }

    func hasAlerts() -> Bool
}

public protocol PodCommManagerProtocol {

    /**
     The delegate used to asynchrounously notify the application of various pod communication events.
     */
    var delegate: PodCommManagerDelegate? { get set }

    /**
     Set customized logger. Note, functions of LoggingProtocol are synchronized calls.
     */
    func setLogger(logger: LoggingProtocol)

    func enableAutoConnection(launchOptions: [AnyHashable : Any]?)

    /**
     Starts a Pod activation. Activation is a 2-phase process. Use this call to initiate the 1st phase.

     This phase includes:

     1. Getting the Pod version
     2. Setting a unique Pod ID
     3. Priming the Pod (to release any air from the cannula)
     4. Programming a default (initial) basal

     - parameters:
     - lowReservoirAlert: `LowReservoirAlert`. If not provided, default of 10 U is programmed.
     - podExpirationAlert: `PodExpirationAlert`. If not provided, default of 4 hours before Pod expiration is programmed.
     - eventListener: a closure to be called when `ActivationStep1Event`s are issued by the comm. layer
     - event: one of the following `ActivationStep1Event`s issued during the 1st phase of activation, listed below (in order) except ActivationStep1Event.podStatus(PodStatus)
     - `ActivationStep1Event.connecting`
     - `ActivationStep1Event.retrievingPodVersion`
     - `ActivationStep1Event.settingPodUid`
     - `ActivationStep1Event.programmingLowReservoirAlert`
     - `ActivationStep1Event.programmingLumpOfCoal`
     - `ActivationStep1Event.primingPod`
     - `ActivationStep1Event.checkingPodStatus`
     - `ActivationStep1Event.programmingPodExpireAlert`
     - `ActivationStep1Event.podStatus(PodStatus)`
     - `ActivationStep1Event.step1Completed`
     - error: In case of an error - `PodCommError`

     - Note: No more events after either PodCommError or ActivationStep1Event.step1Completed.
     */
    func startPodActivation(lowReservoirAlert: PodSDK.LowReservoirAlert?, podExpirationAlert: PodSDK.PodExpirationAlert?, eventListener: @escaping (PodSDK.ActivationStatus<PodSDK.ActivationStep1Event>) -> ())

    /**
     Finishes a Pod activation previously started with `startPodActivation(...)`.

     Activation is a 2-phase process. Use this call to initiate the 2nd phase. This phase
     performs cannula insertion and completes a Pod activation.

     - parameters:
     - basalProgram: a basal program to program during the activation
     - autoOffAlert: optional "Auto-Off" setting to program on the Pod. Default is 'disabled'.
     - eventListener: a closure to be called when `ActivationStatus<ActivationStep2Event>`s are issued by the comm. layer
     - event: one of the following `ActivationStep2Event`s issued during the 2nd phase of activation, listed below in order except ActivationStep2Event.podStatus(PodStatus)
     - `ActivationStep2Event.connecting`
     - `ActivationStep2Event.programmingActiveBasal`
     - `ActivationStep2Event.cancelLumpOfCoal`
     - `ActivationStep2Event.insertingCannula`
     - `ActivationStep2Event.checkingPodStatus`
     - `ActivationStep2Event.podStatus(PodStatus)`
     - `ActivationStep2Event.step2Completed`
     - error: In case of an error - 'optional' `PodCommError`

     - Note: No more events after either PodCommError or ActivationStep2Event.step2Completed.

     */
    func finishPodActivation(basalProgram: PodSDK.BasalProgram, autoOffAlert: PodSDK.AutoOffAlert?, eventListener: @escaping (PodSDK.ActivationStatus<PodSDK.ActivationStep2Event>) -> ())

    /**
     Cancels an ongoing activation and clears all states maintained by the `PodCommManager`.

     This call will not send any command to the POD. Use this call if the deactivation flow started by the `deactivatePod(...)` call fails.

     - parameters:
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: if successful, result is `PodCommResult.success(...)` or in case of an error, result is `PodCommResult.failure(...)`
     */
    func discardPod(completion: @escaping (PodSDK.PodCommResult<Bool>) -> ())

    /**
     Deactivates an 'active' Pod and stores its runtime data for uploading and debugging. This call will try to communicate with Pod and clears all states maintained by the `PodCommManager`. To avoid Pod in alarm, try to call this function instead of `discardPod`

     - parameters:
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: If successful, result is `PodCommResult.success(...)` or in case of an error, result is `PodCommResult.failure(...)`
     */
    func deactivatePod(completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Sends a command to the Pod to retrieve its status.

     - parameters:
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: If successful, result is `PodCommResult.success(...)` or in case of an error, result is `PodCommResult.failure(...)`
     */
    func getPodStatus(completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Sends a command to the Pod to retrieve time of alerts.

     - parameters:
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: If successful, result is `PodCommResult.success(...)` or in case of an error, result is `PodCommResult.failure(...)`
     */
    func getAlertsDetails(completion: @escaping (PodSDK.PodCommResult<PodSDK.PodAlerts>) -> ())

    /**
     Plays test beeps on the Pod.
     - Note: Insulin delivery should be suspended `suspendInsulin(...)` on the Pod in order to run this test successfully.

     - parameters:
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: If successful, result is `PodCommResult.success(...)` or in case of an error, result is  `PodCommResult.failure(...)`

     */
    func playTestBeeps(completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Activates a basal, a temp basal, or a bolus program on the Pod.

     - parameters:
     - programType: one of the defined `ProgramType`s (basal, temp basal or bolus)
     - beepOption: TODO
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: If successful, result is `PodCommResult.success(...)` or in case of an error, result is  `PodCommResult.failure(...)`

     - Note: Pod will go into the state of alarm in the cases listed below. SDK will not check Pod status during this call.
     - Sending a bolus/temp basal/basal program while Pod is running a bolus
     - Sending temp basal/basal program while Pod is running temp basal

     */
    func sendProgram(programType: PodSDK.ProgramType, beepOption: PodSDK.BeepOption?, completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Stops an active bolus or a temp basal program, or suspends insulin delivery by the Pod. Any 'active' insulin delivery program is completely stopped.

     - parameters:
     - programType: use either `StopProgramType.tempBasal` or `StopProgramType.bolus` to stop current running program. use `StopProgramType.stopAll(...)` to stop all programs.
     - completion: a closure to be called when PodCommResult is issued by the comm. layer
     - result: if successful, result is `PodCommResult.success(...)` or in case of an error, result is `PodCommResult.failure(...)`

     - Note: SDK will not resume insulin after the duration of suspended insulin is completed.
     - If bolus is sent after insulin is suspended, bolus can be delivered without a basal program
     - If temp basal is sent after insulin is suspended, temp basal will be running without a basal program.
     */
    func stopProgram(programType: PodSDK.StopProgramType, completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Programs or updates Pod alerts.

     - parameters:
     - alertSetting: a `PodAlertSetting` to program
     - completion: a closure to be called when `PodCommResult` is issued by the comm. layer
     - result: a `PodCommResult.success(...)` if success or `PodCommResult.failure(...)` in case of an error
     */
    func updateAlertSetting(alertSetting: PodAlertSetting, completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Silence Pod alerts.

     - parameters:
     - alert: 'PodAlerts', one or more alerts that need to be silenced
     - completion: a closure to be called when `PodCommResult`s are issued by the comm. layer
     - result: a `PodCommResult.success(...)` if success or `PodCommResult.failure(...)` in case of an error
     */
    func silenceAlerts(alert: PodSDK.PodAlerts, completion: @escaping (PodSDK.PodCommResult<PodStatusProtocol>) -> ())

    /**
     Clears an unacknowledged command. The previous command that has been sent without acknowledgement will be discarded.

     - Note: The app should notify the user that the status of the previously sent command is unknown.
     */
    func clearUnacknowledgedCommand()

    /**
     - returns: an ID of the currently paired Pod
     */
    func getPodId() -> String?

    /**
     - returns: an estimated remaining delivery time of the currently running bolus
     */
    func getEstimatedBolusDeliveryTime() -> TimeInterval?

    /**
     - returns: an estimated remaining volume of the currently running bolus
     */
    func getEstimatedBolusRemaining() -> Int

    /**
     - returns: a `PodCommState`
     */
    var podCommState: PodSDK.PodCommState { get }

}
