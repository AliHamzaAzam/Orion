//
//  MessageQueue.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

class MessageQueue {
    private var queue: [Message] = []
    private let lock = NSLock()
    
    func add(_ message: Message) {
        lock.lock()
        queue.append(message)
        lock.unlock()
    }
    
    func next() -> Message? {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }
}
