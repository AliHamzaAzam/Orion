//
//  ChatView.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import SwiftUI

// MARK: - ChatView
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let client: Contact // Unique identifier for the specific contact

    @State private var inputMessage: String = ""

    var body: some View {
        VStack {
            // Scrollable message list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.filteredMessages(for: client.id), id: \.timestamp) { message in
                        ChatRow(message: message, currentUser: viewModel.currentUserID, currentContact: client.name)
                    }
                }
            }
            .padding()
            .background(Color("Background"))
            .cornerRadius(8)

            // Message input field
            HStack {
                TextField("Type a message...", text: $inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 44)

                Button(action: sendMessage) {
                    Text("Send")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(inputMessage.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(inputMessage.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat with \(viewModel.getContactName(for: client.id))")
    }

    private func sendMessage() {
        guard !inputMessage.isEmpty else { return }
        viewModel.sendMessageToRecipient(content: inputMessage, recipient: client.id)
        inputMessage = ""
    }
}

// MARK: - ChatRow
struct ChatRow: View {
    let message: Message
    let currentUser: UUID
    let currentContact: String

    var body: some View {
        HStack {
            if message.sender == currentUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(message.content)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.black)
                }
            } else {
                VStack(alignment: .leading) {
                    Text(currentContact)
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.black)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChatViewModel()
        let client = Contact(id: UUID(), name: "Contact Name", profileColor: .green, initials: "CN")
        viewModel.addContact(id: client.id, name: "Contact Name")
        
        // Simulate a few messages
        viewModel.messages = [
            Message(sender: viewModel.currentUserID, recipient: client.id, content: "Hello!", timestamp: Date()),
            Message(sender: client.id, recipient: viewModel.currentUserID, content: "Hi there!", timestamp: Date())
        ]
        
        return ChatView(viewModel: viewModel, client: client)
    }
}
