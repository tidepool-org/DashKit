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
                        LocalizedString("Prepare site.", comment: "Label text for step one of insert cannula instructions"),
                        LocalizedString("Remove blue Pod needle cap and check cannula. Then remove paper backing.", comment: "Label text for step two of insert cannula instructions"),
                        LocalizedString("Check Pod and then apply to site.", comment: "Label text for step three of insert cannula instructions")
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
                InsertCannulaView(viewModel: InsertCannulaViewModel(cannulaInserter: MockCannulaInserter(), navigator: MockNavigator()))
            }
        }
        //.environment(\.colorScheme, .dark)
        //.environment(\.sizeCategory, .accessibilityLarge)
    }
}
