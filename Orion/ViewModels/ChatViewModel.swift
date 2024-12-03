//
//  ChatViewModel.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import Foundation
import SwiftUI

// MARK: - ChatViewModel
class ChatViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var messages: [Message] = []
    @Published var groups: [Group] = []
    @Published var inputMessage: String = ""
    private var client: Client?
    var currentUserID = UUID()

    func connectToServer(serverAddress: String, serverPort: UInt16) {
        client = Client(serverAddress: serverAddress, serverPort: serverPort)
        client?.connectToServer()
        listenForMessages()
    }

    func sendMessageToRecipient(content: String, recipient: UUID) {
        guard let client = client else { return }
        client.sendMessage(content, to: recipient)
        let message = Message(sender: currentUserID, recipient: recipient, content: content, timestamp: Date())
        messages.append(message)
    }

    func sendMessageToGroup(content: String, groupID: UUID) {
        guard let client = client else { return }
        client.sendMessageToGroup(content, groupID: groupID)
        let message = Message(sender: currentUserID, recipient: groupID, content: content, timestamp: Date())
        messages.append(message)
    }

    func createGroup(name: String, members: [UUID]) {
        guard let client = client else { return }
        let group = Group(id: UUID(), name: name, members: members + [currentUserID])
        groups.append(group)
        client.joinGroup(group)
    }

    func retrieveGroups() {
        guard let client = client else { return }
        groups = client.retrieveGroups()
    }

    private func listenForMessages() {
        client?.receiveMessage { message in
            print("Received message: \(message)")
            DispatchQueue.main.async { [weak self] in
                if let event = message.content.data(using: .utf8).flatMap({
                    try? JSONSerialization.jsonObject(with: $0, options: []) as? [String: Any]
                }), let eventType = event["event"] as? String {
                    if eventType == "group_created" {
                        if let groupData = event["group"] as? [String: Any],
                           let groupIDString = groupData["id"] as? String,
                           let groupID = UUID(uuidString: groupIDString),
                           let name = groupData["name"] as? String,
                           let members = groupData["members"] as? [String] {
                            let memberUUIDs = members.compactMap { UUID(uuidString: $0) }
                            let group = Group(id: groupID, name: name, members: memberUUIDs)
                            self?.groups.append(group)
                            print("Added new group: \(name)")
                        }
                    }
                }
                self?.messages.append(message)
            }
        }
    }

    func addContact(id: UUID, name: String) {
        let color = Color(hue: .random(in: 0...1), saturation: 0.8, brightness: 0.9, opacity: 1)
        let contact = Contact(id: id, name: name, profileColor: color, initials: name.uppercased().prefix(2).description)
        contacts.append(contact)
    }

    func filteredMessages(for recipient: UUID) -> [Message] {
        return messages.filter { $0.recipient == recipient || $0.sender == recipient }
    }

    func getContactName(for id: UUID) -> String {
        return contacts.first { $0.id == id }?.name ?? "Unknown"
    }
}
