//
//  PodDetails .swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/14/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

protocol PodDetails {
    var podIdentifier: String { get }
    var lotNumber: String { get }
    var tid: String { get }
    var piPmVersion: String { get }
    var pdmIdentifier: String { get }
    var sdkVersion: String { get }
}
