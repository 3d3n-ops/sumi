//
//  SettingsView.swift
//  sumi-ios
//
//  Minimal settings, reached from the conversation screen's toolbar. Holds the
//  interim Worker connection config (URL override + shared secret) until the
//  full Sprint 6 settings + Prompt 6.4 auth land.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workerURL = Keychain.string(for: Keychain.workerURLKey) ?? ""
    @State private var workerSecret = Keychain.string(for: Keychain.workerSecretKey) ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Sumi also works in the background — it surfaces through Siri and notifications without you opening it.")
                        .font(.callout).foregroundStyle(.secondary)
                }
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
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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

        UIApplication.shared.registerForRemoteNotifications()
    }
}
