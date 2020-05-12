//
//  PodCommManager.swift
//  DashKit
//
//  Created by Pete Schwamb on 6/26/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import PodSDK

extension PodCommManager: PodCommManagerProtocol {
    public var podVersionAbstracted: PodVersionProtocol? {
        return self.podVersion
    }
}

extension PodVersion: PodVersionProtocol {}
