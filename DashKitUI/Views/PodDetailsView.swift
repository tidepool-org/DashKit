//
//  PodDetailsView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/14/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI
import DashKit

struct PodDetailsView: View {
    
    var podVersion: PodVersionProtocol
    
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
    }
    
    var body: some View {
        List {
            row(LocalizedString("Lot Number", comment: "description label for lot number pod details row"), value: String(describing: podVersion.lotNumber))
            row(LocalizedString("Sequence Number", comment: "description label for sequence number pod details row"), value: String(describing: podVersion.sequenceNumber))
            row(LocalizedString("Firmware Version", comment: "description label for firmware version pod details row"), value: podVersion.firmwareVersion)
        }
        .navigationBarTitle("Pod Details", displayMode: .automatic)
    }
}

struct PodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PodDetailsView(podVersion: MockPodVersion(lotNumber: 1, sequenceNumber: 1, majorVersion: 1, minorVersion: 1, interimVersion: 1, bleMajorVersion: 1, bleMinorVersion: 1, bleInterimVersion: 1))
    }
}
