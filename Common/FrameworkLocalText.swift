//
//  FrameworkLocalText.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 7/21/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import SwiftUI

private class FrameworkReferenceClass {
    static let bundle = Bundle(for: FrameworkReferenceClass.self)
}

func FrameworkLocalText(_ key: LocalizedStringKey, comment: StaticString) -> Text {
    return Text(key, bundle: FrameworkReferenceClass.bundle, comment: comment)
}
