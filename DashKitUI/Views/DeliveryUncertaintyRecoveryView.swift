//
//  DeliveryUncertaintyRecoveryView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 8/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DeliveryUncertaintyRecoveryView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) private var dismiss
    
    let model: DeliveryUncertaintyRecoveryViewModel

    init(model: DeliveryUncertaintyRecoveryViewModel) {
        self.model = model
    }

    var body: some View {
        GuidePage(content: {
            Text("\(self.model.appName) has been unable to communicate with the pod on your body since \(self.uncertaintyDateLocalizedString).\n\nWithout communication with the pod, the app cannot continue to send commands for insulin delivery or display accurate, recent information about your active insulin or the insulin being delivered by the Pod.\n\nMonitor your glucose closely for the next 6 or more hours, as there may or may not be insulin actively working in your body that \(self.model.appName) cannot display.")
                .padding([.top, .bottom])
        }) {
            VStack {
                Text("Attemping to restablish communication").padding(.top)
                ProgressIndicatorView(state: .indeterminantProgress)
                Button(action: {
                    self.model.podDeactivationChosen?()
                }) {
                    Text(LocalizedString("Deactivate Pod", comment: "Button title to deactive pod on uncertain program"))
                    .actionButtonStyle()
                    .padding()
                }
            }
        }
        .environment(\.horizontalSizeClass, horizontalOverride)
        .navigationBarTitle(Text("Unable to Reach Pod"), displayMode: .large)
        .navigationBarItems(leading: backButton)
    }
    
    private var uncertaintyDateLocalizedString: String {
        DateFormatter.localizedString(from: model.uncertaintyStartedAt, dateStyle: .none, timeStyle: .short)
    }
    
    private var backButton: some View {
        Button(LocalizedString("Back", comment: "Back button text on DeliveryUncertaintyRecoveryView"), action: {
            self.dismiss()
        })
    }
}

struct DeliveryUncertaintyRecoveryView_Previews: PreviewProvider {
    static var previews: some View {
        let model = DeliveryUncertaintyRecoveryViewModel(appName: "Test App", uncertaintyStartedAt: Date())
        return DeliveryUncertaintyRecoveryView(model: model)
    }
}
