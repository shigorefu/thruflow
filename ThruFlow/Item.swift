//
//  Item.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
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
