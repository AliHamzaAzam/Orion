//
//  SettingsView.swift
//  Orion
//
//  Created by Ali Hamza Azam on 27/11/2024.
//

import SwiftUI

struct SettingsView: View {
    @State private var isNotificationsEnabled = true
    @State private var selectedTheme = "Light"
    @State private var showProfileEditor = false

    let themes = ["Light", "Dark", "System"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .bold()
                .padding()

            Form {
                // Notifications Toggle
                Section(header: Text("Preferences")) {
                    Toggle(isOn: $isNotificationsEnabled) {
                        Label("Enable Notifications", systemImage: "bell")
                    }
                }

                // Theme Picker
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Profile Editor
                Section {
                    Button(action: {
                        showProfileEditor = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .padding(.trailing)
                            Text("Edit Profile")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showProfileEditor) {
                        ProfileEditorView()
                    }
                }
            }
            .frame(maxWidth: 600)
            .padding()

            Spacer()

            // Footer
            Text("App Version 1.0.0")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 600)
        .background(
            Color(PlatformSpecificBackgroundColor())
                .edgesIgnoringSafeArea(.all)
        )
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                Button("Close") {
                    // Add close action for macOS modal
                }
            }
            #endif
        }
    }
}

struct ProfileEditorView: View {
    @State private var username: String = "John Doe"
    @State private var profileColor: Color = .blue

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Profile")
                .font(.largeTitle)
                .bold()
                .padding()

            // Profile Name
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Profile Color Picker
            VStack(alignment: .leading) {
                Text("Profile Color")
                    .font(.headline)
                ColorPicker("Choose Color", selection: $profileColor)
                    .padding(.horizontal)
            }

            Spacer()

            // Save Button
            Button(action: {
                // Save profile updates
                print("Profile Updated: \(username), \(profileColor)")
            }) {
                Text("Save")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 600)
        .background(
            Color(PlatformSpecificSecondaryBackgroundColor())
                .edgesIgnoringSafeArea(.all)
        )
    }
}

// MARK: - Platform-Specific Background Colors
func PlatformSpecificBackgroundColor() -> Color {
    #if os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #else
    return Color(.systemGroupedBackground)
    #endif
}

func PlatformSpecificSecondaryBackgroundColor() -> Color {
    #if os(macOS)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color(.secondarySystemGroupedBackground)
    #endif
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

