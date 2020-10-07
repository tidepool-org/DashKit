//
//  MockPodSettings.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 8/22/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import DashKit
import PodSDK

extension PodCommError {
    fileprivate static var simulatedErrors: [PodCommError?] {
        return [
            nil,
            .unacknowledgedCommandPendingRetry,
            .notConnected,
            .failToConnect,
            .activationError(.activationPhase1NotCompleted),
            .bleCommunicationError,
            .bluetoothOff,
            .bluetoothUnauthorized,
            .internalError(.incompatibleProductId),
            .invalidAlertSetting,
            .invalidProgram,
            .invalidProgramStatus(nil),
            .messageSigningFailed,
            .nackReceived(.errorPodState),
            .noUnacknowledgedCommandToRetry
        ]
    }
}

struct MockPodSettingsView: View {
    let mockPodCommManager: MockPodCommManager
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func podCommErrorFormatted(_ error: PodCommError?) -> String {
        if let error = error {
            return error.localizedDescription
        } else {
            return "No error"
        }
    }
    

    var body: some View {

        return Form {
            Section {
                sendProgramErrorPicker
                unacknowledgedCommandRetryResultPicker
            }
            
            Section(header: Text("Reservoir Remaining").font(.headline).foregroundColor(Color.primary)) {
                reservoirRemainingEntry
            }
        }
        .navigationBarTitle("Mock Pod Settings")
    }
    
    var unacknowledgedCommandRetryResultPicker: some View {
        let unacknowledgedCommandRetryResultBinding = Binding<Bool>(get: {
            if let result = self.mockPodCommManager.unacknowledgedCommandRetryResult {
                return result.hasPendingCommandProgrammed
            } else {
                return false
            }
        }, set: {
            self.mockPodCommManager.unacknowledgedCommandRetryResult = $0 ? PendingRetryResult.wasProgrammed : PendingRetryResult.wasNotProgrammed
        })
        
        return Toggle(isOn: unacknowledgedCommandRetryResultBinding) {
            Text("Unacknowledged Command Was Received By Pod")
        }
    }
    
    var sendProgramErrorPicker: some View {
        let sendProgramErrorBinding = Binding<Int>(get: {
            let idx = PodCommError.simulatedErrors.firstIndex {
                $0?.localizedDescription ?? "" == self.mockPodCommManager.deliveryProgramError?.localizedDescription ?? ""
            }
            return idx ?? 0
        }, set: {
            self.mockPodCommManager.deliveryProgramError = PodCommError.simulatedErrors[$0]
        })
        return Picker(selection: sendProgramErrorBinding, label: Text("Delivery Program Error")) {
            ForEach(0 ..< PodCommError.simulatedErrors.count) {
                Text(self.podCommErrorFormatted(PodCommError.simulatedErrors[$0]))
            }
        }
    }
    
    var reservoirRemainingEntry: some View {
        let reservoirRemaining = Binding(
            get: { self.mockPodCommManager.podStatus.reservoirUnitsRemaining / Int(Pod.podSDKInsulinMultiplier) },
            set: { self.mockPodCommManager.podStatus.reservoirUnitsRemaining = $0 * Int(Pod.podSDKInsulinMultiplier) }
        )
        
        return MockPodReservoirRemainingEntryView(reservoirRemaining: reservoirRemaining)
    }

}

struct MockPodReservoirRemainingEntryView: View {
    @Binding var reservoirRemaining: Int
    
    var body: some View {
        TextField("Enter reservoir remaining value",
                  value: $reservoirRemaining,
                  formatter: NumberFormatter())
            .keyboardType(.numberPad)
    }
}

struct MockPodSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPodSettingsView(mockPodCommManager: MockPodCommManager())
    }
}
