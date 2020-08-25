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
        let sendProgramErrorBinding = Binding<Int>(get: {
            let idx = PodCommError.simulatedErrors.firstIndex {
                $0?.localizedDescription ?? "" == self.mockPodCommManager.deliveryProgramError?.localizedDescription ?? ""
            }
            return idx ?? 0
        }, set: {
            self.mockPodCommManager.deliveryProgramError = PodCommError.simulatedErrors[$0]
        })

        return Form {
            Section {
                Picker(selection: sendProgramErrorBinding, label: Text("Delivery Program Error")) {
                    ForEach(0 ..< PodCommError.simulatedErrors.count) {
                        Text(self.podCommErrorFormatted(PodCommError.simulatedErrors[$0]))
                    }
                }
            }
        }
        .navigationBarTitle("Mock Pod Settings")
    }
}

struct MockPodSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPodSettingsView(mockPodCommManager: MockPodCommManager())
    }
}
