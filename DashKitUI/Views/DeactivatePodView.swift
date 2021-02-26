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
        }) {
            if viewModel.state.showProgressDetail {
                VStack {
                    viewModel.error.map {ErrorView($0).accessibility(sortPriority: 0)}

                    if viewModel.error == nil {
                        VStack {
                            HStack { Spacer () }
                            ProgressIndicatorView(state: viewModel.state.progressState)
                                .padding(.horizontal)
                            if viewModel.state.isFinished {
                                FrameworkLocalText("Deactivated", comment: "Label text showing pod is deactivated")
                                    .padding(.top)
                            }
                        }
                    }
                }
                .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                .padding([.top, .horizontal])
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
            .animation(nil)
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .navigationBarTitle("Deactivate Pod", displayMode: .automatic)
        .navigationBarItems(trailing:
            viewModel.error != nil ?
                Button("Discard Pod") {
                    viewModel.discardPodButtonTapped()
                }.foregroundColor(guidanceColors.critical) : nil
        )
    }
    
}

struct DeactivatePodView_Previews: PreviewProvider {
    static var previews: some View {
        DeactivatePodView(viewModel: DeactivatePodViewModel(podDeactivator: MockPodDeactivater(), podAttachedToBody: false))
    }
}
