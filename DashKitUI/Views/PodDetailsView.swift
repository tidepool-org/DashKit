//
//  PodDetailsView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/14/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct PodDetailsView: View {
    
    var podDetails: PodDetails
    
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
    }
    
    var body: some View {
        List {
            row(LocalizedString("Pod Identifier", comment: "description label for pod identifer pod details row"), value: podDetails.podIdentifier)
            row(LocalizedString("Lot", comment: "description label for lot id pod details row"), value: podDetails.lot)
            row(LocalizedString("TID", comment: "description label for tid pod details row"), value: podDetails.tid)
            row(LocalizedString("PI / PM Version", comment: "description label for pi/pm version pod details row"), value: podDetails.piPmVersion)
            row(LocalizedString("PDM Identifier", comment: "description label for pdm identifier details row"), value: podDetails.pdmIdentifier)
            row(LocalizedString("SDK Version", comment: "description label for sdk version details row"), value: podDetails.sdkVersion)
        }
        .navigationBarTitle("Pod Details", displayMode: .automatic)
    }
}

struct PodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PodDetailsView(podDetails: MockPodDetails())
    }
}
