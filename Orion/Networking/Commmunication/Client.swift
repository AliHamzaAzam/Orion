//
//  Client.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation
import CryptoKit

class Client {
    private var socketDescriptor: Int32 = -1
    private let serverAddress: String
    private let serverPort: UInt16
    private let id: UUID
    private let encryptionManager = EncryptionManager()
    private let keyExchange = KeyExchange()
    private var symmetricKey: SymmetricKey?
    
    private var messageQueue: [Message] = [] // Queue to store messages when offline
    private var groups: [Group] = [] // List of groups the client is part of

    init(serverAddress: String, serverPort: UInt16) {
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.id = UUID()
        print("Client ID: \(id)")
    }

    func connectToServer() {
        let clientSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard clientSocket >= 0 else {
            print("Failed to create client socket")
            return
        }

        var addr = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: serverPort.bigEndian,
            sin_addr: in_addr(s_addr: inet_addr(serverAddress)),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(clientSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectResult == 0 else {
            print("Failed to connect to server")
            close(clientSocket)
            return
        }

        print("Connected to server")
        socketDescriptor = clientSocket
        
        // Send client ID to the server
        let idData = id.uuidString.data(using: .utf8)!
        write(socketDescriptor, (idData as NSData).bytes.bindMemory(to: UInt8.self, capacity: idData.count), idData.count)
        print("Sent client ID to the server")

        // Send client's public key to the server
        let publicKeyData = keyExchange.getPublicKeyData()
        publicKeyData.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            write(socketDescriptor, baseAddress, buffer.count)
        }

        // Receive encrypted symmetric key from the server
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        if bytesRead > 0 {
            let encryptedKeyData = Data(buffer[0..<bytesRead])
            symmetricKey = keyExchange.decryptKey(encryptedKeyData)
            if symmetricKey != nil {
                print("Received and decrypted symmetric key")
            } else {
                print("Failed to decrypt symmetric key")
            }
        } else {
            print("Failed to receive encrypted symmetric key")
        }
        
        sendQueuedMessages()
    }

    func sendMessage(_ content: String, to recipientID: UUID? = nil, inGroup groupName: String? = nil) {
        guard socketDescriptor >= 0, let symmetricKey = symmetricKey else {
            print("Not connected to server or symmetric key not available")
            return
        }

        let message = Message(sender: id, recipient: recipientID ?? UUID(), content: content, timestamp: Date())
        if let messageData = try? JSONEncoder().encode(message),
           let encryptedData = encryptionManager.encrypt(message: String(data: messageData, encoding: .utf8)!, using: symmetricKey) {
            print("Sending encrypted data: \(encryptedData.base64EncodedString())")
            sendBase64EncodedData(encryptedData)
        } else {
            print("Failed to encrypt message")
        }
    }

    private func sendBase64EncodedData(_ data: Data) {
        let base64String = data.base64EncodedString()
        base64String.withCString { cString in
            let length = strlen(cString)
            write(socketDescriptor, cString, length)
        }
    }

    func receiveMessage(completion: @escaping (Message) -> Void) {
        DispatchQueue.global().async {
            while true {
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = read(self.socketDescriptor, &buffer, buffer.count)
                
                if bytesRead > 0, let symmetricKey = self.symmetricKey {
                    let encryptedDataString = String(bytes: buffer[0..<bytesRead], encoding: .utf8)
                    print("Received encrypted data: \(encryptedDataString ?? "")")
                    if let encryptedData = Data(base64Encoded: encryptedDataString ?? "") {
                        print("Encrypted data size: \(encryptedData.count) bytes")
                        if let decryptedString = self.encryptionManager.decrypt(data: encryptedData, using: symmetricKey) {
                            print("Decrypted data: \(decryptedString)")
                            self.handleServerEvent(decryptedString, completion: completion)
                        } else {
                            print("Failed to decrypt or decode message")
                        }
                    } else {
                        print("Failed to decode Base64 data")
                    }
                } else if bytesRead > 0 {
                    print("Received unexpected data")
                } else if bytesRead == 0 {
                    print("Server disconnected")
                    self.disconnect()
                    break
                }
            }
        }
    }

    private func handleServerEvent(_ jsonString: String, completion: @escaping (Message) -> Void) {
        guard let data = jsonString.data(using: .utf8) else {
            print("Invalid UTF-8 string")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let event = json["event"] as? String {
                switch event {
                case "group_created":
                    if let groupData = json["group"] as? [String: Any],
                       let groupIDString = groupData["id"] as? String,
                       let groupID = UUID(uuidString: groupIDString),
                       let name = groupData["name"] as? String,
                       let members = groupData["members"] as? [String] {
                        let memberUUIDs = members.compactMap { UUID(uuidString: $0) }
                        let group = Group(id: groupID, name: name, members: memberUUIDs)
                        self.groups.append(group)
                        print("Added new group: \(name)")
                    } else {
                        print("Invalid group data")
                    }
                default:
                    print("Unhandled event: \(event)")
                }
            } else {
                // Attempt to decode as a `Message` object
                let message = try JSONDecoder().decode(Message.self, from: data)
                completion(message)
            }
        } catch {
            print("Failed to process JSON: \(error.localizedDescription)")
        }
    }

    
    func queueMessage(_ content: String, to recipientID: UUID? = nil) {
        let message = Message(sender: id, recipient: recipientID ?? UUID(), content: content, timestamp: Date())
        messageQueue.append(message)
        print("Message queued: \(content)")
        
        // Try to send the message if connected
        if socketDescriptor >= 0 {
            sendQueuedMessages()
        }
    }
    
    func sendQueuedMessages() {
        guard socketDescriptor >= 0, let symmetricKey = symmetricKey else {
            print("Not connected to server or symmetric key not available")
            return
        }
        
        while !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            if let messageData = try? JSONEncoder().encode(message),
               let encryptedData = encryptionManager.encrypt(message: String(data: messageData, encoding: .utf8)!, using: symmetricKey) {
                encryptedData.withUnsafeBytes { buffer in
                    guard let baseAddress = buffer.baseAddress else { return }
                    write(socketDescriptor, baseAddress, buffer.count)
                }
                print("Queued message sent: \(message.content)")
            } else {
                print("Failed to encrypt queued message")
            }
        }
    }
    
    
    func joinGroup(_ group: Group) {
        groups.append(group)
        print("Joined group: \(group.name)")

        // Inform the server about the new group
        let groupData: [String: Any] = [
            "id": group.id.uuidString,
            "name": group.name,
            "members": group.members.map { $0.uuidString } + [id.uuidString]
        ]
        let eventData: [String: Any] = [
            "event": "group_joined",
            "group": groupData
        ]
        do {
            let eventData = try JSONSerialization.data(withJSONObject: eventData)
            if let encryptedData = encryptionManager.encrypt(message: String(data: eventData, encoding: .utf8)!, using: symmetricKey!) {
                let base64String = encryptedData.base64EncodedString()
                print("Sending group joined event to server. Data size: \(base64String.count) characters")
                base64String.withCString { cString in
                    let length = strlen(cString)
                    write(socketDescriptor, cString, length)
                }
                print("Sent group joined event to server: \(base64String)")
            } else {
                print("Failed to encrypt event data")
            }
        } catch {
            print("Failed to serialize event data: \(error)")
        }
    }


    
    func sendMessageToGroup(_ content: String, groupID: UUID) {
        guard groups.first(where: { $0.id == groupID }) != nil else {
            print("Group not found")
            return
        }
        
        let message = Message(sender: id, recipient: groupID, content: content, timestamp: Date())
        if let messageData = try? JSONEncoder().encode(message),
              let encryptedData = encryptionManager.encrypt(message: String(data: messageData, encoding: .utf8)!, using: symmetricKey!) {
            print("Sending encrypted data: \(encryptedData.base64EncodedString())")
            sendBase64EncodedData(encryptedData)
        } else {
            print("Failed to encrypt message")
        }
        // Try to send the message if connected
        if socketDescriptor >= 0 {
            sendQueuedMessages()
        }
    }
    
    func retrieveGroups() -> [Group] {
        return groups
    }


    func disconnect() {
        guard socketDescriptor >= 0 else {
            print("Not connected to server")
            return
        }

        close(socketDescriptor)
        socketDescriptor = -1
        print("Disconnected from server")
    }
}



