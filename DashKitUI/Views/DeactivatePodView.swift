//
//  DeactivatePodView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/9/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DeactivatePodView: View {
    
    @ObservedObject var viewModel: DeactivatePodViewModel

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.guidanceColors) var guidanceColors

    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")

                HStack {
                    Text(viewModel.instructionText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
            .padding(.bottom, 8)
        }) {
            VStack {
                if viewModel.state.showProgressDetail {
                    VStack {
                        viewModel.error.map {ErrorView($0).accessibility(sortPriority: 0)}
                        
                        if viewModel.error == nil {
                            VStack {
                                ProgressIndicatorView(state: viewModel.state.progressState)
                                if self.viewModel.state.isFinished {
                                    FrameworkLocalText("Deactivated", comment: "Label text showing pod is deactivated")
                                        .bold()
                                        .padding(.top)
                                }
                            }
                            .padding(.bottom, 8)
                        }

                    }
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                }
                if viewModel.error != nil {
                    Button(action: {
                        viewModel.discardPodButtonTapped()
                    }) {
                        FrameworkLocalText("Discard Pod", comment: "Text for discard pod button")
                            .accessibility(identifier: "button_discard_pod_action")
                            .actionButtonStyle(.destructive)
                    }
                    .disabled(viewModel.state.isProcessing)
                }
                Button(action: {
                    viewModel.continueButtonTapped()
                }) {
                    Text(viewModel.state.actionButtonDescription)
                        .accessibility(identifier: "button_next_action")
                        .accessibility(label: Text(viewModel.state.actionButtonAccessibilityLabel))
                        .actionButtonStyle(viewModel.state.actionButtonStyle)
                }
                .disabled(viewModel.state.isProcessing)
            }
            .padding()
        }
        .navigationBarTitle("Deactivate Pod", displayMode: .automatic)
        .navigationBarItems(trailing:
            Button("Cancel") {
                viewModel.didCancel?()
            }
        )
    }
    
}

struct DeactivatePodView_Previews: PreviewProvider {
    static var previews: some View {
        DeactivatePodView(viewModel: DeactivatePodViewModel(podDeactivator: MockPodDeactivater(), podAttachedToBody: false))
    }
}
