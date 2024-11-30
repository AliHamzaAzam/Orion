//
//  ChatViewModel.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import Foundation
import SwiftUI

struct Contact: Identifiable {
    let id: UUID
    let profileColor: Color
    let initials: String
}

// MARK: - ChatViewModel
class ChatViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var messages: [Message] = [] // Store all messages
    @Published var inputMessage: String = "" // Current input
    private var client: Client? // Network client
    var currentUserID = UUID() // Current user ID

    func connectToServer(serverAddress: String, serverPort: UInt16) {
        client = Client(serverAddress: serverAddress, serverPort: serverPort)
        client?.connectToServer()

        // Once connected, start receiving messages
        listenForMessages()
    }

    func sendMessageToRecipient(content: String, recipient: UUID) {
        guard let client = client else { return }
        client.sendMessage(content, to: recipient)
        let message = Message(sender: currentUserID, recipient: recipient, content: content, timestamp: Date())
        messages.append(message) // Store message in local list
    }

    private func listenForMessages() {
        // Listen for incoming messages and update the UI
        client?.receiveMessage { message in
            print("Received message: \(message)")
            // Update the messages array on the main thread (UI updates)
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(message)
            }
        }
    }

    func addContact(id: UUID) {
        let contact = Contact(id: id, profileColor: Color.blue, initials: "AB") // Dummy data
        contacts.append(contact)
    }

    func filteredMessages(for recipient: UUID) -> [Message] {
        return messages.filter({ $0.sender == recipient || $0.recipient == recipient })
    }

    func getContactName(for id: UUID) -> String {
        return "Contact \(id.uuidString)" // Placeholder for contact name
    }
}
