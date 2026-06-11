//
//  Item.swift
//  sumi-ios
//
//  Created by olumami etuk on 6/10/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
