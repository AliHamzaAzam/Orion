//
//  MessageFormatter.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

class MessageFormatter {
    static func format(_ message: Message) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let time = dateFormatter.string(from: message.timestamp)
        return "[\(time)] \(message.sender): \(message.content)"
    }
}
