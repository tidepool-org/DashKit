//
//  InstructionListView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/7/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI

struct InstructionListView: View {
    let instructions: [LocalizedStringKey]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(instructions.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index+1)")
                        .padding(6)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(Color.white)
                        .font(.caption)
                        .accessibility(label: Text("\(index+1), ")) // Adds a pause after the number
                    Text(self.instructions[index])
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(2)
                    
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct InstructionListView_Previews: PreviewProvider {
    static var previews: some View {
        let instructions = [
            LocalizedStringKey("This is the first step."),
            LocalizedStringKey("This second step is a bit more tricky and needs more description to support the user, albeit it could be more concise."),
            LocalizedStringKey("With this final step, the task will be accomplished.")
        ]
        return InstructionListView(instructions: instructions)
    }
}
