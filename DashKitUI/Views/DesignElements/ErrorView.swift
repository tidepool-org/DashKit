//
//  ErrorView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/12/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI

struct ErrorView: View {
    var error: LocalizedError
    
    var errorClass: ErrorClass
    
    public enum ErrorClass {
        case critical
        case normal
        
        var symbolColor: UIColor {
            switch self {
            case .critical:
                return .deleteColor
            case .normal:
                return .systemOrange
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
                    .foregroundColor(Color(self.errorClass.symbolColor))
                Text(" ") // Vertical alignment hack
            }
            .accessibilityElement(children: .ignore)
            .accessibility(label: Text("Error"))

            VStack(alignment: .leading, spacing: 10) {
                Text(self.error.errorDescription ?? "")
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
