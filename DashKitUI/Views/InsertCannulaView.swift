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
    
    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Pod")

                HStack {
                    InstructionList(instructions: [
                        "Prepare site.",
                        "Remove blue Pod needle cap and check cannula. Then remove paper backing.",
                        "Check Pod and then apply to site."
                    ]).foregroundColor(Color(self.viewModel.state.instructionsColor))
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
                                Text("Inserted")
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
        .navigationBarTitle("Insert Cannula", displayMode: .automatic)
        .navigationBarItems(trailing:
            Button("Cancel") {
                self.viewModel.cancelButtonTapped()
            }
            .accessibility(identifier: "button_cancel")
        )
    }
}

struct InsertCannulaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack {
                Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all)
                InsertCannulaView(viewModel: InsertCannulaViewModel(cannulaInsertion: MockCannulaInsertion(), navigator: MockNavigator()))
            }
        }
        //.environment(\.colorScheme, .dark)
        //.environment(\.sizeCategory, .accessibilityLarge)
    }
}
