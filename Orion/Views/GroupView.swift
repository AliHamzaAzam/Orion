//
//  GroupView.swift
//  Orion
//
//  Created by Ali Hamza Azam on 01/12/2024.
//

import SwiftUI

struct AddGroupView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var groupName: String = ""
    @State private var selectedMembers: Set<UUID> = []

    var body: some View {
        VStack {
            Text("Create Group")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter Group Name", text: $groupName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            List(viewModel.contacts) { contact in
                Button(action: {
                    if selectedMembers.contains(contact.id) {
                        selectedMembers.remove(contact.id)
                    } else {
                        selectedMembers.insert(contact.id)
                    }
                }) {
                    HStack {
                        Text(contact.id.uuidString)
                        Spacer()
                        if selectedMembers.contains(contact.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            
            Button(action: {
                viewModel.createGroup(name: groupName, members: Array(selectedMembers))
                groupName = ""
                selectedMembers.removeAll()
            }) {
                Text("Create Group")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}


struct GroupChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let groupID: UUID

    @State private var inputMessage: String = ""

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.filteredMessages(for: groupID), id: \.timestamp) { message in
                        ChatRow(message: message, currentUser: viewModel.currentUserID, currentContact: viewModel.getContactName(for: message.sender))
                    }
                }
            }
            .padding()
            .background(Color("Background"))
            .cornerRadius(8)

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
        .navigationTitle(viewModel.groups.first(where: { $0.id == groupID })?.name ?? "Group Chat")
    }

    private func sendMessage() {
        guard !inputMessage.isEmpty else { return }
        viewModel.sendMessageToGroup(content: inputMessage, groupID: groupID)
        inputMessage = ""
    }
}

