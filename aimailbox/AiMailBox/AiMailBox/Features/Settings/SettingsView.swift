import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var autoDeleteSpam = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    Text("user@example.com")
                    NavigationLink(destination: Text("Subscription Details")) {
                        Text("Subscription: Premium")
                    }
                }

                Section(header: Text("Preferences")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Auto-Delete Spam", isOn: $autoDeleteSpam)
                }
                
                Section(header: Text("Privacy & Data"), footer: Text("Manage your data and privacy settings.")) {
                    NavigationLink(destination: Text("Storage Details")) {
                        Text("Manage Storage")
                    }
                    Button("Export All Data") {
                        // TODO: Implement data export
                    }
                    Button("Delete All Cloud Data", role: .destructive) {
                        // TODO: Implement cloud data deletion
                    }
                }

                Section(header: Text("About")) {
                    Text("Version 1.0.0 (Build 1)")
                    NavigationLink("Privacy Policy", destination: Text("Privacy Policy content..."))
                    NavigationLink("Terms of Service", destination: Text("Terms of Service content..."))
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
