//
//  ConnectionState.swift
//  DashKit
//
//  Created by Pete Schwamb on 8/29/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

extension ConnectionState {
    public var localizedDescription: String {
        switch self {
        case .connected:
            return LocalizedString("Connected", comment: "Description for pod connected state.")
        case .disconnected:
            return LocalizedString("Disconnected", comment: "Description for pod disconnected state.")
        case .tryConnecting:
            return LocalizedString("Connecting...", comment: "Description for pod connecting state.")
        }
    }
}
