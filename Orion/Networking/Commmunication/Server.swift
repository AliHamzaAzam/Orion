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
    private let messageFormatter = MessageFormatter()
    private let encryptionManager = EncryptionManager()
    private let keyExchange = KeyExchange()
    private var clientPublicKeys: [UUID: SecKey] = [:]
    private var symmetricKey: SymmetricKey?
    
    private var messageQueues: [UUID: [Message]] = [:] // Queues to store messages for offline clients

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

        // Generate symmetric key for communication
        symmetricKey = SymmetricKey(size: .bits256)

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
                    if let symmetricKey = symmetricKey,
                       let encryptedKey = keyExchange.encryptKey(symmetricKey, with: clientPublicKey) {
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

    private func handleClient(_ clientSocket: Int32, clientID: UUID) {
        while true {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientSocket, &buffer, buffer.count)

            if bytesRead > 0, let symmetricKey = symmetricKey {
                let encryptedDataString = String(bytes: buffer[0..<bytesRead], encoding: .utf8)
                print("Received encrypted data from client \(clientID): \(encryptedDataString ?? "")")
                if let encryptedData = Data(base64Encoded: encryptedDataString ?? ""),
                   let decryptedString = encryptionManager.decrypt(data: encryptedData, using: symmetricKey),
                   let data = decryptedString.data(using: .utf8),
                   let message = try? JSONDecoder().decode(Message.self, from: data) {
                    processMessage(message, from: clientID)
                    // Re-encrypt the message and send it back to the client
                    if let reEncryptedData = encryptionManager.encrypt(message: decryptedString, using: symmetricKey) {
                        print("Re-encrypted data: \(reEncryptedData.base64EncodedString())")
                        sendBase64EncodedData(reEncryptedData, to: clientSocket)
                    } else {
                        print("Failed to re-encrypt message")
                    }
                } else {
                    print("Failed to read or decrypt message from client: \(clientID)")
                }
            }
            sendQueuedMessages(to: clientID)
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

    private func sendMessage(_ message: Message, to socket: Int32) {
        guard let symmetricKey = symmetricKey,
              let encryptedData = encryptionManager.encrypt(message: message.content, using: symmetricKey) else {
            print("Failed to encrypt message")
            return
        }
        
        let encryptedMessage = Message(sender: message.sender, recipient: message.recipient, content: String(data: encryptedData, encoding: .utf8) ?? "", timestamp: message.timestamp)
        messageFormatter.sendMessage(encryptedMessage, to: socket)
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

    func stop() {
        for client in clients.values {
            close(client)
        }
        close(serverSocket)
        print("Server stopped.")
    }
}

