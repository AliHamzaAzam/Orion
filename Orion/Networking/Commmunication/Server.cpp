//
//  Server.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

class Server {
    private var serverSocket: Int32 = -1
    private var clients: [UUID: Int32] = [:] // Map client IDs to socket descriptors
    private var groups: [String: [UUID]] = [:] // Map group names to lists of client IDs
    
    
    func start(port: UInt16) {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("Failed to create server socket")
            return
        }
        
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
            var clientAddr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &addrLen)
                }
            }

            guard clientSocket >= 0 else {
                print("Failed to accept client")
                continue
            }

            let clientID = UUID()
            clients[clientID] = clientSocket
            print("Client connected: \(clientID)")

            // Send the assigned UUID to the client
            sendMessage(clientID.uuidString, to: clientSocket)

            // Handle client communication
            DispatchQueue.global().async {
                self.handleClient(clientSocket)
            }
        }
    }
    
    private func handleClient(_ clientSocket: Int32) {
        guard let clientID = clients.first(where: { $0.value == clientSocket })?.key else { return }

        var buffer = [CChar](repeating: 0, count: 1024)
        var incompleteMessage = ""

        while true {
            let bytesRead = read(clientSocket, &buffer, buffer.count)

            // Handle disconnection
            guard bytesRead > 0 else {
                print("Client disconnected: \(clientID)")
                close(clientSocket)
                clients.removeValue(forKey: clientID)
                return
            }

            if let receivedString = String(validatingUTF8: buffer) {
                print("Received: \(receivedString)")
                incompleteMessage.append(receivedString)

                // Process complete messages (split by '\n')
                let messages = incompleteMessage.split(separator: "\n", omittingEmptySubsequences: false)
                incompleteMessage = String(messages.last ?? "")

                for message in messages.dropLast() {
                    processMessage(String(message), from: clientID)
                }
            }
        }
    }

    private func processMessage(_ rawMessage: String, from senderID: UUID) {
        let components = rawMessage.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        let recipientID = components.count > 0 ? UUID(uuidString: String(components[0])) : nil
        let groupName = components.count > 1 ? String(components[1]) : nil
        let message = components.count > 2 ? String(components[2]) : rawMessage

        if let recipientID = recipientID {
            print("Direct message from \(senderID) to \(recipientID): \(message)")
            routeMessage(message, senderID: senderID, recipientID: recipientID)
        } else if let groupName = groupName {
            print("Group message from \(senderID) in \(groupName): \(message)")
            routeMessage(message, senderID: senderID, groupName: groupName)
        } else {
            print("Unknown message format: \(rawMessage)")
        }
    }
    
    private func routeMessage(_ message: String, senderID: UUID, recipientID: UUID? = nil, groupName: String? = nil) {
        if let recipientID = recipientID {
            // Direct Message
            guard let recipientSocket = clients[recipientID] else {
                print("Recipient \(recipientID) not connected")
                return
            }
            sendMessage(message, to: recipientSocket)
        } else if let groupName = groupName {
            // Group Message
            guard let groupMembers = groups[groupName] else {
                print("Group \(groupName) does not exist")
                return
            }
            for memberID in groupMembers where memberID != senderID {
                if let memberSocket = clients[memberID] {
                    sendMessage(message, to: memberSocket)
                }
            }
        }
    }

    private func sendMessage(_ message: String, to socket: Int32) {
        message.withCString { cString in
            send(socket, cString, strlen(cString), 0)
        }
    }
    
    private func broadcast(_ message: String, excluding senderSocket: Int32) {
//        for client in clients {
//            if client != senderSocket {
//                let _ = message.withCString { send(client, $0, strlen($0), 0) }
//            }
//        }
    }
    
    
    func createGroup(name: String, members: [UUID]) {
        groups[name] = members
        print("Group \(name) created with members: \(members)")
    }

    func addMember(toGroup groupName: String, memberID: UUID) {
        groups[groupName]?.append(memberID)
        print("Added member \(memberID) to group \(groupName)")
    }

    func removeMember(fromGroup groupName: String, memberID: UUID) {
        groups[groupName]?.removeAll { $0 == memberID }
        print("Removed member \(memberID) from group \(groupName)")
    }
    
    
    func stop() {
        for client in clients {
            close(client.value)
        }
        close(serverSocket)
    }
}
