//
//  NumberFormatter.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

extension NumberFormatter {
    func string(from number: Double) -> String? {
        return string(from: NSNumber(value: number))
    }
}
