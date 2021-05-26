//
//  ExpirationReminderPickerView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 5/17/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit

struct ExpirationReminderPickerView: View {
    
    static let expirationReminderHoursAllowed = 1...24
    
    var expirationReminderDefault: Binding<Int>
    
    var collapsible: Bool = true
    
    @State var showingHourPicker: Bool = false
    
    var expirationDefaultFormatter = QuantityFormatter(for: .hour())
    
    var expirationDefaultString: String {
        return expirationValueString(expirationReminderDefault.wrappedValue)
    }
    
    func expirationValueString(_ value: Int) -> String {
        return expirationDefaultFormatter.string(from: HKQuantity(unit: .hour(), doubleValue: Double(value)), for: .hour())!
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(LocalizedString("Expiration Reminder Default", comment: "Label text for expiration reminder default row"))
                Spacer()
                if collapsible {
                    Button(expirationDefaultString) {
                        withAnimation {
                            showingHourPicker.toggle()
                        }
                    }
                } else {
                    Text(expirationDefaultString)
                }
            }
            if showingHourPicker {
                Picker("", selection: expirationReminderDefault) {
                    ForEach(Self.expirationReminderHoursAllowed, id: \.self) { value in
                        Text(expirationValueString(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 100)
                .clipped()
            }
        }
    }
}

struct ExpirationReminderPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ExpirationReminderPickerView(expirationReminderDefault: .constant(2))
    }
}
