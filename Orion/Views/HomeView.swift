//
//  HomeView.swift
//  Orion
//
//  Created by Ali Hamza Azam on 29/11/2024.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isSettingsPresented = false
    @State private var isAddContactPresented = false
    @State private var isAddGroupPresented = false
    @State private var selectedContact: UUID?
    @State private var selectedGroup: UUID?
    @State private var isNavigatingToChat = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ContactSection(viewModel: viewModel, selectedContact: $selectedContact, isNavigatingToChat: $isNavigatingToChat)
                    GroupSection(viewModel: viewModel, selectedGroup: $selectedGroup, isNavigatingToChat: $isNavigatingToChat)
                }
                .listStyle(PlainListStyle())

                Spacer()

                ActionButtons(
                    isAddContactPresented: $isAddContactPresented,
                    isAddGroupPresented: $isAddGroupPresented,
                    isSettingsPresented: $isSettingsPresented,
                    viewModel: viewModel
                )
            }
            .navigationTitle("Chats")
            .navigationDestination(isPresented: $isNavigatingToChat) {
                if let contact = selectedContact {
                    ChatView(viewModel: viewModel, clientName: contact)
                } else if let group = selectedGroup {
                    GroupChatView(viewModel: viewModel, groupID: group)
                }
            }
            .onAppear {
                viewModel.retrieveGroups()
            }
        }
    }
}

struct ContactSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var selectedContact: UUID?
    @Binding var isNavigatingToChat: Bool

    var body: some View {
        Section(header: Text("Contacts")) {
            ForEach(viewModel.contacts) { contact in
                Button(action: {
                    selectedContact = contact.id
                    isNavigatingToChat = true
                }) {
                    HStack {
                        Circle()
                            .fill(contact.profileColor)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(contact.initials)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading) {
                            Text(contact.name)
                                .font(.headline)
                            Text(contact.id.uuidString)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct GroupSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var selectedGroup: UUID?
    @Binding var isNavigatingToChat: Bool

    var body: some View {
        Section(header: Text("Groups")) {
            ForEach(viewModel.groups) { group in
                Button(action: {
                    selectedGroup = group.id
                    isNavigatingToChat = true
                }) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(String(group.name.prefix(2)))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text(group.id.uuidString)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct ActionButtons: View {
    @Binding var isAddContactPresented: Bool
    @Binding var isAddGroupPresented: Bool
    @Binding var isSettingsPresented: Bool
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()

                Button(action: {
                    isAddContactPresented = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.bottom, 16)
                .sheet(isPresented: $isAddContactPresented) {
                    AddContactView(viewModel: viewModel)
                }

                Button(action: {
                    isAddGroupPresented = true
                }) {
                    Image(systemName: "person.3")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.bottom, 16)
                .sheet(isPresented: $isAddGroupPresented) {
                    AddGroupView(viewModel: viewModel)
                }

                Button(action: {
                    isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                }
            }
            .padding()
        }
    }
}




// MARK: - Add Contact View
struct AddContactView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var newContactUUID: String = ""
    @State private var newContactName: String = ""

    var body: some View {
        VStack {
            Text("Add Contact")
                .font(.largeTitle)
                .padding()

            TextField("Enter UUID", text: $newContactUUID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            TextField("Enter Name", text: $newContactName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                if let uuid = UUID(uuidString: newContactUUID) {
                    viewModel.addContact(id: uuid, name: newContactName)
                } else {
                    print("Invalid UUID")
                }
                newContactUUID = ""
            }) {
                Text("Add")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}


// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: ChatViewModel())
    }
}
