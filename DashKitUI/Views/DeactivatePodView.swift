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
                    FrameworkLocalText("Please deactivate the pod. When deactivation is complete, remove pod from body.", comment: "Header for pod deactivation view")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }) {
            if self.viewModel.state.showProgressDetail {
                VStack {
                    self.viewModel.error.map {ErrorView($0).accessibility(sortPriority: 0)}

                    if self.viewModel.error == nil {
                        VStack {
                            HStack { Spacer () }
                            ProgressIndicatorView(state: self.viewModel.state.progressState)
                                .padding(.horizontal)
                            if self.viewModel.state.isFinished {
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
                self.viewModel.continueButtonTapped()
            }) {
                Text(self.viewModel.state.actionButtonDescription)
                    .accessibility(identifier: "button_next_action")
                    .accessibility(label: Text(self.viewModel.state.actionButtonAccessibilityLabel))
                    .actionButtonStyle(self.viewModel.state.actionButtonStyle)
            }
            .disabled(self.viewModel.state.isProcessing)
            .animation(nil)
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .navigationBarTitle("Deactivate Pod", displayMode: .automatic)
        .navigationBarItems(trailing:
            self.viewModel.error != nil ?
                Button("Discard Pod") {
                    self.viewModel.discardPodButtonTapped()
                }.foregroundColor(guidanceColors.critical) : nil
        )
    }
    
}

struct DeactivatePodView_Previews: PreviewProvider {
    static var previews: some View {
        DeactivatePodView(viewModel: DeactivatePodViewModel(podDeactivator: MockPodDeactivater()))
    }
}
