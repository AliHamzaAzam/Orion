//
//  Message.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import Foundation

struct Message: Identifiable, Codable {
    let sender: UUID
    let receiver: UUID
    let content: String
    let timestamp: Date
    let id: UUID
}
