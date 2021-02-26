//
//  InsertCannulaView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/5/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct InsertCannulaView: View {
    
    @ObservedObject var viewModel: InsertCannulaViewModel
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var cancelModalIsPresented: Bool = false
    
    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")

                HStack {
                    InstructionList(instructions: [
                        LocalizedString("Tap below to start cannula insertion.", comment: "Label text for step one of insert cannula instructions"),
                        LocalizedString("Wait until insertion is completed.", comment: "Label text for step two of insert cannula instructions"),
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
                                FrameworkLocalText("Inserted", comment: "Label text indicating cannula inserted")
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
                    .actionButtonStyle(self.viewModel.state.nextActionButtonStyle)
            }
            .disabled(self.viewModel.state.isProcessing)
            .animation(nil)
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .animation(.default)
        .alert(isPresented: $cancelModalIsPresented) { cancelPairingModal }
        .navigationBarTitle("Insert Cannula", displayMode: .automatic)
        .navigationBarItems(trailing: cancelButton)
    }
    
    var cancelButton: some View {
        Button(LocalizedString("Cancel", comment: "Cancel button text in navigation bar on insert cannula screen")) {
            cancelModalIsPresented = true
        }
        .accessibility(identifier: "button_cancel")
    }
    
    var cancelPairingModal: Alert {
        return Alert(
            title: FrameworkLocalText("Are you sure you want to cancel Pod setup?", comment: "Alert title for cancel pairing modal"),
            message: FrameworkLocalText("If you cancel Pod setup, the current Pod will be deactivated and will be unusable.", comment: "Alert message body for confirm pod attachment"),
            primaryButton: .destructive(FrameworkLocalText("Yes, Deactivate Pod", comment: "Button title for confirm deactivation option"), action: { viewModel.didRequestDeactivation?() } ),
            secondaryButton: .default(FrameworkLocalText("No, Continue With Pod", comment: "Continue pairing button title of in pairing cancel modal"))
        )
    }

}

struct InsertCannulaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack {
                Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all)
                InsertCannulaView(viewModel: InsertCannulaViewModel(cannulaInserter: MockCannulaInserter()))
            }
        }
        //.environment(\.colorScheme, .dark)
        //.environment(\.sizeCategory, .accessibilityLarge)
    }
}
