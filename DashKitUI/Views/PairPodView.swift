//
//  PairPodView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/5/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct PairPodView: View {
    
    @ObservedObject var viewModel: PairPodViewModel
    
    @State private var cancelModalIsPresented: Bool = false
    
    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")

                HStack {
                    InstructionList(instructions: [
                        LocalizedString("Fill a new pod with U-100 Insulin (leave blue Pod needle cap on).", comment: "Label text for step 1 of pair pod instructions"),
                        LocalizedString("Listen for 2 beeps.", comment: "Label text for step 2 of pair pod instructions")
                    ])
                    .disabled(viewModel.state.instructionsDisabled)
                }
                .padding(.bottom, 8)
            }
            .accessibility(sortPriority: 1)
        }) {
            if self.viewModel.state.showProgressDetail {
                VStack {
                    self.viewModel.error.map {
                        ErrorView($0, errorClass: $0.recoverable ? .normal : .critical)
                            .accessibility(sortPriority: 0)
                    }

                    if self.viewModel.error == nil {
                        VStack {
                            HStack { Spacer () }
                            ProgressIndicatorView(state: self.viewModel.state.progressState)
                                .padding(.horizontal)
                            if self.viewModel.state.isFinished {
                                FrameworkLocalText("Paired", comment: "Label text indicating pairing finished.")
                                    .padding(.top)
                            }
                        }
                    }
                }
                .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                .padding([.top, .horizontal])
            }
            Button(action: {
                self.viewModel.continueButtonTapped()
            }) {
                Text(self.viewModel.state.nextActionButtonDescription)
                    .accessibility(identifier: "button_next_action")
                    .accessibility(label: Text(self.viewModel.state.actionButtonAccessibilityLabel))
                    .actionButtonStyle(self.viewModel.state.actionButtonType)
            }
            .disabled(self.viewModel.state.isProcessing)
            .animation(nil)
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .animation(.default)
        .alert(isPresented: $cancelModalIsPresented) { cancelPairingModal }
        .navigationBarTitle("Pod Pairing", displayMode: .automatic)
        .navigationBarBackButtonHidden(self.viewModel.state.isProcessing)
        .navigationBarItems(trailing: self.viewModel.state.navBarVisible ? cancelButton : nil)
    }
        
    var cancelButton: some View {
        Button(LocalizedString("Cancel", comment: "Cancel button text in navigation bar on pair pod UI")) {
            if viewModel.podIsActivated {
                cancelModalIsPresented = true
            } else {
                viewModel.didCancelSetup?()
            }
        }
        .accessibility(identifier: "button_cancel")
        .disabled(self.viewModel.state.isProcessing)
    }
    
    var cancelPairingModal: Alert {
        return Alert(
            title: FrameworkLocalText("Are you sure you want to cancel Pod setup?", comment: "Alert title for cancel pairing modal"),
            message: FrameworkLocalText("If you cancel Pod setup, the current Pod will be deactivated and will be unusable.", comment: "Alert message body for confirm pod attachment"),
            primaryButton: .destructive(FrameworkLocalText("Yes, Deactivate Pod", comment: "Button title for confirm deactivation option"), action: { viewModel.didRequestDeactivation?() }),
            secondaryButton: .default(FrameworkLocalText("No, Continue With Pod", comment: "Continue pairing button title of in pairing cancel modal"))
        )
    }

}

struct PairPodView_Previews: PreviewProvider {
    
    static var previews: some View {
        NavigationView {
            PairPodView(viewModel: PairPodViewModel(podPairer: MockPodPairer(), navigator: MockNavigator()))
        }
    }
}
