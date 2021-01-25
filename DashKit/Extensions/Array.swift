//
//  Array.swift
//  DashKit
//
//  Created by Pete Schwamb on 1/7/21.
//  Copyright © 2021 Tidepool. All rights reserved.
//

import Foundation

extension Array {
    func makeInfiniteLoopIterator() -> AnyIterator<Element> {
        var index = self.startIndex

        return AnyIterator({
            if self.isEmpty {
                return nil
            }

            let result = self[index]

            index = self.index(after: index)
            if index == self.endIndex {
                index = self.startIndex
            }

            return result
        })
    }
}
