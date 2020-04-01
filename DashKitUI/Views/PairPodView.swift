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
    
    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")

                HStack {
                    InstructionList(instructions: [
                        LocalizedString("Fill a new pod with U-100 Insulin (leave blue Pod needle cap on)", comment: "Label text for step 1 of pair pod instructions"),
                        LocalizedString("Listen for 2 beeps.", comment: "Label text for step 2 of pair pod instructions")
                    ])
                        .foregroundColor(Color(self.viewModel.state.instructionsColor))
                    Spacer()
                }
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
                                Text("Paired")
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
                    .actionButtonStyle()
            }
            .disabled(self.viewModel.state.isProcessing)
            .animation(nil)
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .animation(.default)
        .navigationBarTitle("Pod Pairing", displayMode: .automatic)
        .navigationBarBackButtonHidden(self.viewModel.state.isProcessing)
        .navigationBarItems(trailing:
            Button("Cancel") {
                self.viewModel.cancelButtonTapped()
            }
            .accessibility(identifier: "button_cancel")
            .disabled(self.viewModel.state.isProcessing)
        )
    }
}

struct PairPodView_Previews: PreviewProvider {
    
    static var previews: some View {
        NavigationView {
            PairPodView(viewModel: PairPodViewModel(podPairer: MockPodPairer(), navigator: MockNavigator()))
        }
        //.environment(\.colorScheme, .dark)
        //.environment(\.sizeCategory, .accessibilityLarge)
    }
}
