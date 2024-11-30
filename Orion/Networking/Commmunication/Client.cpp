//
//  Client.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

class Client {
    private var socketDescriptor: Int32 = -1
    private let serverAddress: String
    private let serverPort: UInt16
    private(set) var id: UUID

    init(serverAddress: String, serverPort: UInt16) {
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.id = UUID()
    }

    func connectToServer() {
        socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            perror("Socket creation failed")
            return
        }

        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = serverPort.bigEndian
        inet_pton(AF_INET, serverAddress, &serverAddr.sin_addr)

        let result = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(socketDescriptor, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard result >= 0 else {
            perror("Connection failed")
            close(socketDescriptor)
            return
        }

        print("Connected to server at \(serverAddress):\(serverPort)")

        // Read the assigned UUID from the server
        if let assignedID = receiveMessage(), let uuid = UUID(uuidString: assignedID) {
            self.id = uuid
            print("Assigned UUID: \(self.id)")
        } else {
            print("Failed to receive UUID from server")
        }
    }

    func sendMessage(_ content: String, to recipientID: UUID? = nil, inGroup groupName: String? = nil) {
        guard socketDescriptor >= 0 else {
            print("Socket is not connected")
            return
        }

        // Create message structure
        let recipientIDString = recipientID?.uuidString ?? ""
        let groupNameString = groupName ?? ""
        let formattedMessage = "\(recipientIDString)|\(groupNameString)|\(content)\n"

        // Send the message
        formattedMessage.withCString { cString in
            let sentBytes = send(socketDescriptor, cString, strlen(cString), 0)
            if sentBytes < 0 {
                print("Failed to send message: \(String(cString: strerror(errno)))")
            } else {
                print("Message sent: \(formattedMessage)")
            }
        }
    }
    
    
    
    func sendMessageToClient(_ message: String, client: Client) {
        guard socketDescriptor >= 0 else {
            print("Socket is not connected")
            return
        }
        
        message.withCString { cString in
            send(client.socketDescriptor, cString, strlen(cString), 0)
        }
    }

    func receiveMessage() -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        let bytesRead = `read`(socketDescriptor, &buffer, buffer.count) // `read` is a built-in function in Swift
        
        guard bytesRead > 0 else {
            return nil
        }
        
        return String(cString: buffer)
    }

    func disconnect() {
        if socketDescriptor >= 0 {
            close(socketDescriptor)
            print("Disconnected")
        }
    }
}
