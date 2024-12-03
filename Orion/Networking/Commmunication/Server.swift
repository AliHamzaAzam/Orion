//
//  Server.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation
import CryptoKit

class Server {
    private var serverSocket: Int32 = -1
    private var clients: [UUID: Int32] = [:]
    private let encryptionManager = EncryptionManager()
    private let keyExchange = KeyExchange()
    private var clientPublicKeys: [UUID: SecKey] = [:]
    private var symmetricKey: SymmetricKey = SymmetricKey(size: .bits256) // Symmetric key to encrypt messages
    
    private var messageQueues: [UUID: [Message]] = [:] // Queues to store messages for offline clients
    private var groups: [Group] = []
    
    func start(port: UInt16) {
        // Create a socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("Failed to create server socket")
            return
        }

        // Bind the socket to an address
        var addr = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr(s_addr: INADDR_ANY),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            print("Failed to bind socket")
            close(serverSocket)
            return
        }

        // Listen for incoming connections
        guard listen(serverSocket, 5) == 0 else {
            print("Failed to listen on socket")
            close(serverSocket)
            return
        }

        print("Server started on port \(port)")

        // Start accepting clients
        DispatchQueue.global().async {
            self.acceptClients()
        }
    }


    private func acceptClients() {
        while true {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else {
                print("Failed to accept client")
                continue
            }
            
            // Read client ID from client
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            if bytesRead > 0 {
                let clientIDString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                let clientID = UUID(uuidString: clientIDString) ?? UUID()
                clients[clientID] = clientSocket
                print("Accepted client: \(clientID)")
                
                // Handle public key reception
                buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = read(clientSocket, &buffer, buffer.count)
                if bytesRead > 0 {
                    let publicKeyData = Data(buffer[0..<bytesRead])
                    let keyDict: [String: Any] = [
                        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                        kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                        kSecAttrKeySizeInBits as String: 2048,
                        kSecReturnPersistentRef as String: true
                    ]
                    guard let clientPublicKey = SecKeyCreateWithData(publicKeyData as CFData, keyDict as CFDictionary, nil) else {
                        print("Failed to create public key for client")
                        continue
                    }
                    clientPublicKeys[clientID] = clientPublicKey

                    // Encrypt symmetric key with client's public key and send it to client
                    if let encryptedKey = keyExchange.encryptKey(symmetricKey, with: clientPublicKey) {
                        encryptedKey.withUnsafeBytes { buffer in
                            guard let baseAddress = buffer.baseAddress else { return }
                            write(clientSocket, baseAddress, buffer.count)
                        }
                        print("Sent encrypted symmetric key to client")
                    } else {
                        print("Failed to encrypt symmetric key")
                    }
                } else {
                    print("Failed to receive client's public key")
                }

                // Handle client communication
                DispatchQueue.global().async {
                    self.handleClient(clientSocket, clientID: clientID)
                }
            } else {
                print("Failed to read client ID")
                close(clientSocket)
                continue
            }
            
        }
    }


    private func sendBase64EncodedData(_ data: Data, to socket: Int32) {
        let base64String = data.base64EncodedString()
        base64String.withCString { cString in
            let length = strlen(cString)
            write(socket, cString, length)
        }
    }

    private func processMessage(_ message: Message, from senderID: UUID) {
        print("Processing message from \(senderID): \(message.content)")
        routeMessage(message, senderID: senderID, recipientID: message.recipient)
        
    }

    private func routeMessage(_ message: Message, senderID: UUID, recipientID: UUID? = nil) {
        if let recipientID = recipientID, let recipientSocket = clients[recipientID] {
            print("Routing message to recipient: \(recipientID)")
            sendMessage(message, to: recipientSocket)
        } else {
            print("Client \(recipientID?.uuidString ?? "") is offline. Queuing message.")
            if let recipientID = recipientID {
                if messageQueues[recipientID] == nil {
                    messageQueues[recipientID] = []
                }
                messageQueues[recipientID]?.append(message)
            }
        }
    }

    private func handleClient(_ clientSocket: Int32, clientID: UUID) {
        while true {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientSocket, &buffer, buffer.count)

            if bytesRead > 0 {
                let encryptedDataString = String(bytes: buffer[0..<bytesRead], encoding: .utf8)
                print("Received encrypted data from client \(clientID): \(encryptedDataString ?? "")")
                if let encryptedData = Data(base64Encoded: encryptedDataString ?? "") {
                    print("Encrypted data size: \(encryptedData.count) bytes")
                    if let decryptedString = encryptionManager.decrypt(data: encryptedData, using: symmetricKey) {
                        print("Decrypted data: \(decryptedString)")
                        
                        if let data = decryptedString.data(using: .utf8) {
                            do {
                                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                                   let event = json["event"] as? String {
                                    switch event {
                                    case "group_joined", "group_created":
                                        if let groupData = json["group"] as? [String: Any],
                                           let groupIDString = groupData["id"] as? String,
                                           let groupID = UUID(uuidString: groupIDString),
                                           let name = groupData["name"] as? String,
                                           let members = groupData["members"] as? [String] {
                                            let memberUUIDs = members.compactMap { UUID(uuidString: $0) }
                                            let group = Group(id: groupID, name: name, members: memberUUIDs)
                                            groups.append(group)
                                            broadcastGroupCreation(group)
                                            print("Group joined: \(name)")
                                        } else {
                                            print("Invalid group data")
                                        }
                                    default:
                                        print("Unhandled event: \(event)")
                                    }
                                } else {
                                    let message = try JSONDecoder().decode(Message.self, from: data)
                                    processMessage(message, from: clientID)
                                    reEncryptAndSendMessage(message, originalContent: decryptedString, to: message.recipient, originalSender: clientID)
                                }
                            } catch {
                                print("Failed to process JSON: \(error.localizedDescription)")
                            }
                        } else {
                            print("Failed to convert decrypted string to data")
                        }
                    } else {
                        print("Failed to decrypt data")
                    }
                } else {
                    print("Failed to decode Base64 data")
                }
            }
        }
    }




    private func reEncryptAndSendMessage(_ message: Message, originalContent: String, to recipientID: UUID, originalSender: UUID) {

        if let reEncryptedData = encryptionManager.encrypt(message: originalContent, using: symmetricKey) {
            print("Re-encrypted data: \(reEncryptedData.base64EncodedString())")
            sendBase64EncodedData(reEncryptedData, to: recipientID)
        } else {
            print("Failed to re-encrypt message")
        }
    }

    private func sendBase64EncodedData(_ data: Data, to recipientID: UUID) {
        guard let recipientSocket = clients[recipientID] else {
            print("Recipient \(recipientID) is not connected")
            return
        }

        let base64String = data.base64EncodedString()
        base64String.withCString { cString in
            let length = strlen(cString)
            write(recipientSocket, cString, length)
        }
    }

    private func sendMessage(_ message: Message, to socket: Int32) {
        guard let messageData = try? JSONEncoder().encode(message),
              let encryptedData = encryptionManager.encrypt(message: String(data: messageData, encoding: .utf8)!, using: symmetricKey) else {
            print("Failed to encrypt message")
            return
        }

        print("Sending encrypted data: \(encryptedData.base64EncodedString())")
        encryptedData.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            write(socket, baseAddress, buffer.count)
        }
    }

    
    private func broadcast(_ message: Message, excluding senderSocket: Int32) {
        for (clientID, clientSocket) in clients where clientSocket != senderSocket {
            print("Broadcasting message to client: \(clientID)")
            sendMessage(message, to: clientSocket)
        }
    }
    
    private func sendQueuedMessages(to clientID: UUID) {
        guard let clientSocket = clients[clientID] else { return }
        
        if let queuedMessages = messageQueues[clientID] {
            for message in queuedMessages {
                sendMessage(message, to: clientSocket)
            }
            messageQueues[clientID] = [] // Clear the queue after sending messages
            print("Queued messages sent to client: \(clientID)")
        }
    }
    
    func createGroup(name: String, members: [UUID]) {
        let group = Group(id: UUID(), name: name, members: members)
        groups.append(group)
        broadcastGroupCreation(group)
    }

    private func broadcastGroupCreation(_ group: Group) {
        let message = [
            "event": "group_created",
            "group": [
                "id": group.id.uuidString,
                "name": group.name,
                "members": group.members.map { $0.uuidString }
            ]
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            print("Serialized group creation message: \(String(data: jsonData, encoding: .utf8)!)")
            if let encryptedData = encryptionManager.encrypt(message: String(data: jsonData, encoding: .utf8)!, using: symmetricKey) {
                let base64EncodedString = encryptedData.base64EncodedString()
                print("Broadcasting group creation. Base64 encoded data size: \(base64EncodedString.count) characters")

                base64EncodedString.withCString { cString in
                    let length = strlen(cString)
                    for (clientID, clientSocket) in clients {
                        if group.members.contains(clientID) {
                            write(clientSocket, cString, length)
                        }
                    }
                }

                print("Broadcasted group creation: \(group.name)")
            } else {
                print("Failed to encrypt group creation message")
            }
        } catch {
            print("Failed to serialize group creation message: \(error)")
        }
    }



    func stop() {
        for client in clients.values {
            close(client)
        }
        close(serverSocket)
        print("Server stopped.")
    }
}



