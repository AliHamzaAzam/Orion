//
//  Item.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
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
