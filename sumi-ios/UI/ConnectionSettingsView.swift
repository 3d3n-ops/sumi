//
//  ConnectionSettingsView.swift
//  sumi-ios
//
//  Advanced: the interim Worker connection config (URL override + shared secret)
//  moved out of the main Settings screen. Secrets live in the Keychain only.
//  This goes away once Prompt 6.4 lands Sign in with Apple.
//

import SwiftUI
import UIKit

struct ConnectionSettingsView: View {
    @State private var workerURL = Keychain.string(for: Keychain.workerURLKey) ?? ""
    @State private var workerSecret = Keychain.string(for: Keychain.workerSecretKey) ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                TextField("Worker URL (override)", text: $workerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Shared secret", text: $workerSecret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save", action: save)
            } header: {
                Text("Connection")
            } footer: {
                Text("Using: \(WorkerConfig.resolvedWorkerURL() ?? "not configured")")
            }
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: saved)
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

        UIApplication.shared.registerForRemoteNotifications()
        saved.toggle()
    }
}

#Preview {
    NavigationStack { ConnectionSettingsView() }
}
