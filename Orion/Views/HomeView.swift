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
    @State private var selectedContact: UUID?
    @State private var isNavigatingToChat = false

    var body: some View {
        NavigationStack {
            VStack {
                // List of Contacts
                List(viewModel.contacts) { contact in
                    Button(action: {
                        selectedContact = contact.id
                        isNavigatingToChat = true
                    }) {
                        HStack {
                            // Profile Picture with Random Color
                            Circle()
                                .fill(contact.profileColor)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(contact.initials)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )

                            // Contact UUID
                            VStack(alignment: .leading) {
                                Text("Contact")
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
                .listStyle(PlainListStyle())

                Spacer()

                // Floating Buttons
                HStack {
                    Spacer()
                    VStack {
                        Spacer()

                        // Add Contact Button
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

                        // Settings Button
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
            .navigationTitle("Chats")
            .navigationDestination(isPresented: $isNavigatingToChat) {
                if let contact = selectedContact {
                    ChatView(viewModel: viewModel, clientName: contact)
                }
            }
        }
    }
}

// MARK: - Add Contact View
struct AddContactView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var newContactUUID: String = ""

    var body: some View {
        VStack {
            Text("Add Contact")
                .font(.largeTitle)
                .padding()

            TextField("Enter UUID", text: $newContactUUID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                if let uuid = UUID(uuidString: newContactUUID) {
                    viewModel.addContact(id: uuid)
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
