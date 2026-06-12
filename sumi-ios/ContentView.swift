//
//  ContentView.swift
//  sumi-ios
//
//  Sumi is proactive-first — it surfaces through notifications and Siri, not by
//  being opened. This placeholder reassures the user it's running, and (until
//  the real Settings screen lands in Sprint 6) offers a minimal field to point
//  the app at its Cloudflare Worker so cloud answers and push work on device.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var workerURL = Keychain.string(for: Keychain.workerURLKey) ?? ""
    @State private var workerSecret = Keychain.string(for: Keychain.workerSecretKey) ?? ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Sumi works in the background. You'll hear from it through Siri and notifications — you don't need to open this app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("Connection") {
                    TextField("Worker URL", text: $workerURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Shared secret", text: $workerSecret)
                    Button("Save", action: save)
                }
            }
            .navigationTitle("Sumi")
            .alert("Saved", isPresented: $didSave) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func save() {
        let url = workerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = workerSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if url.isEmpty {
            Keychain.remove(for: Keychain.workerURLKey)
        } else {
            Keychain.set(url, for: Keychain.workerURLKey)
        }
        if secret.isEmpty {
            Keychain.remove(for: Keychain.workerSecretKey)
        } else {
            Keychain.set(secret, for: Keychain.workerSecretKey)
        }

        // Re-upload the APNs token now that the Worker URL is known.
        UIApplication.shared.registerForRemoteNotifications()
        didSave = true
    }
}

#Preview {
    ContentView()
}
