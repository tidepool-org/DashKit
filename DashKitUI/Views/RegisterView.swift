//
//  RegisterView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/7/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct RegisterView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    
    @Environment(\.verticalSizeClass) var verticalSizeClass

    init(viewModel: RegistrationViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GuidePage(content: {
            Image(frameworkImage: "No Pod")
                .resizable()
                .aspectRatio(contentMode: ContentMode.fit)
                .frame(height: self.verticalSizeClass == .compact ? 70 : 150)
                .padding()

            VStack(alignment: .leading, spacing: 8) {
                Text("This device must be registered as a PDM. Registration requires internet connectivity and is only required once per device.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            self.viewModel.error.map {ErrorView($0).accessibility(sortPriority: 0)}
            
            ProgressIndicatorView(state: self.viewModel.progressState)
        }) {
            Button(action: {
                self.viewModel.registerTapped()
            }) {
                Text(self.viewModel.isRegistered ? "Continue" : "Register")
                    .actionButtonStyle()
            }
            .padding()
            .disabled(self.viewModel.isRegistering)
        }
        .padding()
        .animation(.default)
        .navigationBarTitle("Register Device", displayMode: .automatic)
    }
}

struct RegisterView_Previews: PreviewProvider {
    
    static let manager = MockRegistrationManager()

    static var previews: some View {
        NavigationView {
            RegisterView(viewModel: RegistrationViewModel(registrationManager: manager))
        }
        //.environment(\.colorScheme, .dark)
        //.environment(\.sizeCategory, .accessibilityLarge)
    }
}
