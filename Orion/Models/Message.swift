//
//  Message.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import Foundation

struct Message : Codable {
    let sender: UUID
    let recipient: UUID
    let content: String
    let timestamp: Date
}
