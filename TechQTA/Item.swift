//
//  Item.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
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
