//
//  MessageFormatter.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

class MessageFormatter {
    
    /// Encodes a `Message` instance into `Data` for transmission.
    /// - Parameter message: The `Message` object to encode.
    /// - Returns: Encoded `Data` or `nil` if encoding fails.
    func encodeMessage(_ message: Message) -> Data? {
        do {
            let jsonData = try JSONEncoder().encode(message)
            return jsonData
        } catch {
            print("Error encoding message: \(error)")
            return nil
        }
    }
    
    /// Decodes received `Data` into a `Message` object.
    /// - Parameter data: The `Data` to decode.
    /// - Returns: A `Message` object or `nil` if decoding fails.
    func decodeMessage(_ data: Data) -> Message? {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            return message
        } catch {
            print("Error decoding message: \(error)")
            return nil
        }
    }
    
    /// Sends a `Message` over the given socket.
    /// - Parameters:
    ///   - message: The `Message` object to send.
    ///   - socket: The socket file descriptor to write to.
    func sendMessage(_ message: Message, to socket: Int32) {
        guard let messageData = encodeMessage(message) else {
            print("Failed to encode message.")
            return
        }
        
        messageData.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                print("Invalid buffer base address.")
                return
            }
            let bytesWritten = write(socket, baseAddress, buffer.count)
            if bytesWritten < 0 {
                print("Failed to write to socket: \(String(cString: strerror(errno)))")
            } else {
                print("Message sent successfully.")
            }
        }
    }
    
    /// Reads and decodes a `Message` from the given socket.
    /// - Parameter socket: The socket file descriptor to read from.
    /// - Returns: A `Message` object or `nil` if reading or decoding fails.
    func receiveMessage(from socket: Int32) -> Message? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)
        
        if bytesRead < 0 {
            print("Failed to read from socket: \(String(cString: strerror(errno)))")
            return nil
        }
        
        let data = Data(buffer[0..<bytesRead])
        return decodeMessage(data)
    }
}
