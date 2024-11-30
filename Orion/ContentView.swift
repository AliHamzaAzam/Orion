//
//  ContentView.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var serverAddress: String = "127.0.0.1"
    @State private var serverPort: String = "8080"
    @State private var isConnected: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                if !isConnected {
                    // Connection UI
                    VStack(spacing: 16) {
                        TextField("Server Address", text: $serverAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        TextField("Server Port", text: $serverPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        Button(action: connectToServer) {
                            Text("Connect")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Show HomeView once connected
                    HomeView(viewModel: viewModel)
                }
            }
            .frame(minWidth: 400, minHeight: 300) // Default macOS window size
        }
        .navigationTitle("Chat App")
    }

    private func connectToServer() {
        if let port = UInt16(serverPort) {
            viewModel.connectToServer(serverAddress: serverAddress, serverPort: port)
            isConnected = true
        } else {
            print("Invalid port number")
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
