//
//  ErrorView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/12/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct ErrorView: View {
    var error: LocalizedError
    
    var errorClass: ErrorClass
    
    @Environment(\.guidanceColors) var guidanceColors
    
    public enum ErrorClass {
        case critical
        case normal
        
        func symbolColor(using guidanceColors: GuidanceColors) -> Color {
            switch self {
            case .critical:
                return guidanceColors.critical
            case .normal:
                return guidanceColors.warning
            }
        }
    }
    
    init(_ error: LocalizedError, errorClass: ErrorClass = .normal) {
        self.error = error
        self.errorClass = errorClass
    }

    var body: some View {
        HStack(alignment: .top) {
            ZStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(self.errorClass.symbolColor(using: guidanceColors))
                Text(" ") // Vertical alignment hack
            }
            .accessibilityElement(children: .ignore)
            .accessibility(label: FrameworkLocalText("Error", comment: "Accessibility label indicating an error occurred"))

            VStack(alignment: .leading, spacing: 10) {
                Text(self.error.errorDescription ?? "")
                    .bold()
                    .accessibility(identifier: "label_error_description")
                Text(self.error.recoverySuggestion ?? "")
                    .accessibility(identifier: "label_recovery_suggestion")
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct ErrorView_Previews: PreviewProvider {
    enum ErrorViewPreviewError: LocalizedError {
        case someError
        
        var localizedDescription: String { "It didn't work" }
        var recoverySuggestion: String { "Maybe try turning it on and off." }
    }
    
    static var previews: some View {
        ErrorView(ErrorViewPreviewError.someError)
    }
}
