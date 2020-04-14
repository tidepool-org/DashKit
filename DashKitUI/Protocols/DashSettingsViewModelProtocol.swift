//
//  SettingsViewModelProtocol.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/8/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

protocol DashSettingsViewModelProtocol: ObservableObject, Identifiable {
    var lifeState: PodLifeState { get }
    
    func suspendResumeTapped()
    
    var podDetails: PodDetails { get }
}


